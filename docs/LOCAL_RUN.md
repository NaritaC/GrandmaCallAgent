# 本地运行方式

## V0 本地自动化

V0 不需要启动云端服务。先在仓库根目录运行离线脚本自测：

```powershell
.\scripts\v0_self_test.ps1
```

然后用 Android Studio 打开 `GrandmaBridge/`，同步 Gradle并安装到备用手机或测试手机。在 App 中：

1. 保存本地微信显示名白名单。
2. 手动启用 `GrandmaBridge` 无障碍服务和通知使用权。
3. 保持自动接听开关关闭，先完成权限和负向场景检查。
4. 测试时再打开自动接听开关，并按 [V0 手机验证指南](V0_PHONE_VALIDATION.md) 逐场景验证。

具备 Java、Gradle 和 ADB 时也可使用：

```powershell
.\scripts\v0_host_preflight.ps1 -AssertReady
.\scripts\v0_build_install.ps1
.\scripts\v0_device_preflight.ps1 -AssertReady
```

如果连接了多台 Android 设备，先运行 `adb devices`，再给所有设备脚本传入 `-Serial <deviceSerial>`。

## V1 云端服务（V0 不需要）

```powershell
cd GrandmaAgentServer
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
Copy-Item storage\whitelist.example.json storage\whitelist.json
uvicorn grandma_agent_server.main:app --reload --host 0.0.0.0 --port 8000
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
.\gradlew.bat testDebugUnitTest
```

如果仓库没有 Gradle wrapper，请从 Android Studio 运行 Android 单元测试。Android 端仍需结合真机和微信版本做手工测试，重点验证接听按钮、搜索框、联系人结果和音视频菜单文案。
