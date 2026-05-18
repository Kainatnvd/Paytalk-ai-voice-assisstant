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

from sqlalchemy.ext.hybrid import hybrid_property
from app.database.base import Base
from app.core.security import encrypt_data, decrypt_data


class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partner_id = Column(UUID(as_uuid=True), ForeignKey("partners.partner_id"), nullable=False)
    # Plaintext columns (deprecated, for migration)
    _phone_number = Column("phone_number", String(20), nullable=True)
    _full_name = Column("full_name", String(200), nullable=True)

    # Banking-grade encrypted columns (AES-256-GCM)
    phone_number_encrypted = Column(LargeBinary, nullable=True)
    phone_number_hash = Column(String(64), index=True, nullable=True) # Searchable hash
    full_name_encrypted = Column(LargeBinary, nullable=True)
    
    email = Column(String(255), nullable=True)
    password_hash = Column(String(255), nullable=False)
    account_number = Column(String(50), unique=True, nullable=True)
    cnic_hash = Column(String(64), nullable=True)
    cnic_encrypted = Column(LargeBinary, nullable=True)
    pin_hash = Column(String(255), nullable=True)
    preferred_language = Column(String(10), default="ur")
    is_active = Column(Boolean, default=True)
    failed_auth_count = Column(SmallInteger, default=0)
    locked_until = Column(DateTime(timezone=True), nullable=True)
    voice_consent_given = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())

    @hybrid_property
    def full_name(self) -> str:
        if self.full_name_encrypted:
            # Try lowercase first (new standard)
            try:
                return decrypt_data(self.full_name_encrypted, aad=str(self.user_id).lower())
            except Exception:
                # Fallback to original casing for older users
                try:
                    return decrypt_data(self.full_name_encrypted, aad=str(self.user_id))
                except Exception as e:
                    print(f"[Model] Decryption failed for user {self.user_id} full_name: {e}")
                    return self._full_name or "[Decryption Error]"
        return self._full_name or ""

    @full_name.setter
    def full_name(self, value: str):
        self.full_name_encrypted = encrypt_data(value, aad=str(self.user_id).lower())
        self._full_name = None

    @full_name.expression
    def full_name(cls):
        return cls._full_name

    @hybrid_property
    def phone_number(self) -> str:
        if self.phone_number_encrypted:
            try:
                return decrypt_data(self.phone_number_encrypted, aad=str(self.user_id).lower())
            except Exception:
                try:
                    return decrypt_data(self.phone_number_encrypted, aad=str(self.user_id))
                except Exception as e:
                    print(f"[Model] Decryption failed for user {self.user_id} phone_number: {e}")
                    return self._phone_number or "[Decryption Error]"
        return self._phone_number or ""

    @phone_number.setter
    def phone_number(self, value: str):
        from app.core.security import hash_phone_number
        self.phone_number_encrypted = encrypt_data(value, aad=str(self.user_id).lower())
        self.phone_number_hash = hash_phone_number(value)
        self._phone_number = None

    @phone_number.expression
    def phone_number(cls):
        return cls._phone_number

    def set_cnic(self, cnic: str):
        """Standardized setter for CNIC to handle hashing and GCM encryption."""
        from app.core.security import hash_cnic
        self.cnic_hash = hash_cnic(cnic, salt=str(self.user_id).lower())
        self.cnic_encrypted = encrypt_data(cnic, aad=str(self.user_id).lower())