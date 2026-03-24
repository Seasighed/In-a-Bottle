class_name SurveySaveBundle
extends RefCounted

const FORMAT_ID := "survey_session_bundle"
const CURRENT_VERSION := 2

static func build_payload(survey: SurveyDefinition, template_path: String, answers: Dictionary, preferences: Dictionary = {}, session_state: Dictionary = {}) -> Dictionary:
	var survey_payload: Dictionary = {
		"id": survey.id if survey != null else "",
		"title": survey.title if survey != null else "",
		"template_path": template_path
	}
	var payload: Dictionary = {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"survey": survey_payload,
		"preferences": _normalize_preferences(preferences),
		"session_state": _normalize_session_state(session_state),
		"answers": answers.duplicate(true)
	}
	return payload

static func build_json_text(survey: SurveyDefinition, template_path: String, answers: Dictionary, preferences: Dictionary = {}, session_state: Dictionary = {}) -> String:
	return JSON.stringify(build_payload(survey, template_path, answers, preferences, session_state), "\t")

static func parse_json_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return _normalize_payload(parsed as Dictionary)

static func suggested_filename(survey_id: String) -> String:
	var safe_id: String = _safe_segment(survey_id if not survey_id.is_empty() else "survey")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return "%s_progress_%s.json" % [safe_id, stamp]

static func _normalize_payload(root: Dictionary) -> Dictionary:
	var answers_value: Variant = root.get("answers", null)
	if answers_value is Array:
		return _normalize_export_payload(root)
	return _canonicalize_payload(root)

static func _normalize_export_payload(root: Dictionary) -> Dictionary:
	var flattened_answers: Dictionary = {}
	var answers_value: Variant = root.get("answers", [])
	if answers_value is Array:
		var section_payloads: Array = answers_value as Array
		for section_value in section_payloads:
			if not (section_value is Dictionary):
				continue
			var section_payload: Dictionary = section_value as Dictionary
			var responses_value: Variant = section_payload.get("responses", [])
			if not (responses_value is Array):
				continue
			var responses: Array = responses_value as Array
			for response_value in responses:
				if not (response_value is Dictionary):
					continue
				var response: Dictionary = response_value as Dictionary
				var question_id: String = str(response.get("question_id", "")).strip_edges()
				if question_id.is_empty():
					continue
				flattened_answers[question_id] = response.get("answer", null)
	var legacy_payload: Dictionary = {
		"survey_id": str(root.get("survey_id", "")),
		"saved_at": str(root.get("exported_at", root.get("saved_at", ""))),
		"answers": flattened_answers,
		"preferences": {},
		"session_state": {}
	}
	return _canonicalize_payload(legacy_payload)

static func _canonicalize_payload(root: Dictionary) -> Dictionary:
	var survey_value: Variant = root.get("survey", {})
	var survey_payload: Dictionary = survey_value as Dictionary if survey_value is Dictionary else {}
	var answers_value: Variant = root.get("answers", {})
	var answers_payload: Dictionary = answers_value as Dictionary if answers_value is Dictionary else {}
	var preferences_value: Variant = root.get("preferences", root.get("ui_preferences", {}))
	var preferences_payload: Dictionary = preferences_value as Dictionary if preferences_value is Dictionary else {}
	var session_state_value: Variant = root.get("session_state", root.get("navigation", {}))
	var session_state_payload: Dictionary = session_state_value as Dictionary if session_state_value is Dictionary else {}
	var canonical: Dictionary = {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"survey_id": str(survey_payload.get("id", root.get("survey_id", ""))),
		"template_path": str(survey_payload.get("template_path", root.get("template_path", ""))),
		"saved_at": str(root.get("saved_at", root.get("exported_at", ""))),
		"preferences": _normalize_preferences(preferences_payload),
		"session_state": _normalize_session_state(session_state_payload),
		"answers": answers_payload.duplicate(true)
	}
	return canonical

static func _normalize_preferences(source: Dictionary) -> Dictionary:
	var resolved_preferences: Dictionary = {}
	if source.has("use_dark_mode"):
		resolved_preferences["use_dark_mode"] = bool(source.get("use_dark_mode", true))
	elif source.has("dark_mode"):
		resolved_preferences["use_dark_mode"] = bool(source.get("dark_mode", true))

	if source.has("onboarding_completed"):
		resolved_preferences["onboarding_completed"] = bool(source.get("onboarding_completed", false))
	elif source.has("dismissed_onboarding"):
		resolved_preferences["onboarding_completed"] = bool(source.get("dismissed_onboarding", false))

	var onboarding_mode: String = _normalize_text_value(source.get("onboarding_mode", source.get("preferred_entry_mode", "")))
	if not onboarding_mode.is_empty():
		resolved_preferences["onboarding_mode"] = onboarding_mode

	var preferred_topic_tag: String = _normalize_identifier_value(source.get("preferred_topic_tag", source.get("preferred_topic", "")))
	if not preferred_topic_tag.is_empty():
		resolved_preferences["preferred_topic_tag"] = preferred_topic_tag

	var preferred_audience_id: String = _normalize_identifier_value(source.get("preferred_audience_id", source.get("preferred_audience", "")))
	if not preferred_audience_id.is_empty():
		resolved_preferences["preferred_audience_id"] = preferred_audience_id

	var last_onboarding_query: String = _normalize_text_value(source.get("last_onboarding_query", source.get("last_search_query", "")))
	if not last_onboarding_query.is_empty():
		resolved_preferences["last_onboarding_query"] = last_onboarding_query

	var sfx_volume_key := ""
	for candidate in ["sfx_volume", "ui_sfx_volume", "audio_volume", "effects_volume"]:
		if source.has(candidate):
			sfx_volume_key = candidate
			break
	if not sfx_volume_key.is_empty():
		resolved_preferences["sfx_volume"] = clampf(float(source.get(sfx_volume_key, 0.65)), 0.0, 1.0)

	if source.has("remember_onboarding_preferences"):
		resolved_preferences["remember_onboarding_preferences"] = bool(source.get("remember_onboarding_preferences", true))
	elif source.has("remember_onboarding"):
		resolved_preferences["remember_onboarding_preferences"] = bool(source.get("remember_onboarding", true))

	if source.has("allow_local_session_cache"):
		resolved_preferences["allow_local_session_cache"] = bool(source.get("allow_local_session_cache", true))
	elif source.has("local_session_cache"):
		resolved_preferences["allow_local_session_cache"] = bool(source.get("local_session_cache", true))

	return resolved_preferences

static func _normalize_session_state(source: Dictionary) -> Dictionary:
	var resolved_state: Dictionary = {}
	if source.has("current_section_index"):
		resolved_state["current_section_index"] = max(0, int(source.get("current_section_index", 0)))
	if source.has("selected_question_id"):
		var selected_question_id: String = str(source.get("selected_question_id", "")).strip_edges()
		if not selected_question_id.is_empty():
			resolved_state["selected_question_id"] = selected_question_id
	return resolved_state

static func _normalize_text_value(value: Variant) -> String:
	return str(value).strip_edges()

static func _normalize_identifier_value(value: Variant) -> String:
	return str(value).to_lower().strip_edges().replace("-", "_").replace(" ", "_")

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
