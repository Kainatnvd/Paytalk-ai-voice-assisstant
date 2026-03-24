"""
Contact matching service using RapidFuzz for fuzzy name resolution.
"""
from typing import List, Optional
from rapidfuzz import process, fuzz
from sqlalchemy.orm import Session

from app.models.contacts import Contact

MATCH_THRESHOLD = 75  # minimum similarity score (0-100)


def get_user_contacts(db: Session, user_id: int) -> List[Contact]:
    """Fetch all saved beneficiaries for a user."""
    return db.query(Contact).filter(Contact.user_id == user_id).all()


def match_contact(query_name: str, contacts: List[Contact]) -> dict:
    """
    Fuzzy-match a spoken name against the user's beneficiary list.

    Returns:
        {
            "matched": bool,
            "contact": Contact | None,
            "confidence": float,
            "candidates": list   # top 3 if confidence < threshold
        }
    """
    if not contacts:
        return {"matched": False, "contact": None, "confidence": 0.0, "candidates": []}

    names = [c.full_name for c in contacts]
    results = process.extract(query_name, names, scorer=fuzz.WRatio, limit=3)

    if not results:
        return {"matched": False, "contact": None, "confidence": 0.0, "candidates": []}

    best_name, best_score, best_idx = results[0]

    if best_score >= MATCH_THRESHOLD:
        matched_contact = contacts[best_idx]
        return {
            "matched": True,
            "contact": matched_contact,
            "confidence": round(best_score, 2),
            "candidates": [],
        }

    # Below threshold – return top 3 for user to pick
    candidates = [
        {"name": r[0], "confidence": round(r[1], 2), "index": r[2]}
        for r in results
    ]
    return {
        "matched": False,
        "contact": None,
        "confidence": round(best_score, 2),
        "candidates": candidates,
    }


def find_contact_for_user(db: Session, user_id: int, query_name: str) -> dict:
    """Convenience: fetch contacts then match."""
    contacts = get_user_contacts(db, user_id)
    return match_contact(query_name, contacts)
