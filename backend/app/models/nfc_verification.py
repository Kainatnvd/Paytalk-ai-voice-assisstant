from sqlalchemy.dialects.postgresql import UUID
# from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func

# from app.database.base import Base


# class NfcVerification(Base):
#     __tablename__ = "nfc_verifications"

#     id = Column(Integer, primary_key=True, index=True)
#     user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True, index=True)
#     cnic_hash_scanned = Column(String(64), nullable=False)
#     matched = Column(Boolean, default=False)
#     device_info = Column(String(255), nullable=True)
#     ip_address = Column(String(45), nullable=True)
#     created_at = Column(DateTime(timezone=True), server_default=func.now())
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from app.database.base import Base

class NfcVerification(Base):
    __tablename__ = "nfc_verifications"

    id                  = Column(Integer, primary_key=True, index=True)
    user_id             = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True, index=True)
    device_id           = Column(Integer, ForeignKey("user_devices.id"), nullable=True)
    cnic_chip_id_hash   = Column(String(64), nullable=True)          # SHA-256 of NFC chip serial
    verification_status = Column(String(20), nullable=False, default="failed")
    # valid: success | failed | chip_error | timeout | unsupported
    failure_reason      = Column(Text, nullable=True)                # NULL when status = success
    session_id          = Column(Integer, ForeignKey("auth_sessions.id"), nullable=True)
    verified_at         = Column(DateTime(timezone=True), server_default=func.now())