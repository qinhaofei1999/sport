# SportPose Flutter App — Setup Guide

## 项目结构
```
sport_app/
├── lib/
│   ├── main.dart                          # 入口
│   ├── models/
│   │   ├── pose_landmark.dart             # 姿态关键点数据模型
│   │   ├── frame_data.dart                # 帧数据模型
│   │   ├── gait_event.dart               # 步态事件模型
│   │   ├── gait_cycle.dart               # 步态周期模型
│   │   └── analysis_result.dart          # 分析结果模型 (VideoMeta/Stats/GaitSummary)
│   ├── services/
│   │   ├── pose_detector_service.dart     # Google ML Kit 姿态检测封装
│   │   ├── gait_analysis_service.dart     # 跑步步态分析 (步频/角度/周期)
│   │   └── swimming_analysis_service.dart # 游泳划水分析
│   ├── ui/
│   │   ├── home_screen.dart              # 首页 (跑步/游泳模式选择)
│   │   ├── camera_screen.dart            # 实时摄像头 + 骨骼覆盖
│   │   └── result_screen.dart            # 分析结果展示
│   └── utils/
│       ├── angle_calculator.dart          # 3D 关节角度计算
│       └── pose_painter.dart             # 骨骼绘制 CustomPainter
├── android/                              # Android 平台代码 (minSdk=21)
├── ios/                                  # iOS 平台代码 (Info.plist 已配相机权限)
├── pubspec.yaml                          # 依赖: camera, google_mlkit_pose_detection, etc.
└── assets/models/                        # MediaPipe .task 模型文件 (可选, ML Kit 内置模型)
```

## 前置要求

### Android
1. 安装 [Android Studio](https://developer.android.com/studio)
2. 安装 Android SDK (Android Studio 向导会提示)
3. 安装 JDK 17+
4. 设置环境变量 `ANDROID_HOME` 指向 SDK 路径
5. 连接 Android 设备 (USB 调试) 或启动模拟器

### iOS (需要 Mac)
1. 安装 Xcode (Mac App Store)
2. 安装 CocoaPods: `sudo gem install cocoapods`
3. 设置 Xcode Command Line Tools
4. 连接 iPhone 或使用模拟器
5. 需要 Apple Developer 账号 ($99/年) 才能真机部署

## 开发流程

### 1. 安装依赖
```bash
cd sport_app
flutter pub get
```

### 2. Android 真机运行
```bash
# 连接 Android 手机 (USB 调试开启)
flutter run
```

### 3. iOS 真机运行 (Mac 上)
```bash
cd sport_app
cd ios && pod install && cd ..
flutter run
```

### 4. 构建 APK
```bash
flutter build apk --debug
# 或 release 版本 (需要签名配置)
flutter build apk --release
```

### 5. 构建 IPA (Mac 上)
```bash
flutter build ios --debug
```

## 应用流程

1. **首页** → 选择"跑步分析"或"游泳分析"
2. **摄像头页面** → 按红色按钮开始录制 → 实时显示骨骼和角度 → 再次按钮停止
3. **分析中** → 显示加载动画
4. **结果页** → 步频/步数/关节角度/事件列表/步态周期

## Android Camera 权限
已在 `AndroidManifest.xml` 中声明摄像头权限。

## iOS 权限
已在 `Info.plist` 中配置 `NSCameraUsageDescription`。

## 关键依赖版本
- `camera: ^0.10.6` — 摄像头访问
- `google_mlkit_pose_detection: ^0.12.1` — 姿态检测 (BlazePose)
- `path_provider: ^2.1.5` — 文件存储
- `permission_handler: ^11.4.0` — 权限处理
- `provider: ^6.1.2` — 状态管理 (预留)
