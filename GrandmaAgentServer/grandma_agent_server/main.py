from __future__ import annotations

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from .config import get_settings
from .connection_manager import DeviceConnectionManager
from .models import WhitelistContact
from .safety import SafetyGate
from .task_log import TaskLogger
from .tools import default_tool_registry
from .whitelist import WhitelistStore


def create_app() -> FastAPI:
    settings = get_settings()
    whitelist = WhitelistStore(settings.whitelist_path)
    task_logger = TaskLogger(settings.task_log_path)
    tools = default_tool_registry()
    manager = DeviceConnectionManager(
        whitelist=whitelist,
        safety_gate=SafetyGate(),
        task_logger=task_logger,
        tools=tools,
    )

    app = FastAPI(title="GrandmaAgentServer", version="0.1.0")

    @app.get("/healthz")
    def healthz() -> dict:
        return {"ok": True}

    @app.get("/tools")
    def list_tools() -> list[dict]:
        return tools.list_tools()

    @app.get("/devices")
    def list_devices() -> list[dict]:
        return [device.model_dump() for device in manager.list_devices()]

    @app.get("/tasks")
    def list_tasks(limit: int = 100) -> list[dict]:
        return task_logger.list_recent(limit=limit)

    @app.get("/whitelist")
    def list_whitelist() -> dict:
        return {"contacts": [contact.model_dump() for contact in whitelist.list_contacts()]}

    @app.post("/whitelist/contacts")
    def add_whitelist_contact(contact: WhitelistContact) -> WhitelistContact:
        return whitelist.add_contact(contact)

    @app.websocket("/ws/device/{device_id}")
    async def device_socket(websocket: WebSocket, device_id: str) -> None:
        await manager.connect(device_id, websocket)
        try:
            while True:
                raw_text = await websocket.receive_text()
                await manager.handle_text(device_id, raw_text)
        except WebSocketDisconnect:
            manager.disconnect(device_id)

    return app


app = create_app()
