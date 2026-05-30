# 2026-05-09 - Simplify Journey launch menu and submit flow

## Summary

Simplified Journey for launch playtesting by narrowing the default menu, routing wrap-up CTAs to Review, Upload, or Save based on completion and endpoint configuration, and reframing export as a submit/save screen with local-copy fallback.

## Session Context

- Agent: `Codex`
- Session ID: `auto-20260509042734-in-a-bottle-simplify-journey-launch-menu-and-submit-flow-7afd46`
- Started: `2026-05-09T04:27:34.865315-04:00`
- Finished: `2026-05-09T04:40:36.118132-04:00`
- Branch: `main`
- HEAD: `9b2de86`

## Context

The launch audit found that Journey's core answer flow was close, but adjacent utility surfaces were competing with the participant path. The main cleanup was to make Menu, Export, Upload, Review, and Save feel like one coherent end-to-end flow.

## Changes

- Reframed the overlay as `Journey Menu` with participant-safe actions and a `Submit / Save Answers` handoff.
- Hid preview controls, question debug IDs, theme switching, SFX controls, and destructive clear actions from the default Journey menu.
- Kept `Report Issue` visible in debug/playtest builds.
- Changed wrap-up CTAs so completion and upload configuration choose the primary action.
- Reframed the export screen as submit/save when upload is configured and local save only when it is not.
- Moved raw clipboard copy actions behind `More Copy Options`.
- Updated upload consent copy to say what is sent, where it goes, and whether identifying answers are scrubbed.
- Updated the UI flow catalog to show direct Journey wrap-up to upload, with local save as the fallback path.

## Verification

- `godot.exe --headless --path . --check-only` passed.
- `godot.exe --headless --path . --script res://Scripts/Tests/CiTestBootstrap.gd` passed.
- `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py finish --project-root "X:\Data\Projects\In a Bottle"` completed successfully on the short summary.
- `python X:\Data\Projects\TechTree\tools\techtree.py validate` passed.
- `python X:\Data\Projects\TechTree\tools\techtree_autopilot.py flush --project-root "X:\Data\Projects\In a Bottle"` could not replay queued envelopes because no capture API token was available.

## Follow-Up

- In a playtest build with a real endpoint, review the exact upload destination/public repository copy with the research or operations owner.
- Watch first-time participants for confusion between `Review Answers`, `Submit Anyway`, and `Save a Copy`.

## Related Notes

- [Journey Submit Flow](../01%20Feature%20Guides/Journey%20Submit%20Flow.md)
- [Journey Submit And Save Answers](../06%20User%20Notes/Journey%20Submit%20And%20Save%20Answers.md)

## Change Log

- 2026-05-09 04:40 - Restored implementation details after session autopilot generated the contribution packet scaffold.
- 2026-05-09 04:39 - Captured the Journey launch menu and submit/save implementation notes.
