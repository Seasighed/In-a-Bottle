# Review Imported Answers

In desktop QA mode, the Journey survey picker can review many answer JSON files at once.

## Use It

1. Open the survey picker.
2. Select the survey you want to review.
3. Choose `Review Imports`.
4. Pick the folder containing answer JSON files.
5. Leave `Scan subfolders` on when files may be nested.
6. Review the accepted/rejected counts before trusting the aggregate.
7. Open `Summary` to see whether the wrapped render is ready and save the wrapped pages.
8. Open `Export Settings` to pick a light/dark theme, gradient preset, respondent colors, scrub behavior, and optional profile fields.

The wrapped pages are phone-sized PNGs. Answer pages act like section story cards: they keep one section per screenshot, pack as many legible answer summaries as fit, and show `Part X of Y` when a section needs more than one screenshot. Each screenshot uses its own soft three-color diagonal gradient from the selected preset. The export measures the text area and each label so important answer text stays large but calm, and proof runs fail if text leaves its label, safe area, or screenshot bounds. Matrix summaries show one primary answer chip per row with muted tie/split context, and ranked-choice summaries use compact ordered rows inspired by their question screens. Aggregate stats are saved as the final page, with larger numbers for quick reading.

Free-text wrapped pages show up to three distinct answers with inline `User N` or `Users N, N +X` labels, using respondent colors so it is clear which imported answer file contributed the text. If more than three distinct free-text answers exist, the page switches to a ranked two-column word tally so repeated demo-style answers do not crowd the screenshot. Choice, dropdown, boolean, and numeric-style summaries still use numbered/tallied rows where that improves scanning.

Respondent colors are visual-only. The app assigns each imported file a stable numbered respondent label and default color; Export Settings can override those colors for the wrapped screenshots. These color settings stay local to the review/export settings and are not added to raw JSON/CSV exports.

The wrapped pages can hide answers from questions marked as identifying. Keep that scrub toggle on before sharing outside the review group.

Optional profile fields are stored locally and can be purged from the review/upload UI. The default local profile is `Mushroom`, with blank `Username`, `World`, and `Region` rows. Only rows with values appear on wrapped pages. They are not part of raw JSON/CSV exports, and upload only includes them if the upload screen's optional share-profile checkbox is enabled.

Raw JSON/CSV answer exports are unchanged and remain the best format for deep analysis or archival transfer.

## Change Log

- 2026-06-29 16:41 - Updated operator guidance for inline `User`/`Users` labels on wrapped text-answer samples.
- 2026-06-29 02:41 - Added operator guidance for Summary and Export Settings tabs, gradient presets, respondent colors, and word-tally free-text summaries.
- 2026-06-28 23:24 - Updated operator note for bounded wrapped text sizing, single-chip matrix rows, and per-question-type proof screenshots.
- 2026-06-28 23:00 - Updated operator guidance for measured wrapped text scaling and matrix/ranked visual summaries.
- 2026-06-28 01:54 - Updated operator guidance for section-card wrapped pages, larger final stats, three-color gradients, and custom Mushroom profile fields.
- 2026-06-28 01:19 - Updated operator guidance for answer-first wrapped pages, unique gradients, and final stats screenshots.
- 2026-06-27 23:38 - Updated guidance for phone-sized wrapped pages, optional share profile, purge, and upload opt-in.
- 2026-06-27 22:25 - Added QA operator guidance for reviewing imported answer folders and saving wrapped summaries.
