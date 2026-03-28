class_name SurveyTemplateLoader
extends RefCounted

const TEMPLATE_FORMAT := "survey_template"
const CURRENT_TEMPLATE_VERSION := 2
const BUILTIN_TEMPLATE_DIR := "res://Dev/SurveyTemplates"
const USER_TEMPLATE_DIR := "user://survey_templates"

static func load_from_file(path: String) -> SurveyDefinition:
	var report: Dictionary = validate_template_file(path)
	if not bool(report.get("ok", false)):
		var errors: PackedStringArray = _packed_string_array_from_variant(report.get("errors", PackedStringArray()))
		if errors.is_empty():
			push_warning("Failed to load survey template: %s" % path)
		else:
			push_warning("Failed to load survey template %s: %s" % [path, " | ".join(errors)])
		return null
	var normalized_template: Dictionary = _dictionary_from_variant(report.get("normalized_template", {}))
	return SurveyDefinition.new(normalized_template)

static func validate_template_file(path: String) -> Dictionary:
	if path.is_empty():
		return _validation_report(false, ["Survey template path is empty."], PackedStringArray(), {}, path)
	if not FileAccess.file_exists(path):
		return _validation_report(false, ["Survey template not found: %s" % path], PackedStringArray(), {}, path)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _validation_report(false, ["Failed to open survey template: %s" % path], PackedStringArray(), {}, path)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _validation_report(false, ["Survey template root must be a JSON object."], PackedStringArray(), {}, path)

	return validate_template_dict(parsed as Dictionary, path)

static func validate_template_dict(raw_template: Dictionary, source_path: String = "") -> Dictionary:
	var warnings: PackedStringArray = PackedStringArray()
	var normalized_template: Dictionary = _normalize_template_dict(raw_template, warnings)
	var errors: PackedStringArray = _validate_normalized_template(normalized_template)
	return _validation_report(errors.is_empty(), errors, warnings, normalized_template, source_path)

static func list_available_templates() -> Array[Dictionary]:
	var template_summaries: Array[Dictionary] = []
	var discovered_paths: PackedStringArray = PackedStringArray()
	_append_template_paths(BUILTIN_TEMPLATE_DIR, discovered_paths)
	_append_template_paths(USER_TEMPLATE_DIR, discovered_paths)
	for template_path in discovered_paths:
		var summary: Dictionary = describe_template_file(template_path)
		if not bool(summary.get("ok", false)):
			continue
		var insert_index: int = template_summaries.size()
		for existing_index in range(template_summaries.size()):
			if _sort_template_summaries(summary, template_summaries[existing_index]):
				insert_index = existing_index
				break
		template_summaries.insert(insert_index, summary)
	return template_summaries

static func describe_template_file(path: String) -> Dictionary:
	var report: Dictionary = validate_template_file(path)
	if not bool(report.get("ok", false)):
		return report
	var normalized_template: Dictionary = _dictionary_from_variant(report.get("normalized_template", {}))
	var source_label: String = "Built-in" if path.begins_with("res://") else "Imported"
	var description: String = str(normalized_template.get("description", normalized_template.get("subtitle", ""))).strip_edges()
	var title: String = str(normalized_template.get("title", path.get_file().get_basename())).strip_edges()
	var id_text: String = str(normalized_template.get("id", path.get_file().get_basename())).strip_edges()
	var summary: Dictionary = report.duplicate(true)
	summary["path"] = path
	summary["id"] = id_text
	summary["title"] = title
	summary["description"] = description
	summary["filename"] = path.get_file()
	summary["source_label"] = source_label
	summary["source_kind"] = "builtin" if path.begins_with("res://") else "imported"
	summary["version"] = int(normalized_template.get("version", CURRENT_TEMPLATE_VERSION))
	return summary

static func import_template_file(source_path: String) -> Dictionary:
	var report: Dictionary = validate_template_file(source_path)
	if not bool(report.get("ok", false)):
		return report
	return _import_validated_template_report(report, source_path)

static func import_template_json_text(source_text: String, source_name: String = "imported_template.json") -> Dictionary:
	var parsed: Variant = JSON.parse_string(source_text)
	if not (parsed is Dictionary):
		return _validation_report(false, ["Survey template root must be a JSON object."], PackedStringArray(), {}, source_name)
	var report: Dictionary = validate_template_dict(parsed as Dictionary, source_name)
	if not bool(report.get("ok", false)):
		return report
	return _import_validated_template_report(report, source_name)

