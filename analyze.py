import sys, json, time, os, subprocess, signal, atexit
from pathlib import Path

import requests

BASE_PORT = 8100

MODEL_OPTIONS = {
    0: "Lite（最快，日常测试用）",
    1: "Full（均衡）",
    2: "Heavy（最准，最慢）",
}

def print_banner():
    print("=" * 50)
    print("   SwimPose - 跑步/游泳 姿态分析工具")
    print("=" * 50)

def parse_args():
    video_path = None
    complexity = 0
    for arg in sys.argv[1:]:
        if arg in ("-h", "--help"):
            print("用法: python analyze.py [视频路径] [--model 0|1|2]")
            print("  --model 0  Lite（最快，默认）")
            print("  --model 1  Full（均衡）")
            print("  --model 2  Heavy（最准，最慢）")
            sys.exit(0)
        elif arg == "--model":
            continue
        elif arg in ("0", "1", "2"):
            idx = sys.argv.index(arg)
            if idx > 0 and sys.argv[idx - 1] == "--model":
                complexity = int(arg)
        else:
            video_path = arg
    return video_path, complexity

def find_video():
    path, complexity = parse_args()
    if not path:
        path = input("请输入视频路径（拖拽文件到这里）: ").strip().strip('"')
    p = Path(path)
    if not p.exists():
        print(f"错误：文件不存在 - {path}")
        sys.exit(1)
    return p, complexity

def start_server():
    print("\n1. 启动分析服务...")
    proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--port", str(BASE_PORT)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    atexit.register(lambda: proc.kill())
    for i in range(15):
        try:
            r = requests.get(f"http://localhost:{BASE_PORT}/health", timeout=2)
            if r.status_code == 200:
                print("   服务已启动")
                return proc
        except:
            time.sleep(1)
    print("   服务启动失败")
    proc.kill()
    sys.exit(1)

def upload_video(video_path):
    print("\n2. 上传视频...")
    with open(video_path, "rb") as f:
        r = requests.post(f"http://localhost:{BASE_PORT}/api/gait/upload", files={"file": f})
    data = r.json()
    print(f"   任务ID: {data['task_id']}")
    return data["task_id"]

def analyze(task_id, complexity):
    model_name = MODEL_OPTIONS.get(complexity, "Lite")
    print(f"\n3. 开始分析（{model_name}）...")
    r = requests.post(
        f"http://localhost:{BASE_PORT}/api/gait/analyze/{task_id}",
        params={"resize_width": 960, "model_complexity": complexity}
    )
    if r.status_code != 200:
        print(f"   分析启动失败: {r.json()}")
        sys.exit(1)

    print("   等待", end="", flush=True)
    while True:
        r = requests.get(f"http://localhost:{BASE_PORT}/api/gait/status/{task_id}")
        s = r.json()
        if s["status"] == "completed":
            print(" 完成!")
            return s["result"]
        elif s["status"] == "failed":
            print(f"\n   分析失败: {s.get('error')}")
            sys.exit(1)
        print(".", end="", flush=True)
        time.sleep(2)

def save_result(result, video_name):
    output = Path("result.json")
    with open(output, "w", encoding="utf-8") as f:
        json.dump({"result": result}, f, ensure_ascii=False, indent=2)
    print(f"\n   完整数据已保存到 {output}")

def print_summary(result):
    meta = result["video_meta"]
    s = result["summary"]
    events = result["events"]
    left = sum(1 for e in events if e["side"] == "left")
    right = sum(1 for e in events if e["side"] == "right")

    print()
    print("=" * 50)
    print("  分析结果")
    print("=" * 50)
    print(f"  视频:        {meta['filename']}")
    print(f"  分辨率:      {meta['width']}x{meta['height']}")
    print(f"  时长:        {s['duration_sec']} 秒")
    print(f"  检测率:      {result['stats']['detection_rate']*100:.1f}%")
    print(f"  总步数:      {s['total_steps']} (左脚 {left} / 右脚 {right})")
    print(f"  步频:        {s['cadence_spm']} spm")
    print(f"  平均髋角:    左 {s['avg_hip_angle_left']} / 右 {s['avg_hip_angle_right']}")
    print(f"  平均膝角:    左 {s['avg_knee_angle_left']} / 右 {s['avg_knee_angle_right']}")
    print(f"  平均踝角:    左 {s['avg_ankle_angle_left']} / 右 {s['avg_ankle_angle_right']}")
    print()
    print("  heel strike 事件列表（前 10 条）:")
    print(f"  {'帧号':>5s} {'时间(s)':>8s} {'侧':>4s}")
    print(f"  {'-'*20}")
    for e in events[:10]:
        print(f"  {e['frame']:5d} {e['timestamp']:8.2f} {e['side']:>4s}")
    if len(events) > 10:
        print(f"  ... 共 {len(events)} 条，完整列表见 result.json")
    print()
    print("  详细数据（逐帧角度、所有事件、步态周期）请查看 result.json")

if __name__ == "__main__":
    print_banner()
    video, complexity = find_video()
    server = start_server()
    try:
        tid = upload_video(video)
        result = analyze(tid, complexity)
        save_result(result, video.name)
        print_summary(result)
    finally:
        server.kill()
        print("\n   服务已关闭")
