@tool
extends RefCounted
class_name SeaShellFeedbackSessionStore

const DEFAULT_DEV_VAULT_ROOT := "user://sea_shell_feedback_devlog"

var dev_vault_root := DEFAULT_DEV_VAULT_ROOT
var session_folder := "Devlog/Sessions"
var attachment_folder := "Devlog/Attachments"
var require_explicit_dev_vault := false
var default_dev_vault_root := DEFAULT_DEV_VAULT_ROOT
var frontmatter_prefix := "SS"
var note_kind := "feedback-session"
var _session := {}
var _entries: Array = []

func configure(root_path: String, sessions_path: String, attachments_path: String, options: Dictionary = {}) -> void:
	require_explicit_dev_vault = bool(options.get("require_explicit_dev_vault", false))
	default_dev_vault_root = String(options.get("default_dev_vault_root", DEFAULT_DEV_VAULT_ROOT)).strip_edges()
	frontmatter_prefix = _sanitize_frontmatter_prefix(String(options.get("frontmatter_prefix", "SS")))
	note_kind = String(options.get("note_kind", "feedback-session")).strip_edges()
	if note_kind.is_empty():
		note_kind = "feedback-session"
	var resolved_root := root_path.strip_edges()
	if resolved_root.is_empty() and not require_explicit_dev_vault:
		resolved_root = default_dev_vault_root
	dev_vault_root = resolved_root
	if not sessions_path.strip_edges().is_empty():
		session_folder = sessions_path
	if not attachments_path.strip_edges().is_empty():
		attachment_folder = attachments_path

func ensure_session() -> Dictionary:
	var validation := _validate_dev_vault_root()
	if not bool(validation.get("ok", false)):
		return validation
	if not _session.is_empty():
		_session["feedback_count"] = _entries.size()
		_session["attachment_paths"] = _get_attachment_paths()
		return _session.duplicate(true)
	var created_unix := Time.get_unix_time_from_system()
	var local_stamp := Time.get_datetime_string_from_unix_time(created_unix, false).replace(":", "-")
	var date_folder := local_stamp.substr(0, 10)
	var session_id := "feedback-%s-%s" % [local_stamp.replace("T", "-"), Time.get_ticks_msec()]
	var root := _globalize(dev_vault_root)
	var session_dir := root.path_join(session_folder).path_join(date_folder)
	DirAccess.make_dir_recursive_absolute(session_dir)
	_session = {
		"ok": true,
		"session_id": session_id,
		"created_unix": created_unix,
		"dev_vault_root": root,
		"session_note_relative_path": session_folder.path_join(date_folder).path_join("%s.md" % session_id),
		"session_note_absolute_path": session_dir.path_join("%s.md" % session_id),
		"feedback_count": 0,
		"attachment_paths": [],
	}
	_write_session_note()
	return _session.duplicate(true)

func save_feedback(request: Dictionary) -> Dictionary:
	var session_result := ensure_session()
	if not bool(session_result.get("ok", false)):
		return session_result
	var entry_index := _entries.size() + 1
	var attachments := _copy_attachments(request, entry_index)
	var context: Dictionary = Dictionary(request.get("context", {})).duplicate(true)
	var feedback_text := String(request.get("feedback_text", "")).strip_edges()
	if feedback_text.is_empty():
		feedback_text = "No feedback text entered."
	var entry := {
		"entry_id": "entry-%s-%s" % [entry_index, Time.get_ticks_msec()],
		"created_unix": Time.get_unix_time_from_system(),
		"heading": _build_entry_heading(feedback_text, entry_index),
		"feedback_text": feedback_text,
		"context": context,
		"attachments": attachments,
		"screenshot_failure_message": String(request.get("screenshot_failure_message", context.get("screenshot_failure_message", ""))),
	}
	_entries.append(entry)
	_session["feedback_count"] = _entries.size()
	_session["attachment_paths"] = _get_attachment_paths()
	_write_session_note()
	return {"ok": true, "message": "Saved Sea Shell feedback to %s." % _session.get("session_note_relative_path", ""), "session": _session.duplicate(true), "entry": entry.duplicate(true)}

