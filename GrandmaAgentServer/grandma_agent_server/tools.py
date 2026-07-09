from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ToolDefinition:
    name: str
    action_type: str
    description: str
    risk_level: str


class ToolRegistry:
    def __init__(self) -> None:
        self._tools: dict[str, ToolDefinition] = {}

    def register(self, tool: ToolDefinition) -> None:
        self._tools[tool.name] = tool

    def get(self, name: str) -> ToolDefinition | None:
        return self._tools.get(name)

    def list_tools(self) -> list[dict]:
        return [
            {
                "name": tool.name,
                "action_type": tool.action_type,
                "description": tool.description,
                "risk_level": tool.risk_level,
            }
            for tool in self._tools.values()
        ]


def default_tool_registry() -> ToolRegistry:
    registry = ToolRegistry()
    registry.register(
        ToolDefinition(
            name="accept_wechat_call",
            action_type="accept_call",
            description="Accept a whitelisted WeChat voice/video incoming call.",
            risk_level="guarded_low",
        )
    )
    return registry
