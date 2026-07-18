import logging

import numpy as np
from scipy.signal import savgol_filter

from app.services.mediapipe_service import MediaPipePoseExtractor, LANDMARK_NAMES

logger = logging.getLogger(__name__)

_LANDMARK_IDS = {name: i for i, name in enumerate(LANDMARK_NAMES)}

LWRI = _LANDMARK_IDS["left_wrist"]
RWRI = _LANDMARK_IDS["right_wrist"]
LELB = _LANDMARK_IDS["left_elbow"]
RELB = _LANDMARK_IDS["right_elbow"]
LSHO = _LANDMARK_IDS["left_shoulder"]
RSHO = _LANDMARK_IDS["right_shoulder"]
LHIP = _LANDMARK_IDS["left_hip"]
RHIP = _LANDMARK_IDS["right_hip"]
NOSE = _LANDMARK_IDS["nose"]


def _calc_joint_angles(landmarks: list[dict]) -> dict:
    lm = {item["id"]: item for item in landmarks}

    def angle(p1_id: int, vertex_id: int, p2_id: int) -> float | None:
        if p1_id not in lm or vertex_id not in lm or p2_id not in lm:
            return None
        v1 = np.array([
            lm[p1_id]["x"] - lm[vertex_id]["x"],
            lm[p1_id]["y"] - lm[vertex_id]["y"],
            lm[p1_id]["z"] - lm[vertex_id]["z"],
        ])
        v2 = np.array([
            lm[p2_id]["x"] - lm[vertex_id]["x"],
            lm[p2_id]["y"] - lm[vertex_id]["y"],
            lm[p2_id]["z"] - lm[vertex_id]["z"],
        ])
        dot = np.dot(v1, v2)
        norm = np.linalg.norm(v1) * np.linalg.norm(v2)
        if norm == 0:
            return None
        cos_a = np.clip(dot / norm, -1.0, 1.0)
        return round(float(np.degrees(np.arccos(cos_a))), 2)

    def shoulder_zuo() -> float | None:
        if LSHO not in lm or RHIP not in lm:
            return None
        return round(float((1 - lm[LSHO]["z"]) * 90), 2)

    body_roll = 0.0
    if LSHO in lm and RSHO in lm:
        body_roll = round(float((lm[LSHO]["z"] - lm[RSHO]["z"]) * 180), 2)

    return {
        "elbow_left": angle(LSHO, LELB, LWRI),
        "elbow_right": angle(RSHO, RELB, RWRI),
        "shoulder_left": angle(LHIP, LSHO, LELB),
        "shoulder_right": angle(RHIP, RSHO, RELB),
        "body_roll": body_roll,
    }


def _extract_signal(
    frames: list[dict], landmark_id: int, attr: str = "y"
) -> np.ndarray:
    vals = []
    for f in frames:
        if not f.get("detected") or not f.get("landmarks"):
            vals.append(np.nan)
        else:
            vals.append(f["landmarks"][landmark_id][attr])
    return np.array(vals, dtype=float)


def _detect_strokes(
    wrist_y: np.ndarray, fps: float, min_distance_sec: float = 0.3
) -> list[int]:
    mask = ~np.isnan(wrist_y)
    if mask.sum() < 10:
        return []
    clean = wrist_y.copy()
    clean[~mask] = np.nanmedian(wrist_y[mask])

    window = min(11, max(5, mask.sum() - (1 - mask.sum() % 2)))
    if window < 5:
        window = 5
    if window % 2 == 0:
        window += 1
    if window < len(clean):
        clean = savgol_filter(clean, window_length=window, polyorder=2)

    mean = np.mean(clean)
    std = np.std(clean)
    threshold = mean - std * 0.5
    min_distance = int(min_distance_sec * fps)

    strokes = []
    for i in range(1, len(clean) - 1):
        if (
            clean[i] < threshold
            and clean[i] < clean[i - 1]
            and clean[i] < clean[i + 1]
        ):
            if not strokes or i - strokes[-1] >= min_distance:
                strokes.append(i)
    return strokes


class SwimmingAnalyzer:
    def __init__(self, model_complexity: int | None = None):
        self._extractor = MediaPipePoseExtractor(model_complexity=model_complexity)

    def analyze_video(
        self,
        video_path: str,
        resize_width: int | None = 1280,
        max_frames: int | None = None,
    ) -> dict:
        pose_result = self._extractor.extract_video(
            video_path, resize_width=resize_width, max_frames=max_frames,
        )
        frames = pose_result["frames"]
        meta = pose_result["video_meta"]
        fps = meta["fps"]

        frame_swim = []
        for f in frames:
            angles = _calc_joint_angles(f.get("landmarks", [])) if f.get("detected") else {}
            frame_swim.append({
                "frame": f["frame"],
                "timestamp": f["timestamp"],
                "detected": f["detected"],
                "angles": angles,
            })

        lwrist_y = _extract_signal(frames, LWRI, "y")
        rwrist_y = _extract_signal(frames, RWRI, "y")
        left_strokes = _detect_strokes(lwrist_y, fps)
        right_strokes = _detect_strokes(rwrist_y, fps)

        events = []
        for p in left_strokes:
            events.append({
                "frame": frames[p]["frame"],
                "timestamp": frames[p]["timestamp"],
                "side": "left",
                "event_type": "stroke",
            })
        for p in right_strokes:
            events.append({
                "frame": frames[p]["frame"],
                "timestamp": frames[p]["timestamp"],
                "side": "right",
                "event_type": "stroke",
            })
        events.sort(key=lambda e: e["frame"])
        for i, e in enumerate(events):
            e["event_id"] = i

        total_strokes = len(events)
        duration = meta["duration_sec"]
        if max_frames:
            duration = min(duration, max_frames / fps)
        stroke_rate = round((total_strokes / duration) * 60, 1) if duration > 0 and total_strokes >= 2 else 0.0

        all_angles = [fs["angles"] for fs in frame_swim if fs["detected"]]

        def avg_angle(key: str) -> float | None:
            vals = [a[key] for a in all_angles if a.get(key) is not None]
            return round(float(np.mean(vals)), 2) if vals else None

        summary = {
            "total_strokes": total_strokes,
            "stroke_rate_spm": stroke_rate,
            "duration_sec": round(duration, 2),
            "avg_elbow_angle_left": avg_angle("elbow_left"),
            "avg_elbow_angle_right": avg_angle("elbow_right"),
            "avg_shoulder_angle_left": avg_angle("shoulder_left"),
            "avg_shoulder_angle_right": avg_angle("shoulder_right"),
            "avg_body_roll": avg_angle("body_roll"),
        }

        return {
            "video_meta": meta,
            "stats": {
                **pose_result["stats"],
                "swim_events": len(events),
                "stroke_rate_spm": stroke_rate,
            },
            "frames": frame_swim,
            "events": events,
            "summary": summary,
        }

    def close(self):
        self._extractor.close()
