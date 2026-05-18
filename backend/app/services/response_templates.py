"""
Bilingual response templates – Urdu and English.
All user-facing text goes through these functions.
"""


def balance_response(amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"Your balance is PKR {amount}."
    return f"آپ کا بیلنس {amount} روپے ہے۔"


def transfer_success(recipient: str, amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"PKR {amount} has been sent to {recipient} successfully."
    return f"{recipient} کو {amount} روپے بھیج دیے گئے ہیں۔"


def transfer_failed(lang: str = "ur") -> str:
    if lang == "en":
        return "Transaction failed. Please try again."
    return "ٹرانزیکشن فیل ہو گئی ہے۔ دوبارہ کوشش کریں۔"


def otp_sent(lang: str = "ur") -> str:
    if lang == "en":
        return "An OTP has been sent to your registered phone number."
    return "آپ کے نمبر پر او ٹی پی بھیج دیا گیا ہے۔"


def auth_failed(lang: str = "ur") -> str:
    if lang == "en":
        return "Verification failed. Please try again."
    return "تصدیق ناکام ہو گئی۔ دوبارہ کوشش کریں۔"


def confirm_transfer_prompt(recipient: str, amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"You want to send PKR {amount} to {recipient}. Please confirm."
    return f"کیا آپ {recipient} کو {amount} روپے بھیجنا چاہتے ہیں؟ براہ کرم تصدیق کریں۔"


def account_locked(minutes: int = 15, lang: str = "ur") -> str:
    if lang == "en":
        return f"Account locked due to multiple failed attempts. Try again in {minutes} minutes."
    return f"اکاؤنٹ {minutes} منٹ کے لیے بند ہو گیا ہے۔ بعد میں کوشش کریں۔"


def transaction_history_intro(count: int, lang: str = "ur") -> str:
    if lang == "en":
        return f"Here are your last {count} transactions."
    return f"آپ کی پچھلی {count} ٹرانزیکشنز یہ ہیں۔"


def unknown_intent(lang: str = "ur") -> str:
    if lang == "en":
        return "Sorry, I did not understand that. Please try again."
    return "معاف کیجیے گا، مجھے سمجھ نہیں آیا۔ دوبارہ بولیں۔"


def insufficient_balance(balance: str, amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"Insufficient balance. Your balance is PKR {balance} but you are trying to send PKR {amount}."
    return f"آپ کا بیلنس ناکافی ہے۔ آپ کا بیلنس {balance} روپے ہے لیکن آپ {amount} روپے بھیجنا چاہتے ہیں۔"


