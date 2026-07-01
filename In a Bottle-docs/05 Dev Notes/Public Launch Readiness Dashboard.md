# Public Launch Readiness Dashboard

Use this note as the public-release gate for `MapleStory Pulse`. A public link is not ready until every blocker row is either passed or explicitly accepted as a launch caveat.

## Current Status

| Area | Status | Evidence Needed | Notes |
| --- | --- | --- | --- |
| Dirty worktree curation | Promoted | [Public Launch Worktree Curation](Public%20Launch%20Worktree%20Curation.md) plus commits | Clean safety branch `codex-release-candidate-proof-pass` was pushed to GitHub at `adb1ccbae33db7f76ccd52b04ec621f489f70f7e`; foreground checkout still cannot write `.git` refs. |
| Schema identity | Ready | `maplestory_pulse`, template version `2`, schema hash `c69e1f63dd9480f644261067dbbf8d4e46d4d6f390702e58ccba8b2748a74c37` | Re-run after any `maplestory_pulse.json` edit. |
| Supabase migration | Blocked on credentials | Migration applied to production project | `npx supabase --version` works at `2.109.0`, but this machine is not logged in and no project ref/access token has been supplied. |
| Supabase function deploy | Blocked on credentials | `survey-upload` deployed with secrets set | Requires Supabase project ref, access token or login, service role secret, and hosted origin. |
| Supabase local validation | Passed locally | Deno tests and checks pass | `deno test supabase/functions/survey-upload/validation.test.ts` passed 7 tests and `deno check` passed for `index.ts` and `smoke.ts`. |
| Live endpoint smoke | Not started | `smoke.ts` passes accepted, duplicate, custom, wrong-schema, malformed, and scrubbed cases | Creates private test rows when enabled; blocked until migration/function deployment and endpoint URL exist. |
| Godot validation | Passed locally | `tools/playtest.ps1 test` and release validation pass | `tools/playtest.ps1` now uses Godot `--import` during bootstrap and isolates validation AppData so fresh clones can build their class/import cache. |
| Public web build | Packaged locally | `build/playtest/20260630-rc-proof-adb1ccb/release_manifest.json` points at `web/participant` | Final local release package was generated from clean promoted commit `adb1ccbae33db7f76ccd52b04ec621f489f70f7e`. |
| Windows builds | Packaged locally | Participant and QA folders exist under `build/playtest/20260630-rc-proof-adb1ccb` | Built by `tools/playtest.ps1 release -IncludeAudit` with non-Mono Godot 4.6.1. |
| Visual audit proof | Passed locally | Renderer-backed audit has zero placeholder captures | Final audit copied `build/playtest/20260630-rc-proof-adb1ccb/audit/survey_visual_audit_2026-07-01t01-17-14.zip` with 92 captures and 0 placeholders. |
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
deno check supabase/functions/survey-upload/index.ts supabase/functions/survey-upload/smoke.ts
```

Release package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\playtest.ps1 release -IncludeAudit -GodotPath 'X:\Apps\Godot\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
```

Supabase deploy, after project credentials are supplied:

```powershell
$env:SUPABASE_ACCESS_TOKEN='paste-token-for-this-shell'
npx supabase link --project-ref PROJECT_REF
npx supabase db push
npx supabase secrets set --env-file supabase/survey-upload.env
npx supabase functions deploy survey-upload
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
- Headless visual captures can become placeholders; the current launch proof uses renderer-backed D3D12 capture with zero placeholders.
- Real Supabase deployment cannot be completed without project credentials, production URL, and allowed hosted origin.
- The Supabase CLI is not on PATH, but `npx supabase --version` works and reported `2.109.0`.
- Git branch and commit creation in the foreground checkout still need a commit-capable environment because lock files under `X:/Projects/In a Bottle/.git` are denied from this session. Use the safety clone or verified bundle for the committed baseline.
- `tools/playtest.ps1` now isolates Godot AppData for validation and audit proof, and uses Godot `--import` so fresh clones create the metadata cache before checks run.
- Deno execution is working in this session; backend validation and type checks passed locally.
- The successful release command still prints Godot editor-settings save errors for `C:/Users/Alex/AppData/Roaming/Godot/editor_settings-4.6.tres` after completion; the process exits successfully, but keep the noise listed until a cleaner editor settings path is proven.

## Latest Local Artifacts

- Release folder: `build/playtest/20260630-wrapper-release-passed`
- Release manifest: `build/playtest/20260630-wrapper-release-passed/release_manifest.json`
- Final promoted-branch release folder: `build/playtest/20260630-rc-proof-adb1ccb`
- Final promoted-branch release manifest: `build/playtest/20260630-rc-proof-adb1ccb/release_manifest.json`
- Final promoted-branch renderer audit ZIP: `build/playtest/20260630-rc-proof-adb1ccb/audit/survey_visual_audit_2026-07-01t01-17-14.zip`
- Previous safety-clone release folder: `build/playtest/20260630-044822`
- Previous safety-clone release manifest: `build/playtest/20260630-044822/release_manifest.json`
- Previous safety-clone renderer audit ZIP: `build/playtest/20260630-044822/audit/survey_visual_audit_2026-06-30t08-48-59.zip`
- Build-only web proof folder: `build/playtest/20260630-rc-proof-build`
- Build-only web proof manifest: `build/playtest/20260630-rc-proof-build/release_manifest.json`
- Contract audit ZIP: `build/playtest/20260630-wrapper-release-passed/audit/survey_visual_audit_2026-06-30t06-57-47.zip`
- Wrapped proof manifest: `exports/survey_fake_answer_screenshots/2026-06-30t00-21-58/manifest.json`

## Change Log

- 2026-06-30 21:21 - Recorded the promoted GitHub branch, final `adb1ccb` release proof, working `npx supabase` CLI path, and refreshed Deno validation results.
- 2026-06-30 04:55 - Recorded the clean safety-branch release, renderer-backed 0-placeholder audit, fresh-clone import fix, and current backend tooling blockers.
- 2026-06-30 02:58 - Recorded the isolated AppData wrapper fix, passing local Godot validation, and the coherent contract-audit release folder.
- 2026-06-30 02:26 - Refreshed MapleStory Pulse identity and recorded the build-only web proof package.
- 2026-06-30 02:13 - Added Deno and Godot user-data validation blockers from the proof pass.
- 2026-06-30 02:04 - Recorded branch/commit lock-file denial as a release-candidate curation blocker.
- 2026-06-29 20:13 - Added the public launch readiness dashboard.
