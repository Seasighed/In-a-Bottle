# Imported Answer Review Pipeline

The imported answer review pipeline is implemented by `SurveyAnswerReview` and the Journey review overlay. It scans a local folder, normalizes compatible answer JSON files into respondent records, aggregates by survey question, and feeds the aggregate into the review UI and wrapped PNG card.

## Accepted Payloads

The scanner accepts three answer shapes:

- Current progress bundles with an `answers` dictionary.
- Legacy answer exports with sectioned `answers` arrays and `responses`.
- Upload submission bundles with root `responses` sections.

Each compatible file is normalized into one respondent record with `source_path`, `source_name`, `payload_format`, `survey_id`, `schema_hash`, `payload_hash`, `saved_at`, `answers`, and `record_signature`. Aggregation then adds visual-review respondent metadata: stable `respondent_id`, `respondent_number`, `display_label`, and default wrapped color.

## Matching Rules

Imports are matched to the active survey by `survey_id` when the payload provides one. A mismatched survey id rejects the file.

When the payload and active survey both provide `schema_hash`, the hashes must match. If the payload omits the hash, the file can still be accepted, but the scan report records a warning and only recognized question ids are aggregated.

Exact duplicate payloads are rejected within a single scan. The signature uses a provided payload hash when available, otherwise it hashes the payload format, survey id, schema hash, saved timestamp, and normalized answers.

## Scan Report

`scan_folder(survey, folder_path, recursive)` returns:

- `records`
- `rejected_files`
- `aggregate`
- `survey_id`
- `schema_hash`
- `accepted_count`
- `question_count`
- `generated_at`

`rejected_files` keeps path/name/message entries so the UI can report what failed without stopping the whole folder scan.

## Aggregation

Aggregation preserves survey order. Every section contains question aggregate payloads, and `questions_by_id` gives direct lookup for tests and future tooling.

Question-type behavior:

- Choice, dropdown, multi-choice, and boolean: option tallies.
- Number, scale, and NPS: numeric values, value counts, min, max, and average.
- Ranked choice: rank-position counts and average rank per option.
- Matrix: option tallies per row.
- Text, date, email, and custom text values: full text lists, bounded samples, numbered individual-answer metadata, distinct-answer tallies, and word tallies for natural-language free text.

## Wrapped Export Data

`build_wrapped_summary_data(survey, aggregate, scrub_identifying_info, share_profile, theme_id, wrap_options)` remains available as the aggregate summary contract. Existing callers can keep using the shorter argument list. When scrubbing is enabled, identifying-marked questions keep their aggregate metadata but remove text lists, samples, individual-answer payloads, distinct-answer tallies, and word tallies.

`build_wrapped_pages_data(survey, aggregate_or_answers, scrub_identifying_info, share_profile, theme_id, wrap_options)` is the mobile export contract. Version 4 returns fixed phone page metadata, a `pages` array, `page_width = 1080`, `page_height = 1920`, a theme id, gradient preset id, sanitized optional share-profile fields for wrap display, respondent color maps, and per-page `page_kind`, `title`, `subtitle`, and `background_gradient` metadata. Question payloads also carry `wrapped_renderer` hints such as `option_tallies`, `numeric_summary`, `matrix_summary`, `ranked_summary`, `text_individual_answers`, `text_answer_tallies`, and `text_word_tallies` so the renderer can use question-like aggregate layouts.

`wrap_options` currently includes `gradient_preset_id`, `respondent_color_overrides`, and `text_summary_mode = "auto"`. Respondent color overrides are visual-only and keyed by stable respondent id. They are persisted with answer-review settings but are not included in raw JSON/CSV answer exports.

Pagination is answer-story based and section-bound. The builder keeps survey order, splits long text-answer lists, matrix rows, and ranked-choice summaries into chunks, then greedily packs chunks into a section page budget. Pages never mix section ids. Short sections usually become one full-screen story card, while larger sections expose `section_part_number` and `section_part_count` so the subtitle can show `Part X of Y`.

`background_gradient` is deterministic and contains `start`, `middle`, and `end` color stops. The renderer draws those as a soft diagonal three-stop gradient. Presets `soft_white`, `sunrise`, `mint`, `sky`, `rose`, `violet`, `night`, and `aurora` provide the base palette; page number, section, and part metadata add small repeatable variation.

Free-text wrapped behavior is summary-first. When a text question has one to three distinct answers, it renders distinct answers with inline `User N` or `Users N, N +X` labels colored by respondent so the numbers read as respondent ids instead of ranks. When it has more than three distinct answers, it renders ranked two-column word tallies. The tokenizer lowercases text, strips punctuation, ignores common stopwords, skips numeric-only tokens and words shorter than three characters, and counts a word once per respondent answer.

The final page always has `page_kind = stats`. It carries the answer/respondent count, response total, and question count so aggregate stats appear at the end of the wrapped page set rather than before the answers.

