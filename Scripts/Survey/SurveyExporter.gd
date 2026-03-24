class_name SurveyExporter
extends RefCounted

static func export_json(survey: SurveyDefinition, answers: Dictionary) -> String:
	var export_dir := _ensure_export_dir()
	if export_dir.is_empty():
		return ""

	var filename := "%s/%s" % [export_dir, suggested_filename(survey.id, "json")]
	if not save_text_file(filename, build_json_text(survey, answers)):
		return ""
	return filename

static func export_csv(survey: SurveyDefinition, answers: Dictionary) -> String:
	var export_dir := _ensure_export_dir()
	if export_dir.is_empty():
		return ""

	var filename := "%s/%s" % [export_dir, suggested_filename(survey.id, "csv")]
	if not save_text_file(filename, build_csv_text(survey, answers)):
		return ""
	return filename

static func build_json_text(survey: SurveyDefinition, answers: Dictionary) -> String:
	var payload := {
		"survey_id": survey.id,
		"title": survey.title,
		"subtitle": survey.subtitle,
		"exported_at": Time.get_datetime_string_from_system(true),
		"answers": _build_answers_payload(survey, answers)
	}
	return JSON.stringify(payload, "\t")

static func build_csv_text(survey: SurveyDefinition, answers: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("section_id,section_title,question_id,question_prompt,question_type,answer")
	for section in survey.sections:
		for question in section.questions:
			var row: Array[String] = [
				_csv_escape(section.id),
				_csv_escape(section.title),
				_csv_escape(question.id),
				_csv_escape(question.prompt),
				_csv_escape(str(question.type)),
				_csv_escape(_answer_to_text(answers.get(question.id)))
			]
			lines.append(",".join(row))
	return "\n".join(lines) + "\n"

static func save_text_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true

static func save_image_file(path: String, image: Image) -> bool:
	if image == null:
		return false
	return image.save_png(path) == OK

static func suggested_filename(survey_id: String, extension: String) -> String:
	return "%s.%s" % [_timestamped_name(survey_id), extension.to_lower()]

static func _build_answers_payload(survey: SurveyDefinition, answers: Dictionary) -> Array[Dictionary]:
	var payload: Array[Dictionary] = []
	for section in survey.sections:
		var section_payload := {
			"section_id": section.id,
			"section_title": section.title,
			"responses": []
		}
		for question in section.questions:
			var value: Variant = answers.get(question.id, null)
			section_payload["responses"].append({
				"question_id": question.id,
				"prompt": question.prompt,
				"type": str(question.type),
				"answer": value
			})
		payload.append(section_payload)
	return payload

static func _ensure_export_dir() -> String:
	var export_dir := ProjectSettings.globalize_path("user://exports")
	var result := DirAccess.make_dir_recursive_absolute(export_dir)
	if result != OK and not DirAccess.dir_exists_absolute(export_dir):
		return ""
	return export_dir

static func _timestamped_name(survey_id: String) -> String:
	var safe_id := survey_id.to_lower().replace(" ", "_")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return "%s_%s" % [safe_id, stamp]

static func _csv_escape(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")

static func _answer_to_text(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(str(item))
			return " | ".join(parts)
		TYPE_DICTIONARY:
			return JSON.stringify(value)
		TYPE_BOOL:
			return "true" if value else "false"
	return str(value)

