from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, func

from app.database.base import Base


class VoiceCommand(Base):
    __tablename__ = "voice_commands"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("auth_sessions.id"), nullable=True)
    audio_duration_seconds = Column(Float, nullable=True)
    transcribed_text = Column(Text, nullable=True)
    language_detected = Column(String(10), nullable=True)
    intent = Column(String(100), nullable=True)
    intent_confidence = Column(Float, nullable=True)
    entities = Column(Text, nullable=True)                  # JSON string
    response_text = Column(Text, nullable=True)
    processing_time_ms = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
