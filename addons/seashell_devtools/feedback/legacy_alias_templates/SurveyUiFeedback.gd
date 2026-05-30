extends Node

# Opt-in migration template.
# Copy this file into a host project and add `class_name SurveyUiFeedback`
# there if legacy In a Bottle call sites must keep their old symbol.

const DEFAULT_SFX_VOLUME := SeaShellFeedbackSurveyCompat.DEFAULT_SFX_VOLUME

static func play_hover() -> void:
	SeaShellFeedbackSurveyCompat.play_hover()

static func play_option_hover() -> void:
	SeaShellFeedbackSurveyCompat.play_option_hover()

static func play_select() -> void:
	SeaShellFeedbackSurveyCompat.play_select()

static func play_navigation_next() -> void:
	SeaShellFeedbackSurveyCompat.play_navigation_next()

static func play_navigation_previous() -> void:
	SeaShellFeedbackSurveyCompat.play_navigation_previous()

static func play_answer_select() -> void:
	SeaShellFeedbackSurveyCompat.play_answer_select()

static func play_answer_charge(intensity: float = 1.0) -> void:
	SeaShellFeedbackSurveyCompat.play_answer_charge(intensity)

static func play_answer_unselect() -> void:
	SeaShellFeedbackSurveyCompat.play_answer_unselect()

static func play_export() -> void:
	SeaShellFeedbackSurveyCompat.play_export()

static func play_xp_gain(intensity: float = 0.5) -> void:
	SeaShellFeedbackSurveyCompat.play_xp_gain(intensity)

static func play_unlock() -> void:
	SeaShellFeedbackSurveyCompat.play_unlock()

static func play_attack_launch(strong: bool = false) -> void:
	SeaShellFeedbackSurveyCompat.play_attack_launch(strong)

static func play_boss_hit(strong: bool = false) -> void:
	SeaShellFeedbackSurveyCompat.play_boss_hit(strong)

static func play_boss_glancing() -> void:
	SeaShellFeedbackSurveyCompat.play_boss_glancing()

static func play_boss_section_break() -> void:
	SeaShellFeedbackSurveyCompat.play_boss_section_break()

static func play_boss_victory() -> void:
	SeaShellFeedbackSurveyCompat.play_boss_victory()

static func play_boss_partial_result(tier: String = "") -> void:
	SeaShellFeedbackSurveyCompat.play_boss_partial_result(tier)

static func play_gamble_spin_tick(progress: float) -> void:
	SeaShellFeedbackSurveyCompat.play_gamble_spin_tick(progress)

static func play_menu_open() -> void:
	SeaShellFeedbackSurveyCompat.play_menu_open()

static func play_menu_close() -> void:
	SeaShellFeedbackSurveyCompat.play_menu_close()

static func set_sfx_volume(volume: float) -> void:
	SeaShellFeedbackSurveyCompat.set_sfx_volume(volume)

static func get_sfx_volume() -> float:
	return SeaShellFeedbackSurveyCompat.get_sfx_volume()

static func set_hover_sfx_enabled(enabled: bool) -> void:
	SeaShellFeedbackSurveyCompat.set_hover_sfx_enabled(enabled)

static func is_hover_sfx_enabled() -> bool:
	return SeaShellFeedbackSurveyCompat.is_hover_sfx_enabled()

static func pulse(control: Control, scale_amount: float = 0.08, duration: float = 0.18) -> void:
	SeaShellFeedbackSurveyCompat.pulse(control, scale_amount, duration)

static func shake_control(control: Control, amplitude: float = 5.0, duration: float = 0.22) -> void:
	SeaShellFeedbackSurveyCompat.shake_control(control, amplitude, duration)
