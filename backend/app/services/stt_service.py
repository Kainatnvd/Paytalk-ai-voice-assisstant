"""
Speech-to-Text service using OpenAI Whisper.
Model is loaded ONCE at startup to avoid repeated cold-start delays.
"""
import io
import time
import os
from typing import Optional

# ── FFmpeg Configuration ──────────────────────────────────────────────────
# Force add winget/gyan ffmpeg to path to avoid [WinError 2]
ffmpeg_path = r"C:\Users\shafi laptop\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build\bin"
if ffmpeg_path not in os.environ["PATH"]:
    os.environ["PATH"] = ffmpeg_path + os.pathsep + os.environ["PATH"]
# ─────────────────────────────────────────────────────────────────────────

import whisper

from app.core.config import settings

# ── Load model once at module import (startup) ────────────────────────────────
_model: Optional[whisper.Whisper] = None


def get_model() -> Optional[whisper.Whisper]:
    global _model
    if settings.STT_ENGINE != "local":
        return None
        
    if _model is None:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        
        print(f"[STT] Loading Whisper model '{settings.WHISPER_MODEL_SIZE}' (on {device.upper()})...")
        _model = whisper.load_model(settings.WHISPER_MODEL_SIZE, device=device)
        print("[STT] Model loaded.")
    return _model


def transcribe_audio(audio_bytes: bytes, language_hint: str = "ur") -> dict:
    """
    Transcribe raw audio bytes.
    Supports Local Whisper or Cloud Gemini based on settings.
    Falls back to local Whisper if Gemini fails.
    """
    start = time.perf_counter()
    
    # ── Option A: Gemini Cloud STT (No local resources) ──────────────────────
    if settings.STT_ENGINE == "gemini":
        try:
            from google import genai
            from google.genai import types
            
            if not settings.GOOGLE_API_KEY:
                print("[STT] Gemini API key missing. Falling back to local Whisper.")
            else:
                client = genai.Client(api_key=settings.GOOGLE_API_KEY)
                
                # Robust multi-model fallback chain for cloud audio processing
                models_to_try = ['gemini-flash-latest', 'gemini-flash-lite-latest', 'gemini-2.5-flash-lite', 'gemini-2.5-flash']
                response = None
                last_err = None
                
                audio_contents = [
                    types.Part.from_bytes(data=audio_bytes, mime_type="audio/wav"),
                    "Transcribe this audio exactly. If the user speaks English, transcribe it in English. If they speak Urdu, transcribe it in Urdu. Do NOT translate. Do NOT include any timestamps like 00:01. Return ONLY the transcribed text."
                ]
                
                for model_name in models_to_try:
                    try:
                        response = client.models.generate_content(
                            model=model_name,
                            contents=audio_contents
                        )
                        break
                    except Exception as e:
                        last_err = e
                        print(f"[STT] Cloud Model {model_name} failed: {e}. Trying next fallback...")
                        continue
                
                if response is None:
                    raise last_err or Exception("All Gemini STT models failed")
                
                text = response.text.strip()
                elapsed_ms = int((time.perf_counter() - start) * 1000)
                
                # Detect language from the transcribed text
                import re
                ascii_chars = len(re.findall(r'[a-zA-Z]', text))
                total_chars = len(text.replace(" ", ""))
                detected_lang = "en" if total_chars > 0 and (ascii_chars / max(1, total_chars)) > 0.5 else "ur"
                
                return {
                    "text": text,
                    "language": detected_lang,
                    "duration_seconds": 0.0,
                    "processing_time_ms": elapsed_ms,
                }
        except Exception as e:
            print(f"[STT] Gemini Cloud Error: {e}. Falling back to local Whisper.")

    # ── Option B: Local Whisper (fallback) ────────────────────────────────────
    try:
        model = get_model()
        if model is None:
            # If STT_ENGINE is gemini but model not loaded, force-load it
            global _model
            import torch
            device = "cuda" if torch.cuda.is_available() else "cpu"
            print(f"[STT] Force-loading Whisper model '{settings.WHISPER_MODEL_SIZE}' for fallback (on {device.upper()})...")
            _model = whisper.load_model(settings.WHISPER_MODEL_SIZE, device=device)
            print("[STT] Whisper model loaded.")
            model = _model

        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"

        # Whisper expects a file-like object or numpy array; write bytes to buffer
        import tempfile, os
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        try:
            result = model.transcribe(
                tmp_path,
                task="transcribe",
                language="en",
                fp16=(device == "cuda"),
                temperature=0.0,
                beam_size=3,
                condition_on_previous_text=False,
                no_speech_threshold=0.5,
                initial_prompt=(
                    "PayTalk voice banking assistant. "
                    "User commands include: send 500 to Cafe, send 1000 to Ali, "
                    "send 200 to Ahmed, transfer 3000 to Farzam, "
                    "pay Electricity Bill, pay Water Bill, pay Gas Bill, "
                    "send money to Tailor, send 500 to Coffee Shop, "
                    "check balance, transaction history, check my account."
                ),
            )
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            
        raw_text = result["text"].strip()
        segments = result.get("segments", [])
        
        # ── Hallucination & Silence Filtering ──
        avg_no_speech = sum(s.get("no_speech_prob", 0.0) for s in segments) / max(1, len(segments))
        if avg_no_speech > 0.9:
             raw_text = ""
        if len(raw_text) > 15 and len(set(raw_text.replace(" ", ""))) <= 4:
            raw_text = ""
        if "ॐ" in raw_text or "Amma Amma" in raw_text or "Subtitles by" in raw_text:
            raw_text = ""

        # ── Language Detection ──
        import re
        ascii_chars = len(re.findall(r'[a-zA-Z]', raw_text))
        total_chars = len(raw_text.replace(" ", ""))
        if total_chars > 0 and (ascii_chars / total_chars) > 0.5:
            final_lang = "en"
        else:
            final_lang = "ur"

        elapsed_ms = int((time.perf_counter() - start) * 1000)
        duration = sum(seg.get("end", 0) - seg.get("start", 0) for seg in result.get("segments", []))

        print(f"[STT] Whisper result: '{raw_text}' (lang={final_lang})")
        
        return {
            "text": raw_text,
            "language": final_lang,
            "duration_seconds": round(duration, 2),
            "processing_time_ms": elapsed_ms,
        }

    except Exception as e:
        import traceback
        print(f"[STT] Transcription error: {e}")
        traceback.print_exc()
        return {"error": "transcription_failed", "detail": str(e)}

