from __future__ import annotations

import json
import time
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import WebSocket
from pydantic import ValidationError

from .models import DeviceCommand, DeviceEvent, DeviceSnapshot, TaskLogEntry
from .safety import SafetyGate
from .task_log import TaskLogger
from .tools import ToolRegistry
from .whitelist import WhitelistStore


class DeviceConnectionManager:
    def __init__(
        self,
        whitelist: WhitelistStore,
        safety_gate: SafetyGate,
        task_logger: TaskLogger,
        tools: ToolRegistry,
    ) -> None:
        self.whitelist = whitelist
        self.safety_gate = safety_gate
        self.task_logger = task_logger
        self.tools = tools
        self._connections: dict[str, WebSocket] = {}
        self._devices: dict[str, DeviceSnapshot] = {}
        self._recent_call_events: dict[str, float] = {}

    async def connect(self, device_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[device_id] = websocket
        self._mark_device(device_id, connected=True, payload={"event": "connected"})

    def disconnect(self, device_id: str) -> None:
        self._connections.pop(device_id, None)
        self._mark_device(device_id, connected=False, payload={"event": "disconnected"})

    def list_devices(self) -> list[DeviceSnapshot]:
        return list(self._devices.values())

    async def handle_text(self, device_id: str, raw_text: str) -> None:
        try:
            event = DeviceEvent.model_validate(json.loads(raw_text))
        except (json.JSONDecodeError, ValidationError) as exc:
            self._log(
                task_id=str(uuid.uuid4()),
                device_id=device_id,
                event_type="invalid_message",
                status="error",
                reason=str(exc),
                payload={"raw": raw_text},
            )
            return

        if event.device_id != device_id:
            self._log(
                task_id=str(uuid.uuid4()),
                device_id=device_id,
                event_type=event.type,
                status="error",
                reason="device_id_mismatch",
                payload={"path_device_id": device_id, "body_device_id": event.device_id},
            )
            return

        self._mark_device(device_id, connected=True, payload=event.payload)

        if event.type == "heartbeat":
            self._log(
                task_id=str(uuid.uuid4()),
                device_id=device_id,
                event_type=event.type,
                status="info",
                reason="heartbeat_received",
                payload=event.payload,
            )
            return

        if event.type == "incoming_wechat_call":
            await self._handle_incoming_wechat_call(event)
            return

        if event.type == "action_result":
            self._log(
                task_id=str(event.payload.get("task_id") or uuid.uuid4()),
                device_id=device_id,
                event_type=event.type,
                status="action_result",
                reason=str(event.payload.get("reason") or "result_received"),
                payload=event.payload,
            )
            return

        if event.type == "tool_request":
            await self._handle_tool_request(event)
            return

        self._log(
            task_id=str(uuid.uuid4()),
            device_id=device_id,
            event_type=event.type,
            status="info",
            reason="ignored_event_type",
            payload=event.payload,
        )

    async def _handle_incoming_wechat_call(self, event: DeviceEvent) -> None:
        tool = self.tools.get("accept_wechat_call")
        task_id = str(uuid.uuid4())
        if tool is None:
            self._log(task_id, event.device_id, event.type, "blocked", "tool_not_registered", event.payload)
            return

        payload = {
            "app_package": event.payload.get("app_package"),
            "contact_name": event.payload.get("contact_name"),
            "call_type": event.payload.get("call_type"),
            "source": event.payload.get("source"),
        }
        if self._is_duplicate_call_event(event.device_id, payload):
            self._log(task_id, event.device_id, event.type, "info", "duplicate_call_event_ignored", payload)
            return

        decision = self.safety_gate.evaluate(tool.action_type, payload, self.whitelist)
        if not decision.allowed:
            self._log(task_id, event.device_id, event.type, "blocked", decision.reason, payload)
            await self._send_command(
                event.device_id,
                DeviceCommand(
                    command_id=str(uuid.uuid4()),
                    type="safety_denied",
                    task_id=task_id,
                    payload={"reason": decision.reason},
                ),
            )
            return

        command = DeviceCommand(
            command_id=str(uuid.uuid4()),
            type="accept_call",
            task_id=task_id,
            payload=payload,
        )
        self._log(task_id, event.device_id, event.type, "command_sent", decision.reason, payload)
        await self._send_command(event.device_id, command)

    def _is_duplicate_call_event(self, device_id: str, payload: dict[str, Any]) -> bool:
        key = "|".join(
            [
                device_id,
                str(payload.get("app_package") or ""),
                str(payload.get("contact_name") or ""),
                str(payload.get("call_type") or ""),
            ]
        )
        now = time.monotonic()
        last_seen = self._recent_call_events.get(key)
        self._recent_call_events[key] = now
        return last_seen is not None and now - last_seen < 15

    async def _handle_tool_request(self, event: DeviceEvent) -> None:
        task_id = str(uuid.uuid4())
        action_type = str(event.payload.get("action_type") or "")
        payload = dict(event.payload.get("payload") or {})
        decision = self.safety_gate.evaluate(action_type, payload, self.whitelist)
        self._log(
            task_id=task_id,
            device_id=event.device_id,
            event_type=event.type,
            status="allowed" if decision.allowed else "blocked",
            reason=decision.reason,
            payload={"action_type": action_type, "payload": payload},
        )
        if not decision.allowed:
            await self._send_command(
                event.device_id,
                DeviceCommand(
                    command_id=str(uuid.uuid4()),
                    type="safety_denied",
                    task_id=task_id,
                    payload={"reason": decision.reason},
                ),
            )

    async def _send_command(self, device_id: str, command: DeviceCommand) -> None:
        websocket = self._connections.get(device_id)
        if websocket is None:
            self._log(
                task_id=command.task_id or str(uuid.uuid4()),
                device_id=device_id,
                event_type=command.type,
                status="error",
                reason="device_not_connected",
                payload=command.payload,
            )
            return
        await websocket.send_text(command.model_dump_json())

    def _mark_device(self, device_id: str, connected: bool, payload: dict[str, Any]) -> None:
        self._devices[device_id] = DeviceSnapshot(
            device_id=device_id,
            connected=connected,
            last_seen_at=datetime.now(timezone.utc).isoformat(),
            payload=payload,
        )

    def _log(
        self,
        task_id: str,
        device_id: str,
        event_type: str,
        status: str,
        reason: str,
        payload: dict[str, Any],
    ) -> None:
        self.task_logger.append(
            TaskLogEntry(
                task_id=task_id,
                device_id=device_id,
                event_type=event_type,
                status=status,  # type: ignore[arg-type]
                reason=reason,
                payload=payload,
            )
        )
