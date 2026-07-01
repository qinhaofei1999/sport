import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks

from app.core.config import settings
from app.schemas.pose import ProcessResponse
from app.services.mediapipe_service import MediaPipePoseExtractor

router = APIRouter(prefix="/api/video", tags=["video"])

_task_status: dict[str, dict] = {}


@router.post("/upload")
async def upload_video(file: UploadFile = File(...)):
    ext = Path(file.filename).suffix.lower()
    if ext not in settings.allowed_video_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported format: {ext}. Allowed: {settings.allowed_video_extensions}",
        )

    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    task_id = str(uuid.uuid4())[:8]
    save_path = settings.upload_dir / f"{task_id}_{file.filename}"

    content = await file.read()
    if len(content) > settings.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max: {settings.max_upload_size_mb}MB",
        )

    save_path.write_bytes(content)

    return {
        "task_id": task_id,
        "filename": file.filename,
        "path": str(save_path),
        "size_bytes": len(content),
    }


@router.post("/process/{task_id}", response_model=ProcessResponse)
async def process_video(
    task_id: str,
    background_tasks: BackgroundTasks,
    resize_width: int = 1280,
    model_complexity: int | None = None,
):
    upload_dir = settings.upload_dir
    candidates = list(upload_dir.glob(f"{task_id}_*"))
    if not candidates:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")

    video_path = candidates[0]

    _task_status[task_id] = {"status": "queued", "progress": 0.0, "result": None}

    background_tasks.add_task(_run_extraction, task_id, str(video_path), resize_width, model_complexity)

    return ProcessResponse(
        task_id=task_id,
        status="queued",
        message="Processing started. Poll /api/video/status/{task_id} for result.",
    )


@router.get("/status/{task_id}")
async def get_status(task_id: str):
    status = _task_status.get(task_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    return status


def _run_extraction(task_id: str, video_path: str, resize_width: int, model_complexity: int | None):
    _task_status[task_id] = {"status": "processing", "progress": 0.0, "result": None}
    try:
        extractor = MediaPipePoseExtractor(model_complexity=model_complexity)
        result = extractor.extract_video(video_path, resize_width=resize_width)
        extractor.close()
        _task_status[task_id] = {"status": "completed", "progress": 1.0, "result": result}
    except Exception as e:
        _task_status[task_id] = {"status": "failed", "progress": 0.0, "error": str(e)}
