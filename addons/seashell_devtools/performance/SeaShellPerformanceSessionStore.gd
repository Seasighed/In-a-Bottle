@tool
extends RefCounted
class_name SeaShellPerformanceSessionStore

const DEFAULT_SESSION_ROOT := "user://sea_shell_performance"
const TEST_RUN_POINTER_PATH := "res://.godot/sea_shell_test_runs/latest-run.json"

var session_root := DEFAULT_SESSION_ROOT
var _session := {}
var _last_state := {}
var _copied_screenshot_paths: Dictionary = {}

func configure(root_path: String) -> void:
	var resolved_root := root_path.strip_edges()
	session_root = resolved_root if not resolved_root.is_empty() else DEFAULT_SESSION_ROOT

func ensure_session() -> Dictionary:
	if not _session.is_empty():
		return _session.duplicate(true)
	var created_unix := Time.get_unix_time_from_system()
	var created_local := Time.get_datetime_string_from_unix_time(created_unix, false)
	var session_id := "perf-%s-%s" % [created_local.replace(":", "-").replace("T", "-"), Time.get_ticks_msec()]
	var date_folder := created_local.substr(0, 10)
	var absolute_root := ProjectSettings.globalize_path(session_root).path_join("sessions").path_join(date_folder).path_join(session_id)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	_session = {
		"ok": true,
		"session_id": session_id,
		"created_unix": created_unix,
		"session_root": absolute_root,
		"manifest_absolute_path": absolute_root.path_join("manifest.json"),
		"frames_absolute_path": absolute_root.path_join("frames.jsonl"),
		"metrics_schema_absolute_path": absolute_root.path_join("metrics_schema.json"),
		"summary_absolute_path": absolute_root.path_join("summary.md"),
		"capture_context_absolute_path": absolute_root.path_join("capture_context.json"),
		"screenshot_root": absolute_root.path_join("screenshots"),
		"attachment_paths": PackedStringArray(),
	}
	return _session.duplicate(true)

func save_session(state: Dictionary) -> Dictionary:
	var session := ensure_session()
	_last_state = state.duplicate(true)
	var frames: Array = Array(state.get("frames", [])).duplicate(true)
	var metrics_schema: Dictionary = Dictionary(state.get("metrics_schema", {})).duplicate(true)
	var raw_captures: Array = Array(state.get("capture_records", [])).duplicate(true)
	var captures := _materialize_capture_records(raw_captures)
	var manifest := _build_manifest(state, captures, frames)
	_write_json(String(session.get("manifest_absolute_path", "")), manifest)
	_write_jsonl(String(session.get("frames_absolute_path", "")), frames)
	_write_json(String(session.get("metrics_schema_absolute_path", "")), metrics_schema)
	_write_summary_markdown(String(session.get("summary_absolute_path", "")), manifest, state)
	var latest_capture := captures.back() as Dictionary if not captures.is_empty() else {}
	if latest_capture.is_empty():
		_clear_file(String(session.get("capture_context_absolute_path", "")))
	else:
		_write_json(String(session.get("capture_context_absolute_path", "")), Dictionary(latest_capture.get("context", {})).duplicate(true))
	var attachments := PackedStringArray([
		String(session.get("manifest_absolute_path", "")),
		String(session.get("frames_absolute_path", "")),
		String(session.get("metrics_schema_absolute_path", "")),
		String(session.get("summary_absolute_path", "")),
	])
	if FileAccess.file_exists(String(session.get("capture_context_absolute_path", ""))):
		attachments.append(String(session.get("capture_context_absolute_path", "")))
	for capture in captures:
		var screenshot_path := String(Dictionary(capture).get("screenshot_absolute_path", "")).strip_edges()
		if not screenshot_path.is_empty() and FileAccess.file_exists(screenshot_path) and not attachments.has(screenshot_path):
			attachments.append(screenshot_path)
	_session["attachment_paths"] = attachments
	return {
		"ok": true,
		"session": _session.duplicate(true),
		"manifest": manifest,
		"capture_records": captures,
		"attachment_paths": attachments,
	}

func export_session_prompt() -> Dictionary:
	var session := ensure_session()
	return {
		"ok": true,
		"prompt_markdown": _build_codex_prompt(_last_state),
		"session": session,
	}

func get_session_snapshot() -> Dictionary:
	return _session.duplicate(true)

