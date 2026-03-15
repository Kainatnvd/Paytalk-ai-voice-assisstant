"""
PayTalk FastAPI Application Entry Point
AI-Powered Voice Banking with NFC/NIC Authentication
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import auth, account, transaction, voice, admin
# from app.services.stt_service import get_model   # pre-load Whisper at startup

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
    allow_origins=["*"],       # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
    print("[PayTalk] Starting up – pre-loading Whisper model...")
    # get_model()
    print("[PayTalk] Ready.")


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "PayTalk API", "version": "1.0.0"}
