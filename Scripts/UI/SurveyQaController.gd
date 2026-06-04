class_name SurveyQaController
extends Node

const SURVEY_QA_OVERLAY = preload("res://Scripts/UI/SurveyQaOverlay.gd")
const SURVEY_QA_CHECKLIST_CATALOG = preload("res://Scripts/QA/SurveyQaChecklistCatalog.gd")
const SURVEY_QA_SESSION_SUPPORT = preload("res://Scripts/QA/SurveyQaSessionSupport.gd")
const SURVEY_VISUAL_AUDIT_RUNNER = preload("res://Scripts/Tools/SurveyVisualAuditRunner.gd")
const QUESTION_TYPE_GALLERY_SCENE = preload("res://Scenes/UI/QuestionTypeGallery.tscn")

signal status_requested(message: String, is_error: bool)

var _root_control: Control
var _surface_id := ""
var _page_context_provider: Callable = Callable()
var _runtime_state_provider: Callable = Callable()
var _qa_action_callback: Callable = Callable()
var _status_callback: Callable = Callable()
var _download_callback: Callable = Callable()
var _share_callback: Callable = Callable()
var _share_supported_callback: Callable = Callable()
var _switch_surface_callback: Callable = Callable()
var _feedback_controller
var _overlay: SurveyQaOverlay
var _session: Dictionary = {}
var _selected_page_node_id := ""
var _auto_open_pending := false
var _question_gallery_overlay: CanvasLayer
var _question_gallery_panel: PanelContainer
var _question_gallery_close_button: Button
var _visual_audit_runner: SurveyVisualAuditRunner

func configure(root_control: Control, surface_id: String, page_context_provider: Callable, runtime_state_provider: Callable, qa_action_callback: Callable, status_callback: Callable, download_callback: Callable, share_callback: Callable = Callable(), share_supported_callback: Callable = Callable(), feedback_controller = null, switch_surface_callback: Callable = Callable()) -> void:
	_root_control = root_control
	_surface_id = surface_id.strip_edges()
	_page_context_provider = page_context_provider
	_runtime_state_provider = runtime_state_provider
	_qa_action_callback = qa_action_callback
	_status_callback = status_callback
	_download_callback = download_callback
	_share_callback = share_callback
	_share_supported_callback = share_supported_callback
	_feedback_controller = feedback_controller
	_switch_surface_callback = switch_surface_callback
	_session = SURVEY_QA_SESSION_SUPPORT.ensure_session(_surface_id, SURVEY_QA_CHECKLIST_CATALOG.default_template_path())
	_sync_feedback_snapshot()
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
	_ensure_overlay()
	_ensure_question_gallery_overlay()
	_ensure_visual_audit_runner()
	refresh_layout(_viewport_size())

func refresh_layout(viewport_size: Vector2) -> void:
	if _overlay != null:
		_overlay.refresh_layout(viewport_size)
	if _question_gallery_overlay != null:
		_layout_question_gallery(viewport_size)

func open_home() -> void:
	if _overlay == null:
		return
	_sync_feedback_snapshot()
	_overlay.open_home(_build_home_state())

func open_tutorial() -> void:
	if _overlay == null:
		return
	_overlay.open_tutorial(_build_tutorial_state())

func open_checklist(selected_page_node_id: String = "") -> void:
	if _overlay == null:
		return
	var resolved_page_node_id := selected_page_node_id.strip_edges()
	if resolved_page_node_id.is_empty():
		resolved_page_node_id = _current_page_node_id()
	if resolved_page_node_id.is_empty():
		var page_ids: Array[String] = SURVEY_QA_CHECKLIST_CATALOG.page_ids_for_surface(_surface_id)
		resolved_page_node_id = page_ids[0] if not page_ids.is_empty() else ""
	_selected_page_node_id = resolved_page_node_id
	_overlay.open_checklist(_build_checklist_state())

func show_intro_if_needed() -> void:
	if _auto_open_pending:
		return
	_auto_open_pending = true
	call_deferred("_show_intro_after_frame")

