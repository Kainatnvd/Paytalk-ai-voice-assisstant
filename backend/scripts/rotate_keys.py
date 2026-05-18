import os
import sys

# Add backend dir to path so we can import app modules
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.database.database import SessionLocal
from app.models.user import User
from app.core.security import decrypt_cnic, encrypt_cnic
from app.core.secrets_manager import secrets_manager

def rotate_aes_keys():
    """
    Reads all users from the database, decrypts their CNIC using whatever key
    is valid (from the secrets manager's list of all keys), and re-encrypts
    it using the newly designated 'active' AES key.
    
    Before running this:
    1. Add the new AES key to .secrets.json with status="active"
    2. Change the old key's status to "deprecated"
    """
    print(f"[*] Starting AES key rotation...")
    print(f"[*] Active AES key starts with: {secrets_manager.get_active_aes_key()[:5]}...")
    print(f"[*] Total keys available for decryption: {len(secrets_manager.get_all_aes_keys())}")
    
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"[*] Found {len(users)} users to process.")
        
        success_count = 0
        fail_count = 0
        
        for user in users:
            if not user.cnic_encrypted:
                continue
                
            try:
                # 1. Decrypt using any valid key in the keyring
                plain_cnic = decrypt_cnic(user.cnic_encrypted)
                
                # 2. Re-encrypt using the single active key
                new_encrypted = encrypt_cnic(plain_cnic)
                
                # 3. Save back
                user.cnic_encrypted = new_encrypted
                success_count += 1
                
            except ValueError as e:
                print(f"[!] Failed to decrypt CNIC for user {user.user_id}: {e}")
                fail_count += 1
                
        db.commit()
        print(f"[*] Key rotation complete!")
        print(f"    - Successfully re-encrypted: {success_count}")
        print(f"    - Failed: {fail_count}")
        
    finally:
        db.close()

if __name__ == "__main__":
    rotate_aes_keys()
