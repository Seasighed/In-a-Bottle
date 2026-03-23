# Session Logging Policy

## Daily File Location

- Store daily logs in `Log/YYYY-MM-DD.md`.

## Required Session Fields

- `session_label`
- `start_time`
- `end_time`
- `duration`
- `agent`
- `token_usage`
- `token_usage_note`
- `session_stats`
- `summary`
- `files_changed`
- `verification`
- `next_steps`

## Required Session Stats Fields

- `editor_start`
- `editor_uptime`
- `last_crash_time`
- `log_lines_captured`
- `resources_loaded`
- `filesystem_refreshes`
- `recompiles_triggered`
- `output_log_path`
- `latest_crash_path`

## Session Stats Rules

- Prefer values copied from the Tools tab at the end of the session.
- If the Tools tab does not expose a metric yet, record `unavailable`.
- Do not invent derived values that were not actually observed.
- If a value is approximate or partial, say so directly.
- Use the same metric names in daily notes so they stay machine- and human-readable.

## Formatting Rules

- Use Markdown.
- Prefer YAML frontmatter at the top of each daily file.
- Treat frontmatter as machine-readable metadata and the body as human-readable narrative.
- Use flat bullets only.
- Keep entries concise but specific.

## Obsidian Compatibility Rules

- Keep session-stat property names stable across the Tools tab, daily notes, and exported markdown notes.
- Prefer exports that can be pasted directly into `Log/YYYY-MM-DD.md` without manual reformatting.
- When generating markdown from tooling, include both YAML frontmatter and a readable body section.
- Prefer vault-friendly note structures over plain text dumps when the output is intended for long-term reference.

## Token Usage Rules

- Preferred:
  - actual runtime token count
- Acceptable fallback:
  - `unavailable`
- Not allowed:
  - fabricated exact token counts

## Time Tracking Rules

- Prefer actual local timestamps.
- If timing started late, mark the duration as partial.
- If time cannot be recovered honestly, say so.

## Attribution Rules

- Summaries should make Codex contributions easy to identify.
- When useful, mention the main files changed and the user-facing outcome.
