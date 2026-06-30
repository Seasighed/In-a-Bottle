# Imported Answer Review And Wrapped Export

Imported answer review is a desktop QA workflow for checking many completed answer JSON files against one survey. It lives on the Journey survey picker as `Review Imports` when QA mode is enabled and the build can open local folders.

## Workflow

1. Select a survey in the Journey survey picker.
2. Open `Review Imports`.
3. Choose the folder that contains exported answers.
4. Toggle `Scan subfolders` when answer files may be nested.
5. Rescan to build the aggregate review.
6. Use the `Review` tab to browse each question card and see tallies, numeric summaries, ranked summaries, matrix row counts, or text-answer lists.
7. Use the `Summary` tab to confirm the wrapped-page render status and save the phone screenshots when compatible records exist.
8. Use `Export Settings` to choose the light/dark mode, gradient preset, respondent colors, scrub behavior, and optional share-profile details.

The selected folder, recursive scan setting, last scan counts, wrapped-image scrub setting, wrapped theme, gradient preset, and respondent color overrides are saved per survey in `user://answer_review_sources.json`.

## Review Cards

Preset-answer questions show option tallies. This includes single choice, dropdown, multi choice, and boolean questions.

Numeric questions show min, max, average, and value-count summaries. This includes number, scale, and NPS questions.

Ranked-choice questions show per-option average rank and rank-position counts.

Matrix questions show each row with its own option counts.

Text-like questions show custom answers. This includes short text, long text, email, and date/custom text values. Wrapped free-text summaries show up to three distinct answers with inline `User N` or `Users N, N +X` labels colored by respondent; once there are more than three distinct free-text answers, the wrapped page switches to a two-column ranked word tally instead of listing repeated responses. When the scrub toggle is on, questions marked as identifying hide their answer text in both the review surface and the wrapped PNG summary.

## Wrapped Pages

Wrapped export renders phone-sized `1080x1920` PNG pages. The light theme is the default, a dark theme is available from the review overlay, and each screenshot gets a deterministic soft diagonal gradient so pages feel distinct while repeat exports stay stable. Gradient presets include `soft_white`, `sunrise`, `mint`, `sky`, `rose`, `violet`, `night`, and `aurora`; each preset still varies by page/section in a repeatable way.

Answer pages are story-style screenshots instead of form-like reports. Each page behaves like a full-screen section card: it shows a faint centered survey title and subtitle for context, then packs as many legible answer summaries from that section as fit. Sections never mix on one screenshot. When a section is too large, the subtitle shows `Part X of Y`.

Question prompts remain as tiny faint labels above the answer data, while tallies, text answers, numeric stats, matrix rows, and ranked-choice results carry the visual weight. Choice, dropdown, boolean, and numeric-like summaries use ranked numbered tally rows for faster scanning. The wrapped renderer measures the safe story area, vital text rectangle, and each tracked label after layout. It targets a calmer roughly 60-70% story fill, caps each renderer's font scale, and treats any label text, long word, or screenshot-bounds overflow as a proof failure. Each screenshot uses a deterministic three-color diagonal gradient, so pages feel distinct while repeat exports stay stable.

Matrix and ranked-choice answers use question-like summary treatments instead of plain text. Matrix pages show one dominant answer chip per row, with tie states such as `Tie: Agree / Disagree` and muted `also:` context for split aggregate votes. Ranked-choice pages show ordered rank rows with average rank and sample counts.

Aggregate counts no longer appear at the start of the wrap. The export appends a dedicated final stats page with answer/respondent counts, response totals, question totals, and scrub/generated context.

The optional share profile is a purgeable local custom field list. The app ships with a blank `Mushroom` profile template containing `Username`, `World`, and `Region` rows, and users can add or remove their own label/value rows. Only rows with values appear on wrapped pages, and those fields do not appear in raw JSON/CSV answer exports.

Each imported record also gets visual-only respondent metadata for the wrap: a stable respondent id, a numbered label such as `User 1`, and a default color. Export Settings can override those colors per survey so the same respondent remains visually consistent across inline text-answer labels. These visual settings are not written into raw JSON/CSV answer exports.

When multiple pages are generated, desktop export saves a timestamped folder with numbered PNG files. A single-page wrap still uses the normal save/download image path. Raw JSON remains the deep-data handoff.

## Upload Profile

Upload can include the optional share profile only when the person explicitly enables the upload checkbox for those fields. The upload payload stores generic volunteered `fields` under `volunteered_profile`, separate from normal survey responses and separate from identifying-question scrub settings.

## Related Notes

- [Imported Answer Review Pipeline](../02%20Systems/Imported%20Answer%20Review%20Pipeline.md)
- [Review Imported Answers](../06%20User%20Notes/Review%20Imported%20Answers.md)

## Change Log

- 2026-06-29 16:41 - Updated wrapped text-answer docs for inline `User`/`Users` labels instead of rank-like respondent badges.
- 2026-06-29 02:41 - Documented Summary and Export Settings tabs, gradient presets, respondent colors, numbered text answers, and word-tally wrapped summaries.
- 2026-06-28 23:24 - Updated wrapped readability guidance for calmer measured font caps, label-level bounds checks, single-chip matrix rows, and per-question-type proof screenshots.
- 2026-06-28 23:00 - Documented measured wrapped text layout, matrix/ranked story summaries, and non-overflow readability scaling.
- 2026-06-28 01:54 - Updated wrapped export guidance for section-bound story cards, three-color gradients, larger final stats, and custom Mushroom profile fields.
- 2026-06-28 01:19 - Updated wrapped export guidance for answer-story pages, deterministic gradients, and final stats screenshots.
- 2026-06-27 23:38 - Documented phone-sized wrapped pages, section pagination, theme choice, and optional share-profile behavior.
- 2026-06-27 22:25 - Added the imported answer review and wrapped export feature guide.
