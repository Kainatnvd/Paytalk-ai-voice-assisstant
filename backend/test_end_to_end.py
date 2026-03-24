import requests
from app.database.database import SessionLocal
from app.models.partner import Partner
import uuid

db = SessionLocal()

# Create a test partner if none exists
test_partner = db.query(Partner).filter(Partner.partner_code == "TEST_PARTNER_01").first()
if not test_partner:
    test_partner = Partner(
        name="Test Partner",
        partner_code="TEST_PARTNER_01",
        contact_email="partner@test.com"
    )
    db.add(test_partner)
    db.commit()
    db.refresh(test_partner)

partner_id = str(test_partner.partner_id)
print(f"Using Partner ID: {partner_id}")

# 2. Test Registration API
url_register = "http://127.0.0.1:8000/auth/register"
payload_register = {
    "full_name": "Test EndToEnd User",
    "phone_number": "03009999999",
    "email": "test99@example.com",
    "password": "SecurePassword123!",
    "cnic": "12345-9999999-9",
    "partner_id": partner_id
}

print("Testing /auth/register...")
res_reg = requests.post(url_register, json=payload_register)
if res_reg.status_code == 201:
    print("SUCCESS: Registered User =>", res_reg.json())
elif res_reg.status_code == 409:
    print("User already exists, proceeding to login...")
else:
    print("FAILED:", res_reg.status_code, res_reg.text)

# 3. Test Login API (Optional, if UserLoginRequest expects a password)
url_login = "http://127.0.0.1:8000/auth/login"
payload_login = {
    "phone_number": "03009999999",
    "password": "SecurePassword123!"
}

print("\nTesting /auth/login...")
res_login = requests.post(url_login, json=payload_login)
if res_login.status_code == 200:
    token = res_login.json().get("access_token")
    print("SUCCESS: Logged In! Token =>", token[:30], "...")
    
    # 4. Test Authenticated Route (e.g., viewing a transaction or mocking one)
    # We will just try to hit a protected route, e.g. /transaction/1
    print("\nTesting Authenticated Route (GET /transaction/99999)...")
    headers = {
        "Authorization": f"Bearer {token}"
    }
    res_txn = requests.get("http://127.0.0.1:8000/transaction/99999", headers=headers)
    if res_txn.status_code == 404:
        print("SUCCESS (Auth Working): Transaction not found (which means auth succeeded!)")
    else:
        print("RESPONSE:", res_txn.status_code, res_txn.text)
else:
    print("FAILED:", res_login.status_code, res_login.text)