func _materialize_capture_records(raw_captures: Array) -> Array:
	var result := []
	for raw_capture in raw_captures:
		var capture: Dictionary = Dictionary(raw_capture).duplicate(true)
		var screenshot_source_path := String(capture.get("screenshot_source_path", "")).strip_edges()
		if not screenshot_source_path.is_empty():
			var copied := _copy_screenshot(capture, screenshot_source_path)
			if not copied.is_empty():
				capture["screenshot_absolute_path"] = String(copied.get("absolute_path", ""))
				capture["screenshot_relative_path"] = String(copied.get("relative_path", ""))
		result.append(capture)
	return result

func _copy_screenshot(capture: Dictionary, source_path: String) -> Dictionary:
	var capture_id := String(capture.get("capture_id", "capture"))
	if _copied_screenshot_paths.has(capture_id):
		return _copied_screenshot_paths[capture_id]
	var absolute_source := ProjectSettings.globalize_path(source_path)
	if not FileAccess.file_exists(absolute_source):
		return {}
	var bytes := FileAccess.get_file_as_bytes(absolute_source)
	if bytes.is_empty():
		return {}
	var extension := absolute_source.get_extension()
	var file_name := "%s.%s" % [capture_id, extension] if not extension.is_empty() else capture_id
	var session := ensure_session()
	var screenshot_root := String(session.get("screenshot_root", ""))
	DirAccess.make_dir_recursive_absolute(screenshot_root)
	var destination := screenshot_root.path_join(file_name)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return {}
	file.store_buffer(bytes)
	var copied := {
		"absolute_path": destination,
		"relative_path": _relative_to_session(destination),
	}
	_copied_screenshot_paths[capture_id] = copied
	return copied

func _build_manifest(state: Dictionary, captures: Array, frames: Array) -> Dictionary:
	var session := ensure_session()
	var last_frame: Dictionary = Dictionary(state.get("last_frame", {})).duplicate(true)
	var max_frame_time_ms := 0.0
	for frame in frames:
		max_frame_time_ms = maxf(max_frame_time_ms, float(Dictionary(frame).get("frame_time_ms", 0.0)))
	return {
		"format": "SeaShellPerformanceSession",
		"version": 1,
		"session_id": String(session.get("session_id", "")),
		"created_unix": int(session.get("created_unix", 0)),
		"capture_mode": String(state.get("capture_mode", "")),
		"run_started_usec": int(state.get("run_started_usec", 0)),
		"run_updated_usec": Time.get_ticks_usec(),
		"saved_frame_count": frames.size(),
		"capture_count": captures.size(),
		"max_frame_time_ms": max_frame_time_ms,
		"latest_scene_file_path": String(last_frame.get("scene_file_path", "")),
		"latest_hovered_control_path": String(last_frame.get("hovered_control_path", "")),
		"capture_records": captures,
		"files": {
			"manifest": String(session.get("manifest_absolute_path", "")),
			"frames": String(session.get("frames_absolute_path", "")),
			"metrics_schema": String(session.get("metrics_schema_absolute_path", "")),
			"summary": String(session.get("summary_absolute_path", "")),
			"capture_context": String(session.get("capture_context_absolute_path", "")),
		},
	}

func _write_summary_markdown(path: String, manifest: Dictionary, state: Dictionary) -> void:
	var lines := PackedStringArray()
	var latest_test_run := _load_latest_test_run_bundle()
	lines.append("# Sea Shell Performance Session")
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("- Session ID: `%s`" % String(manifest.get("session_id", "")))
	lines.append("- Mode: `%s`" % String(manifest.get("capture_mode", "")))
	lines.append("- Frames Saved: `%d`" % int(manifest.get("saved_frame_count", 0)))
	lines.append("- Captures: `%d`" % int(manifest.get("capture_count", 0)))
	lines.append("- Max Frame Time: `%.2f ms`" % float(manifest.get("max_frame_time_ms", 0.0)))
	lines.append("- Session Root: `%s`" % String(ensure_session().get("session_root", "")))
	lines.append("")
	lines.append("## Captures")
	lines.append("")
	var captures: Array = Array(manifest.get("capture_records", []))
	if captures.is_empty():
		lines.append("No capture windows were saved.")
	else:
		for capture in captures:
			var record: Dictionary = Dictionary(capture)
			lines.append("### %s" % String(record.get("label", record.get("capture_id", "Capture"))))
			lines.append("")
			lines.append("- Reason: `%s`" % String(record.get("reason", "")))
			lines.append("- Trigger Frame: `%d`" % int(record.get("trigger_frame_index", 0)))
			lines.append("- Frame Count: `%d`" % int(record.get("frame_count", 0)))
			lines.append("- Max Frame Time: `%.2f ms`" % float(record.get("max_frame_time_ms", 0.0)))
			lines.append("- Scene: `%s`" % String(record.get("scene_file_path", "")))
			var screenshot_path := String(record.get("screenshot_relative_path", ""))
			if not screenshot_path.is_empty():
				lines.append("- Screenshot: [[%s]]" % screenshot_path)
			lines.append("")
	lines.append("## Latest Test Run")
	lines.append("")
	_append_latest_test_run_lines(lines, latest_test_run)
	lines.append("## Codex Prompt")
	lines.append("")
	lines.append(_build_codex_prompt(state))
	lines.append("")
	_write_text(path, "\n".join(lines))

