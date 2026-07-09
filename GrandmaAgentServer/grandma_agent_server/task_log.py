from __future__ import annotations

import json
from pathlib import Path

from .models import TaskLogEntry


class TaskLogger:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def append(self, entry: TaskLogEntry) -> None:
        with self.path.open("a", encoding="utf-8") as file:
            file.write(entry.model_dump_json() + "\n")

    def list_recent(self, limit: int = 100) -> list[dict]:
        if not self.path.exists():
            return []
        lines = self.path.read_text(encoding="utf-8").splitlines()
        recent = lines[-limit:]
        return [json.loads(line) for line in recent if line.strip()]
