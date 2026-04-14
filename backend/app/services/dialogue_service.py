"""
Dialogue state machine.
States: IDLE → AWAITING_CONFIRMATION → AWAITING_OTP → EXECUTING → COMPLETE
Stored per session in auth_sessions.dialogue_state / pending_action.
"""
import json
from typing import Optional

from sqlalchemy.orm import Session

from app.models.auth_session import AuthSession

VALID_STATES = {"IDLE", "AWAITING_CONFIRMATION", "AWAITING_OTP", "EXECUTING", "COMPLETE"}


def get_state(db: Session, session_id: int) -> dict:
    session = db.query(AuthSession).filter(AuthSession.id == session_id).first()
    if not session:
        return {"state": "IDLE", "pending_action": None}
    pending = json.loads(session.pending_action) if session.pending_action else None
    return {"state": session.dialogue_state or "IDLE", "pending_action": pending}
  

def set_state(db: Session, session_id: int, state: str, pending_action: Optional[dict] = None):
    if state not in VALID_STATES:
        raise ValueError(f"Invalid dialogue state: {state}")
    session = db.query(AuthSession).filter(AuthSession.id == session_id).first()
    if not session:
        return
    session.dialogue_state = state
    session.pending_action = json.dumps(pending_action) if pending_action else None
    db.commit()


def reset_state(db: Session, session_id: int):
    """Return to IDLE and clear any pending action (e.g. user said 'cancel')."""
    set_state(db, session_id, "IDLE", None)
