import requests
import uuid

url = "http://127.0.0.1:8000/auth/register"
payload = {
    "full_name": "Test User",
    "phone_number": "03001234567",
    "email": "test@example.com",
    "password": "Password123!",
    "cnic": "12345-1234567-1",
    "partner_id": str(uuid.uuid4())
}

response = requests.post(url, json=payload)
print("REGISTER:", response.status_code, response.text)
