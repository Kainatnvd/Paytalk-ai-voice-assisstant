from fastapi import FastAPI
from app.database.base import Base
from app.database.database import engine

# Import models so SQLAlchemy registers them
from app.models import user, transaction, otp

app = FastAPI(title="PayTalk API")

Base.metadata.create_all(bind=engine)

@app.get("/")
def root():
    return {"message": "PayTalk Backend Running"}