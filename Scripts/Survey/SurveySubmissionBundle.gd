class_name SurveySubmissionBundle
extends RefCounted

const FORMAT_ID := "survey_submission_bundle"
const CURRENT_VERSION := 1
const MAX_SHORT_TEXT_LENGTH := 280
const MAX_LONG_TEXT_LENGTH := 4000
const MAX_EMAIL_LENGTH := 254
const MAX_DATE_LENGTH := 32
const MAX_OPTION_LENGTH := 160

static func build_package(survey: SurveyDefinition, template_path: String, answers: Dictionary, summary_data: Dictionary = {}, install_id: String = "") -> Dictionary:
	if survey == null:
		return {}

	var sections_payload: Array[Dictionary] = []
	var valid_response_count := 0
	var complete_answered_count := 0
	var sections_with_responses_count := 0
	var dropped_response_count := 0
	var dropped_question_ids: Array[String] = []

	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var section_responses: Array[Dictionary] = []
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var raw_value: Variant = answers.get(question.id, null)
			var normalized: Dictionary = _normalize_answer(question, raw_value)
			if not bool(normalized.get("has_response", false)):
				if not normalized.get("dropped_reason", "").is_empty():
					dropped_response_count += 1
					dropped_question_ids.append(question.id)
				continue

			valid_response_count += 1
			if bool(normalized.get("is_complete", false)):
				complete_answered_count += 1

			var response_payload: Dictionary = {
				"question_id": question.id,
				"question_number": question_index + 1,
				"display_number": "%d.%d" % [section_index + 1, question_index + 1],
				"prompt": question.prompt.strip_edges(),
				"question_type": str(question.type),
				"required": question.required,
				"response_state": normalized.get("response_state", "complete"),
				"answer": normalized.get("value", null)
			}
			var score_percent: float = question.answer_score_percent(normalized.get("value", null))
			if score_percent >= 0.0:
				response_payload["score_percent"] = snappedf(score_percent, 0.1)
			section_responses.append(response_payload)

		if section_responses.is_empty():
			continue
		sections_with_responses_count += 1
		sections_payload.append({
			"section_id": section.id,
			"section_number": section_index + 1,
			"title": section.title.strip_edges(),
			"responses": section_responses
		})

	var stats: Dictionary = {
		"valid_response_count": valid_response_count,
		"complete_answered_question_count": complete_answered_count,
		"sections_with_responses_count": sections_with_responses_count,
		"total_question_count": survey.total_questions(),
		"total_section_count": survey.sections.size(),
		"dropped_response_count": dropped_response_count
	}

	var payload: Dictionary = {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"submitted_at": Time.get_datetime_string_from_system(true),
		"survey": {
			"id": survey.id,
			"title": survey.title,
			"subtitle": survey.subtitle,
			"template_path": template_path
		},
		"client": {
			"install_id": install_id,
			"platform": OS.get_name(),
			"is_debug_build": OS.is_debug_build()
		},
		"stats": stats,
		"summary": _sanitize_summary(summary_data),
		"responses": sections_payload
	}
	if not dropped_question_ids.is_empty():
		payload["dropped_question_ids"] = dropped_question_ids

	var json_text: String = JSON.stringify(payload, "\t")
	var payload_hash: String = _sha256_text(json_text)
	payload["client_payload_hash"] = payload_hash
	json_text = JSON.stringify(payload, "\t")

	return {
		"payload": payload,
		"json": json_text,
		"payload_hash": payload_hash,
		"stats": stats,
		"dropped_question_ids": dropped_question_ids
	}

