"""
OTP service: generate, send via console mock (Twilio disabled), verify with expiry + lockout.
"""
import secrets
import hashlib
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.otp import OtpRequest
from app.models.user import User
from app.models.audit_log import AuditLog

MAX_FAILED_ATTEMPTS = 3
OTP_EXPIRY_SECONDS = 60
LOCKOUT_MINUTES = 15


def generate_otp() -> str:
    """6-digit cryptographically secure OTP."""
    return str(secrets.randbelow(900000) + 100000)   # always 6 digits


def send_otp(db: Session, user_id, phone_number: str, purpose: str = "login") -> OtpRequest:
    """Generate OTP, persist to DB, print to console (mock mode)."""
    otp_code = generate_otp()
    otp_hash = hashlib.sha256(otp_code.encode()).hexdigest()   # never store plaintext
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=OTP_EXPIRY_SECONDS)

    record = OtpRequest(
        user_id=user_id,
        otp_hash=otp_hash,
        phone_number=phone_number,
        purpose=purpose,
        expires_at=expires_at,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    # ── MOCK MODE: print OTP to console instead of sending via Twilio ──
    print(f"\n{'='*50}")
    print(f"[MOCK OTP] Phone: {phone_number}")
    print(f"[MOCK OTP] Code:  {otp_code}")
    print(f"[MOCK OTP] Valid for {OTP_EXPIRY_SECONDS} seconds")
    print(f"{'='*50}\n")

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
        
        # Write to immutable audit log
        audit_entry = AuditLog(
            user_id=user_id,
            event_type="OTP_FAILED",
            severity="WARNING",
            details=f"Failed OTP attempt {record.attempt_count} for phone {record.phone_number}"
        )
        db.add(audit_entry)
        
        user = db.query(User).filter(User.user_id == user_id).first()
        if user:
            user.failed_auth_count += 1
            if user.failed_auth_count >= MAX_FAILED_ATTEMPTS:
                user.locked_until = now + timedelta(minutes=LOCKOUT_MINUTES)
                
        db.commit()
        
        # Anomaly Detection: Check if >10 failed attempts in the last hour
        one_hour_ago = now - timedelta(hours=1)
        recent_failures = db.query(AuditLog).filter(
            AuditLog.user_id == user_id,
            AuditLog.event_type == "OTP_FAILED",
            AuditLog.timestamp >= one_hour_ago
        ).count()
        
        if recent_failures >= 10:
            alert = AuditLog(
                user_id=user_id,
                event_type="ANOMALY_ALERT",
                severity="CRITICAL",
                details=f"BRUTE FORCE DETECTED: {recent_failures} failed OTP attempts in the last hour."
            )
            db.add(alert)
            db.commit()
            print(f"\n[CRITICAL ALERT] Possible brute force attack detected for User ID: {user_id}\n")
            
        return {"success": False, "reason": "Incorrect OTP"}

    # Mark used
    record.is_used = True
    user = db.query(User).filter(User.user_id == user_id).first()
    if user:
        user.failed_auth_count = 0  # reset on success
    db.commit()

    return {"success": True}
