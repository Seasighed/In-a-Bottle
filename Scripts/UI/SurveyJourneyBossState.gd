class_name SurveyJourneyBossState
extends RefCounted

const MILESTONE_THRESHOLDS := [0.25, 0.5, 0.75, 1.0]

static func build_state(survey: SurveyDefinition, answers: Dictionary, committed_questions: Dictionary = {}) -> Dictionary:
	if survey == null:
		return {}
	var total_questions: int = max(survey.total_questions(), 0)
	var damage_per_question: float = 1.0 / float(total_questions) if total_questions > 0 else 0.0
	var filtered_committed: Dictionary = _filtered_committed_questions(survey, committed_questions)
	var complete_question_ids: Array[String] = []
	var partial_question_ids: Array[String] = []
	var unanswered_question_ids: Array[String] = []
	var question_section_map: Dictionary = {}
	var sections: Array[Dictionary] = []
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var section_committed_count := 0
		var section_complete_count := 0
		var section_partial_count := 0
		var section_unanswered_count := 0
		var question_ids: Array[String] = []
		for question in section.questions:
			var question_id: String = question.id
			question_section_map[question_id] = section_index
			question_ids.append(question_id)
			var answer_state: StringName = question.answer_completion_state(answers.get(question_id, null))
			match answer_state:
				SurveyQuestion.ANSWER_STATE_COMPLETE:
					complete_question_ids.append(question_id)
					section_complete_count += 1
				SurveyQuestion.ANSWER_STATE_PARTIAL:
					partial_question_ids.append(question_id)
					section_partial_count += 1
				_:
					unanswered_question_ids.append(question_id)
					section_unanswered_count += 1
			if filtered_committed.has(question_id):
				section_committed_count += 1
		var question_count := section.questions.size()
		var question_layer_damage_ratio := 1.0 / float(question_count) if question_count > 0 else 0.0
		var max_health: float = float(question_count) * damage_per_question
		var current_health: float = max(max_health - (float(section_committed_count) * damage_per_question), 0.0)
		var damage_ratio: float = 0.0 if max_health <= 0.0 else clampf((max_health - current_health) / max_health, 0.0, 1.0)
		var is_eliminated := current_health <= 0.0001 and max_health > 0.0
		sections.append({
			"section_id": section.id,
			"section_index": section_index,
			"title": section.title.strip_edges(),
			"display_title": section.display_title(section_index),
			"question_count": question_count,
			"question_ids": question_ids,
			"max_health": max_health,
			"current_health": current_health,
			"damage_ratio": damage_ratio,
			"question_total_damage_ratio": damage_per_question,
			"question_layer_damage_ratio": question_layer_damage_ratio,
			"is_broken": is_eliminated,
			"is_eliminated": is_eliminated,
			"committed_count": section_committed_count,
			"complete_count": section_complete_count,
			"partial_count": section_partial_count,
			"unanswered_count": section_unanswered_count
		})
	var total_committed_count: int = filtered_committed.size()
	var total_damage: float = float(total_committed_count) * damage_per_question
	var total_health: float = max(1.0 - total_damage, 0.0)
	var completion_ratio: float = float(complete_question_ids.size()) / float(total_questions) if total_questions > 0 else 0.0
	var partial_ratio: float = float(partial_question_ids.size()) / float(total_questions) if total_questions > 0 else 0.0
	var unanswered_ratio: float = float(unanswered_question_ids.size()) / float(total_questions) if total_questions > 0 else 0.0
	var wrapup_result: Dictionary = build_wrapup_result(total_questions, complete_question_ids.size(), partial_question_ids.size(), unanswered_question_ids.size(), completion_ratio)
	return {
		"total_questions": total_questions,
		"damage_per_question": damage_per_question,
		"committed_questions": filtered_committed.duplicate(true),
		"committed_count": total_committed_count,
		"complete_question_ids": complete_question_ids,
		"partial_question_ids": partial_question_ids,
		"unanswered_question_ids": unanswered_question_ids,
		"complete_count": complete_question_ids.size(),
		"partial_count": partial_question_ids.size(),
		"unanswered_count": unanswered_question_ids.size(),
		"question_section_map": question_section_map,
		"sections": sections,
		"total_damage": total_damage,
		"total_health": total_health,
		"damage_ratio": clampf(total_damage, 0.0, 1.0),
		"health_ratio": clampf(total_health, 0.0, 1.0),
		"completion_ratio": clampf(completion_ratio, 0.0, 1.0),
		"partial_ratio": clampf(partial_ratio, 0.0, 1.0),
		"unanswered_ratio": clampf(unanswered_ratio, 0.0, 1.0),
		"milestone_thresholds": MILESTONE_THRESHOLDS,
		"wrapup_result": wrapup_result
	}

