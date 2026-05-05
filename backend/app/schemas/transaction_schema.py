from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, field_validator
from uuid import UUID

from app.core.sanitization import sanitise_field


class TransferRequest(BaseModel):
    recipient_name_query: str       # Fuzzy matched against contacts
    amount: Decimal
    note: Optional[str] = None

    @field_validator("recipient_name_query", mode="before")
    @classmethod
    def sanitise_recipient_query(cls, v):
        return sanitise_field("recipient_name_query", v)

    @field_validator("note", mode="before")
    @classmethod
    def sanitise_note(cls, v):
        if v is not None:
            return sanitise_field("note", v)
        return v


class TransactionConfirmRequest(BaseModel):
    recipient_account: str
    recipient_name: str
    amount: Decimal
    otp_code: str

    @field_validator("recipient_name", mode="before")
    @classmethod
    def sanitise_recipient_name(cls, v):
        return sanitise_field("recipient_name", v)

    @field_validator("recipient_account", mode="before")
    @classmethod
    def sanitise_recipient_account(cls, v):
        return sanitise_field("recipient_account", v)

    @field_validator("otp_code", mode="before")
    @classmethod
    def sanitise_otp(cls, v):
        return sanitise_field("otp_code", v)


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
