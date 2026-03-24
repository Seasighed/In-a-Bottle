# In a Bottle

A GDScript-only survey shell for building custom questionnaires with section-based navigation, reusable UI hooks, and export-ready response data.

## What is included

- Sectioned survey flow with smooth fades between sections.
- A persistent survey map that shows sections and nested questions in an indented list.
- A global overlay menu opened by `Escape` or the `Menu` button.
- JSON and CSV export to `user://exports`.
- Swappable custom section header scenes and custom question view scenes.
- Scene-prefab UI shells so layout changes made in the editor cascade across the app.

## Main files

- `Scenes/Main.tscn`: app entry scene and main survey shell prefab.
- `Scenes/UI/SectionOutlinePanel.tscn`: prefab for the section/question navigator.
- `Scenes/UI/OverlayMenu.tscn`: prefab for the global overlay menu.
- `Scenes/QuestionViews/DefaultQuestionView.tscn`: prefab for the default question card.
- `Scenes/Headers/SpotlightHeader.tscn`: sample section header prefab.
- `Scenes/QuestionViews/ScaleChipQuestionView.tscn`: sample custom question prefab.
- `Scripts/UI/SurveyApp.gd`: survey controller and navigation flow.
- `Scripts/Survey/SampleSurvey.gd`: the questionnaire definition you edit to design your survey.

## How to customize the questionnaire

Edit `Scripts/Survey/SampleSurvey.gd` and replace the sample sections/questions with your own.

Built-in question types:

- `SurveyQuestion.TYPE_SHORT_TEXT`
- `SurveyQuestion.TYPE_LONG_TEXT`
- `SurveyQuestion.TYPE_SINGLE_CHOICE`
- `SurveyQuestion.TYPE_MULTI_CHOICE`
- `SurveyQuestion.TYPE_BOOLEAN`
- `SurveyQuestion.TYPE_SCALE`

## How to use custom visuals

For a custom question card:

1. Create a new scene whose root script extends `SurveyQuestionView`.
2. Implement `_apply_question()` and call `emit_answer(value)` when the answer changes.
3. Assign that scene to `custom_view_scene` on a `SurveyQuestion` in `SampleSurvey.gd`.

For a custom section hero/header:

1. Create a new scene whose root script extends `SurveySectionHeaderView`.
2. Implement `_apply_section()`.
3. Assign that scene to `custom_header_scene` on a `SurveySection` in `SampleSurvey.gd`.

The sample project already includes one custom section header and one custom scale question scene as references.