`SurveyAnswerReviewOverlay.capture_wrapped_pages(pages_data)` renders every page through `SurveyAnswerWrappedCard` and includes `layout_metrics` in each capture payload. `measure_wrapped_pages(pages_data)` returns the same metrics without requiring callers to inspect the image objects. The older `capture_wrapped_image(summary_data)` method is retained as a compatibility shim that returns the first phone page.

`SurveyAnswerWrappedCard.get_layout_metrics()` measures the post-layout safe story rectangle, vital text rectangle, answer text rectangle, fill ratios, overflow state, renderer kinds, chosen prompt/answer font sizes, and label-level bounds. Each label metric includes its allocated rect, measured text size, font size, max lines, longest-word width, and overflow flags. The renderer uses a guarded preflight estimate before building the page, then scales answer text toward a calmer 60-70% story-area target while keeping prompts smaller and preventing overflow. Final stats use the same metrics path with oversized but capped stat typography.

Matrix wrapped summaries are visualized as one primary answer chip per matrix row. The source aggregate still keeps every option count, but the wrapped page chooses the dominant response for the row, renders ties as one tie chip, and adds muted split-vote context instead of drawing multiple selected-looking cells.

Optional share profile data is stored by `SurveyShareProfileStore` in `user://survey_share_profile.json`. The canonical shape is `profile_name`, `fields: [{ label, value }]`, `show_on_wrap`, `include_in_upload`, and `updated_at`. The default local template is `Mushroom` with blank `Username`, `World`, and `Region` rows. The store migrates legacy `display_name`, `world_name`, and `game_region` keys into those rows, normalizes field lengths, supports purge, and produces separate payloads for wrap display and upload opt-in.

## Visual Audit

The visual audit catalog includes:

- `answer_review_overlay` screen captures at phone and desktop sizes.
- `answer_wrapped_image` feature captures at phone-page size for light, dark, unique-gradient second-page, matrix, ranked-choice, and final-stats variants.

Contract-only visual audit tests verify the files are included in the bundle. Renderer-backed visual captures use the same routes when the audit runs outside headless mode. Wrapped visual-audit captures also write `metadata/wrapped_layout_metrics.json` when metrics are available.

For focused proof, `Scripts/Tools/RunWrappedMeasurementProof.gd` renders the key wrapped pages and writes `exports/wrapped_text_measurement/measurement_report.json` plus page PNGs. It now records the representative first light/dark pages, matrix, ranked-choice, final stats, and one isolated wrapped screenshot for every supported question type. In headless mode the PNGs are placeholders, but the metrics are still collected from the actual Control layout.

For template coverage proof, `Scripts/Tools/RunSurveyTemplateScreenshotProof.gd` loads every built-in survey JSON from `Dev/SurveyTemplates`, fills it with deterministic fake respondent records, and writes a Journey review screenshot plus wrapped page captures under `exports/survey_fake_answer_screenshots/<timestamp>/`. By default it renders one three-respondent scenario with the full wrapped page set. `--respondents=1,5,100` renders multiple scenario folders, `--sample-pages-only` captures only the first answer page and final stats page for quick comparison, and `--survey=<id-or-template>` narrows the run to one survey. The generated `manifest.json` records accepted survey counts, scenario counts, wrapped page metadata, file paths, and layout metrics so the output can be reviewed visually and checked programmatically.

## Upload Integration

`SurveySubmissionBundle.build_package` accepts an optional volunteered profile dictionary. The payload adds `volunteered_profile` only when `include_in_upload` is true and at least one custom field has both a label and value. The upload flow keeps this separate from survey responses, and `SurveySaveBundle`/`SurveyExporter` raw JSON and CSV exports remain unchanged.

## Change Log

- 2026-06-29 16:41 - Documented inline `User`/`Users` labels for wrapped text-answer sample rows.
- 2026-06-29 02:41 - Documented wrapped page data version 4, wrap options, respondent colors, gradient presets, and free-text word-tally summaries.
- 2026-06-29 01:55 - Documented respondent-count scenario and sample-page options for fake-answer screenshot proof.
- 2026-06-28 23:55 - Documented the all-template fake-answer screenshot proof runner and export manifest.
- 2026-06-28 23:24 - Documented bounded label-level metrics, calmer story fill targets, single-primary matrix rows, and per-question-type wrapped proof captures.
- 2026-06-28 23:00 - Documented wrapped page data version 3, layout metrics APIs, matrix/ranked renderers, and focused measurement proof output.
- 2026-06-28 01:54 - Documented section-bound wrapped pagination, three-stop gradients, and custom Mushroom share-profile storage/upload payloads.
- 2026-06-28 01:19 - Documented wrapped page data version 2, answer-story pagination, deterministic gradients, and final stats page behavior.
- 2026-06-27 23:38 - Documented mobile wrapped page data, pagination, share-profile storage, and volunteered upload integration.
- 2026-06-27 22:25 - Documented the imported answer review scan, aggregate, and wrapped export pipeline.