static func _import_validated_template_report(report: Dictionary, source_path: String) -> Dictionary:
	var normalized_template: Dictionary = _dictionary_from_variant(report.get("normalized_template", {}))
	var user_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_TEMPLATE_DIR))
	if user_dir_error != OK:
		return _validation_report(false, ["Failed to prepare the survey template folder."], _packed_string_array_from_variant(report.get("warnings", PackedStringArray())), normalized_template, source_path)

	var base_name: String = _slugify_identifier(str(normalized_template.get("id", source_path.get_file().get_basename())))
	if base_name.is_empty():
		base_name = _slugify_identifier(source_path.get_file().get_basename())
	if base_name.is_empty():
		base_name = "survey_template"
	var target_path: String = _unique_user_template_path(base_name)
	var output_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if output_file == null:
		return _validation_report(false, ["Failed to write the imported survey template."], _packed_string_array_from_variant(report.get("warnings", PackedStringArray())), normalized_template, source_path)
	output_file.store_string(JSON.stringify(normalized_template, "\t", false))
	output_file.close()

	var imported_summary: Dictionary = describe_template_file(target_path)
	if not bool(imported_summary.get("ok", false)):
		return imported_summary
	imported_summary["imported_from"] = source_path
	return imported_summary

static func user_template_directory() -> String:
	return USER_TEMPLATE_DIR

static func built_in_template_directory() -> String:
	return BUILTIN_TEMPLATE_DIR

static func _validation_report(ok: bool, errors_value: Variant, warnings_value: Variant, normalized_template: Dictionary, source_path: String) -> Dictionary:
	return {
		"ok": ok,
		"errors": _packed_string_array_from_variant(errors_value),
		"warnings": _packed_string_array_from_variant(warnings_value),
		"normalized_template": normalized_template.duplicate(true),
		"source_path": source_path
	}

static func _normalize_template_dict(raw_template: Dictionary, warnings: PackedStringArray) -> Dictionary:
	var normalized_template: Dictionary = raw_template.duplicate(true)
	normalized_template["format"] = _resolved_template_format(raw_template)
	normalized_template["version"] = _resolved_template_version(raw_template, warnings)
	normalized_template["id"] = _resolved_root_id(raw_template)
	normalized_template["title"] = _resolved_root_title(raw_template, normalized_template)
	normalized_template["subtitle"] = str(raw_template.get("subtitle", raw_template.get("tagline", raw_template.get("description", "")))).strip_edges()
	normalized_template["description"] = str(raw_template.get("description", normalized_template.get("subtitle", ""))).strip_edges()
	normalized_template["onboarding_subject"] = str(raw_template.get("onboarding_subject", normalized_template.get("title", ""))).strip_edges()
	normalized_template["audience_profiles"] = _array_from_variant(raw_template.get("audience_profiles", raw_template.get("player_types", [])))
	normalized_template["guided_presets"] = _array_from_variant(raw_template.get("guided_presets", raw_template.get("onboarding_presets", [])))
	normalized_template["faq_items"] = _array_from_variant(raw_template.get("faq_items", raw_template.get("faqs", [])))
	normalized_template["sections"] = _normalize_sections(raw_template.get("sections", []), warnings)
	return normalized_template

static func _resolved_template_format(raw_template: Dictionary) -> String:
	var format_text: String = str(raw_template.get("format", raw_template.get("template_format", TEMPLATE_FORMAT))).strip_edges()
	if format_text.is_empty():
		return TEMPLATE_FORMAT
	return format_text

static func _resolved_template_version(raw_template: Dictionary, warnings: PackedStringArray) -> int:
	var raw_version: Variant = raw_template.get("version", raw_template.get("schema_version", raw_template.get("template_version", CURRENT_TEMPLATE_VERSION)))
	var version_number: int = int(raw_version)
	if version_number <= 0:
		version_number = 1
	if version_number > CURRENT_TEMPLATE_VERSION:
		warnings.append("Template version %d is newer than loader version %d. Unknown fields will be preserved when possible." % [version_number, CURRENT_TEMPLATE_VERSION])
	return version_number

