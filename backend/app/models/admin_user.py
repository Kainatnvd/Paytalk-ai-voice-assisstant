# from sqlalchemy import Boolean, Column, DateTime, Integer, String, func

# from app.database.base import Base


# class AdminUser(Base):
#     __tablename__ = "admin_users"

#     id = Column(Integer, primary_key=True, index=True)
#     username = Column(String(100), unique=True, nullable=False)
#     email = Column(String(255), unique=True, nullable=False)
#     password_hash = Column(String(255), nullable=False)
#     role = Column(String(50), default="admin")      # 'super_admin' | 'admin' | 'support'
#     is_active = Column(Boolean, default=True)
#     created_at = Column(DateTime(timezone=True), server_default=func.now())
#     last_login = Column(DateTime(timezone=True), nullable=True)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func
from app.database.base import Base

class AdminUser(Base):
    __tablename__ = "admin_users"

    id            = Column(Integer, primary_key=True, index=True)
    partner_id = Column(UUID(as_uuid=True), ForeignKey("partners.partner_id"), nullable=True)  # NULL = super admin
    email         = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role          = Column(String(30), nullable=False, default="partner_admin")
    # valid: super_admin | partner_admin | log_viewer | analytics_viewer
    is_active     = Column(Boolean, default=True)
    mfa_enabled   = Column(Boolean, default=True)        # NFR-017
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())
    updated_at    = Column(DateTime(timezone=True), onupdate=func.now())