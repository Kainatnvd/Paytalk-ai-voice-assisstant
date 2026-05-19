"""Auth routes: /auth/*"""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    create_access_token,
    encrypt_cnic,
    get_current_user,
    hash_cnic,
    hash_phone_number,
    hash_password,
    normalize_cnic,
    verify_password,
)
from app.database.database import get_db
from app.models.auth_session import AuthSession
from app.models.user import User
from app.models.partner import Partner
from app.schemas.misc_schema import NfcMockRequest, NfcVerifyRequest, NfcVerifyResponse
from app.schemas.otp_schema import OtpSendRequest, OtpVerifyRequest, OtpResponse
from app.schemas.user_schema import TokenResponse, UserLoginRequest, UserRegisterRequest, UserResponse, ForgotPasswordRequest, ForgotPinRequest
from app.services import nfc_service, otp_service
from app.models.contacts import Contact
from app.core.rate_limit import limiter

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=201)
def register(payload: UserRegisterRequest, db: Session = Depends(get_db)):
    """Register a new user under a partner. CNIC is hashed and AES-256 encrypted on save."""
    phone_hash = hash_phone_number(payload.phone_number)
    if db.query(User).filter(User.phone_number_hash == phone_hash).first():
        raise HTTPException(status_code=409, detail="Phone number already registered")

    # Normalize CNIC: strip dashes so "12345-6789012-3" → "1234567890123"
    cnic_normalized = normalize_cnic(payload.cnic)

    cnic_hash = hash_cnic(cnic_normalized)
    if db.query(User).filter(User.cnic_hash == cnic_hash).first():
        raise HTTPException(status_code=409, detail="CNIC already registered")

    partner_id = payload.partner_id
    if partner_id is None:
        default_partner = db.query(Partner).first()
        if not default_partner:
            raise HTTPException(status_code=500, detail="No partners found in database. Please run create_partner.py.")
        partner_id = default_partner.partner_id
    elif not db.query(Partner).filter(Partner.partner_id == partner_id).first():
        raise HTTPException(status_code=400, detail="Invalid partner_id")

    user = User(
        user_id=uuid.uuid4(),  # Explicitly set so AAD is valid during encryption
        email=payload.email,
        password_hash=hash_password(payload.password),
        pin_hash=hash_password(payload.pin),
        partner_id=partner_id,
        preferred_language=payload.preferred_language or "ur",
    )
    # Use standardized setter for PII and CNIC
    user.full_name = payload.full_name or "Unknown User"
    user.phone_number = payload.phone_number
    user.set_cnic(cnic_normalized)
    
    db.add(user)
    db.commit()
    db.refresh(user)

    # Seed demo contacts for the new user so they can immediately test voice NLP
    demo_contacts = [
        Contact(user_id=user.user_id, full_name="Cafe", account_number_masked="****1111", bank_name="HBL"),
        Contact(user_id=user.user_id, full_name="Coffee Shop", account_number_masked="****2222", bank_name="Meezan"),
        Contact(user_id=user.user_id, full_name="Tailor", account_number_masked="****3333", bank_name="Alfalah"),
        Contact(user_id=user.user_id, full_name="School", account_number_masked="****4444", bank_name="Allied"),
        Contact(user_id=user.user_id, full_name="Electric Bill", account_number_masked="****5555", bank_name="KE"),
        Contact(user_id=user.user_id, full_name="Ali", account_number_masked="****6666", bank_name="JazzCash"),
        Contact(user_id=user.user_id, full_name="Ahmed", account_number_masked="****7777", bank_name="Easypaisa"),
    ]
    db.add_all(demo_contacts)
    db.commit()

    return user


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, payload: UserLoginRequest, db: Session = Depends(get_db)):
    """Validate credentials, create JWT, and record auth session."""
    phone_hash = hash_phone_number(payload.phone_number)
    user = db.query(User).filter(User.phone_number_hash == phone_hash).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is disabled")

    # Check lockout
    if user.locked_until and datetime.now(timezone.utc) < user.locked_until:
        raise HTTPException(status_code=423, detail=f"Account locked until {user.locked_until}")

    token, jti = create_access_token({"sub": str(user.user_id)})   # unpack tuple (token, jti)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    session = AuthSession(
        user_id=user.user_id,
        session_token=token,
        jwt_jti=jti,
        device_id=request.headers.get("X-Device-Id"),
        ip_address=request.client.host,
        auth_method="otp",
        expires_at=expires_at,
    )
    db.add(session)
    db.commit()

    return TokenResponse(access_token=token, user=user)