func export_session_prompt() -> Dictionary:
	var session_result := ensure_session()
	if not bool(session_result.get("ok", false)):
		return session_result
	_write_session_note()
	return {"ok": true, "prompt_markdown": _build_codex_prompt(), "session": _session.duplicate(true), "message": "Exported Sea Shell feedback prompt."}

func get_session_snapshot() -> Dictionary:
	ensure_session()
	return _session.duplicate(true)

func get_entries() -> Array:
	return _entries.duplicate(true)

func _copy_attachments(request: Dictionary, entry_index: int) -> Array:
	var copied := []
	var paths := PackedStringArray()
	for key in ["screenshot_source_path", "recording_source_path", "file_attachment_source_path"]:
		var path := String(request.get(key, "")).strip_edges()
		if not path.is_empty():
			paths.append(path)
	for raw_path in request.get("attachment_paths", PackedStringArray()):
		var path := String(raw_path).strip_edges()
		if not path.is_empty():
			paths.append(path)
	for index in range(paths.size()):
		var copied_record := _copy_attachment(paths[index], entry_index, index + 1)
		if not copied_record.is_empty():
			copied.append(copied_record)
	return copied

func _copy_attachment(source_path: String, entry_index: int, attachment_index: int) -> Dictionary:
	var absolute_source := _globalize(source_path)
	if not FileAccess.file_exists(absolute_source):
		return {}
	var bytes := FileAccess.get_file_as_bytes(absolute_source)
	if bytes.is_empty():
		return {}
	var source_file := absolute_source.get_file()
	var extension := source_file.get_extension()
	var stem := "entry-%02d-%02d" % [entry_index, attachment_index]
	var file_name := "%s.%s" % [stem, extension] if not extension.is_empty() else stem
	var attachment_dir := _build_attachment_dir()
	DirAccess.make_dir_recursive_absolute(attachment_dir)
	var destination := attachment_dir.path_join(file_name)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return {}
	file.store_buffer(bytes)
	var relative_path := _relative_to_root(destination)
	return {"kind": _guess_attachment_kind(extension), "display_name": source_file, "relative_path": relative_path, "absolute_path": destination, "original_source_path": absolute_source}

func _write_session_note() -> void:
	if _session.is_empty():
		return
	var path := String(_session.get("session_note_absolute_path", ""))
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(_build_session_markdown())

func _build_session_markdown() -> String:
	var lines := PackedStringArray()
	var prefix := frontmatter_prefix
	lines.append("---")
	lines.append("note_kind_%s: %s" % [prefix, JSON.stringify(note_kind)])
	lines.append("session_id_%s: %s" % [prefix, JSON.stringify(_session.get("session_id", ""))])
	lines.append("created_unix_%s: %s" % [prefix, int(_session.get("created_unix", 0))])
	lines.append("entry_count_%s: %s" % [prefix, _entries.size()])
	lines.append("attachment_paths_%s: %s" % [prefix, JSON.stringify(_get_attachment_paths())])
	lines.append("---")
	lines.append("")
	lines.append("# Sea Shell Feedback Session")
	lines.append("")
	lines.append("## Session Summary")
	lines.append("")
	lines.append("- Session ID: `%s`" % _session.get("session_id", ""))
	lines.append("- Dev Vault Root: `%s`" % _session.get("dev_vault_root", ""))
	lines.append("- Session Note: `%s`" % _session.get("session_note_relative_path", ""))
	lines.append("- Feedback Count: `%d`" % _entries.size())
	var latest_entry: Dictionary = _entries.back() if not _entries.is_empty() else {}
	if not latest_entry.is_empty():
		var latest_context: Dictionary = latest_entry.get("context", {})
		lines.append("- Latest Surface: `%s`" % latest_context.get("surface_id", ""))
		lines.append("- Latest Activity: %s" % _inline_text(String(latest_context.get("latest_session_status", ""))))
	lines.append("")
	lines.append("## Feedback Entries")
	lines.append("")
	if _entries.is_empty():
		lines.append("No feedback entries saved yet.")
	else:
		for entry in _entries:
			_append_entry_markdown(lines, entry)
	lines.append("")
	lines.append("## Codex Prompt")
	lines.append("")
	lines.append(_build_codex_prompt())
	lines.append("")
	return "\n".join(lines)

