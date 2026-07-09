from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    storage_dir: Path
    whitelist_path: Path
    task_log_path: Path


def get_settings() -> Settings:
    package_root = Path(__file__).resolve().parents[1]
    storage_dir = Path(os.getenv("GRANDMA_STORAGE_DIR", package_root / "storage"))
    whitelist_path = Path(os.getenv("GRANDMA_WHITELIST_PATH", storage_dir / "whitelist.json"))
    task_log_path = Path(os.getenv("GRANDMA_TASK_LOG_PATH", storage_dir / "tasks.jsonl"))
    return Settings(
        storage_dir=storage_dir,
        whitelist_path=whitelist_path,
        task_log_path=task_log_path,
    )
