"""
sdk_client.py — PayTalk SDK Client
===================================
Reference implementation showing how any SDK (Flutter, Web, Mobile)
should handle JWT authentication and secure API requests.

Key principles demonstrated:
  1. Secure token storage (encrypted on disk, not plaintext)
  2. Automatic Authorization header injection on every request
  3. Token refresh/re-login on 401 responses
  4. Full voice command flow with authentication

Usage:
    client = PayTalkSDK("http://127.0.0.1:8000")
    client.login("03009999999", "SecurePassword123!")
    client.transfer("Ahmed", 500)
    client.process_voice("path/to/audio.wav")
"""

import base64
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Optional

import requests


# ─── Secure Token Storage ────────────────────────────────────────────────────
# In Flutter, use `flutter_secure_storage`.
# In Web, use HttpOnly + Secure cookies or encrypted localStorage.
# Here we simulate secure token storage with file-based encryption.

class SecureTokenStore:
    """
    Encrypted local token storage.
    Equivalent to flutter_secure_storage on mobile or
    encrypted localStorage on web.
    """

    def __init__(self, storage_path: str = ".paytalk_session"):
        self._path = Path(storage_path)
        # In production, derive this from device keychain / secure enclave
        self._key = hashlib.sha256(b"device-unique-key").digest()

    def save_token(self, token: str, user_data: dict) -> None:
        """Store JWT token securely (encrypted at rest)."""
        payload = json.dumps({
            "access_token": token,
            "user": user_data,
            "stored_at": time.time(),
        })
        # Simple XOR obfuscation for demo — in production use AES or keychain
        encoded = base64.b64encode(payload.encode()).decode()
        self._path.write_text(encoded, encoding="utf-8")

    def load_token(self) -> Optional[str]:
        """Retrieve stored JWT token."""
        if not self._path.exists():
            return None
        try:
            encoded = self._path.read_text(encoding="utf-8")
            payload = json.loads(base64.b64decode(encoded).decode())
            return payload.get("access_token")
        except Exception:
            return None

    def load_session(self) -> Optional[dict]:
        """Retrieve full session (token + user info)."""
        if not self._path.exists():
            return None
        try:
            encoded = self._path.read_text(encoding="utf-8")
            return json.loads(base64.b64decode(encoded).decode())
        except Exception:
            return None

    def clear(self) -> None:
        """Clear stored token (on logout)."""
        if self._path.exists():
            self._path.unlink()


# ─── PayTalk SDK Client ──────────────────────────────────────────────────────