func capture_current_page(reason: String = "manual", item_id: String = "", result_status: String = "") -> Dictionary:
	if _root_control == null:
		return {}
	var viewport: Viewport = _root_control.get_viewport()
	if viewport == null or viewport.get_texture() == null:
		_emit_status("QA capture is unavailable in this build.", true)
		return {}
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_emit_status("The current surface did not produce a capture image.", true)
		return {}
	var page_node_id := _current_page_node_id()
	var paths := SURVEY_QA_SESSION_SUPPORT.build_capture_paths(str(_session.get("session_id", "")), _surface_id, page_node_id, reason)
	if paths.is_empty():
		_emit_status("Unable to prepare the QA capture folder.", true)
		return {}
	var absolute_path := str(paths.get("absolute_path", "")).strip_edges()
	if image.save_png(absolute_path) != OK:
		_emit_status("Failed to save the QA capture image.", true)
		return {}
	var capture_entry := {
		"id": "%s_%s" % [_surface_id, Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")],
		"surface_id": _surface_id,
		"page_node_id": page_node_id,
		"captured_at": Time.get_datetime_string_from_system(true),
		"reason": reason.strip_edges(),
		"item_id": item_id.strip_edges(),
		"result_status": result_status.strip_edges(),
		"absolute_path": absolute_path,
		"relative_path": str(paths.get("relative_path", "")).strip_edges()
	}
	_session = SURVEY_QA_SESSION_SUPPORT.record_capture(_session, _surface_id, capture_entry)
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
	_emit_status("Captured %s for the QA bundle." % page_node_id.replace("_", " "), false)
	_refresh_overlay()
	return capture_entry

func export_bundle() -> void:
	_sync_feedback_snapshot()
	var runtime_state := _runtime_state()
	var export_payload := SURVEY_QA_SESSION_SUPPORT.build_export_payload(runtime_state)
	var environment := _environment_payload(runtime_state)
	var bundle := SURVEY_QA_SESSION_SUPPORT.build_zip_export(_session, _surface_id, environment, export_payload)
	if not bool(bundle.get("ok", false)):
		_emit_status(str(bundle.get("message", "Unable to build the QA bundle.")), true)
		return
	if not _download_callback.is_valid():
		_emit_status("QA bundle downloads are unavailable in this build.", true)
		return
	var started := bool(_download_callback.call(
		bundle.get("buffer", PackedByteArray()),
		str(bundle.get("file_name", "survey_qa_bundle.zip")),
		"QA bundle export started."
	))
	if not started:
		_emit_status("Unable to start the QA bundle export.", true)
		return
	_emit_status("QA bundle export started.", false)

func export_visual_audit() -> void:
	if _download_callback.is_valid() == false:
		_emit_status("Visual audit downloads are unavailable in this build.", true)
		return
	_ensure_visual_audit_runner()
	_emit_status("Exporting the visual audit bundle...", false)
	var bundle := await _visual_audit_runner.export_visual_audit_bundle()
	if not bool(bundle.get("ok", false)):
		_emit_status(str(bundle.get("message", "Unable to build the visual audit bundle.")), true)
		return
	var started := bool(_download_callback.call(
		bundle.get("buffer", PackedByteArray()),
		str(bundle.get("file_name", "survey_visual_audit.zip")),
		"Visual audit bundle export started."
	))
	if not started:
		_emit_status("Unable to start the visual audit bundle export.", true)
		return
	_emit_status("Visual audit bundle export started.", false)

func has_open_gallery() -> bool:
	return _question_gallery_overlay != null and _question_gallery_overlay.visible

func close_gallery() -> void:
	if _question_gallery_overlay != null:
		_question_gallery_overlay.visible = false

func _show_intro_after_frame() -> void:
	await get_tree().process_frame
	_auto_open_pending = false
	if _overlay == null:
		return
	if SURVEY_QA_SESSION_SUPPORT.session_has_resume_data(_session):
		open_home()
	else:
		open_tutorial()

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = SURVEY_QA_OVERLAY.new()
	_overlay.name = "SurveyQaOverlay"
	add_child(_overlay)
	_overlay.start_guided_requested.connect(_on_start_guided_requested)
	_overlay.resume_requested.connect(_on_resume_requested)
	_overlay.export_bundle_requested.connect(export_bundle)
	_overlay.export_visual_audit_requested.connect(export_visual_audit)
	_overlay.open_tutorial_requested.connect(_on_open_tutorial_requested)
	_overlay.home_requested.connect(_on_home_requested)
	_overlay.close_requested.connect(_on_overlay_closed)
	_overlay.switch_surface_requested.connect(_on_switch_surface_requested)
	_overlay.page_selected.connect(_on_page_selected)
	_overlay.capture_requested.connect(_on_capture_requested)
	_overlay.focus_item_requested.connect(_on_focus_item_requested)
	_overlay.auto_item_requested.connect(_on_auto_item_requested)
	_overlay.item_status_requested.connect(_on_item_status_requested)
	_overlay.tutorial_feedback_action_requested.connect(_on_tutorial_feedback_action_requested)

func _ensure_question_gallery_overlay() -> void:
	if _question_gallery_overlay != null:
		return
	_question_gallery_overlay = CanvasLayer.new()
	_question_gallery_overlay.name = "QuestionGalleryOverlay"
	_question_gallery_overlay.layer = 72
	_question_gallery_overlay.visible = false
	add_child(_question_gallery_overlay)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_question_gallery_overlay.add_child(root)

	_question_gallery_panel = PanelContainer.new()
	_question_gallery_panel.name = "GalleryPanel"
	_question_gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_question_gallery_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_question_gallery_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	stack.add_child(top_row)

	var title := Label.new()
	title.text = "Question Gallery"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.style_heading(title, 20)
	top_row.add_child(title)

	_question_gallery_close_button = Button.new()
	_question_gallery_close_button.text = "Close"
	SurveyStyle.apply_secondary_button(_question_gallery_close_button)
	_question_gallery_close_button.pressed.connect(close_gallery)
	top_row.add_child(_question_gallery_close_button)

	var gallery: Control = QUESTION_TYPE_GALLERY_SCENE.instantiate()
	if gallery != null:
		gallery.name = "QuestionTypeGallery"
		stack.add_child(gallery)

func _ensure_visual_audit_runner() -> void:
	if _visual_audit_runner != null:
		return
	_visual_audit_runner = SURVEY_VISUAL_AUDIT_RUNNER.new()
	_visual_audit_runner.name = "SurveyVisualAuditRunner"
	add_child(_visual_audit_runner)
	_visual_audit_runner.status_changed.connect(_on_visual_audit_status_changed)

func _layout_question_gallery(viewport_size: Vector2) -> void:
	if _question_gallery_panel == null:
		return
	var width := clampf(viewport_size.x * 0.76, 520.0, 1260.0)
	var height := clampf(viewport_size.y * 0.82, 360.0, 980.0)
	_question_gallery_panel.position = Vector2(floor((viewport_size.x - width) * 0.5), floor((viewport_size.y - height) * 0.5))
	_question_gallery_panel.size = Vector2(width, height)
	_question_gallery_panel.custom_minimum_size = Vector2(width, height)
	SurveyStyle.apply_panel(_question_gallery_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)

func _refresh_overlay() -> void:
	if _overlay == null or not _overlay.visible:
		return
	var current_view := str(_overlay.get_meta("qa_view", "home")).strip_edges()
	if _selected_page_node_id.is_empty():
		_selected_page_node_id = _current_page_node_id()
	match current_view:
		"tutorial":
			_overlay.refresh_state(_build_tutorial_state())
		"checklist":
			_overlay.refresh_state(_build_checklist_state())
		_:
			_overlay.refresh_state(_build_home_state())

func _build_home_state() -> Dictionary:
	var surface_state := SURVEY_QA_SESSION_SUPPORT.surface_state(_session, _surface_id)
	var checklist_results: Dictionary = surface_state.get("checklist_results", {}) as Dictionary
	var captures: Array = surface_state.get("captures", []) as Array
	var issues: Array = surface_state.get("issues", []) as Array
	var counts := _status_counts(checklist_results)
	var summary_lines := [
		"Use the guided QA flow to step through expected behavior, capture screenshots, and export one QA bundle at the end.",
		"",
		"- Surface: %s" % _surface_id.replace("_", " ").capitalize(),
		"- Started: %s" % str(_session.get("started_at", "")).strip_edges(),
		"- Checklist: %s" % _status_summary(counts),
		"- Captures: %d" % captures.size(),
		"- Reported issues: %d" % issues.size()
	]
	var switch_surface_payload := _switch_surface_payload()
	return {
		"title": "QA Guide",
		"subtitle": "%s test surface" % _surface_id.replace("_", " ").capitalize(),
		"status_text": _current_page_status_text(),
		"summary_text": "\n".join(summary_lines),
		"can_resume": SURVEY_QA_SESSION_SUPPORT.session_has_resume_data(_session),
		"resume_label": "Resume %s checklist" % _surface_id.replace("_", " ").capitalize(),
		"switch_surface_label": str(switch_surface_payload.get("label", "")).strip_edges(),
		"switch_surface_id": str(switch_surface_payload.get("surface_id", "")).strip_edges()
	}

func _build_tutorial_state() -> Dictionary:
	var can_export_feedback_zip := _feedback_controller != null and _feedback_controller.has_issues()
	return {
		"title": "How To Report An Issue",
		"subtitle": "Teach the feedback system first",
		"status_text": _current_page_status_text(),
		"tutorial_text": "1. Use the QA checklist to navigate to the page you want to inspect.\n2. If something looks wrong, press Start Issue Tagging, then click or tap the broken area.\n3. On desktop, Ctrl-click still works as a direct shortcut when QA mode is enabled.\n4. Add a short description before saving the issue.\n5. Use Open Issue Review to delete or confirm captured issues.\n6. Export the final QA bundle when you are done. It already includes the structured issue report assets.",
		"can_export_feedback_zip": can_export_feedback_zip
	}

func _build_checklist_state() -> Dictionary:
	var sections: Array[Dictionary] = []
	var surface_state := SURVEY_QA_SESSION_SUPPORT.surface_state(_session, _surface_id)
	var checklist_results: Dictionary = surface_state.get("checklist_results", {}) as Dictionary
	for section in SURVEY_QA_CHECKLIST_CATALOG.sections_for_surface(_surface_id):
		var resolved_items: Array[Dictionary] = []
		for item_value in section.get("items", []) as Array:
			if not (item_value is Dictionary):
				continue
			var item: Dictionary = (item_value as Dictionary).duplicate(true)
			var item_id := str(item.get("id", "")).strip_edges()
			var result: Dictionary = checklist_results.get(item_id, {}) as Dictionary
			if not result.is_empty():
				item["status"] = str(result.get("status", "pending")).strip_edges()
				item["note"] = str(result.get("note", "")).strip_edges()
			var conditional_message := _conditional_message(item)
			if not conditional_message.is_empty():
				item["conditional_message"] = conditional_message
				if str(item.get("status", "")).strip_edges().is_empty():
					item["status"] = "skip"
			resolved_items.append(item)
		var resolved_section := section.duplicate(true)
		resolved_section["items"] = resolved_items
		sections.append(resolved_section)
	if _selected_page_node_id.is_empty():
		_selected_page_node_id = _current_page_node_id()
	return {
		"title": "Guided QA Checklist",
		"subtitle": "Expected behavior by page",
		"status_text": _current_page_status_text(),
		"sections": sections,
		"selected_page_node_id": _selected_page_node_id,
		"page_status_text": _page_status_text(_selected_page_node_id, checklist_results)
	}

func _page_status_text(page_node_id: String, checklist_results: Dictionary) -> String:
	if page_node_id.is_empty():
		return ""
	var status_counts := {}
	for result_value in checklist_results.values():
		if not (result_value is Dictionary):
			continue
		var result: Dictionary = result_value as Dictionary
		if str(result.get("page_node_id", "")).strip_edges() != page_node_id:
			continue
		var status := str(result.get("status", "pending")).strip_edges().to_lower()
		status_counts[status] = int(status_counts.get(status, 0)) + 1
	return "This page: %s" % _status_summary(status_counts)

func _current_page_status_text() -> String:
	return "Current page: %s" % _current_page_node_id().replace("_", " ")

func _conditional_message(item: Dictionary) -> String:
	var conditional_key := str(item.get("conditional_key", "")).strip_edges()
	if conditional_key != "upload_configured":
		return ""
	var runtime_state := _runtime_state()
	if bool(runtime_state.get("upload_configured", false)):
		return ""
	return "Skipped by build configuration: this build does not have a live upload endpoint."

func _current_page_node_id() -> String:
	if has_open_gallery():
		return "question_gallery"
	var page_context := _page_context()
	var explicit_page_node_id := str(page_context.get("qa_page_node_id", "")).strip_edges()
	if not explicit_page_node_id.is_empty():
		return explicit_page_node_id
	if _surface_id == "survey_app":
		return _derive_survey_app_page_node_id(page_context)
	if _surface_id == "survey_journey":
		return _derive_journey_page_node_id(page_context)
	return ""

func _derive_survey_app_page_node_id(page_context: Dictionary) -> String:
	var open_overlays: Array = page_context.get("open_overlays", []) as Array
	var open_overlay_set := _string_set(open_overlays)
	if open_overlay_set.has("help"):
		return "survey_app_help"
	if open_overlay_set.has("profile"):
		return "survey_app_profile"
	if open_overlay_set.has("export"):
		return "survey_app_export"
	if open_overlay_set.has("summary"):
		return "survey_app_summary"
	if open_overlay_set.has("settings"):
		return "survey_app_settings"
	if open_overlay_set.has("onboarding"):
		return "survey_app_onboarding"
	if open_overlay_set.has("search"):
		return "survey_app_search"
	if open_overlay_set.has("overlay_menu"):
		return "survey_app_menu"
	return "survey_app_focus" if bool(page_context.get("focus_mode_active", false)) else "survey_app_scroll"

func _derive_journey_page_node_id(page_context: Dictionary) -> String:
	var open_overlays: Array = page_context.get("open_overlays", []) as Array
	var open_overlay_set := _string_set(open_overlays)
	if open_overlay_set.has("lore_link_prompt"):
		return "journey_lore_link"
	if open_overlay_set.has("help"):
		return "journey_help"
	if open_overlay_set.has("profile"):
		return "journey_profile"
	if open_overlay_set.has("focus_outline"):
		return "journey_outline"
	if open_overlay_set.has("overlay_menu"):
		return "journey_menu"
	var current_view := str(page_context.get("current_view", "")).strip_edges()
	if current_view == "landing" and bool(page_context.get("theme_drawer_expanded", false)):
		return "journey_theme_drawer"
	match current_view:
		"landing":
			return "journey_landing"
		"survey_selection":
			return "journey_survey_selection"
		"lore":
			return "journey_lore"
		"focus":
			return "journey_focus"
		"review":
			return "journey_review"
		"thanks":
			return "journey_thanks"
		"export":
			return "journey_export"
		"upload":
			return "journey_upload"
	return "journey_landing"

func _page_context() -> Dictionary:
	if not _page_context_provider.is_valid():
		return {}
	var raw_context: Variant = _page_context_provider.call()
	if raw_context is Dictionary:
		var payload: Dictionary = raw_context as Dictionary
		var page_context_value: Variant = payload.get("page_context", {})
		if page_context_value is Dictionary:
			return page_context_value as Dictionary
	return {}

func _runtime_state() -> Dictionary:
	if not _runtime_state_provider.is_valid():
		return {}
	var raw_state: Variant = _runtime_state_provider.call()
	return raw_state as Dictionary if raw_state is Dictionary else {}

func _environment_payload(runtime_state: Dictionary) -> Dictionary:
	var survey: SurveyDefinition = runtime_state.get("survey") as SurveyDefinition
	return {
		"surface_id": _surface_id,
		"platform_label": OS.get_name(),
		"is_web": OS.has_feature("web"),
		"is_debug_build": OS.is_debug_build(),
		"display_server": DisplayServer.get_name(),
		"rendering_driver": RenderingServer.get_rendering_device() != null,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")).strip_edges(),
		"page_node_id": _current_page_node_id(),
		"template_path": str(runtime_state.get("template_path", "")).strip_edges(),
		"upload_configured": bool(runtime_state.get("upload_configured", false)),
		"survey_id": survey.id if survey != null else "",
		"survey_title": survey.title if survey != null else "",
		"captured_at": Time.get_datetime_string_from_system(true)
	}

func _status_counts(checklist_results: Dictionary) -> Dictionary:
	var counts := {}
	for result_value in checklist_results.values():
		if not (result_value is Dictionary):
			continue
		var result: Dictionary = result_value as Dictionary
		var status := str(result.get("status", "pending")).strip_edges().to_lower()
		counts[status] = int(counts.get(status, 0)) + 1
	return counts

func _status_summary(counts: Dictionary) -> String:
	if counts.is_empty():
		return "0 recorded"
	var order := ["pass", "fail", "skip", "pending"]
	var parts: Array[String] = []
	for status in order:
		if not counts.has(status):
			continue
		parts.append("%s %d" % [status, int(counts.get(status, 0))])
	return ", ".join(parts)

func _switch_surface_payload() -> Dictionary:
	if not _switch_surface_callback.is_valid():
		return {}
	if _surface_id == "survey_journey":
		return {
			"surface_id": "survey_app",
			"label": "Switch To Survey App Smoke Test"
		}
	if _surface_id == "survey_app":
		return {
			"surface_id": "survey_journey",
			"label": "Return To Journey Guided Test"
		}
	return {}

func _sync_feedback_snapshot() -> void:
	if _feedback_controller == null or not _feedback_controller.has_method("issues_snapshot"):
		return
	var issues: Array = _feedback_controller.call("issues_snapshot") as Array
	_session = SURVEY_QA_SESSION_SUPPORT.record_feedback_issues(_session, _surface_id, issues)

func _emit_status(message: String, is_error: bool) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return
	status_requested.emit(trimmed, is_error)
	if _status_callback.is_valid():
		_status_callback.call(trimmed, is_error)

func _on_visual_audit_status_changed(message: String, is_error: bool) -> void:
	_emit_status(message, is_error)

func _string_set(values: Array) -> Dictionary:
	var resolved := {}
	for value in values:
		var text := str(value).strip_edges()
		if text.is_empty():
			continue
		resolved[text] = true
	return resolved

func _on_start_guided_requested() -> void:
	if _qa_action_callback.is_valid():
		var load_result: Variant = _qa_action_callback.call("load_default_template", {
			"path": SURVEY_QA_CHECKLIST_CATALOG.default_template_path()
		})
		if load_result is Dictionary:
			var result: Dictionary = load_result as Dictionary
			var message := str(result.get("message", "")).strip_edges()
			if not message.is_empty():
				_emit_status(message, not bool(result.get("ok", true)))
	_selected_page_node_id = _current_page_node_id()
	open_checklist(_selected_page_node_id)
	if _selected_page_node_id == "journey_landing" or _selected_page_node_id == "survey_app_scroll":
		_focus_page(_selected_page_node_id)

func _on_resume_requested() -> void:
	_selected_page_node_id = str(SURVEY_QA_SESSION_SUPPORT.surface_state(_session, _surface_id).get("current_page_node_id", "")).strip_edges()
	open_checklist(_selected_page_node_id)

func _on_open_tutorial_requested() -> void:
	open_tutorial()

func _on_home_requested() -> void:
	open_home()

func _on_overlay_closed() -> void:
	_sync_feedback_snapshot()
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)

