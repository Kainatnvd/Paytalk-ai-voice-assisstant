# Implementation Plan: Banking-Grade Security Upgrade - COMPLETED

## 1. Cryptographic Upgrade
- [x] Modify `app/core/security.py` to implement `AES-256-GCM`.
    - [x] `encrypt_data(data: str, aad: Optional[str] = None)`: returns `version + iv + tag + ciphertext`.
    - [x] `decrypt_data(payload: bytes, aad: Optional[str] = None)`: verifies tag and version.
- [x] Update `app/core/secrets_manager.py` to return key versions along with keys.

## 2. Hashing Upgrade (CNIC)
- [x] Modify `hash_cnic` in `app/core/security.py` to use a salted SHA-256.
- [x] Use `user_id` as a per-user salt in the `User` model.

## 3. PII Protection (Data At-Rest)
- [x] Locate models with `phone_number`, `full_name`, and `note`.
- [x] `User` model: `full_name`, `phone_number`.
- [x] `Transaction` model: `note`.
- [x] `Contact` model: `full_name`, `nickname`, `raast_id`.
- [x] Update database migrations to change these from string to bytes (LargeBinary).

## 4. Lazy Migration Strategy
- [x] Implement SQLAlchemy `hybrid_property` to handle "read-decrypt-check_version-reencrypt-save" flow.
- [x] Update `app/core/security.py` to handle both legacy CBC and new GCM during transition.

## 5. Key Lifecycle Management
- [x] Enhance `SecretsManager` to support version-based lookup.
- [x] Define rotation logic in `app/core/secrets_manager.py`.

## 6. Testing & Verification
- [x] Test decryption of legacy CBC data.
- [x] Verify GCM tag verification (tamper proof).
- [x] Verify PII encryption/decryption in the API.
