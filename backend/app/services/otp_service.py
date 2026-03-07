"""
OTP service: generate, send via Twilio SMS, verify with expiry + lockout.
"""
import secrets
import hashlib
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session
from twilio.rest import Client

from app.core.config import settings
from app.models.otp import OtpRequest
from app.models.user import User

MAX_FAILED_ATTEMPTS = 3
OTP_EXPIRY_SECONDS = 60
LOCKOUT_MINUTES = 15

_twilio_client = None


def _get_twilio() -> Client:
    global _twilio_client
    if _twilio_client is None:
        _twilio_client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    return _twilio_client


def generate_otp() -> str:
    """6-digit cryptographically secure OTP."""
    return str(secrets.randbelow(900000) + 100000)   # always 6 digits


def send_otp(db: Session, user_id: int, phone_number: str) -> OtpRequest:
    """Generate OTP, persist to DB, send via Twilio SMS."""
    otp_code = generate_otp()
    otp_hash = hashlib.sha256(otp_code.encode()).hexdigest()   # never store plaintext
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=OTP_EXPIRY_SECONDS)

    record = OtpRequest(
        user_id=user_id,
        otp_hash=otp_hash,
        phone_number=phone_number,
        expires_at=expires_at,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    # Send SMS
    try:
        _get_twilio().messages.create(
            body=f"Your PayTalk OTP is: {otp_code}. Valid for {OTP_EXPIRY_SECONDS} seconds.",
            from_=settings.TWILIO_PHONE_NUMBER,
            to=phone_number,
        )
    except Exception as e:
        print(f"[OTP] Twilio send failed: {e}")
        # Do NOT raise – OTP is still in DB; let caller handle gracefully

    return record


def verify_otp(db: Session, user_id: int, otp_code: str) -> dict:
    """
    Validate OTP. Returns {"success": True} or {"success": False, "reason": str}.
    Increments failed_auth_count; locks account after MAX_FAILED_ATTEMPTS.
    """
    now = datetime.now(timezone.utc)

    # Most recent unused OTP for this user
    record = (
        db.query(OtpRequest)
        .filter(
            OtpRequest.user_id == user_id,
            OtpRequest.is_used == False,
        )
        .order_by(OtpRequest.created_at.desc())
        .first()
    )

    if not record:
        return {"success": False, "reason": "No pending OTP found"}

    # Check expiry
    if now > record.expires_at:
        return {"success": False, "reason": "OTP has expired"}

    # Check code — compare hashes, never compare plaintext
    submitted_hash = hashlib.sha256(otp_code.encode()).hexdigest()
    if record.otp_hash != submitted_hash:
        record.attempt_count += 1
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.failed_auth_count += 1
            if user.failed_auth_count >= MAX_FAILED_ATTEMPTS:
                user.locked_until = now + timedelta(minutes=LOCKOUT_MINUTES)
        db.commit()
        return {"success": False, "reason": "Incorrect OTP"}

    # Mark used
    record.is_used = True
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.failed_auth_count = 0  # reset on success
    db.commit()

    return {"success": True}
