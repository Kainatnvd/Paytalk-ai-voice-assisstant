"""Transaction routes: /transaction/*"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.database.database import get_db
from app.models.transaction import Transaction
from app.schemas.transaction_schema import TransactionResponse, TransferRequest
from app.services import contact_service, otp_service, raast_service
from app.services import response_templates as tmpl

router = APIRouter(prefix="/transaction", tags=["Transactions"])


@router.post("/transfer")
def initiate_transfer(
    payload: TransferRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Full transfer flow (API / non-voice path):
    1. Fuzzy-match contact name → account number
    2. Enforce confirmation required (BR-005) – client must POST /transaction/confirm
    Returns a pending confirmation token.
    """
    lang = current_user.preferred_language or "ur"

    # Step 1: Fuzzy match contact
    match_result = contact_service.find_contact_for_user(
        db, current_user.user_id, payload.recipient_name_query
    )
    if not match_result["matched"]:
        if match_result["candidates"]:
            return {
                "status": "ambiguous",
                "message": "Could not uniquely identify contact. Did you mean one of these?",
                "candidates": match_result["candidates"],
            }
        raise HTTPException(status_code=404, detail="No matching contact found")

    contact = match_result["contact"]

    # Step 2: Return confirmation prompt (BR-005: explicit confirmation required)
    return {
        "status": "awaiting_confirmation",
        "message": tmpl.confirm_transfer_prompt(contact.full_name, str(payload.amount), lang),
        "pending": {
            "recipient_name": contact.full_name,
            "recipient_account": contact.raast_id or contact.account_number_masked,
            "amount": str(payload.amount),
        },
    }


@router.post("/confirm")
def confirm_transfer(
    recipient_account: str,
    recipient_name: str,
    amount: float,
    otp_code: str,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Step 2 of transfer: verify OTP, then execute Raast payment.
    """
    lang = current_user.preferred_language or "ur"

    # Verify OTP
    otp_result = otp_service.verify_otp(db, current_user.user_id, otp_code)
    if not otp_result["success"]:
        raise HTTPException(status_code=400, detail=otp_result["reason"])

    # Execute transfer
    from decimal import Decimal
    try:
        txn = raast_service.initiate_transfer(
            db=db,
            sender_id=current_user.user_id,
            recipient_account=recipient_account,
            recipient_name=recipient_name,
            amount=Decimal(str(amount)),
            partner_id=current_user.partner_id or 1,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if txn.status.value == "completed":
        msg = tmpl.transfer_success(recipient_name, str(amount), lang)
    else:
        msg = tmpl.transfer_failed(lang)

    return {"status": txn.status.value, "message": msg, "transaction": txn}


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return details of a single transaction. Only the sender can view it."""
    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.sender_id == current_user.user_id,
    ).first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return txn
