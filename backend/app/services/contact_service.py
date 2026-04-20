"""
Contact matching service using RapidFuzz for fuzzy name resolution.

Tiered strategy:
  90%+      → high confidence, auto-match
  70-89%    → low confidence, return top 3 candidates
  below 70% → not found
"""
from typing import List
from rapidfuzz import process, fuzz
from sqlalchemy.orm import Session

from app.models.contacts import Contact

HIGH_CONFIDENCE = 90   # auto-match threshold
LOW_CONFIDENCE  = 70   # minimum to show candidates


def get_user_contacts(db: Session, user_id: int) -> List[Contact]:
    """Fetch all saved beneficiaries for a user. Auto-seed missing ones."""
    contacts = db.query(Contact).filter(Contact.user_id == user_id).all()
    
    # Required demo contacts for testing
    demo_contacts_data = [
        {"full_name": "Cafe", "account_number_masked": "****1111", "bank_name": "HBL"},
        {"full_name": "Coffee Shop", "account_number_masked": "****2222", "bank_name": "Meezan"},
        {"full_name": "Tailor", "account_number_masked": "****3333", "bank_name": "Alfalah"},
        {"full_name": "School Fees", "account_number_masked": "****4444", "bank_name": "Allied"},
        {"full_name": "Electricity Bill", "account_number_masked": "****5555", "bank_name": "KE"},
        {"full_name": "Water Bill", "account_number_masked": "****8888", "bank_name": "KW&SB"},
        {"full_name": "Gas Bill", "account_number_masked": "****9999", "bank_name": "SSGC"},
        {"full_name": "Ali", "account_number_masked": "****6666", "bank_name": "JazzCash"},
        {"full_name": "Farzam", "account_number_masked": "****0000", "bank_name": "UBL"},
        {"full_name": "Ahmed", "account_number_masked": "****7777", "bank_name": "Easypaisa"},
    ]
    
    existing_names = {c.full_name for c in contacts}
    missing_contacts = []
    
    for c_data in demo_contacts_data:
        if c_data["full_name"] not in existing_names:
            missing_contacts.append(Contact(user_id=user_id, **c_data))
            
    if missing_contacts:
        db.add_all(missing_contacts)
        db.commit()
        # Re-fetch after adding
        contacts = db.query(Contact).filter(Contact.user_id == user_id).all()
        
    return contacts


def match_contact(query_name: str, contacts: List[Contact]) -> dict:
    """
    Fuzzy-match a spoken name against the user's contact list.

    Returns:
        {
            "matched": bool,
            "confidence": "high" | "low" | None,
            "contact": Contact | None,       # set when confidence == "high"
            "candidates": [Contact, ...]     # set when confidence == "low"
            "score": float
        }
    """
    if not contacts:
        return {"matched": False, "confidence": None, "contact": None, "candidates": [], "score": 0.0}

    query_lower = query_name.strip().lower()

    # Score against full_name AND nickname, take the best
    scored = []
    for contact in contacts:
        name_score = fuzz.token_set_ratio(query_lower, contact.full_name.lower())
        nick_score = fuzz.token_set_ratio(query_lower, contact.nickname.lower()) if contact.nickname else 0
        best = max(name_score, nick_score)
        scored.append((contact, best))

    scored.sort(key=lambda x: x[1], reverse=True)
    best_contact, best_score = scored[0]

    # Tier 1: 90%+ — auto match
    if best_score >= HIGH_CONFIDENCE:
        return {
            "matched": True,
            "confidence": "high",
            "contact": best_contact,
            "candidates": [],
            "score": round(best_score, 2),
        }

    # Tier 2: 70-89% — show top 3
    candidates = [c for c, s in scored if s >= LOW_CONFIDENCE][:3]
    if candidates:
        return {
            "matched": True,
            "confidence": "low",
            "contact": None,
            "candidates": candidates,
            "score": round(best_score, 2),
        }

    # Tier 3: below 70% — not found
    return {"matched": False, "confidence": None, "contact": None, "candidates": [], "score": round(best_score, 2)}


def find_contact_for_user(db: Session, user_id, query_name: str) -> dict:
    """Convenience: fetch contacts then match."""
    contacts = get_user_contacts(db, user_id)
    return match_contact(query_name, contacts)