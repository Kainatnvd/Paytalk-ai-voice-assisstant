from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text, func

from app.database.base import Base


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    session_token = Column(String(512), nullable=False, unique=True)
    jwt_jti = Column(String(128), unique=True, nullable=True, index=True)  # NFR-016: JWT revocation
    device_id = Column(String(255), nullable=True)
    ip_address = Column(String(45), nullable=True)
    is_active = Column(Boolean, default=True)
    auth_method = Column(String(30), nullable=True)   # 'otp' | 'nfc_otp' — NFR-017 MFA audit
    dialogue_state = Column(String(50), default="IDLE")  # IDLE | AWAITING_CONFIRMATION | AWAITING_OTP | EXECUTING | COMPLETE
    pending_action = Column(Text, nullable=True)          # JSON blob for in-progress transfer
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_activity = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())