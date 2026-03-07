from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/paytalk_db"

    # JWT
    SECRET_KEY: str = "change_this_to_a_64_char_hex_string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # AES Encryption for CNIC
    AES_ENCRYPTION_KEY: str = "change_this_32_byte_key_here!!!!"  # exactly 32 bytes

    # Twilio
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE_NUMBER: str = ""

    # Raast
    RAAST_SANDBOX_URL: str = "https://sandbox.raast.sbp.org.pk"
    RAAST_API_KEY: str = ""

    # Whisper
    WHISPER_MODEL_SIZE: str = "base"

    # Rasa
    RASA_URL: str = "http://localhost:5005"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
