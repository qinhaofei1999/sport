import sys
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions

model_path = "models/pose_landmarker_lite.task"

options = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model_path),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=1,
    min_pose_detection_confidence=0.5,
)
landmarker = vision.PoseLandmarker.create_from_options(options)

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

SKELETON = [
    (11, 12), (12, 24), (24, 23), (23, 11),
    (11, 13), (13, 15), (12, 14), (14, 16),
    (23, 25), (25, 27), (27, 29), (29, 31),
    (24, 26), (26, 28), (28, 30), (30, 32),
]

def calc_angle(a, b, c):
    v1 = np.array([a[0]-b[0], a[1]-b[1]])
    v2 = np.array([c[0]-b[0], c[1]-b[1]])
    dot = np.dot(v1, v2)
    n = np.linalg.norm(v1) * np.linalg.norm(v2)
    return np.degrees(np.arccos(np.clip(dot/n, -1, 1))) if n > 0 else 0

video_path = sys.argv[1] if len(sys.argv) > 1 else 0
cap = cv2.VideoCapture(video_path)
if not cap.isOpened():
    cap = cv2.VideoCapture("Test/run/00.mp4")

print("按 ESC 退出，实时显示骨骼 + 关节角度")
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    ts = int(cap.get(cv2.CAP_PROP_POS_MSEC))
    result = landmarker.detect_for_video(mp_img, ts)

    if result and result.pose_landmarks:
        lm = result.pose_landmarks[0]
        h, w = frame.shape[:2]
        pts = [(int(lm[i].x * w), int(lm[i].y * h)) for i in range(33)]

        for i, j in SKELETON:
            cv2.line(frame, pts[i], pts[j], (0, 255, 0), 2)

        for p in pts:
            cv2.circle(frame, p, 3, (0, 0, 255), -1)

        knee_l = calc_angle(pts[23], pts[25], pts[27])
        knee_r = calc_angle(pts[24], pts[26], pts[28])
        ankle_l = calc_angle(pts[25], pts[27], pts[31])
        ankle_r = calc_angle(pts[26], pts[28], pts[32])

        cv2.putText(frame, f"Knee L: {knee_l:.0f}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        cv2.putText(frame, f"Knee R: {knee_r:.0f}", (10, 55),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
        cv2.putText(frame, f"Ankle L: {ankle_l:.0f}", (10, 80),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        cv2.putText(frame, f"Ankle R: {ankle_r:.0f}", (10, 105),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)

    cv2.imshow("MediaPipe Pose - Realtime", frame)
    if cv2.waitKey(1) == 27:
        break

cap.release()
cv2.destroyAllWindows()
landmarker.close()
