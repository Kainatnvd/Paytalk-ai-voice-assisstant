import hashlib
import secrets
import struct
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.secrets_manager import secrets_manager
from app.database.database import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer()


# ─── Password Hashing ──────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


# ─── JWT ───────────────────────────────────────────────────────────────────────

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> tuple[str, str]:
    """Returns (token_string, jti) so the caller can store jti in auth_sessions."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    jti = secrets.token_hex(16)
    to_encode.update({"exp": expire, "jti": jti})
    active_key = secrets_manager.get_active_jwt_key()
    token = jwt.encode(to_encode, active_key, algorithm=settings.ALGORITHM)
    return token, jti


def decode_access_token(token: str) -> dict:
    for rec in secrets_manager.jwt_keys:
        try:
            return jwt.decode(token, rec.key, algorithms=[settings.ALGORITHM])
        except JWTError:
            continue
            
    raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ─── CNIC Hashing & AES-256 Encryption ───────────────────────────────────────

def normalize_cnic(cnic: str) -> str:
    """Normalize CNIC: strip dashes and whitespace to get exactly 13 digits."""
    return cnic.replace("-", "").strip()


def hash_cnic(cnic: str, salt: str = "default_static_salt_for_migration") -> str:
    """Salted SHA-256 hash of CNIC."""
    salted = cnic + salt
    return hashlib.sha256(salted.encode()).hexdigest()


def hash_phone_number(phone: str) -> str:
    """
    Searchable hash for phone numbers. 
    Uses a static salt from settings to ensure it can be computed for queries.
    """
    static_salt = settings.SECRET_KEY # Use the app's secret key as salt
    salted = phone + static_salt
    return hashlib.sha256(salted.encode()).hexdigest()


def _get_aes_key_and_version() -> tuple[bytes, str]:
    rec = secrets_manager.get_active_aes_record()
    key = rec.key.encode()[:32].ljust(32, b"\x00")
    return key, rec.version


def encrypt_data(data: str, aad: Optional[str] = None) -> bytes:
    """
    AES-256-GCM encryption. 
    Returns: b"gcm:" + version_len(1) + version + iv(12) + tag(16) + ciphertext
    """
    key, version = _get_aes_key_and_version()
    iv = secrets.token_bytes(12)  # 12 bytes is standard for GCM
    aesgcm = Cipher(
        algorithms.AES(key),
        modes.GCM(iv),
        backend=default_backend()
    ).encryptor()
    
    if aad:
        aesgcm.authenticate_additional_data(aad.encode())
        
    ciphertext = aesgcm.update(data.encode()) + aesgcm.finalize()
    tag = aesgcm.tag
    
    v_bytes = version.encode()
    return b"gcm:" + struct.pack("B", len(v_bytes)) + v_bytes + iv + tag + ciphertext


def decrypt_data(encrypted: bytes, aad: Optional[str] = None) -> str:
    """
    Decrypt data, supporting both legacy CBC and new GCM with lazy migration.
    """
    if not encrypted:
        return ""

    # Check for GCM prefix
    if encrypted.startswith(b"gcm:"):
        try:
            v_len = struct.unpack("B", encrypted[4:5])[0]
            version = encrypted[5:5+v_len].decode()
            iv = encrypted[5+v_len : 5+v_len+12]
            tag = encrypted[5+v_len+12 : 5+v_len+12+16]
            ciphertext = encrypted[5+v_len+12+16:]
            
            rec = secrets_manager.get_aes_record_by_version(version)
            if not rec:
                raise ValueError(f"Unknown key version: {version}")
                
            key = rec.key.encode()[:32].ljust(32, b"\x00")
            
            cipher = Cipher(
                algorithms.AES(key),
                modes.GCM(iv, tag),
                backend=default_backend()
            )
            decryptor = cipher.decryptor()
            if aad:
                decryptor.authenticate_additional_data(aad.encode())
            
            return (decryptor.update(ciphertext) + decryptor.finalize()).decode()
        except Exception as e:
            print(f"[Security] GCM Decryption failed: {e}")
            raise

    # Fallback to legacy CBC
    iv, ciphertext = encrypted[:16], encrypted[16:]
    for rec in secrets_manager.get_all_aes_records():
        try:
            key = rec.key.encode()[:32].ljust(32, b"\x00")
            cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
            decryptor = cipher.decryptor()
            padded = decryptor.update(ciphertext) + decryptor.finalize()
            unpadder = padding.PKCS7(128).unpadder()
            return (unpadder.update(padded) + unpadder.finalize()).decode()
        except Exception:
            continue
            
    raise ValueError("Failed to decrypt data with any available key.")


# Keep old names for backward compatibility if needed, but point to new generic ones
encrypt_cnic = encrypt_data
decrypt_cnic = decrypt_data


# ─── SDK API Key Middleware ────────────────────────────────────────────────────

def validate_sdk_key(db: Session, api_key: str):
    """Validate SDK API key and return partner_id. Key is SHA-256 hashed before lookup."""
    from app.models.sdk_api_key import SdkApiKey
    hashed = hashlib.sha256(api_key.encode()).hexdigest()
    record = db.query(SdkApiKey).filter(
        SdkApiKey.key_hash == hashed,
        SdkApiKey.is_active == True,
    ).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid SDK API key")
    record.last_used_at = datetime.now(timezone.utc)
    db.commit()
    return record.partner_id


# ─── Dependency: get current user from JWT ────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    from app.models.auth_session import AuthSession
    from app.models.user import User

    token = credentials.credentials
    payload = decode_access_token(token)

    user_id_str = payload.get("sub")
    if user_id_str is None:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    jti = payload.get("jti")
    if not jti:
        raise HTTPException(status_code=401, detail="Invalid token payload: missing JTI")

    try:
        user_id = uuid.UUID(user_id_str)   # convert string back to UUID
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    # Verify session is still active (this acts as a strict token blacklist)
    session = (
        db.query(AuthSession)
        .filter(AuthSession.jwt_jti == jti, AuthSession.is_active == True)
        .first()
    )
    if not session:
        raise HTTPException(status_code=401, detail="Session expired or logged out")

    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user