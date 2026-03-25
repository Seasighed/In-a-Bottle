# In a Bottle

In a Bottle is a customizable survey app built in Godot. It lets you define your own questionnaires, guide people through them with multiple navigation styles, and export answers as JSON for storage, review, or downstream tooling.

## Primary Features

- Template-driven surveys with sections, descriptions, icons, onboarding prompts, and reusable question layouts.
- Multiple ways to move through a survey, including the full survey scroll, search, guided onboarding routes, gamble/random entry, and mobile-friendly focus mode.
- Built-in question types for text, email, date, number, single choice, dropdown, multi choice, yes/no, scale, NPS, ranked choice, and matrix questions.
- Export tools for answer-only JSON and CSV, plus a progress bundle that can preserve answers, local preferences, and last position.
- Opinion summary support for rating-enabled questions, including section scoring, overall sentiment, and PNG export.
- Desktop and web-aware behaviors, including browser downloads in web builds.

## Creating Surveys

Survey definitions live in JSON files. The easiest way to start is to copy one of the templates in [`Dev/SurveyTemplates`](x:/Data/Projects/In%20a%20Bottle/Dev/SurveyTemplates), edit it, then load it through the onboarding flow or point `SurveyApp.survey_template_path` at it.

The template format uses a versioned schema:

- Root fields: `format`, `version`, `id`, `title`, `subtitle` or `description`, and `sections`
- Section fields: `id`, `title`, `description`, optional `icon`, optional `emoji`, optional `header_template`, and `questions`
- Question fields: `id`, `prompt`, `type`, optional `description`, `required`, `placeholder`, `options`, `rows`, `min_value`, `max_value`, `step`, `left_label`, `right_label`, and optional `view_template`
- Optional rating fields: `rating.enabled`, `rating.reverse`, `rating.weight`, `rating.label`, and `rating.option_scores`

Minimal example:

```json
{
  "format": "survey_template",
  "version": 2,
  "id": "example_survey",
  "title": "Example Survey",
  "description": "A short custom survey.",
  "sections": [
    {
      "id": "general",
      "title": "General",
      "description": "Start here.",
      "questions": [
        {
          "id": "q1",
          "prompt": "How are you feeling about this?",
          "type": "scale",
          "required": true,
          "min_value": 1,
          "max_value": 5,
          "left_label": "Very poor",
          "right_label": "Excellent"
        }
      ]
    }
  ]
}
```

Supported question types:

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

If you want custom visuals, you can also assign:

- `custom_view_scene` or `view_template` for a custom question presentation
- `custom_header_scene` or `header_template` for a custom section header

## Data Output

The app supports more than one export shape depending on what you need.

### Answer Export JSON

This is the main answer payload for external use. It includes survey metadata and section-grouped responses:

- `survey_id`
- `title`
- `subtitle`
- `exported_at`
- `answers`

Each item inside `answers` contains:

- `section_id`
- `section_title`
- `responses`

Each response contains:

- `question_id`
- `prompt`
- `type`
- `answer`

Answer values preserve the natural structure of the question:

- text-like questions export strings
- number and scale questions export numbers
- boolean exports `true` or `false`
- multi choice and ranked choice export arrays
- matrix questions export dictionaries keyed by row name

### Progress Bundle JSON

The progress bundle is for restoring a session, not just sharing answers. It includes:

- `format`
- `version`
- `saved_at`
- `survey`
- `preferences`
- `session_state`
- `answers`

This is the format used for save/load progress behavior, since it can preserve:

- current answers
- theme and sound preferences
- onboarding memory preferences
- current section and selected question

### CSV Export

The app can also export a flat CSV with:

- `section_id`
- `section_title`
- `question_id`
- `question_prompt`
- `question_type`
- `answer`

## Vibe Code Transparency

This app was vibe coded with Codex.
