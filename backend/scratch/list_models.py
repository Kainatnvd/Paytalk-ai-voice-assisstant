import os
from google import genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    print("GOOGLE_API_KEY not found in .env")
    exit(1)

client = genai.Client(api_key=api_key)

try:
    print("Listing models:")
    for model in client.models.list():
        print(f"Model: {model.name}, Display Name: {model.display_name}")
except Exception as e:
    print(f"Error listing models: {e}")
