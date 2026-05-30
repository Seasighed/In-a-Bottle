@tool
extends RefCounted
class_name SeaShellFeedbackSurveyCompat

const DEFAULT_SFX_VOLUME := 0.35

static func play_hover() -> void:
	_play_event("Ui.Hover")

static func play_option_hover() -> void:
	_play_event("Ui.OptionHover")

static func play_select() -> void:
	_play_event("Ui.Select")

static func play_navigation_next() -> void:
	_play_event("Ui.Navigation.Next")

static func play_navigation_previous() -> void:
	_play_event("Ui.Navigation.Previous")

static func play_answer_select() -> void:
	_play_event("Survey.Answer.Select")

static func play_answer_charge(intensity: float = 1.0) -> void:
	var resolved := clampf(intensity, 0.0, 1.0)
	var pitch := lerpf(0.88, 1.14, resolved)
	_play_event("Survey.Answer.Charge", null, {}, {"pitch_min": pitch, "pitch_max": pitch + 0.04})

static func play_answer_unselect() -> void:
	_play_event("Survey.Answer.Unselect")

static func play_export() -> void:
	_play_event("Ui.Export")

static func play_xp_gain(intensity: float = 0.5) -> void:
	var resolved := clampf(intensity, 0.0, 1.0)
	var pitch := lerpf(0.96, 1.28, resolved)
	_play_event("Survey.XpGain", null, {}, {"pitch_min": pitch, "pitch_max": pitch + 0.05})

static func play_unlock() -> void:
	_play_event("Survey.Unlock")

static func play_attack_launch(strong: bool = false) -> void:
	_play_event("Survey.Attack.Launch", null, {}, {
		"pitch_min": 0.92 if strong else 1.0,
		"pitch_max": 0.98 if strong else 1.08,
	})

static func play_boss_hit(strong: bool = false) -> void:
	_play_event("Survey.Boss.Hit", null, {}, {
		"pitch_min": 0.92 if strong else 1.0,
		"pitch_max": 0.98 if strong else 1.06,
	})

static func play_boss_glancing() -> void:
	_play_event("Survey.Boss.Glancing")

static func play_boss_section_break() -> void:
	_play_event("Survey.Boss.SectionBreak")

static func play_boss_victory() -> void:
	_play_event("Survey.Boss.Victory")

static func play_boss_partial_result(tier: String = "") -> void:
	var pitch := 0.94
	match tier:
		"near_win":
			pitch = 1.04
		"solid_progress":
			pitch = 1.0
		_:
			pitch = 0.94
	_play_event("Survey.Boss.PartialResult", null, {"tier": tier}, {"pitch_min": pitch, "pitch_max": pitch + 0.04})

static func play_gamble_spin_tick(progress: float) -> void:
	var resolved := clampf(progress, 0.0, 1.0)
	var pitch := lerpf(0.92, 1.28, resolved)
	_play_event("Survey.Gamble.SpinTick", null, {"progress": resolved}, {"pitch_min": pitch, "pitch_max": pitch})

static func play_menu_open() -> void:
	_play_event("Ui.Menu.Open")

static func play_menu_close() -> void:
	_play_event("Ui.Menu.Close")

static func set_sfx_volume(volume: float) -> void:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("set_setting_value"):
		feedback.call("set_setting_value", "SeaShell.Feedback.SfxVolume", clampf(volume, 0.0, 1.0))

static func get_sfx_volume() -> float:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("get_setting_value"):
		return float(feedback.call("get_setting_value", "SeaShell.Feedback.SfxVolume", DEFAULT_SFX_VOLUME))
	return DEFAULT_SFX_VOLUME

static func set_hover_sfx_enabled(enabled: bool) -> void:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("set_setting_value"):
		feedback.call("set_setting_value", "SeaShell.Feedback.HoverSfxEnabled", enabled)

static func is_hover_sfx_enabled() -> bool:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("get_setting_value"):
		return bool(feedback.call("get_setting_value", "SeaShell.Feedback.HoverSfxEnabled", false))
	return false

static func pulse(control: Control, scale_amount: float = 0.08, duration: float = 0.18) -> void:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("pulse"):
		feedback.call("pulse", control, scale_amount, duration)

static func shake_control(control: Control, amplitude: float = 5.0, duration: float = 0.22) -> void:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("shake_control"):
		feedback.call("shake_control", control, amplitude, duration)

static func _play_event(event_id: String, target: Variant = null, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("emit_event"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("emit_event", event_id, target, payload, options)

static func _feedback() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SeaShellFeedback")
