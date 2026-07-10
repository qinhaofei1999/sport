# result.json 数据格式说明

`analyze.py` 分析完成后输出的完整数据结构如下：

## 顶层结构

```json
{
  "result": {
    "video_meta": { ... },
    "stats": { ... },
    "frames": [ ... ],
    "events": [ ... ],
    "summary": { ... },
    "cycles": [ ... ]
  }
}
```

## 字段详解

### 1. video_meta — 视频元信息

```json
{
  "filename": "00.mp4",
  "fps": 29.97,
  "total_frames": 961,
  "duration_sec": 32.07,
  "width": 960,
  "height": 720
}
```

### 2. stats — 统计概览

```json
{
  "frames_processed": 961,    // 处理的总帧数
  "frames_detected": 961,     // 检测到人体的帧数
  "detection_rate": 1.0,      // 检测率（detected / processed）
  "gait_events": 89,          // 检测到的 heel strike 总数
  "cadence_spm": 166.5        // 步频（步/分钟）
}
```

### 3. frames — 每帧关节角度（核心数据）

```json
[
  {
    "frame": 0,
    "timestamp": 0.0,
    "detected": true,
    "angles": {
      "hip_left": 149.32,    // 左侧髋角（度）
      "hip_right": 153.96,   // 右侧髋角（度）
      "knee_left": 73.82,    // 左侧膝角（度）
      "knee_right": 142.38,  // 右侧膝角（度）
      "ankle_left": 85.57,   // 左侧踝角（度）
      "ankle_right": 102.45  // 右侧踝角（度）
    }
  },
  ... 共 961 条
]
```

**角度定义**（三点法）：

| 角度 | 三点（顶点为中点） | 说明 |
|------|-------------------|------|
| 髋角 (Hip) | 肩 → 髋 → 膝 | 躯干与大腿的夹角，站立≈180°，抬腿时减小 |
| 膝角 (Knee) | 髋 → 膝 → 踝 | 大腿与小腿的夹角，伸直≈180°，弯曲时减小 |
| 踝角 (Ankle) | 膝 → 踝 → 脚趾 | 小腿与脚的夹角，站立≈90° |

### 4. events — Heel Strike 事件列表

```json
[
  {
    "event_id": 0,
    "frame": 13,
    "timestamp": 0.43,
    "side": "right",      // 左脚/右脚
    "event_type": "heel_strike"   // 事件类型
  },
  ... 共 89 条
]
```

每次脚跟触地（heel strike）记为一个事件。通过检测踝关节 Y 坐标（上下位置）的波峰来识别。

### 5. summary — 汇总指标

```json
{
  "total_steps": 89,          // 总步数（左+右）
  "cadence_spm": 166.5,       // 步频
  "duration_sec": 32.07,      // 分析时长
  "avg_hip_angle_left": 145.65,   // 左髋平均角度
  "avg_hip_angle_right": 143.94,  // 右髋平均角度
  "avg_knee_angle_left": 101.1,   // 左膝平均角度
  "avg_knee_angle_right": 137.99, // 右膝平均角度
  "avg_ankle_angle_left": 102.25, // 左踝平均角度
  "avg_ankle_angle_right": 108.54 // 右踝平均角度
}
```

### 6. cycles — 步态周期

```json
[
  {
    "cycle_id": 0,
    "start_frame": 13,
    "end_frame": 24,
    "duration_sec": 0.367,     // 周期时长（秒）
    "cadence_spm": 163.5       // 该周期推算步频
  },
  ... 共 88 条
]
```

相邻两次 heel strike 之间定义为一个步态周期。

## 如何自己读取

```python
import json

with open("result.json", encoding="utf-8") as f:
    data = json.load(f)

result = data["result"]

# 看汇总
print(result["summary"])

# 看第 100 帧的角度
print(result["frames"][100]["angles"])

# 看所有左脚事件
left_events = [e for e in result["events"] if e["side"] == "left"]
print(f"左脚触地 {len(left_events)} 次")
```

## 注意事项

- 角度值是 2D 投影角度（不是 3D 真实角度），受拍摄视角影响
- heel strike 检测基于踝关节 Y 坐标波峰，可能与真实触地有 ±1-2 帧偏差
- 左右脚步数差异不一定代表真实步态不对称——拍摄角度、信号噪声都可能导致偏差