func _append_entry_markdown(lines: PackedStringArray, entry: Dictionary) -> void:
	lines.append("### %s" % entry.get("heading", "Feedback"))
	lines.append("")
	lines.append(String(entry.get("feedback_text", "")))
	lines.append("")
	var context: Dictionary = entry.get("context", {})
	lines.append("Context:")
	lines.append("- Captured: `%s`" % context.get("local_timestamp", ""))
	lines.append("- Event: `%s`" % context.get("event_id", ""))
	lines.append("- Screen Position: `(%s, %s)`" % [context.get("screen_x", 0), context.get("screen_y", 0)])
	lines.append("- Window Position: `(%s, %s)`" % [context.get("window_x", 0), context.get("window_y", 0)])
	lines.append("- Target Path: `%s`" % context.get("target_path", ""))
	lines.append("- Control Type: `%s`" % context.get("control_type", ""))
	lines.append("- Surface: `%s`" % context.get("surface_id", ""))
	lines.append("- Layer: `%s`" % String(Dictionary(context.get("layer", {})).get("name", "")))
	if context.has("top_level_tab"):
		lines.append("- Top-Level Tab: `%s`" % context.get("top_level_tab", ""))
	if context.has("current_note_path"):
		lines.append("- Bound Note: `%s`" % context.get("current_note_path", ""))
	if context.has("navigation_target"):
		lines.append("- Navigation Target: `%s`" % JSON.stringify(context.get("navigation_target", {})))
	if context.has("dashboard_vault_name") or context.has("dashboard_vault_id"):
		lines.append("- Dashboard Vault: `%s`" % String(context.get("dashboard_vault_name", context.get("dashboard_vault_id", ""))))
	if context.has("dashboard_vault_root"):
		lines.append("- Dashboard Vault Root: `%s`" % context.get("dashboard_vault_root", ""))
	lines.append("- Hovered Text: %s" % _inline_text(String(context.get("display_text", ""))))
	lines.append("- Tooltip: %s" % _inline_text(String(context.get("tooltip_text", ""))))
	if context.has("menu_path") and not String(context.get("menu_path", "")).is_empty():
		lines.append("- Hovered Menu Path: `%s`" % context.get("menu_path", ""))
	if context.has("latest_session_status"):
		lines.append("- Latest Activity: %s" % _inline_text(String(context.get("latest_session_status", ""))))
	if context.has("is_obs_recording"):
		lines.append("- OBS Recording: `%s`" % ("yes" if bool(context.get("is_obs_recording", false)) else "no"))
	if context.has("recent_actions"):
		lines.append("")
		lines.append("Recent Actions:")
		var recent_actions: Array = context.get("recent_actions", [])
		if recent_actions.is_empty():
			lines.append("- No recent actions were captured.")
		else:
			for action in recent_actions:
				lines.append("- %s" % String(action))
	var screenshot_failure := String(entry.get("screenshot_failure_message", "")).strip_edges()
	if not screenshot_failure.is_empty():
		lines.append("- Screenshot Failure: %s" % _inline_text(screenshot_failure))
	var attachments: Array = entry.get("attachments", [])
	if not attachments.is_empty():
		lines.append("")
		lines.append("Attachments:")
		for attachment in attachments:
			lines.append("- %s: [[%s]] (%s)" % [String(attachment.get("kind", "file")).capitalize(), attachment.get("relative_path", ""), attachment.get("display_name", "")])
	lines.append("")
	lines.append("---")
	lines.append("")

