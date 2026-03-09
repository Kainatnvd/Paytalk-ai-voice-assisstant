from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, Numeric, func

from app.database.base import Base


class DailyTxnSummary(Base):
    """Tracks total daily spend per user for limit enforcement."""
    __tablename__ = "daily_txn_summaries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    partner_id = Column(Integer, ForeignKey("partners.id"), nullable=False)
    txn_date = Column(Date, nullable=False)
    total_amount = Column(Numeric(15, 2), default=0.00)
    txn_count = Column(Integer, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
