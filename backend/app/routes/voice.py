"""Voice processing route: POST /voice/process"""
import json
import time
from datetime import datetime, timezone, timedelta
import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, Request
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.sanitization import sanitise_text, validate_audio_file, detect_liveness
from app.core.rate_limit import user_limiter
from app.core.security import get_current_user
from app.database.database import get_db
from app.models.auth_session import AuthSession
from app.models.voice_nonce import VoiceNonce
from app.models.transaction import Transaction
from app.models.voice_command import VoiceCommand
from app.schemas.misc_schema import VoiceProcessResponse, TextInputRequest
from app.services import (
    contact_service,
    dialogue_service,
    nlu_service,
    otp_service,
    raast_service,
    response_templates as tmpl,
    stt_service,
    tts_service,
    transcription as transcription_service,
)

def levenshtein_similarity(s1: str, s2: str) -> float:
    """Computes Levenshtein similarity between two strings."""
    if len(s1) < len(s2):
        s1, s2 = s2, s1
    if len(s2) == 0:
        return 1.0 if len(s1) == 0 else 0.0
    
    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
        
    distance = previous_row[-1]
    max_len = max(len(s1), len(s2))
    return 1.0 - (distance / max_len)


def match_account_type(text: str) -> str:
    """
    Fuzzy matches the user's transcription to one of the bank account types:
    Easypaisa, Jazzcash, Nayapay, Sadapay, or Bank Transfer.
    Returns 'multiple' if more than one matches (asking user to clarify),
    'unknown' if none matches, or the matching canonical string.
    """
    import re
    text_clean = re.sub(r'[^\w\s]', '', text.lower()).strip()
    
    # Define keywords/variations for token matching and simple similarity
    categories = {
        "Bank Transfer": ["bank", "transfer", "account", "بینک"],
        "Easypaisa": ["easypaisa", "easy paisa", "easy pesa", "easy paysa", "easy", "paisa", "pesa", "paysa", "ایزی پیسہ"],
        "Jazzcash": ["jazzcash", "jazz cash", "jazcash", "jazz", "cash", "جاز کیش"],
        "Nayapay": ["nayapay", "naya pay", "naya", "نیا پے"],
        "Sadapay": ["sadapay", "sada pay", "sada", "سادہ پے"]
    }
    
    # Exact phrase matches take high priority
    exact_phrases = {
        "Bank Transfer": ["bank transfer", "bank account", "bank", "transfer"],
        "Easypaisa": ["easypaisa", "easy paisa", "easy pesa", "easy paysa", "easy, pesa", "easy, paisa", "easypesa", "easypaysa"],
        "Jazzcash": ["jazzcash", "jazz cash", "jazcash"],
        "Nayapay": ["nayapay", "naya pay"],
        "Sadapay": ["sadapay", "sada pay"]
    }
    
    matched_exact = []
    for cat, phrases in exact_phrases.items():
        for phrase in phrases:
            if phrase in text_clean or phrase in text.lower():
                matched_exact.append(cat)
                break
                
    unique_exact = list(set(matched_exact))
    if len(unique_exact) == 1:
        return unique_exact[0]
    elif len(unique_exact) > 1:
        return "multiple"
        
    # Keyword & Fuzzy token fallback
    matched_cats = []
    tokens = text_clean.split()
    for cat, kw_list in categories.items():
        for kw in kw_list:
            if kw in text_clean:
                matched_cats.append(cat)
                break
            
            # Fuzzy match word tokens
            for token in tokens:
                if len(token) >= 4 and len(kw) >= 4:
                    sim = levenshtein_similarity(token, kw)
                    if sim >= 0.8:
                        matched_cats.append(cat)
                        break
                        
    unique_cats = list(set(matched_cats))
    if len(unique_cats) == 1:
        return unique_cats[0]
    elif len(unique_cats) > 1:
        return "multiple"
        
    return "unknown"


router = APIRouter(prefix="/voice", tags=["Voice AI"])

@router.get("/nonce")
def get_voice_nonce(db: Session = Depends(get_db)):
    """Generate a single-use nonce valid for 60 seconds to prevent replay attacks."""
    nonce_val = str(uuid.uuid4())
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=60)
    record = VoiceNonce(nonce=nonce_val, expires_at=expires_at, is_used=False)
    db.add(record)
    db.commit()
    return {"nonce": nonce_val, "expires_in": 60}


