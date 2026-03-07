"""
NLU service: calls Rasa /model/parse and returns intent + entities.
Falls back to keyword matching if Rasa is unreachable.
"""
import re
from typing import Any, Dict, Optional

import httpx

from app.core.config import settings

RASA_PARSE_URL = f"{settings.RASA_URL}/model/parse"

# ── Keyword fallback patterns ──────────────────────────────────────────────────
_KEYWORD_RULES = [
    ("check_balance",       r"balance|paisa|kitna|baqi|remaining"),
    ("transfer_money",      r"bhejo|send|transfer|bhejna|payment"),
    ("transaction_history", r"history|transactions?|tarikh|details?"),
    ("confirm",             r"\b(haan|yes|theek|ok|okay|confirm|bilkul)\b"),
    ("cancel",              r"\b(nahi|no|cancel|band|rukk|mat karo|stop)\b"),
    ("get_account_info",    r"account.*(number|detail)|number.*account"),
]


def _keyword_classify(text: str) -> Dict[str, Any]:
    """Simple regex-based intent classification for offline fallback."""
    lower = text.lower()
    for intent, pattern in _KEYWORD_RULES:
        if re.search(pattern, lower):
            return {"intent": intent, "confidence": 0.60, "entities": {}}
    return {"intent": "unknown", "confidence": 0.0, "entities": {}}


def classify_intent(text: str) -> Dict[str, Any]:
    """
    Call Rasa to classify intent and extract entities.

    Returns:
        {
            "intent": str,
            "confidence": float,
            "entities": {entity_name: value, ...}
        }
    """
    try:
        resp = httpx.post(
            RASA_PARSE_URL,
            json={"text": text},
            timeout=5.0,
        )
        resp.raise_for_status()
        data = resp.json()

        intent = data.get("intent", {})
        entities_raw = data.get("entities", [])

        # Convert list of entity dicts to {name: value} map
        entities = {e["entity"]: e["value"] for e in entities_raw}

        return {
            "intent": intent.get("name", "unknown"),
            "confidence": round(intent.get("confidence", 0.0), 4),
            "entities": entities,
        }

    except Exception as e:
        print(f"[NLU] Rasa unreachable ({e}), falling back to keyword matching.")
        return _keyword_classify(text)
