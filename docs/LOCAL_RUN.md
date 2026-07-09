# 本地运行方式

## 云端服务

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

## 白名单配置

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

## Android 端

1. 用 Android Studio 打开 `GrandmaBridge`。
2. 等待 Gradle 同步完成。
3. 安装到模拟器或真机。
4. 设置服务地址：
   - Android 模拟器：`ws://10.0.2.2:8000`
   - 局域网真机：`ws://<电脑 IP>:8000`
5. 在系统设置中启用无障碍服务和通知使用权。
6. 让白名单联系人发起微信语音或视频通话。

## 查看运行状态

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
```

Android 端需要结合真机和微信版本做手工测试，重点验证不同微信版本下接听按钮文本和通知文案。
