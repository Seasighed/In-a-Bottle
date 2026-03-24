class_name SurveySummaryAnalyzer
extends RefCounted

static func build_summary(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	if survey == null:
		return {}

	var section_summaries: Array[Dictionary] = []
	var answered_question_count := 0
	var sections_answered_count := 0
	var scored_question_count := 0
	var scored_section_count := 0
	var overall_weighted_total := 0.0
	var overall_total_weight := 0.0
	var all_score_values: Array[float] = []
	var strongest_section: Dictionary = {}
	var weakest_section: Dictionary = {}

	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var section_answered_count := 0
		var section_weighted_total := 0.0
		var section_total_weight := 0.0
		var scored_questions: Array[Dictionary] = []

		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var answer_value: Variant = answers.get(question.id, null)
			var is_answered: bool = question.is_answer_complete(answer_value)
			if is_answered:
				answered_question_count += 1
				section_answered_count += 1

			var score_percent: float = question.answer_score_percent(answer_value)
			if score_percent < 0.0:
				continue

			scored_question_count += 1
			all_score_values.append(score_percent)
			var effective_weight: float = _effective_weight(question)
			section_weighted_total += score_percent * effective_weight
			section_total_weight += effective_weight
			overall_weighted_total += score_percent * effective_weight
			overall_total_weight += effective_weight
			scored_questions.append({
				"question_id": question.id,
				"question_number": question_index + 1,
				"display_number": "%d.%d" % [section_index + 1, question_index + 1],
				"prompt": question.prompt.strip_edges(),
				"score_percent": snappedf(score_percent, 0.1),
				"score_label": _score_label(score_percent),
				"answer_text": _truncate_text(_answer_to_text(question, answer_value), 140)
			})

		if section_answered_count > 0:
			sections_answered_count += 1

		var section_score_percent := -1.0
		if section_total_weight > 0.0:
			section_score_percent = section_weighted_total / section_total_weight
			scored_section_count += 1

		var section_summary: Dictionary = {
			"section_id": section.id,
			"section_number": section_index + 1,
			"title": section.title.strip_edges(),
			"answered_question_count": section_answered_count,
			"total_question_count": section.questions.size(),
			"scored_question_count": scored_questions.size(),
			"score_percent": snappedf(section_score_percent, 0.1) if section_score_percent >= 0.0 else -1.0,
			"score_label": _score_label(section_score_percent),
			"questions": scored_questions
		}
		section_summaries.append(section_summary)

		if section_score_percent >= 0.0:
			if strongest_section.is_empty() or section_score_percent > float(strongest_section.get("score_percent", -1.0)):
				strongest_section = section_summary.duplicate(true)
			if weakest_section.is_empty() or section_score_percent < float(weakest_section.get("score_percent", 101.0)):
				weakest_section = section_summary.duplicate(true)

	var overall_score_percent := -1.0
	if overall_total_weight > 0.0:
		overall_score_percent = overall_weighted_total / overall_total_weight

	var answered_ratio: float = 0.0
	var total_questions: int = survey.total_questions()
	if total_questions > 0:
		answered_ratio = float(answered_question_count) / float(total_questions)

	return {
		"survey_id": survey.id,
		"survey_title": survey.title,
		"survey_subtitle": survey.subtitle,
		"answered_question_count": answered_question_count,
		"total_question_count": total_questions,
		"sections_answered_count": sections_answered_count,
		"total_section_count": survey.sections.size(),
		"scored_question_count": scored_question_count,
		"scored_section_count": scored_section_count,
		"overall_score_percent": snappedf(overall_score_percent, 0.1) if overall_score_percent >= 0.0 else -1.0,
		"overall_sentiment_label": _overall_sentiment_label(overall_score_percent),
		"overall_sentiment_summary": _overall_sentiment_summary(overall_score_percent, strongest_section, weakest_section),
		"adjective_suggestions": _build_adjective_suggestions(overall_score_percent, answered_ratio, all_score_values),
		"sections": section_summaries,
		"strongest_section": strongest_section,
		"weakest_section": weakest_section
	}

static func _effective_weight(question: SurveyQuestion) -> float:
	return question.rating_weight if question.rating_weight > 0.0 else 1.0

static func _overall_sentiment_label(score_percent: float) -> String:
	if score_percent < 0.0:
		return "No sentiment signal yet"
	if score_percent >= 85.0:
		return "Very positive"
	if score_percent >= 70.0:
		return "Positive"
	if score_percent >= 55.0:
		return "Mixed leaning positive"
	if score_percent >= 45.0:
		return "Mixed"
	if score_percent >= 30.0:
		return "Mixed leaning negative"
	return "Negative"

static func _overall_sentiment_summary(score_percent: float, strongest_section: Dictionary, weakest_section: Dictionary) -> String:
	if score_percent < 0.0:
		return "Answer rating-enabled questions, or opt more questions into ratings, to generate a sentiment snapshot."
	var parts: Array[String] = ["Rated answers currently land at %d%% overall." % int(round(score_percent))]
	if not strongest_section.is_empty():
		parts.append("Strongest section: %s (%d%%)." % [str(strongest_section.get("title", "Section")), int(round(float(strongest_section.get("score_percent", 0.0))))])
		if not weakest_section.is_empty() and str(weakest_section.get("section_id", "")) != str(strongest_section.get("section_id", "")):
			parts.append("Lowest section: %s (%d%%)." % [str(weakest_section.get("title", "Section")), int(round(float(weakest_section.get("score_percent", 0.0))))])
	return " ".join(parts)

static func _score_label(score_percent: float) -> String:
	if score_percent < 0.0:
		return "Not scored"
	if score_percent >= 85.0:
		return "Strong positive"
	if score_percent >= 70.0:
		return "Positive"
	if score_percent >= 55.0:
		return "Soft positive"
	if score_percent >= 45.0:
		return "Mixed"
	if score_percent >= 30.0:
		return "Soft negative"
		
	return "Negative"

static func _build_adjective_suggestions(score_percent: float, answered_ratio: float, score_values: Array[float]) -> Array[String]:
	var suggestions: Array[String] = []
	if score_percent < 0.0:
		suggestions.append_array(["unfinished", "open", "exploratory"])
	elif score_percent >= 85.0:
		suggestions.append_array(["optimistic", "confident", "satisfied"])
	elif score_percent >= 70.0:
		suggestions.append_array(["positive", "hopeful", "encouraged"])
	elif score_percent >= 55.0:
		suggestions.append_array(["mixed", "curious", "measured"])
	elif score_percent >= 40.0:
		suggestions.append_array(["uncertain", "skeptical", "conflicted"])
	else:
		suggestions.append_array(["frustrated", "concerned", "disappointed"])

	var spread: float = _score_spread(score_values)
	if spread >= 28.0:
		suggestions.append("torn")
	elif spread >= 16.0:
		suggestions.append("uneven")

	if answered_ratio >= 0.85:
		suggestions.append("clear-eyed")
	elif answered_ratio >= 0.5:
		suggestions.append("thoughtful")
	else:
		suggestions.append("tentative")

	if score_percent >= 60.0 and spread >= 0.0 and spread < 12.0:
		suggestions.append("steady")
	elif score_percent >= 0.0 and score_percent < 40.0 and spread >= 0.0 and spread < 12.0:
		suggestions.append("drained")

	var unique_suggestions: Array[String] = []
	for suggestion in suggestions:
		var normalized: String = suggestion.strip_edges().to_lower()
		if normalized.is_empty() or unique_suggestions.has(normalized):
			continue
		unique_suggestions.append(normalized)
		if unique_suggestions.size() >= 6:
			break
	return unique_suggestions

static func _score_spread(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var min_score := INF
	var max_score := -INF
	for value in values:
		min_score = minf(min_score, value)
		max_score = maxf(max_score, value)
	if min_score == INF or max_score == -INF:
		return -1.0
	return max_score - min_score

static func _answer_to_text(question: SurveyQuestion, value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "Yes" if bool(value) else "No"
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(str(item))
			return ", ".join(parts)
		TYPE_DICTIONARY:
			var dict: Dictionary = value as Dictionary
			var pairs: Array[String] = []
			if question.type == SurveyQuestion.TYPE_MATRIX:
				for row_name in question.rows:
					var row_value: String = str(dict.get(row_name, "")).strip_edges()
					if row_value.is_empty():
						continue
					pairs.append("%s: %s" % [row_name, row_value])
				return " | ".join(pairs)
			for key in dict.keys():
				pairs.append("%s: %s" % [str(key), str(dict.get(key))])
			pairs.sort()
			return " | ".join(pairs)
	return str(value)

static func _truncate_text(value: String, max_length: int) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return "%s..." % trimmed.substr(0, max(max_length - 3, 0)).rstrip(" ")
