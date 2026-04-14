import sys
import os

# Add backend to sys.path to allow imports from app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from app.core.security import (
        create_access_token,
        decode_access_token,
        encrypt_cnic,
        decrypt_cnic
    )
except Exception as e:
    print(f"Failed to import security modules: {e}")
    sys.exit(1)

def run_tests():
    print("====================================")
    print("    TESTING JWT FUNCTIONALITY       ")
    print("====================================")
    
    # 1. Test JWT
    test_payload = {"sub": "12345678-1234-5678-1234-567812345678", "role": "user"}
    print(f"Original Payload: {test_payload}")
    
    token, jti = create_access_token(test_payload)
    print(f"\\n[+] Generated Token: {token[:30]}...{token[-30:]}")
    print(f"[+] Generated JTI: {jti}")
    
    decoded = decode_access_token(token)
    print(f"\\n[+] Decoded Payload: {decoded}")
    if decoded.get("sub") == test_payload["sub"] and decoded.get("jti") == jti:
        print("--> \u2705 JWT Encoding & Decoding working successfully!")
    else:
        print("--> \u274c JWT Encoding/Decoding failed!")


    print("\\n====================================")
    print("    TESTING AES-256 ENCRYPTION      ")
    print("====================================")
    
    # 2. Test AES-256
    original_cnic = "12345-1234567-1".replace("-", "") # normalized CNIC
    print(f"Original CNIC to encrypt: {original_cnic}")
    
    try:
        encrypted_bytes = encrypt_cnic(original_cnic)
        print(f"\\n[+] Encrypted CNIC (hex): {encrypted_bytes.hex()}")
        print(f"[+] Encrypted length: {len(encrypted_bytes)} bytes")
        
        decrypted_cnic = decrypt_cnic(encrypted_bytes)
        print(f"\\n[+] Decrypted CNIC: {decrypted_cnic}")
        
        if original_cnic == decrypted_cnic:
            print("--> \u2705 AES-256 Encryption & Decryption working successfully!")
        else:
            print("--> \u274c AES-256 Encryption/Decryption failed!")
    except Exception as e:
         print(f"--> \u274c AES error: {e}")
         print("This sometimes happens if settings.AES_ENCRYPTION_KEY is not set or properly loaded in .env")

if __name__ == "__main__":
    run_tests()