@router.post("/reset-password")
def reset_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Reset a user's password using their phone number and CNIC."""
    phone_hash = hash_phone_number(payload.phone_number)
    user = db.query(User).filter(User.phone_number_hash == phone_hash).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    cnic_normalized = normalize_cnic(payload.cnic)
    
    # Verify CNIC (Lazy Migration support)
    current_hash = hash_cnic(cnic_normalized, salt=str(user.user_id))
    legacy_hash = hash_cnic(cnic_normalized, salt="default_static_salt_for_migration")
    raw_hash = hash_cnic(cnic_normalized, salt="") # old unsalted (empty salt)

    if user.cnic_hash not in [current_hash, legacy_hash, raw_hash]:
        raise HTTPException(status_code=401, detail="Identity verification failed. Invalid CNIC.")

    # Lazy Migration: Update to salted hash and GCM encryption if needed
    if user.cnic_hash != current_hash:
        user.set_cnic(cnic_normalized)

    user.password_hash = hash_password(payload.new_password)
    db.commit()


    return {"message": "Password reset successfully"}


@router.post("/reset-pin")
def reset_pin(payload: ForgotPinRequest, db: Session = Depends(get_db)):
    """Reset a user's transaction PIN using their phone number and CNIC."""
    phone_hash = hash_phone_number(payload.phone_number)
    user = db.query(User).filter(User.phone_number_hash == phone_hash).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    cnic_normalized = normalize_cnic(payload.cnic)
    
    # Verify CNIC (Lazy Migration support)
    current_hash = hash_cnic(cnic_normalized, salt=str(user.user_id))
    legacy_hash = hash_cnic(cnic_normalized, salt="default_static_salt_for_migration")
    raw_hash = hash_cnic(cnic_normalized, salt="") # old unsalted (empty salt)

    if user.cnic_hash not in [current_hash, legacy_hash, raw_hash]:
        raise HTTPException(status_code=401, detail="Identity verification failed. Invalid CNIC.")

    # Lazy Migration: Update to salted hash and GCM encryption if needed
    if user.cnic_hash != current_hash:
        user.set_cnic(cnic_normalized)

    user.pin_hash = hash_password(payload.new_pin)
    db.commit()

    return {"message": "PIN reset successfully"}


@router.post("/otp/send", response_model=OtpResponse)
def send_otp(payload: OtpSendRequest, current_user=Depends(get_current_user), db: Session = Depends(get_db)):
    """Generate and SMS an OTP to the user's phone number."""
    otp_service.send_otp(db, current_user.user_id, payload.phone_number)
    return OtpResponse(message="OTP sent successfully", expires_in_seconds=60)


@router.post("/otp/verify")
def verify_otp(payload: OtpVerifyRequest, db: Session = Depends(get_db)):
    """Verify a submitted OTP code."""
    result = otp_service.verify_otp(db, payload.user_id, payload.otp_code)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["reason"])
    return {"message": "OTP verified successfully"}


@router.post("/nfc/verify", response_model=NfcVerifyResponse)
def nfc_verify(payload: NfcVerifyRequest, request: Request, db: Session = Depends(get_db)):
    """Verify a CNIC hash received from an NFC scan."""
    matched = nfc_service.verify_cnic_hash(db, payload.cnic_hash, payload.user_id, request.client.host)
    return NfcVerifyResponse(
        matched=matched,
        message="Identity verified" if matched else "CNIC does not match",
    )


@router.post("/nfc/mock", response_model=dict)
def nfc_mock(payload: NfcMockRequest, db: Session = Depends(get_db)):
    """Mock NADRA lookup – for FYP demo without real NFC hardware."""
    nadra_result = nfc_service.mock_nadra_lookup(payload.cnic)
    if not nadra_result["valid"]:
        raise HTTPException(status_code=400, detail=nadra_result.get("reason"))
    cnic_normalized = normalize_cnic(payload.cnic)
    cnic_hash = hash_cnic(cnic_normalized)
    matched = nfc_service.verify_cnic_hash(db, cnic_hash, payload.user_id)
    return {**nadra_result, "hash_matched": matched}


@router.post("/logout")
def logout(current_user=Depends(get_current_user), db: Session = Depends(get_db)):
    """Deactivate the current session."""
    session = (
        db.query(AuthSession)
        .filter(AuthSession.user_id == current_user.user_id, AuthSession.is_active == True)
        .order_by(AuthSession.created_at.desc())
        .first()
    )
    if session:
        session.is_active = False
        db.commit()
    return {"message": "Logged out successfully"}