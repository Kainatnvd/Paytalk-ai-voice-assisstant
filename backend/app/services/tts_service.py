"""
Text-to-Speech service using gTTS (Google Text-to-Speech).
Supports Urdu and English natively.
"""
import base64
import io

from gtts import gTTS


def generate_voice_response(text: str, lang: str = "ur") -> bytes:
    """
    Convert text to MP3 audio bytes.

    Args:
        text: Text to speak.
        lang: Language code ('ur' for Urdu, 'en' for English).

    Returns:
        MP3 audio as bytes.
    """
    # gTTS language mapping
    lang_map = {"ur": "ur", "en": "en"}
    gtts_lang = lang_map.get(lang, "ur")

    tts = gTTS(text=text, lang=gtts_lang, slow=False)
    buffer = io.BytesIO()
    tts.write_to_fp(buffer)
    return buffer.getvalue()


def generate_voice_response_base64(text: str, lang: str = "ur") -> str:
    """Return base64-encoded MP3 for embedding in JSON API responses."""
    mp3_bytes = generate_voice_response(text, lang)
    return base64.b64encode(mp3_bytes).decode("utf-8")
