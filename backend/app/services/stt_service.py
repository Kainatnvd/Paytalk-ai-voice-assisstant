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


def get_model() -> whisper.Whisper:
    global _model
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

    Returns:
        {
            "text": str,
            "language": str,
            "duration_seconds": float,
            "processing_time_ms": int
        }
        OR {"error": "transcription_failed"} on failure.
    """
    start = time.perf_counter()
    try:
        model = get_model()
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"

        # Whisper expects a file-like object or numpy array; write bytes to buffer
        audio_buffer = io.BytesIO(audio_bytes)

        # Use whisper's load_audio helper via a temp approach
        import tempfile, os
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        try:
            # Prevent Whisper hallucination with strict decoding parameters.
            result = model.transcribe(
                tmp_path,
                task="transcribe",
                language="en", # Forces output in Latin alphabet (Roman Urdu)
                fp16=(device == "cuda"),
                temperature=(0.0, 0.2, 0.4), # Allow slight fallback for hallucination loops
                condition_on_previous_text=False, # Stops hallucination loops
            )
        finally:
            os.unlink(tmp_path)
            
        # ── Hallucination & Silence Filtering ──
        raw_text = result["text"].strip()
        segments = result.get("segments", [])
        
        # 1. Check if the audio is mostly silence/noise
        avg_no_speech = sum(s.get("no_speech_prob", 0.0) for s in segments) / max(1, len(segments))
        if avg_no_speech > 0.7:
             raw_text = ""
             
        # 2. Check for crazy repetetive patterns (e.g. "Om Om Om Om Om")
        # If the text is long but consists of very few unique characters, it's a hallucination.
        if len(raw_text) > 15 and len(set(raw_text.replace(" ", ""))) <= 4:
            raw_text = ""
            
        # 3. Hardcode known Whisper "silence" hallucination tokens
        if "ॐ" in raw_text or "Amma Amma" in raw_text or "Subtitles by" in raw_text:
            raw_text = ""

        # ── Language Detection & Normalization ──
        detected_raw = result.get("language", "ur")
        
        # Whisper maps: 'hi' (Hindi), 'ur' (Urdu), 'pa' (Punjabi) -> 'ur'
        # Others can stay as they are, but we mostly care about 'en' vs 'ur'
        if detected_raw in ["ur", "hi", "pa", "sd"]:
            final_lang = "ur"
        elif detected_raw == "en":
            final_lang = "en"
        else:
            # Fallback to the hint or English
            final_lang = language_hint if language_hint in ["en", "ur"] else "en"

        elapsed_ms = int((time.perf_counter() - start) * 1000)

        # Whisper duration is in the segments
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