static func _resolved_root_id(raw_template: Dictionary) -> String:
	var raw_id: String = str(raw_template.get("id", raw_template.get("key", raw_template.get("title", raw_template.get("name", "survey_template"))))).strip_edges()
	var resolved_id: String = _slugify_identifier(raw_id)
	if resolved_id.is_empty():
		return "survey_template"
	return resolved_id

static func _resolved_root_title(raw_template: Dictionary, normalized_template: Dictionary) -> String:
	var title: String = str(raw_template.get("title", raw_template.get("name", normalized_template.get("id", "Survey")))).strip_edges()
	if title.is_empty():
		return "Survey"
	return title

static func _normalize_sections(value: Variant, warnings: PackedStringArray) -> Array[Dictionary]:
	var normalized_sections: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var raw_sections: Array = _array_from_variant(value)
	for section_index in range(raw_sections.size()):
		var raw_section: Variant = raw_sections[section_index]
		if not (raw_section is Dictionary):
			warnings.append("Skipped section %d because it was not an object." % [section_index + 1])
			continue
		var normalized_section: Dictionary = _normalize_section(raw_section as Dictionary, section_index, warnings)
		var section_id: String = str(normalized_section.get("id", "")).strip_edges()
		if section_id.is_empty():
			section_id = "section_%d" % [section_index + 1]
			normalized_section["id"] = section_id
		if seen_ids.has(section_id):
			var deduped_id: String = _dedupe_identifier(section_id, seen_ids)
			warnings.append("Duplicate section id '%s' was renamed to '%s'." % [section_id, deduped_id])
			normalized_section["id"] = deduped_id
			section_id = deduped_id
		seen_ids[section_id] = true
		normalized_sections.append(normalized_section)
	return normalized_sections

static func _normalize_section(raw_section: Dictionary, section_index: int, warnings: PackedStringArray) -> Dictionary:
	var model: SurveySection = SurveySection.new(raw_section)
	var title: String = model.title.strip_edges()
	if title.is_empty():
		title = "Section %d" % [section_index + 1]
		warnings.append("Section %d was missing a title. A fallback title was generated." % [section_index + 1])
	var section_id: String = _slugify_identifier(str(raw_section.get("id", title)))
	if section_id.is_empty():
		section_id = "section_%d" % [section_index + 1]
		warnings.append("Section '%s' was missing an id. A fallback id was generated." % title)
	return {
		"id": section_id,
		"title": title,
		"description": model.description,
		"icon": model.icon_name,
		"emoji": str(raw_section.get("emoji", raw_section.get("icon_emoji", ""))).strip_edges(),
		"header_template": str(raw_section.get("header_template", "")).strip_edges(),
		"questions": _normalize_questions(raw_section.get("questions", []), section_id, warnings)
	}

static func _normalize_questions(value: Variant, section_id: String, warnings: PackedStringArray) -> Array[Dictionary]:
	var normalized_questions: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var raw_questions: Array = _array_from_variant(value)
	for question_index in range(raw_questions.size()):
		var raw_question: Variant = raw_questions[question_index]
		if not (raw_question is Dictionary):
			warnings.append("Skipped question %d in section '%s' because it was not an object." % [question_index + 1, section_id])
			continue
		var normalized_question: Dictionary = _normalize_question(raw_question as Dictionary, section_id, question_index, warnings)
		var question_id: String = str(normalized_question.get("id", "")).strip_edges()
		if question_id.is_empty():
			question_id = "%s_question_%d" % [section_id, question_index + 1]
			normalized_question["id"] = question_id
		if seen_ids.has(question_id):
			var deduped_id: String = _dedupe_identifier(question_id, seen_ids)
			warnings.append("Duplicate question id '%s' in section '%s' was renamed to '%s'." % [question_id, section_id, deduped_id])
			normalized_question["id"] = deduped_id
			question_id = deduped_id
		seen_ids[question_id] = true
		normalized_questions.append(normalized_question)
	return normalized_questions

