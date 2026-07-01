from pydantic import BaseModel


class Landmark(BaseModel):
    id: int
    name: str
    x: float
    y: float
    z: float
    visibility: float


class FramePose(BaseModel):
    frame: int
    timestamp: float
    landmarks: list[Landmark]
    detected: bool = True


class VideoMeta(BaseModel):
    filename: str
    fps: float
    total_frames: int
    duration_sec: float
    width: int
    height: int


class VideoPoseResult(BaseModel):
    video_meta: VideoMeta
    frames: list[FramePose]


class ProcessResponse(BaseModel):
    task_id: str
    status: str
    message: str


class ProcessStatus(BaseModel):
    task_id: str
    status: str
    progress: float
    result: VideoPoseResult | None = None