func _on_switch_surface_requested(target_surface_id: String) -> void:
	_sync_feedback_snapshot()
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
	if not _switch_surface_callback.is_valid():
		_emit_status("Surface switching is unavailable in this build.", true)
		return
	_switch_surface_callback.call(target_surface_id)

func _on_page_selected(page_node_id: String) -> void:
	_selected_page_node_id = page_node_id.strip_edges()
	_session = SURVEY_QA_SESSION_SUPPORT.set_current_page(_session, _surface_id, _selected_page_node_id)
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
	open_checklist(_selected_page_node_id)

func _on_capture_requested(reason: String) -> void:
	capture_current_page(reason)

func _on_focus_item_requested(item_id: String) -> void:
	var item := SURVEY_QA_CHECKLIST_CATALOG.find_item(_surface_id, item_id)
	if item.is_empty():
		return
	_focus_page(str(item.get("page_node_id", "")).strip_edges())
	open_checklist(str(item.get("page_node_id", "")).strip_edges())

func _on_auto_item_requested(item_id: String) -> void:
	var item := SURVEY_QA_CHECKLIST_CATALOG.find_item(_surface_id, item_id)
	if item.is_empty():
		return
	var conditional_message := _conditional_message(item)
	if not conditional_message.is_empty():
		_on_item_status_requested(item_id, "skip")
		return
	var page_node_id := str(item.get("page_node_id", "")).strip_edges()
	_focus_page(page_node_id)
	_run_auto_page(page_node_id)
	open_checklist(page_node_id)

