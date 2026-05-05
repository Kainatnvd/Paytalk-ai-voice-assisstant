from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Integer, LargeBinary, Numeric, String, Text, func
from sqlalchemy.ext.hybrid import hybrid_property
from app.core.security import encrypt_data, decrypt_data
import enum

from app.database.base import Base


class TransactionStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"
    reversed = "reversed"


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False, index=True)
    recipient_account = Column(String(50), nullable=False)
    # Plaintext (deprecated)
    _recipient_name = Column("recipient_name", String(200), nullable=True)

    # Encrypted (AES-256-GCM)
    recipient_name_encrypted = Column(LargeBinary, nullable=True)
    note_encrypted = Column(LargeBinary, nullable=True)
    amount = Column(Numeric(15, 2), nullable=False)
    currency = Column(String(5), default="PKR")
    status = Column(Enum(TransactionStatus), default=TransactionStatus.pending)
    idempotency_key = Column(String(128), unique=True, nullable=True, index=True)  # NFR-009
    confirmed_by_user = Column(Boolean, default=False)   # BR-005: high-value confirmation
    raast_reference_id = Column(String(100), nullable=True, unique=True)
    failure_reason = Column(Text, nullable=True)
    initiated_via = Column(String(20), default="voice")  # 'voice' | 'api'
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    completed_at = Column(DateTime(timezone=True), nullable=True)

    @hybrid_property
    def recipient_name(self) -> str:
        # Check if we are an instance (not the class) to avoid Boolean error
        if hasattr(self, 'recipient_name_encrypted') and self.recipient_name_encrypted is not None:
            # Try lowercase and original UUID for AAD resilience
            try:
                return decrypt_data(self.recipient_name_encrypted, aad=str(self.sender_id).lower())
            except Exception:
                try:
                    return decrypt_data(self.recipient_name_encrypted, aad=str(self.sender_id))
                except Exception:
                    return self._recipient_name or "[Decryption Error]"
        return self._recipient_name or ""

    @recipient_name.setter
    def recipient_name(self, value: str):
        self.recipient_name_encrypted = encrypt_data(value, aad=str(self.sender_id).lower())
        self._recipient_name = None

    @hybrid_property
    def note(self) -> str:
        if hasattr(self, 'note_encrypted') and self.note_encrypted is not None:
            try:
                return decrypt_data(self.note_encrypted, aad=str(self.sender_id).lower())
            except Exception:
                try:
                    return decrypt_data(self.note_encrypted, aad=str(self.sender_id))
                except Exception:
                    return "[Decryption Error]"
        return ""

    @note.setter
    def note(self, value: str):
        self.note_encrypted = encrypt_data(value, aad=str(self.sender_id).lower())