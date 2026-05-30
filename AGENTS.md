# Agent Instructions

<!-- TechTree package: project-docs-guide start -->
## TechTree Project Documentation Rules

This project uses the TechTree `project-docs-guide` package.

- Read `TECHTREE.md` for the project manifest and TechTree link.
- Keep the project guide in `In a Bottle-docs`.
- Treat documentation as part of done for feature, system, and logic work.

### Required Workflow

1. Identify the feature, system, or logic path touched by the task.
2. Search `In a Bottle-docs` for an existing note before making assumptions.
3. If the relevant docs are missing or stale, create or update them before considering the task complete.
4. Record technical explanations, operating rules, state flow, edge cases, and implementation notes.
5. If the change affects user behavior, update the matching note in `06 User Notes`.
6. Add a concise `## Change Log` bullet with a local timestamp to every changed project-doc note.

### Where To Put Information

- `01 Feature Guides`: important features, user-visible workflows, and important editor surfaces.
- `02 Systems`: architecture, integrations, services, pipelines, and cross-cutting technical systems.
- `03 Logic`: rules, state machines, algorithms, and behavior constraints that deserve precise explanation.
- `04 Troubleshooting`: failure modes, debugging steps, gotchas, and recovery notes.
- `05 Dev Notes`: iteration logs, reasoning snapshots, implementation tradeoffs, and milestone progress.
- `06 User Notes`: concise user-facing guidance, operator notes, and behavior changes people should know.
- `90 Templates`: seed structures for new notes when no matching document exists yet.

### Quality Bar

- Prefer updating an existing note over creating a near-duplicate.
- Use concrete names that match the code or feature surface.
- Explain why a system works the way it does, not only what buttons exist.
- Link related notes when a feature depends on a system or logic rule.
<!-- TechTree package: project-docs-guide end -->

<!-- TechTree package: session-autopilot start -->
## TechTree Session Autopilot Rules

This project uses the TechTree `session-autopilot` package.

- Use `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py ...` to track implementation work.
- Keep the project guide in `In a Bottle-docs` current while you work.
- Treat local docs, shared TechTree session logs, and capture events as part of done.

### Required Session Flow

1. Start implementation work with:
   `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py begin --project-root "X:\Data\Projects\In a Bottle" --task "<task title>" --agent <agent>`
2. After meaningful progress, tests, or milestone movement, record a checkpoint:
   `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py checkpoint --project-root "X:\Data\Projects\In a Bottle" --kind <plan|implementation|tests|milestone|note> --title "<checkpoint title>"`
3. Before wrapping the task, finish the session:
   `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py finish --project-root "X:\Data\Projects\In a Bottle" --summary "<what changed>"`
4. If the capture API was unavailable, replay pending work with:
   `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py flush --project-root "X:\Data\Projects\In a Bottle"`

### Autopilot Expectations

- `begin` starts or resumes the current work block when the last activity is still fresh.
- `checkpoint` records an agent event plus a git snapshot with branch, HEAD, dirty state, changed files, and diffstat.
- `finish` must update `05 Dev Notes`, contribute the shared TechTree session log, and emit the final capture events.
- If a task changes a feature, system, or logic rule, update the matching docs in `In a Bottle-docs` before `finish`.
- Do not skip the flow because the capture API is down. Queue the work and continue.
<!-- TechTree package: session-autopilot end -->
