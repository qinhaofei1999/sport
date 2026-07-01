import json
import csv
from pathlib import Path

import pandas as pd


def export_json(data: dict, output_path: str | Path, indent: int | None = None):
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=indent)
    return path


def export_csv(data: dict, output_path: str | Path):
    rows = []
    for frame in data["frames"]:
        row = {
            "frame": frame["frame"],
            "timestamp": frame["timestamp"],
            "detected": frame["detected"],
        }
        for lm in frame.get("landmarks", []):
            row[f"x_{lm['name']}"] = lm["x"]
            row[f"y_{lm['name']}"] = lm["y"]
            row[f"z_{lm['name']}"] = lm["z"]
            row[f"vis_{lm['name']}"] = lm["visibility"]
        rows.append(row)

    df = pd.DataFrame(rows)

    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False)
    return path


def export_compact_json(data: dict, output_path: str | Path):
    landmarks_names = [
        "nose", "left_eye_inner", "left_eye", "left_eye_outer",
        "right_eye_inner", "right_eye", "right_eye_outer",
        "left_ear", "right_ear", "mouth_left", "mouth_right",
        "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
        "left_wrist", "right_wrist", "left_pinky", "right_pinky",
        "left_index", "right_index", "left_thumb", "right_thumb",
        "left_hip", "right_hip", "left_knee", "right_knee",
        "left_ankle", "right_ankle", "left_heel", "right_heel",
        "left_foot_index", "right_foot_index",
    ]

    compact = {
        "meta": data["video_meta"],
        "stats": data.get("stats", {}),
        "frames": [],
    }

    for frame in data["frames"]:
        f = {
            "f": frame["frame"],
            "t": frame["timestamp"],
            "d": 1 if frame["detected"] else 0,
        }
        lms = []
        for lm in frame.get("landmarks", []):
            lms.extend([lm["x"], lm["y"], lm["z"], lm["visibility"]])
        f["lms"] = lms
        compact["frames"].append(f)

    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(compact, f, ensure_ascii=False)

    return path
