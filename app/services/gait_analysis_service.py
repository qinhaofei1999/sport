import logging
from pathlib import Path

import numpy as np
from scipy.signal import find_peaks, savgol_filter

from app.services.mediapipe_service import MediaPipePoseExtractor, LANDMARK_NAMES

logger = logging.getLogger(__name__)

_LANDMARK_IDS = {name: i for i, name in enumerate(LANDMARK_NAMES)}

LHIP = _LANDMARK_IDS["left_hip"]
RHIP = _LANDMARK_IDS["right_hip"]
LKNE = _LANDMARK_IDS["left_knee"]
RKNE = _LANDMARK_IDS["right_knee"]
LANK = _LANDMARK_IDS["left_ankle"]
RANK = _LANDMARK_IDS["right_ankle"]
LHEE = _LANDMARK_IDS["left_heel"]
RHEE = _LANDMARK_IDS["right_heel"]
LFOOT = _LANDMARK_IDS["left_foot_index"]
RFOOT = _LANDMARK_IDS["right_foot_index"]
LSHO = _LANDMARK_IDS["left_shoulder"]
RSHO = _LANDMARK_IDS["right_shoulder"]


def _vec(a: dict, b: dict) -> np.ndarray:
    return np.array([b["x"] - a["x"], b["y"] - a["y"], b["z"] - a["z"]])


def _angle_between(v1: np.ndarray, v2: np.ndarray) -> float:
    dot = np.dot(v1, v2)
    norm = np.linalg.norm(v1) * np.linalg.norm(v2)
    if norm == 0:
        return 0.0
    cos_a = np.clip(dot / norm, -1.0, 1.0)
    return float(np.degrees(np.arccos(cos_a)))


def _calc_joint_angles(landmarks: list[dict]) -> dict:
    lm = {item["id"]: item for item in landmarks}

    def angle(p1_id: int, vertex_id: int, p2_id: int) -> float | None:
        if p1_id not in lm or vertex_id not in lm or p2_id not in lm:
            return None
        v1 = _vec(lm[vertex_id], lm[p1_id])
        v2 = _vec(lm[vertex_id], lm[p2_id])
        return round(_angle_between(v1, v2), 2)

    return {
        "hip_left": angle(LSHO, LHIP, LKNE),
        "hip_right": angle(RSHO, RHIP, RKNE),
        "knee_left": angle(LHIP, LKNE, LANK),
        "knee_right": angle(RHIP, RKNE, RANK),
        "ankle_left": angle(LKNE, LANK, LFOOT),
        "ankle_right": angle(RKNE, RANK, RFOOT),
    }


def _extract_pose_array(frames: list[dict], landmark_id: int, attr: str = "y") -> np.ndarray:
    vals = []
    for f in frames:
        if not f.get("detected") or not f.get("landmarks"):
            vals.append(np.nan)
        else:
            vals.append(f["landmarks"][landmark_id][attr])
    arr = np.array(vals, dtype=float)
    mask = ~np.isnan(arr)
    if mask.sum() < 3:
        return arr
    try:
        window = min(11, mask.sum() - (1 - mask.sum() % 2))
        if window >= 5 and window % 2 == 1:
            arr[mask] = savgol_filter(arr[mask], window_length=window, polyorder=2)
    except Exception:
        pass
    return arr


def _detect_steps(
    signal: np.ndarray,
    fps: float,
    height_ratio: float = 0.3,
    distance_sec: float = 0.15,
) -> list[int]:
    mask = ~np.isnan(signal)
    if mask.sum() < 10:
        return []
    clean = signal.copy()
    clean[~mask] = np.nanmedian(signal[mask])
    std = np.nanstd(clean)
    mean = np.nanmean(clean)
    height = std * height_ratio
    distance_frames = max(1, int(distance_sec * fps))
    peaks, _ = find_peaks(clean, height=mean + height, distance=distance_frames)
    return peaks.tolist()


class GaitAnalyzer:
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

        frame_gait = []
        events = []
        lankle_y = _extract_pose_array(frames, LANK, "y")
        rankle_y = _extract_pose_array(frames, RANK, "y")

        for i, f in enumerate(frames):
            angles = _calc_joint_angles(f.get("landmarks", [])) if f.get("detected") else {}
            frame_gait.append({
                "frame": f["frame"],
                "timestamp": f["timestamp"],
                "detected": f["detected"],
                "angles": angles,
                "phase": "unknown",
            })

        left_peaks = _detect_steps(lankle_y, fps)
        right_peaks = _detect_steps(rankle_y, fps)
        all_peaks = sorted(left_peaks + right_peaks)

        for p in left_peaks:
            events.append({
                "frame": frames[p]["frame"],
                "timestamp": frames[p]["timestamp"],
                "side": "left",
                "event_type": "heel_strike",
                "landmark_y": float(rankle_y[p]) if not np.isnan(rankle_y[p]) else None,
            })

        for p in right_peaks:
            events.append({
                "frame": frames[p]["frame"],
                "timestamp": frames[p]["timestamp"],
                "side": "right",
                "event_type": "heel_strike",
            })

        events.sort(key=lambda e: e["frame"])
        for i, e in enumerate(events):
            e["event_id"] = i

        total_steps = len(events)
        duration = meta["duration_sec"]
        if max_frames:
            duration = min(duration, max_frames / fps)
        cadence = round((total_steps / duration) * 60, 1) if duration > 0 and total_steps >= 2 else 0.0

        all_angles = [fg["angles"] for fg in frame_gait if fg["detected"]]

        def avg_angle(key: str) -> float | None:
            vals = [a[key] for a in all_angles if a.get(key) is not None]
            return round(float(np.mean(vals)), 2) if vals else None

        cycles = []
        if len(events) >= 2:
            for i in range(len(events) - 1):
                e0, e1 = events[i], events[i + 1]
                cycles.append({
                    "cycle_id": i,
                    "start_frame": e0["frame"],
                    "end_frame": e1["frame"],
                    "duration_sec": round(e1["timestamp"] - e0["timestamp"], 3),
                    "cadence_spm": round(60.0 / (e1["timestamp"] - e0["timestamp"]), 1)
                    if e1["timestamp"] > e0["timestamp"] else None,
                    "stance_ratio": None,
                    "swing_ratio": None,
                })

        summary = {
            "total_steps": total_steps,
            "cadence_spm": cadence,
            "duration_sec": round(duration, 2),
            "avg_hip_angle_left": avg_angle("hip_left"),
            "avg_hip_angle_right": avg_angle("hip_right"),
            "avg_knee_angle_left": avg_angle("knee_left"),
            "avg_knee_angle_right": avg_angle("knee_right"),
            "avg_ankle_angle_left": avg_angle("ankle_left"),
            "avg_ankle_angle_right": avg_angle("ankle_right"),
        }

        return {
            "video_meta": meta,
            "stats": {
                **pose_result["stats"],
                "gait_events": len(events),
                "cadence_spm": cadence,
            },
            "frames": frame_gait,
            "events": events,
            "summary": summary,
            "cycles": cycles,
        }

    def close(self):
        self._extractor.close()
