class_name SurveyQaSessionSupport
extends RefCounted

const SURVEY_EXPORTER = preload("res://Scripts/Survey/SurveyExporter.gd")
const SURVEY_SAVE_BUNDLE = preload("res://Scripts/Survey/SurveySaveBundle.gd")
const SURVEY_PLAYTEST_FEEDBACK_SUPPORT = preload("res://Scripts/UI/SurveyPlaytestFeedbackSupport.gd")

const FORMAT_ID := "survey_qa_session_v1"
const SESSION_STATE_PATH := "user://qa_mode_session.json"
const CAPTURE_ROOT_DIR := "user://qa_captures"
const ZIP_EXPORT_DIR := "user://qa_exports"

static func default_session(surface_id: String, default_template_path: String = "") -> Dictionary:
	var stamp := Time.get_datetime_string_from_system(true)
	var session_id := _safe_segment("%s_%s" % [surface_id.strip_edges(), stamp.replace(":", "-")])
	return {
		"format": FORMAT_ID,
		"version": 1,
		"session_id": session_id,
		"started_at": stamp,
		"updated_at": stamp,
		"default_template_path": default_template_path.strip_edges(),
		"surfaces": {
			surface_id.strip_edges(): _default_surface_state(surface_id)
		}
	}

static func load_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_STATE_PATH):
		return {}
	var contents := FileAccess.get_file_as_string(SESSION_STATE_PATH)
	if contents.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(contents)
	if not (parsed is Dictionary):
		return {}
	return _normalize_session(parsed as Dictionary)

static func ensure_session(surface_id: String, default_template_path: String = "") -> Dictionary:
	var session: Dictionary = load_session()
	if session.is_empty():
		session = default_session(surface_id, default_template_path)
	var normalized_surface_id := surface_id.strip_edges()
	if not session.has("surfaces"):
		session["surfaces"] = {}
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	if not surfaces.has(normalized_surface_id):
		surfaces[normalized_surface_id] = _default_surface_state(normalized_surface_id)
	session["surfaces"] = surfaces
	if str(session.get("default_template_path", "")).strip_edges().is_empty():
		session["default_template_path"] = default_template_path.strip_edges()
	session["updated_at"] = Time.get_datetime_string_from_system(true)
	return _normalize_session(session)

static func save_session(session: Dictionary) -> bool:
	var normalized_session := _normalize_session(session)
	var file := FileAccess.open(SESSION_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_sanitize_variant(normalized_session), "\t"))
	file.close()
	return true

static func surface_state(session: Dictionary, surface_id: String) -> Dictionary:
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	return surfaces.get(surface_id.strip_edges(), _default_surface_state(surface_id)) as Dictionary

