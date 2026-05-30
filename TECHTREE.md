---
techtree_manifest: 1
project_id: in-a-bottle
project_name: 'In a Bottle'
techtree_root: 'X:\Data\Projects\TechTree'
source_root: .
source_remote: 'https://github.com/Seasighed/In-a-Bottle.git'
default_branch: 'main'
tools: []
languages: []
contribution_policy: meaningful_sessions
packages:
  - project-docs-guide
  - session-autopilot
documentation_policy: 'backfill_before_finish'
docs_root: 'In a Bottle-docs'
vendors:
  - codex
  - claude
autopilot_enabled: true
autopilot_mode: continuous_work_block
autopilot_idle_minutes: 45
---

# TechTree Manifest

This project links back to the shared TechTree vault at `X:\Data\Projects\TechTree`.

## Local Documentation Workflow

- The project guide lives in `In a Bottle-docs`.
- Before finishing feature or system work, search the guide for relevant docs.
- If the right note does not exist, create it from `90 Templates`.
- If behavior changed, update the related user-facing or troubleshooting note too.
- Add a concise `## Change Log` bullet to every changed docs note.

## Session Autopilot Workflow

- Start work with `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py begin --project-root "X:\Data\Projects\In a Bottle" --task "<task>" --agent <agent>`.
- Add checkpoints after meaningful planning, implementation, tests, milestone changes, or decisions.
- Finish the work block with `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py finish --project-root "X:\Data\Projects\In a Bottle" --summary "<what changed>"`.
- If the capture API is offline, queued envelopes stay in `.techtree/outbox` until `flush` replays them.

## Shared TechTree Workflow

At the end of meaningful coding sessions, contribute durable learnings back to the shared TechTree vault using the workflow in `X:\Data\Projects\TechTree\AGENTS.md`.
