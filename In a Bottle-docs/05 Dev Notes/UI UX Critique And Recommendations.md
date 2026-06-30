# UI UX Critique And Recommendations

## Framing

This critique is based on the current app surfaces plus the renderer-backed visual audit exported on `2026-06-17`. The app already has more real product shape than a typical prototype, but it is also carrying three identities at once: respondent product, alternate survey shell, and internal QA harness.

## Where The App Already Feels Strong

- The visual language is coherent. The dark canvas, blue accent, rounded cards, and restrained motion feel consistent across Journey, Survey App, and the overlays.
- Journey has a clear emotional frame. The landing page, lore path, character/profile language, and wrap-up combat metaphor make the experience feel more authored than a normal form.
- Survey App is operationally strong. The left-side map plus large question cards make long-form navigation understandable without needing tutorial text.
- The app handles evidence better than most internal tools. QA Mode, issue reporting, visual-audit ZIP export, and the flow atlas make the project unusually inspectable.
- Mobile layouts generally preserve hierarchy well. The cards, buttons, and question grouping stay readable even when the canvas narrows.

## Product Identity Split

- Journey feels like the premium respondent path.
- Survey App feels like the utility shell or fallback shell.
- QA tooling feels like a third product layered on top.

This is workable internally, but a major playtest should not ask a participant to understand all three. The participant build needs one clear story: "this is the survey experience." The QA build can stay richer and more technical because it is for internal evidence gathering.

## First-Run Clarity

- Journey landing is calm and attractive, but on desktop it uses a lot of empty space before it explains what the tester should do next.
- The theme chooser is visually prominent before the participant has even committed to the survey, which makes the first decision feel broader than it needs to.
- Survey App explains task structure more directly, but it feels less authored and less special than Journey.

Recommendation:

- Keep Journey as the default participant surface.
- Tighten the desktop landing copy so it explains the exact next step in one sentence.
- Move theme exploration slightly lower in the hierarchy for participant mode, or collapse it behind a lighter affordance until after the first answer.

## CTA Hierarchy And Copy

- `Take Survey` is the correct primary action on Journey.
- `Get Lore` and `Character` are understandable, but they compete early with the main task.
- QA Guide actions are explicit, but the desktop panel still reads like a tool drawer more than a numbered walkthrough.

Recommendation:

- Participant mode should emphasize one primary CTA and one secondary reassurance line.
- QA mode should number the first three actions in the panel copy so a low-context tester knows the exact order without inference.
- Anywhere the app offers both save or export and upload, the copy should make the safe local path feel like the normal path rather than a fallback.

## Save Vs Upload Trust Signals

- The strongest trust story in the current product is local evidence handoff, not live submission.
- That truth exists in the system, but it should be even more visible in participant-facing copy.

Recommendation:

- Add a short local-trust sentence near export or submit surfaces such as "Saved locally on this device unless your organizer tells you otherwise."
- Keep upload copy conditional and honest when an endpoint is not configured.
- In participant builds, never let QA or report affordances imply that the session is being silently monitored.

## Cognitive Load

- There are many valid surfaces: Journey, Survey App, focus mode, outline, menu, lore, help, profile, summary, export, upload, QA checklist, report issue, and visual audit.
- That breadth is powerful for internal work, but it can overwhelm a first-time participant if too many of those surfaces are visible at once.

Recommendation:

- Participant mode should be opinionated and narrow.
- QA mode should be explicit about being a tester build and should keep its toolset grouped under one guide rather than many scattered buttons.
- Survey App should stay in the product, but it should read as a secondary shell rather than equal-first-entry during a major participant playtest.

## Mobile Vs Desktop Readability

- Desktop Journey currently feels elegant but sparse.
- Desktop QA panels leave a lot of unused negative space and could support denser, more guided layout.
- Mobile form cards hold up well, but some meta copy is still small and low-contrast when compared with the main headline and button scale.

Recommendation:

- Add more instructional density on desktop QA surfaces.
- Keep important reassurance copy above the fold on both desktop and mobile.
- Review caption contrast and minimum font sizing for metadata, helper text, and status rows.

## Must Change Before A Major Playtest

- Hand external testers the `participant` build, not the QA build.
- Make the first-run participant copy clearer about what the app is and what happens to saved answers.
- Keep QA and reporting controls fully hidden in participant mode.
- Provide one short start-here operator note beside the build artifact.
- Keep Journey as the primary external path and treat Survey App as secondary verification unless research goals say otherwise.

## Strong Next Wave

- Add a stronger participant onboarding state that explains the emotional framing in one short beat.
- Unify naming so Journey, Survey App, Character, Profile, and QA Guide feel like one family instead of neighboring systems.
- Add more desktop-specific density or illustration so wide layouts feel intentionally composed rather than merely centered.
- Introduce a clearer progress language that ties section progress, profile growth, and final wrap-up together.

## Later Polish

- Reduce warning debt in layout and preview paths so automation logs become easier to trust at a glance.
- Add baseline image comparison on top of the new screenshot export flow.
- Consider a more distinct visual identity for participant versus QA overlays so internal tooling never accidentally feels public-facing.
- Explore richer motion or transitions only after first-run clarity and trust signals are locked.

## Related Notes

- [Major Playtest Readiness Audit](Major%20Playtest%20Readiness%20Audit.md)
- [Current Feature Inventory And Milestones](../01%20Feature%20Guides/Current%20Feature%20Inventory%20And%20Milestones.md)
- [QA Guided Test Mode](../06%20User%20Notes/QA%20Guided%20Test%20Mode.md)

## Change Log

- 2026-06-17 04:35 - Added the major playtest UX critique covering product identity, CTA hierarchy, trust signals, cognitive load, and rollout-priority recommendations.
