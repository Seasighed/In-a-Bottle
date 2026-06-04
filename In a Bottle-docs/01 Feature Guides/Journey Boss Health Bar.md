# Journey Boss Health Bar

## Purpose

The Journey boss health bar turns survey completion into a lightweight progress fight. It helps respondents see how much progress their saved answers have made without changing how answers are stored or exported.

## Where It Lives

- `Scripts/UI/SurveyJourneyBossState.gd` builds the section health state and per-question damage metadata.
- `Scripts/UI/SurveyJourneyBossBar.gd` renders the layered health bar, HP text, hit flashes, and callouts.
- `Scripts/UI/SurveyJourneyApp.gd` commits live focus damage on navigation and keeps edited-but-uncommitted answers as charge only.
- `Scripts/UI/SurveyJourneyWrapupStage.gd` reuses the same bar for the end-of-survey recap.

## How It Works

The bar is one rounded rectangle with one full-width layer per survey section. Each section layer drains from left to right as completed questions in that section are committed. When a section reaches zero health, its layer is removed from the visible stack. If a respondent navigates back to a previously committed answer, the hit is healed immediately and the section layer reappears when needed.

Each complete question deals the same amount of total boss HP damage: `1 / survey.total_questions()`. Inside its own section layer, that same hit removes `1 / section.questions.size()` of the layer, so one question in a three-question section removes one third of that section layer.

On the Journey thanks screen, the wrap-up recap turns every answered question into a short text-only projectile. Each answer gets a center-screen focus beat first so the words can be recognized quickly, then launches into its mapped boss-bar section. The recap plays one answer at a time and accelerates across the sequence instead of firing every answer in one overlapping burst.

## Important States Or Rules

- Editing an answer only charges the attack visuals; it does not damage live boss HP until the respondent navigates forward.
- Partial answers can appear as glancing hits in the wrap-up recap, but they do not reduce boss health.
- The focus bar status shows remaining total HP, such as `HP 87%`.
- The focus bar detail text shows the current question's total HP value and section-layer value.
- The wrap-up stage uses final complete answers rather than only the live committed navigation history.
- Wrap-up attack text is answer-only, not question-prompt copy, and is aggressively shortened for instant readability.
- Hit feedback pulses the bar scale rather than moving its layout position, so repeated projectile hits cannot push the health bar off screen.
- Zero-health layers snap their fill visibility and fill scale to zero when depleted, preventing a minimum sliver from remaining after the last question in a section.

## Related Notes

- [Journey Health Bar](../06%20User%20Notes/Journey%20Health%20Bar.md)
- [TechTree Integration](../02%20Systems/TechTree%20Integration.md)

## Change Log

- 2026-06-04 01:16 - Documented the sequential text-only wrap-up attacks and condensed answer-summary rules.
- 2026-05-09 04:13 - Documented the no-drift hit pulse and zero-fill depleted layer behavior.
- 2026-05-09 03:50 - Documented the layered Journey boss health bar behavior and damage rules.
