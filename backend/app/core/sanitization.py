"""
Input sanitisation & validation utilities for PayTalk.

Three security layers:
  1. Text sanitisation   – bleach strips HTML/JS from user-supplied strings
  2. SQL injection guard – enforced by using SQLAlchemy ORM only (this module
                           provides an audit helper to reject raw SQL patterns)
  3. Audio file validation – magic-byte + extension whitelist for uploaded media
"""
import re
import struct
from typing import Optional

import bleach

# ── 1. TEXT SANITISATION ──────────────────────────────────────────────────────

# We strip ALL tags/attributes – PayTalk stores plain-text only.
_ALLOWED_TAGS: list[str] = []
_ALLOWED_ATTRS: dict[str, list[str]] = {}

# Maximum lengths for common fields (prevents megabyte-sized payloads)
FIELD_MAX_LENGTHS = {
    "full_name": 120,
    "phone_number": 20,
    "email": 254,
    "cnic": 15,
    "password": 128,
    "new_password": 128,
    "otp_code": 10,
    "device_info": 256,
    "label": 64,
    "note": 500,
    "recipient_name_query": 120,
    "recipient_name": 120,
    "recipient_account": 40,
    "service": 64,
}


def sanitise_text(value: str, *, max_length: Optional[int] = None) -> str:
    """
    Sanitise a user-supplied string:
      • Strip all HTML tags and attributes (XSS prevention)
      • Collapse control characters
      • Enforce optional max length
    """
    if not isinstance(value, str):
        return value

    # 1. Bleach – strip every HTML tag
    cleaned = bleach.clean(value, tags=_ALLOWED_TAGS, attributes=_ALLOWED_ATTRS, strip=True)

    # 2. Remove null bytes and dangerous control chars (keep \n, \r, \t)
    cleaned = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", cleaned)

    # 3. Truncate
    if max_length and len(cleaned) > max_length:
        cleaned = cleaned[:max_length]

    return cleaned.strip()


def sanitise_field(field_name: str, value: str) -> str:
    """Sanitise with the per-field max-length from FIELD_MAX_LENGTHS."""
    max_len = FIELD_MAX_LENGTHS.get(field_name)
    return sanitise_text(value, max_length=max_len)


# ── 2. SQL PATTERN GUARD ─────────────────────────────────────────────────────
# The codebase uses SQLAlchemy ORM exclusively, but this helper can be called
# on free-text search inputs as a defence-in-depth measure.

_SQL_INJECTION_PATTERNS = re.compile(
    r"(--|;|\b(DROP|ALTER|DELETE|INSERT|UPDATE|UNION|SELECT)\b)",
    re.IGNORECASE,
)


def contains_sql_patterns(value: str) -> bool:
    """Return True if the string contains suspicious SQL fragments."""
    return bool(_SQL_INJECTION_PATTERNS.search(value))


# ── 3. AUDIO FILE VALIDATION ─────────────────────────────────────────────────

# Allowed MIME types and their magic byte signatures
ALLOWED_AUDIO_TYPES: dict[str, list[bytes]] = {
    "audio/wav": [
        b"RIFF",   # WAV files start with RIFF header
    ],
    "audio/mpeg": [
        b"\xff\xfb",  # MP3 frame sync (MPEG1 Layer3)
        b"\xff\xf3",  # MP3 frame sync (MPEG2 Layer3)
        b"\xff\xf2",  # MP3 frame sync (MPEG2.5 Layer3)
        b"ID3",       # MP3 with ID3v2 tag
    ],
    "audio/ogg": [
        b"OggS",   # OGG container
    ],
    "audio/flac": [
        b"fLaC",   # FLAC
    ],
    "audio/x-m4a": [
        b"\x00\x00\x00",  # M4A/MP4 (ftyp box — checked more carefully below)
    ],
    "audio/webm": [
        b"\x1a\x45\xdf\xa3",  # WebM (EBML header)
    ],
}

# Flat set of allowed extensions (lowercase, with dot)
ALLOWED_AUDIO_EXTENSIONS = {
    ".wav", ".mp3", ".ogg", ".oga", ".flac", ".m4a", ".webm", ".weba",
}

# 10 MB default max upload size
MAX_AUDIO_SIZE_BYTES = 10 * 1024 * 1024


def _check_wav_header(data: bytes) -> bool:
    """Validate a WAV file has a proper RIFF/WAVE header."""
    if len(data) < 12:
        return False
    return data[:4] == b"RIFF" and data[8:12] == b"WAVE"


def _check_mp4_ftyp(data: bytes) -> bool:
    """Validate an M4A/MP4 file has a proper ftyp box."""
    if len(data) < 12:
        return False
    # ftyp box: bytes 4..8 should be 'ftyp'
    return data[4:8] == b"ftyp"


def validate_audio_file(
    file_bytes: bytes,
    filename: str,
    *,
    max_size: int = MAX_AUDIO_SIZE_BYTES,
) -> dict:
    """
    Validate an uploaded audio file.

    Returns:
        {"valid": True}
        OR {"valid": False, "reason": str}
    """
    # 1. Size check
    if len(file_bytes) > max_size:
        return {
            "valid": False,
            "reason": f"Audio file too large ({len(file_bytes):,} bytes). "
                      f"Maximum allowed is {max_size:,} bytes.",
        }

    # 2. Empty file
    if len(file_bytes) < 4:
        return {"valid": False, "reason": "Audio file is empty or too small."}

    # 3. Extension whitelist
    import os
    ext = os.path.splitext(filename or "")[1].lower()
    if ext and ext not in ALLOWED_AUDIO_EXTENSIONS:
        return {
            "valid": False,
            "reason": f"File extension '{ext}' is not allowed. "
                      f"Accepted: {', '.join(sorted(ALLOWED_AUDIO_EXTENSIONS))}",
        }

    # 4. Magic-byte validation (defence-in-depth)
    header = file_bytes[:12]
    matched = False

    # WAV
    if _check_wav_header(header):
        matched = True
    # MP3
    elif header[:3] == b"ID3" or header[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
        matched = True
    # OGG
    elif header[:4] == b"OggS":
        matched = True
    # FLAC
    elif header[:4] == b"fLaC":
        matched = True
    # M4A / MP4
    elif _check_mp4_ftyp(header):
        matched = True
    # WebM
    elif header[:4] == b"\x1a\x45\xdf\xa3":
        matched = True

    if not matched:
        return {
            "valid": False,
            "reason": "File content does not match any allowed audio format. "
                      "Accepted formats: WAV, MP3, OGG, FLAC, M4A, WebM.",
        }

    return {"valid": True}


def detect_liveness(audio_bytes: bytes) -> dict:
    """
    Stub for Voice Liveness Detection / Anti-Spoofing.
    In a production setting, this would run a lightweight ML model 
    (like ASVspoof models) or analyze the audio spectrum for artifacts of 
    synthetic generation (TTS) or playback (speaker/mic distortion).
    """
    # Currently mocked to True. If integrated, it would return:
    # {"is_live": False, "score": 0.12, "reason": "Synthetic TTS artifacts detected"}
    return {"is_live": True, "score": 0.98}
