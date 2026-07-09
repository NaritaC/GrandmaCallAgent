# Repository Guidelines

## Project Structure & Module Organization

This repository is a two-part monorepo for a senior-friendly Android call agent.

- `GrandmaBridge/`: Android Kotlin app. Main sources live under `app/src/main/java/com/grandmacallagent/bridge/`; Android resources live under `app/src/main/res/`.
- `GrandmaAgentServer/`: Python FastAPI server. Package code is in `grandma_agent_server/`; tests are in `tests/`; example runtime data is in `storage/`.
- `docs/`: architecture, permissions, local run steps, test checklist, and reference project research.

Keep phase-one behavior scoped to whitelisted WeChat voice/video call handling and device heartbeat reporting.

## Build, Test, and Development Commands

Server setup and run:

```powershell
cd GrandmaAgentServer
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
Copy-Item storage\whitelist.example.json storage\whitelist.json
uvicorn grandma_agent_server.main:app --reload --host 0.0.0.0 --port 8000
```

Server tests:

```powershell
cd GrandmaAgentServer
pytest
```

Android: open `GrandmaBridge/` in Android Studio, sync Gradle, then run on a device or emulator. The current environment may not include a global `gradle` command.

## Coding Style & Naming Conventions

Use Kotlin for Android and Python 3.11+ for the server. Prefer clear package-level organization over large utility files. Kotlin classes use `PascalCase`; functions and properties use `camelCase`. Python modules and functions use `snake_case`; Pydantic models use `PascalCase`. Keep comments short and only where they clarify non-obvious safety or platform behavior.

## Testing Guidelines

Add focused tests for `SafetyGate`, whitelist behavior, tool registration, WebSocket message handling, and task logging. Test files should be named `test_*.py`. For Android, document manual device checks in `docs/TEST_CHECKLIST.md`, especially WeChat UI text/resource-id changes across versions.

## Commit & Pull Request Guidelines

The current history uses short imperative commit messages, for example `Add reference project research`. Keep commits scoped and descriptive. Pull requests should include: summary, user impact, safety implications, validation performed, and screenshots only when UI changes are visible.

## Security & Configuration Tips

All high-risk actions must pass `SafetyGate`. Do not add payment, transfer, red packet, message deletion, message sending, friend management, or chat scraping actions. Runtime secrets and real whitelist data must stay out of Git; use `GrandmaAgentServer/storage/whitelist.json` locally.

## Agent 八荣八耻

- 以暗猜接口为耻，以认真查阅为荣。
- 以模糊执行为耻，以寻求确认为荣。
- 以盲想业务为耻，以人类确认为荣。
- 以创造接口为耻，以复用现有为荣。
- 以跳过验证为耻，以主动测试为荣。
- 以破坏架构为耻，以遵循规范为荣。
- 以假装理解为耻，以诚实无知为荣。
- 以盲目修改为耻，以谨慎重构为荣。
