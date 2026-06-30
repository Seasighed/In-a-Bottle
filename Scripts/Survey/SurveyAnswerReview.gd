class_name SurveyAnswerReview
extends RefCounted

const SURVEY_SHARE_PROFILE_STORE = preload("res://Scripts/Survey/SurveyShareProfileStore.gd")

const REVIEW_SETTINGS_PATH := "user://answer_review_sources.json"
const WRAP_THEME_LIGHT := "light"
const WRAP_THEME_DARK := "dark"
const WRAP_PAGE_WIDTH := 1080
const WRAP_PAGE_HEIGHT := 1920
const WRAP_PAGE_DATA_VERSION := 4
const WRAP_PAGE_CONTENT_BUDGET := 27.5
const WRAP_MAX_STORY_TEXT_LINES := 18
const WRAP_TEXT_ANSWERS_PER_CHUNK := 5
const WRAP_MATRIX_ROWS_PER_CHUNK := 4
const WRAP_RANKED_OPTIONS_PER_CHUNK := 4
const WRAP_GRADIENT_SOFT_WHITE := "soft_white"
const WRAP_GRADIENT_SUNRISE := "sunrise"
const WRAP_GRADIENT_MINT := "mint"
const WRAP_GRADIENT_SKY := "sky"
const WRAP_GRADIENT_ROSE := "rose"
const WRAP_GRADIENT_VIOLET := "violet"
const WRAP_GRADIENT_NIGHT := "night"
const WRAP_GRADIENT_AURORA := "aurora"
const WRAP_DEFAULT_GRADIENT_PRESET := WRAP_GRADIENT_SOFT_WHITE
const WRAP_TEXT_SUMMARY_AUTO := "auto"
const WRAP_TEXT_DISTINCT_ANSWER_LIMIT := 3
const WRAP_WORD_TALLY_LIMIT := 12
const WRAP_DEFAULT_RESPONDENT_COLORS := [
	"3b82f6", "ef4444", "22c55e", "f59e0b", "a855f7", "06b6d4",
	"f97316", "14b8a6", "ec4899", "84cc16", "6366f1", "eab308"
]
const WRAP_WORD_TALLY_STOPWORDS := [
	"the", "and", "for", "you", "your", "are", "was", "were", "that", "this", "with", "from",
	"have", "has", "had", "but", "not", "all", "any", "can", "could", "would", "should",
	"there", "their", "they", "them", "then", "than", "because", "about", "into", "onto",
	"just", "really", "very", "more", "most", "less", "least", "our", "out", "get", "got",
	"did", "does", "done", "its", "it's", "too", "also", "when", "what", "where", "who",
	"why", "how", "yes", "no", "response", "answer", "demo"
]

static func scan_folder(survey: SurveyDefinition, folder_path: String, recursive: bool = true) -> Dictionary:
	var normalized_folder := _normalized_filesystem_path(folder_path)
	var report: Dictionary = {
		"survey_id": survey.id if survey != null else "",
		"schema_hash": survey.schema_hash if survey != null else "",
		"folder_path": normalized_folder,
		"recursive": recursive,
		"generated_at": Time.get_datetime_string_from_system(true),
		"records": [],
		"rejected_files": [],
		"warnings": [],
		"aggregate": {},
		"accepted_count": 0,
		"question_count": survey.total_questions() if survey != null else 0
	}
	if survey == null:
		report["rejected_files"].append(_rejected_file("", "No survey is loaded."))
		return report
	if normalized_folder.is_empty() or not DirAccess.dir_exists_absolute(normalized_folder):
		report["rejected_files"].append(_rejected_file(normalized_folder, "Answer folder was not found."))
		report["aggregate"] = build_aggregate(survey, [])
		return report

	var files := _collect_json_files(normalized_folder, recursive)
	var seen_signatures: Dictionary = {}
	for file_path in files:
		var parse_result := parse_answer_file(survey, file_path)
		if bool(parse_result.get("ok", false)):
			var record: Dictionary = parse_result.get("record", {}) as Dictionary
			var signature := str(record.get("record_signature", "")).strip_edges()
			if not signature.is_empty() and seen_signatures.has(signature):
				report["rejected_files"].append(_rejected_file(file_path, "Duplicate answer payload already counted from %s." % str(seen_signatures.get(signature, "")).get_file()))
				continue
			if not signature.is_empty():
				seen_signatures[signature] = file_path
			report["records"].append(record)
			for warning in parse_result.get("warnings", []):
				report["warnings"].append(str(warning))
		else:
			report["rejected_files"].append(_rejected_file(file_path, str(parse_result.get("message", "No compatible answers found."))))

	report["accepted_count"] = (report.get("records", []) as Array).size()
	report["aggregate"] = build_aggregate(survey, report.get("records", []) as Array)
	return report

