# Public Launch QA Findings

Use this as the running release findings log. Keep entries short and reproducible.

| ID | Severity | Device / Browser | Area | Repro | Evidence | Status | Launch Blocker |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QA-001 | High | Local Git | Worktree curation | Attempt to create `codex-release-candidate-proof-pass` branch. | Git reports repo top-level as `X:/Projects/In a Bottle` and cannot create `.git/refs/heads/*.lock` from this session. | Open | Yes |
| QA-002 | High | Local CLI | Supabase deploy | Run `supabase --version`. | Supabase CLI is not on PATH, so migration/function deploy and live smoke cannot run locally yet. | Open | Yes |
| QA-003 | High | Headless Godot | Visual proof | Use current release audit evidence from `build/playtest/20260630-wrapper-release-passed`. | Contract/headless audit has 92 placeholder captures; public launch requires renderer-backed zero-placeholder proof. | Open | Yes |
| QA-004 | High | Manual devices | Device smoke | Review current dashboard/manual smoke state. | Desktop hosted web, iOS Safari, and Android Chrome smoke passes are still not recorded. | Open | Yes |
| QA-005 | Medium | Docs | Release evidence | Compare feature inventory/readiness notes. | Older zero-placeholder audit language was stale relative to current RC blocker status. | Fixed | No |
| QA-006 | High | Local CLI | Supabase validation | Run `deno --version` and rerun with escalation. | `deno.exe` returns Access denied, so Supabase validation/type checks cannot be refreshed from this session. | Open | Yes |
| QA-007 | High | Godot CI | Local validation | Run `tools/playtest.ps1 test` with Godot 4.6.1. | Fixed by isolating Godot AppData to `.godot_appdata/playtest` for validation and audit runs; `tools/playtest.ps1 test` passes locally. | Fixed | No |
| QA-008 | Medium | Godot release CLI | Release log noise | Run `tools/playtest.ps1 release -IncludeAudit -ContractOnly`. | The release exits successfully, but Godot still prints editor-settings save errors for `C:/Users/Alex/AppData/Roaming/Godot/editor_settings-4.6.tres` after completion. | Open | No |

## Severity Guide

- Critical: data loss, broken upload/export, privacy ambiguity, or cannot finish survey.
- High: major mobile layout issue, misleading copy, inaccessible core control, or repeated crash.
- Medium: confusing but recoverable flow, ugly visual overlap, non-blocking upload/export issue.
- Low: typo, minor charm/timing issue, cosmetic polish.

## Change Log

- 2026-06-30 02:58 - Marked the Godot `user://` validation blocker fixed and recorded the current contract-audit release proof folder.
- 2026-06-30 02:13 - Added Deno execution and Godot user-data write failures found during the RC proof pass.
- 2026-06-30 02:04 - Replaced placeholder row with concrete release-candidate blocker findings from the proof pass.
- 2026-06-29 20:13 - Added the public launch QA findings log.
