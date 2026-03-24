"""Account routes: /account/*"""
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.database.database import get_db
from app.models.transaction import Transaction
from app.schemas.transaction_schema import TransactionResponse
from app.schemas.user_schema import UserResponse

router = APIRouter(prefix="/account", tags=["Account"])


@router.get("/balance")
def get_balance(current_user=Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Fetch account balance.
    In production this calls the partner bank's core banking API.
    For FYP demo, returns a mocked balance.
    """
    # TODO: Replace with real bank API call via partner integration
    mock_balance = "25,000.00"
    return {
        "account_number": current_user.account_number or "0000-0000000-0",
        "balance": mock_balance,
        "currency": "PKR",
        "owner": current_user.full_name,
    }


@router.get("/history", response_model=List[TransactionResponse])
def get_history(
    limit: int = Query(10, ge=1, le=50),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the last N transactions for the authenticated user."""
    transactions = (
        db.query(Transaction)
        .filter(Transaction.sender_id == current_user.user_id)
        .order_by(Transaction.created_at.desc())
        .limit(limit)
        .all()
    )
    return transactions


@router.get("/info", response_model=UserResponse)
def get_account_info(current_user=Depends(get_current_user)):
    """Return basic account and user details. CNIC is never included."""
    return current_user