static func parse_answer_file(survey: SurveyDefinition, file_path: String) -> Dictionary:
	if survey == null:
		return _parse_failure("No survey is loaded.")
	if file_path.strip_edges().is_empty() or not FileAccess.file_exists(file_path):
		return _parse_failure("Answer file was not found.")
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return _parse_failure("Answer file could not be opened.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return _parse_failure("Invalid JSON: %s" % parser.get_error_message())
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return _parse_failure("JSON root must be an object.")
	var root: Dictionary = parsed as Dictionary
	var extracted := _extract_payload_record(root)
	if not bool(extracted.get("ok", false)):
		return extracted

	var payload_survey_id := str(extracted.get("survey_id", "")).strip_edges()
	if not payload_survey_id.is_empty() and payload_survey_id != survey.id:
		return _parse_failure("Survey id '%s' does not match '%s'." % [payload_survey_id, survey.id])
	var payload_schema_hash := str(extracted.get("schema_hash", "")).strip_edges()
	if not payload_schema_hash.is_empty() and not survey.schema_hash.is_empty() and payload_schema_hash != survey.schema_hash:
		return _parse_failure("Survey schema hash does not match the active survey.")

	var warnings: Array[String] = []
	if payload_survey_id.is_empty():
		warnings.append("%s did not include a survey id." % file_path.get_file())
	if payload_schema_hash.is_empty() and not survey.schema_hash.is_empty():
		warnings.append("%s did not include a schema hash." % file_path.get_file())

	var raw_answers: Dictionary = extracted.get("answers", {}) as Dictionary
	var sanitized_answers := _sanitize_answers_for_survey(survey, raw_answers)
	if sanitized_answers.is_empty():
		return _parse_failure("No recognized non-empty answers matched this survey.")

	var record := {
		"source_path": file_path,
		"source_name": file_path.get_file(),
		"payload_format": str(extracted.get("format", "unknown")),
		"survey_id": payload_survey_id if not payload_survey_id.is_empty() else survey.id,
		"schema_hash": payload_schema_hash,
		"payload_hash": str(extracted.get("payload_hash", "")).strip_edges(),
		"saved_at": str(extracted.get("saved_at", "")),
		"answers": sanitized_answers
	}
	record["record_signature"] = _record_signature(record)
	return {
		"ok": true,
		"record": record,
		"warnings": warnings
	}

static func build_aggregate(survey: SurveyDefinition, records: Array) -> Dictionary:
	var respondent_count := records.size()
	var respondents := _respondents_for_records(records)
	var sections: Array[Dictionary] = []
	var questions_by_id: Dictionary = {}
	var answered_response_total := 0
	if survey == null:
		return {
			"respondent_count": respondent_count,
			"respondents": respondents,
			"answered_response_total": 0,
			"sections": sections,
			"questions_by_id": questions_by_id
		}
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var section_payload: Dictionary = {
			"section_id": section.id,
			"section_number": section_index + 1,
			"title": section.title.strip_edges(),
			"questions": []
		}
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var question_payload := _base_question_aggregate(section, section_index, question, question_index, respondent_count)
			for record_index in range(records.size()):
				var record_value: Variant = records[record_index]
				if not (record_value is Dictionary):
					continue
				var record: Dictionary = record_value as Dictionary
				var answers: Dictionary = record.get("answers", {}) as Dictionary
				if not answers.has(question.id):
					continue
				var answer_value: Variant = answers.get(question.id, null)
				if question.is_answer_empty(answer_value):
					continue
				question_payload["answer_count"] = int(question_payload.get("answer_count", 0)) + 1
				answered_response_total += 1
				var respondent: Dictionary = respondents[record_index] if record_index < respondents.size() else _respondent_for_record(record, record_index)
				_add_answer_to_question_aggregate(question_payload, question, answer_value, respondent)
			_finalize_question_aggregate(question_payload, question, respondent_count)
			(section_payload["questions"] as Array).append(question_payload)
			questions_by_id[question.id] = question_payload
		sections.append(section_payload)
	return {
		"survey_id": survey.id,
		"schema_hash": survey.schema_hash,
		"survey_title": survey.title,
		"respondent_count": respondent_count,
		"respondents": respondents,
		"answered_response_total": answered_response_total,
		"total_question_count": survey.total_questions(),
		"sections": sections,
		"questions_by_id": questions_by_id
	}

static func build_wrapped_summary_data(survey: SurveyDefinition, aggregate: Dictionary, scrub_identifying_info: bool = true, share_profile: Dictionary = {}, theme_id: String = WRAP_THEME_LIGHT, wrap_options: Dictionary = {}) -> Dictionary:
	if survey == null:
		return {}
	var question_map := _question_map(survey)
	var normalized_options := _normalized_wrap_options(wrap_options)
	var respondents := _respondents_for_wrap(aggregate.get("respondents", []) as Array, normalized_options)
	var respondent_colors := _respondent_color_map(respondents)
	var sections: Array[Dictionary] = []
	for section_value in aggregate.get("sections", []) as Array:
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = (section_value as Dictionary).duplicate(true)
		var questions: Array[Dictionary] = []
		for question_value in section.get("questions", []) as Array:
			if not (question_value is Dictionary):
				continue
			var question_payload: Dictionary = (question_value as Dictionary).duplicate(true)
			var question_id := str(question_payload.get("question_id", "")).strip_edges()
			var question: SurveyQuestion = question_map.get(question_id, null)
			var scrubbed := scrub_identifying_info and question != null and question.asks_identifying_info
			question_payload["scrubbed"] = scrubbed
			question_payload["respondent_colors"] = respondent_colors.duplicate(true)
			_apply_respondent_colors_to_question(question_payload, respondent_colors)
			if question != null:
				_decorate_wrapped_question_payload(question_payload, question, scrubbed, normalized_options)
			question_payload["wrapped_renderer"] = _wrapped_renderer_for_question_payload(question_payload, scrubbed)
			if scrubbed:
				question_payload["text_answers"] = []
				question_payload["text_samples"] = []
				question_payload["individual_answers"] = []
				question_payload["distinct_answer_tallies"] = []
				question_payload["word_tallies"] = []
				question_payload["summary_text"] = "Identifying answers hidden for sharing."
			questions.append(question_payload)
		section["questions"] = questions
		sections.append(section)
	return {
		"survey_id": survey.id,
		"schema_hash": survey.schema_hash,
		"survey_title": survey.title,
		"survey_subtitle": survey.subtitle,
		"generated_at": Time.get_datetime_string_from_system(true),
		"scrub_identifying_info": scrub_identifying_info,
		"respondent_count": int(aggregate.get("respondent_count", 0)),
		"respondents": respondents,
		"respondent_colors": respondent_colors,
		"answered_response_total": int(aggregate.get("answered_response_total", 0)),
		"total_question_count": survey.total_questions(),
		"theme_id": _normalized_wrap_theme(theme_id),
		"share_profile": _share_profile_for_wrap(share_profile),
		"wrap_options": normalized_options,
		"sections": sections
	}

static func build_wrapped_pages_data(survey: SurveyDefinition, aggregate_or_answers: Dictionary, scrub_identifying_info: bool = true, share_profile: Dictionary = {}, theme_id: String = WRAP_THEME_LIGHT, wrap_options: Dictionary = {}) -> Dictionary:
	if survey == null:
		return {}
	var aggregate := _aggregate_from_wrapped_source(survey, aggregate_or_answers)
	var normalized_options := _normalized_wrap_options(wrap_options)
	var summary := build_wrapped_summary_data(survey, aggregate, scrub_identifying_info, share_profile, theme_id, normalized_options)
	var file_stem := suggested_wrapped_file_stem(survey.id)
	var root: Dictionary = summary.duplicate(true)
	root["format"] = "survey_answer_wrapped_pages"
	root["version"] = WRAP_PAGE_DATA_VERSION
	root["page_width"] = WRAP_PAGE_WIDTH
	root["page_height"] = WRAP_PAGE_HEIGHT
	root["theme_id"] = _normalized_wrap_theme(theme_id)
	root["share_profile"] = _share_profile_for_wrap(share_profile)
	root["wrap_options"] = normalized_options
	root["gradient_preset_id"] = str(normalized_options.get("gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET))
	root["file_stem"] = file_stem
	var pages := _paginate_wrapped_summary(root)
	pages.append(_wrapped_stats_page(root))
	root["page_count"] = pages.size()
	for index in range(pages.size()):
		var page: Dictionary = pages[index]
		page["page_number"] = index + 1
		page["page_count"] = pages.size()
		page["file_name"] = wrapped_page_filename(file_stem, index + 1, pages.size())
		_decorate_wrapped_page(root, page, index, pages.size())
		pages[index] = page
	root["pages"] = pages
	return root

static func load_review_settings(survey_id: String) -> Dictionary:
	var all_settings := _load_all_review_settings()
	var key := _settings_key(survey_id)
	if key.is_empty() or not all_settings.has(key):
		return _default_review_settings()
	var settings_value: Variant = all_settings.get(key, {})
	if not (settings_value is Dictionary):
		return _default_review_settings()
	var settings: Dictionary = _default_review_settings()
	for item_key in (settings_value as Dictionary).keys():
		settings[str(item_key)] = (settings_value as Dictionary).get(item_key)
	settings["recursive"] = bool(settings.get("recursive", true))
	settings["scrub_identifying_info"] = bool(settings.get("scrub_identifying_info", true))
	settings["wrapped_theme_id"] = _normalized_wrap_theme(str(settings.get("wrapped_theme_id", WRAP_THEME_LIGHT)))
	settings["wrapped_gradient_preset_id"] = _normalized_gradient_preset_id(str(settings.get("wrapped_gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET)))
	settings["text_summary_mode"] = str(settings.get("text_summary_mode", WRAP_TEXT_SUMMARY_AUTO)).strip_edges().to_lower()
	settings["respondent_color_overrides"] = _normalized_respondent_color_overrides(settings.get("respondent_color_overrides", {}))
	return settings

static func save_review_settings(survey_id: String, settings: Dictionary) -> bool:
	var key := _settings_key(survey_id)
	if key.is_empty():
		return false
	var all_settings := _load_all_review_settings()
	all_settings[key] = {
		"folder_path": str(settings.get("folder_path", "")).strip_edges(),
		"recursive": bool(settings.get("recursive", true)),
		"scrub_identifying_info": bool(settings.get("scrub_identifying_info", true)),
		"wrapped_theme_id": _normalized_wrap_theme(str(settings.get("wrapped_theme_id", WRAP_THEME_LIGHT))),
		"wrapped_gradient_preset_id": _normalized_gradient_preset_id(str(settings.get("wrapped_gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET))),
		"text_summary_mode": str(settings.get("text_summary_mode", WRAP_TEXT_SUMMARY_AUTO)).strip_edges().to_lower(),
		"respondent_color_overrides": _normalized_respondent_color_overrides(settings.get("respondent_color_overrides", {})),
		"last_scan_at": str(settings.get("last_scan_at", "")),
		"last_accepted_count": int(settings.get("last_accepted_count", 0)),
		"last_rejected_count": int(settings.get("last_rejected_count", 0))
	}
	var absolute_path := ProjectSettings.globalize_path(REVIEW_SETTINGS_PATH)
	var ensure_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if ensure_error != OK and not DirAccess.dir_exists_absolute(absolute_path.get_base_dir()):
		return false
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(all_settings, "\t"))
	file.close()
	return true

static func suggested_wrapped_filename(survey_id: String) -> String:
	return "%s.png" % suggested_wrapped_file_stem(survey_id)

static func suggested_wrapped_file_stem(survey_id: String) -> String:
	return "%s_wrapped_%s" % [_safe_segment(survey_id if not survey_id.is_empty() else "survey"), _safe_stamp(Time.get_datetime_string_from_system())]

static func suggested_wrapped_folder_name(survey_id: String) -> String:
	return suggested_wrapped_file_stem(survey_id)

static func wrapped_page_filename(file_stem: String, page_number: int, page_count: int) -> String:
	var stem := _safe_segment(file_stem)
	if stem.is_empty():
		stem = "survey_wrapped"
	if page_count <= 1:
		return "%s.png" % stem
	return "%s_%02d-of-%02d.png" % [stem, page_number, page_count]

static func _aggregate_from_wrapped_source(survey: SurveyDefinition, source: Dictionary) -> Dictionary:
	if source.has("aggregate") and source.get("aggregate") is Dictionary:
		return source.get("aggregate") as Dictionary
	if source.has("sections") and source.has("respondent_count"):
		return source
	if source.has("answers") and source.get("answers") is Dictionary:
		return build_aggregate(survey, [{"source_name": "current_answers", "answers": source.get("answers", {})}])
	return build_aggregate(survey, [{"source_name": "current_answers", "answers": source}])

static func _paginate_wrapped_summary(root: Dictionary) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	for section_value in root.get("sections", []) as Array:
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value as Dictionary
		var section_pages: Array[Dictionary] = []
		var current_questions: Array[Dictionary] = []
		var current_cost := 0.0
		for question_value in section.get("questions", []) as Array:
			if not (question_value is Dictionary):
				continue
			for chunk in _wrapped_question_chunks(question_value as Dictionary):
				var chunk_cost := _wrapped_question_chunk_cost(chunk)
				var projected_cost := current_cost + chunk_cost + (1.35 if not current_questions.is_empty() else 0.0)
				var projected_questions := current_questions.duplicate(true)
				projected_questions.append(chunk)
				if not current_questions.is_empty() and (projected_cost > WRAP_PAGE_CONTENT_BUDGET or not _wrapped_questions_fit_readability(projected_questions)):
					section_pages.append(_wrapped_page(root, section, current_questions))
					current_questions = []
					current_cost = 0.0
				current_questions.append(chunk)
				current_cost += chunk_cost + (1.35 if current_questions.size() > 1 else 0.0)
		if not current_questions.is_empty():
			section_pages.append(_wrapped_page(root, section, current_questions))
		for index in range(section_pages.size()):
			var page: Dictionary = section_pages[index]
			page["section_part_number"] = index + 1
			page["section_part_count"] = section_pages.size()
			section_pages[index] = page
			pages.append(page)
	return pages

static func _wrapped_page(root: Dictionary, section: Dictionary, questions: Array[Dictionary]) -> Dictionary:
	return {
		"page_kind": "answers",
		"survey_id": str(root.get("survey_id", "")),
		"schema_hash": str(root.get("schema_hash", "")),
		"survey_title": str(root.get("survey_title", "Survey")),
		"survey_subtitle": str(root.get("survey_subtitle", "")),
		"generated_at": str(root.get("generated_at", "")),
		"scrub_identifying_info": bool(root.get("scrub_identifying_info", true)),
		"respondent_count": int(root.get("respondent_count", 0)),
		"answered_response_total": int(root.get("answered_response_total", 0)),
		"total_question_count": int(root.get("total_question_count", 0)),
		"theme_id": str(root.get("theme_id", WRAP_THEME_LIGHT)),
		"gradient_preset_id": str(root.get("gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET)),
		"share_profile": (root.get("share_profile", {}) as Dictionary).duplicate(true) if root.get("share_profile", {}) is Dictionary else {},
		"wrap_options": (root.get("wrap_options", {}) as Dictionary).duplicate(true) if root.get("wrap_options", {}) is Dictionary else {},
		"section_id": str(section.get("section_id", "")),
		"section_number": int(section.get("section_number", 0)),
		"section_title": str(section.get("title", "Survey")),
		"section_part_number": 1,
		"section_part_count": 1,
		"questions": questions.duplicate(true),
		"page_width": WRAP_PAGE_WIDTH,
		"page_height": WRAP_PAGE_HEIGHT
	}

static func _wrapped_stats_page(root: Dictionary) -> Dictionary:
	var page := _wrapped_page(root, {}, [])
	page["page_kind"] = "stats"
	page["section_id"] = "__stats"
	page["section_number"] = 0
	page["section_title"] = "Final Stats"
	page["stats"] = [
		{"label": "answers", "value": str(int(root.get("respondent_count", 0)))},
		{"label": "responses", "value": str(int(root.get("answered_response_total", 0)))},
		{"label": "questions", "value": str(int(root.get("total_question_count", 0)))}
	]
	return page

static func _decorate_wrapped_page(root: Dictionary, page: Dictionary, page_index: int, page_count: int) -> void:
	page["title"] = str(root.get("survey_title", "Survey")).strip_edges()
	if str(page.get("title", "")).strip_edges().is_empty():
		page["title"] = "Survey"
	page["subtitle"] = _wrapped_page_subtitle(root, page, page_count)
	page["background_gradient"] = _wrapped_background_gradient(root, page, page_index)

static func _wrapped_page_subtitle(root: Dictionary, page: Dictionary, page_count: int) -> String:
	var parts: Array[String] = []
	if str(page.get("page_kind", "answers")) == "stats":
		parts.append("Final stats")
	else:
		var section_title := str(page.get("section_title", "")).strip_edges()
		if section_title.is_empty():
			section_title = str(root.get("survey_subtitle", "")).strip_edges()
		if not section_title.is_empty():
			parts.append(section_title)
		var part_count := int(page.get("section_part_count", 1))
		if part_count > 1:
			parts.append("Part %d of %d" % [int(page.get("section_part_number", 1)), part_count])
	var profile_text := _share_profile_subtitle(page.get("share_profile", {}) as Dictionary if page.get("share_profile", {}) is Dictionary else {})
	if not profile_text.is_empty():
		parts.append(profile_text)
	if page_count > 1 and str(page.get("page_kind", "answers")) == "stats":
		parts.append("%d screenshots" % page_count)
	return " | ".join(parts)

static func _wrapped_background_gradient(root: Dictionary, page: Dictionary, page_index: int) -> Dictionary:
	var section_number := int(page.get("section_number", 0))
	var part_number := int(page.get("section_part_number", 1))
	var theme_id := _normalized_wrap_theme(str(root.get("theme_id", WRAP_THEME_LIGHT)))
	var preset_id := _normalized_gradient_preset_id(str(root.get("gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET)))
	var preset := _wrap_gradient_preset_colors(preset_id, theme_id)
	var variation := float((page_index * 43 + section_number * 17 + part_number * 7) % 360) / 360.0
	var shift := (variation - 0.5) * 0.045
	return {
		"start": _shift_gradient_color(preset[0], shift).to_html(false),
		"middle": _shift_gradient_color(preset[1], shift * -0.7).to_html(false),
		"end": _shift_gradient_color(preset[2], shift * 1.3).to_html(false)
	}

static func _wrapped_renderer_for_question_payload(question_payload: Dictionary, scrubbed: bool = false) -> String:
	if scrubbed:
		return "text_samples"
	var explicit := str(question_payload.get("wrapped_renderer", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	match StringName(str(question_payload.get("question_type", ""))):
		SurveyQuestion.TYPE_MATRIX:
			return "matrix_summary"
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return "ranked_summary"
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			return "numeric_summary"
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_MULTI_CHOICE, SurveyQuestion.TYPE_DROPDOWN, SurveyQuestion.TYPE_BOOLEAN:
			return "option_tallies"
	return "text_samples"

static func _wrap_gradient_preset_colors(preset_id: String, theme_id: String) -> Array:
	var preset := _normalized_gradient_preset_id(preset_id)
	var dark := _normalized_wrap_theme(theme_id) == WRAP_THEME_DARK
	match preset:
		WRAP_GRADIENT_SUNRISE:
			return [Color("fff7ed"), Color("fed7aa"), Color("fb7185")] if not dark else [Color("22100a"), Color("5b2813"), Color("7f1d1d")]
		WRAP_GRADIENT_MINT:
			return [Color("f0fdfa"), Color("ccfbf1"), Color("86efac")] if not dark else [Color("06251f"), Color("134e4a"), Color("14532d")]
		WRAP_GRADIENT_SKY:
			return [Color("f0f9ff"), Color("dbeafe"), Color("93c5fd")] if not dark else [Color("061a2f"), Color("0f2f55"), Color("1e3a8a")]
		WRAP_GRADIENT_ROSE:
			return [Color("fff1f2"), Color("fce7f3"), Color("f9a8d4")] if not dark else [Color("2a0b12"), Color("581c32"), Color("831843")]
		WRAP_GRADIENT_VIOLET:
			return [Color("faf5ff"), Color("ede9fe"), Color("c4b5fd")] if not dark else [Color("160822"), Color("312e81"), Color("4c1d95")]
		WRAP_GRADIENT_NIGHT:
			return [Color("eef2ff"), Color("dbeafe"), Color("a5b4fc")] if not dark else [Color("030712"), Color("111827"), Color("1e1b4b")]
		WRAP_GRADIENT_AURORA:
			return [Color("ecfeff"), Color("d9f99d"), Color("f0abfc")] if not dark else [Color("042f2e"), Color("164e63"), Color("581c87")]
	return [Color("ffffff"), Color("f8fbff"), Color("e7f2ff")] if not dark else [Color("061018"), Color("0d1b2d"), Color("172235")]

static func _shift_gradient_color(color: Color, shift: float) -> Color:
	var hue := fmod(color.h + shift + 1.0, 1.0)
	return Color.from_hsv(hue, clampf(color.s, 0.0, 1.0), clampf(color.v, 0.0, 1.0), color.a)

static func _wrapped_questions_fit_readability(questions: Array) -> bool:
	if questions.size() <= 1:
		return true
	if questions.size() > 8:
		return false
	var estimated_lines := 0
	var complex_count := 0
	for question_value in questions:
		if not (question_value is Dictionary):
			continue
		var question: Dictionary = question_value as Dictionary
		estimated_lines += _estimated_wrap_lines(str(question.get("prompt", "")), 64, 3)
		estimated_lines += _wrapped_answer_line_count(question)
		match StringName(str(question.get("question_type", ""))):
			SurveyQuestion.TYPE_MATRIX, SurveyQuestion.TYPE_RANKED_CHOICE:
				complex_count += 1
	if complex_count >= 2 and questions.size() > 4:
		return false
	return estimated_lines <= WRAP_MAX_STORY_TEXT_LINES

static func _wrapped_question_chunk_cost(question: Dictionary) -> float:
	var prompt := str(question.get("prompt", "")).strip_edges()
	var prompt_lines := _estimated_wrap_lines(prompt, 64, 3)
	var answer_lines := _wrapped_answer_line_count(question)
	var cost := 1.8 + (float(prompt_lines) * 0.7) + (float(answer_lines) * 1.2)
	match StringName(str(question.get("question_type", ""))):
		SurveyQuestion.TYPE_MATRIX, SurveyQuestion.TYPE_RANKED_CHOICE:
			cost += 1.2
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			cost += 0.8
	return maxf(cost, 3.4)

static func _wrapped_answer_line_count(question: Dictionary) -> int:
	if bool(question.get("scrubbed", false)):
		return 1
	var renderer := str(question.get("wrapped_renderer", "")).strip_edges()
	match renderer:
		"text_word_tallies":
			return mini(maxi((question.get("word_tallies", []) as Array).size(), 1), 8)
		"text_individual_answers", "text_answer_tallies":
			return mini(maxi((question.get("distinct_answer_tallies", []) as Array).size(), 1), WRAP_TEXT_DISTINCT_ANSWER_LIMIT)
	match StringName(str(question.get("question_type", ""))):
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			var samples: Array = question.get("text_samples", [])
			if samples.is_empty():
				samples = question.get("text_answers", [])
			var total := 0
			for sample_value in samples:
				var text := ""
				if sample_value is Dictionary:
					text = str((sample_value as Dictionary).get("text", "")).strip_edges()
				elif typeof(sample_value) != TYPE_NIL:
					text = str(sample_value).strip_edges()
				total += _estimated_wrap_lines(text, 44, 2)
				if total >= 8:
					return 8
			return maxi(total, 1)
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			return 2 if not (question.get("numeric_stats", {}) as Dictionary).is_empty() else 1
		SurveyQuestion.TYPE_MATRIX:
			return maxi((question.get("matrix_rows", []) as Array).size(), 1)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return maxi((question.get("ranked_options", []) as Array).size(), 1)
	var option_lines := 0
	for entry in _sorted_count_entries_for_wrap(question.get("option_counts", {}) as Dictionary):
		if int(entry.get("count", 0)) > 0:
			option_lines += 1
		if option_lines >= 5:
			break
	return maxi(option_lines, 1)

static func _estimated_wrap_lines(text: String, characters_per_line: int, maximum: int) -> int:
	var clean := text.strip_edges()
	if clean.is_empty():
		return 1
	var lines := int(ceil(float(clean.length()) / float(maxi(characters_per_line, 1))))
	return clampi(lines, 1, maximum)

static func _sorted_count_entries_for_wrap(counts: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key in counts.keys():
		entries.append({"label": str(key), "count": int(counts.get(key, 0))})
	entries.sort_custom(Callable(SurveyAnswerReview, "_sort_count_entries_for_wrap"))
	return entries

static func _sort_count_entries_for_wrap(left: Dictionary, right: Dictionary) -> bool:
	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("label", "")) < str(right.get("label", ""))

static func _wrapped_question_chunks(question: Dictionary) -> Array[Dictionary]:
	if bool(question.get("scrubbed", false)):
		return [question.duplicate(true)]
	var renderer := str(question.get("wrapped_renderer", "")).strip_edges()
	if renderer in ["text_word_tallies", "text_individual_answers", "text_answer_tallies"]:
		return [question.duplicate(true)]
	var question_type := StringName(str(question.get("question_type", "")))
	match question_type:
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			var text_source: Array = question.get("text_answers", [])
			if text_source.is_empty():
				text_source = question.get("text_samples", [])
			return _chunk_question_array(question, "text_answers", "text_samples", text_source, WRAP_TEXT_ANSWERS_PER_CHUNK)
		SurveyQuestion.TYPE_MATRIX:
			return _chunk_question_array(question, "matrix_rows", "matrix_rows", question.get("matrix_rows", []), WRAP_MATRIX_ROWS_PER_CHUNK)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return _chunk_question_array(question, "ranked_options", "ranked_options", question.get("ranked_options", []), WRAP_RANKED_OPTIONS_PER_CHUNK)
	return [question.duplicate(true)]

static func _chunk_question_array(question: Dictionary, source_key: String, mirror_key: String, source: Array, chunk_size: int) -> Array[Dictionary]:
	if source.size() <= chunk_size:
		var single: Dictionary = question.duplicate(true)
		if source_key == "text_answers":
			single["text_samples"] = _first_text_samples(source, chunk_size)
		return [single]
	var chunks: Array[Dictionary] = []
	var index := 0
	while index < source.size():
		var chunk_values := source.slice(index, mini(index + chunk_size, source.size()))
		var chunk: Dictionary = question.duplicate(true)
		chunk[source_key] = chunk_values
		chunk[mirror_key] = chunk_values
		if source_key == "text_answers":
			chunk["text_samples"] = _first_text_samples(chunk_values, chunk_size)
		chunk["wrap_part_number"] = chunks.size() + 1
		chunk["wrap_part_count"] = int(ceil(float(source.size()) / float(chunk_size)))
		chunk["summary_text"] = "%d answer(s), page %d of %d." % [source.size(), int(chunk.get("wrap_part_number", 1)), int(chunk.get("wrap_part_count", 1))]
		chunks.append(chunk)
		index += chunk_size
	return chunks

static func _share_profile_for_wrap(profile: Dictionary) -> Dictionary:
	return SURVEY_SHARE_PROFILE_STORE.wrap_payload(profile)

static func _share_profile_subtitle(profile: Dictionary) -> String:
	var parts: Array[String] = []
	for field_value in profile.get("fields", []) as Array:
		if not (field_value is Dictionary):
			continue
		var field: Dictionary = field_value as Dictionary
		var label := str(field.get("label", "")).strip_edges()
		var value := str(field.get("value", "")).strip_edges()
		if label.is_empty() or value.is_empty():
			continue
		parts.append("%s: %s" % [label, value])
	return " | ".join(parts)

static func _normalized_wrap_options(options: Dictionary) -> Dictionary:
	var normalized := {
		"gradient_preset_id": _normalized_gradient_preset_id(str(options.get("gradient_preset_id", WRAP_DEFAULT_GRADIENT_PRESET))),
		"text_summary_mode": str(options.get("text_summary_mode", WRAP_TEXT_SUMMARY_AUTO)).strip_edges().to_lower(),
		"respondent_color_overrides": _normalized_respondent_color_overrides(options.get("respondent_color_overrides", {}))
	}
	if str(normalized.get("text_summary_mode", "")).is_empty():
		normalized["text_summary_mode"] = WRAP_TEXT_SUMMARY_AUTO
	return normalized

static func _normalized_gradient_preset_id(preset_id: String) -> String:
	var normalized := preset_id.strip_edges().to_lower()
	match normalized:
		WRAP_GRADIENT_SUNRISE, WRAP_GRADIENT_MINT, WRAP_GRADIENT_SKY, WRAP_GRADIENT_ROSE, WRAP_GRADIENT_VIOLET, WRAP_GRADIENT_NIGHT, WRAP_GRADIENT_AURORA, WRAP_GRADIENT_SOFT_WHITE:
			return normalized
	return WRAP_DEFAULT_GRADIENT_PRESET

static func _normalized_respondent_color_overrides(value: Variant) -> Dictionary:
	var overrides: Dictionary = {}
	if not (value is Dictionary):
		return overrides
	for key in (value as Dictionary).keys():
		var respondent_id := str(key).strip_edges()
		var color := _normalized_hex_color(str((value as Dictionary).get(key, "")))
		if respondent_id.is_empty() or color.is_empty():
			continue
		overrides[respondent_id] = color
	return overrides

static func _normalized_hex_color(value: String) -> String:
	var color := value.strip_edges().trim_prefix("#").to_lower()
	if color.length() != 6:
		return ""
	for index in range(color.length()):
		var character := color.substr(index, 1)
		if not "0123456789abcdef".contains(character):
			return ""
	return color

static func _respondents_for_wrap(respondents: Array, wrap_options: Dictionary) -> Array[Dictionary]:
	var overrides: Dictionary = wrap_options.get("respondent_color_overrides", {}) as Dictionary if wrap_options.get("respondent_color_overrides", {}) is Dictionary else {}
	var normalized: Array[Dictionary] = []
	for index in range(respondents.size()):
		if not (respondents[index] is Dictionary):
			continue
		var respondent: Dictionary = (respondents[index] as Dictionary).duplicate(true)
		if not respondent.has("respondent_number"):
			respondent["respondent_number"] = index + 1
		if str(respondent.get("respondent_id", "")).strip_edges().is_empty():
			respondent["respondent_id"] = "r_%s" % _sha256_text(JSON.stringify(respondent, "", true)).substr(0, 12)
		if str(respondent.get("display_label", "")).strip_edges().is_empty():
			respondent["display_label"] = "User %d" % int(respondent.get("respondent_number", index + 1))
		var default_color := _normalized_hex_color(str(respondent.get("default_color", "")))
		if default_color.is_empty():
			default_color = _default_respondent_color(index)
		var respondent_id := str(respondent.get("respondent_id", ""))
		var override_color := _normalized_hex_color(str(overrides.get(respondent_id, "")))
		respondent["default_color"] = default_color
		respondent["export_color"] = override_color if not override_color.is_empty() else default_color
		normalized.append(respondent)
	return normalized

static func _respondent_color_map(respondents: Array) -> Dictionary:
	var colors: Dictionary = {}
	for respondent_value in respondents:
		if not (respondent_value is Dictionary):
			continue
		var respondent: Dictionary = respondent_value as Dictionary
		var respondent_id := str(respondent.get("respondent_id", "")).strip_edges()
		var color := _normalized_hex_color(str(respondent.get("export_color", respondent.get("default_color", ""))))
		if respondent_id.is_empty() or color.is_empty():
			continue
		colors[respondent_id] = color
	return colors

static func _apply_respondent_colors_to_question(question_payload: Dictionary, respondent_colors: Dictionary) -> void:
	_apply_respondent_colors_to_answer_array(question_payload.get("individual_answers", []) as Array, respondent_colors)
	_apply_respondent_colors_to_answer_array(question_payload.get("text_answers", []) as Array, respondent_colors)
	_apply_respondent_colors_to_answer_array(question_payload.get("text_samples", []) as Array, respondent_colors)
	for tally_value in question_payload.get("distinct_answer_tallies", []) as Array:
		if not (tally_value is Dictionary):
			continue
		var tally: Dictionary = tally_value as Dictionary
		_apply_respondent_colors_to_answer_array(tally.get("respondents", []) as Array, respondent_colors)
		var colors: Array[String] = []
		for respondent_value in tally.get("respondents", []) as Array:
			if respondent_value is Dictionary:
				var color := str((respondent_value as Dictionary).get("respondent_color", "")).strip_edges()
				if not color.is_empty() and not colors.has(color):
					colors.append(color)
		tally["respondent_colors"] = colors

static func _apply_respondent_colors_to_answer_array(values: Array, respondent_colors: Dictionary) -> void:
	for answer_value in values:
		if not (answer_value is Dictionary):
			continue
		var answer: Dictionary = answer_value as Dictionary
		var respondent_id := str(answer.get("respondent_id", "")).strip_edges()
		if not respondent_id.is_empty() and respondent_colors.has(respondent_id):
			answer["respondent_color"] = str(respondent_colors.get(respondent_id, ""))

static func _decorate_wrapped_question_payload(question_payload: Dictionary, question: SurveyQuestion, scrubbed: bool, wrap_options: Dictionary) -> void:
	if scrubbed:
		return
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT:
			var distinct: Array = question_payload.get("distinct_answer_tallies", [])
			var words: Array = question_payload.get("word_tallies", [])
			if distinct.size() > WRAP_TEXT_DISTINCT_ANSWER_LIMIT and not words.is_empty():
				question_payload["wrapped_renderer"] = "text_word_tallies"
				question_payload["text_samples"] = []
			else:
				question_payload["wrapped_renderer"] = "text_individual_answers"
				question_payload["text_samples"] = _first_text_samples(question_payload.get("text_answers", []) as Array, WRAP_TEXT_DISTINCT_ANSWER_LIMIT)
		SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			var email_distinct: Array = question_payload.get("distinct_answer_tallies", [])
			question_payload["wrapped_renderer"] = "text_answer_tallies" if email_distinct.size() > WRAP_TEXT_DISTINCT_ANSWER_LIMIT else "text_individual_answers"

static func _normalized_wrap_theme(theme_id: String) -> String:
	var normalized := theme_id.strip_edges().to_lower()
	return WRAP_THEME_DARK if normalized == WRAP_THEME_DARK else WRAP_THEME_LIGHT

static func _extract_payload_record(root: Dictionary) -> Dictionary:
	var format_text := str(root.get("format", "")).strip_edges()
	if format_text == "survey_submission_bundle" or root.has("responses"):
		return _extract_submission_payload(root)
	var answers_value: Variant = root.get("answers", null)
	if answers_value is Array:
		return _extract_legacy_export_payload(root)
	if answers_value is Dictionary:
		return _extract_progress_payload(root)
	return _parse_failure("No supported answer payload was found.")

static func _extract_progress_payload(root: Dictionary) -> Dictionary:
	var survey_payload: Dictionary = root.get("survey", {}) as Dictionary if root.get("survey", {}) is Dictionary else {}
	return {
		"ok": true,
		"format": str(root.get("format", "survey_session_bundle")),
		"survey_id": str(survey_payload.get("id", root.get("survey_id", ""))).strip_edges(),
		"schema_hash": str(survey_payload.get("schema_hash", root.get("schema_hash", ""))).strip_edges(),
		"payload_hash": str(root.get("client_payload_hash", root.get("payload_hash", ""))).strip_edges(),
		"saved_at": str(root.get("saved_at", root.get("exported_at", ""))),
		"answers": (root.get("answers", {}) as Dictionary).duplicate(true)
	}

static func _extract_legacy_export_payload(root: Dictionary) -> Dictionary:
	var flattened_answers: Dictionary = {}
	for section_value in root.get("answers", []) as Array:
		if not (section_value is Dictionary):
			continue
		for response_value in (section_value as Dictionary).get("responses", []) as Array:
			if not (response_value is Dictionary):
				continue
			var response: Dictionary = response_value as Dictionary
			var question_id := str(response.get("question_id", "")).strip_edges()
			if question_id.is_empty():
				continue
			flattened_answers[question_id] = response.get("answer", null)
	return {
		"ok": true,
		"format": "answer_export",
		"survey_id": str(root.get("survey_id", "")).strip_edges(),
		"schema_hash": str(root.get("schema_hash", "")).strip_edges(),
		"payload_hash": str(root.get("client_payload_hash", root.get("payload_hash", ""))).strip_edges(),
		"saved_at": str(root.get("exported_at", root.get("saved_at", ""))),
		"answers": flattened_answers
	}

static func _extract_submission_payload(root: Dictionary) -> Dictionary:
	var survey_payload: Dictionary = root.get("survey", {}) as Dictionary if root.get("survey", {}) is Dictionary else {}
	var flattened_answers: Dictionary = {}
	for section_value in root.get("responses", []) as Array:
		if not (section_value is Dictionary):
			continue
		for response_value in (section_value as Dictionary).get("responses", []) as Array:
			if not (response_value is Dictionary):
				continue
			var response: Dictionary = response_value as Dictionary
			var question_id := str(response.get("question_id", "")).strip_edges()
			if question_id.is_empty():
				continue
			flattened_answers[question_id] = response.get("answer", null)
	return {
		"ok": true,
		"format": str(root.get("format", "survey_submission_bundle")),
		"survey_id": str(survey_payload.get("id", root.get("survey_id", ""))).strip_edges(),
		"schema_hash": str(survey_payload.get("schema_hash", root.get("schema_hash", ""))).strip_edges(),
		"payload_hash": str(root.get("client_payload_hash", root.get("payload_hash", ""))).strip_edges(),
		"saved_at": str(root.get("submitted_at", root.get("saved_at", ""))),
		"answers": flattened_answers
	}

static func _sanitize_answers_for_survey(survey: SurveyDefinition, raw_answers: Dictionary) -> Dictionary:
	var resolved: Dictionary = {}
	var question_map := _question_map(survey)
	for question_id_variant in raw_answers.keys():
		var question_id := str(question_id_variant).strip_edges()
		if question_id.is_empty() or not question_map.has(question_id):
			continue
		var question: SurveyQuestion = question_map[question_id]
		var value: Variant = _normalize_answer_for_question(question, raw_answers.get(question_id_variant))
		if question.is_answer_empty(value):
			continue
		resolved[question_id] = value
	return resolved

static func _normalize_answer_for_question(question: SurveyQuestion, raw_value: Variant) -> Variant:
	match question.type:
		SurveyQuestion.TYPE_BOOLEAN:
			return _normalize_boolean(raw_value)
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			return _normalize_number(raw_value)
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			var selection := str(raw_value).strip_edges()
			return selection if question.options.is_empty() or question.options.find(selection) != -1 else null
		SurveyQuestion.TYPE_MULTI_CHOICE, SurveyQuestion.TYPE_RANKED_CHOICE:
			return _normalize_option_array(question, raw_value)
		SurveyQuestion.TYPE_MATRIX:
			return _normalize_matrix(question, raw_value)
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			return str(raw_value).strip_edges()
	return raw_value

static func _normalize_boolean(raw_value: Variant) -> Variant:
	if typeof(raw_value) == TYPE_BOOL:
		return raw_value
	var text := str(raw_value).strip_edges().to_lower()
	if text in ["true", "yes", "1"]:
		return true
	if text in ["false", "no", "0"]:
		return false
	return null

static func _normalize_number(raw_value: Variant) -> Variant:
	match typeof(raw_value):
		TYPE_INT, TYPE_FLOAT:
			return raw_value
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(raw_value).strip_edges()
			if text.is_valid_int():
				return int(text)
			if text.is_valid_float():
				return float(text)
	return null

static func _normalize_option_array(question: SurveyQuestion, raw_value: Variant) -> Array[String]:
	var source: Array = []
	if raw_value is Array:
		source = raw_value as Array
	elif typeof(raw_value) != TYPE_NIL:
		source = [raw_value]
	var resolved: Array[String] = []
	for item in source:
		var option := str(item).strip_edges()
		if option.is_empty() or resolved.has(option):
			continue
		if not question.options.is_empty() and question.options.find(option) == -1:
			continue
		resolved.append(option)
	return resolved

static func _normalize_matrix(question: SurveyQuestion, raw_value: Variant) -> Dictionary:
	var resolved: Dictionary = {}
	if not (raw_value is Dictionary):
		return resolved
	var source: Dictionary = raw_value as Dictionary
	for row_name in question.rows:
		var selection := str(source.get(row_name, "")).strip_edges()
		if selection.is_empty():
			continue
		if not question.options.is_empty() and question.options.find(selection) == -1:
			continue
		resolved[row_name] = selection
	return resolved

static func _respondents_for_records(records: Array) -> Array[Dictionary]:
	var respondents: Array[Dictionary] = []
	for index in range(records.size()):
		var record: Dictionary = records[index] as Dictionary if records[index] is Dictionary else {}
		respondents.append(_respondent_for_record(record, index))
	return respondents

static func _respondent_for_record(record: Dictionary, index: int) -> Dictionary:
	var seed := str(record.get("record_signature", "")).strip_edges()
	if seed.is_empty():
		seed = str(record.get("payload_hash", "")).strip_edges()
	if seed.is_empty():
		seed = str(record.get("source_path", "")).strip_edges()
	if seed.is_empty():
		seed = JSON.stringify(record.get("answers", {}), "", true)
	if seed.is_empty():
		seed = "respondent_%d" % (index + 1)
	var hash := _sha256_text(seed)
	if hash.is_empty():
		hash = _safe_segment(seed)
	var respondent_id := "r_%s" % hash.substr(0, 12)
	return {
		"respondent_id": respondent_id,
		"respondent_number": index + 1,
		"display_label": "User %d" % (index + 1),
		"source_name": str(record.get("source_name", "")).strip_edges(),
		"default_color": _default_respondent_color(index)
	}

static func _default_respondent_color(index: int) -> String:
	if WRAP_DEFAULT_RESPONDENT_COLORS.is_empty():
		return "3b82f6"
	var resolved_index := posmod(index, WRAP_DEFAULT_RESPONDENT_COLORS.size())
	return str(WRAP_DEFAULT_RESPONDENT_COLORS[resolved_index])

static func _base_question_aggregate(section: SurveySection, section_index: int, question: SurveyQuestion, question_index: int, respondent_count: int) -> Dictionary:
	return {
		"section_id": section.id,
		"section_number": section_index + 1,
		"question_id": question.id,
		"question_number": question_index + 1,
		"display_number": "%d.%d" % [section_index + 1, question_index + 1],
		"prompt": question.prompt.strip_edges(),
		"question_type": str(question.type),
		"type_label": question.display_type_label(),
		"asks_identifying_info": question.asks_identifying_info,
		"required": question.required,
		"answer_count": 0,
		"missing_count": respondent_count,
		"response_rate_percent": 0.0,
		"option_counts": _initialized_option_counts(question),
		"individual_answers": [],
		"text_answers": [],
		"text_samples": [],
		"distinct_answer_tallies": [],
		"word_tallies": [],
		"respondent_colors": {},
		"numeric_values": [],
		"numeric_stats": {},
		"matrix_rows": [],
		"ranked_options": [],
		"summary_text": ""
	}

static func _add_individual_answer(payload: Dictionary, question: SurveyQuestion, value: Variant, respondent: Dictionary) -> void:
	var display_value := _answer_to_text(question, value).strip_edges()
	if display_value.is_empty():
		return
	var respondent_id := str(respondent.get("respondent_id", "")).strip_edges()
	var respondent_color := str(respondent.get("default_color", "")).strip_edges()
	var answer := {
		"respondent_id": respondent_id,
		"respondent_number": int(respondent.get("respondent_number", 0)),
		"respondent_label": str(respondent.get("display_label", "")),
		"respondent_color": respondent_color,
		"source_name": str(respondent.get("source_name", "")),
		"display_value": display_value
	}
	(payload["individual_answers"] as Array).append(answer)
	if not respondent_id.is_empty():
		var colors: Dictionary = payload.get("respondent_colors", {})
		colors[respondent_id] = respondent_color
		payload["respondent_colors"] = colors

static func _add_answer_to_question_aggregate(payload: Dictionary, question: SurveyQuestion, value: Variant, respondent: Dictionary) -> void:
	_add_individual_answer(payload, question, value, respondent)
	match question.type:
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			_increment_dictionary_count(payload["option_counts"], str(value))
		SurveyQuestion.TYPE_BOOLEAN:
			_increment_dictionary_count(payload["option_counts"], "Yes" if bool(value) else "No")
		SurveyQuestion.TYPE_MULTI_CHOICE:
			for item in value as Array:
				_increment_dictionary_count(payload["option_counts"], str(item))
		SurveyQuestion.TYPE_MATRIX:
			_add_matrix_answer(payload, question, value as Dictionary)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			_add_ranked_answer(payload, question, value as Array)
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			(payload["numeric_values"] as Array).append(float(value))
		_:
			var text := _answer_to_text(question, value).strip_edges()
			if not text.is_empty():
				(payload["text_answers"] as Array).append({
					"text": text,
					"source_name": str(respondent.get("source_name", "")),
					"respondent_id": str(respondent.get("respondent_id", "")),
					"respondent_number": int(respondent.get("respondent_number", 0)),
					"respondent_label": str(respondent.get("display_label", "")),
					"respondent_color": str(respondent.get("default_color", ""))
				})

static func _finalize_question_aggregate(payload: Dictionary, question: SurveyQuestion, respondent_count: int) -> void:
	var answer_count := int(payload.get("answer_count", 0))
	payload["missing_count"] = maxi(respondent_count - answer_count, 0)
	payload["response_rate_percent"] = snappedf((float(answer_count) / float(respondent_count)) * 100.0, 0.1) if respondent_count > 0 else 0.0
	match question.type:
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			payload["numeric_stats"] = _numeric_stats(payload.get("numeric_values", []) as Array)
			payload["option_counts"] = _numeric_value_counts(payload.get("numeric_values", []) as Array)
		SurveyQuestion.TYPE_MATRIX:
			payload["matrix_rows"] = _finalized_matrix_rows(payload, question)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			payload["ranked_options"] = _finalized_ranked_options(payload, question)
	payload["distinct_answer_tallies"] = _distinct_answer_tallies(payload.get("individual_answers", []) as Array)
	if question.type in [SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT]:
		payload["word_tallies"] = _word_tallies(payload.get("text_answers", []) as Array, WRAP_WORD_TALLY_LIMIT)
	payload["text_samples"] = _first_text_samples(payload.get("text_answers", []) as Array, 8)
	payload["summary_text"] = _summary_for_question_payload(payload, question)

static func _distinct_answer_tallies(individual_answers: Array) -> Array[Dictionary]:
	var by_answer: Dictionary = {}
	for answer_value in individual_answers:
		if not (answer_value is Dictionary):
			continue
		var answer: Dictionary = answer_value as Dictionary
		var text := str(answer.get("display_value", "")).strip_edges()
		if text.is_empty():
			continue
		var key := text.to_lower()
		var entry: Dictionary = by_answer.get(key, {
			"text": text,
			"count": 0,
			"respondents": [],
			"respondent_colors": []
		})
		entry["count"] = int(entry.get("count", 0)) + 1
		var respondent := {
			"respondent_id": str(answer.get("respondent_id", "")),
			"respondent_number": int(answer.get("respondent_number", 0)),
			"respondent_label": str(answer.get("respondent_label", "")),
			"respondent_color": str(answer.get("respondent_color", ""))
		}
		(entry["respondents"] as Array).append(respondent)
		var color := str(answer.get("respondent_color", "")).strip_edges()
		if not color.is_empty() and not (entry["respondent_colors"] as Array).has(color):
			(entry["respondent_colors"] as Array).append(color)
		by_answer[key] = entry
	var tallies: Array[Dictionary] = []
	for key in by_answer.keys():
		tallies.append(by_answer[key] as Dictionary)
	tallies.sort_custom(Callable(SurveyAnswerReview, "_sort_distinct_answer_tallies"))
	for index in range(tallies.size()):
		(tallies[index] as Dictionary)["rank"] = index + 1
	return tallies

static func _sort_distinct_answer_tallies(left: Dictionary, right: Dictionary) -> bool:
	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("text", "")) < str(right.get("text", ""))

static func _word_tallies(text_answers: Array, limit: int) -> Array[Dictionary]:
	var counts: Dictionary = {}
	for answer_value in text_answers:
		if not (answer_value is Dictionary):
			continue
		var words := _unique_words_for_answer(str((answer_value as Dictionary).get("text", "")))
		for word in words:
			counts[word] = int(counts.get(word, 0)) + 1
	var entries: Array[Dictionary] = []
	for word in counts.keys():
		entries.append({"word": str(word), "count": int(counts.get(word, 0))})
	entries.sort_custom(Callable(SurveyAnswerReview, "_sort_word_tallies"))
	var trimmed := entries.slice(0, mini(entries.size(), maxi(limit, 0)))
	for index in range(trimmed.size()):
		(trimmed[index] as Dictionary)["rank"] = index + 1
	return trimmed

static func _sort_word_tallies(left: Dictionary, right: Dictionary) -> bool:
	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("word", "")) < str(right.get("word", ""))

static func _unique_words_for_answer(text: String) -> Array[String]:
	var cleaned := text.to_lower()
	for token in [".", ",", ";", ":", "!", "?", "\"", "'", "`", "(", ")", "[", "]", "{", "}", "/", "\\", "|", "+", "=", "*", "&", "^", "%", "$", "#", "@", "~", "<", ">", "\n", "\r", "\t", "_", "-"]:
		cleaned = cleaned.replace(token, " ")
	var seen: Dictionary = {}
	var words: Array[String] = []
	for raw_part in cleaned.split(" ", false):
		var word := str(raw_part).strip_edges()
		if word.length() < 3:
			continue
		if word.is_valid_int() or word.is_valid_float():
			continue
		if WRAP_WORD_TALLY_STOPWORDS.has(word):
			continue
		if seen.has(word):
			continue
		seen[word] = true
		words.append(word)
	return words

static func _add_matrix_answer(payload: Dictionary, question: SurveyQuestion, value: Dictionary) -> void:
	var row_counts: Dictionary = payload.get("_matrix_row_counts", {})
	for row_name in question.rows:
		var selection := str(value.get(row_name, "")).strip_edges()
		if selection.is_empty():
			continue
		var option_counts: Dictionary = row_counts.get(row_name, _initialized_option_counts(question))
		_increment_dictionary_count(option_counts, selection)
		row_counts[row_name] = option_counts
	payload["_matrix_row_counts"] = row_counts

static func _add_ranked_answer(payload: Dictionary, question: SurveyQuestion, value: Array) -> void:
	var rank_counts: Dictionary = payload.get("_rank_counts", {})
	for rank_index in range(value.size()):
		var option := str(value[rank_index]).strip_edges()
		if option.is_empty():
			continue
		var per_option: Array = rank_counts.get(option, [])
		while per_option.size() < question.options.size():
			per_option.append(0)
		per_option[rank_index] = int(per_option[rank_index]) + 1
		rank_counts[option] = per_option
	payload["_rank_counts"] = rank_counts

static func _finalized_matrix_rows(payload: Dictionary, question: SurveyQuestion) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var row_counts: Dictionary = payload.get("_matrix_row_counts", {})
	for row_name in question.rows:
		rows.append({
			"row": row_name,
			"option_counts": row_counts.get(row_name, _initialized_option_counts(question))
		})
	payload.erase("_matrix_row_counts")
	return rows

static func _finalized_ranked_options(payload: Dictionary, question: SurveyQuestion) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var rank_counts: Dictionary = payload.get("_rank_counts", {})
	for option in question.options:
		var counts: Array = rank_counts.get(option, [])
		while counts.size() < question.options.size():
			counts.append(0)
		var weighted_total := 0.0
		var sample_count := 0
		for index in range(counts.size()):
			var count := int(counts[index])
			weighted_total += float(index + 1) * float(count)
			sample_count += count
		options.append({
			"option": option,
			"rank_counts": counts,
			"average_rank": snappedf(weighted_total / float(sample_count), 0.01) if sample_count > 0 else 0.0,
			"sample_count": sample_count
		})
	options.sort_custom(Callable(SurveyAnswerReview, "_sort_ranked_options"))
	payload.erase("_rank_counts")
	return options

static func _sort_ranked_options(left: Dictionary, right: Dictionary) -> bool:
	var left_average := float(left.get("average_rank", 999.0))
	var right_average := float(right.get("average_rank", 999.0))
	if not is_equal_approx(left_average, right_average):
		return left_average < right_average
	return str(left.get("option", "")) < str(right.get("option", ""))

static func _numeric_stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var min_value := INF
	var max_value := -INF
	var total := 0.0
	for value in values:
		var numeric := float(value)
		min_value = minf(min_value, numeric)
		max_value = maxf(max_value, numeric)
		total += numeric
	return {
		"min": snappedf(min_value, 0.01),
		"max": snappedf(max_value, 0.01),
		"average": snappedf(total / float(values.size()), 0.01),
		"count": values.size()
	}

static func _numeric_value_counts(values: Array) -> Dictionary:
	var counts: Dictionary = {}
	for value in values:
		_increment_dictionary_count(counts, _format_numeric(float(value)))
	return counts

static func _summary_for_question_payload(payload: Dictionary, question: SurveyQuestion) -> String:
	var answer_count := int(payload.get("answer_count", 0))
	if answer_count <= 0:
		return "No imported answers yet."
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			return "%d custom answer(s)." % answer_count
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			var stats: Dictionary = payload.get("numeric_stats", {})
			if stats.is_empty():
				return "%d numeric answer(s)." % answer_count
			return "Average %s from %d answer(s)." % [_format_numeric(float(stats.get("average", 0.0))), answer_count]
		SurveyQuestion.TYPE_MATRIX:
			return "%d matrix answer(s)." % answer_count
		SurveyQuestion.TYPE_RANKED_CHOICE:
			var ranked: Array = payload.get("ranked_options", [])
			if ranked.is_empty():
				return "%d ranked answer(s)." % answer_count
			return "Top average rank: %s." % str((ranked[0] as Dictionary).get("option", ""))
	return "%d answer(s)." % answer_count

static func _initialized_option_counts(question: SurveyQuestion) -> Dictionary:
	var counts: Dictionary = {}
	match question.type:
		SurveyQuestion.TYPE_BOOLEAN:
			counts["Yes"] = 0
			counts["No"] = 0
		_:
			for option in question.options:
				counts[option] = 0
	return counts

static func _increment_dictionary_count(counts: Dictionary, key: String) -> void:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return
	counts[normalized_key] = int(counts.get(normalized_key, 0)) + 1

static func _first_text_samples(values: Array, limit: int) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for value in values:
		if not (value is Dictionary):
			continue
		samples.append((value as Dictionary).duplicate(true))
		if samples.size() >= limit:
			break
	return samples

static func _collect_json_files(folder_path: String, recursive: bool) -> PackedStringArray:
	var files := PackedStringArray()
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return files
	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var child_path := folder_path.path_join(entry_name)
		if directory.current_is_dir():
			if recursive:
				files.append_array(_collect_json_files(child_path, recursive))
		elif entry_name.get_extension().to_lower() == "json":
			files.append(child_path.replace("\\", "/"))
	directory.list_dir_end()
	return files

static func _question_map(survey: SurveyDefinition) -> Dictionary:
	var map: Dictionary = {}
	if survey == null:
		return map
	for section in survey.sections:
		for question in section.questions:
			map[question.id] = question
	return map

static func _answer_to_text(question: SurveyQuestion, value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "Yes" if bool(value) else "No"
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value as Array:
				parts.append(str(item))
			return ", ".join(parts)
		TYPE_DICTIONARY:
			var pairs: Array[String] = []
			var dict: Dictionary = value as Dictionary
			if question.type == SurveyQuestion.TYPE_MATRIX:
				for row_name in question.rows:
					var row_value := str(dict.get(row_name, "")).strip_edges()
					if not row_value.is_empty():
						pairs.append("%s: %s" % [row_name, row_value])
				return " | ".join(pairs)
			for key in dict.keys():
				pairs.append("%s: %s" % [str(key), str(dict.get(key))])
			pairs.sort()
			return " | ".join(pairs)
	return str(value)

static func _record_signature(record: Dictionary) -> String:
	var payload_hash := str(record.get("payload_hash", "")).strip_edges()
	if not payload_hash.is_empty():
		return payload_hash
	var signature_payload := {
		"payload_format": str(record.get("payload_format", "")).strip_edges(),
		"survey_id": str(record.get("survey_id", "")).strip_edges(),
		"schema_hash": str(record.get("schema_hash", "")).strip_edges(),
		"saved_at": str(record.get("saved_at", "")).strip_edges(),
		"answers": record.get("answers", {})
	}
	return _sha256_text(JSON.stringify(signature_payload, "", true))

static func _sha256_text(text: String) -> String:
	var context := HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()

static func _default_review_settings() -> Dictionary:
	return {
		"folder_path": "",
		"recursive": true,
		"scrub_identifying_info": true,
		"wrapped_theme_id": WRAP_THEME_LIGHT,
		"wrapped_gradient_preset_id": WRAP_DEFAULT_GRADIENT_PRESET,
		"text_summary_mode": WRAP_TEXT_SUMMARY_AUTO,
		"respondent_color_overrides": {},
		"last_scan_at": "",
		"last_accepted_count": 0,
		"last_rejected_count": 0
	}

static func _load_all_review_settings() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(REVIEW_SETTINGS_PATH)
	if not FileAccess.file_exists(absolute_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute_path))
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}

static func _settings_key(survey_id: String) -> String:
	return _safe_segment(survey_id.strip_edges())

static func _parse_failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message.strip_edges()
	}

static func _rejected_file(path: String, message: String) -> Dictionary:
	return {
		"path": path,
		"file_name": path.get_file(),
		"message": message.strip_edges()
	}

static func _normalized_filesystem_path(path: String) -> String:
	var resolved := path.strip_edges()
	if resolved.is_empty():
		return ""
	if resolved.begins_with("user://") or resolved.begins_with("res://"):
		return ProjectSettings.globalize_path(resolved)
	return resolved.replace("\\", "/")

static func _safe_stamp(raw_value: String) -> String:
	return raw_value.replace(":", "-").replace(" ", "_")

static func _safe_segment(raw_value: String) -> String:
	var value := raw_value.to_lower().strip_edges()
	if value.is_empty():
		return ""
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	return value.trim_prefix("_").trim_suffix("_")

static func _format_numeric(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.01))
