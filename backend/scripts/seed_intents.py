"""
scripts/seed_intents.py
Seeds the nlu_intents table with all PayTalk banking intents.
Run from backend/ folder: python scripts/seed_intents.py
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database.database import SessionLocal
from app.models.nlu_intent import NluIntent

INTENTS = [
    {
        "intent_name": "check_balance",
        "description_en": "User wants to check their account balance",
        "description_ur": "صارف اپنا بیلنس چیک کرنا چاہتا ہے",
        "example_phrases": ["Balance batao", "Check my balance", "Kitna paisa hai"],
    },
    {
        "intent_name": "transfer_money",
        "description_en": "User wants to transfer money to a contact",
        "description_ur": "صارف کسی کو رقم بھیجنا چاہتا ہے",
        "example_phrases": ["Ali ko 500 bhejo", "Send 1000 to Sara", "Transfer money"],
    },
    {
        "intent_name": "transaction_history",
        "description_en": "User wants to see recent transactions",
        "description_ur": "صارف حالیہ لین دین دیکھنا چاہتا ہے",
        "example_phrases": ["Transactions dikhao", "Show history", "Recent payments"],
    },
    {
        "intent_name": "confirm",
        "description_en": "User is confirming an action",
        "description_ur": "صارف کسی عمل کی تصدیق کر رہا ہے",
        "example_phrases": ["Haan", "Yes", "Confirm", "Theek hai"],
    },
    {
        "intent_name": "cancel",
        "description_en": "User wants to cancel the current action",
        "description_ur": "صارف موجودہ عمل منسوخ کرنا چاہتا ہے",
        "example_phrases": ["Nahi", "No", "Cancel", "Rukk jao"],
    },
    {
        "intent_name": "get_account_info",
        "description_en": "User wants their account number and details",
        "description_ur": "صارف اپنا اکاؤنٹ نمبر جاننا چاہتا ہے",
        "example_phrases": ["Account number batao", "My account details"],
    },
]


def seed():
    db = SessionLocal()
    created = 0
    try:
        for intent_data in INTENTS:
            existing = db.query(NluIntent).filter(NluIntent.intent_name == intent_data["intent_name"]).first()
            if not existing:
                db.add(NluIntent(
                    intent_name=intent_data["intent_name"],
                    description_en=intent_data["description_en"],
                    description_ur=intent_data["description_ur"],
                    example_phrases=json.dumps(intent_data["example_phrases"]),
                ))
                created += 1
        db.commit()
        print(f"[Seed] {created} intents added, {len(INTENTS) - created} already existed.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