static func session_has_resume_data(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	for surface_value in surfaces.values():
		if not (surface_value is Dictionary):
			continue
		var surface_state_dict: Dictionary = surface_value as Dictionary
		var checklist_results: Dictionary = surface_state_dict.get("checklist_results", {}) as Dictionary
		var captures: Array = surface_state_dict.get("captures", []) as Array
		var issues: Array = surface_state_dict.get("issues", []) as Array
		if not checklist_results.is_empty() or not captures.is_empty() or not issues.is_empty():
			return true
	return false

static func set_current_page(session: Dictionary, surface_id: String, page_node_id: String) -> Dictionary:
	var updated := _normalize_session(session)
	var surface := surface_state(updated, surface_id)
	surface["current_page_node_id"] = page_node_id.strip_edges()
	_set_surface_state(updated, surface_id, surface)
	return updated

static func record_check_result(session: Dictionary, surface_id: String, item: Dictionary, status: String, note: String = "", extra: Dictionary = {}) -> Dictionary:
	var updated := _normalize_session(session)
	var surface := surface_state(updated, surface_id)
	var item_id := str(item.get("id", "")).strip_edges()
	if item_id.is_empty():
		return updated
	var checklist_results: Dictionary = surface.get("checklist_results", {}) as Dictionary
	var result_payload := {
		"item_id": item_id,
		"page_node_id": str(item.get("page_node_id", "")).strip_edges(),
		"label": str(item.get("label", "")).strip_edges(),
		"expected_result": str(item.get("expected_result", "")).strip_edges(),
		"status": status.strip_edges().to_lower(),
		"note": note.strip_edges(),
		"updated_at": Time.get_datetime_string_from_system(true),
		"severity": str(item.get("severity", "normal")).strip_edges(),
		"manual_only": bool(item.get("manual_only", false)),
		"conditional_key": str(item.get("conditional_key", "")).strip_edges()
	}
	for key_variant in extra.keys():
		var key := str(key_variant).strip_edges()
		if key.is_empty():
			continue
		result_payload[key] = extra.get(key_variant)
	checklist_results[item_id] = result_payload
	surface["checklist_results"] = checklist_results
	_set_surface_state(updated, surface_id, surface)
	return updated

static func record_capture(session: Dictionary, surface_id: String, capture_entry: Dictionary) -> Dictionary:
	var updated := _normalize_session(session)
	var surface := surface_state(updated, surface_id)
	var captures: Array = surface.get("captures", []) as Array
	captures.append(_sanitize_variant(capture_entry))
	surface["captures"] = captures
	_set_surface_state(updated, surface_id, surface)
	return updated

static func record_feedback_issues(session: Dictionary, surface_id: String, issues: Array) -> Dictionary:
	var updated := _normalize_session(session)
	var surface := surface_state(updated, surface_id)
	surface["issues"] = _sanitize_variant(issues)
	_set_surface_state(updated, surface_id, surface)
	return updated

static func build_capture_paths(session_id: String, surface_id: String, page_node_id: String, label: String = "capture") -> Dictionary:
	var file_name := "%s_%s_%s.png" % [
		_safe_segment(surface_id),
		_safe_segment(page_node_id),
		_safe_segment("%s_%s" % [label, Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")])
	]
	var relative_dir := "%s/%s" % [_safe_segment(session_id), _safe_segment(surface_id)]
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_ROOT_DIR.path_join(relative_dir))
	var ensure_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return {}
	return {
		"absolute_path": absolute_dir.path_join(file_name),
		"relative_path": "%s/%s" % [relative_dir, file_name]
	}

static func suggested_zip_filename(session: Dictionary, surface_id: String) -> String:
	var session_id := _safe_segment(str(session.get("session_id", "qa_session")))
	var surface := _safe_segment(surface_id)
	return "survey_qa_bundle_%s_%s.zip" % [surface if not surface.is_empty() else "surface", session_id]

static func build_zip_export(session: Dictionary, surface_id: String, environment: Dictionary, export_payload: Dictionary) -> Dictionary:
	var normalized_session := _normalize_session(session)
	var zip_dir_absolute := ProjectSettings.globalize_path(ZIP_EXPORT_DIR)
	var ensure_error := DirAccess.make_dir_recursive_absolute(zip_dir_absolute)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(zip_dir_absolute):
		return {
			"ok": false,
			"message": "Failed to prepare the QA export folder."
		}
	var file_name := suggested_zip_filename(normalized_session, surface_id)
	var zip_path := ZIP_EXPORT_DIR.path_join(file_name)
	var writer := ZIPPacker.new()
	writer.compression_level = ZIPPacker.COMPRESSION_DEFAULT
	var open_error := writer.open(zip_path, ZIPPacker.APPEND_CREATE)
	if open_error != OK:
		return {
			"ok": false,
			"message": "Failed to create the QA ZIP archive."
		}
	var checklist_json := JSON.stringify(_checklist_results_payload(normalized_session), "\t")
	var session_json := JSON.stringify(_sanitize_variant(normalized_session), "\t")
	var environment_json := JSON.stringify(_sanitize_variant(environment), "\t")
	var report_markdown := build_report_markdown(normalized_session, environment)
	var write_error := _write_zip_entry(writer, "report.md", report_markdown.to_utf8_buffer())
	if write_error == OK:
		write_error = _write_zip_entry(writer, "session.json", session_json.to_utf8_buffer())
	if write_error == OK:
		write_error = _write_zip_entry(writer, "checklist_results.json", checklist_json.to_utf8_buffer())
	if write_error == OK:
		write_error = _write_zip_entry(writer, "environment.json", environment_json.to_utf8_buffer())
	if write_error == OK:
		write_error = _write_export_payload_entries(writer, export_payload)
	if write_error == OK:
		write_error = _write_capture_entries(writer, normalized_session)
	if write_error == OK:
		write_error = _write_issue_entries(writer, normalized_session)
	var close_error := writer.close()
	if write_error != OK or close_error != OK:
		return {
			"ok": false,
			"message": "Failed to finish the QA ZIP archive."
		}
	var zip_buffer := FileAccess.get_file_as_bytes(zip_path)
	if zip_buffer.is_empty():
		return {
			"ok": false,
			"message": "The QA ZIP archive was empty."
		}
	return {
			"ok": true,
			"buffer": zip_buffer,
			"file_name": file_name,
			"zip_path": zip_path
		}

static func build_report_markdown(session: Dictionary, environment: Dictionary) -> String:
	var lines: Array[String] = [
		"# QA Session Report",
		"",
		"- Session ID: %s" % str(session.get("session_id", "")).strip_edges(),
		"- Started: %s" % str(session.get("started_at", "")).strip_edges(),
		"- Updated: %s" % str(session.get("updated_at", "")).strip_edges(),
		"- Template: %s" % str(session.get("default_template_path", "")).strip_edges(),
		"- Current surface: %s" % str(environment.get("surface_id", "")).strip_edges(),
		"- Platform: %s" % str(environment.get("platform_label", "")).strip_edges(),
		""
	]
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	for surface_id_variant in surfaces.keys():
		var surface_id := str(surface_id_variant).strip_edges()
		var surface: Dictionary = surfaces.get(surface_id_variant, {}) as Dictionary
		var checklist_results: Dictionary = surface.get("checklist_results", {}) as Dictionary
		var captures: Array = surface.get("captures", []) as Array
		var issues: Array = surface.get("issues", []) as Array
		lines.append("## %s" % surface_id)
		lines.append("")
		lines.append("- Current page: %s" % str(surface.get("current_page_node_id", "")).strip_edges())
		lines.append("- Checklist results: %d" % checklist_results.size())
		lines.append("- Captures: %d" % captures.size())
		lines.append("- Reported issues: %d" % issues.size())
		var status_counts := _status_counts(checklist_results)
		if not status_counts.is_empty():
			lines.append("- Status counts: %s" % _status_summary(status_counts))
		lines.append("")
	return "\n".join(lines).strip_edges() + "\n"

static func build_export_payload(runtime_state: Dictionary) -> Dictionary:
	var survey: SurveyDefinition = runtime_state.get("survey") as SurveyDefinition
	if survey == null:
		return {}
	var template_path := str(runtime_state.get("template_path", "")).strip_edges()
	var answers: Dictionary = runtime_state.get("answers", {}) as Dictionary
	var preferences: Dictionary = runtime_state.get("preferences", {}) as Dictionary
	var session_state: Dictionary = runtime_state.get("session_state", {}) as Dictionary
	return {
		"answers_json": SURVEY_EXPORTER.build_json_text(survey, answers),
		"answers_csv": SURVEY_EXPORTER.build_csv_text(survey, answers),
		"progress_bundle_json": SURVEY_SAVE_BUNDLE.build_json_text(survey, template_path, answers, preferences, session_state)
	}

static func clear_session_file() -> void:
	if FileAccess.file_exists(SESSION_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_STATE_PATH))

static func _checklist_results_payload(session: Dictionary) -> Dictionary:
	var payload := {}
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	for surface_id_variant in surfaces.keys():
		var surface_id := str(surface_id_variant).strip_edges()
		var surface: Dictionary = surfaces.get(surface_id_variant, {}) as Dictionary
		payload[surface_id] = surface.get("checklist_results", {})
	return payload

static func _status_counts(checklist_results: Dictionary) -> Dictionary:
	var counts := {}
	for value in checklist_results.values():
		if not (value is Dictionary):
			continue
		var result: Dictionary = value as Dictionary
		var status := str(result.get("status", "pending")).strip_edges().to_lower()
		counts[status] = int(counts.get(status, 0)) + 1
	return counts

static func _status_summary(counts: Dictionary) -> String:
	var ordered_statuses := ["pass", "fail", "skip", "pending"]
	var parts: Array[String] = []
	for status in ordered_statuses:
		if not counts.has(status):
			continue
		parts.append("%s %d" % [status, int(counts.get(status, 0))])
	return ", ".join(parts)

static func _write_export_payload_entries(writer: ZIPPacker, export_payload: Dictionary) -> Error:
	var answers_json := str(export_payload.get("answers_json", "")).strip_edges()
	if not answers_json.is_empty():
		var write_error := _write_zip_entry(writer, "answers.json", answers_json.to_utf8_buffer())
		if write_error != OK:
			return write_error
	var answers_csv := str(export_payload.get("answers_csv", "")).strip_edges()
	if not answers_csv.is_empty():
		var csv_error := _write_zip_entry(writer, "answers.csv", answers_csv.to_utf8_buffer())
		if csv_error != OK:
			return csv_error
	var progress_bundle_json := str(export_payload.get("progress_bundle_json", "")).strip_edges()
	if not progress_bundle_json.is_empty():
		var progress_error := _write_zip_entry(writer, "progress_bundle.json", progress_bundle_json.to_utf8_buffer())
		if progress_error != OK:
			return progress_error
	return OK

static func _write_capture_entries(writer: ZIPPacker, session: Dictionary) -> Error:
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	for surface_value in surfaces.values():
		if not (surface_value is Dictionary):
			continue
		var surface: Dictionary = surface_value as Dictionary
		var captures: Array = surface.get("captures", []) as Array
		for capture_value in captures:
			if not (capture_value is Dictionary):
				continue
			var capture: Dictionary = capture_value as Dictionary
			var relative_path := str(capture.get("relative_path", "")).strip_edges()
			if relative_path.is_empty():
				continue
			var absolute_path := ProjectSettings.globalize_path(CAPTURE_ROOT_DIR.path_join(relative_path))
			var capture_bytes := FileAccess.get_file_as_bytes(absolute_path)
			if capture_bytes.is_empty():
				continue
			var write_error := _write_zip_entry(writer, "page_captures/%s" % relative_path.replace("\\", "/"), capture_bytes)
			if write_error != OK:
				return write_error
	return OK

static func _write_issue_entries(writer: ZIPPacker, session: Dictionary) -> Error:
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	for surface_id_variant in surfaces.keys():
		var surface_id := str(surface_id_variant).strip_edges()
		var surface: Dictionary = surfaces.get(surface_id_variant, {}) as Dictionary
		var issues: Array = surface.get("issues", []) as Array
		if issues.is_empty():
			continue
		var session_manifest := SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_session_manifest(
			surface_id,
			0,
			str(session.get("started_at", "")).strip_edges(),
			issues.size()
		)
		var report_markdown := SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_report_markdown(session_manifest, issues)
		var bundle_json := SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_bundle_json_text(session_manifest, issues)
		var report_error := _write_zip_entry(writer, "issues/%s/feedback_report.md" % _safe_segment(surface_id), report_markdown.to_utf8_buffer())
		if report_error != OK:
			return report_error
		var bundle_error := _write_zip_entry(writer, "issues/%s/feedback_bundle.json" % _safe_segment(surface_id), bundle_json.to_utf8_buffer())
		if bundle_error != OK:
			return bundle_error
		for issue_value in issues:
			if not (issue_value is Dictionary):
				continue
			var issue: Dictionary = issue_value as Dictionary
			var screenshot: Dictionary = issue.get("screenshot", {}) as Dictionary
			var screenshot_path := str(screenshot.get("file_path", "")).strip_edges()
			var screenshot_buffer: PackedByteArray = issue.get("_screenshot_png", PackedByteArray())
			if screenshot_path.is_empty() or screenshot_buffer.is_empty():
				continue
			var screenshot_error := _write_zip_entry(writer, "issues/%s/%s" % [_safe_segment(surface_id), screenshot_path], screenshot_buffer)
			if screenshot_error != OK:
				return screenshot_error
	return OK

static func _write_zip_entry(writer: ZIPPacker, entry_path: String, buffer: PackedByteArray) -> Error:
	var start_error := writer.start_file(entry_path)
	if start_error != OK:
		return start_error
	var write_error := writer.write_file(buffer)
	var close_error := writer.close_file()
	if write_error != OK:
		return write_error
	return close_error

static func _normalize_session(source: Dictionary) -> Dictionary:
	var session := source.duplicate(true)
	if str(session.get("format", "")).strip_edges().is_empty():
		session["format"] = FORMAT_ID
	if not session.has("version"):
		session["version"] = 1
	if str(session.get("session_id", "")).strip_edges().is_empty():
		session["session_id"] = _safe_segment(Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_"))
	if str(session.get("started_at", "")).strip_edges().is_empty():
		session["started_at"] = Time.get_datetime_string_from_system(true)
	session["updated_at"] = Time.get_datetime_string_from_system(true)
	if not session.has("surfaces"):
		session["surfaces"] = {}
	var normalized_surfaces := {}
	var surfaces_value: Variant = session.get("surfaces", {})
	if surfaces_value is Dictionary:
		for surface_id_variant in (surfaces_value as Dictionary).keys():
			var surface_id := str(surface_id_variant).strip_edges()
			if surface_id.is_empty():
				continue
			var surface_value: Variant = (surfaces_value as Dictionary).get(surface_id_variant, {})
			if surface_value is Dictionary:
				normalized_surfaces[surface_id] = _normalize_surface_state(surface_id, surface_value as Dictionary)
			else:
				normalized_surfaces[surface_id] = _default_surface_state(surface_id)
	session["surfaces"] = normalized_surfaces
	return session

static func _default_surface_state(surface_id: String) -> Dictionary:
	return {
		"surface_id": surface_id.strip_edges(),
		"current_page_node_id": "",
		"checklist_results": {},
		"captures": [],
		"issues": []
	}

static func _normalize_surface_state(surface_id: String, source: Dictionary) -> Dictionary:
	var surface := _default_surface_state(surface_id)
	surface["current_page_node_id"] = str(source.get("current_page_node_id", "")).strip_edges()
	var checklist_results_value: Variant = source.get("checklist_results", {})
	if checklist_results_value is Dictionary:
		surface["checklist_results"] = (checklist_results_value as Dictionary).duplicate(true)
	var captures_value: Variant = source.get("captures", [])
	if captures_value is Array:
		surface["captures"] = (captures_value as Array).duplicate(true)
	var issues_value: Variant = source.get("issues", [])
	if issues_value is Array:
		surface["issues"] = (issues_value as Array).duplicate(true)
	return surface

static func _set_surface_state(session: Dictionary, surface_id: String, surface_state_value: Dictionary) -> void:
	var surfaces: Dictionary = session.get("surfaces", {}) as Dictionary
	surfaces[surface_id.strip_edges()] = _normalize_surface_state(surface_id, surface_state_value)
	session["surfaces"] = surfaces
	session["updated_at"] = Time.get_datetime_string_from_system(true)

static func _sanitize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var resolved: Dictionary = {}
			var source := value as Dictionary
			for key_variant in source.keys():
				var key := str(key_variant).strip_edges()
				if key.is_empty():
					continue
				resolved[key] = _sanitize_variant(source.get(key_variant))
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

static func _safe_segment(raw_value: String) -> String:
	var value := raw_value.strip_edges().to_lower()
	if value.is_empty():
		return "qa"
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	return value.trim_prefix("_").trim_suffix("_")
