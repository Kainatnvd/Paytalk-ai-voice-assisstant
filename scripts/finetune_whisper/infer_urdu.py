import torch
import sys
import os
from transformers import WhisperForConditionalGeneration, WhisperProcessor
import librosa

# ── CONFIGURATION ──────────────────────────────────────────────────────────
MODEL_PATH = "./whisper-small-urdu"
# Check if model exists, if not fallback to original (for demonstration)
if not os.path.exists(MODEL_PATH):
    print(f"Warning: Fine-tuned model at {MODEL_PATH} not found. Falling back to openai/whisper-small.")
    MODEL_PATH = "openai/whisper-small"

# Device setup
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")
# ──────────────────────────────────────────────────────────────────────────

def transcribe(audio_path):
    # 1. Load model and processor
    print(f"Loading model from {MODEL_PATH}...")
    processor = WhisperProcessor.from_pretrained(MODEL_PATH)
    model = WhisperForConditionalGeneration.from_pretrained(MODEL_PATH).to(device)

    # 2. Load audio file
    print(f"Loading audio file: {audio_path}")
    # Whisper requires 16kHz audio
    audio, sr = librosa.load(audio_path, sr=16000)

    # 3. Preprocess audio
    input_features = processor(audio, sampling_rate=16000, return_tensors="pt").input_features.to(device)

    # 4. Generate transcription
    # We force the decoder to start with the <|ur|> token for Urdu transcription
    forced_decoder_ids = processor.get_decoder_prompt_ids(language="urdu", task="transcribe")

    print("Generating transcription...")
    predicted_ids = model.generate(input_features, forced_decoder_ids=forced_decoder_ids)

    # 5. Decode
    transcription = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0]
    
    return transcription

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python infer_urdu.py <path_to_audio_file>")
        sys.exit(1)

    audio_file = sys.argv[1]
    if not os.path.exists(audio_file):
        print(f"Error: File {audio_file} not found.")
        sys.exit(1)

    try:
        result = transcribe(audio_file)
        print("\n" + "="*30)
        print("URDU TRANSCRIPTION:")
        print(result)
        print("="*30)
    except Exception as e:
        print(f"An error occurred: {e}")
