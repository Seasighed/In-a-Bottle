class_name SurveySaveBundle
extends RefCounted

const FORMAT_ID := "survey_session_bundle"
const CURRENT_VERSION := 3

static func build_payload(survey: SurveyDefinition, template_path: String, answers: Dictionary, preferences: Dictionary = {}, session_state: Dictionary = {}, scrub_identifying_info: bool = false) -> Dictionary:
	var survey_payload: Dictionary = {
		"id": survey.id if survey != null else "",
		"title": survey.title if survey != null else "",
		"template_path": template_path,
		"template_version": survey.template_version if survey != null else 0,
		"schema_hash": survey.schema_hash if survey != null else "",
		"asks_identifying_info": survey.asks_identifying_info if survey != null else false
	}
	var payload: Dictionary = {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"survey": survey_payload,
		"question_catalog": _build_question_catalog(survey),
		"preferences": _normalize_preferences(preferences),
		"session_state": _normalize_session_state(session_state),
		"answers": _filtered_answers(survey, answers, scrub_identifying_info),
		"scrub_identifying_info": scrub_identifying_info
	}
	return payload

static func build_json_text(survey: SurveyDefinition, template_path: String, answers: Dictionary, preferences: Dictionary = {}, session_state: Dictionary = {}, scrub_identifying_info: bool = false) -> String:
	return JSON.stringify(build_payload(survey, template_path, answers, preferences, session_state, scrub_identifying_info), "\t")

static func parse_json_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return _normalize_payload(parsed as Dictionary)

static func suggested_filename(survey_id: String) -> String:
	var safe_id: String = _safe_segment(survey_id if not survey_id.is_empty() else "survey")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return "%s_progress_%s.json" % [safe_id, stamp]

static func _filtered_answers(survey: SurveyDefinition, answers: Dictionary, scrub_identifying_info: bool) -> Dictionary:
	if not scrub_identifying_info or survey == null:
		return answers.duplicate(true)
	var filtered: Dictionary = {}
	for section in survey.sections:
		for question in section.questions:
			if question.asks_identifying_info:
				continue
			if answers.has(question.id):
				filtered[question.id] = answers.get(question.id)
	return filtered

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
		"template_version": int(root.get("template_version", 0)),
		"schema_hash": str(root.get("schema_hash", "")).strip_edges(),
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
		"template_version": int(survey_payload.get("template_version", root.get("template_version", 0))),
		"schema_hash": str(survey_payload.get("schema_hash", root.get("schema_hash", ""))).strip_edges(),
		"saved_at": str(root.get("saved_at", root.get("exported_at", ""))),
		"preferences": _normalize_preferences(preferences_payload),
		"session_state": _normalize_session_state(session_state_payload),
		"answers": answers_payload.duplicate(true)
	}
	var question_catalog_value: Variant = root.get("question_catalog", [])
	if question_catalog_value is Array:
		canonical["question_catalog"] = (question_catalog_value as Array).duplicate(true)
	return canonical

static func _build_question_catalog(survey: SurveyDefinition) -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	if survey == null:
		return catalog
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var questions_payload: Array = []
		var section_payload: Dictionary = {
			"section_id": section.id,
			"section_number": section_index + 1,
			"title": section.title.strip_edges(),
			"questions": questions_payload
		}
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var question_payload: Dictionary = {
				"question_id": question.id,
				"question_number": question_index + 1,
				"display_number": "%d.%d" % [section_index + 1, question_index + 1],
				"prompt": question.prompt.strip_edges(),
				"question_type": str(question.type),
				"required": question.required,
				"asks_identifying_info": question.asks_identifying_info
			}
			if question.has_modifier():
				question_payload["modifier"] = question.modifier_key
			if not question.modifier_settings.is_empty():
				question_payload["modifier_settings"] = question.modifier_settings.duplicate(true)
			if question.reward_count_configured:
				question_payload["reward_count"] = question.reward_count
			if not question.reward_sprite.is_empty():
				question_payload["reward_sprite"] = question.reward_sprite
			questions_payload.append(question_payload)
		catalog.append(section_payload)
	return catalog

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

	var hover_sfx_key := ""
	for candidate in ["hover_sfx_enabled", "enable_hover_sfx", "hover_audio_enabled"]:
		if source.has(candidate):
			hover_sfx_key = candidate
			break
	if not hover_sfx_key.is_empty():
		resolved_preferences["hover_sfx_enabled"] = bool(source.get(hover_sfx_key, false))

	var survey_view_mode: String = str(source.get("survey_view_mode", source.get("view_mode", ""))).to_lower().strip_edges()
	if survey_view_mode == "scroll" or survey_view_mode == "focus" or survey_view_mode == "auto":
		resolved_preferences["survey_view_mode"] = survey_view_mode

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
	for candidate in ["answer_change_xp_awards", "answer_change_awards"]:
		if not source.has(candidate):
			continue
		var awards_value: Variant = source.get(candidate, {})
		if not (awards_value is Dictionary):
			break
		var normalized_awards: Dictionary = {}
		for question_id_variant in (awards_value as Dictionary).keys():
			var question_id: String = str(question_id_variant).strip_edges()
			if question_id.is_empty():
				continue
			normalized_awards[question_id] = max(0, int((awards_value as Dictionary).get(question_id_variant, 0)))
		if not normalized_awards.is_empty():
			resolved_state["answer_change_xp_awards"] = normalized_awards
		break
	for numeric_key in ["session_started_at_unix", "first_answer_at_unix", "last_answer_at_unix", "answer_change_count"]:
		if source.has(numeric_key):
			resolved_state[numeric_key] = max(0, int(source.get(numeric_key, 0)))
	if source.has("restored_progress"):
		resolved_state["restored_progress"] = bool(source.get("restored_progress", false))
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
