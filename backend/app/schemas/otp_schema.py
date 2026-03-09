from pydantic import BaseModel


class OtpSendRequest(BaseModel):
    phone_number: str


class OtpVerifyRequest(BaseModel):
    user_id: int
    otp_code: str


class OtpResponse(BaseModel):
    message: str
    expires_in_seconds: int = 60
