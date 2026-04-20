"""
Text-to-Speech service using gTTS (Google Text-to-Speech).
Supports Urdu and English.
"""
import base64
import io
import time

def _synthesize_gtts(text: str, lang: str) -> bytes:
    """
    Synthesize using Google TTS (requires internet).
    Returns MP3 bytes.
    """
    from gtts import gTTS

    lang_map = {"ur": "ur", "en": "en"}
    # Default to urdu if the language is missing
    gtts_lang = lang_map.get(lang, "ur")

    max_retries = 2
    for attempt in range(max_retries + 1):
        try:
            tts = gTTS(text=text, lang=gtts_lang, slow=False)
            buffer = io.BytesIO()
            tts.write_to_fp(buffer)
            
            audio_data = buffer.getvalue()
            print(f"[TTS] gTTS generated voice for '{lang}' ({len(audio_data)} bytes)")
            return audio_data
        except Exception as e:
            print(f"[TTS] gTTS Error attempt {attempt + 1}/{max_retries + 1}: {e}")
            if attempt < max_retries:
                time.sleep(1)
            else:
                print(f"[TTS] Returning empty audio due to failure.")
                return b""

# ── Language Normalization ─────────────────────────────────────────────────────
# Whisper often detects Hindi/Punjabi/etc. for Urdu speech.
_LANG_NORMALIZE = {
    "ur": "ur",
    "hi": "ur",   # Hindi ↔ Urdu are mutually intelligible
    "pa": "ur",   # Punjabi speakers often get detected as this
    "sd": "ur",   # Sindhi
    "en": "en",
}

def _normalize_lang(lang: str) -> str:
    """Map Whisper-detected language codes to the two we support: 'en' or 'ur'."""
    return _LANG_NORMALIZE.get(lang, "en")

# ── Public API ─────────────────────────────────────────────────────────────────

def generate_voice_response(text: str, lang: str = "ur") -> bytes:
    """
    Convert text to audio bytes using gTTS.

    Args:
        text: Text to speak.
        lang: Language code ('ur' for Urdu, 'en' for English).

    Returns:
        Audio bytes (MP3 from gTTS).
    """
    lang = _normalize_lang(lang)
    return _synthesize_gtts(text, lang)

def generate_voice_response_base64(text: str, lang: str = "ur") -> str:
    """Return base64-encoded audio for embedding in JSON API responses."""
    audio_bytes = generate_voice_response(text, lang)
    return base64.b64encode(audio_bytes).decode("utf-8")
