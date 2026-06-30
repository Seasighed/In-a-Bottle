# Public Launch Readiness Dashboard

Use this note as the public-release gate for `MapleStory Pulse`. A public link is not ready until every blocker row is either passed or explicitly accepted as a launch caveat.

## Current Status

| Area | Status | Evidence Needed | Notes |
| --- | --- | --- | --- |
| Dirty worktree curation | Blocked locally | [Public Launch Worktree Curation](Public%20Launch%20Worktree%20Curation.md) plus commits | The tree is grouped, but branch/commit writes are blocked because Git resolves the repo to `X:/Projects/In a Bottle/.git` and lock-file creation is denied from this session. |
| Schema identity | Ready | `maplestory_pulse`, template version `2`, schema hash `c69e1f63dd9480f644261067dbbf8d4e46d4d6f390702e58ccba8b2748a74c37` | Re-run after any `maplestory_pulse.json` edit. |
| Supabase migration | Blocked locally | Migration applied to production project | Requires Supabase CLI and project credentials. `supabase` is not installed on this machine as of 2026-06-29 20:13; re-check before deploy. |
| Supabase function deploy | Blocked locally | `survey-upload` deployed with secrets set | Requires Supabase CLI, project credentials, and hosted origin. |
| Supabase local validation | Blocked locally | Deno tests and checks pass | `deno.exe` still returns Access denied from this session as of 2026-06-30 02:58. |
| Live endpoint smoke | Not started | `smoke.ts` passes accepted, duplicate, custom, wrong-schema, malformed, and scrubbed cases | Creates private test rows when enabled; blocked until deploy credentials and Deno execution are available. |
| Godot validation | Passed locally | `tools/playtest.ps1 test` passes | `tools/playtest.ps1` now temporarily redirects Godot AppData to `.godot_appdata/playtest` for validation so `user://` fixtures stay writable. |
| Public web build | Packaged locally, not release-approved | `build/playtest/20260630-wrapper-release-passed/release_manifest.json` points at `web/participant` | Full release command succeeded, but dirty worktree, backend, manual QA, and renderer-backed visual proof are still blockers. |
| Windows builds | Packaged locally | Participant and QA folders exist under `build/playtest/20260630-wrapper-release-passed` | Built by `tools/playtest.ps1 release -IncludeAudit -ContractOnly`. |
| Visual audit proof | Contract-only only | Renderer-backed audit has zero placeholder captures | Contract audit produced 92 placeholder captures in `build/playtest/20260630-wrapper-release-passed`; this is not public-launch visual proof. |
| Wrapped proof | Layout metrics pass | `exports/survey_fake_answer_screenshots/2026-06-30t00-21-58` | 1, 5, and 100 respondent sample proof had 0 overflow flags but 9 placeholder captures in headless mode. |
| Desktop smoke | Not started | Chrome or Edge checklist completed | Use the public launch QA smoke script. |
| iOS/mobile Safari smoke | Not started | Device or emulation checklist completed | Check long prompts, exports, and upload copy. |
| Android Chrome smoke | Not started | Device or emulation checklist completed | Check narrow layout and reload/resume. |
| Privacy review | Not started | Public summary/wrapped export reviewed before posting | Raw DB rows stay private. |

## Required Commands

Generate survey identity:

```powershell
& 'X:\Apps\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'X:\Data\Projects\In a Bottle' --script 'res://Scripts/Tools/PrintSurveyIdentity.gd'
```

Local validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\playtest.ps1 doctor -GodotPath 'X:\Apps\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\playtest.ps1 test -GodotPath 'X:\Apps\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
deno test supabase/functions/survey-upload/validation.test.ts
```

Release package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\playtest.ps1 release -GodotPath 'X:\Apps\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
```

Live upload smoke after deploy:

```powershell
$env:SURVEY_UPLOAD_ENDPOINT='https://PROJECT_REF.supabase.co/functions/v1/survey-upload'
$env:MAPLESTORY_PULSE_SCHEMA_HASH='c69e1f63dd9480f644261067dbbf8d4e46d4d6f390702e58ccba8b2748a74c37'
$env:SUPABASE_ANON_KEY='optional-if-required'
$env:SURVEY_UPLOAD_SMOKE_WRITE_OK='true'
deno run --allow-env --allow-net supabase/functions/survey-upload/smoke.ts
```

## Known Caveats

- Headless Godot currently emits dummy renderer resource leak warnings at shutdown.
- Headless visual captures can become placeholders; public launch proof needs renderer-backed captures with zero placeholders.
- Real Supabase deployment cannot be completed without project credentials, production URL, and allowed hosted origin.
- This machine did not have the Supabase CLI on PATH during this pass.
- Git branch and commit creation currently need a commit-capable environment because lock files under `X:/Projects/In a Bottle/.git` are denied from this session.
- `tools/playtest.ps1` now isolates Godot AppData for validation and audit proof, but renderer-backed proof still needs a non-placeholder capture path.
- Deno execution is still blocked locally, so Supabase validation must be refreshed from a shell where `deno.exe` can run.
- The successful release command still prints Godot editor-settings save errors for `C:/Users/Alex/AppData/Roaming/Godot/editor_settings-4.6.tres` after completion; the process exits successfully, but keep the noise listed until a cleaner editor settings path is proven.

## Latest Local Artifacts

- Release folder: `build/playtest/20260630-wrapper-release-passed`
- Release manifest: `build/playtest/20260630-wrapper-release-passed/release_manifest.json`
- Build-only web proof folder: `build/playtest/20260630-rc-proof-build`
- Build-only web proof manifest: `build/playtest/20260630-rc-proof-build/release_manifest.json`
- Contract audit ZIP: `build/playtest/20260630-wrapper-release-passed/audit/survey_visual_audit_2026-06-30t06-57-47.zip`
- Wrapped proof manifest: `exports/survey_fake_answer_screenshots/2026-06-30t00-21-58/manifest.json`

## Change Log

- 2026-06-30 02:58 - Recorded the isolated AppData wrapper fix, passing local Godot validation, and the coherent contract-audit release folder.
- 2026-06-30 02:26 - Refreshed MapleStory Pulse identity and recorded the build-only web proof package.
- 2026-06-30 02:13 - Added Deno and Godot user-data validation blockers from the proof pass.
- 2026-06-30 02:04 - Recorded branch/commit lock-file denial as a release-candidate curation blocker.
- 2026-06-29 20:13 - Added the public launch readiness dashboard.
