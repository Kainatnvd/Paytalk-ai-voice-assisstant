from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, LargeBinary, String, func
from sqlalchemy.ext.hybrid import hybrid_property
from app.database.base import Base
from app.core.security import encrypt_data, decrypt_data

class Contact(Base):
    __tablename__ = "contacts"

    id                       = Column(Integer, primary_key=True, index=True)
    user_id                  = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False, index=True)
    # Plaintext (deprecated)
    _full_name = Column("full_name", String(255), nullable=True)
    _nickname = Column("nickname", String(100), nullable=True)
    _raast_id = Column("raast_id", String(100), nullable=True)

    # Encrypted (AES-256-GCM)
    full_name_encrypted = Column(LargeBinary, nullable=True)
    nickname_encrypted = Column(LargeBinary, nullable=True)
    raast_id_encrypted = Column(LargeBinary, nullable=True)
    
    account_number_encrypted = Column(LargeBinary, nullable=True)
    account_number_masked    = Column(String(20), nullable=True)
    bank_name                = Column(String(255), nullable=True)
    is_active                = Column(Boolean, default=True)
    created_at               = Column(DateTime(timezone=True), server_default=func.now())
    updated_at               = Column(DateTime(timezone=True), onupdate=func.now())

    @hybrid_property
    def full_name(self) -> str:
        if self.full_name_encrypted:
            return decrypt_data(self.full_name_encrypted, aad=str(self.user_id))
        return self._full_name or ""

    @full_name.setter
    def full_name(self, value: str):
        self.full_name_encrypted = encrypt_data(value, aad=str(self.user_id))
        self._full_name = None

    @full_name.expression
    def full_name(cls):
        return cls._full_name

    @hybrid_property
    def nickname(self) -> str:
        if self.nickname_encrypted:
            return decrypt_data(self.nickname_encrypted, aad=str(self.user_id))
        return self._nickname or ""

    @nickname.setter
    def nickname(self, value: str):
        self.nickname_encrypted = encrypt_data(value, aad=str(self.user_id))
        self._nickname = None

    @nickname.expression
    def nickname(cls):
        return cls._nickname

    @hybrid_property
    def raast_id(self) -> str:
        if self.raast_id_encrypted:
            return decrypt_data(self.raast_id_encrypted, aad=str(self.user_id))
        return self._raast_id or ""

    @raast_id.setter
    def raast_id(self, value: str):
        self.raast_id_encrypted = encrypt_data(value, aad=str(self.user_id))
        self._raast_id = None

    @raast_id.expression
    def raast_id(cls):
        return cls._raast_id

    def set_account_number(self, account_number: str):
        self.account_number_encrypted = encrypt_data(account_number, aad=str(self.user_id))
        # Masking logic
        if len(account_number) > 4:
            self.account_number_masked = "*" * (len(account_number) - 4) + account_number[-4:]
        else:
            self.account_number_masked = account_number