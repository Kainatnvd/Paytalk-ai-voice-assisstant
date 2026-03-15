from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func

from app.database.base import Base


class UserDevice(Base):
    """
    Tracks every physical device a user has registered.

    Required by:
    - REQ-009: NFC capability is device-dependent — nfc_capable flag
    - NFR-014: SSL certificate pinning per device — ssl_pin_hash
    - REQ-033: Multi-platform support (android / ios / web)

    Currently used by:
    - nfc_service.py: logs NFC scans against device_id
    - auth_session: device_id stored as string until this FK is wired up
    - security.py get_current_user: can be extended to check is_trusted

    Faraz: wire the FK from auth_sessions.device_id and
    nfc_verifications.device_id to this table in the next Alembic migration.
    """
    __tablename__ = "user_devices"

    id                 = Column(Integer, primary_key=True, index=True)
    user_id            = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False, index=True)
    device_fingerprint = Column(String(512), nullable=False)  # Hashed OS + hardware identifiers
    platform           = Column(String(20),  nullable=False)  # 'android', 'ios', 'web'
    os_version         = Column(String(50),  nullable=True)   # e.g. "Android 13", "iOS 17"
    nfc_capable        = Column(Boolean,     default=False)   # REQ-009: NFC hardware present?
    ssl_pin_hash       = Column(String(128), nullable=True)   # NFR-014: expected cert pin
    is_trusted         = Column(Boolean,     default=False)   # Admin-approved device flag
    last_seen_at       = Column(DateTime(timezone=True), nullable=True)
    registered_at      = Column(DateTime(timezone=True), server_default=func.now())
