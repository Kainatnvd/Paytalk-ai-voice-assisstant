import uuid
from sqlalchemy import Column, String, DateTime, Boolean
from datetime import datetime, timezone
from app.database.base import Base

class VoiceNonce(Base):
    """
    Tracks nonces issued for voice commands to prevent replay attacks.
    A nonce is strictly single-use and expires shortly after generation.
    """
    __tablename__ = "voice_nonces"

    nonce = Column(String(100), primary_key=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
