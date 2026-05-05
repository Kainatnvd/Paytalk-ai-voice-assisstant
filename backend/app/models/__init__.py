# Import all models here so Alembic can discover them via Base.metadata
# and generate correct migrations with: alembic revision --autogenerate

from app.models.user import User
from app.models.partner import Partner
from app.models.user_devices import UserDevice          # REQ-009 NFC device tracking
from app.models.auth_session import AuthSession
from app.models.otp import OtpRequest
from app.models.nfc_verification import NfcVerification
from app.models.contacts import Contact                # Renamed from Account — contacts list for RapidFuzz
from app.models.transaction import Transaction
from app.models.bill_payments import BillPayment        # Post-MVP — table exists, routes not yet wired
from app.models.voice_command import VoiceCommand
from app.models.nlu_intent import NluIntent
from app.models.system_log import SystemLog
from app.models.admin_user import AdminUser
from app.models.sdk_api_key import SdkApiKey
from app.models.daily_txn_summaries import DailyTxnSummary
from app.models.audit_log import AuditLog
from app.models.voice_nonce import VoiceNonce

__all__ = [
    "User",
    "Partner",
    "UserDevice",
    "AuthSession",
    "OtpRequest",
    "NfcVerification",
    "Contact",
    "Transaction",
    "BillPayment",
    "VoiceCommand",
    "NluIntent",
    "SystemLog",
    "AdminUser",
    "SdkApiKey",
    "DailyTxnSummary",
    "AuditLog",
    "VoiceNonce",
]
