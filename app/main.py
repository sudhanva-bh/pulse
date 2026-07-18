from fastapi import FastAPI
from app.routers import auth, conversations, messages, sync

app = FastAPI(title="Pulse API", version="0.1.0")

app.include_router(auth.router)
app.include_router(conversations.router)
app.include_router(messages.router)
app.include_router(sync.router)

@app.get("/health")
def health():
    return {"status": "ok"}