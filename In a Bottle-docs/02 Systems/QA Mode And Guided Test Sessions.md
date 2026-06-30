# QA Mode And Guided Test Sessions

## Purpose

QA Mode turns the existing survey shells into a guided playtest surface for non-technical testers. It layers a checklist, page focus helpers, deterministic auto-drive actions, screenshot capture, one final QA ZIP bundle, and an optional full visual-audit export on top of the normal Journey and Survey App flows.

## Components

- `Scripts/UI/SurveyRuntimeBuildProfile.gd` resolves `qa` versus `participant` at runtime for both shells and injects the correct default template plus QA visibility rules.
- `Scripts/UI/SurveyFeatureFlags.gd` and `Resources/Survey/DefaultFeatureFlags.tres` expose the `enable_qa_mode` flag that turns the QA tooling on for both shells.
- `Scripts/UI/SurveyQaController.gd` coordinates the tutorial, guided checklist, screenshot capture, page focus/auto-drive requests, and final bundle export.
- `Scripts/UI/SurveyQaOverlay.gd` renders the QA home, issue-report tutorial, and per-page expected-behavior checklist UI.
- `Scripts/QA/SurveyQaChecklistCatalog.gd` defines the Journey, Survey App, and shared question-gallery checklist items keyed to `SurveyUiFlowCatalog` node ids.
- `Scripts/QA/SurveyQaSessionSupport.gd` persists the QA session state, stores page captures, and exports the final ZIP bundle.
- `Scripts/Tools/SurveyVisualAuditCatalog.gd` defines the responsive visual-audit coverage matrix for full-screen captures, dedicated question-type renders, custom view captures, and feature export images.
- `Scripts/Tools/SurveyVisualAuditRunner.gd` is the shared renderer-backed screenshot/export pipeline used by both the tooling scene and QA Mode.
- `tools/playtest.ps1` is the repo-owned operator and CI entrypoint for validation, packaging, and QA audit export.
- `Scripts/UI/SurveyApp.gd`, `Scripts/UI/SurveyJourneyApp.gd`, and `Scripts/UI/OverlayMenu.gd` expose the QA guide, capture, and export actions in both shells.

## Data Or Control Flow

1. The runtime profile layer resolves whether the app is in `qa` or `participant` mode before either shell finishes startup.
2. QA-enabled builds create a `SurveyQaController` beside the existing playtest feedback controller in both survey shells.
3. The first QA entry opens a short tutorial that teaches issue reporting before the tester starts the guided pass.
4. `Start Guided Test` loads `res://Dev/SurveyTemplates/personal_checkin_debug.json`, because it exercises every supported question family for playtesting.
5. Checklist sections are built from `SurveyUiFlowCatalog` page ids. Every item includes expected behavior text plus `Focus me`, and deterministic items also expose `Try for me`.
6. Focus or auto-drive actions route back through the active shell so the tester lands on the real Journey or Survey App surface instead of a fake mock screen.
7. Pass, fail, or skip results are stored in `user://qa_mode_session.json`. Screenshot captures are stored in `user://qa_captures/<session>/<surface>/`.
8. Final QA export writes one ZIP bundle with `report.md`, `session.json`, `checklist_results.json`, `environment.json`, `answers.json`, `answers.csv`, `progress_bundle.json`, `page_captures/*`, and nested issue-report assets when the tester used `Report Issue`.
9. `Export Visual Audit` routes through `SurveyVisualAuditRunner`, which captures the current curated screen catalog plus QA and feedback overlays, question-family cards, custom question views, summary and profile export cards, and a `flow_chart/ui_flow.png` atlas image into one ZIP.

## Operational Notes

- `participant` mode is the external playtest build. It uses `studio_feedback.json` and hides QA or report controls.
- `qa` mode is the internal evidence build. It uses `personal_checkin_debug.json` and keeps the full QA guide plus reporting controls visible.
- Journey is the primary guided path. Survey App stays in the checklist as the required smoke pass, and `question_gallery` remains shared coverage for supported question types.
- Upload checklist items stay conditional. If the current build has no upload endpoint configured, the QA checklist marks those items as skipped by build configuration instead of pretending the path is available.
- QA bundle downloads reuse the same transfer/save helpers as the existing feedback system. Browser builds download the ZIP, while desktop builds save to `user://exports` and open the export folder.
- Visual audit exports intentionally use a single canonical theme and a curated state matrix instead of every possible permutation. The goal is stable regression proof, not an explosion of near-duplicate images.
- The build and export tooling now runs through `tools/playtest.ps1`, packages profile-specific folders under `build/playtest/<timestamp>/...`, and verifies expected artifacts after each export instead of trusting a successful process exit alone.
- `tools/playtest.ps1` temporarily redirects Godot AppData to `.godot_appdata/playtest` for validation and visual-audit commands so `user://` QA fixtures, captures, and ZIP exports stay inside the repo's ignored local proof area. Build/export commands use normal AppData so export templates remain discoverable.

## Related Notes

- [Playtest Feedback And Response Transfer](Playtest%20Feedback%20And%20Response%20Transfer.md)
- [SeaShell Devtools And UI Flow Tooling](SeaShell%20Devtools%20And%20UI%20Flow%20Tooling.md)
- [QA Guided Test Mode](../06%20User%20Notes/QA%20Guided%20Test%20Mode.md)

## Change Log

- 2026-06-30 02:58 - Documented the isolated AppData behavior used by the playtest wrapper for validation and visual audit proof.
- 2026-06-17 04:35 - Added runtime build profile notes, participant-versus-QA packaging behavior, and the shared playtest CLI contract.
- 2026-06-04 02:31 - Added the shared visual audit runner, QA-mode visual audit export path, and curated responsive screenshot coverage contract.
- 2026-06-03 23:25 - Documented the QA mode controller, guided checklist flow, deterministic auto-drive behavior, and final QA ZIP bundle contract.
