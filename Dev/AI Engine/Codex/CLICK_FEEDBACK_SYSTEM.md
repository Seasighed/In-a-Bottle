# Click Feedback System

## What this system is

In this project, the "click feedback system" is the shared `SurveyUiFeedback` hub in [Scripts/UI/SurveyUiFeedback.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyUiFeedback.gd:1).

Its job is to make UI interactions feel responsive by providing:

- short procedural sound effects for hover, select, navigation, answer selection, export, and some journey/boss events
- simple visual feedback helpers like `pulse()` and `shake_control()`
- one shared volume/hover-SFX control surface for the app

It is not the same thing as the playtest issue reporter. The issue reporter lives in `SurveyPlaytestFeedback*` files and captures bug reports/screenshots/context. `SurveyUiFeedback` is strictly UX feedback for interactions.

## How it is created

Both app shells instantiate the hub at startup:

- [Scripts/UI/SurveyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyApp.gd:535)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:415)

Each app does roughly the same thing:

1. `SurveyUiFeedback.new()`
2. `add_child(_feedback_hub)`
3. push current SFX settings into the hub with `set_sfx_volume(...)`
4. in `SurveyApp`, also set `set_hover_sfx_enabled(...)`

This means the system behaves like a scene-local singleton, but it is not an autoload. Instead, `SurveyUiFeedback` adds itself to the `survey_ui_feedback` group in `_ready()`, and all static `play_*()` helpers look up the first node in that group.

## How the hub works internally

`SurveyUiFeedback` is intentionally self-contained:

- It synthesizes sounds at runtime with `_build_tone_stream(...)`.
- Each cue gets its own `AudioStreamPlayer`.
- No external `.wav` files are required for the core click/UI sounds.

Important implementation details:

- `_ready()` builds the players and registers the node in the `survey_ui_feedback` group.
- `_create_player(...)` creates an `AudioStreamPlayer` on the `Master` bus.
- `_play_player(...)` stops the player, sets a randomized `pitch_scale` in a supplied range, then plays it.
- `_apply_volume_to_players()` maps the linear `0..1` SFX volume into `volume_db`.

The pitch randomization is small but important. It prevents repeated clicks from sounding completely identical.

## Main public API

The common calls are:

- `play_hover()` and `play_option_hover()`
- `play_select()`
- `play_navigation_next()` / `play_navigation_previous()`
- `play_answer_select()` / `play_answer_unselect()`
- `play_export()`
- `pulse(control, scale_amount, duration)`
- `shake_control(control, amplitude, duration)`

There are also journey/gamification-specific calls:

- `play_answer_charge(...)`
- `play_xp_gain(...)`
- `play_unlock()`
- `play_attack_launch(...)`
- `play_boss_hit(...)`
- `play_boss_glancing()`
- `play_boss_section_break()`
- `play_boss_victory()`
- `play_boss_partial_result(...)`
- `play_gamble_spin_tick(...)`

## How UI code uses it

The typical pattern is "wire once, then call the static helpers."

### Buttons and overlays

Many overlays and menus connect:

- `mouse_entered` or `focus_entered` -> `SurveyUiFeedback.play_hover()`
- `pressed` -> `SurveyUiFeedback.play_select()`

Representative files:

- [Scripts/UI/OverlayMenu.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/OverlayMenu.gd:491)
- [Scripts/UI/SurveySettingsOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveySettingsOverlay.gd:126)
- [Scripts/UI/SurveyExportOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyExportOverlay.gd:223)
- [Scripts/UI/SurveyToastOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyToastOverlay.gd:130)

`SurveyApp` and `SurveyJourneyApp` also have small helper methods for wiring button feedback across many controls:

- [Scripts/UI/SurveyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyApp.gd:581)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:826)

### Navigation

The previous/next buttons use dedicated navigation sounds instead of the generic select sound:

- [Scripts/UI/SurveyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyApp.gd:690)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:1023)

### Question answers

