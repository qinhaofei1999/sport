from pydantic import BaseModel


class JointAngles(BaseModel):
    hip_left: float | None = None
    hip_right: float | None = None
    knee_left: float | None = None
    knee_right: float | None = None
    ankle_left: float | None = None
    ankle_right: float | None = None


class GaitEvent(BaseModel):
    frame: int
    timestamp: float
    side: str
    event_type: str


class FrameGait(BaseModel):
    frame: int
    timestamp: float
    detected: bool
    angles: JointAngles = JointAngles()
    phase: str = "unknown"


class GaitCycleMetrics(BaseModel):
    cycle_id: int
    start_frame: int
    end_frame: int
    duration_sec: float
    cadence_spm: float | None = None
    stance_ratio: float | None = None
    swing_ratio: float | None = None


class GaitSummary(BaseModel):
    total_steps: int
    cadence_spm: float
    duration_sec: float
    avg_hip_angle_left: float | None = None
    avg_hip_angle_right: float | None = None
    avg_knee_angle_left: float | None = None
    avg_knee_angle_right: float | None = None
    avg_ankle_angle_left: float | None = None
    avg_ankle_angle_right: float | None = None


class GaitAnalysisResult(BaseModel):
    video_meta: dict
    stats: dict
    frames: list[FrameGait]
    events: list[GaitEvent]
    summary: GaitSummary
    cycles: list[GaitCycleMetrics] = []
