"""
Contact matching service using RapidFuzz for fuzzy name resolution.
"""
from typing import List, Optional
from rapidfuzz import process, fuzz
from sqlalchemy.orm import Session

from app.models.contacts import Contact

MATCH_THRESHOLD = 75  # minimum similarity score (0-100)


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