static func _sanitize_summary(summary_data: Dictionary) -> Dictionary:
	if summary_data.is_empty():
		return {}
	var section_scores: Array[Dictionary] = []
	var sections_value: Variant = summary_data.get("sections", [])
	if sections_value is Array:
		for raw_section in sections_value:
			if not (raw_section is Dictionary):
				continue
			var section: Dictionary = raw_section as Dictionary
			section_scores.append({
				"section_id": str(section.get("section_id", "")).strip_edges(),
				"section_number": int(section.get("section_number", 0)),
				"title": str(section.get("title", "")).strip_edges(),
				"answered_question_count": int(section.get("answered_question_count", 0)),
				"score_percent": float(section.get("score_percent", -1.0))
			})
	return {
		"answered_question_count": int(summary_data.get("answered_question_count", 0)),
		"sections_answered_count": int(summary_data.get("sections_answered_count", 0)),
		"overall_score_percent": float(summary_data.get("overall_score_percent", -1.0)),
		"overall_sentiment_label": str(summary_data.get("overall_sentiment_label", "")).strip_edges(),
		"section_scores": section_scores
	}

static func _normalize_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return _normalize_text_answer(raw_value, MAX_SHORT_TEXT_LENGTH, question.is_answer_complete(raw_value))
		SurveyQuestion.TYPE_LONG_TEXT:
			return _normalize_text_answer(raw_value, MAX_LONG_TEXT_LENGTH, question.is_answer_complete(raw_value), true)
		SurveyQuestion.TYPE_EMAIL:
			return _normalize_email_answer(raw_value)
		SurveyQuestion.TYPE_DATE:
			return _normalize_date_answer(raw_value)
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			return _normalize_single_choice_answer(question, raw_value)
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return _normalize_multi_choice_answer(question, raw_value)
		SurveyQuestion.TYPE_BOOLEAN:
			return _normalize_boolean_answer(raw_value)
		SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS, SurveyQuestion.TYPE_NUMBER:
			return _normalize_numeric_answer(question, raw_value)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return _normalize_ranked_choice_answer(question, raw_value)
		SurveyQuestion.TYPE_MATRIX:
			return _normalize_matrix_answer(question, raw_value)
	return _normalize_text_answer(raw_value, MAX_SHORT_TEXT_LENGTH, question.is_answer_complete(raw_value))

static func _normalize_text_answer(raw_value: Variant, max_length: int, is_complete: bool, preserve_newlines: bool = false) -> Dictionary:
	var text_value: String = str(raw_value).strip_edges()
	if text_value.is_empty():
		return _no_response()
	if not preserve_newlines:
		text_value = " ".join(text_value.split("\n", false)).replace("\t", " ")
	while text_value.contains("  "):
		text_value = text_value.replace("  ", " ")
	text_value = text_value.substr(0, min(text_value.length(), max_length))
	if text_value.is_empty():
		return _no_response("blank_after_trim")
	return _response(text_value, is_complete)

static func _normalize_email_answer(raw_value: Variant) -> Dictionary:
	var text_value: String = str(raw_value).strip_edges().to_lower()
	if text_value.is_empty():
		return _no_response()
	text_value = text_value.substr(0, min(text_value.length(), MAX_EMAIL_LENGTH))
	if not text_value.contains("@"):
		return _no_response("invalid_email")
	var fragments: PackedStringArray = text_value.split("@")
	if fragments.size() != 2:
		return _no_response("invalid_email")
	if fragments[0].strip_edges().is_empty() or fragments[1].strip_edges().is_empty() or not fragments[1].contains("."):
		return _no_response("invalid_email")
	return _response(text_value, true)

static func _normalize_date_answer(raw_value: Variant) -> Dictionary:
	var text_value: String = str(raw_value).strip_edges()
	if text_value.is_empty():
		return _no_response()
	text_value = text_value.substr(0, min(text_value.length(), MAX_DATE_LENGTH))
	var date_regex := RegEx.new()
	date_regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if date_regex.search(text_value) == null:
		return _no_response("invalid_date")
	return _response(text_value, true)

static func _normalize_single_choice_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	var selection: String = str(raw_value).strip_edges()
	if selection.is_empty():
		return _no_response()
	if question.options.find(selection) == -1:
		return _no_response("invalid_option")
	return _response(selection.substr(0, min(selection.length(), MAX_OPTION_LENGTH)), true)

