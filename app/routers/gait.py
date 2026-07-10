import uuid
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, File, HTTPException, UploadFile

from app.core.config import settings
from app.schemas.pose import ProcessResponse
from app.services.gait_analysis_service import GaitAnalyzer

router = APIRouter(prefix="/api/gait", tags=["gait"])

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
    save_path = settings.upload_dir / f"gait_{task_id}_{file.filename}"
    content = await file.read()
    if len(content) > settings.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large. Max: {settings.max_upload_size_mb}MB")
    save_path.write_bytes(content)
    return {"task_id": task_id, "filename": file.filename, "path": str(save_path), "size_bytes": len(content)}


@router.post("/analyze/{task_id}", response_model=ProcessResponse)
async def analyze_gait(
    task_id: str,
    background_tasks: BackgroundTasks,
    resize_width: int = 1280,
    model_complexity: int | None = None,
):
    candidates = list(settings.upload_dir.glob(f"gait_{task_id}_*"))
    if not candidates:
        candidates = list(settings.upload_dir.glob(f"{task_id}_*"))
    if not candidates:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    video_path = candidates[0]
    _task_status[task_id] = {"status": "queued", "progress": 0.0, "result": None}
    background_tasks.add_task(_run_analysis, task_id, str(video_path), resize_width, model_complexity)
    return ProcessResponse(
        task_id=task_id,
        status="queued",
        message="Gait analysis started. Poll /api/gait/status/{task_id} for result.",
    )


@router.get("/status/{task_id}")
async def get_status(task_id: str):
    status = _task_status.get(task_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    return status


def _run_analysis(task_id: str, video_path: str, resize_width: int, model_complexity: int | None):
    _task_status[task_id] = {"status": "processing", "progress": 0.0, "result": None}
    try:
        analyzer = GaitAnalyzer(model_complexity=model_complexity)
        result = analyzer.analyze_video(video_path, resize_width=resize_width)
        analyzer.close()
        _task_status[task_id] = {"status": "completed", "progress": 1.0, "result": result}
    except Exception as e:
        logger = __import__("logging").getLogger(__name__)
        logger.exception("Gait analysis failed")
        _task_status[task_id] = {"status": "failed", "progress": 0.0, "error": str(e)}


@router.get("/summary/{task_id}")
async def get_summary(task_id: str):
    status = _task_status.get(task_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    if status["status"] != "completed":
        raise HTTPException(status_code=400, detail=f"Analysis not completed. Status: {status['status']}")
    return status["result"]["summary"]
