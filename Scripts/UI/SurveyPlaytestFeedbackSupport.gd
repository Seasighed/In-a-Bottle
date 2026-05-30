class_name SurveyPlaytestFeedbackSupport
extends RefCounted

const FORMAT_ID := "survey_playtest_feedback_v1"
const ZIP_EXPORT_DIR := "user://playtest_feedback_exports"

static func build_session_manifest(surface_id: String, session_started_at_unix: int, session_started_at_iso: String, issue_count: int) -> Dictionary:
	return {
		"format": FORMAT_ID,
		"surface": surface_id.strip_edges(),
		"session_started_at_unix": session_started_at_unix,
		"session_started_at": session_started_at_iso.strip_edges(),
		"issue_count": issue_count
	}

static func suggested_zip_filename(surface_id: String, stamp: String) -> String:
	var sanitized_surface := _sanitize_file_segment(surface_id)
	var sanitized_stamp := _sanitize_file_segment(stamp)
	if sanitized_surface.is_empty():
		sanitized_surface = "feedback"
	if sanitized_stamp.is_empty():
		sanitized_stamp = "session"
	return "playtest_feedback_%s_%s.zip" % [sanitized_surface, sanitized_stamp]

static func build_bundle_json_text(session_manifest: Dictionary, issues: Array) -> String:
	var payload := {
		"format": FORMAT_ID,
		"session": _sanitize_variant(session_manifest),
		"issues": _sanitize_variant(issues)
	}
	return JSON.stringify(payload, "\t")

static func build_report_markdown(session_manifest: Dictionary, issues: Array) -> String:
	var lines: Array[String] = [
		"# Playtest Feedback Report",
		"",
		"- Surface: %s" % str(session_manifest.get("surface", "")).strip_edges(),
		"- Session started: %s" % str(session_manifest.get("session_started_at", "")).strip_edges(),
		"- Issue count: %d" % issues.size(),
		""
	]
	if issues.is_empty():
		lines.append("No issues were captured during this session.")
		return "\n".join(lines).strip_edges() + "\n"
	for issue_variant in issues:
		if not (issue_variant is Dictionary):
			continue
		var issue: Dictionary = issue_variant as Dictionary
		lines.append("## %s" % str(issue.get("id", "issue")).strip_edges())
		lines.append("")
		lines.append("- Timestamp: %s" % str(issue.get("timestamp", "")).strip_edges())
		lines.append("- Surface: %s" % str(issue.get("surface", "")).strip_edges())
		lines.append("- Page: %s" % str(issue.get("page_summary", "")).strip_edges())
		lines.append("- Target: %s" % str(issue.get("target_summary", "")).strip_edges())
		var capture_summary: String = _capture_summary(issue)
		if not capture_summary.is_empty():
			lines.append("- Captured via: %s" % capture_summary)
		lines.append("- Coordinates: %s" % _coordinate_summary(issue.get("click", {})))
		var semantic_context: Dictionary = issue.get("semantic_context", {}) as Dictionary
		var semantic_summary := _semantic_summary(semantic_context)
		if not semantic_summary.is_empty():
			lines.append("- Semantic context: %s" % semantic_summary)
		var control_context: Dictionary = issue.get("control_context", {}) as Dictionary
		var control_summary := _control_summary(control_context)
		if not control_summary.is_empty():
			lines.append("- Control: %s" % control_summary)
		var nearby_text := _array_from_variant(issue.get("nearby_text", []))
		if not nearby_text.is_empty():
			lines.append("- Nearby text: %s" % " | ".join(nearby_text))
		var screenshot: Dictionary = issue.get("screenshot", {}) as Dictionary
		var screenshot_path := str(screenshot.get("file_path", "")).strip_edges()
		if not screenshot_path.is_empty():
			lines.append("- Screenshot: %s" % screenshot_path)
		lines.append("")
		lines.append("Description:")
		lines.append("")
		lines.append(str(issue.get("description", "")).strip_edges())
		lines.append("")
		lines.append("Structured context:")
		lines.append("")
		lines.append("```json")
		lines.append(JSON.stringify(_sanitize_variant(issue), "\t"))
		lines.append("```")
		lines.append("")
	return "\n".join(lines).strip_edges() + "\n"

