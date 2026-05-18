import json
import os
from typing import List, Dict, Optional
from pydantic import BaseModel

from app.core.config import settings

SECRETS_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), ".secrets.json")

class KeyRecord(BaseModel):
    version: str
    key: str
    status: str  # "active" or "deprecated"

class SecretsManager:
    """
    Abstracts secret retrieval. In production, this would interface with 
    HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault.
    For this demo, it uses a local JSON file to support key rotation, 
    falling back to .env if the file is missing.
    """
    
    def __init__(self):
        self.jwt_keys: List[KeyRecord] = []
        self.aes_keys: List[KeyRecord] = []
        self._load_secrets()

    def _load_secrets(self):
        if os.path.exists(SECRETS_FILE):
            with open(SECRETS_FILE, "r") as f:
                data = json.load(f)
                self.jwt_keys = [KeyRecord(**k) for k in data.get("JWT_KEYS", [])]
                self.aes_keys = [KeyRecord(**k) for k in data.get("AES_KEYS", [])]
        
        # Fallback to .env if empty
        if not self.jwt_keys:
            self.jwt_keys.append(KeyRecord(version="v0", key=settings.SECRET_KEY, status="active"))
        if not self.aes_keys:
            self.aes_keys.append(KeyRecord(version="v0", key=settings.AES_ENCRYPTION_KEY, status="active"))

    def get_active_jwt_key(self) -> str:
        for k in self.jwt_keys:
            if k.status == "active":
                return k.key
        return self.jwt_keys[-1].key

    def get_all_jwt_keys(self) -> List[str]:
        return [k.key for k in self.jwt_keys]

    def get_active_aes_record(self) -> KeyRecord:
        for k in self.aes_keys:
            if k.status == "active":
                return k
        return self.aes_keys[-1]

    def get_active_aes_key(self) -> bytes:
        rec = self.get_active_aes_record()
        return rec.key.encode()[:32].ljust(32, b"\x00")

    def get_aes_record_by_version(self, version: str) -> Optional[KeyRecord]:
        for k in self.aes_keys:
            if k.version == version:
                return k
        return None

    def get_all_aes_records(self) -> List[KeyRecord]:
        """Returns all AES key records for decryption trials."""
        return self.aes_keys

    def rotate_aes_key(self):
        """Programmatic trigger for key rotation."""
        import secrets
        import json
        
        # 1. Deprecate current active keys
        for k in self.aes_keys:
            if k.status == "active":
                k.status = "deprecated"
        
        # 2. Create new key
        new_version = f"v{len(self.aes_keys)}"
        new_key = secrets.token_hex(32)
        self.aes_keys.append(KeyRecord(version=new_version, key=new_key, status="active"))
        
        # 3. Persist to file
        data = {
            "JWT_KEYS": [k.dict() for k in self.jwt_keys],
            "AES_KEYS": [k.dict() for k in self.aes_keys]
        }
        with open(SECRETS_FILE, "w") as f:
            json.dump(data, f, indent=4)
        
        print(f"[SecretsManager] AES Key rotated to {new_version}")

secrets_manager = SecretsManager()
