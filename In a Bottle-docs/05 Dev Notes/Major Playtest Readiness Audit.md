# Major Playtest Readiness Audit

## Current Verified State

- Repo-native validation is green through `godot --headless --path . --check-only --quit-after 1` and `godot --headless --path . --script res://Scripts/Tests/CiTestBootstrap.gd`.
- The project now has one repo-owned release CLI at `tools/playtest.ps1` with `doctor`, `test`, `build`, `audit`, and `release` commands.
- Dual runtime profiles are now resolved in code instead of by mutating tracked defaults at export time.
- Versioned playtest packaging now lands under `build/playtest/<timestamp>/...` and currently exists at `build/playtest/20260617-major-playtest`.
- The historical renderer-backed visual audit exported one ZIP plus a real `ui_flow.png` atlas with `84` captures and `0` placeholders. The current safety-branch release now also has fresh renderer-backed `MapleStory Pulse` proof with `92` captures and `0` placeholders.
- CI now calls the same playtest CLI on Linux for Web and on Windows for desktop export, and Pages deploy now points at participant Web output only.
- The older smoke build at `build/windows` still exists for immediate manual use, but the intended handoff artifact is the versioned playtest folder.

## Ship Blockers And Gating Rules

- External testers should receive the `participant` profile, not the QA profile. The QA profile is intentionally instrumented and should stay internal.
- Local Web export must use a non-Mono Godot build. Mono remains acceptable for some validation or Windows work, but it is not the trustworthy local Web gate.
- The CLI contract is PowerShell 7 first. This workstation currently does not have `pwsh` on `PATH`, so local operators either need PowerShell 7 installed or must use `powershell.exe` as a fallback until that environment gap is closed.
- The build is playable, but there is still warning debt in capture logs. The main noise comes from layout warnings in QA/report overlays and preview-field instance warnings in question card surfaces.
- Pages should continue to publish only participant Web output. QA Web should remain a downloadable artifact, not the public default.
- For the public `MapleStory Pulse` release, contract-only or headless placeholder visual audits are useful checks, but launch proof should use the renderer-backed 0-placeholder audit from the safety branch.

## QA Vs Participant Packaging

- `participant` resolves to `res://Dev/SurveyTemplates/studio_feedback.json`.
- `participant` forces `enable_qa_mode = false` and hides reporting or QA affordances for first-impression playtests.
- `qa` resolves to `res://Dev/SurveyTemplates/personal_checkin_debug.json`.
- `qa` forces `enable_qa_mode = true` and exposes the guided checklist, issue reporting, screenshot capture, and final ZIP handoff.
- Windows packaging exports one shared binary, then writes profile-specific folders with `Launch Participant.cmd` or `Launch QA.cmd`.
- Web packaging exports one shared asset set, then writes profile-specific entry pages so participant remains `index.html` and QA remains an intentional alternate entry.

## Build, Test, And Audit Handoff Flow

1. Run `pwsh ./tools/playtest.ps1 doctor`.
2. Run `pwsh ./tools/playtest.ps1 test`.
3. Run `pwsh ./tools/playtest.ps1 build -Targets windows,web -Profiles participant,qa`.
4. Run `pwsh ./tools/playtest.ps1 audit -Profiles qa` on a renderer-backed machine when real screenshots are required.
5. Hand off the versioned folder under `build/playtest/<timestamp>/`.

The current verified folder layout is:

- `build/playtest/20260617-major-playtest/windows/participant`
- `build/playtest/20260617-major-playtest/windows/qa`
- `build/playtest/20260617-major-playtest/web/participant`
- `build/playtest/20260617-major-playtest/web/qa`
- `build/playtest/20260617-major-playtest/audit`

## Recommended Rollout Order

1. Internal QA pass on Windows with the `qa` launcher and the guided checklist.
2. Participant first-impression smoke pass on Windows with the `participant` launcher.
3. Internal Web smoke pass with participant first and QA second.
4. Only after those passes are stable, send the participant build to a major external playtest cohort.

## Practical Recommendations

- Give non-technical testers the participant build plus one short operator note that says answers save locally and no live upload is required.
- Keep the QA build for trusted internal testers who can return the richer QA ZIP and visual audit ZIP.
- Treat the visual audit as a release-proof artifact, not as a substitute for a human pass.
- Keep the release manifest and per-folder `START-HERE.txt` files in every handoff package.
- Schedule a follow-up cleanup pass for warning debt before broadening automation expectations around perfectly quiet logs.

## Related Notes

- [Current Feature Inventory And Milestones](../01%20Feature%20Guides/Current%20Feature%20Inventory%20And%20Milestones.md)
- [QA Mode And Guided Test Sessions](../02%20Systems/QA%20Mode%20And%20Guided%20Test%20Sessions.md)
- [SeaShell Devtools And UI Flow Tooling](../02%20Systems/SeaShell%20Devtools%20And%20UI%20Flow%20Tooling.md)
- [UI UX Critique And Recommendations](UI%20UX%20Critique%20And%20Recommendations.md)

## Change Log

- 2026-06-30 04:55 - Updated current visual-proof status after the safety-branch renderer-backed audit passed with 92 captures and 0 placeholders.
- 2026-06-30 02:04 - Marked the older zero-placeholder audit as historical and clarified the current release proof gate.
- 2026-06-17 04:35 - Added the major playtest readiness audit for dual runtime profiles, packaged Windows and Web handoff folders, CLI validation, and rollout guidance.
