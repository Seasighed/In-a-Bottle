class_name SurveyShellSupport
extends RefCounted

const SURVEY_GAMIFICATION_STORE = preload("res://Scripts/Survey/SurveyGamificationStore.gd")

const MODIFIER_RESTORE_ACTION_ID := "restore_question_modifiers"
const DEFAULT_MODIFIER_RESTORE_MESSAGE := "Question modifiers were paused for this run. You can turn them back on any time."

static func build_profile_snapshot(gamification_hub, survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	if gamification_hub == null:
		return SURVEY_GAMIFICATION_STORE.build_profile_snapshot({}, survey, answers)
	return gamification_hub.current_snapshot(survey, answers)

static func refresh_visible_profile_overlay(profile_overlay, gamification_hub, survey: SurveyDefinition, answers: Dictionary) -> void:
	if profile_overlay == null or not profile_overlay.visible:
		return
	profile_overlay.update_profile(build_profile_snapshot(gamification_hub, survey, answers))

static func build_preferences(selected_theme_id: String, use_dark_mode: bool, sfx_volume: float, survey_view_mode: String = "", extras: Dictionary = {}) -> Dictionary:
	var preferences: Dictionary = {
		"selected_theme_id": selected_theme_id,
		"use_dark_mode": use_dark_mode,
		"sfx_volume": snappedf(sfx_volume, 0.01)
	}
	if not survey_view_mode.strip_edges().is_empty():
		preferences["survey_view_mode"] = survey_view_mode.strip_edges()
	for raw_key in extras.keys():
		var key := str(raw_key).strip_edges()
		if key.is_empty():
			continue
		preferences[key] = extras.get(raw_key)
	return preferences

static func show_modifier_restore_toast(toast_overlay, message: String) -> void:
	if toast_overlay == null:
		return
	var resolved_message := message.strip_edges()
	if resolved_message.is_empty():
		resolved_message = DEFAULT_MODIFIER_RESTORE_MESSAGE
	toast_overlay.show_toast(resolved_message, "modifier", MODIFIER_RESTORE_ACTION_ID, "Turn Modifiers Back On", true)

static func handle_modifier_restore_action(action_id: String, set_modifiers_enabled: Callable, toast_overlay) -> bool:
	if action_id != MODIFIER_RESTORE_ACTION_ID:
		return false
	if set_modifiers_enabled.is_valid():
		set_modifiers_enabled.call(true)
	if toast_overlay != null:
		toast_overlay.show_toast("Question modifiers are back on for this run.", "success")
	return true
