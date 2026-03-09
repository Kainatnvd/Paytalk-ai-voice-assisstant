from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func

from app.database.base import Base


class NfcVerification(Base):
    __tablename__ = "nfc_verifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    cnic_hash_scanned = Column(String(64), nullable=False)
    matched = Column(Boolean, default=False)
    device_info = Column(String(255), nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
