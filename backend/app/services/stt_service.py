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
    """
    start = time.perf_counter()
    
    # ── Option A: Gemini Cloud STT (No local resources) ──────────────────────
    if settings.STT_ENGINE == "gemini":
        try:
            from google import genai
            from google.genai import types
            
            if not settings.GOOGLE_API_KEY:
                return {"error": "gemini_api_key_missing"}

            client = genai.Client(api_key=settings.GOOGLE_API_KEY)
            
            # Gemini can process audio directly
            response = client.models.generate_content(
                model='gemini-2.0-flash',
                contents=[
                    types.Part.from_bytes(data=audio_bytes, mime_type="audio/wav"),
                    f"Transcribe this audio exactly. The language is likely {language_hint}. Return ONLY the transcription text."
                ]
            )
            
            text = response.text.strip()
            elapsed_ms = int((time.perf_counter() - start) * 1000)
            
            return {
                "text": text,
                "language": language_hint, # Gemini usually detects automatically but we'll stick to hint
                "duration_seconds": 0.0,    # Cloud API doesn't always return this easily
                "processing_time_ms": elapsed_ms,
            }
        except Exception as e:
            print(f"[STT] Gemini Cloud Error: {e}")
            return {"error": "gemini_transcription_failed", "detail": str(e)}

    # ── Option B: Local Whisper ───────────────────────────────────────────────
    try:
        model = get_model()
        if model is None:
            return {"error": "stt_engine_misconfigured"}

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
                fp16=(device == "cuda"),
                temperature=(0.0, 0.2, 0.4), 
                condition_on_previous_text=False, 
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
        detected_raw = result.get("language", "ur")
        if detected_raw in ["ur", "hi", "pa", "sd"]:
            final_lang = "ur"
        elif detected_raw == "en":
            final_lang = "en"
        else:
            final_lang = language_hint if language_hint in ["en", "ur"] else "en"

        elapsed_ms = int((time.perf_counter() - start) * 1000)
        duration = sum(seg.get("end", 0) - seg.get("start", 0) for seg in result.get("segments", []))

        return {
            "text": raw_text,
            "language": final_lang,
            "duration_seconds": round(duration, 2),
            "processing_time_ms": elapsed_ms,
        }

    except Exception as e:
        print(f"[STT] Transcription error: {e}")
        return {"error": "transcription_failed", "detail": str(e)}
