from uuid import UUID

from pydantic import BaseModel, field_validator

from app.core.sanitization import sanitise_field


class OtpSendRequest(BaseModel):
    phone_number: str


class OtpVerifyRequest(BaseModel):
    # user_id: int
    user_id: UUID
    otp_code: str

    @field_validator("otp_code", mode="before")
    @classmethod
    def sanitise_otp_code(cls, v):
        return sanitise_field("otp_code", v)


class OtpResponse(BaseModel):
    message: str
    expires_in_seconds: int = 60