func _on_item_status_requested(item_id: String, status: String) -> void:
	var item := SURVEY_QA_CHECKLIST_CATALOG.find_item(_surface_id, item_id)
	if item.is_empty():
		return
	var note := _conditional_message(item)
	var resolved_status := status.strip_edges().to_lower()
	if not note.is_empty():
		resolved_status = "skip"
	_session = SURVEY_QA_SESSION_SUPPORT.record_check_result(_session, _surface_id, item, resolved_status, note, {
		"page_node_id": str(item.get("page_node_id", "")).strip_edges()
	})
	_session = SURVEY_QA_SESSION_SUPPORT.set_current_page(_session, _surface_id, str(item.get("page_node_id", "")).strip_edges())
	if resolved_status == "fail" or (resolved_status == "pass" and bool(item.get("capture_on_pass", false))):
		capture_current_page("check_%s" % resolved_status, item_id, resolved_status)
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
	open_checklist(str(item.get("page_node_id", "")).strip_edges())

func _on_tutorial_feedback_action_requested(action_id: String) -> void:
	if _feedback_controller == null:
		_emit_status("Playtest issue capture is unavailable in this build.", true)
		return
	match action_id:
		"capture":
			if _feedback_controller.has_method("begin_armed_capture"):
				_feedback_controller.call("begin_armed_capture", &"qa_tutorial")
		"review":
			if _feedback_controller.has_method("open_review"):
				_feedback_controller.call("open_review")
		"download":
			if _feedback_controller.has_method("download_feedback_zip"):
				_feedback_controller.call("download_feedback_zip")

