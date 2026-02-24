from sqlalchemy import Column, Integer, String
from app.database.base import Base

class OTP(Base):
    __tablename__ = "otps"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, nullable=False)
    otp_code = Column(String, nullable=False)