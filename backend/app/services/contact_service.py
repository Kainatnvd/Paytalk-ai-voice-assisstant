"""
Contact matching service using RapidFuzz for fuzzy name resolution.
"""
from typing import List, Optional
from rapidfuzz import process, fuzz
from sqlalchemy.orm import Session

from app.models.contacts import Contact

MATCH_THRESHOLD = 75  # minimum similarity score (0-100)


def get_user_contacts(db: Session, user_id: int) -> List[Contact]:
    """Fetch all saved beneficiaries for a user. Auto-seed if empty."""
    contacts = db.query(Contact).filter(Contact.user_id == user_id).all()
    if not contacts:
        # Retroactively inject demo contacts for older test accounts
        demo_contacts = [
            Contact(user_id=user_id, full_name="Cafe", account_number_masked="****1111", bank_name="HBL"),
            Contact(user_id=user_id, full_name="Coffee Shop", account_number_masked="****2222", bank_name="Meezan"),
            Contact(user_id=user_id, full_name="Tailor", account_number_masked="****3333", bank_name="Alfalah"),
            Contact(user_id=user_id, full_name="School", account_number_masked="****4444", bank_name="Allied"),
            Contact(user_id=user_id, full_name="Electric Bill", account_number_masked="****5555", bank_name="KE"),
            Contact(user_id=user_id, full_name="Ali", account_number_masked="****6666", bank_name="JazzCash"),
            Contact(user_id=user_id, full_name="Ahmed", account_number_masked="****7777", bank_name="Easypaisa"),
        ]
        db.add_all(demo_contacts)
        db.commit()
        return db.query(Contact).filter(Contact.user_id == user_id).all()
    return contacts


def match_contact(query_name: str, contacts: List[Contact]) -> dict:
    """
    Fuzzy-match a spoken name against the user's Contactlist.

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
