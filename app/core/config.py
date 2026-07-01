from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Swim Pose API"
    debug: bool = True

    upload_dir: Path = Path("uploads")
    data_raw_dir: Path = Path("data") / "raw"
    data_processed_dir: Path = Path("data") / "processed"
    data_annotations_dir: Path = Path("data") / "annotations"

    mediapipe_model_complexity: int = 2
    mediapipe_min_detection_confidence: float = 0.5
    mediapipe_min_tracking_confidence: float = 0.5

    max_upload_size_mb: int = 500
    allowed_video_extensions: set[str] = {".mp4", ".avi", ".mov", ".mkv", ".webm"}

    class Config:
        env_file = ".env"


settings = Settings()
