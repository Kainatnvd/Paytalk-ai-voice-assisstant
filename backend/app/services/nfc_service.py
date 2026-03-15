"""
NFC / CNIC verification service.
Real NADRA API requires official permission – mock used for FYP demo.
"""
from sqlalchemy.orm import Session

from app.core.security import hash_cnic
from app.models.nfc_verification import NfcVerification
from app.models.user import User


def verify_cnic_hash(db: Session, cnic_hash: str, user_id: int, ip: str = None) -> bool:
    """Compare scanned CNIC hash against stored hash in users table."""
    user = db.query(User).filter(User.user_id == user_id).first()
    matched = user is not None and user.cnic_hash == cnic_hash

    # Log every NFC scan
    db.add(NfcVerification(
    user_id=user_id,
    cnic_chip_id_hash=cnic_hash,
    verification_status="success" if matched else "failed",
))
    db.commit()

    return matched


def mock_nadra_lookup(cnic: str) -> dict:
    """
    Simulated NADRA CNIC verification for FYP demo.
    In production this would call the official NADRA Verisys API.
    """
    # Basic format validation
    cleaned = cnic.replace("-", "")
    if len(cleaned) != 13 or not cleaned.isdigit():
        return {"valid": False, "reason": "Invalid CNIC format"}

    # Mock response: always valid for demo
    return {
        "valid": True,
        "cnic": cleaned,
        "name": "Demo Citizen",
        "dob": "1990-01-01",
        "gender": "M",
        "province": "Punjab",
        "note": "MOCK RESPONSE – not real NADRA data",
    }
