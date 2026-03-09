from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, func
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
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    recipient_account = Column(String(50), nullable=False)
    recipient_name = Column(String(200), nullable=True)
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