func _build_codex_prompt() -> String:
	var lines := PackedStringArray()
	lines.append("Use this Sea Shell feedback session as implementation context.")
	lines.append("")
	lines.append("Session:")
	lines.append("- Dev Vault Root: `%s`" % _session.get("dev_vault_root", ""))
	lines.append("- Session Note: `%s`" % _session.get("session_note_relative_path", ""))
	lines.append("- Feedback Count: `%d`" % _entries.size())
	var attachment_paths := _get_attachment_paths()
	if not attachment_paths.is_empty():
		lines.append("- Attachment Paths: %s" % ", ".join(attachment_paths))
	lines.append("")
	lines.append("Feedback Summary:")
	if _entries.is_empty():
		lines.append("- No feedback entries captured yet.")
	else:
		for index in range(_entries.size()):
			var entry: Dictionary = _entries[index]
			var context: Dictionary = entry.get("context", {})
			lines.append("%d. %s" % [index + 1, entry.get("heading", "Feedback")])
			lines.append("   Note: %s" % String(entry.get("feedback_text", "")).replace("\n", " ").strip_edges())
			lines.append("   Context: event=`%s`, target=`%s`, surface=`%s`, control=`%s`" % [context.get("event_id", ""), context.get("target_path", ""), context.get("surface_id", ""), context.get("control_type", "")])
			if context.has("top_level_tab") or context.has("current_note_path"):
				lines.append("   Navigation: tab=`%s`, note=`%s`" % [context.get("top_level_tab", ""), context.get("current_note_path", "")])
	return "\n".join(lines)

func _build_entry_heading(text: String, entry_index: int) -> String:
	var first_line := text.split("\n", false)[0].strip_edges()
	if first_line.length() > 56:
		first_line = first_line.substr(0, 53) + "..."
	return "Feedback %02d - %s" % [entry_index, first_line]

func _build_attachment_dir() -> String:
	var session := ensure_session()
	var date_folder := Time.get_datetime_string_from_unix_time(int(session.get("created_unix", 0)), false).substr(0, 10)
	return String(session.get("dev_vault_root", "")).path_join(attachment_folder).path_join(date_folder).path_join(String(session.get("session_id", "")))

func _get_attachment_paths() -> Array:
	var result := []
	for entry in _entries:
		for attachment in Dictionary(entry).get("attachments", []):
			result.append(String(Dictionary(attachment).get("relative_path", "")))
	return result

func _validate_dev_vault_root() -> Dictionary:
	var root := dev_vault_root.strip_edges()
	if root.is_empty():
		return {"ok": false, "error": "Choose a feedback dev vault before saving feedback."}
	if require_explicit_dev_vault and root == default_dev_vault_root:
		return {"ok": false, "error": "Choose an explicit feedback dev vault before saving feedback."}
	return {"ok": true}

func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _relative_to_root(path: String) -> String:
	var root := String(_session.get("dev_vault_root", ""))
	if not root.is_empty() and path.begins_with(root):
		return path.trim_prefix(root).trim_prefix("/").trim_prefix("\\").replace("\\", "/")
	return path.replace("\\", "/")

func _guess_attachment_kind(extension: String) -> String:
	var normalized := extension.to_lower()
	if ["png", "jpg", "jpeg", "webp"].has(normalized):
		return "screenshot"
	if ["mp4", "mov", "mkv", "webm"].has(normalized):
		return "recording"
	return "file"

func _sanitize_frontmatter_prefix(raw: String) -> String:
	var result := raw.strip_edges()
	if result.is_empty():
		return "SS"
	for character in [" ", "-", ".", "/", "\\"]:
		result = result.replace(character, "_")
	return result

func _inline_text(text: String) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	return "`%s`" % normalized if not normalized.is_empty() else "``"
