import hashlib
import secrets
from datetime import datetime, timedelta
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
    jti = secrets.token_hex(16)   # unique token ID for revocation (NFR-016)
    to_encode.update({"exp": expire, "jti": jti})
    token = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return token, jti


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ─── CNIC Hashing & AES-256 Encryption ───────────────────────────────────────

def hash_cnic(cnic: str) -> str:
    """SHA-256 hash of CNIC for fast lookup/matching."""
    return hashlib.sha256(cnic.encode()).hexdigest()


def _get_aes_key() -> bytes:
    key = settings.AES_ENCRYPTION_KEY.encode()
    return key[:32].ljust(32, b"\x00")  # Ensure exactly 32 bytes


def encrypt_cnic(cnic: str) -> bytes:
    """AES-256-CBC encryption. Returns iv + ciphertext."""
    key = _get_aes_key()
    iv = secrets.token_bytes(16)
    padder = padding.PKCS7(128).padder()
    padded = padder.update(cnic.encode()) + padder.finalize()
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(padded) + encryptor.finalize()
    return iv + ciphertext


def decrypt_cnic(encrypted: bytes) -> str:
    """Decrypt AES-256-CBC encrypted CNIC."""
    key = _get_aes_key()
    iv, ciphertext = encrypted[:16], encrypted[16:]
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    padded = decryptor.update(ciphertext) + decryptor.finalize()
    unpadder = padding.PKCS7(128).unpadder()
    return (unpadder.update(padded) + unpadder.finalize()).decode()


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
    # Update last_used_at
    from datetime import datetime, timezone
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
    user_id: int = payload.get("sub")
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    # Also verify session is still active
    session = (
        db.query(AuthSession)
        .filter(AuthSession.user_id == user_id, AuthSession.is_active == True)
        .order_by(AuthSession.created_at.desc())
        .first()
    )
    if not session:
        raise HTTPException(status_code=401, detail="Session expired or logged out")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
