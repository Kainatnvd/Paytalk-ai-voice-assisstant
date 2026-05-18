"""
PayTalk FastAPI Application Entry Point
AI-Powered Voice Banking with NFC/NIC Authentication
"""
import logging
import traceback
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.routes import auth, account, transaction, voice, admin
from app.services.stt_service import get_model   # pre-load Whisper at startup
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from app.core.rate_limit import limiter

app = FastAPI(
    title="PayTalk API",
    description="AI-Powered Voice Banking with NFC/NIC Authentication",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:63068", "http://localhost", "http://127.0.0.1", "http://localhost:8000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Rate Limiting ─────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ── Global Exception Handler ──────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Safe error handling: prevents stack traces, database details, or file paths 
    from leaking to the client. Returns a generic 500 JSON response.
    """
    # Log the real error securely on the backend for developers
    logging.error(f"Unhandled Server Error at {request.url.path}: {exc}\n{traceback.format_exc()}")
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "internal_server_error",
            "message": "An unexpected error occurred. Please try again later."
        },
    )

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(account.router)
app.include_router(transaction.router)
app.include_router(voice.router)
app.include_router(admin.router)


# ── Startup: pre-load Whisper model ──────────────────────────────────────────
@app.on_event("startup")
async def startup_event():
    print("[PayTalk] Starting up...")
    get_model()  # Pre-load Whisper at startup (commented out to prevent hang)
    print("[PayTalk] Ready.")


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "PayTalk API", "version": "1.0.0"}

# Verified: Whisper=Small, TTS=Piper, NLU=Gemini-1.5
