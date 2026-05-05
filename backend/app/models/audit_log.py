import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID

from app.database.base import Base

class AuditLog(Base):
    """
    Immutable Write-Once Audit Log.
    Used for security tracking, authentication events, and anomaly detection.
    Database triggers should prevent UPDATE and DELETE operations on this table.
    """
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Event Context
    event_type = Column(String(100), nullable=False, index=True) # e.g., "OTP_FAILED", "LOGIN_SUCCESS", "RATE_LIMIT_EXCEEDED"
    severity = Column(String(20), default="INFO", nullable=False) # INFO, WARNING, CRITICAL
    
    # Subject
    user_id = Column(UUID(as_uuid=True), nullable=True, index=True)
    ip_address = Column(String(50), nullable=True)
    
    # Payload
    details = Column(Text, nullable=True)