static func build_wrapup_result(total_questions: int, complete_count: int, partial_count: int, unanswered_count: int, completion_ratio: float) -> Dictionary:
	var tier := "good_start"
	var headline := "Good Start"
	var body := "You have early momentum on this survey."
	var recommendation := "Open Review Answers and finish the unanswered questions before exporting."
	var primary_cta := "review"
	var is_victory := false
	if total_questions > 0 and complete_count >= total_questions:
		tier = "victory"
		headline = "Boss Defeated"
		body = "Every question landed. This survey is fully complete."
		recommendation = "Open the export screen to save or share the completed survey, or review answers for one final pass."
		primary_cta = "export"
		is_victory = true
	elif completion_ratio >= 0.75:
		tier = "near_win"
		headline = "Almost There"
		body = "You pushed the survey close to a full clear."
		recommendation = "Review the last unanswered questions first, then export once the survey is complete."
	elif completion_ratio >= 0.40:
		tier = "solid_progress"
		headline = "Solid Progress"
		body = "You landed a strong set of answers and set up an easy finish."
		recommendation = "Use Review Answers to complete the remaining questions before treating this as final."
	var progress_line := "%d complete" % complete_count
	if partial_count > 0:
		progress_line += "  |  %d partial" % partial_count
	progress_line += "  |  %d unanswered" % unanswered_count
	var wrapup_body := "%s %s" % [body, progress_line]
	if not is_victory:
		wrapup_body += " This is still a partially complete survey, and the ideal next step is to finish it."
	return {
		"tier": tier,
		"headline": headline,
		"body": wrapup_body.strip_edges(),
		"recommendation": recommendation.strip_edges(),
		"primary_cta": primary_cta,
		"is_victory": is_victory
	}

static func build_committed_questions_from_answers(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	var committed: Dictionary = {}
	if survey == null:
		return committed
	for section in survey.sections:
		for question in section.questions:
			if question.is_answer_complete(answers.get(question.id, null)):
				committed[question.id] = true
	return committed

static func charge_ratio_for_question(question: SurveyQuestion, value: Variant) -> float:
	if question == null:
		return 0.0
	match question.answer_completion_state(value):
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return 1.0
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return 0.45
	return 0.0

static func answered_counts_for_section(state: Dictionary, section_index: int) -> Dictionary:
	var sections_value: Variant = state.get("sections", [])
	if not (sections_value is Array):
		return {}
	var sections: Array = sections_value as Array
	if section_index < 0 or section_index >= sections.size():
		return {}
	var section_value: Variant = sections[section_index]
	return (section_value as Dictionary).duplicate(true) if section_value is Dictionary else {}

static func snapshot_hash(survey: SurveyDefinition, answers: Dictionary) -> String:
	if survey == null:
		return ""
	var lines: Array[String] = []
	lines.append(str(survey.id).strip_edges())
	for section in survey.sections:
		lines.append(str(section.id).strip_edges())
		for question in section.questions:
			lines.append("%s=%s" % [question.id, _stable_variant_text(answers.get(question.id, null))])
	return "|".join(lines)

static func milestone_keys_crossed(previous_ratio: float, next_ratio: float) -> Array[String]:
	var crossed: Array[String] = []
	var before := clampf(previous_ratio, 0.0, 1.0)
	var after := clampf(next_ratio, 0.0, 1.0)
	for threshold in MILESTONE_THRESHOLDS:
		if before < threshold and after >= threshold:
			crossed.append(_milestone_key(threshold))
	return crossed

static func milestone_label(key: String) -> String:
	match key:
		"25":
			return "25% broken"
		"50":
			return "50% broken"
		"75":
			return "75% broken"
		"100":
			return "Boss down"
	return key

static func _filtered_committed_questions(survey: SurveyDefinition, committed_questions: Dictionary) -> Dictionary:
	var filtered: Dictionary = {}
	if survey == null:
		return filtered
	for section in survey.sections:
		for question in section.questions:
			if committed_questions.has(question.id):
				filtered[question.id] = true
	return filtered

static func _milestone_key(threshold: float) -> String:
	return str(int(round(threshold * 100.0)))

static func _stable_variant_text(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"%s\"" % str(value).replace("\\", "\\\\").replace("\"", "\\\"")
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(_stable_variant_text(item))
			return "[%s]" % ",".join(parts)
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			var keys: Array[String] = []
			for key in dict.keys():
				keys.append(str(key))
			keys.sort()
			var dict_parts: Array[String] = []
			for key in keys:
				dict_parts.append("%s:%s" % [_stable_variant_text(key), _stable_variant_text(dict.get(key))])
			return "{%s}" % ",".join(dict_parts)
	return str(value)
