from sqlalchemy import Column, DateTime, Integer, String, Text, func

from app.database.base import Base


class SystemLog(Base):
    __tablename__ = "system_logs"

    id = Column(Integer, primary_key=True, index=True)
    log_level = Column(String(10), default="INFO")   # DEBUG | INFO | WARNING | ERROR
    service = Column(String(100), nullable=False)    # e.g. 'raast_service', 'otp_service'
    action = Column(String(200), nullable=False)
    user_id = Column(Integer, nullable=True)
    details = Column(Text, nullable=True)            # JSON payload / error message
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
