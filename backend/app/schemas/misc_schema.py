from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, field_validator
from uuid import UUID

from app.core.sanitization import sanitise_field


# ─── Voice ────────────────────────────────────────────────────────────────────

class VoiceProcessResponse(BaseModel):
    transcription: str
    language: Optional[str]
    intent: Optional[str]
    confidence: Optional[float]
    entities: Optional[Dict[str, Any]]
    response_text: str
    response_audio: Optional[str]   # base64-encoded MP3
    session_id: Union[int, UUID, str]
    processing_time_ms: int
    dialogue_state: Optional[str] = "IDLE"
    pending_action: Optional[Dict[str, Any]] = None
    payload: Optional[Dict[str, Any]] = None


class TextInputRequest(BaseModel):
    text: str
    nonce: str


# ─── NFC ──────────────────────────────────────────────────────────────────────

class NfcVerifyRequest(BaseModel):
    cnic_hash: str                  # SHA-256 hex from NFC scan
    user_id: UUID
    device_info: Optional[str] = None

    @field_validator("device_info", mode="before")
    @classmethod
    def sanitise_device_info(cls, v):
        if v is not None:
            return sanitise_field("device_info", v)
        return v


class NfcVerifyResponse(BaseModel):
    matched: bool
    message: str


class NfcMockRequest(BaseModel):
    cnic: str                       # Plain CNIC for mock NADRA lookup
    user_id: UUID


# ─── Admin ────────────────────────────────────────────────────────────────────

class SdkKeyCreateRequest(BaseModel):
    partner_id: int
    label: Optional[str] = "Default"

    @field_validator("label", mode="before")
    @classmethod
    def sanitise_label(cls, v):
        if v is not None:
            return sanitise_field("label", v)
        return v


class SdkKeyResponse(BaseModel):
    id: int
    partner_id: int
    api_key: str
    label: Optional[str]
    is_active: bool

    model_config = {"from_attributes": True}


class AdminUserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: str
    is_active: bool

    model_config = {"from_attributes": True}
