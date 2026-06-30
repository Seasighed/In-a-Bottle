# Reporting Playtest Issues

## When It Appears

The playtest reporting tools are meant for debug or playtest builds. If you do not see a `Report` button or `Report Issue` menu action, you are probably in a normal participant build.

In QA Mode, the first tutorial also teaches this system before the guided checklist starts.

The intended QA entry points are:

- `Launch QA.cmd` on Windows packages.
- `index.html` in the separate QA Web package.

## How To Capture An Issue

- On desktop, hold `Ctrl` and click the place where the issue happened.
- On touch-first layouts, use the `Report` action first, then tap the target area you want to tag.
- Add a short description before saving so the screenshot and control context have a human explanation attached.

## What You Can Do After Capturing

- Open the review list to inspect, delete, or clear saved issue tags for the current session.
- Copy the markdown report when you only need a text handoff.
- Share or download the ZIP bundle when you want screenshots plus structured JSON context.

## Notes

- Captures are session-local until you export or share them.
- Browser builds may open a share sheet first and fall back to download if file sharing is unavailable.
- QA bundle export includes the saved issue report automatically, so you do not need to export a separate bug-report ZIP unless someone asked for only the issue list.
- The feature is meant to help playtests, not ordinary respondents.

## Related Notes

- [Playtest Feedback And Response Transfer](../02%20Systems/Playtest%20Feedback%20And%20Response%20Transfer.md)
- [Journey Submit And Save Answers](Journey%20Submit%20And%20Save%20Answers.md)

## Change Log

- 2026-06-29 20:13 - Updated Web QA entry guidance for separate QA bundles.
- 2026-06-17 04:35 - Added QA entry-point guidance for Windows and Web playtest packages.
- 2026-06-03 23:25 - Added the QA mode tutorial and final-bundle guidance for playtest issue reporting.
- 2026-05-30 02:53 - Added operator guidance for capturing, reviewing, and exporting playtest issue reports.