Answer widgets use the answer-specific cues so selections feel different from generic button presses.

Examples:

- [Scripts/UI/CheckboxOptionRow.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/CheckboxOptionRow.gd:74)
- [Scripts/UI/MultipleChoiceOptionRow.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/MultipleChoiceOptionRow.gd:67)
- [Scripts/UI/ScaleChipQuestionView.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/ScaleChipQuestionView.gd:152)
- [Scripts/UI/MatrixQuestionView.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/MatrixQuestionView.gd:431)

These handlers usually:

1. guard against programmatic changes with a flag like `_is_configuring`
2. play `play_answer_select()` or `play_answer_unselect()`
3. optionally call `pulse(...)` on the selected row/cell/control
4. emit the actual domain signal

That guard is important: the system is meant to react to user interactions, not every state sync.

### Search/results/list rows

Non-button clickable rows often call `play_select()` and `pulse(...)` manually inside `gui_input` handlers:

- [Scripts/UI/SurveySearchOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveySearchOverlay.gd:279)
- [Scripts/UI/SectionOutlinePanel.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SectionOutlinePanel.gd:312)
- [Scripts/UI/SurveyOnboardingOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyOnboardingOverlay.gd:1341)

### Export/save/copy success

Successful copy/save/export/upload actions use `play_export()` rather than `play_select()`, which gives output-related actions a distinct cue.

Examples:

- [Scripts/UI/SurveyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyApp.gd:512)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:3713)

### Journey combat/gamification

The journey app uses the same hub for richer feedback beyond plain clicking:

- answer charge buildup
- attack launch
- boss hit / glancing / break / victory
- unlock milestones
- panel shake on impact

Representative usage:

- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:2613)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:4659)
- [Scripts/UI/SurveyJourneyApp.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveyJourneyApp.gd:4695)

## Settings and user control

There are two relevant settings:

- `sfx_volume`
- `hover_sfx_enabled`

Volume is exposed in the overlay menu and the settings overlay:

- [Scripts/UI/OverlayMenu.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/OverlayMenu.gd:243)
- [Scripts/UI/SurveySettingsOverlay.gd](/X:/Data/Projects/In%20a%20Bottle/Scripts/UI/SurveySettingsOverlay.gd:88)

Important nuance:

- `SurveyUiFeedback.DEFAULT_SFX_VOLUME` is `0.35`.
- Hover sound effects default to off.
- `SurveyApp` persists and restores `hover_sfx_enabled`.
- `SurveyJourneyApp` currently sets volume, but does not expose the hover toggle path the same way `SurveyApp` does.

So if hover sounds seem missing, that is usually expected behavior, not a bug.

## Practical mental model for Codex

If you need to change click feedback behavior, think in three layers:

1. Hub layer: add or adjust a cue in `SurveyUiFeedback.gd`.
2. Wiring layer: connect hover/pressed/focus signals in the relevant overlay, row, or screen.
3. Interaction layer: call the right helper at the exact user-action moment, while avoiding programmatic updates.

## Safest way to extend it

If you want to add a new cue:

1. Add a new player field in `SurveyUiFeedback.gd`.
2. Build its stream in `_ready()`.
3. Add it to `_apply_volume_to_players()`.
4. Expose a new static `play_*()` wrapper.
5. Call that wrapper from the user-facing interaction handler.

If you want a new control to feel consistent:

1. Wire hover via `mouse_entered` and optionally `focus_entered`.
2. Wire press via `pressed` or manual `gui_input`.
3. Use `pulse(...)` for selections that should feel tactile.
4. Use `_is_configuring`-style guards when state changes can happen without direct user input.

## Short summary

`SurveyUiFeedback` is a lightweight, procedural, app-wide interaction feedback hub. It is created by the app shell, discovered through a node group, and invoked through static helper methods. Most of the project's "click feel" comes from small sound cues plus occasional `pulse()`/`shake_control()` animations wired directly into user interaction handlers.
