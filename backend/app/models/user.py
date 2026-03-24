# from sqlalchemy import Boolean, Column, DateTime, Integer, LargeBinary, String, func

# from app.database.base import Base


# class User(Base):
#     __tablename__ = "users"

#     id = Column(Integer, primary_key=True, index=True)
#     full_name = Column(String(200), nullable=False)
#     phone_number = Column(String(20), unique=True, nullable=False, index=True)
#     email = Column(String(255), unique=True, nullable=True)
#     password_hash = Column(String(255), nullable=False)
#     cnic_hash = Column(String(64), unique=True, nullable=False)          # SHA-256 hex
#     cnic_encrypted = Column(LargeBinary, nullable=False)                  # AES-256 bytes
#     account_number = Column(String(50), unique=True, nullable=True)
#     partner_id = Column(Integer, nullable=True)
#     preferred_language = Column(String(10), default="ur")                 # 'ur' or 'en'
#     failed_auth_count = Column(Integer, default=0)
#     locked_until = Column(DateTime(timezone=True), nullable=True)
#     is_active = Column(Boolean, default=True)
#     voice_consent_given = Column(Boolean, default=False)   # BR-004: required before storing audio
#     created_at = Column(DateTime(timezone=True), server_default=func.now())
#     updated_at = Column(DateTime(timezone=True), onupdate=func.now())
from sqlalchemy import Boolean, Column, DateTime, LargeBinary, SmallInteger, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy import ForeignKey
import uuid

from app.database.base import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partner_id = Column(UUID(as_uuid=True), ForeignKey("partners.partner_id"), nullable=False)
    phone_number = Column(String(20), nullable=False)
    email = Column(String(255), nullable=True)
    full_name = Column(String(200), nullable=False)
    password_hash = Column(String(255), nullable=False)
    account_number = Column(String(50), unique=True, nullable=True)
    cnic_hash = Column(String(64), nullable=True)
    cnic_encrypted = Column(LargeBinary, nullable=True)
    password_hash = Column(String(255), nullable=True)
    preferred_language = Column(String(10), default="ur")
    is_active = Column(Boolean, default=True)
    failed_auth_count = Column(SmallInteger, default=0)
    locked_until = Column(DateTime(timezone=True), nullable=True)
    voice_consent_given = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())