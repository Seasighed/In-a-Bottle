class_name SurveySessionStateSupport
extends RefCounted

const SURVEY_UPLOAD_AUDIT_STORE = preload("res://Scripts/Survey/SurveyUploadAuditStore.gd")

static func build_response_quality_state(session_started_at_unix: int, first_answer_at_unix: int, last_answer_at_unix: int, answer_change_count: int, restored_progress: bool) -> Dictionary:
	return {
		"session_started_at_unix": max(0, session_started_at_unix),
		"first_answer_at_unix": max(0, first_answer_at_unix),
		"last_answer_at_unix": max(0, last_answer_at_unix),
		"answer_change_count": max(0, answer_change_count),
		"restored_progress": restored_progress
	}

static func restore_response_quality_state(restored_state: Dictionary, restored_progress: bool, answered_question_count: int) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var session_started_at_unix: int = max(0, int(restored_state.get("session_started_at_unix", now)))
	if session_started_at_unix <= 0 or session_started_at_unix > now:
		session_started_at_unix = now
	var first_answer_at_unix: int = clampi(int(restored_state.get("first_answer_at_unix", 0)), 0, now)
	var last_answer_at_unix: int = clampi(int(restored_state.get("last_answer_at_unix", 0)), 0, now)
	if first_answer_at_unix > 0 and first_answer_at_unix < session_started_at_unix:
		first_answer_at_unix = session_started_at_unix
	if last_answer_at_unix > 0 and last_answer_at_unix < first_answer_at_unix:
		last_answer_at_unix = first_answer_at_unix
	var answer_change_count: int = max(0, int(restored_state.get("answer_change_count", 0)))
	if answer_change_count <= 0:
		answer_change_count = max(answered_question_count, 0)
	return build_response_quality_state(
		session_started_at_unix,
		first_answer_at_unix,
		last_answer_at_unix,
		answer_change_count,
		restored_progress or bool(restored_state.get("restored_progress", false))
	)

static func register_response_answer_change(question: SurveyQuestion, previous_value: Variant, next_value: Variant, current_state: Dictionary) -> Dictionary:
	var state: Dictionary = _normalized_response_quality_state(current_state)
	if question == null or previous_value == next_value:
		return state
	var now: int = int(Time.get_unix_time_from_system())
	var session_started_at_unix: int = int(state.get("session_started_at_unix", 0))
	var first_answer_at_unix: int = int(state.get("first_answer_at_unix", 0))
	var last_answer_at_unix: int = int(state.get("last_answer_at_unix", 0))
	var answer_change_count: int = int(state.get("answer_change_count", 0))
	if session_started_at_unix <= 0:
		session_started_at_unix = now
	answer_change_count += 1
	if not question.is_answer_empty(next_value):
		if first_answer_at_unix <= 0:
			first_answer_at_unix = now
		last_answer_at_unix = now
	elif last_answer_at_unix <= 0:
		last_answer_at_unix = now
	return build_response_quality_state(
		session_started_at_unix,
		first_answer_at_unix,
		last_answer_at_unix,
		answer_change_count,
		bool(state.get("restored_progress", false))
	)

static func answered_question_count(survey: SurveyDefinition, answers: Dictionary) -> int:
	if survey == null:
		return 0
	var count := 0
	for section in survey.sections:
		for question in section.questions:
			if not question.is_answer_empty(answers.get(question.id, null)):
				count += 1
	return count

static func completed_answer_count(survey: SurveyDefinition, answers: Dictionary) -> int:
	if survey == null:
		return 0
	var count := 0
	for section in survey.sections:
		for question in section.questions:
			if question.is_answer_complete(answers.get(question.id, null)):
				count += 1
	return count

static func build_upload_quality_metadata(survey: SurveyDefinition, answers: Dictionary, response_quality_state: Dictionary, template_load_count_this_session: int = 1) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var state: Dictionary = _normalized_response_quality_state(response_quality_state)
	var session_started_at_unix: int = int(state.get("session_started_at_unix", 0))
	if session_started_at_unix <= 0:
		session_started_at_unix = now
	var answered_question_count_value: int = answered_question_count(survey, answers)
	var completed_answer_count_value: int = completed_answer_count(survey, answers)
	var session_duration_seconds: int = max(now - session_started_at_unix, 0)
	var first_answer_at_unix: int = int(state.get("first_answer_at_unix", 0))
	var seconds_to_first_answer := -1
	if first_answer_at_unix > 0:
		seconds_to_first_answer = max(first_answer_at_unix - session_started_at_unix, 0)
	var last_answer_at_unix: int = int(state.get("last_answer_at_unix", 0))
	var seconds_since_last_answer := -1
	if last_answer_at_unix > 0:
		seconds_since_last_answer = max(now - last_answer_at_unix, 0)
	var answers_per_minute := 0.0
	if session_duration_seconds > 0:
		answers_per_minute = (float(answered_question_count_value) * 60.0) / float(session_duration_seconds)
	return {
		"session_duration_seconds": session_duration_seconds,
		"seconds_to_first_answer": seconds_to_first_answer,
		"seconds_since_last_answer": seconds_since_last_answer,
		"answer_change_count": int(state.get("answer_change_count", 0)),
		"distinct_answered_question_count": answered_question_count_value,
		"completed_answered_question_count": completed_answer_count_value,
		"answers_per_minute": answers_per_minute,
		"template_load_count_this_session": max(template_load_count_this_session, 1),
		"restored_progress": bool(state.get("restored_progress", false))
	}

static func upload_template_key(survey: SurveyDefinition) -> String:
	if survey == null:
		return ""
	return SURVEY_UPLOAD_AUDIT_STORE.template_key_for_values(survey.id, survey.template_version, survey.schema_hash)

static func build_upload_audit_context(session_metrics: Dictionary, survey: SurveyDefinition, limits: Dictionary = {}) -> Dictionary:
	var context: Dictionary = session_metrics.duplicate(true)
	context["template_key"] = upload_template_key(survey)
	for key in limits.keys():
		context[str(key)] = limits.get(key)
	return context

static func build_session_state(current_section_index: int, selected_question_id: String, response_quality_state: Dictionary, extras: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _normalized_response_quality_state(response_quality_state)
	state["current_section_index"] = max(current_section_index, 0)
	var resolved_question_id := selected_question_id.strip_edges()
	if not resolved_question_id.is_empty():
		state["selected_question_id"] = resolved_question_id
	for raw_key in extras.keys():
		var key := str(raw_key).strip_edges()
		if key.is_empty():
			continue
		state[key] = extras.get(raw_key)
	return state

static func _normalized_response_quality_state(source: Dictionary) -> Dictionary:
	return build_response_quality_state(
		int(source.get("session_started_at_unix", 0)),
		int(source.get("first_answer_at_unix", 0)),
		int(source.get("last_answer_at_unix", 0)),
		int(source.get("answer_change_count", 0)),
		bool(source.get("restored_progress", false))
	)
