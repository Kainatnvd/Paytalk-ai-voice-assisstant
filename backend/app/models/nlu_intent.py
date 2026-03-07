from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text, func

from app.database.base import Base


class NluIntent(Base):
    __tablename__ = "nlu_intents"

    id = Column(Integer, primary_key=True, index=True)
    intent_name = Column(String(100), unique=True, nullable=False)
    description_en = Column(Text, nullable=True)
    description_ur = Column(Text, nullable=True)
    example_phrases = Column(Text, nullable=True)   # JSON array of example strings
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
