# SportPose

AI 运动姿态分析 App（Flutter）

## 环境要求

- Flutter 3.x
- Android Studio（含 Android SDK）
- 可选：Visual Studio（用于 Windows 桌面端）

## 快速开始（Android 模拟器）

### 1. 启动模拟器

```powershell
# 查看已有 AVD 列表
flutter emulators

# 启动模拟器（如果还没有 AVD，先创建）
flutter emulators --launch flutter_emulator

# 如果没有 AVD，手动创建
flutter emulators --create flutter_emulator

# 或者直接用 Android Studio 创建：
# Tools → Device Manager → Create device
```

### 2. 运行 App

```powershell
cd sport_app

# 确保模拟器已启动并连接
flutter devices

# 运行 App（会自动选择模拟器）
flutter run

# 如果多个设备，指定设备 ID
flutter run --device-id emulator-5554
```

### 3. 首次启动说明

- 首次运行需下载 Gradle 依赖，耗时 3~10 分钟
- App 启动后会请求**摄像头权限**，请允许
- 模拟器默认提供虚拟摄像头场景，可直接体验

## 构建 iOS（云端编译，无需 Mac）

通过 **Codemagic** 云平台编译 iOS App，构建成功后自动上传到 **TestFlight**，即可下载到 iPhone。

### 前置条件

- Apple Developer 付费账号（$99/年）
- 代码已推送到 Git 仓库（Codemagic 支持 GitLab / GitHub / Bitbucket）

### 一次性配置（首次约 30 分钟）

1. **注册 Bundle ID**：https://developer.apple.com/account/resources/identifiers
   → 添加 `com.sportpose.sportApp`

2. **创建 App Store Connect 应用记录**：https://appstoreconnect.apple.com → My Apps → 新建 App，选择你注册的 Bundle ID

3. **生成 App Store Connect API Key**：https://appstoreconnect.apple.com/access/api
   → 创建密钥（勾选 App Manager 权限）→ 下载 `.p8` 文件，记录 Key ID 和 Issuer ID

4. **在 Codemagic 中配置**：
   - 注册账号 → https://codemagic.io ，导入 Git 仓库
   - **Team → Integrations → Developer Portal**：添加 App Store Connect API key（Integration 名称填 `sportpose_appstore`，对应 `codemagic.yaml` 里的配置）
   - **App Settings → Environment variables**：创建变量组 `appstore_credentials`，包含：
     - `APP_STORE_CONNECT_PRIVATE_KEY`（`.p8` 文件内容）
     - `APP_STORE_CONNECT_KEY_IDENTIFIER`
     - `APP_STORE_CONNECT_ISSUER_ID`
     - `CERTIFICATE_PRIVATE_KEY`（分发证书的私钥，Codemagic 首次自动生成后会提供下载）
   - **App Settings → codemagic.yaml settings**：把签名证书生成方式设为 App Store Connect API key（自动签名）

5. **修改 `codemagic.yaml` 中的通知邮箱**（`email.recipients`）

### 触发编译

推送代码到 `main` 分支即可自动触发：

```bash
git push origin main
```

或在 Codemagic 上手动点 **Start new build**。

### 下载到 iPhone

1. 构建成功后进入 TestFlight 上传流程（post-processing 自动完成）
2. iPhone 上安装 **TestFlight** App，登录同一个 Apple ID
3. 首次上传后需在 App Store Connect → TestFlight → 构建版本，完成**出口合规**确认（加密选项，若只用 HTTPS 选"不适用"）
4. 在 TestFlight 中接受并安装 App（Internal 组内测无需 Beta 审核）

> 注意：本地（Windows）无法执行 `flutter build ios`，此命令只能在 macOS 上运行。

## 项目结构

```
sport_app/lib/
├── main.dart                    # 入口
├── models/                      # 数据模型
│   ├── pose_landmark.dart
│   ├── frame_data.dart
│   ├── gait_event.dart
│   ├── gait_cycle.dart
│   └── analysis_result.dart
├── services/                    # 业务逻辑
│   ├── pose_detector_service.dart
│   ├── gait_analysis_service.dart
│   └── swimming_analysis_service.dart
├── ui/                          # 界面
│   ├── home_screen.dart
│   ├── camera_screen.dart
│   └── result_screen.dart
└── utils/                       # 工具
    ├── angle_calculator.dart
    └── pose_painter.dart
```
