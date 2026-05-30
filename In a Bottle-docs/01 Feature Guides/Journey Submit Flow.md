# Journey Submit Flow

## Purpose

Journey mode is intended to feel simple for playtest participants: answer questions, review if needed, then either upload the answers or save a local copy. The launch flow keeps reporting available for playtest feedback while moving developer and power-user controls out of the default participant menu.

## Where It Lives

- `Scripts/UI/SurveyJourneyApp.gd` owns the Journey menu options, wrap-up CTAs, export/save screen, upload screen, and upload readiness copy.
- `Scripts/UI/OverlayMenu.gd` renders the shared overlay menu and supports Journey-specific visibility labels.
- `Scripts/Tools/SurveyUiFlowCatalog.gd` records the Journey submit/save/upload transitions for the UI flow map.
- `Scripts/Tests/CiTestRunner.gd` covers the launch menu, wrap-up CTA routing, and secondary export/copy actions.

## Participant Menu

The default Journey menu is labeled `Journey Menu` and keeps the normal path small:

- `Continue`
- `Review Answers`
- `Jump To Section`
- `Character`
- `Report Issue` in debug/playtest builds
- `Submit / Save Answers`

The normal Journey menu hides destructive answer clearing, theme switching, SFX controls, preview mode, window presets, and question debug ID controls. Section rows are jump-only by default.

## Wrap-Up Routing

The wrap-up buttons depend on completion and upload configuration:

- Incomplete survey: `Review Answers` is primary. If upload is configured, the secondary action is `Submit Anyway`; otherwise it is `Save a Copy`.
- Complete survey with upload configured: `Upload Answers` is primary and opens the upload consent/review screen directly.
- Complete survey without upload configured: `Save Answers` is primary and opens the local save screen.

## Submit Or Save Screen

When upload is configured, the save screen is titled `Submit or Save Answers`. Upload is presented as the preferred handoff, and JSON/CSV saving remains available as a local fallback.

When upload is not configured, the screen is titled `Save Your Answers`, hides the upload button, and explains that upload is unavailable for the build. JSON and CSV buttons use `Save JSON Copy` and `Save CSV Copy`. Raw clipboard actions are hidden behind `More Copy Options`.

## Upload Consent Copy

The upload screen states what will be sent, the configured destination, where public answers will appear, and whether identifying answers will be scrubbed. Submit remains disabled until readiness and consent requirements are satisfied.

## Change Log

- 2026-05-09 04:39 - Documented the simplified Journey launch menu, wrap-up submit/save routing, and upload/local-copy behavior.
