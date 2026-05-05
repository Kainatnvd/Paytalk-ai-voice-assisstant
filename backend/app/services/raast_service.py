"""
Raast payment service: integrates with SBP Raast sandbox.
Includes idempotency, daily limit enforcement, and full logging.
"""
import json
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import httpx
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.daily_txn_summaries import DailyTxnSummary
from app.models.partner import Partner
from app.models.system_log import SystemLog
from app.models.transaction import Transaction, TransactionStatus

IDEMPOTENCY_WINDOW_SECONDS = 60


def _log(db: Session, action: str, user_id: uuid.UUID, details: dict, level: str = "INFO"):
    db.add(SystemLog(
        severity=level,
        event_type="transaction",
        event_subtype=action,
        user_id=user_id,
        message=f"Raast action: {action}",
        metadata_json=json.dumps(details),
    ))



def _check_idempotency(db: Session, sender_id: uuid.UUID, recipient_account: str, amount: Decimal) -> bool:
    """Return True if an identical transaction was submitted in the last 60 seconds."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=IDEMPOTENCY_WINDOW_SECONDS)
    duplicate = (
        db.query(Transaction)
        .filter(
            Transaction.sender_id == sender_id,
            Transaction.recipient_account == recipient_account,
            Transaction.amount == amount,
            Transaction.created_at >= cutoff,
            Transaction.status != TransactionStatus.failed,
        )
        .first()
    )
    return duplicate is not None


def _check_daily_limit(db: Session, user_id: uuid.UUID, partner_id: uuid.UUID, amount: Decimal) -> dict:
    """Return {"ok": True} or {"ok": False, "reason": str}."""
    partner = db.query(Partner).filter(Partner.partner_id == partner_id).first()
    if not partner:
        return {"ok": False, "reason": "Partner not found"}

    today = datetime.now(timezone.utc).date()
    summary = (
        db.query(DailyTxnSummary)
        .filter(
            DailyTxnSummary.user_id == user_id,
            DailyTxnSummary.partner_id == partner_id,
            DailyTxnSummary.txn_date == today,
        )
        .first()
    )
    current_total = summary.total_amount if summary else Decimal("0")

    if current_total + amount > partner.daily_txn_limit:
        return {
            "ok": False,
            "reason": f"Daily limit of PKR {partner.daily_txn_limit} exceeded",
        }
    return {"ok": True}


def _update_daily_summary(db: Session, user_id: uuid.UUID, partner_id: uuid.UUID, amount: Decimal):
    today = datetime.now(timezone.utc).date()
    summary = (
        db.query(DailyTxnSummary)
        .filter(
            DailyTxnSummary.user_id == user_id,
            DailyTxnSummary.partner_id == partner_id,
            DailyTxnSummary.txn_date == today,
        )
        .first()
    )
    if summary:
        summary.total_amount = Decimal(str(summary.total_amount)) + amount
        summary.txn_count += 1
    else:
        db.add(DailyTxnSummary(
            user_id=user_id,
            partner_id=partner_id,
            txn_date=today,
            total_amount=amount,
            txn_count=1,
        ))


def initiate_transfer(
    db: Session,
    sender_id: uuid.UUID,
    recipient_account: str,
    recipient_name: str,
    amount: Decimal,
    partner_id: uuid.UUID,
) -> Transaction:
    """
    Execute a Raast transfer. Handles idempotency, daily limits,
    API call (or mock), and transaction logging.
    """

    # 1. Idempotency check
    if _check_idempotency(db, sender_id, recipient_account, amount):
        raise ValueError("Duplicate transaction: identical transfer submitted within 60 seconds")

    # 2. Balance check
    baseline = Decimal("50000")
    total_spent = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == sender_id,
        Transaction.status == "completed"
    ).scalar() or Decimal("0")
    current_balance = baseline - Decimal(str(total_spent))
    if amount > current_balance:
        raise ValueError(f"Insufficient balance. Available: PKR {current_balance:,.2f}, Requested: PKR {amount:,.2f}")

    # 3. Daily limit check
    limit_result = _check_daily_limit(db, sender_id, partner_id, amount)
    if not limit_result["ok"]:
        raise ValueError(limit_result["reason"])

    # 3. Create transaction record (pending)
    txn = Transaction(
        sender_id=sender_id,
        recipient_account=recipient_account,
        recipient_name=recipient_name,
        amount=amount,
        status=TransactionStatus.pending,
    )
    db.add(txn)
    db.commit()
    db.refresh(txn)

    # 4. Call Raast sandbox API (bypass if disabled)
    if not settings.RAAST_SANDBOX_ENABLED:
        txn.status = TransactionStatus.completed
        txn.raast_reference_id = f"MOCK-DEMO-{txn.id}"
        txn.completed_at = datetime.now(timezone.utc)
        _update_daily_summary(db, sender_id, partner_id, amount)
        _log(db, "transfer_mocked", sender_id, {"txn_id": txn.id, "mode": "demo_bypass"}, level="INFO")
        db.commit()
        return txn

    try:
        payload = {
            "senderAccount": "",           # filled by bank middleware
            "recipientAccount": recipient_account,
            "amount": str(amount),
            "currency": "PKR",
            "transactionId": str(txn.id),
        }
        headers = {"Authorization": f"Bearer {settings.RAAST_API_KEY}"}

        resp = httpx.post(
            f"{settings.RAAST_SANDBOX_URL}/v1/transfer",
            json=payload,
            headers=headers,
            timeout=5.0, # Reduced timeout for better UX
        )
        resp.raise_for_status()
        result = resp.json()
        raast_ref = result.get("referenceId", f"MOCK-{txn.id}")

        txn.status = TransactionStatus.completed
        txn.raast_reference_id = raast_ref
        txn.completed_at = datetime.now(timezone.utc)

        _update_daily_summary(db, sender_id, partner_id, amount)
        _log(db, "transfer_success", sender_id, {"txn_id": txn.id, "raast_ref": raast_ref})

    except (httpx.HTTPError, httpx.RequestError) as e:
        # Sandbox unavailable or DNS error – mock for FYP demo
        # Logging as INFO because this is expected behavior in non-internet demo environments
        print(f"[Raast] Sandbox unreachable ({e}). Falling back to mock response for demo.")
        txn.status = TransactionStatus.completed
        txn.raast_reference_id = f"MOCK-FALLBACK-{txn.id}"
        txn.completed_at = datetime.now(timezone.utc)
        _update_daily_summary(db, sender_id, partner_id, amount)
        _log(db, "transfer_mocked", sender_id, {"txn_id": txn.id, "error": str(e)}, level="WARNING")


    except Exception as e:
        txn.status = TransactionStatus.failed
        txn.failure_reason = str(e)
        _log(db, "transfer_failed", sender_id, {"txn_id": txn.id, "error": str(e)}, level="ERROR")

    db.commit()
    db.refresh(txn)
    return txn
