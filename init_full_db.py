import sys
import os
import uuid
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app.database.base import Base
from app.database.database import engine, SessionLocal
import app.models  # Ensure all models are loaded for metadata

def init_db():
    print("Initializing database schema...")
    # This will create tables if they don't exist
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        # Enforce write-once policy on audit_logs using Postgres Rules
        from sqlalchemy import text
        try:
            db.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto;"))
            db.execute(text("CREATE RULE prevent_audit_log_delete AS ON DELETE TO audit_logs DO INSTEAD NOTHING;"))
            db.execute(text("CREATE RULE prevent_audit_log_update AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;"))
            db.commit()
            print("Enabled pgcrypto and enforced immutable rules on audit_logs table.")
        except Exception as rule_err:
            db.rollback()
            # Rules might already exist, so we ignore the error
            print(f"(Note: immutable rules may already exist or DB isn't Postgres: {rule_err})")
        
        # 1. Create Partner if not exists
        partner = db.query(app.models.Partner).first()
        if not partner:
            print("Creating default partner...")
            partner = app.models.Partner(
                partner_id=uuid.uuid4(),
                name="PayTalk Demo Bank",
                partner_code="PAYTALK_DEMO",
                is_active=True
            )
            db.add(partner)
            db.commit()
            db.refresh(partner)
        
        # 2. Create Test User if not exists
        from app.core.security import hash_password, hash_cnic, encrypt_cnic
        phone = "03001234567"
        user = db.query(app.models.User).filter(app.models.User.phone_number == phone).first()
        if not user:
            print(f"Creating test user {phone}...")
            user = app.models.User(
                user_id=uuid.uuid4(),
                partner_id=partner.partner_id,
                phone_number=phone,
                full_name="Faraz Hashmi",
                password_hash=hash_password("password123"),
                account_number="PK12PAYT00000001",
                cnic_hash=hash_cnic("4210112345678"),
                cnic_encrypted=encrypt_cnic("4210112345678"),
                is_active=True,
                preferred_language="en",
                voice_consent_given=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            print("User created successfully!")
        else:
            print(f"User {phone} already exists.")
            
        # 3. Seed some transactions if empty
        tx_count = db.query(app.models.Transaction).filter(app.models.Transaction.sender_id == user.user_id).count()
        if tx_count == 0:
            print("Seeding transaction history...")
            from app.models.transaction import TransactionStatus
            txs = [
                app.models.Transaction(
                    sender_id=user.user_id,
                    recipient_account="PK12MEZN12345678",
                    recipient_name="Coffee Shop",
                    amount=Decimal("450.00"),
                    currency="PKR",
                    status=TransactionStatus.completed,
                    initiated_via="api"
                ),
                app.models.Transaction(
                    sender_id=user.user_id,
                    recipient_account="PK12HBL00987654",
                    recipient_name="Electricity Bill",
                    amount=Decimal("12500.00"),
                    currency="PKR",
                    status=TransactionStatus.completed,
                    initiated_via="voice"
                )
            ]
            db.add_all(txs)
            
            # Seed contacts
            contacts = [
                app.models.Contact(user_id=user.user_id, full_name="Cafe", account_number_masked="****1111", bank_name="HBL"),
                app.models.Contact(user_id=user.user_id, full_name="Tailor", account_number_masked="****3333", bank_name="Alfalah")
            ]
            db.add_all(contacts)
            db.commit()
            print("Seeding complete.")
            
        print("\n--- DATABASE READY ---")
        print(f"Phone: {phone}")
        print("Password: password123")
        
    except Exception as e:
        print(f"Error during init: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_db()
