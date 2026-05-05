import sys
import os
import uuid
from sqlalchemy.orm import Session
from decimal import Decimal

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.database import SessionLocal
from app.models.user import User
from app.models.partner import Partner
from app.models.transaction import Transaction, TransactionStatus
from app.core.security import hash_password, hash_cnic, encrypt_cnic

def create_test_user():
    db = SessionLocal()
    try:
        # 1. Get Partner
        partner = db.query(Partner).first()
        if not partner:
            print("No partner found. Please run create_partner.py first.")
            return

        # 2. Check existing
        phone = "03001234567"
        existing = db.query(User).filter(User.phone_number == phone).first()
        if existing:
            print(f"User with {phone} already exists!")
            u_id = existing.user_id
        else:
            # 3. Create User
            print(f"Creating test user with phone: {phone}...")
            u_id = uuid.uuid4()
            user = User(
                user_id=u_id,
                partner_id=partner.partner_id,
                email="faraz@example.com",
                password_hash=hash_password("password123"),
                account_number="PK12PAYT00000001",
                is_active=True,
                preferred_language="en",
                voice_consent_given=True
            )
            # Use encrypted setters
            user.full_name = "Faraz Hashmi"
            user.phone_number = phone
            user.set_cnic("4210112345678")
            
            db.add(user)

            db.commit()
            print(f"Successfully created test user!")

        # 4. Add some transaction history
        print("Seeding transaction history...")
        
        # Check if already seeded
        existing_tx = db.query(Transaction).filter(Transaction.sender_id == u_id).first()
        if existing_tx:
            print("Transactions already seeded for this user. Skipping.")
        else:
            tx1 = Transaction(
                sender_id=u_id,
                recipient_account="PK12MEZN12345678",
                recipient_name="Coffee Shop",
                amount=Decimal("450.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="api"
            )
            tx2 = Transaction(
                sender_id=u_id,
                recipient_account="PK12HBL00987654",
                recipient_name="Electricity Bill",
                amount=Decimal("12500.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="voice"
            )
            tx3 = Transaction(
                sender_id=u_id,
                recipient_account="PK12ALLD33445566",
                recipient_name="Tailor",
                amount=Decimal("500.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="voice"
            )
            tx4 = Transaction(
                sender_id=u_id,
                recipient_account="PK12SCHL99887766",
                recipient_name="School Fees",
                amount=Decimal("15000.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="api"
            )
            tx5 = Transaction(
                sender_id=u_id,
                recipient_account="PK12WTRB11223344",
                recipient_name="Water Bill",
                amount=Decimal("1200.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="voice"
            )
            tx6 = Transaction(
                sender_id=u_id,
                recipient_account="PK12GASB55667788",
                recipient_name="Gas Bill",
                amount=Decimal("3500.00"),
                currency="PKR",
                status=TransactionStatus.completed,
                initiated_via="voice"
            )
            db.add_all([tx1, tx2, tx3, tx4, tx5, tx6])
            db.commit()
            print(f"Successfully seeded transactions!")
        print(f"User ID: {u_id}")
        print(f"Phone: {phone}")
        print(f"Password: password123")
        print(f"Balance (Mocked): 25,000 PKR")
        
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    create_test_user()
