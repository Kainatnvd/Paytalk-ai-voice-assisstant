from uuid import UUID
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator
import re

from app.core.sanitization import sanitise_field


class UserRegisterRequest(BaseModel):
    full_name: Optional[str] = None
    phone_number: str
    email: Optional[EmailStr] = None
    password: str
    pin: str
    cnic: str                           # Plain CNIC – encrypted on save, never stored raw
    partner_id: Optional[UUID] = None
    preferred_language: Optional[str] = "ur"

    @field_validator("full_name", mode="before")
    @classmethod
    def sanitise_full_name(cls, v):
        if v is not None:
            return sanitise_field("full_name", v)
        return v

    @field_validator("cnic")
    @classmethod
    def validate_cnic(cls, v: str) -> str:
        cleaned = v.replace("-", "")
        if not re.fullmatch(r"\d{13}", cleaned):
            raise ValueError("CNIC must be 13 digits (with or without dashes)")
        return cleaned

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not re.fullmatch(r"(\+92|0)?3\d{9}", v):
            raise ValueError("Phone number must be a valid Pakistani mobile number")
        return v

    @field_validator("password")
    @classmethod
    def validate_password_length(cls, v: str) -> str:
        if len(v) > 128:
            raise ValueError("Password must be at most 128 characters")
        return v

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v: str) -> str:
        if not re.fullmatch(r"\d{4}", v):
            raise ValueError("PIN must be exactly 4 digits")
        return v


class UserLoginRequest(BaseModel):
    phone_number: str
    password: str

    @field_validator("password")
    @classmethod
    def validate_password_length(cls, v: str) -> str:
        if len(v) > 128:
            raise ValueError("Password must be at most 128 characters")
        return v


class ForgotPasswordRequest(BaseModel):
    phone_number: str
    cnic: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_length(cls, v: str) -> str:
        if len(v) > 128:
            raise ValueError("Password must be at most 128 characters")
        return v


class UserResponse(BaseModel):
    user_id: UUID
    full_name: str
    phone_number: str
    email: Optional[str] = None
    account_number: Optional[str] = None
    preferred_language: str
    is_active: bool

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
