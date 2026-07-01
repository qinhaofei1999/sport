import logging
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions

logger = logging.getLogger(__name__)

MODEL_MAP = {
    0: "models/pose_landmarker_lite.task",
    1: "models/pose_landmarker_full.task",
    2: "models/pose_landmarker_heavy.task",
}

LANDMARK_NAMES = [
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


def _get_model_path(model_complexity: int) -> str:
    return MODEL_MAP.get(model_complexity, MODEL_MAP[1])


class MediaPipePoseExtractor:
    def __init__(
        self,
        model_complexity: int | None = None,
        min_detection_confidence: float | None = None,
        min_tracking_confidence: float | None = None,
    ):
        complexity = model_complexity if model_complexity is not None else 2
        model_path = _get_model_path(complexity)
        if not Path(model_path).exists():
            raise FileNotFoundError(
                f"Pose model not found at {model_path}. "
                f"Run `python _download_model.py` first."
            )

        self._landmarker = vision.PoseLandmarker.create_from_options(
            vision.PoseLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=model_path),
                running_mode=vision.RunningMode.VIDEO,
                num_poses=1,
                min_pose_detection_confidence=min_detection_confidence or 0.5,
                min_pose_presence_confidence=min_detection_confidence or 0.5,
                min_tracking_confidence=min_tracking_confidence or 0.5,
                output_segmentation_masks=False,
            )
        )

    def extract_frame(self, frame: np.ndarray, timestamp_ms: int) -> dict | None:
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = self._landmarker.detect_for_video(mp_image, timestamp_ms)

        if not result or not result.pose_landmarks:
            return None

        landmarks = result.pose_landmarks[0]
        return {
            "landmarks": [
                {
                    "id": i,
                    "name": LANDMARK_NAMES[i],
                    "x": round(lm.x, 6),
                    "y": round(lm.y, 6),
                    "z": round(lm.z, 6),
                    "visibility": round(lm.visibility, 6),
                }
                for i, lm in enumerate(landmarks)
            ],
        }

    def extract_video(
        self,
        video_path: str,
        resize_width: int | None = 1280,
        start_frame: int = 0,
        max_frames: int | None = None,
    ) -> dict:
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            raise ValueError(f"Cannot open video: {video_path}")

        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        if resize_width:
            scale = resize_width / width
            target_size = (resize_width, int(height * scale))
        else:
            target_size = None

        cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

        frames_data = []
        frame_idx = start_frame
        detected_count = 0

        while True:
            if max_frames and (frame_idx - start_frame) >= max_frames:
                break

            ret, frame = cap.read()
            if not ret:
                break

            if target_size:
                frame = cv2.resize(frame, target_size, interpolation=cv2.INTER_LINEAR)

            timestamp_ms = int(frame_idx / fps * 1000)
            result = self.extract_frame(frame, timestamp_ms)

            frame_entry = {
                "frame": frame_idx,
                "timestamp": round(frame_idx / fps, 4),
                "detected": result is not None,
            }

            if result:
                frame_entry["landmarks"] = result["landmarks"]
                detected_count += 1
            else:
                frame_entry["landmarks"] = []

            frames_data.append(frame_entry)
            frame_idx += 1

        cap.release()

        return {
            "video_meta": {
                "filename": Path(video_path).name,
                "fps": round(fps, 2),
                "total_frames": total_frames,
                "duration_sec": round(total_frames / fps, 2),
                "width": width,
                "height": height,
                "processed_width": target_size[0] if target_size else width,
                "processed_height": target_size[1] if target_size else height,
            },
            "frames": frames_data,
            "stats": {
                "frames_processed": len(frames_data),
                "frames_detected": detected_count,
                "detection_rate": round(detected_count / len(frames_data), 4) if frames_data else 0.0,
            },
        }

    def close(self):
        self._landmarker.close()
