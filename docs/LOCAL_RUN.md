# 本地运行方式

## V0-A 本地自动接听

V0-A 不启动云端服务，APK 也不声明 `INTERNET` 权限。先在仓库根目录运行离线脚本自测：

```powershell
.\scripts\v0_self_test.ps1
```

Windows 上没有 ADB 时，先阅读 [Android SDK License](https://developer.android.com/studio/terms)。明确接受后可安装 Google 官方 Platform-Tools 到仓库隔离目录：

```powershell
.\scripts\v0_setup_platform_tools.ps1 -AcceptAndroidSdkLicense
```

脚本固定稳定版 `37.0.0` 和 Google 仓库校验值，只写入已忽略的 `.tools/android-sdk/`，不会修改系统 `PATH`。也可改用 Android Studio SDK Manager 安装 Platform-Tools。

Android 构建基线使用 JDK 17、Android SDK 35 和 Gradle 8.9。仓库的 [Android V0 workflow](https://github.com/NaritaC/GrandmaCallAgent/actions/workflows/android-v0.yml) 会运行：

```powershell
cd GrandmaBridge
.\gradlew.bat --no-daemon --console=plain :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

Wrapper 会校验 Gradle 8.9 发行包的 SHA-256。CI 通过不代表微信 UI 自动化已通过真机验收。

在安装和启用 GrandmaBridge 前，先保持所有自动化无障碍服务关闭，按 [V0 手机验证指南](V0_PHONE_VALIDATION.md) 采集六组只读来电快照并生成门禁：

```powershell
.\scripts\v0_capture_call_snapshot.ps1 -ExpectedContactRemark V0TEST01 -CallType Voice -ScreenState Unlocked -AcceptPrivateDataCapture -ConfirmAutomationDisabled -ConfirmTargetDeviceMatrix
.\scripts\v0_check_snapshot_gate.ps1 -ConfirmScreenshotsReviewed -OutputPath artifacts/v0-call-snapshots/v0-a-gate.json
```

第一条命令需分别覆盖语音/视频和三种屏幕状态，不能只运行示例一次。门禁通过后，用 Android Studio 打开 `GrandmaBridge/`，同步 Gradle 并安装到备用手机或测试手机。在 App 中：

1. 保存家属维护的唯一微信备注白名单，例如 `V0TEST01`。
2. 手动启用 `GrandmaBridge` 无障碍服务和通知使用权。
3. 保持自动接听开关关闭，先完成权限和负向场景检查。
4. 负向测试通过后再打开自动接听开关，并按指南验证六种来电状态。

具备 JDK 17 或更高版本、Android SDK 35 和 ADB 时也可使用：

```powershell
.\scripts\v0_host_preflight.ps1 -AssertReady
.\scripts\v0_build_install.ps1
.\scripts\v0_device_preflight.ps1 -AssertReady
```

`v0_build_install.ps1` 默认用仓库 Wrapper 构建后安装。已有自己从本仓库 CI 或 Android Studio 生成并解压的 debug APK 时，也可跳过构建：

```powershell
.\scripts\v0_build_install.ps1 -ApkPath C:\path\to\app-debug.apk
```

不要安装来源不明的 APK。脚本会从 `PATH`、`ANDROID_SDK_ROOT`、`ANDROID_HOME` 或 Android Studio 默认 SDK 目录寻找 ADB。

如果连接了多台 Android 设备，先运行 `adb devices`，再给所有设备脚本传入 `-Serial <deviceSerial>`。

## V1 云端服务（V0 不需要）

```powershell
cd GrandmaAgentServer
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
Copy-Item storage\whitelist.example.json storage\whitelist.json
uvicorn grandma_agent_server.main:app --reload --host 127.0.0.1 --port 8000
```

服务启动后检查：

```powershell
curl http://127.0.0.1:8000/healthz
curl http://127.0.0.1:8000/tools
curl http://127.0.0.1:8000/whitelist
```

## V1 服务端白名单配置

编辑 `GrandmaAgentServer/storage/whitelist.json`：

```json
{
  "contacts": [
    {
      "name": "妈妈",
      "aliases": ["妈", "母亲"]
    }
  ]
}
```

联系人名称需要和微信来电通知或来电页显示名一致。可用 `aliases` 增加别名。

## V1 查看运行状态

```powershell
curl http://127.0.0.1:8000/devices
curl http://127.0.0.1:8000/tasks
```

任务日志文件位于：

```text
GrandmaAgentServer/storage/tasks.jsonl
```

## 运行测试

```powershell
cd GrandmaAgentServer
pytest

cd ..\GrandmaBridge
.\gradlew.bat --no-daemon --console=plain :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

本机没有 Android SDK 35 时，请从已配置 SDK 的 Android Studio 运行 Android 单元测试、Lint 和 debug 构建。Android 端仍需结合真机和微信版本做手工测试，重点验证接听按钮、搜索框、联系人结果和音视频菜单文案。
