# QA Guided Test Mode

## What It Is

QA Mode is the tester-friendly build path for this project. It turns the app into a guided checklist with built-in issue reporting, screenshot capture, and one final QA bundle that can be sent back without needing repo context.

Use the QA-specific package on purpose:

- On Windows, open `Launch QA.cmd`.
- On Web, open the separate QA web bundle's `index.html`.
- If you only need the normal respondent experience, use the participant build instead. That build intentionally hides the QA and report tools.

## Start Here

When QA Mode opens, use these actions:

- `Start Guided Test` to load the QA template and begin the Journey checklist.
- `How To Report An Issue` to learn the bug-report flow before you start.
- `Export QA Bundle` when you are done and want the final ZIP file.
- `Export Visual Audit` when you want the full screenshot pack plus the UI flow chart ZIP.
- `Resume Last Session` if you already started and need to keep going.

## How To Use The Checklist

- Each page lists short expected behaviors instead of code-heavy instructions.
- `Focus me` moves you to the right page or surface.
- `Try for me` is available only when the app can safely auto-open the right page or preload example answers.
- Mark each line `Pass`, `Fail`, or `Skip` as you go.

The guided path is:

1. Journey full pass.
2. Survey App smoke pass.
3. Shared question gallery coverage.
4. Final QA bundle export.
5. Optional visual audit export for the full screenshot archive.

## How To Report An Issue

- On desktop, hold `Ctrl` and click the broken area.
- On touch-first layouts, press `Start Issue Tagging` first, then tap the broken area.
- Add a short description before saving.
- Use the review screen if you want to delete or confirm captures before the final export.

## What To Send Back

Export the final QA bundle at the end of the pass.

- Browser builds download the ZIP.
- Desktop builds save it locally and open the export folder for you.
- The ZIP already includes checklist results, screenshots, saved answers, environment details, and any issue reports you captured.

Use `Export Visual Audit` when you want the larger evidence package.

- It exports responsive screen captures for Journey, Survey App, QA overlays, and issue-report overlays.
- It also includes dedicated question-type screenshots, custom view screenshots, summary/profile export cards, and a `ui_flow.png` chart of the flow catalog.
- This is the fastest way to hand back "show me every screen" proof from a build without asking the tester to hunt through the app manually.

## Which Build To Open

- `participant` is for normal playtest participants and hides the QA tools.
- `qa` is for internal testers and exposes the guide, report system, screenshot recorder, and final evidence ZIP.
- If someone asks you to follow a guided test plan or collect screenshots for every screen, they mean the QA build.

## Streamlined Pass Tips

- Teach the issue reporter first, then keep the tester on the guided Journey path before asking for any freeform exploration.
- Export the QA bundle as the minimum required handoff, then export the visual audit only when you want broader visual regression proof.
- Use the visual audit bundle as a release-readiness snapshot, not as a replacement for the human checklist. The screenshots prove coverage; the checklist proves behavior.

## Change Log

- 2026-06-29 20:13 - Updated Web QA guidance now that participant bundles no longer include `qa.html`.
- 2026-06-17 04:35 - Added the participant-versus-QA build distinction plus launcher guidance for Windows and Web handoff packages.
- 2026-06-04 02:31 - Added the visual audit export path, full-screen screenshot bundle handoff, and streamlined tester guidance.
- 2026-06-03 23:25 - Added the tester-facing QA mode walkthrough, guided checklist expectations, and final bundle handoff instructions.
