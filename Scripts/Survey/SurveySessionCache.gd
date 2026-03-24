class_name SurveySessionCache
extends RefCounted

const CACHE_DIR := "user://survey_cache"
const SURVEY_SAVE_BUNDLE = preload("res://Scripts/Survey/SurveySaveBundle.gd")

static func load_session(survey: SurveyDefinition, template_path: String) -> Dictionary:
	var cache_path: String = _cache_path(survey, template_path)
	if not FileAccess.file_exists(cache_path):
		return {}
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Dictionary = SURVEY_SAVE_BUNDLE.parse_json_text(file.get_as_text())
	if payload.is_empty():
		return {}
	if str(payload.get("template_path", "")).is_empty():
		payload["template_path"] = template_path
	return payload

static func load_answers(survey: SurveyDefinition, template_path: String) -> Dictionary:
	var session_payload: Dictionary = load_session(survey, template_path)
	var answers_value: Variant = session_payload.get("answers", {})
	if answers_value is Dictionary:
		return (answers_value as Dictionary).duplicate(true)
	return {}

static func load_preferences(survey: SurveyDefinition, template_path: String) -> Dictionary:
	var session_payload: Dictionary = load_session(survey, template_path)
	var preferences_value: Variant = session_payload.get("preferences", {})
	if preferences_value is Dictionary:
		return (preferences_value as Dictionary).duplicate(true)
	return {}

static func load_session_state(survey: SurveyDefinition, template_path: String) -> Dictionary:
	var session_payload: Dictionary = load_session(survey, template_path)
	var session_state_value: Variant = session_payload.get("session_state", {})
	if session_state_value is Dictionary:
		return (session_state_value as Dictionary).duplicate(true)
	return {}

static func save_session(survey: SurveyDefinition, template_path: String, answers: Dictionary, preferences: Dictionary = {}, session_state: Dictionary = {}) -> bool:
	if not _ensure_cache_dir():
		return false
	var cache_path: String = _cache_path(survey, template_path)
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(SURVEY_SAVE_BUNDLE.build_json_text(survey, template_path, answers, preferences, session_state))
	file.close()
	return true

static func save_answers(survey: SurveyDefinition, template_path: String, answers: Dictionary) -> bool:
	return save_session(survey, template_path, answers)

static func clear_session(survey: SurveyDefinition, template_path: String) -> void:
	var cache_path: String = _cache_path(survey, template_path)
	var absolute_path: String = ProjectSettings.globalize_path(cache_path)
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(absolute_path)

static func clear_answers(survey: SurveyDefinition, template_path: String) -> void:
	clear_session(survey, template_path)

static func _ensure_cache_dir() -> bool:
	var absolute_dir: String = ProjectSettings.globalize_path(CACHE_DIR)
	var result: int = DirAccess.make_dir_recursive_absolute(absolute_dir)
	return result == OK or DirAccess.dir_exists_absolute(absolute_dir)

static func _cache_path(survey: SurveyDefinition, template_path: String) -> String:
	var survey_segment: String = _safe_segment(survey.id if survey != null else "survey")
	var template_segment: String = _safe_segment(template_path.get_file().get_basename())
	if template_segment.is_empty():
		template_segment = "embedded"
	return "%s/%s__%s.json" % [CACHE_DIR, survey_segment, template_segment]

static func _safe_segment(raw_value: String) -> String:
	var value: String = raw_value.to_lower().strip_edges()
	if value.is_empty():
		return "survey"
	for token in ["/", "\\", ":", ".", " ", "-", "(", ")", "[", "]"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	while value.begins_with("_"):
		value = value.substr(1)
	while value.ends_with("_"):
		value = value.left(value.length() - 1)
	return value if not value.is_empty() else "survey"
