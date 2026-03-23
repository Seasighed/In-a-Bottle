# Codex Context

## Owner Preferences

- The user prefers Codex to compile after meaningful changes when practical.
- Verification is valued. A compile step is usually preferred to a purely unverified patch.
- The user wants Codex work to be attributable and visible in project logs.
- The user wants end-of-session and end-of-day summaries written into `Log/YYYY-MM-DD.md`.
- The user wants next steps documented so work can resume cleanly later.

## Logging Expectations

- Every Codex session should update the dated log file for the current day.
- If the file does not exist, create it.
- If it exists, append a new session section rather than replacing prior notes.
- Record:
  - start time
  - end time
  - duration
  - summary of work
  - files changed
  - verification performed
  - blockers or risks
  - next steps

## Token Tracking

- If actual token usage is exposed by the runtime, record it.
- If actual token usage is not exposed, write `token_usage: unavailable`.
- Do not invent or estimate token counts unless the user explicitly asks for an estimate.

## Time Tracking

- Track session time with real timestamps when available during the session.
- If earlier work was not timed, mark duration as partial or retroactively unavailable.
- Prefer honesty over reconstructed precision.

## Verification Preference

- Compile after substantive edits when practical.
- If compilation is skipped, explain why in the final response and in the session log.

## Known Environment Note

- Godot has recently shown intermittent editor crashes in `coreclr.dll` during editor usage.
- This should be treated as an environment risk, not an excuse to skip verification automatically.
- If compilation appears correlated with instability, note that risk explicitly while still respecting the user's preference for verification.

