# TechTree Integration

## Purpose

The TechTree integration connects this repo to the shared TechTree knowledge vault at `X:\Data\Projects\TechTree`. It gives agents a project-local documentation guide, a manifest that identifies the repo to TechTree, and a session-autopilot workflow for recording meaningful implementation work.

## Components

- `TECHTREE.md` is the project manifest. It records the project id, TechTree root, docs root, installed packages, and autopilot settings.
- `.techtree/config.json` is the machine-readable package and autopilot config used by TechTree tooling.
- `AGENTS.md` and `CLAUDE.md` contain the installed project guidance blocks for Codex and Claude.
- `In a Bottle-docs` is the focused local Obsidian vault for feature guides, system notes, logic notes, troubleshooting, dev notes, and user notes.
- `X:\Data\Projects\TechTree\tools\techtree_autopilot.py` manages begin, checkpoint, finish, status, and flush commands for work blocks.

## Data Or Control Flow

1. At the start of implementation work, run `begin` with the project root, task title, and agent name.
2. During work, record checkpoints after meaningful planning, implementation, tests, or decisions.
3. Keep notes in `In a Bottle-docs` current for any feature, system, logic path, or user-facing behavior changed by the task.
4. Before wrapping, run `finish` so the local dev note and shared TechTree session trail are written.
5. If the capture API is unavailable, queued envelopes stay under `.techtree/outbox` until `flush` can replay them.

## Operational Notes

- Installed packages: `project-docs-guide` and `session-autopilot`.
- `session-autopilot` depends on `project-docs-guide`, so local docs are part of the done state for implementation work.
- The local docs guide should be searched before creating new notes; update existing notes when they are the closest match.
- The capture API is configured for `http://127.0.0.1:8765` and reads its token from `TECHTREE_CAPTURE_TOKEN`.
- Existing project daily logs under `Log/YYYY-MM-DD.md` still apply; TechTree adds the docs vault and shared session trail rather than replacing them.

## Related Notes

- [System Index](System%20Index.md)
- [Iteration Log](../05%20Dev%20Notes/Iteration%20Log.md)
- [Project Docs Home](../00%20Home/Home.md)

## Change Log

- 2026-05-09 02:55 - Documented the newly installed TechTree project integration and session-autopilot workflow.
