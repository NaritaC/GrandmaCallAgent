from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal

from pydantic import BaseModel, Field


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class DeviceEvent(BaseModel):
    type: str
    device_id: str
    timestamp: int | None = None
    payload: dict[str, Any] = Field(default_factory=dict)


class DeviceCommand(BaseModel):
    command_id: str
    type: Literal["accept_call", "safety_denied", "noop"]
    task_id: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)


class WhitelistContact(BaseModel):
    name: str
    aliases: list[str] = Field(default_factory=list)
    note: str | None = None


class SafetyDecision(BaseModel):
    allowed: bool
    reason: str
    action_type: str
    payload: dict[str, Any] = Field(default_factory=dict)


class TaskLogEntry(BaseModel):
    task_id: str
    device_id: str
    event_type: str
    status: Literal["allowed", "blocked", "command_sent", "action_result", "info", "error"]
    reason: str
    created_at: str = Field(default_factory=now_iso)
    payload: dict[str, Any] = Field(default_factory=dict)


class DeviceSnapshot(BaseModel):
    device_id: str
    connected: bool
    last_seen_at: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
