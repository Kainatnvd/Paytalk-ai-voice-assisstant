from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel
from uuid import UUID


class TransferRequest(BaseModel):
    recipient_name_query: str       # Fuzzy matched against contacts
    amount: Decimal
    note: Optional[str] = None


class TransactionResponse(BaseModel):
    id: int
    sender_id: UUID
    recipient_account: str
    recipient_name: Optional[str]
    amount: Decimal
    currency: str
    status: str
    raast_reference_id: Optional[str]
    failure_reason: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
