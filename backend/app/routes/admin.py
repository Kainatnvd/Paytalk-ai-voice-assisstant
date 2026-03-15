"""Admin routes: /admin/*"""
import secrets
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.database.database import get_db
from app.models.sdk_api_key import SdkApiKey
from app.models.system_log import SystemLog
from app.models.user import User
from app.schemas.misc_schema import AdminUserResponse, SdkKeyCreateRequest, SdkKeyResponse

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/logs")
def get_logs(
    limit: int = Query(50, ge=1, le=200),
    service: str = Query(None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Fetch recent system logs, optionally filtered by service name."""
    query = db.query(SystemLog).order_by(SystemLog.created_at.desc())
    if service:
        query = query.filter(SystemLog.service == service)
    return query.limit(limit).all()


@router.post("/sdk-keys", response_model=SdkKeyResponse, status_code=201)
def create_sdk_key(
    payload: SdkKeyCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Generate a new SDK API key for a partner."""
    api_key = "ptk_" + secrets.token_hex(32)   # 68-char key
    record = SdkApiKey(
        partner_id=payload.partner_id,
        api_key=api_key,
        label=payload.label,
        created_by=current_user.user_id,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("/users", response_model=List[AdminUserResponse])
def list_users(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """List registered users (admin only). CNIC is never returned."""
    return db.query(User).order_by(User.created_at.desc()).limit(limit).all()
