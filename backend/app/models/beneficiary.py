from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func

from app.database.base import Base


class Beneficiary(Base):
    __tablename__ = "beneficiaries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    contact_name = Column(String(200), nullable=False)          # Friendly name for fuzzy match
    account_number = Column(String(50), nullable=False)
    bank_name = Column(String(200), nullable=True)
    is_favourite = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())