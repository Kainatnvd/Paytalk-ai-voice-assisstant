from uuid import UUID

from pydantic import BaseModel


class OtpSendRequest(BaseModel):
    phone_number: str


class OtpVerifyRequest(BaseModel):
    # user_id: int
    user_id: UUID
    otp_code: str


class OtpResponse(BaseModel):
    message: str
    expires_in_seconds: int = 60
