class_name SurveyGamificationHub
extends Node

const STORE = preload("res://Scripts/Survey/SurveyGamificationStore.gd")

signal award_resolved(result: Dictionary)
signal profile_changed(profile: Dictionary)

var _profile: Dictionary = {}

func _ready() -> void:
	_profile = STORE.load_profile()
	profile_changed.emit(current_profile())

func current_profile() -> Dictionary:
	return _profile.duplicate(true)

func current_snapshot(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	return STORE.build_profile_snapshot(_profile, survey, answers)

func save_profile() -> void:
	STORE.save_profile(_profile)

func award_question_lock(question: SurveyQuestion, base_xp: int, screen_pos: Vector2 = Vector2.ZERO, question_reward_key: String = "", max_question_xp: int = 0) -> Dictionary:
	return _apply_result(STORE.award_question_lock(_profile, question, base_xp, screen_pos, question_reward_key, max_question_xp))

func award_section_complete(section_id: String, section_title: String, screen_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	return _apply_result(STORE.award_section_complete(_profile, section_id, section_title, screen_pos))

func award_survey_complete(survey_id: String, survey_title: String, screen_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	return _apply_result(STORE.award_survey_complete(_profile, survey_id, survey_title, screen_pos))

func _apply_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	if result.has("profile") and result.get("profile") is Dictionary:
		_profile = (result.get("profile") as Dictionary).duplicate(true)
		STORE.save_profile(_profile)
		profile_changed.emit(current_profile())
	award_resolved.emit(result.duplicate(true))
	return result
