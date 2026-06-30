# Current Feature Inventory And Milestones

## Respondent Experience

- Journey shell with landing, theme drawer, survey selection, lore, lore link, focus mode, outline, menu, help, review, profile, thanks, export, and conditional upload surfaces.
- Survey App shell with scroll mode, focus mode, menu, search, onboarding, settings, summary, export, profile, and help surfaces.
- Shared question gallery for broad question coverage and quick visual inspection.
- Supported question families include short text, long text, email, date, single choice, dropdown, multi choice, boolean, number, scale, NPS, ranked choice, and matrix.
- Journey wrap-up includes the boss-health payoff sequence and profile or gamification tie-in.

## Template, Schema, And Authoring

- Runtime JSON survey templates can be loaded without rebuilding the app.
- Public participant playtests now center on the built-in `MapleStory Pulse` template for the launch candidate.
- QA playtests now default to `personal_checkin_debug.json`.
- Question views are registry-driven, which allows shared rendering contracts plus custom view coverage such as the scale-chip presentation.
- Feature flags and runtime build profiles can change shell affordances without mutating repo-tracked defaults.

## Export, Upload, And Data Handling

- Local answer export exists for JSON, CSV, and progress-bundle style handoff.
- Playtest reporting and QA export reuse the same ZIP-transfer helpers across desktop and browser.
- Upload flows remain conditional and should tell the truth when the endpoint is absent.
- Environment metadata, answer data, and structured issue context can now ship together in one QA bundle.

## Summary, Profile, And Gamification

- Summary overlay captures answer synthesis in-app.
- Profile overlay exposes the respondent or character summary view.
- Progress, XP, and lock-state behavior are already wired into the shells.
- Journey uses the profile and health-bar metaphor to make completion feel authored instead of purely administrative.

## QA, Reporting, And Visual Audit Tooling

- QA Mode now provides a guided checklist for Journey, Survey App smoke coverage, and shared question coverage.
- Each checklist item can expose `Focus me`, and deterministic items can expose `Try for me`.
- Issue reporting supports ctrl-click or armed capture, structured review, and ZIP export.
- Visual audit tooling exports a flow chart plus screenshot coverage for shells, overlays, question types, custom views, summary, and profile states.
- Previous renderer-backed proof captured real screens, but the current `MapleStory Pulse` release candidate still needs fresh renderer-backed proof with zero placeholders before public launch.

## Build, Devtools, And CI

- SeaShell devtools remain integrated for local tooling and shared survey helpers.
- The repo now has a single PowerShell-first playtest CLI at `tools/playtest.ps1`.
- Playtest packaging now emits versioned Windows and Web folders for both participant and QA profiles.
- CI uses the same CLI for validation and export rather than duplicating raw Godot commands.
- Pages deployment now publishes participant Web output only.

## Must Do Before Major Playtest

- Keep participant mode as the public-facing default.
- Tighten participant first-run copy and local-save trust messaging.
- Make sure the operator handing builds to testers uses the versioned `build/playtest/...` package rather than an older flat export.
- Keep validating Windows and Web together for every release candidate.

## Strong Next Wave

- Reduce warning debt in the capture and preview paths.
- Add participant-specific onboarding language that explains the product in one short beat.
- Add baseline image comparison on top of the current screenshot export bundle.
- Sharpen the relationship between Journey and Survey App so their roles feel more intentional.

## Later Platform Or Product Investments

- Optional live upload handoff after the local ZIP path is fully trusted.
- Richer hotspot guidance for QA focus actions.
- Stronger desktop composition and denser instructional layouts for internal tooling.
- Broader authoring ergonomics if custom templates become a regular operator workflow.

## Related Notes

- [Journey Submit Flow](Journey%20Submit%20Flow.md)
- [Journey Boss Health Bar](Journey%20Boss%20Health%20Bar.md)
- [Major Playtest Readiness Audit](../05%20Dev%20Notes/Major%20Playtest%20Readiness%20Audit.md)
- [QA Mode And Guided Test Sessions](../02%20Systems/QA%20Mode%20And%20Guided%20Test%20Sessions.md)

## Change Log

- 2026-06-30 02:04 - Updated launch-candidate defaults and clarified that older zero-placeholder audit evidence is not current public-launch proof.
- 2026-06-17 04:35 - Added the current feature inventory and milestone buckets for major playtest planning.