static func build_zip_export(session_manifest: Dictionary, issues: Array, file_name: String) -> Dictionary:
	var report_markdown := build_report_markdown(session_manifest, issues)
	var bundle_json := build_bundle_json_text(session_manifest, issues)
	var zip_dir_absolute := ProjectSettings.globalize_path(ZIP_EXPORT_DIR)
	var ensure_error := DirAccess.make_dir_recursive_absolute(zip_dir_absolute)
	if ensure_error != OK:
		return {
			"ok": false,
			"message": "Failed to prepare the feedback export folder."
		}
	var zip_path := ZIP_EXPORT_DIR.path_join(file_name)
	var writer := ZIPPacker.new()
	writer.compression_level = ZIPPacker.COMPRESSION_DEFAULT
	var open_error := writer.open(zip_path, ZIPPacker.APPEND_CREATE)
	if open_error != OK:
		return {
			"ok": false,
			"message": "Failed to create the feedback ZIP archive."
		}
	var write_error := _write_zip_entry(writer, "feedback_report.md", report_markdown.to_utf8_buffer())
	if write_error == OK:
		write_error = _write_zip_entry(writer, "feedback_bundle.json", bundle_json.to_utf8_buffer())
	if write_error == OK:
		for issue_variant in issues:
			if not (issue_variant is Dictionary):
				continue
			var issue: Dictionary = issue_variant as Dictionary
			var screenshot: Dictionary = issue.get("screenshot", {}) as Dictionary
			var screenshot_path := str(screenshot.get("file_path", "")).strip_edges()
			var screenshot_buffer: PackedByteArray = issue.get("_screenshot_png", PackedByteArray())
			if screenshot_path.is_empty() or screenshot_buffer.is_empty():
				continue
			write_error = _write_zip_entry(writer, screenshot_path, screenshot_buffer)
			if write_error != OK:
				break
	var close_error := writer.close()
	if write_error != OK or close_error != OK:
		return {
			"ok": false,
			"message": "Failed to finish the feedback ZIP archive."
		}
	var zip_buffer := FileAccess.get_file_as_bytes(zip_path)
	if zip_buffer.is_empty():
		return {
			"ok": false,
			"message": "The feedback ZIP archive was empty."
		}
	return {
		"ok": true,
		"buffer": zip_buffer,
		"file_name": file_name,
		"zip_path": zip_path,
		"report_markdown": report_markdown,
		"bundle_json": bundle_json
	}

static func _write_zip_entry(writer: ZIPPacker, entry_path: String, buffer: PackedByteArray) -> Error:
	var start_error := writer.start_file(entry_path)
	if start_error != OK:
		return start_error
	var write_error := writer.write_file(buffer)
	var close_error := writer.close_file()
	if write_error != OK:
		return write_error
	return close_error

static func _coordinate_summary(click_context: Dictionary) -> String:
	var pixel_position: Dictionary = click_context.get("pixel_position", {}) as Dictionary
	var normalized_position: Dictionary = click_context.get("normalized_position", {}) as Dictionary
	return "(%d, %d) | normalized %.3f, %.3f" % [
		int(pixel_position.get("x", 0)),
		int(pixel_position.get("y", 0)),
		float(normalized_position.get("x", 0.0)),
		float(normalized_position.get("y", 0.0))
	]

static func _capture_summary(issue: Dictionary) -> String:
	var parts: Array[String] = []
	var capture_method: String = str(issue.get("capture_method", "")).strip_edges()
	var input_kind: String = str(issue.get("input_kind", "")).strip_edges()
	var trigger_source: String = str(issue.get("trigger_source", "")).strip_edges()
	if not capture_method.is_empty():
		parts.append(capture_method)
	if not input_kind.is_empty():
		parts.append(input_kind)
	if not trigger_source.is_empty():
		parts.append(trigger_source)
	return " | ".join(parts)