static func _normalize_multi_choice_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	var raw_items: Array = []
	if raw_value is Array:
		raw_items = (raw_value as Array)
	elif typeof(raw_value) != TYPE_NIL:
		raw_items = [raw_value]
	var selections: Array[String] = []
	for item in raw_items:
		var selection: String = str(item).strip_edges()
		if selection.is_empty() or question.options.find(selection) == -1 or selections.has(selection):
			continue
		selections.append(selection.substr(0, min(selection.length(), MAX_OPTION_LENGTH)))
	if selections.is_empty():
		return _no_response("invalid_option")
	return _response(selections, question.is_answer_complete(selections), "complete" if question.is_answer_complete(selections) else "partial")

static func _normalize_boolean_answer(raw_value: Variant) -> Dictionary:
	if typeof(raw_value) == TYPE_BOOL:
		return _response(bool(raw_value), true)
	var text_value: String = str(raw_value).strip_edges().to_lower()
	if text_value.is_empty():
		return _no_response()
	if text_value in ["true", "yes", "1"]:
		return _response(true, true)
	if text_value in ["false", "no", "0"]:
		return _response(false, true)
	return _no_response("invalid_boolean")

static func _normalize_numeric_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	var numeric_value := 0.0
	match typeof(raw_value):
		TYPE_INT, TYPE_FLOAT:
			numeric_value = float(raw_value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text_value: String = str(raw_value).strip_edges()
			if text_value.is_empty() or (not text_value.is_valid_int() and not text_value.is_valid_float()):
				return _no_response("invalid_number")
			numeric_value = float(text_value)
		_:
			return _no_response("invalid_number")
	var clamped_value: float = clampf(numeric_value, float(question.min_value), float(question.max_value))
	if is_equal_approx(clamped_value, round(clamped_value)):
		return _response(int(round(clamped_value)), true)
	return _response(snappedf(clamped_value, question.step if question.step > 0.0 else 0.01), true)

static func _normalize_ranked_choice_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	var raw_items: Array = []
	if raw_value is Array:
		raw_items = raw_value as Array
	elif typeof(raw_value) != TYPE_NIL:
		raw_items = [raw_value]
	var ranked: Array[String] = []
	for item in raw_items:
		var selection: String = str(item).strip_edges()
		if selection.is_empty() or question.options.find(selection) == -1 or ranked.has(selection):
			continue
		ranked.append(selection.substr(0, min(selection.length(), MAX_OPTION_LENGTH)))
	if ranked.is_empty():
		return _no_response("invalid_option")
	return _response(ranked, question.is_answer_complete(ranked), "complete" if question.is_answer_complete(ranked) else "partial")

static func _normalize_matrix_answer(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	if not (raw_value is Dictionary):
		return _no_response("invalid_matrix")
	var source: Dictionary = raw_value as Dictionary
	var normalized: Dictionary = {}
	for row_name in question.rows:
		var selection: String = str(source.get(row_name, "")).strip_edges()
		if selection.is_empty() or question.options.find(selection) == -1:
			continue
		normalized[row_name] = selection.substr(0, min(selection.length(), MAX_OPTION_LENGTH))
	if normalized.is_empty():
		return _no_response("invalid_matrix")
	return _response(normalized, question.is_answer_complete(normalized), "complete" if question.is_answer_complete(normalized) else "partial")

static func _response(value: Variant, is_complete: bool, response_state: String = "complete") -> Dictionary:
	return {
		"has_response": true,
		"value": value,
		"is_complete": is_complete,
		"response_state": response_state,
		"dropped_reason": ""
	}

static func _no_response(reason: String = "") -> Dictionary:
	return {
		"has_response": false,
		"value": null,
		"is_complete": false,
		"response_state": "missing",
		"dropped_reason": reason
	}

static func _sha256_text(text: String) -> String:
	var context := HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()