func _focus_page(page_node_id: String) -> void:
	if page_node_id == "question_gallery":
		_question_gallery_overlay.visible = true
		_session = SURVEY_QA_SESSION_SUPPORT.set_current_page(_session, _surface_id, page_node_id)
		SURVEY_QA_SESSION_SUPPORT.save_session(_session)
		return
	close_gallery()
	if not _qa_action_callback.is_valid():
		return
	var result: Variant = _qa_action_callback.call("focus_page", {
		"page_node_id": page_node_id
	})
	if result is Dictionary:
		var payload: Dictionary = result as Dictionary
		var message := str(payload.get("message", "")).strip_edges()
		if not message.is_empty():
			_emit_status(message, not bool(payload.get("ok", true)))
	_session = SURVEY_QA_SESSION_SUPPORT.set_current_page(_session, _surface_id, page_node_id)
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)

func _run_auto_page(page_node_id: String) -> void:
	if page_node_id == "question_gallery":
		_focus_page(page_node_id)
		return
	if not _qa_action_callback.is_valid():
		return
	var result: Variant = _qa_action_callback.call("auto_page", {
		"page_node_id": page_node_id
	})
	if result is Dictionary:
		var payload: Dictionary = result as Dictionary
		var message := str(payload.get("message", "")).strip_edges()
		if not message.is_empty():
			_emit_status(message, not bool(payload.get("ok", true)))
	_session = SURVEY_QA_SESSION_SUPPORT.set_current_page(_session, _surface_id, page_node_id)
	SURVEY_QA_SESSION_SUPPORT.save_session(_session)