static func _normalize_question(raw_question: Dictionary, section_id: String, question_index: int, warnings: PackedStringArray) -> Dictionary:
	var model: SurveyQuestion = SurveyQuestion.new(raw_question)
	var prompt: String = model.prompt.strip_edges()
	if prompt.is_empty():
		prompt = "Question %d" % [question_index + 1]
		warnings.append("Question %d in section '%s' was missing a prompt. A fallback prompt was generated." % [question_index + 1, section_id])
	var question_id: String = _slugify_identifier(str(raw_question.get("id", prompt)))
	if question_id.is_empty():
		question_id = "%s_question_%d" % [_slugify_identifier(section_id), question_index + 1]
		warnings.append("Question '%s' was missing an id. A fallback id was generated." % prompt)
	var normalized_question: Dictionary = {
		"id": question_id,
		"prompt": prompt,
		"description": model.description,
		"type": str(model.type),
		"required": model.required,
		"placeholder": model.placeholder,
		"options": model.options,
		"rows": model.rows,
		"topic_tags": model.topic_tags,
		"keywords": model.keywords,
		"audience_tags": model.audience_tags,
		"min_value": model.min_value,
		"max_value": model.max_value,
		"step": model.step,
		"left_label": model.left_label,
		"right_label": model.right_label,
		"emoji": str(raw_question.get("emoji", raw_question.get("prompt_emoji", ""))).strip_edges()
	}
	if raw_question.has("default_value"):
		normalized_question["default_value"] = raw_question.get("default_value")
	var view_template: String = str(raw_question.get("view_template", raw_question.get("template", ""))).strip_edges()
	if not view_template.is_empty():
		normalized_question["view_template"] = view_template
	var normalized_rating: Dictionary = _normalize_question_rating(raw_question, model, prompt, warnings)
	if not normalized_rating.is_empty():
		normalized_question["rating"] = normalized_rating
	if int(normalized_question["max_value"]) < int(normalized_question["min_value"]):
		var resolved_min: int = int(normalized_question["max_value"])
		var resolved_max: int = int(normalized_question["min_value"])
		normalized_question["min_value"] = resolved_min
		normalized_question["max_value"] = resolved_max
		warnings.append("Question '%s' had min/max reversed. The values were swapped." % prompt)
	if float(normalized_question["step"]) <= 0.0:
		normalized_question["step"] = 1.0
		warnings.append("Question '%s' had a non-positive step. It was reset to 1." % prompt)
	return normalized_question

static func _normalize_question_rating(raw_question: Dictionary, model: SurveyQuestion, prompt: String, warnings: PackedStringArray) -> Dictionary:
	var has_rating_source: bool = not _dictionary_from_variant(raw_question.get("rating", {})).is_empty()
	for key in ["rating_enabled", "rating_reverse", "rating_weight", "rating_label", "rating_option_scores"]:
		if raw_question.has(key):
			has_rating_source = true
			break
	if not has_rating_source:
		return {}
	var normalized_rating: Dictionary = {
		"enabled": model.rating_enabled
	}
	if model.rating_reverse:
		normalized_rating["reverse"] = true
	if not is_equal_approx(model.rating_weight, 1.0):
		normalized_rating["weight"] = model.rating_weight
	if not model.rating_label.is_empty():
		normalized_rating["label"] = model.rating_label
	if not model.rating_option_scores.is_empty():
		var option_scores: Dictionary = {}
		for key in model.rating_option_scores.keys():
			option_scores[str(key)] = float(model.rating_option_scores.get(key, 0.0))
		normalized_rating["option_scores"] = option_scores
	if model.rating_enabled and not model.is_rating_question():
		warnings.append("Question '%s' has rating metadata, but its type does not currently produce a score with the supplied config." % prompt)
	return normalized_rating

