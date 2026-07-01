# Public Launch QA Findings

Use this as the running release findings log. Keep entries short and reproducible.

| ID | Severity | Device / Browser | Area | Repro | Evidence | Status | Launch Blocker |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QA-001 | High | Local Git | Worktree curation | Create a branch/commits in the foreground checkout, then use the safety clone fallback. | Foreground `.git` lock creation is still denied, but clean branch `codex-release-candidate-proof-pass` was pushed to GitHub at `adb1ccb`. | Mitigated | No |
| QA-002 | High | Local CLI | Supabase deploy | Run `npx supabase --version`, then list projects. | `npx supabase --version` works at `2.109.0`; deploy is blocked because no Supabase login/access token or project ref is configured. | Blocked External | Yes |
| QA-003 | High | Renderer-backed Godot | Visual proof | Run `tools/playtest.ps1 release -IncludeAudit` from the promoted branch. | Final promoted-branch audit `build/playtest/20260630-rc-proof-adb1ccb/audit/survey_visual_audit_2026-07-01t01-17-14.zip` has 92 captures and 0 placeholders. | Fixed | No |
| QA-004 | High | Manual devices | Device smoke | Review current dashboard/manual smoke state. | Desktop hosted web, iOS Safari, and Android Chrome smoke passes are still not recorded. | Open | Yes |
| QA-005 | Medium | Docs | Release evidence | Compare feature inventory/readiness notes. | Older zero-placeholder audit language was stale relative to current RC blocker status. | Fixed | No |
| QA-006 | High | Local CLI | Supabase validation | Run `deno --version`, `deno test`, and `deno check`. | Deno now runs; validation tests passed 7/7 and `index.ts` plus `smoke.ts` type-check. | Fixed | No |
| QA-007 | High | Godot CI | Local validation | Run `tools/playtest.ps1 test` with Godot 4.6.1. | Fixed by isolating Godot AppData to `.godot_appdata/playtest` for validation and audit runs; `tools/playtest.ps1 test` passes locally. | Fixed | No |
| QA-008 | Medium | Godot release CLI | Release log noise | Run `tools/playtest.ps1 release -IncludeAudit -ContractOnly`. | The release exits successfully, but Godot still prints editor-settings save errors for `C:/Users/Alex/AppData/Roaming/Godot/editor_settings-4.6.tres` after completion. | Open | No |
| QA-009 | Medium | Visual audit | Upload proof | Inspect `journey_upload__configured` visual audit capture. | Configured upload proof initially used a non-allowlisted fixture and then a repeated-load guard; fixed so the configured capture uses allowlisted MapleStory Pulse and disables only the fixture load-count guard. | Fixed | No |
| QA-010 | Medium | Fresh clone | Local validation | Run `tools/playtest.ps1 test` from the safety clone before `.godot` metadata exists. | Initial run timed out with unresolved GDScript class-name parse errors; fixed by using Godot `--import` during bootstrap. | Fixed | No |

## Severity Guide

- Critical: data loss, broken upload/export, privacy ambiguity, or cannot finish survey.
- High: major mobile layout issue, misleading copy, inaccessible core control, or repeated crash.
- Medium: confusing but recoverable flow, ugly visual overlap, non-blocking upload/export issue.
- Low: typo, minor charm/timing issue, cosmetic polish.

## Change Log

- 2026-06-30 21:21 - Recorded the promoted GitHub branch, final `adb1ccb` release proof, working Supabase CLI via `npx`, and fixed Deno validation finding.
- 2026-06-30 04:55 - Marked worktree curation mitigated through the safety clone, marked renderer-backed visual proof fixed, and added fixed findings for the audit upload fixture and fresh-clone import cache.
- 2026-06-30 02:58 - Marked the Godot `user://` validation blocker fixed and recorded the current contract-audit release proof folder.
- 2026-06-30 02:13 - Added Deno execution and Godot user-data write failures found during the RC proof pass.
- 2026-06-30 02:04 - Replaced placeholder row with concrete release-candidate blocker findings from the proof pass.
- 2026-06-29 20:13 - Added the public launch QA findings log.
