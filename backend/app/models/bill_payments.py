from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, Numeric, String, func

from app.database.base import Base


class BillPayment(Base):
    """
    Extended detail for bill payment transactions (Post-MVP feature, SRS §4.4).

    This is a 1:1 extension of the transactions table — only rows where
    transactions.transaction_type == 'bill_payment' will have a matching row here.

    The class-table inheritance pattern keeps the core transactions table
    clean while storing bill-specific fields (utility provider, consumer number,
    due date) separately.

    Status: Table created now so Alembic includes it in the initial migration.
    Routes and services for bill payment are Post-MVP — do not wire up yet.
    """
    __tablename__ = "bill_payments"

    id                    = Column(Integer, primary_key=True, index=True)
    transaction_id        = Column(Integer, ForeignKey("transactions.id"),
                                   unique=True, nullable=False)        # 1:1 with transactions
    bill_type             = Column(String(50),    nullable=False)      # 'electricity', 'gas', 'water', 'internet', 'phone'
    utility_provider_code = Column(String(50),    nullable=False)      # Provider ID for external utility API (REQ-027)
    consumer_number       = Column(String(100),   nullable=False)      # Customer's utility reference number
    bill_amount           = Column(Numeric(15, 2), nullable=False)     # Amount fetched from utility API (REQ-027)
    due_date              = Column(Date,           nullable=True)       # Bill due date from utility provider
    receipt_reference     = Column(String(255),    nullable=True)      # Utility provider payment receipt (REQ-029)
    created_at            = Column(DateTime(timezone=True), server_default=func.now())
