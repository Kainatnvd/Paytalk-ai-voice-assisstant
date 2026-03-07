from typing import Any, Dict, List, Optional
from pydantic import BaseModel


# ─── Voice ────────────────────────────────────────────────────────────────────

class VoiceProcessResponse(BaseModel):
    transcription: str
    language: Optional[str]
    intent: Optional[str]
    confidence: Optional[float]
    entities: Optional[Dict[str, Any]]
    response_text: str
    response_audio: Optional[str]   # base64-encoded MP3
    session_id: int
    processing_time_ms: int


# ─── NFC ──────────────────────────────────────────────────────────────────────

class NfcVerifyRequest(BaseModel):
    cnic_hash: str                  # SHA-256 hex from NFC scan
    user_id: int
    device_info: Optional[str] = None


class NfcVerifyResponse(BaseModel):
    matched: bool
    message: str


class NfcMockRequest(BaseModel):
    cnic: str                       # Plain CNIC for mock NADRA lookup
    user_id: int


# ─── Admin ────────────────────────────────────────────────────────────────────

class SdkKeyCreateRequest(BaseModel):
    partner_id: int
    label: Optional[str] = "Default"


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
