from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, SmallInteger, String, func

from app.database.base import Base


class OtpRequest(Base):
    __tablename__ = "otp_requests"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    otp_hash = Column(String(64), nullable=False)           # SHA-256 — never store plaintext OTP
    phone_number = Column(String(20), nullable=False)
    purpose = Column(String(50), nullable=False, default="login")  # 'login' | 'transfer' | 'bill_payment'
    is_used = Column(Boolean, default=False)
    attempt_count = Column(SmallInteger, default=0)         # renamed from failed_attempts
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
