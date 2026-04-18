"""Voice processing route: POST /voice/process"""
import json
import time
from decimal import Decimal

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.database.database import get_db
from app.models.auth_session import AuthSession
from app.models.transaction import Transaction
from app.models.voice_command import VoiceCommand
from app.schemas.misc_schema import VoiceProcessResponse
from app.services import (
    contact_service,
    dialogue_service,
    nlu_service,
    otp_service,
    raast_service,
    response_templates as tmpl,
    stt_service,
    tts_service,
)

router = APIRouter(prefix="/voice", tags=["Voice AI"])


@router.post("/process", response_model=VoiceProcessResponse)
async def process_voice(
    audio: UploadFile = File(..., description="Audio file (WAV/MP3/OGG)"),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Main SDK endpoint – full pipeline:
    Audio → Whisper STT → Rasa NLU → Intent Handler → TTS response
    """
    start_ms = time.perf_counter()
    lang = current_user.preferred_language or "ur"

    # ── 1. Read audio bytes ───────────────────────────────────────────────────
    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # ── 2. STT: transcribe audio ──────────────────────────────────────────────
    stt_result = stt_service.transcribe_audio(audio_bytes, language_hint=lang)
    if "error" in stt_result:
        raise HTTPException(status_code=500, detail="Speech transcription failed")

    transcription = stt_result["text"]
    detected_lang = stt_result.get("language", lang)

    # ── 3. NLU: classify intent ───────────────────────────────────────────────
    nlu_result = nlu_service.classify_intent(transcription)
    intent = nlu_result["intent"]
    confidence = nlu_result["confidence"]
    entities = nlu_result["entities"]

    # ── 4. Fetch current session ──────────────────────────────────────────────
    session = (
        db.query(AuthSession)
        .filter(AuthSession.user_id == current_user.user_id, AuthSession.is_active == True)
        .order_by(AuthSession.created_at.desc())
        .first()
    )
    session_id = session.id if session else None
    dialogue = dialogue_service.get_state(db, session_id)
    state = dialogue["state"]

    response_text = ""

    # ── 5. Intent handler ─────────────────────────────────────────────────────
    # If it's a new primary command, reset any stuck state
    if intent in ["check_balance", "transaction_history", "transfer_money"]:
        dialogue_service.reset_state(db, session_id)
        state = "IDLE"

    if intent == "cancel":
        dialogue_service.reset_state(db, session_id)
        response_text = "Theek hai, cancel kar diya." if lang == "ur" else "Cancelled."

    elif state == "AWAITING_OTP":
        # User is expected to speak the OTP
        otp_code = transcription.strip().replace(" ", "")
        pending = dialogue["pending_action"] or {}
        otp_result = otp_service.verify_otp(db, current_user.user_id, otp_code)
        if otp_result["success"]:
            dialogue_service.set_state(db, session_id, "EXECUTING", pending)
            try:
                partner_id = current_user.partner_id
                if not partner_id:
                    default_partner = db.query(Partner).first()
                    partner_id = default_partner.partner_id if default_partner else None

                txn = raast_service.initiate_transfer(
                    db=db,
                    sender_id=current_user.user_id,
                    recipient_account=pending["recipient_account"],
                    recipient_name=pending["recipient_name"],
                    amount=Decimal(str(pending["amount"])),
                    partner_id=partner_id,
                )
                dialogue_service.reset_state(db, session_id)
                response_text = tmpl.transfer_success(pending["recipient_name"], pending["amount"], lang)
            except ValueError as e:
                dialogue_service.reset_state(db, session_id)
                response_text = str(e)
        else:
            response_text = otp_result["reason"]

    elif state == "AWAITING_CONFIRMATION":
        if intent == "confirm":
            pending = dialogue["pending_action"] or {}
            otp_service.send_otp(db, current_user.user_id, current_user.phone_number)
            dialogue_service.set_state(db, session_id, "AWAITING_OTP", pending)
            response_text = tmpl.otp_sent(lang)
        else:
            dialogue_service.reset_state(db, session_id)
            response_text = "Theek hai, transaction cancel kar diya." if lang == "ur" else "Transaction cancelled."

    elif intent == "check_balance":
        baseline = 50000.00
        total_spent = db.query(func.sum(Transaction.amount)).filter(
            Transaction.sender_id == current_user.user_id,
            Transaction.status == "completed"
        ).scalar() or 0.0
        
        current_balance = float(baseline) - float(total_spent)
        formatted_balance = f"{current_balance:,.2f}"
        
        response_text = tmpl.balance_response(formatted_balance, lang)

    elif intent == "transaction_history":
        response_text = tmpl.transaction_history_intro(5, lang)

    elif intent == "get_account_info":
        acc = current_user.account_number or "N/A"
        response_text = f"Aapka account number {acc} hai." if lang == "ur" else f"Your account number is {acc}."

    elif intent == "transfer_money":
        recipient_query = entities.get("recipient", "")
        amount = entities.get("amount", 0)

        if not recipient_query or not amount:
            response_text = "Please batayein: kise aur kitne rupay bhejna hai?" if lang == "ur" else "Please specify recipient and amount."
        else:
            match_result = contact_service.find_contact_for_user(db, current_user.user_id, recipient_query)

            if not match_result["matched"]:
                response_text = "Contact nahi mila. Naam dobara bolein." if lang == "ur" else "Contact not found. Please repeat the name."

            elif match_result["confidence"] == "high":
                contact = match_result["contact"]
                pending = {
                    "recipient_name": contact.full_name,
                    "recipient_account": contact.account_number_masked,
                    "amount": str(amount),
                }
                dialogue_service.set_state(db, session_id, "AWAITING_CONFIRMATION", pending)
                response_text = tmpl.confirm_transfer_prompt(contact.full_name, str(amount), lang)
            else:
                response_text = "Contact nahi mila. Naam dobara bolein." if lang == "ur" else "Contact not found. Please repeat the name."

            elif match_result["confidence"] == "low":
                names = ", ".join([c.full_name for c in match_result["candidates"]])
                response_text = (
                    f"Kya aap in mein se kisi ko bhejna chahte hain? {names}"
                    if lang == "ur"
                    else f"Did you mean one of these? {names}. Please say the full name."
                )
    else:
        response_text = tmpl.unknown_intent(lang)

    # ── 6. Generate TTS response ──────────────────────────────────────────────
    response_audio_b64 = tts_service.generate_voice_response_base64(response_text, detected_lang)

    # ── 7. Log to voice_commands ──────────────────────────────────────────────
    elapsed_ms = int((time.perf_counter() - start_ms) * 1000)
    db.add(VoiceCommand(
        user_id=current_user.user_id,
        session_id=session_id,
        audio_duration_seconds=stt_result.get("duration_seconds"),
        transcribed_text=transcription,
        language_detected=detected_lang,
        intent=intent,
        intent_confidence=confidence,
        entities=json.dumps(entities),
        response_text=response_text,
        processing_time_ms=elapsed_ms,
    ))
    db.commit()

    return VoiceProcessResponse(
        transcription=transcription,
        language=detected_lang,
        intent=intent,
        confidence=confidence,
        entities=entities,
        response_text=response_text,
        response_audio=response_audio_b64,
        session_id=session_id,
        processing_time_ms=elapsed_ms,
        dialogue_state=dialogue_service.get_state(db, session_id)["state"] if session_id else "IDLE",
        pending_action=dialogue_service.get_state(db, session_id)["pending_action"] if session_id else None,
    )
