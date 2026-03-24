# Survey Templates

The app loads `studio_feedback.json` by default through `SurveyApp.survey_template_path`.

## Quick start

1. Copy `starter_template.json`, `studio_feedback.json`, or `minecraft_modder.json`.
2. Edit it in any text editor.
3. Pick it from the onboarding template grid, import it into the template folder, or point `SurveyApp.survey_template_path` at it.
4. Run the scene.
5. Use the export menu to copy JSON or CSV to the clipboard, or save either format to disk.

## Versioned format

Templates are now normalized through a versioned loader.

- Root object:
  - `format`: use `"survey_template"`
  - `version`: current loader version is `2`
  - `id`, `title`, `subtitle` or `description`, `sections`
- Optional root onboarding fields:
  - `onboarding_subject`: short phrase used in onboarding and search prompts
  - `audience_profiles`: array of `{ id, label, description }`
  - `guided_presets`: array of `{ id, label, description, audience_id, topic_tags[] }`
  - `faq_items`: array of `{ id, question, answer }`
- Section object:
  - `id`, `title`, `description`, optional `icon`, optional `emoji`, optional `header_template`, `questions`
- Question object:
  - `id`, `prompt`, optional `emoji`, optional `description`, `type`, `required`, `placeholder`, `options`, `rows`, `min_value`, `max_value`, `step`, `left_label`, `right_label`, optional `view_template`
- Optional question scoring field:
  - `rating`: `{ enabled, reverse, weight, label, option_scores }`
  - `enabled`: opt a question into the opinion summary. `scale`, `nps`, and `matrix` auto-score by default unless you explicitly disable them.
  - `reverse`: flips the score for prompts where a higher raw answer means a worse sentiment, like burnout.
  - `weight`: lets one scored question count more heavily in section and overall averages.
  - `label`: overrides the display label used in the summary card.
  - `option_scores`: maps answer labels to numeric scores for `single_choice`, `dropdown`, `multi_choice`, `ranked_choice`, or custom boolean scoring.
- Optional question onboarding fields:
  - `topic_tags`: explicit topic chips shown in onboarding
  - `keywords`: extra search words and fallback topic labels
  - `audience_tags`: targeting hints that match `audience_profiles.id`

## Compatibility and validation

The loader normalizes several older aliases so older templates can still load as the schema evolves.

- `player_types` -> `audience_profiles`
- `onboarding_presets` -> `guided_presets`
- `faqs` -> `faq_items`
- `choices` -> `options`
- `statements` -> `rows`
- `template` -> `view_template`
- `tags` -> `topic_tags`
- `audiences` -> `audience_tags`

Validation now checks for:

- a JSON object root
- at least one section
- at least one question per section
- required prompts and titles
- required options for choice questions
- required rows and options for matrix questions
- duplicate ids, which are auto-deduped during normalization with warnings
- reversed `min_value` / `max_value`, which are auto-corrected with warnings

Imported templates are copied into `user://survey_templates`, and the onboarding template grid shows both built-in and imported templates.

## Supported question types

- `short_text`
- `long_text`
- `email`
- `date`
- `number`
- `single_choice`
- `dropdown`
- `multi_choice`
- `boolean`
- `scale`
- `nps`
- `ranked_choice`
- `matrix`

## Friendly aliases

Authors can also use common survey labels and the loader will normalize them.

- `text`, `short_answer`, `single_line` -> `short_text`
- `paragraph`, `textarea`, `comment` -> `long_text`
- `multiple_choice`, `radio` -> `single_choice`
- `checkbox`, `checkboxes`, `select_all` -> `multi_choice`
- `yes_no` -> `boolean`
- `rating`, `linear_scale`, `slider` -> `scale`
- `ranking`, `rank_order` -> `ranked_choice`
- `likert`, `grid`, `multiple_choice_grid` -> `matrix`

## Built-in templates

- `header_template: "spotlight"`
- `view_template: "scale_chips"`
- `view_template: "ranked_choice"`
- `view_template: "matrix"`

## Emoji support

Yes, emojis work in the JSON format as long as the file is saved as UTF-8.

- `emoji` on a section prefixes the section title everywhere it is displayed.
- `emoji` on a question prefixes the prompt everywhere it is displayed.
- If you omit `emoji`, the app falls back to a type-based or section-based default icon.
- Final rendering still depends on the font Godot is using. If a glyph is missing, switch to a font with emoji coverage.

## Notes

- `matrix` uses `rows` for statements and `options` for the selectable column labels.
- `nps` is rendered as a 0-10 chip scale.
- `scale` can use `left_label` and `right_label` for the end captions.
- JSON and CSV exports include every rendered answer, including ranked arrays and matrix dictionaries.
- The opinion summary uses rating-enabled questions to generate per-question, per-section, and overall score percentages, then lets the respondent export that summary as a PNG.
- Section Crossroads can route people into Survey Scroll, Search, topic browsing, Guided Match, or Gamble.