@router.post("/process-text", response_model=VoiceProcessResponse)
@user_limiter.limit("60/minute")
async def process_text(
    request: Request,
    payload: TextInputRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Manual text input endpoint – bypasses STT.
    Used for PIN entry or typing commands.
    """
    start_ms = time.perf_counter()
    lang = current_user.preferred_language or "ur"

    # ── 0. Validate Nonce (Anti-Replay) ───────────────────────────────────────
    nonce_record = db.query(VoiceNonce).filter(VoiceNonce.nonce == payload.nonce).first()
    if not nonce_record or nonce_record.is_used or datetime.now(timezone.utc) > nonce_record.expires_at:
        raise HTTPException(status_code=400, detail="Invalid or expired nonce.")
    nonce_record.is_used = True
    db.commit()

    text = sanitise_text(payload.text, max_length=2000)
    
    return await _handle_voice_logic(
        db=db,
        current_user=current_user,
        transcription=text,
        detected_lang=lang,
        start_ms=start_ms,
        stt_result={"duration_seconds": 0.0}
    )


@router.post("/process", response_model=VoiceProcessResponse)
@user_limiter.limit("30/minute")
async def process_voice(
    request: Request,
    nonce: str = Form(..., description="Cryptographic nonce to prevent replay attacks"),
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

    # ── 0. Validate Nonce (Anti-Replay) ───────────────────────────────────────
    nonce_record = db.query(VoiceNonce).filter(VoiceNonce.nonce == nonce).first()
    if not nonce_record or nonce_record.is_used or datetime.now(timezone.utc) > nonce_record.expires_at:
        raise HTTPException(status_code=400, detail="Invalid or expired nonce. Possible replay attack.")
    nonce_record.is_used = True
    db.commit()

    # ── 1. Read & validate audio bytes ────────────────────────────────────────
    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # Validate file type
    validation = validate_audio_file(
        audio_bytes,
        audio.filename or "upload.wav",
        max_size=settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024,
    )
    if not validation["valid"]:
        raise HTTPException(status_code=400, detail=validation["reason"])

    # ── 1.5 Liveness Detection
    liveness = detect_liveness(audio_bytes)
    if not liveness["is_live"]:
        raise HTTPException(status_code=403, detail="Audio spoofing detected.")

    # ── 2. STT: transcribe audio ──────────────────────────────────────────────
    import tempfile, os
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        stt_result = transcription_service.transcribe_audio(tmp_path, language=lang)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    if "error" in stt_result:
        raise HTTPException(status_code=500, detail=f"Speech transcription failed: {stt_result.get('error')}")

    transcription = sanitise_text(stt_result["text"], max_length=2000)
    detected_lang = stt_result.get("language", lang)
    
    # Normalize language to 'ur' or 'en'
    raw_lang = str(detected_lang).lower()
    if raw_lang in ["hi", "hindi", "urdu", "ur", "pa", "punjabi", "sd", "sindhi"]:
        detected_lang = "ur"
    elif raw_lang in ["english", "en"]:
        detected_lang = "en"
    else:
        detected_lang = "ur"

    return await _handle_voice_logic(
        db=db,
        current_user=current_user,
        transcription=transcription,
        detected_lang=detected_lang,
        start_ms=start_ms,
        stt_result=stt_result
    )


async def _handle_voice_logic(
    db: Session,
    current_user,
    transcription: str,
    detected_lang: str,
    start_ms: float,
    stt_result: dict
):
    # ── 3. NLU: classify intent ───────────────────────────────────────────────
    print(f"[Voice] Input: '{transcription}'")
    nlu_result = nlu_service.classify_intent(transcription)
    intent = nlu_result["intent"]
    confidence = nlu_result["confidence"]
    entities = nlu_result["entities"]
    print(f"[Voice] Result -> Intent: {intent} ({confidence:.2f})")

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
    response_payload = None

    # ── 5. Intent handler ─────────────────────────────────────────────────────
    if intent in ["check_balance", "transaction_history", "transfer_money"]:
        dialogue_service.reset_state(db, session_id)
        state = "IDLE"

    if intent == "cancel":
        dialogue_service.reset_state(db, session_id)
        response_text = "ٹھیک ہے، کینسل کر دیا گیا ہے۔" if detected_lang == "ur" else "Cancelled."

    elif state == "AWAITING_OTP":
        otp_code = transcription.strip().replace(" ", "")
        pending = dialogue["pending_action"] or {}
        otp_result = otp_service.verify_otp(db, current_user.user_id, otp_code)
        if otp_result["success"]:
            dialogue_service.set_state(db, session_id, "EXECUTING", pending)
            try:
                from app.models.partner import Partner
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
                response_text = tmpl.transfer_success(pending["recipient_name"], pending["amount"], detected_lang)
            except ValueError as e:
                dialogue_service.reset_state(db, session_id)
                response_text = str(e)
        else:
            response_text = otp_result["reason"]

    elif state == "AWAITING_PAYMENT_METHOD":
        pending = dialogue["pending_action"] or {}
        text_lower = transcription.lower()
        raast_keywords = ["raast", "راست", "rast", "rust", "raz", "ras", "rahst", "raaast"]
        if any(kw in text_lower for kw in raast_keywords):
            dialogue_service.set_state(db, session_id, "AWAITING_RAAST_ID", pending)
            response_text = "براہ کرم راست (Raast) اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else "Please enter the Raast account number."
        else:
            # Check if they directly mentioned a wallet or bank type (even multiple)
            matched_type = match_account_type(transcription)
            if matched_type == "multiple":
                dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_TYPE", pending)
                response_text = "براہ کرم اکاؤنٹ کی قسم بتائیں: ایزی پیسہ، جاز کیش، نیا پے، سادہ پے یا بینک ٹرانسفر۔" if detected_lang == "ur" else "Please specify the account type: Easypaisa, Jazzcash, Nayapay, Sadapay, or Bank Transfer."
            elif matched_type in ["Bank Transfer", "Easypaisa", "Jazzcash", "Nayapay", "Sadapay"]:
                if matched_type == "Bank Transfer":
                    pending["account_type"] = "Bank Transfer"
                    dialogue_service.set_state(db, session_id, "AWAITING_BANK_NAME", pending)
                    response_text = "براہ کرم بینک کا نام بتائیں، جیسے بینک الفلاح، میزان بینک، یا یو بی ایل۔" if detected_lang == "ur" else "Please speak the bank name, such as Bank Alfalah, Meezan Bank, or UBL."
                else:
                    pending["account_type"] = matched_type
                    dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
                    response_text = f"براہ کرم {matched_type} اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else f"Please enter the {matched_type} account number."
            elif "account" in text_lower or "اکاؤنٹ" in text_lower or "number" in text_lower:
                dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_TYPE", pending)
                response_text = "براہ کرم اکاؤنٹ کی قسم بتائیں: ایزی پیسہ، جاز کیش، نیا پے، سادہ پے یا بینک ٹرانسفر۔" if detected_lang == "ur" else "Please specify the account type: Easypaisa, Jazzcash, Nayapay, Sadapay, or Bank Transfer."
            else:
                response_text = "براہ کرم بتائیں: اکاؤنٹ نمبر یا راست؟" if detected_lang == "ur" else "Please specify: Account Number or Raast?"

    elif state == "AWAITING_ACCOUNT_TYPE":
        pending = dialogue["pending_action"] or {}
        matched_type = match_account_type(transcription)
        
        if matched_type == "Bank Transfer":
            pending["account_type"] = "Bank Transfer"
            dialogue_service.set_state(db, session_id, "AWAITING_BANK_NAME", pending)
            response_text = "براہ کرم بینک کا نام بتائیں، جیسے بینک الفلاح، میزان بینک، یا یو بی ایل۔" if detected_lang == "ur" else "Please speak the bank name, such as Bank Alfalah, Meezan Bank, or UBL."
        elif matched_type == "Easypaisa":
            pending["account_type"] = "Easypaisa"
            dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
            response_text = "براہ کرم ایزی پیسہ اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else "Please enter the Easypaisa account number."
        elif matched_type == "Jazzcash":
            pending["account_type"] = "Jazzcash"
            dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
            response_text = "براہ کرم جاز کیش اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else "Please enter the Jazzcash account number."
        elif matched_type == "Nayapay":
            pending["account_type"] = "Nayapay"
            dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
            response_text = "براہ کرم نیا پے اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else "Please enter the Nayapay account number."
        elif matched_type == "Sadapay":
            pending["account_type"] = "Sadapay"
            dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
            response_text = "براہ کرم سادہ پے اکاؤنٹ نمبر درج کریں۔" if detected_lang == "ur" else "Please enter the Sadapay account number."
        elif matched_type == "multiple":
            response_text = "معذرت، آپ نے ایک سے زیادہ آپشنز بتائے ہیں۔ براہ کرم کسی ایک کا انتخاب کریں: ایزی پیسہ، جاز کیش، نیا پے، سادہ پے یا بینک؟" if detected_lang == "ur" else "You mentioned multiple options. Please specify only one: Easypaisa, Jazzcash, Nayapay, Sadapay, or Bank?"
        else:
            response_text = "معذرت، میں سمجھ نہیں سکا۔ براہ کرم بتائیں: ایزی پیسہ، جاز کیش، نیا پے، سادہ پے یا بینک؟" if detected_lang == "ur" else "Sorry, I didn't catch that. Please specify: Easypaisa, Jazzcash, Nayapay, Sadapay, or Bank?"

    elif state == "AWAITING_BANK_NAME":
        pending = dialogue["pending_action"] or {}
        text_lower = transcription.lower()
        if any(kw in text_lower for kw in ["alfalah", "alpha", "al falah", "al-falah", "الفلاح"]):
            pending["bank_name"] = "Bank Alfalah"
        elif any(kw in text_lower for kw in ["meezan", "میزان"]):
            pending["bank_name"] = "Meezan Bank"
        elif any(kw in text_lower for kw in ["ubl", "یو بی ایل"]):
            pending["bank_name"] = "UBL"
        else:
            pending["bank_name"] = transcription.title()
            
        dialogue_service.set_state(db, session_id, "AWAITING_ACCOUNT_NUMBER", pending)
        response_text = f"براہ کرم {pending['bank_name']} کا اکاؤنٹ نمبر یا IBAN درج کریں۔" if detected_lang == "ur" else f"Please enter the account number or IBAN for {pending['bank_name']}."

    elif state == "AWAITING_ACCOUNT_NUMBER":
        import re
        # Allow letters for IBAN (PK...) but ignore spaces/dashes
        entered_account = re.sub(r'[^a-zA-Z0-9]', '', transcription).upper()
        
        pending = dialogue["pending_action"] or {}
        account_type = pending.get("account_type", "Account")
        bank_name = pending.get("bank_name", "")
        
        # Support both mock account numbers and mock IBANs
        mock_accounts = {
            "Easypaisa": ["03451234567"],
            "Jazzcash": ["03001234567"],
            "Nayapay": ["03331234567"],
            "Sadapay": ["03111234567"],
            "Bank Alfalah": ["100200300400", "PK12ALFH100200300400"]
        }
        
        # Determine the expected mocks based on selection
        expected_mocks = mock_accounts.get(bank_name if account_type == "Bank Transfer" else account_type, ["123456789"])
        
        if entered_account in expected_mocks:
            pending["recipient_account"] = entered_account
            pending["is_raast"] = False
            dialogue_service.set_state(db, session_id, "AWAITING_PIN", pending)
            response_text = "Write your 4 digit pin." if detected_lang == "en" else "اپنا 4 ہندسوں کا پن لکھیں۔"
        else:
            display_name = bank_name if account_type == "Bank Transfer" else account_type
            response_text = f"Incorrect {display_name} account number. Please enter the correct account number or IBAN." if detected_lang == "en" else f"غلط {display_name} اکاؤنٹ نمبر۔ براہ کرم درست اکاؤنٹ نمبر یا IBAN درج کریں۔"

    elif state == "AWAITING_RAAST_ID":
        import re
        digits = re.sub(r'\D', '', transcription)
        
        pending = dialogue["pending_action"] or {}
        recipient_name = pending.get("recipient_name", "")
        
        mock_raast_mapping = {
            "Cafe": "03001111111",
            "Coffee Shop": "03002222222",
            "Tailor": "03003333333",
            "School Fees": "03004444444",
            "Ali": "03006666666",
            "Ahmed": "03007777777",
            "Farzam": "03000000000"
        }
        
        MOCK_RAAST_NUMBER = mock_raast_mapping.get(recipient_name, "03331234567")
        
        if digits == MOCK_RAAST_NUMBER:
            pending["recipient_account"] = digits
            pending["is_raast"] = True
            dialogue_service.set_state(db, session_id, "AWAITING_PIN", pending)
            response_text = "Write your 4 digit pin." if detected_lang == "en" else "اپنا 4 ہندسوں کا پن لکھیں۔"
        else:
            response_text = f"The Raast number for {recipient_name} must match the mock number: {MOCK_RAAST_NUMBER}." if detected_lang == "en" else f"براہ کرم {recipient_name} کا موک راست نمبر درج کریں: {MOCK_RAAST_NUMBER}۔"

    elif state == "AWAITING_REFERENCE_NUMBER":
        import re
        digits = re.sub(r'\D', '', transcription)
        
        pending = dialogue["pending_action"] or {}
        recipient_name = pending.get("recipient_name", "")
        
        mock_reference_mapping = {
            "Electricity Bill": "11223344",
            "Water Bill": "55667788",
            "Gas Bill": "99001122"
        }
        
        MOCK_REF = mock_reference_mapping.get(recipient_name, "12345678")
        
        if digits == MOCK_REF:
            pending["reference_number"] = digits
            dialogue_service.set_state(db, session_id, "AWAITING_CONFIRMATION", pending)
            response_text = tmpl.confirm_transfer_prompt(pending.get("recipient_name"), pending.get("amount"), detected_lang)
        else:
            response_text = f"The reference number for {recipient_name} must match the mock number: {MOCK_REF}." if detected_lang == "en" else f"براہ کرم {recipient_name} کا موک حوالہ نمبر (Reference Number) درج کریں: {MOCK_REF}۔"

    elif state == "AWAITING_CONFIRMATION":
        if intent == "confirm":
            pending = dialogue["pending_action"] or {}
            dialogue_service.set_state(db, session_id, "AWAITING_PIN", pending)
            response_text = "Write your 4 digit pin." if detected_lang == "en" else "اپنا 4 ہندسوں کا پن لکھیں۔"
        else:
            dialogue_service.reset_state(db, session_id)
            response_text = "ٹھیک ہے، ٹرانزیکشن کینسل کر دی گئی ہے۔" if detected_lang == "ur" else "Transaction cancelled."

    elif state == "AWAITING_PIN":
        import re
        from app.core.security import verify_password
        
        digits = re.sub(r'\D', '', transcription)
        if len(digits) >= 4:
            pin = digits[:4]
            if current_user.pin_hash and verify_password(pin, current_user.pin_hash):
                pending = dialogue["pending_action"] or {}
                otp_service.send_otp(db, current_user.user_id, current_user.phone_number)
                dialogue_service.set_state(db, session_id, "AWAITING_OTP", pending)
                response_text = tmpl.otp_sent(detected_lang)
            else:
                response_text = "غلط پن۔ براہ کرم صحیح 4 ہندسوں کا پن درج کریں۔" if detected_lang == "ur" else "Incorrect PIN. Please provide the correct 4-digit PIN."
        else:
            response_text = "Write your 4 digit pin." if detected_lang == "en" else "اپنا 4 ہندسوں کا پن لکھیں۔"

    elif intent == "check_balance":
        baseline = 50000.00
        total_spent = db.query(func.sum(Transaction.amount)).filter(
            Transaction.sender_id == current_user.user_id,
            Transaction.status == "completed"
        ).scalar() or 0.0
        current_balance = float(baseline) - float(total_spent)
        formatted_balance = f"{current_balance:,.2f}"
        response_text = tmpl.balance_response(formatted_balance, detected_lang)

    elif intent == "transaction_history":
        from sqlalchemy import or_
        filter_condition = Transaction.sender_id == current_user.user_id
        if current_user.account_number:
            filter_condition = or_(filter_condition, Transaction.recipient_account == current_user.account_number)
        history = db.query(Transaction).filter(filter_condition).order_by(Transaction.created_at.desc()).limit(5).all()
        history_list = [{"type": "sent" if t.sender_id == current_user.user_id else "received", "amount": float(t.amount), "status": t.status, "date": t.created_at.isoformat() if t.created_at else None} for t in history]
        response_payload = {"transactions": history_list}
        response_text = tmpl.transaction_history_intro(len(history), detected_lang)

    elif intent == "get_account_info":
        acc = current_user.account_number or "N/A"
        response_text = f"آپ کا اکاؤنٹ نمبر {acc} ہے۔" if detected_lang == "ur" else f"Your account number is {acc}."

    elif intent == "transfer_money":
        recipient_query = entities.get("recipient", "")
        amount = entities.get("amount", 0)
        if not recipient_query or not amount:
            response_text = "براہ کرم بتائیں: کسے اور کتنے روپے بھیجنا ہیں؟" if detected_lang == "ur" else "Please specify recipient and amount."
        else:
            baseline = 50000.00
            total_spent = db.query(func.sum(Transaction.amount)).filter(Transaction.sender_id == current_user.user_id, Transaction.status == "completed").scalar() or 0.0
            current_balance = float(baseline) - float(total_spent)
            if float(amount) > current_balance:
                formatted_balance = f"{current_balance:,.2f}"
                response_text = tmpl.insufficient_balance(formatted_balance, str(amount), detected_lang)
            else:
                match_result = contact_service.find_contact_for_user(db, current_user.user_id, recipient_query)
                if match_result["matched"]:
                    contact = match_result["contact"]
                    pending = {"recipient_name": contact.full_name, "recipient_account": contact.account_number_masked, "amount": str(amount)}
                    
                    if contact.full_name in ["Electricity Bill", "Water Bill", "Gas Bill"]:
                        dialogue_service.set_state(db, session_id, "AWAITING_REFERENCE_NUMBER", pending)
                        response_text = "براہ کرم بل کا حوالہ نمبر (Reference Number) بولیں یا لکھیں۔" if detected_lang == "ur" else "Please say or enter the bill reference number."
                    elif contact.full_name in ["Ali", "Ahmed", "Farzam", "Bilal", "Usman", "Fatima", "Ayesha", "Saad", "Hamza"]:
                        # Pre-fill account number for saved contacts to skip manual entry
                        mock_saved_accounts = {
                            "Ali": "03006666666",
                            "Ahmed": "03007777777",
                            "Farzam": "03000000000",
                            "Bilal": "03011112222",
                            "Usman": "03022223333",
                            "Fatima": "03033334444",
                            "Ayesha": "03044445555",
                            "Saad": "03055556666",
                            "Hamza": "03066667777"
                        }
                        pending["recipient_account"] = mock_saved_accounts.get(contact.full_name, "123456789")
                        pending["is_raast"] = False
                        dialogue_service.set_state(db, session_id, "AWAITING_PIN", pending)
                        response_text = "Write your 4 digit pin." if detected_lang == "en" else "اپنا 4 ہندسوں کا پن لکھیں۔"
                    else:
                        dialogue_service.set_state(db, session_id, "AWAITING_PAYMENT_METHOD", pending)
                        response_text = "کیا آپ اکاؤنٹ نمبر کے ذریعے پیسے بھیجنا چاہتے ہیں یا راست (Raast) کے ذریعے؟" if detected_lang == "ur" else "Do you want to send via Account Number or Raast?"
                else:
                    response_text = "رابطہ نہیں ملا۔ نام دوبارہ بولیں۔" if detected_lang == "ur" else "Contact not found. Please repeat the name."
    else:
        response_text = tmpl.unknown_intent(detected_lang)

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

    # If it's Urdu or Hindi, prioritize the Nastaliq Urdu version from Gemini
    if detected_lang == "ur" and nlu_result.get("nastaliq_urdu"):
        transcription = nlu_result["nastaliq_urdu"]

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
        payload=response_payload,
    )