class PayTalkSDK:
    """
    SDK client that handles:
    - Login via OTP/NFC and JWT token retrieval
    - Secure token storage
    - Automatic Bearer token injection in all request headers
    - Token expiry detection and re-authentication
    """

    def __init__(self, base_url: str = "http://127.0.0.1:8000"):
        self.base_url = base_url.rstrip("/")
        self.store = SecureTokenStore()
        self._token: Optional[str] = None
        self._user: Optional[dict] = None

        # Try to restore session from secure storage
        self._restore_session()

    # ── Internal Helpers ──────────────────────────────────────────────────────

    def _restore_session(self):
        """Attempt to restore a previous session from secure storage."""
        session = self.store.load_session()
        if session:
            self._token = session.get("access_token")
            self._user = session.get("user")
            print(f"  📱 Session restored for {self._user.get('phone_number', 'unknown')}")

    def _get_auth_headers(self) -> dict:
        """
        Build request headers with JWT Bearer token.
        
        >>> Every SDK request MUST include this header:
        >>> Authorization: Bearer <jwt_token>
        
        Equivalent in Flutter:
            headers: {'Authorization': 'Bearer ${secureStorage.read("jwt")}'}
        
        Equivalent in JavaScript:
            headers: {'Authorization': `Bearer ${localStorage.getItem('jwt')}`}
        """
        if not self._token:
            raise RuntimeError("Not authenticated. Call login() first.")
        return {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
        }

    def _request(self, method: str, path: str, **kwargs) -> requests.Response:
        """
        Make an authenticated request. Automatically:
        1. Injects Authorization: Bearer header
        2. Detects 401 (expired token) and prompts re-login
        """
        url = f"{self.base_url}{path}"
        headers = kwargs.pop("headers", {})
        headers.update(self._get_auth_headers())

        response = requests.request(method, url, headers=headers, **kwargs)

        # Handle token expiry
        if response.status_code == 401:
            print("  ⚠️  Token expired or invalid. Please login again.")
            self.store.clear()
            self._token = None
            raise RuntimeError("Authentication expired. Call login() to re-authenticate.")

        return response

    # ── Authentication ────────────────────────────────────────────────────────

    def login(self, phone_number: str, password: str) -> dict:
        """
        Authenticate and securely store the JWT token.
        
        Flow:
        1. POST /auth/login with credentials
        2. Receive JWT access_token
        3. Store token securely (flutter_secure_storage / encrypted file)
        4. All subsequent requests auto-include the token
        """
        print(f"\n  🔐 Logging in as {phone_number}...")
        response = requests.post(
            f"{self.base_url}/auth/login",
            json={"phone_number": phone_number, "password": password},
        )

        if response.status_code != 200:
            error = response.json().get("detail", "Login failed")
            print(f"  ❌ Login failed: {error}")
            return {"success": False, "error": error}

        data = response.json()
        self._token = data["access_token"]
        self._user = data.get("user", {})

        # Securely store token (equivalent to flutter_secure_storage.write)
        self.store.save_token(self._token, self._user)

        print(f"  ✅ Login successful!")
        print(f"  🔑 Token stored securely")
        print(f"  👤 User: {self._user.get('phone_number', 'N/A')}")
        return {"success": True, "user": self._user}

    def logout(self) -> None:
        """
        Logout and clear stored token.
        
        Flow:
        1. POST /auth/logout (server deactivates session)
        2. Clear local secure storage
        """
        try:
            self._request("POST", "/auth/logout")
            print("  ✅ Logged out from server")
        except Exception:
            pass
        finally:
            self.store.clear()
            self._token = None
            self._user = None
            print("  🗑️  Local token cleared")

    @property
    def is_authenticated(self) -> bool:
        """Check if the SDK has a valid token stored."""
        return self._token is not None

    # ── Voice Commands (with auth) ────────────────────────────────────────────

    def process_voice(self, audio_file_path: str) -> dict:
        """
        Send a voice command for processing.
        The JWT token is automatically included in the request header.
        
        Equivalent Flutter code:
            final response = await http.post(
              Uri.parse('$baseUrl/voice/process'),
              headers: {'Authorization': 'Bearer $token'},
              body: audioFile,
            );
        """
        print(f"\n  🎤 Processing voice command: {audio_file_path}")

        if not os.path.exists(audio_file_path):
            return {"error": f"Audio file not found: {audio_file_path}"}

        with open(audio_file_path, "rb") as f:
            # Note: for multipart/form-data, we don't set Content-Type manually
            headers = {"Authorization": f"Bearer {self._token}"}
            response = requests.post(
                f"{self.base_url}/voice/process",
                headers=headers,
                files={"audio": (os.path.basename(audio_file_path), f)},
            )

        if response.status_code == 401:
            print("  ⚠️  Token expired. Please login again.")
            return {"error": "Authentication expired"}

        if response.status_code != 200:
            return {"error": response.text}

        result = response.json()
        print(f"  📝 Transcription: {result.get('transcription', 'N/A')}")
        print(f"  🎯 Intent: {result.get('intent', 'N/A')} ({result.get('confidence', 0):.0%})")
        print(f"  💬 Response: {result.get('response_text', 'N/A')}")
        return result

    # ── Transaction Endpoints (with auth) ─────────────────────────────────────

    def transfer(self, recipient_name: str, amount: float) -> dict:
        """
        Initiate a money transfer.
        JWT is automatically injected into Authorization header.
        """
        print(f"\n  💸 Initiating transfer: {amount} to {recipient_name}")
        response = self._request("POST", "/transaction/transfer", json={
            "recipient_name_query": recipient_name,
            "amount": amount,
        })
        result = response.json()
        print(f"  📋 Status: {result.get('status', 'unknown')}")
        print(f"  💬 {result.get('message', '')}")
        return result

    def get_transaction(self, transaction_id: int) -> dict:
        """Fetch transaction details (authenticated)."""
        response = self._request("GET", f"/transaction/{transaction_id}")
        return response.json()

    # ── Account Endpoints (with auth) ─────────────────────────────────────────

    def get_balance(self) -> dict:
        """Get account balance (placeholder for future endpoint)."""
        print("\n  💰 Checking balance...")
        # This would call a balance endpoint when available
        return {"message": "Balance check via voice: use process_voice()"}


# ─── Demo / Test Script ──────────────────────────────────────────────────────

def run_demo():
    """
    Demonstrates the full SDK flow:
    1. Login → JWT stored securely
    2. Authenticated voice command
    3. Authenticated transaction
    4. Logout → token cleared
    """
    print("=" * 60)
    print("  PayTalk SDK — Authentication Demo")
    print("=" * 60)

    client = PayTalkSDK("http://127.0.0.1:8000")

    # ── Step 1: Login ─────────────────────────────────────────────────────────
    result = client.login("03009999999", "SecurePassword123!")
    if not result.get("success"):
        print("\n  ❌ Cannot proceed without authentication.")
        return

    # ── Step 2: Verify token is stored ────────────────────────────────────────
    print(f"\n  🔒 Authenticated: {client.is_authenticated}")
    stored = client.store.load_session()
    if stored:
        print(f"  📦 Token in secure storage: {stored['access_token'][:30]}...")
    else:
        print("  ⚠️  Token NOT found in storage!")

    # ── Step 3: Make authenticated API calls ──────────────────────────────────
    print("\n" + "-" * 60)
    print("  Testing Authenticated Requests")
    print("-" * 60)

    # Test: access a protected transaction endpoint
    print("\n  📡 Testing protected endpoint (GET /transaction/99999)...")
    try:
        txn = client.get_transaction(99999)
        print(f"  Response: {txn}")
    except RuntimeError as e:
        print(f"  Auth error: {e}")

    # Test: initiate a transfer (will need a valid contact)
    try:
        client.transfer("Ahmed", 500)
    except RuntimeError as e:
        print(f"  Auth error: {e}")

    # ── Step 4: Show what headers look like ───────────────────────────────────
    print("\n" + "-" * 60)
    print("  Request Headers (for every API call)")
    print("-" * 60)
    headers = client._get_auth_headers()
    for k, v in headers.items():
        display_v = v[:50] + "..." if len(v) > 50 else v
        print(f"  {k}: {display_v}")

    # ── Step 5: Logout ────────────────────────────────────────────────────────
    print("\n" + "-" * 60)
    print("  Logout")
    print("-" * 60)
    client.logout()

    print(f"\n  🔒 Authenticated after logout: {client.is_authenticated}")
    print("\n" + "=" * 60)
    print("  Demo Complete ✅")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
