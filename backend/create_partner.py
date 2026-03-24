import sys
import os

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.database import SessionLocal
from app.models.partner import Partner

def main():
    db = SessionLocal()
    try:
        existing_partner = db.query(Partner).first()
        if existing_partner:
            print(f"Partner already exists!")
            print(f"Partner ID: {existing_partner.partner_id}")
            print(f"Name: {existing_partner.name}")
            return
            
        print("Creating a new partner...")
        new_partner = Partner(
            name="Default Partner",
            partner_code="DEFAULT_001",
            contact_email="admin@example.com"
        )
        db.add(new_partner)
        db.commit()
        db.refresh(new_partner)
        
        print("Successfully created a new partner!")
        print(f"Partner ID: {new_partner.partner_id}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
