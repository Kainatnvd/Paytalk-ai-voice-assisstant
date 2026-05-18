import os
import time
from groq import Groq
from dotenv import load_dotenv
from app.services import stt_service

# Load environment variables from .env
load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

def transcribe_audio(audio_path: str, language: str = "ur") -> dict:
    """
    Transcribe audio using Groq Whisper Large V3 Turbo with fallback to local Whisper.
    
    Args:
        audio_path: Path to the audio file.
        language: ISO-639-1 language code (default "ur" for Urdu).
        
    Returns:
        Dictionary with transcription text or error details.
    """
    # 1. Attempt Groq API transcription
    if GROQ_API_KEY and GROQ_API_KEY != "your_api_key_here":
        client = Groq(api_key=GROQ_API_KEY)
        
        max_retries = 3
        retry_delay = 60  # seconds
        
        for attempt in range(max_retries):
            try:
                print(f"[Transcription] Attempting Groq API (Attempt {attempt + 1})...")
                with open(audio_path, "rb") as file:
                    transcription = client.audio.transcriptions.create(
                        file=(audio_path, file.read()),
                        model="whisper-large-v3-turbo",
                        # Removing forced language to allow auto-detection (EN/UR)
                        response_format="verbose_json",
                    )
                
                # Detect the language from the result or fallback to 'ur'
                raw_lang = str(getattr(transcription, 'language', language)).lower()
                lang_map = {
                    "hindi": "ur", "hi": "ur", 
                    "urdu": "ur", "ur": "ur", 
                    "english": "en", "en": "en"
                }
                detected_lang = lang_map.get(raw_lang, "ur")
                
                print(f"[Transcription] Groq API success. Detected: {detected_lang} (raw: {raw_lang})")
                return {
                    "text": transcription.text,
                    "language": detected_lang,
                    "source": "groq_api"
                }
                
            except Exception as e:
                err_msg = str(e)
                # Check for rate limit (429)
                if "429" in err_msg or "rate_limit" in err_msg.lower():
                    if attempt < max_retries - 1:
                        print(f"[Transcription] Groq Rate Limit (429). Retrying in {retry_delay}s...")
                        time.sleep(retry_delay)
                        continue
                    else:
                        print("[Transcription] Max retries reached for Groq Rate Limit.")
                
                # Any other error or max retries reached -> Fallback
                print(f"[Transcription] Groq API failed: {err_msg}. Falling back to local Whisper.")
                break
    else:
        print("[Transcription] GROQ_API_KEY missing or placeholder. Falling back to local Whisper.")

    # 2. Fallback to local Whisper
    try:
        with open(audio_path, "rb") as f:
            audio_bytes = f.read()
        
        # Use existing stt_service for local transcription
        result = stt_service.transcribe_audio(audio_bytes, language_hint=language)
        
        if "error" in result:
            return result
            
        return {
            "text": result.get("text", ""),
            "language": result.get("language", language),
            "source": "local_whisper"
        }
    except Exception as e:
        print(f"[Transcription] Local fallback failed: {e}")
        return {"error": "transcription_failed", "detail": str(e)}