static func _semantic_summary(semantic_context: Dictionary) -> String:
	var parts: Array[String] = []
	var question_context: Dictionary = semantic_context.get("survey_question", {}) as Dictionary
	if not question_context.is_empty():
		var question_id := str(question_context.get("question_id", "")).strip_edges()
		var question_type := str(question_context.get("type", "")).strip_edges()
		var requirement := str(question_context.get("requirement_label", "")).strip_edges()
		var answer_state := str(question_context.get("answer_state", "")).strip_edges()
		var question_bits: Array[String] = []
		if not question_id.is_empty():
			question_bits.append("question `%s`" % question_id)
		if not question_type.is_empty():
			question_bits.append(question_type)
		if not requirement.is_empty():
			question_bits.append(requirement)
		if not answer_state.is_empty():
			question_bits.append(answer_state)
		if not question_bits.is_empty():
			parts.append(", ".join(question_bits))
	var section_context: Dictionary = semantic_context.get("survey_section", {}) as Dictionary
	if not section_context.is_empty():
		var title := str(section_context.get("section_title", "")).strip_edges()
		var index := int(section_context.get("section_index", -1))
		if not title.is_empty():
			parts.append("section %d: %s" % [index + 1, title] if index >= 0 else "section: %s" % title)
	var review_context: Dictionary = semantic_context.get("journey_review", {}) as Dictionary
	if not review_context.is_empty():
		parts.append("review card")
	var template_context: Dictionary = semantic_context.get("journey_template", {}) as Dictionary
	if not template_context.is_empty():
		var title := str(template_context.get("title", "")).strip_edges()
		parts.append("template card%s" % (": %s" % title if not title.is_empty() else ""))
	var search_context: Dictionary = semantic_context.get("search_result", {}) as Dictionary
	if not search_context.is_empty():
		parts.append("search result")
	var outline_context: Dictionary = semantic_context.get("section_outline", {}) as Dictionary
	if not outline_context.is_empty():
		parts.append("section outline")
	var menu_context: Dictionary = semantic_context.get("menu_action", {}) as Dictionary
	if not menu_context.is_empty():
		var action_label := str(menu_context.get("label", menu_context.get("action", ""))).strip_edges()
		parts.append("menu action%s" % (": %s" % action_label if not action_label.is_empty() else ""))
	return " | ".join(parts)

static func _control_summary(control_context: Dictionary) -> String:
	var target: Dictionary = control_context.get("target", {}) as Dictionary
	var parts: Array[String] = []
	var control_class_name := str(target.get("class_name", "")).strip_edges()
	var node_name := str(target.get("name", "")).strip_edges()
	var path := str(target.get("path", "")).strip_edges()
	var text := str(target.get("text_summary", "")).strip_edges()
	if not control_class_name.is_empty():
		parts.append(control_class_name)
	if not node_name.is_empty():
		parts.append(node_name)
	if not text.is_empty():
		parts.append(text)
	if not path.is_empty():
		parts.append(path)
	return " | ".join(parts)

static func _array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
		return result
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result

static func _sanitize_file_segment(value: String) -> String:
	var sanitized := value.strip_edges().to_lower()
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		sanitized = sanitized.replace(token, "_")
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	return sanitized.trim_prefix("_").trim_suffix("_")

static func _sanitize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var resolved: Dictionary = {}
			var source := value as Dictionary
			for key_variant in source.keys():
				var key_text := str(key_variant)
				if key_text.begins_with("_"):
					continue
				resolved[key_text] = _sanitize_variant(source.get(key_variant))
			return resolved
		TYPE_ARRAY:
			var resolved_array: Array = []
			for item in value as Array:
				resolved_array.append(_sanitize_variant(item))
			return resolved_array
		TYPE_PACKED_STRING_ARRAY:
			var resolved_strings: Array = []
			for item in value as PackedStringArray:
				resolved_strings.append(str(item))
			return resolved_strings
		TYPE_STRING_NAME:
			return str(value)
	return value
