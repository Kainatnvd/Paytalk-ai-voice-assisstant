# Import all models here so Alembic can discover them via Base.metadata
from app.models.user import User
from app.models.transaction import Transaction
from app.models.otp import OtpRequest
from app.models.auth_session import AuthSession
from app.models.partner import Partner
from app.models.beneficiary import Beneficiary
from app.models.voice_command import VoiceCommand
from app.models.nfc_verification import NfcVerification
from app.models.nlu_intent import NluIntent
from app.models.sdk_api_key import SdkApiKey
from app.models.system_log import SystemLog
from app.models.admin_user import AdminUser
from app.models.daily_txn_summary import DailyTxnSummary

__all__ = [
    "User", "Transaction", "OtpRequest", "AuthSession",
    "Partner", "Beneficiary", "VoiceCommand", "NfcVerification",
    "NluIntent", "SdkApiKey", "SystemLog", "AdminUser", "DailyTxnSummary",
]