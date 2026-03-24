import os
import re

files_to_fix = [
    "app/routes/voice.py",
    "app/routes/transaction.py",
    "app/routes/auth.py",
    "app/routes/account.py",
    "app/schemas/user_schema.py",
    "app/services/otp_service.py",
    "app/services/nfc_service.py"
]

for file_path in files_to_fix:
    if not os.path.exists(file_path):
        continue
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Replace current_user.id -> current_user.user_id
    content = content.replace("current_user.id", "current_user.user_id")
    # Replace user.id -> user.user_id
    content = content.replace("user.id", "user.user_id")
    
    if file_path == "app/schemas/user_schema.py":
        content = content.replace("id: int", "user_id: UUID")
        if "from uuid import UUID" not in content:
            content = "from uuid import UUID\n" + content
        content = content.replace("partner_id: Optional[int] = None", "partner_id: UUID")
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

print("Replacement complete.")
