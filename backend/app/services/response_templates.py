"""
Bilingual response templates – Urdu and English.
All user-facing text goes through these functions.
"""


def balance_response(amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"Your balance is PKR {amount}."
    return f"Aapka balance {amount} rupay hai."


def transfer_success(recipient: str, amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"PKR {amount} has been sent to {recipient} successfully."
    return f"{recipient} ko {amount} rupay bhej diye gaye hain."


def transfer_failed(lang: str = "ur") -> str:
    if lang == "en":
        return "Transaction failed. Please try again."
    return "Transaction fail ho gayi. Dobara koshish karein."


def otp_sent(lang: str = "ur") -> str:
    if lang == "en":
        return "An OTP has been sent to your registered phone number."
    return "Aapke number par OTP bheja gaya hai."


def auth_failed(lang: str = "ur") -> str:
    if lang == "en":
        return "Verification failed. Please try again."
    return "Verification fail ho gayi. Dobara koshish karein."


def confirm_transfer_prompt(recipient: str, amount: str, lang: str = "ur") -> str:
    if lang == "en":
        return f"You want to send PKR {amount} to {recipient}. Please confirm."
    return f"{recipient} ko {amount} rupay bhejna hai? Confirm karo."


def account_locked(minutes: int = 15, lang: str = "ur") -> str:
    if lang == "en":
        return f"Account locked due to multiple failed attempts. Try again in {minutes} minutes."
    return f"Account {minutes} minute ke liye band ho gaya hai. Baad mein koshish karein."


def transaction_history_intro(count: int, lang: str = "ur") -> str:
    if lang == "en":
        return f"Here are your last {count} transactions."
    return f"Aapki pichli {count} transactions yahan hain."


def unknown_intent(lang: str = "ur") -> str:
    if lang == "en":
        return "Sorry, I did not understand that. Please try again."
    return "Maafi chahta hoon, mujhe samajh nahi aaya. Dobara bolein."
