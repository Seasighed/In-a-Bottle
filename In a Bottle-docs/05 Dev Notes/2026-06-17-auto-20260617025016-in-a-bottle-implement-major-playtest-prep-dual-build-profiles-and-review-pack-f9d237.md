# 2026-06-17 - Implement major playtest prep, dual build profiles, and review pack

## Summary

Implemented runtime build profiles, added the playtest CLI and CI packaging flow, refreshed QA and visual-audit capture support, produced the versioned playtest handoff folder, and added the major playtest review-pack docs.

## Session Context

- Agent: `Codex`
- Session ID: `auto-20260617025016-in-a-bottle-implement-major-playtest-prep-dual-build-profiles-and-review-pack-f9d237`
- Started: `2026-06-17T02:50:16.886970-04:00`
- Finished: `2026-06-17T05:18:47.930520-04:00`
- AI Logged Time: `2h 29m`
- Human Reported Time: `0m`
- Milestone: ``
- Tools: None recorded.
- Languages: None recorded.

## What Changed

- Implemented runtime build profiles, added the playtest CLI and CI packaging flow, refreshed QA and visual-audit capture support, produced the versioned playtest handoff folder, and added the major playtest review-pack docs.

## Checkpoints

### Wire runtime build profiles, playtest CLI, and packaged audit export
- Kind: `implementation`
- Time: `2026-06-17T04:33:19.737643-04:00`
- Git: `main` @ `0a1db4c`

```text
.github/workflows/ci.yml                           |  62 ++---
 .github/workflows/deploy-pages.yml                 |  31 +--
 .techtree/autopilot-events.jsonl                   |  16 ++
 .techtree/autopilot-history.jsonl                  |   3 +
 Scripts/QA/SurveyQaChecklistCatalog.gd             |   4 +-
 Scripts/Tests/CiTestRunner.gd                      | 136 ++++++++---
 Scripts/Tools/SurveyVisualAuditCatalog.gd          |   4 +-
 Scripts/Tools/SurveyVisualAuditRunner.gd           |  22 +-
 Scripts/UI/SurveyApp.gd                            |  66 +++++-
 Scripts/UI/SurveyJourneyApp.gd                     |  41 +++-
 Scripts/UI/SurveyJourneyWrapupStage.gd             |   8 +-
 Scripts/UI/SurveyPlaytestFeedbackController.gd     |  28 ++-
 Scripts/UI/SurveyQaController.gd                   |   7 +-
 .../settings/SeaShellSettingItem.gd                | 125 ++++++++++
 .../seashell_devtools/settings/SeaShellSettings.gd | 185 +++++++++++++++
 .../settings/SeaShellSettingsStore.gd              |   3 +
 .../settings/ui/SeaShellBoundSettingField.gd       |   7 +
 .../settings/ui/SeaShellBoundSettingsList.gd       |  82 +++++--
 .../settings/ui/SeaShellSettingsPanel.gd           | 251 ++++++++++++++++++++-
 project.godot                                      |  10 +-
 20 files changed, 945 insertions(+), 146 deletions(-)
```

### Validate playtest CLI, refresh web build, and verify packaged Windows artifacts
- Kind: `tests`
- Time: `2026-06-17T05:18:20.693494-04:00`
- Git: `main` @ `0a1db4c`

```text
.github/workflows/ci.yml                           |  62 ++---
 .github/workflows/deploy-pages.yml                 |  31 +--
 .techtree/autopilot-events.jsonl                   |  17 ++
 .techtree/autopilot-history.jsonl                  |   3 +
 .../01 Feature Guides/Feature Guide Index.md       |   2 +
 .../02 Systems/QA Mode And Guided Test Sessions.md |  24 +-
 .../SeaShell Devtools And UI Flow Tooling.md       |  13 +-
 .../06 User Notes/QA Guided Test Mode.md           |  13 ++
 .../06 User Notes/Reporting Playtest Issues.md     |   6 +
 Scripts/QA/SurveyQaChecklistCatalog.gd             |   4 +-
 Scripts/Tests/CiTestRunner.gd                      | 136 ++++++++---
 Scripts/Tools/SurveyVisualAuditCatalog.gd          |   4 +-
 Scripts/Tools/SurveyVisualAuditRunner.gd           |  22 +-
 Scripts/UI/SurveyApp.gd                            |  66 +++++-
 Scripts/UI/SurveyJourneyApp.gd                     |  41 +++-
 Scripts/UI/SurveyJourneyWrapupStage.gd             |   8 +-
 Scripts/UI/SurveyPlaytestFeedbackController.gd     |  28 ++-
 Scripts/UI/SurveyQaController.gd                   |   7 +-
 .../settings/SeaShellSettingItem.gd                | 125 ++++++++++
 .../seashell_devtools/settings/SeaShellSettings.gd | 185 +++++++++++++++
 .../settings/SeaShellSettingsStore.gd              |   3 +
 .../settings/ui/SeaShellBoundSettingField.gd       |   7 +
 .../settings/ui/SeaShellBoundSettingsList.gd       |  82 +++++--
 .../settings/ui/SeaShellSettingsPanel.gd           | 251 ++++++++++++++++++++-
 project.godot                                      |  10 +-
 25 files changed, 992 insertions(+), 158 deletions(-)
```


## Final Git Snapshot

- Branch: `main`
- HEAD: `0a1db4c`
- Dirty: `True`

```text
.github/workflows/ci.yml                           |  62 ++---
 .github/workflows/deploy-pages.yml                 |  31 +--
 .techtree/autopilot-events.jsonl                   |  18 ++
 .techtree/autopilot-history.jsonl                  |   3 +
 .../01 Feature Guides/Feature Guide Index.md       |   2 +
 .../02 Systems/QA Mode And Guided Test Sessions.md |  24 +-
 .../SeaShell Devtools And UI Flow Tooling.md       |  13 +-
 .../06 User Notes/QA Guided Test Mode.md           |  13 ++
 .../06 User Notes/Reporting Playtest Issues.md     |   6 +
 Scripts/QA/SurveyQaChecklistCatalog.gd             |   4 +-
 Scripts/Tests/CiTestRunner.gd                      | 136 ++++++++---
 Scripts/Tools/SurveyVisualAuditCatalog.gd          |   4 +-
 Scripts/Tools/SurveyVisualAuditRunner.gd           |  22 +-
 Scripts/UI/SurveyApp.gd                            |  66 +++++-
 Scripts/UI/SurveyJourneyApp.gd                     |  41 +++-
 Scripts/UI/SurveyJourneyWrapupStage.gd             |   8 +-
 Scripts/UI/SurveyPlaytestFeedbackController.gd     |  28 ++-
 Scripts/UI/SurveyQaController.gd                   |   7 +-
 .../settings/SeaShellSettingItem.gd                | 125 ++++++++++
 .../seashell_devtools/settings/SeaShellSettings.gd | 185 +++++++++++++++
 .../settings/SeaShellSettingsStore.gd              |   3 +
 .../settings/ui/SeaShellBoundSettingField.gd       |   7 +
 .../settings/ui/SeaShellBoundSettingsList.gd       |  82 +++++--
 .../settings/ui/SeaShellSettingsPanel.gd           | 251 ++++++++++++++++++++-
 project.godot                                      |  10 +-
 25 files changed, 993 insertions(+), 158 deletions(-)
```

## Concepts

- None recorded.

## Lessons

- None recorded.

## Evidence

- No visual evidence recorded.

## Bug Trail

- No bug note was linked for this work block.

## Follow-Ups

- No explicit follow-up was captured for this work block.

## Change Log

- 2026-06-17 05:18 - Updated by session autopilot.
