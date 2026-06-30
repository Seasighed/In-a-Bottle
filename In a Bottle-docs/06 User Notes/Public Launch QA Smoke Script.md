# Public Launch QA Smoke Script

Run this checklist before sharing the public link. Record each issue in the QA findings log with severity, screenshot path, repro steps, status, and whether it blocks launch.

## Devices

- Windows desktop Chrome or Edge.
- Hosted desktop web build.
- iOS Safari or iOS emulation.
- Android Chrome or Android emulation.

## Participant Flow

1. Open the public participant link.
2. Confirm the default survey is `MapleStory Pulse`.
3. Confirm QA/debug/review-import tooling is not visible.
4. Start the survey.
5. Answer every question type: text, email, number, choice, multi-choice, scale, ranked-choice, and matrix.
6. Watch the boss-health feedback; it should be fun but should not block navigation.
7. Move rapidly next/back for a few questions.
8. Reload mid-survey and confirm resume behavior.
9. Complete the survey and open review.
10. Confirm identifying questions are marked clearly.
11. Turn scrub identifying answers on and export JSON.
12. Save CSV.
13. Open upload, read the disclosure, and verify consent behavior.
14. Upload an eligible `MapleStory Pulse` response only when the live endpoint is configured.
15. Copy the success or failure response.

## Custom Survey Flow

1. Import a valid template JSON.
2. Confirm it appears as `Custom Survey`.
3. Import invalid JSON and confirm the app explains the failure.
4. Import a duplicate-id template and confirm normalization or rejection is understandable.
5. Answer the custom survey.
6. Save JSON and CSV locally.
7. Confirm upload is disabled and the message says local exports still work.

## Stress And Accessibility

- Rapidly tap next/back and upload buttons.
- Try long text and long option labels.
- Use keyboard-only navigation on desktop.
- Enable reduced motion and confirm playful behavior becomes tolerable.
- Check browser zoom and narrow mobile widths for overlap.
- Test endpoint offline and malformed server responses.
- Rotate mobile if practical.

## Proof Screenshots

Capture the public landing/start, representative question types, boss-health change, export panel, upload eligible, upload disabled, upload success, upload failure, and wrapped summary.

## Change Log

- 2026-06-29 20:13 - Added the public launch manual QA smoke script.
