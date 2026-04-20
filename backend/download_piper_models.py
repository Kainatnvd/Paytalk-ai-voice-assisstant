"""
Download Piper TTS voice models for English and Urdu.
Run this once: python download_piper_models.py
"""
import os
import urllib.request
import sys

MODELS_DIR = os.path.join(os.path.dirname(__file__), "app", "models", "piper")
os.makedirs(MODELS_DIR, exist_ok=True)

FILES = {
    # English – Amy (low quality, small ~63MB)
    "en_US-amy-low.onnx": "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx",
    "en_US-amy-low.onnx.json": "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx.json",
    # Urdu – Fasih (medium quality)
    "ur_PK-fasih-medium.onnx": "https://huggingface.co/IhorShevchuk/piper-voice-ur-fasih/resolve/main/ur_PK-fasih-medium-model.onnx",
    "ur_PK-fasih-medium.onnx.json": "https://huggingface.co/IhorShevchuk/piper-voice-ur-fasih/resolve/main/ur_PK-fasih-medium-model.onnx.json",
}


def download(name: str, url: str):
    dest = os.path.join(MODELS_DIR, name)
    if os.path.exists(dest) and os.path.getsize(dest) > 100:
        print(f"[OK] {name} already exists, skipping.")
        return
    print(f"[>>] Downloading {name} ...")
    try:
        urllib.request.urlretrieve(url, dest)
        size_mb = os.path.getsize(dest) / (1024 * 1024)
        print(f"    Saved {name} ({size_mb:.1f} MB)")
    except Exception as e:
        print(f"    [FAIL] Failed to download {name}: {e}")
        # Remove partial file
        if os.path.exists(dest):
            os.remove(dest)


if __name__ == "__main__":
    print(f"Downloading Piper models to: {MODELS_DIR}\n")
    for name, url in FILES.items():
        download(name, url)
    print("\nDone!")
