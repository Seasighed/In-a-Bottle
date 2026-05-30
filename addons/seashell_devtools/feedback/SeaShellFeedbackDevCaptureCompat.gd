@tool
extends RefCounted
class_name SeaShellFeedbackDevCaptureCompat

static func ensure_session(options: Dictionary = {}) -> Dictionary:
	_apply_options(options)
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("ensure_dev_session"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("ensure_dev_session")

static func begin_capture(request: Dictionary = {}) -> Dictionary:
	_apply_options(request)
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("begin_dev_capture_request"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("begin_dev_capture_request", request)

static func save_feedback(request: Dictionary = {}) -> Dictionary:
	_apply_options(request)
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("save_dev_feedback_request"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("save_dev_feedback_request", request)

static func export_session_prompt(options: Dictionary = {}) -> Dictionary:
	_apply_options(options)
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("export_session_prompt"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("export_session_prompt")

static func get_session_snapshot() -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("get_session_snapshot"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("get_session_snapshot")

static func set_capture_armed(armed: bool) -> void:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("set_dev_capture_armed"):
		feedback.call("set_dev_capture_armed", armed)

static func is_capture_armed() -> bool:
	var feedback := _feedback()
	if feedback != null and feedback.has_method("is_dev_capture_armed"):
		return bool(feedback.call("is_dev_capture_armed"))
	return false

static func stage_viewport_screenshot() -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("stage_viewport_screenshot"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("stage_viewport_screenshot")

static func collect_evidence(context: Dictionary = {}) -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("collect_evidence"):
		return {"attachment_paths": PackedStringArray(), "recording_source_path": "", "file_attachment_source_path": ""}
	return feedback.call("collect_evidence", context)

static func _apply_options(options: Dictionary) -> void:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("set_setting_value"):
		return
	if options.has("dev_vault_root"):
		feedback.call("set_setting_value", "SeaShell.Feedback.DevVaultRoot", String(options.get("dev_vault_root", "")))
	if options.has("session_folder"):
		feedback.call("set_setting_value", "SeaShell.Feedback.SessionFolder", String(options.get("session_folder", "")))
	if options.has("attachment_folder"):
		feedback.call("set_setting_value", "SeaShell.Feedback.AttachmentFolder", String(options.get("attachment_folder", "")))
	if options.has("require_explicit_dev_vault"):
		feedback.call("set_setting_value", "SeaShell.Feedback.RequireExplicitDevVault", bool(options.get("require_explicit_dev_vault", false)))
	if options.has("frontmatter_prefix"):
		feedback.call("set_setting_value", "SeaShell.Feedback.FrontmatterPrefix", String(options.get("frontmatter_prefix", "")))
	if options.has("note_kind"):
		feedback.call("set_setting_value", "SeaShell.Feedback.NoteKind", String(options.get("note_kind", "")))

static func _feedback() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SeaShellFeedback")
