import uuid
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, Integer, Numeric, String, func

from app.database.base import Base


class Partner(Base):
    __tablename__ = "partners"

    # id = Column(Integer, primary_key=True, index=True)
    partner_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(200), nullable=False)
    partner_code = Column(String(50), unique=True, nullable=False)
    contact_email = Column(String(255), nullable=True)
    daily_txn_limit = Column(Numeric(15, 2), default=500000.00)  # PKR
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
