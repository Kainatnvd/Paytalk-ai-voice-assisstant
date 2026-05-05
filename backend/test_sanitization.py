"""Quick smoke-test for the sanitization module."""

from app.core.sanitization import (
    sanitise_text,
    sanitise_field,
    validate_audio_file,
    contains_sql_patterns,
)

print("=" * 60)
print("PayTalk Security Sanitization - Smoke Test")
print("=" * 60)

# ── 1. XSS stripping (bleach strips tags, keeps inner text) ──
xss = "<script>alert(1)</script>Hello"
result = sanitise_text(xss)
assert "<script>" not in result, f"Script tag not stripped: {result!r}"
assert "</script>" not in result
print(f"[PASS] XSS strip: {xss!r} -> {result!r}")

xss2 = '<img src=x onerror="alert(1)">Clean text'
result2 = sanitise_text(xss2)
assert "onerror" not in result2
print(f"[PASS] XSS img: {xss2!r} -> {result2!r}")

# ── 2. Field length enforcement ──
long = "A" * 500
result = sanitise_field("full_name", long)
assert len(result) == 120
print(f"[PASS] Length enforcement: 500 chars -> {len(result)} chars (max 120)")

# ── 3. Null byte removal ──
null_str = "Hello\x00World"
result = sanitise_text(null_str)
assert "\x00" not in result
print(f"[PASS] Null byte removal: {null_str!r} -> {result!r}")

# ── 4. SQL pattern detection ──
assert contains_sql_patterns("DROP TABLE users") == True
assert contains_sql_patterns("SELECT * FROM users") == True
assert contains_sql_patterns("send money to Ali") == False
assert contains_sql_patterns("check balance") == False
print("[PASS] SQL pattern detection works correctly")

# ── 5. Audio validation - bad content ──
result = validate_audio_file(b"not audio data", "test.wav")
assert result["valid"] == False
print(f"[PASS] Bad audio rejected: {result['reason'][:50]}")

# ── 6. Audio validation - valid WAV ──
wav = b"RIFF" + b"\x00" * 4 + b"WAVE" + b"\x00" * 100
result = validate_audio_file(wav, "test.wav")
assert result["valid"] == True
print("[PASS] Valid WAV accepted")

# ── 7. Audio validation - bad extension ──
result = validate_audio_file(wav, "test.exe")
assert result["valid"] == False
print(f"[PASS] Bad extension rejected: {result['reason'][:50]}")

# ── 8. Audio validation - oversized file ──
big = b"RIFF" + b"\x00" * 4 + b"WAVE" + b"\x00" * (11 * 1024 * 1024)
result = validate_audio_file(big, "test.wav", max_size=10 * 1024 * 1024)
assert result["valid"] == False
print(f"[PASS] Oversized file rejected: {result['reason'][:50]}")

# ── 9. Audio validation - MP3 with ID3 ──
mp3 = b"ID3" + b"\x00" * 200
result = validate_audio_file(mp3, "test.mp3")
assert result["valid"] == True
print("[PASS] MP3 (ID3 header) accepted")

# ── 10. Audio validation - OGG ──
ogg = b"OggS" + b"\x00" * 200
result = validate_audio_file(ogg, "test.ogg")
assert result["valid"] == True
print("[PASS] OGG accepted")

# ── 11. Pydantic schema sanitization ──
from app.schemas.user_schema import UserRegisterRequest

req = UserRegisterRequest(
    full_name="<b>Evil</b> User",
    phone_number="03001234567",
    password="test123",
    cnic="1234567890123",
)
assert "<b>" not in req.full_name
assert "Evil" in req.full_name and "User" in req.full_name
print(f"[PASS] Pydantic schema sanitized: '<b>Evil</b> User' -> {req.full_name!r}")

from app.schemas.transaction_schema import TransferRequest
from decimal import Decimal

req2 = TransferRequest(
    recipient_name_query='<script>alert("xss")</script>Ali',
    amount=Decimal("500"),
)
assert "<script>" not in req2.recipient_name_query
print(f"[PASS] TransferRequest sanitized: -> {req2.recipient_name_query!r}")

print()
print("=" * 60)
print("ALL 11 TESTS PASSED")
print("=" * 60)
