from fastapi import APIRouter, HTTPException
from pathlib import Path

from app.core.config import settings

router = APIRouter(prefix="/api/pose", tags=["pose"])


@router.get("/files")
async def list_processed_files():
    processed_dir = settings.data_processed_dir
    if not processed_dir.exists():
        return {"files": []}
    files = []
    for f in sorted(processed_dir.iterdir()):
        if f.suffix in {".json", ".csv", ".json.gz", ".csv.gz"}:
            files.append({
                "name": f.name,
                "size_bytes": f.stat().st_size,
                "suffix": f.suffix,
            })
    return {"files": files, "total": len(files)}


@router.get("/files/{filename}")
async def get_processed_file(filename: str):
    path = settings.data_processed_dir / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"File {filename} not found")
    content = path.read_text(encoding="utf-8")
    return {"filename": filename, "content": content}


@router.get("/dataset/stats")
async def dataset_stats():
    processed_dir = settings.data_processed_dir
    if not processed_dir.exists():
        return {"total_videos": 0, "total_frames": 0, "detection_rates": []}

    stats = {"total_videos": 0, "total_frames": 0, "detection_rates": []}
    for f in processed_dir.glob("*.json"):
        if f.stat().st_size < 1024:
            continue
        stats["total_videos"] += 1

    return stats
