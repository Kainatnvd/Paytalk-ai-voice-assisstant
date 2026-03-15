# from sqlalchemy import Column, DateTime, Integer, String, Text, func

# from app.database.base import Base


# class SystemLog(Base):
#     __tablename__ = "system_logs"

#     id = Column(Integer, primary_key=True, index=True)
#     log_level = Column(String(10), default="INFO")   # DEBUG | INFO | WARNING | ERROR
#     service = Column(String(100), nullable=False)    # e.g. 'raast_service', 'otp_service'
#     action = Column(String(200), nullable=False)
#     user_id = Column(Integer, nullable=True)
#     details = Column(Text, nullable=True)            # JSON payload / error message
#     ip_address = Column(String(45), nullable=True)
#     created_at = Column(DateTime(timezone=True), server_default=func.now())
from sqlalchemy import Column, DateTime, Integer, String, Text, func
from app.database.base import Base

class SystemLog(Base):
    __tablename__ = "system_logs"

    id             = Column(Integer, primary_key=True, index=True)   # BIGSERIAL in schema, Integer is fine for SQLAlchemy
    partner_id     = Column(Integer, nullable=True)                  # no FK — log preserved if partner deleted
    user_id        = Column(Integer, nullable=True)                  # no FK — log preserved if user purged
    admin_user_id  = Column(Integer, nullable=True)                  # no FK
    event_type     = Column(String(50), nullable=False)
    # valid: voice_command|auth_attempt|auth_success|auth_failure|transaction|admin_action|api_error|system_event
    event_subtype  = Column(String(50), nullable=True)
    reference_id   = Column(Integer, nullable=True)                  # UUID of related entity
    reference_type = Column(String(50), nullable=True)               # e.g. 'transaction', 'session'
    severity       = Column(String(10), nullable=False, default="INFO")  # INFO|WARN|ERROR|CRITICAL
    message        = Column(Text, nullable=False)                    # never store raw PII here
    metadata_json  = Column(Text, nullable=True)                     # JSON, also PII-free
    ip_address     = Column(String(45), nullable=True)
    created_at     = Column(DateTime(timezone=True), server_default=func.now())