static func _validate_normalized_template(normalized_template: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var title: String = str(normalized_template.get("title", "")).strip_edges()
	if title.is_empty():
		errors.append("Template title is required.")
	var format_text: String = str(normalized_template.get("format", TEMPLATE_FORMAT)).strip_edges()
	if format_text != TEMPLATE_FORMAT:
		errors.append("Unsupported template format '%s'." % format_text)
	var sections: Array = _array_from_variant(normalized_template.get("sections", []))
	if sections.is_empty():
		errors.append("At least one section is required.")
		return errors
	for section_index in range(sections.size()):
		var section: Dictionary = _dictionary_from_variant(sections[section_index])
		var section_title: String = str(section.get("title", "")).strip_edges()
		if section_title.is_empty():
			errors.append("Section %d is missing a title." % [section_index + 1])
		var questions: Array = _array_from_variant(section.get("questions", []))
		if questions.is_empty():
			errors.append("Section '%s' must contain at least one question." % section_title)
			continue
		for question_index in range(questions.size()):
			var question: Dictionary = _dictionary_from_variant(questions[question_index])
			_validate_question(question, section_title, question_index, errors)
	return errors

static func _validate_question(question: Dictionary, section_title: String, question_index: int, errors: PackedStringArray) -> void:
	var prompt: String = str(question.get("prompt", "")).strip_edges()
	if prompt.is_empty():
		errors.append("Question %d in section '%s' is missing a prompt." % [question_index + 1, section_title])
	var question_type: String = str(question.get("type", SurveyQuestion.TYPE_SHORT_TEXT)).strip_edges()
	var options: PackedStringArray = _packed_string_array_from_variant(question.get("options", PackedStringArray()))
	var rows: PackedStringArray = _packed_string_array_from_variant(question.get("rows", PackedStringArray()))
	match StringName(question_type):
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_MULTI_CHOICE, SurveyQuestion.TYPE_DROPDOWN, SurveyQuestion.TYPE_RANKED_CHOICE, SurveyQuestion.TYPE_BOOLEAN:
			if options.is_empty():
				errors.append("Question '%s' requires at least one option." % prompt)
		SurveyQuestion.TYPE_MATRIX:
			if rows.is_empty():
				errors.append("Matrix question '%s' requires at least one row." % prompt)
			if options.is_empty():
				errors.append("Matrix question '%s' requires at least one option." % prompt)

static func _append_template_paths(root_dir: String, paths: PackedStringArray) -> void:
	_ensure_template_directory(root_dir)
	var directory: DirAccess = DirAccess.open(root_dir)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var child_path: String = "%s/%s" % [root_dir.trim_suffix("/"), entry_name]
		if directory.current_is_dir():
			_append_template_paths(child_path, paths)
		elif entry_name.get_extension().to_lower() == "json" and not paths.has(child_path):
			paths.append(child_path)
	directory.list_dir_end()

static func _ensure_template_directory(dir_path: String) -> void:
	if dir_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

static func _sort_template_summaries(left: Dictionary, right: Dictionary) -> bool:
	var left_source: String = str(left.get("source_kind", ""))
	var right_source: String = str(right.get("source_kind", ""))
	if left_source != right_source:
		return left_source == "builtin"
	return str(left.get("title", "")) < str(right.get("title", ""))

static func _unique_user_template_path(base_name: String) -> String:
	var candidate_path: String = "%s/%s.json" % [USER_TEMPLATE_DIR, base_name]
	if not FileAccess.file_exists(candidate_path):
		return candidate_path
	var suffix: int = 2
	while true:
		var next_path: String = "%s/%s_%d.json" % [USER_TEMPLATE_DIR, base_name, suffix]
		if not FileAccess.file_exists(next_path):
			return next_path
		suffix += 1
	return candidate_path

static func _dedupe_identifier(identifier: String, seen_ids: Dictionary) -> String:
	var suffix: int = 2
	while true:
		var candidate: String = "%s_%d" % [identifier, suffix]
		if not seen_ids.has(candidate):
			return candidate
		suffix += 1
	return identifier

static func _slugify_identifier(raw_value: String) -> String:
	var slug: String = raw_value.to_lower().strip_edges()
	for token in ["\n", "\t", ".", ",", ":", ";", "!", "?", "(", ")", "[", "]", "{", "}", "/", "\\", "-", " ", '"', "'", "|", "&"]:
		slug = slug.replace(token, "_")
	while slug.contains("__"):
		slug = slug.replace("__", "_")
	return slug.trim_prefix("_").trim_suffix("_")

static func _array_from_variant(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is PackedStringArray:
		var resolved: Array = []
		for item in value:
			resolved.append(item)
		return resolved
	return []

static func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _packed_string_array_from_variant(value: Variant) -> PackedStringArray:
	var resolved: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				resolved.append(text)
		return resolved
	if value is Array:
		var values: Array = value as Array
		for item in values:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				resolved.append(text)
		return resolved
	var single_value: String = str(value).strip_edges()
	if not single_value.is_empty():
		resolved.append(single_value)
	return resolved

