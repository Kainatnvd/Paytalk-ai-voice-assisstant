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
        print(f"[STT] Loading Whisper model '{settings.WHISPER_MODEL_SIZE}'...")
        _model = whisper.load_model(settings.WHISPER_MODEL_SIZE)
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

        # Whisper expects a file-like object or numpy array; write bytes to buffer
        audio_buffer = io.BytesIO(audio_bytes)

        # Use whisper's load_audio helper via a temp approach
        import tempfile, os
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        try:
            result = model.transcribe(
                tmp_path,
                language=language_hint,   # hint Urdu-first; Whisper auto-detects if wrong
                task="transcribe",
                fp16=False,               # Fix FP16 warning on CPU
            )
        finally:
            os.unlink(tmp_path)

        elapsed_ms = int((time.perf_counter() - start) * 1000)

        # Whisper duration is in the segments
        duration = sum(seg.get("end", 0) - seg.get("start", 0) for seg in result.get("segments", []))

        return {
            "text": result["text"].strip(),
            "language": result.get("language", language_hint),
            "duration_seconds": round(duration, 2),
            "processing_time_ms": elapsed_ms,
        }

    except Exception as e:
        print(f"[STT] Transcription error: {e}")
        return {"error": "transcription_failed", "detail": str(e)}
