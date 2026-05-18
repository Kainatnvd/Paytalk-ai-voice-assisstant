from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from jose import jwt

from app.core.config import settings

def get_user_identifier(request: Request) -> str:
    """Extract user ID from JWT if present, fallback to IP."""
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            user_id = payload.get("sub")
            if user_id:
                return f"user:{user_id}"
        except Exception:
            pass
    
    # Fallback to IP if no valid token
    return f"ip:{get_remote_address(request)}"

# Default limiter (by IP)
limiter = Limiter(key_func=get_remote_address)

# User-based limiter (by user ID in JWT, fallback to IP)
user_limiter = Limiter(key_func=get_user_identifier)
