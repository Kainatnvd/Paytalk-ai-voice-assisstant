from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, LargeBinary, String, func
from app.database.base import Base

class Contact(Base):
    __tablename__ = "contacts"

    id                       = Column(Integer, primary_key=True, index=True)
    user_id                  = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False, index=True)
    full_name                = Column(String(255), nullable=False)       # RapidFuzz match target
    nickname                 = Column(String(100), nullable=True)        # e.g. 'Ali bhai'
    raast_id                 = Column(String(100), nullable=True)
    account_number_encrypted = Column(LargeBinary, nullable=True)        # AES-256
    account_number_masked    = Column(String(20), nullable=True)         # e.g. ****5678
    bank_name                = Column(String(255), nullable=True)
    is_active                = Column(Boolean, default=True)
    created_at               = Column(DateTime(timezone=True), server_default=func.now())
    updated_at               = Column(DateTime(timezone=True), onupdate=func.now())