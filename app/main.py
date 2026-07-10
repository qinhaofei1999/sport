import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.routers import video, pose, gait

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Sport pose estimation API using MediaPipe BlazePose (swimming + running gait)",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(video.router)
app.include_router(pose.router)
app.include_router(gait.router)


@app.get("/health")
async def health():
    return {"status": "ok", "app": settings.app_name, "debug": settings.debug}
