import re
import json
from typing import Any, Dict, Optional

import httpx
from google import genai

from app.core.config import settings

# ── Keyword fallback patterns (for offline or API failure) ─────────────────────
_KEYWORD_RULES = [
    ("check_balance",       r"balance|paisa|kitna|baqi|remaining|check|batana|dekhna|show"),
    ("transfer_money",      r"bhejo|send|transfer|bhejna|payment|pay|ada|rakam|rupiya|bhijwado"),
    ("transaction_history", r"history|transactions?|tarikh|details?|record|purana|statement|pichli"),
    ("confirm",             r"\b(haan|yes|theek|ok|okay|confirm|bilkul|kar do|kardo|confirm|sahi)\b"),
    ("cancel",              r"\b(nahi|no|cancel|band|rukk|mat karo|stop|rehne do|choro|no)\b"),
    ("get_account_info",    r"account.*(number|detail|maloomat)|number.*account|info|shanakht"),
]


def _map_canonical_contact(raw_name: str) -> str:
    """Maps varied Urdu/English terms to exact database contact names."""
    if not isinstance(raw_name, str):
        return raw_name
    
    lower = raw_name.lower()
    
    if any(k in lower for k in ["electric", "electricity", "bijli", "light"]):
        return "Electricity Bill"
    if any(k in lower for k in ["water", "paani", "wssk"]):
        return "Water Bill"
    if any(k in lower for k in ["gas", "recreation", "sui"]):
        return "Gas Bill"
    if any(k in lower for k in ["school", "fee", "education", "college", "uni"]):
        return "School Fees"
    if any(k in lower for k in ["tailor", "darzi", "suit", "clothes", "kapray"]):
        return "Tailor"
    if any(k in lower for k in ["cafe", "coffee", "restaurant", "hotel"]):
        return "Cafe"
    if "ali" in lower: return "Ali"
    if "ahmed" in lower: return "Ahmed"
    if "farzam" in lower: return "Farzam"
        
    return raw_name


def _keyword_classify(text: str) -> Dict[str, Any]:
    """Simple regex-based intent classification for offline fallback."""
    lower = text.lower()
    
    # 1. Intent Matching
    detected_intent = "unknown"
    confidence = 0.0
    
    for intent, pattern in _KEYWORD_RULES:
        if re.search(pattern, lower):
            detected_intent = intent
            confidence = 0.65  # Baseline confidence for rule-based matching
            break
    
    if detected_intent == "unknown":
        return {"intent": "unknown", "confidence": 0.0, "entities": {}}

    entities = {}

    # 2. Entity Extraction for specific intents
    if detected_intent == "transfer_money":
        # Amount extraction: handle digits (e.g., "500", "1000")
        amt_match = re.search(r'\b(\d+)\b', lower)
        if amt_match:
            entities["amount"] = int(amt_match.group(1))
        
        mapped_contact = _map_canonical_contact(lower)
        if mapped_contact != lower:
             entities["recipient"] = mapped_contact
                
    return {"intent": detected_intent, "confidence": confidence, "entities": entities}


def classify_intent(text: str) -> Dict[str, Any]:
    """
    Classify intent using Google Gemini Pro.
    Falls back to Rule-based matching if API Key is missing or request fails.
    """
    # 1. Check for Gemini API Key
    if not settings.GOOGLE_API_KEY or "your_gemini_api_key_here" in settings.GOOGLE_API_KEY:
        print("[NLU] Gemini Key missing. Using Rule-based Matcher.")
        return _keyword_classify(text)

    import time
    max_retries = 3
    retry_delay = 1
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)

    for attempt in range(max_retries):
        try:
            prompt = f"""
            You are an AI NLU engine for a banking app called PayTalk. 
            Analyze the user's voice command: "{text}"
            
            Available Intents:
            - check_balance
            - transfer_money (Entities: "amount" (int), "recipient" (string))
            - transaction_history
            - get_account_info
            - confirm
            - cancel
            
            Strict Rules:
            1. Return ONLY valid JSON.
            2. If intent is unclear, return "unknown".
            3. For transfer_money, extract amount as an integer and recipient as a string.
            
            Format: {{
                "intent": "intent_name", 
                "confidence": 0.0-1.0, 
                "entities": {{}},
                "nastaliq_urdu": "The transcription translated to proper Urdu script (Nastaliq). IMPORTANT: If input is Hindi (Devanagari) or Roman Urdu, this field MUST be the Nastaliq Urdu version."
            }}
            """
            
            response = client.models.generate_content(
                model='gemini-3.1-flash-lite-preview',
                contents=prompt,
            )
            resp_text = response.text.strip()
            
            # Clean up markdown
            if "```json" in resp_text:
                resp_text = resp_text.split("```json")[1].split("```")[0].strip()
            elif "```" in resp_text:
                resp_text = resp_text.split("```")[1].strip()

            data = json.loads(resp_text)
            
            entities_data = data.get("entities", {})
            if "recipient" in entities_data:
                entities_data["recipient"] = _map_canonical_contact(entities_data["recipient"])
                
            print(f"[NLU] Gemini Result: {data.get('intent')} ({data.get('confidence')})")
            return {
                "intent": data.get("intent", "unknown") or "unknown",
                "confidence": data.get("confidence", 0.0),
                "entities": entities_data,
                "nastaliq_urdu": data.get("nastaliq_urdu")
            }

        except Exception as e:
            err_str = str(e)
            if ("503" in err_str or "quota" in err_str.lower()) and attempt < max_retries - 1:
                print(f"[NLU] Gemini busy (503/Quota). Retrying in {retry_delay}s... ({attempt+1}/{max_retries})")
                time.sleep(retry_delay)
                retry_delay *= 2
                continue
            
            print(f"[NLU] Gemini Error: {err_str}. Falling back to Rule-based.")
            return _keyword_classify(text)
