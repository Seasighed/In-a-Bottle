# Playtest Feedback And Response Transfer

## Purpose

This system gives playtest builds a structured way to capture issues, bundle the evidence, and hand survey answers or bug reports off through the same browser-friendly transfer helpers. QA Mode now layers a guided tutorial and final QA bundle on top of the same reporting pipeline instead of creating a second bug-report path.

## Components

- `Scripts/UI/SurveyPlaytestFeedbackController.gd` owns capture triggers, issue storage, viewport crops, and export/share actions.
- `Scripts/UI/SurveyPlaytestFeedbackOverlay.gd` renders the capture popup, armed-capture state, and review UI.
- `Scripts/UI/SurveyPlaytestFeedbackSupport.gd` formats the saved issue bundle into markdown, JSON, and ZIP-friendly structures.
- `Scripts/UI/SurveyQaController.gd` and `Scripts/QA/SurveyQaSessionSupport.gd` reuse the feedback session data when the tester exports a full QA bundle.
- `Scripts/Survey/SurveyTransferSupport.gd` centralizes clipboard copy, browser share/download fallback, upload response formatting, and upload reset helpers.
- `Scripts/Survey/SurveySessionStateSupport.gd` tracks answer timing, answer-change counts, and upload quality metadata so uploads carry better context.
- `Scripts/UI/SurveyApp.gd`, `Scripts/UI/SurveyJourneyApp.gd`, and `Scripts/UI/OverlayMenu.gd` expose the report/review/share/download actions in the two survey shells.

## Data Or Control Flow

1. Debug or playtest builds create a `SurveyPlaytestFeedbackController` and wire it to the current survey shell.
2. A desktop tester can ctrl-click a surface, or a touch tester can arm capture from the report controls and tap the target area.
3. The controller resolves the clicked control, merges any `feedback_context` metadata from the control tree, captures a cropped viewport image, and opens the review popup.
4. Saved issues are kept in-memory for the session and can be reviewed, deleted, cleared, copied as markdown, or bundled into a ZIP with screenshots plus machine-readable JSON.
5. QA Mode can snapshot the same issue list into its session state so the final QA bundle nests `feedback_report.md`, `feedback_bundle.json`, and issue screenshots beside checklist results and answer exports.
6. Transfer helpers attempt browser-native sharing when available and fall back to normal downloads when it is not.
7. The same transfer/session helpers are reused by answer upload flows so upload payloads include response-quality metrics and consistent status formatting.

## Operational Notes

- The reporting UI is intentionally gated to debug-style runs rather than ordinary participant builds.
- Browser file sharing is optional. If `navigator.share` or file sharing support is unavailable, the export path falls back to download.
- `feedback_context` metadata is the preferred way to enrich controls with semantic labels, question ids, menu actions, or section context before a capture happens.
- QA Mode teaches the same system in-app: ctrl-click on desktop, armed tap capture on touch layouts, review/delete before export, then export one final bundle when the pass is done.
- Session-quality metadata is meant to describe answer pace and completeness, not to block local save/export paths.

## Related Notes

- [Journey Submit Flow](../01%20Feature%20Guides/Journey%20Submit%20Flow.md)
- [Reporting Playtest Issues](../06%20User%20Notes/Reporting%20Playtest%20Issues.md)
- [TechTree Integration](TechTree%20Integration.md)

## Change Log

- 2026-06-03 23:25 - Added the QA mode integration notes for issue-report tutorials and nested feedback assets in the final QA bundle.
- 2026-05-30 02:53 - Documented the playtest issue capture pipeline, transfer helpers, and upload quality support.
