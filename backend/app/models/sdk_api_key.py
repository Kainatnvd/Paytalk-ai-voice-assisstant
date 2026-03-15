from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func

from app.database.base import Base


class SdkApiKey(Base):
    __tablename__ = "sdk_api_keys"

    id = Column(Integer, primary_key=True, index=True)
    partner_id = Column(Integer, ForeignKey("partners.id"), nullable=False, index=True)
    key_prefix = Column(String(12), nullable=False)         # e.g. 'pt_live_abc1' — shown in admin UI
    key_hash = Column(String(64), unique=True, nullable=False, index=True)  # SHA-256, never store raw
    label = Column(String(200), nullable=True)
    is_active = Column(Boolean, default=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True)
    last_used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)