import sys
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions
from scipy.signal import savgol_filter

MODE = "running"
if "--mode" in sys.argv:
    idx = sys.argv.index("--mode")
    if idx + 1 < len(sys.argv):
        MODE = sys.argv[idx + 1]

model_path = "models/pose_landmarker_lite.task"
options = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model_path),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=1,
    min_pose_detection_confidence=0.5,
)
landmarker = vision.PoseLandmarker.create_from_options(options)

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

def smooth_win(n):
    if n < 5:
        return n if n % 2 == 1 else n - 1
    w = min(11, n - (1 - n % 2))
    return w if w % 2 == 1 else w - 1

video_path = 0
for a in sys.argv[1:]:
    if a != "--mode" and not a.startswith("-"):
        video_path = a
        break

cap = cv2.VideoCapture(video_path)
if not cap.isOpened():
    cap = cv2.VideoCapture("Test/run/00.mp4")

lwrist_hist = []
rwrist_hist = []
stroke_count_l = 0
stroke_count_r = 0
prev_valley_l = -100
prev_valley_r = -100
mode = MODE

print(f"模式: {mode}  ESC=退出  m=切换模式")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    ts = int(cap.get(cv2.CAP_PROP_POS_MSEC))
    result = landmarker.detect_for_video(mp_img, ts)

    h, w = frame.shape[:2]
    if result and result.pose_landmarks:
        lm = result.pose_landmarks[0]
        pts = [(int(lm[i].x * w), int(lm[i].y * h)) for i in range(33)]

        for i, j in SKELETON:
            cv2.line(frame, pts[i], pts[j], (0, 255, 0), 2)
        for p in pts:
            cv2.circle(frame, p, 3, (0, 0, 255), -1)

        if mode == "running":
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

        elif mode == "swimming":
            elbow_l = calc_angle(pts[11], pts[13], pts[15])
            elbow_r = calc_angle(pts[12], pts[14], pts[16])
            shoulder_l = calc_angle(pts[23], pts[11], pts[13])
            shoulder_r = calc_angle(pts[24], pts[12], pts[14])
            body_roll = (lm[11].z - lm[12].z) * 180

            lwrist = lm[15].y
            rwrist = lm[16].y
            lwrist_hist.append(lwrist)
            rwrist_hist.append(rwrist)
            if len(lwrist_hist) > 60:
                lwrist_hist.pop(0)
                rwrist_hist.pop(0)

            if len(lwrist_hist) >= 10:
                win = smooth_win(len(lwrist_hist))
                if win >= 5 and win <= len(lwrist_hist):
                    l_s = savgol_filter(lwrist_hist, win, 2)
                    r_s = savgol_filter(rwrist_hist, win, 2)
                    ml, sl = np.mean(l_s), np.std(l_s)
                    mr, sr = np.mean(r_s), np.std(r_s)
                    tl = ml - sl * 0.5
                    tr = mr - sr * 0.5

                    li = len(lwrist_hist) - 1
                    if l_s[-1] < tl and l_s[-1] < l_s[-2] and (len(l_s) < 3 or l_s[-1] < l_s[-3]):
                        if li - prev_valley_l > 15:
                            stroke_count_l += 1
                            prev_valley_l = li
                    if r_s[-1] < tr and r_s[-1] < r_s[-2] and (len(r_s) < 3 or r_s[-1] < r_s[-3]):
                        if li - prev_valley_r > 15:
                            stroke_count_r += 1
                            prev_valley_r = li

            total_strokes = stroke_count_l + stroke_count_r
            elapsed = ts / 1000
            spm = round((total_strokes / elapsed) * 60, 1) if elapsed > 0 and total_strokes >= 2 else 0

            cv2.putText(frame, f"Elbow L: {elbow_l:.0f}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            cv2.putText(frame, f"Elbow R: {elbow_r:.0f}", (10, 55),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            cv2.putText(frame, f"Shoulder L: {shoulder_l:.0f}", (10, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            cv2.putText(frame, f"Shoulder R: {shoulder_r:.0f}", (10, 105),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            cv2.putText(frame, f"Body Roll: {body_roll:.1f}", (10, 130),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 255), 2)
            cv2.putText(frame, f"Strokes: L{stroke_count_l} R{stroke_count_r}", (10, 155),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 200, 200), 2)
            cv2.putText(frame, f"Rate: {spm} spm", (10, 180),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    cv2.putText(frame, f"Mode: {mode}", (w - 130, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    cv2.imshow("MediaPipe Pose - Realtime", frame)
    key = cv2.waitKey(1) & 0xFF
    if key == 27:
        break
    elif key == ord('m'):
        mode = "swimming" if mode == "running" else "running"
        print(f"切换到 {mode} 模式")

cap.release()
cv2.destroyAllWindows()
landmarker.close()