func _build_codex_prompt(state: Dictionary) -> String:
	var session := ensure_session()
	var latest_test_run := _load_latest_test_run_bundle()
	var lines := PackedStringArray()
	lines.append("Use this Sea Shell performance session as profiling context.")
	lines.append("")
	lines.append("Artifacts:")
	lines.append("- Manifest: `%s`" % String(session.get("manifest_absolute_path", "")))
	lines.append("- Frames: `%s`" % String(session.get("frames_absolute_path", "")))
	lines.append("- Metrics Schema: `%s`" % String(session.get("metrics_schema_absolute_path", "")))
	lines.append("- Summary: `%s`" % String(session.get("summary_absolute_path", "")))
	lines.append("")
	lines.append("Session:")
	lines.append("- Mode: `%s`" % String(state.get("capture_mode", "")))
	lines.append("- Captures: `%d`" % Array(state.get("capture_records", [])).size())
	var last_frame: Dictionary = Dictionary(state.get("last_frame", {})).duplicate(true)
	if not last_frame.is_empty():
		lines.append("- Latest Scene: `%s`" % String(last_frame.get("scene_file_path", "")))
		lines.append("- Latest Hovered Control: `%s`" % String(last_frame.get("hovered_control_path", "")))
		lines.append("- Latest Frame Time: `%.2f ms`" % float(last_frame.get("frame_time_ms", 0.0)))
	lines.append("")
	lines.append("Latest Test Run:")
	_append_latest_test_run_lines(lines, latest_test_run, "- ")
	lines.append("")
	lines.append("Review goals:")
	lines.append("- Identify spikes, repeated high-cost spans, and suspicious custom metrics.")
	lines.append("- Correlate frame windows with scene, hovered UI, layer context, and recent feedback events when present.")
	lines.append("- Recommend concrete instrumentation or code-path follow-up based on the saved capture windows.")
	return "\n".join(lines)

func _load_latest_test_run_bundle() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(TEST_RUN_POINTER_PATH)
	if not FileAccess.file_exists(absolute_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute_path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _append_latest_test_run_lines(lines: PackedStringArray, latest_test_run: Dictionary, bullet_prefix := "") -> void:
	var prefix := bullet_prefix if not bullet_prefix.is_empty() else "- "
	var child_prefix := "  - "
	if latest_test_run.is_empty():
		lines.append("%sNo canonical Sea Shell test run bundle was linked." % prefix)
		return
	lines.append("%sRun ID: `%s`" % [prefix, String(latest_test_run.get("run_id", ""))])
	lines.append("%sManifest: `%s`" % [prefix, String(latest_test_run.get("manifest_absolute_path", ""))])
	lines.append("%sSummary: `%s`" % [prefix, String(latest_test_run.get("summary_absolute_path", ""))])
	var logs: Dictionary = Dictionary(latest_test_run.get("suite_logs", {})).duplicate(true)
	if logs.is_empty():
		lines.append("%sSuite Logs: none recorded" % prefix)
		return
	var suite_ids := PackedStringArray()
	for suite_id in logs.keys():
		suite_ids.append(String(suite_id))
	suite_ids.sort()
	lines.append("%sSuite Logs:" % prefix)
	for suite_id in suite_ids:
		lines.append("%s`%s`: `%s`" % [child_prefix, suite_id, String(logs.get(suite_id, ""))])

func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t"))

func _write_jsonl(path: String, rows: Array) -> void:
	var lines := PackedStringArray()
	for row in rows:
		lines.append(JSON.stringify(row))
	_write_text(path, "\n".join(lines))

func _write_text(path: String, text: String) -> void:
	var absolute_path := path.strip_edges()
	if absolute_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)

func _clear_file(path: String) -> void:
	var absolute_path := path.strip_edges()
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return
	DirAccess.remove_absolute(absolute_path)

func _relative_to_session(path: String) -> String:
	var session_root_path := String(ensure_session().get("session_root", ""))
	if path.begins_with(session_root_path):
		return path.trim_prefix(session_root_path).trim_prefix("\\").trim_prefix("/")
	return path.get_file()
