class_name SurveyPlaytestFeedbackController
extends Node

const SURVEY_PLAYTEST_FEEDBACK_SUPPORT = preload("res://Scripts/UI/SurveyPlaytestFeedbackSupport.gd")
const SURVEY_PLAYTEST_FEEDBACK_OVERLAY = preload("res://Scripts/UI/SurveyPlaytestFeedbackOverlay.gd")
const SURVEY_TRANSFER_SUPPORT = preload("res://Scripts/Survey/SurveyTransferSupport.gd")

const SCREENSHOT_WIDTH := 320
const SCREENSHOT_HEIGHT := 240
const CAPTURE_METHOD_DESKTOP := "desktop_ctrl_click"
const CAPTURE_METHOD_ARMED := "mobile_armed_tap"
const INPUT_KIND_MOUSE := "mouse"
const INPUT_KIND_TOUCH := "touch"
const TRIGGER_SOURCE_CTRL_CLICK := &"ctrl_click"

signal issues_changed(issue_count: int)
signal overlay_visibility_changed(is_visible: bool)
signal status_requested(message: String, is_error: bool)

var _root_control: Control
var _surface_id: String = ""
var _page_context_provider: Callable = Callable()
var _download_callback: Callable = Callable()
var _share_callback: Callable = Callable()
var _share_supported_callback: Callable = Callable()
var _overlay: SurveyPlaytestFeedbackOverlay
var _pending_capture: Dictionary = {}
var _issues: Array = []
var _issue_counter: int = 0
var _capture_in_progress: bool = false
var _session_started_unix: int = int(Time.get_unix_time_from_system())
var _session_started_at: String = Time.get_datetime_string_from_system(true)
var _armed_trigger_source: StringName = StringName()

func configure(root_control: Control, surface_id: String, page_context_provider: Callable, download_callback: Callable, share_callback: Callable = Callable(), share_supported_callback: Callable = Callable()) -> void:
	_root_control = root_control
	_surface_id = surface_id.strip_edges()
	_page_context_provider = page_context_provider
	_download_callback = download_callback
	_share_callback = share_callback
	_share_supported_callback = share_supported_callback
	_ensure_overlay()
	_overlay.refresh_layout(_viewport_size())

func handle_input(event: InputEvent) -> bool:
	if _root_control == null or _overlay == null or _capture_in_progress:
		return false
	if _overlay.is_armed_capture_active():
		return _handle_armed_capture_input(event)
	if _overlay.has_open_ui():
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.ctrl_pressed:
		return false
	_begin_capture(mouse_event.position, CAPTURE_METHOD_DESKTOP, INPUT_KIND_MOUSE, TRIGGER_SOURCE_CTRL_CLICK)
	return true

func refresh_layout(viewport_size: Vector2) -> void:
	if _overlay != null:
		_overlay.refresh_layout(viewport_size)

func has_open_ui() -> bool:
	return _overlay != null and _overlay.has_open_ui()

func close_active_ui() -> bool:
	if _overlay == null:
		return false
	var closed: bool = _overlay.close_active()
	if closed:
		_pending_capture.clear()
		_armed_trigger_source = StringName()
	return closed

func issue_count() -> int:
	return _issues.size()

func has_issues() -> bool:
	return not _issues.is_empty()

func supports_share_feedback_zip() -> bool:
	if not _share_callback.is_valid():
		return false
	if not _share_supported_callback.is_valid():
		return true
	return bool(_share_supported_callback.call())

func is_armed_capture_active() -> bool:
	return _overlay != null and _overlay.is_armed_capture_active()

func begin_armed_capture(trigger_source: StringName) -> bool:
	if _root_control == null or _overlay == null or _capture_in_progress:
		return false
	if _overlay.has_open_ui() and not _overlay.is_armed_capture_active():
		return false
	_armed_trigger_source = trigger_source if trigger_source != StringName() else &"floating_report_button"
	_overlay.open_armed_capture()
	overlay_visibility_changed.emit(true)
	return true

func cancel_armed_capture() -> bool:
	if _overlay == null or not _overlay.is_armed_capture_active():
		return false
	_armed_trigger_source = StringName()
	return _overlay.close_active()

func open_review() -> void:
	if _overlay == null:
		return
	_overlay.open_review(_issues_snapshot())
	overlay_visibility_changed.emit(true)

func clear_all_issues() -> void:
	var cleared_count: int = _issues.size()
	_issues.clear()
	_pending_capture.clear()
	if _overlay != null:
		_overlay.refresh_review(_issues_snapshot())
	issues_changed.emit(0)
	overlay_visibility_changed.emit(has_open_ui())
	status_requested.emit("Cleared %d captured issue(s)." % cleared_count, false)

func build_report_markdown() -> String:
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_report_markdown(_session_manifest(), _issues_snapshot())

func build_bundle_json_text() -> String:
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_bundle_json_text(_session_manifest(), _issues_snapshot())

func build_zip_export() -> Dictionary:
	var file_name: String = SURVEY_PLAYTEST_FEEDBACK_SUPPORT.suggested_zip_filename(_surface_id, _session_started_at.replace(":", "-").replace(" ", "_"))
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_zip_export(_session_manifest(), _issues_snapshot(), file_name)

func copy_text_report() -> void:
	var report_markdown: String = build_report_markdown()
	var copy_result: Dictionary = SURVEY_TRANSFER_SUPPORT.copy_text_to_clipboard(
		report_markdown,
		"No playtest issues are available to copy yet.",
		"Playtest issue report copied to the clipboard."
	)
	status_requested.emit(str(copy_result.get("message", "")), not bool(copy_result.get("ok", false)))

func download_feedback_zip() -> void:
	if _issues.is_empty():
		status_requested.emit("Capture at least one playtest issue before exporting a ZIP.", true)
		return
	if not _download_callback.is_valid():
		status_requested.emit("Feedback ZIP downloads are unavailable in this build.", true)
		return
	var export_bundle: Dictionary = build_zip_export()
	if not bool(export_bundle.get("ok", false)):
		status_requested.emit(str(export_bundle.get("message", "Unable to build the feedback ZIP.")), true)
		return
	var started: bool = bool(_download_callback.call(
		export_bundle.get("buffer", PackedByteArray()),
		str(export_bundle.get("file_name", "playtest_feedback.zip")),
		"Playtest feedback ZIP download started."
	))
	if not started:
		status_requested.emit("Unable to start the playtest feedback ZIP download.", true)

func share_feedback_zip() -> void:
	if _issues.is_empty():
		status_requested.emit("Capture at least one playtest issue before sharing a ZIP.", true)
		return
	if not supports_share_feedback_zip():
		download_feedback_zip()
		return
	var export_bundle: Dictionary = build_zip_export()
	if not bool(export_bundle.get("ok", false)):
		status_requested.emit(str(export_bundle.get("message", "Unable to build the feedback ZIP.")), true)
		return
	var started: bool = bool(_share_callback.call(
		export_bundle.get("buffer", PackedByteArray()),
		str(export_bundle.get("file_name", "playtest_feedback.zip")),
		"application/zip",
		"Playtest feedback ZIP",
		"Playtest issues exported from %s." % _surface_id,
		"Feedback ZIP share requested."
	))
	if not started:
		download_feedback_zip()

func pending_capture_snapshot() -> Dictionary:
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT._sanitize_variant(_pending_capture) as Dictionary

func issues_snapshot() -> Array:
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT._sanitize_variant(_issues_snapshot())

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = SURVEY_PLAYTEST_FEEDBACK_OVERLAY.new()
	_overlay.name = "PlaytestFeedbackOverlay"
	add_child(_overlay)
	_overlay.capture_saved.connect(_on_capture_saved)
	_overlay.capture_cancelled.connect(_on_capture_cancelled)
	_overlay.review_delete_requested.connect(_on_review_delete_requested)
	_overlay.review_clear_all_requested.connect(clear_all_issues)
	_overlay.overlay_closed.connect(_on_overlay_closed)

func _handle_armed_capture_input(event: InputEvent) -> bool:
	var pressed_point: Vector2 = Vector2.ZERO
	var input_kind: String = ""
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed:
			return false
		pressed_point = touch_event.position
		input_kind = INPUT_KIND_TOUCH
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		pressed_point = mouse_event.position
		input_kind = INPUT_KIND_MOUSE
	else:
		return false
	if not _overlay.is_armed_capture_point_allowed(pressed_point):
		return false
	_overlay.dismiss_armed_capture()
	_begin_capture(pressed_point, CAPTURE_METHOD_ARMED, input_kind, _armed_trigger_source)
	_armed_trigger_source = StringName()
	return true

func _begin_capture(click_position: Vector2, capture_method: String, input_kind: String, trigger_source: StringName) -> void:
	_capture_in_progress = true
	_pending_capture = _build_capture_context(click_position, capture_method, input_kind, trigger_source)
	call_deferred("_finalize_capture_popup")

func _finalize_capture_popup() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _pending_capture.is_empty():
		_capture_in_progress = false
		return
	var click_context: Dictionary = _pending_capture.get("click", {}) as Dictionary
	var screenshot: Dictionary = _capture_screenshot(click_context)
	for key_variant in screenshot.keys():
		_pending_capture[str(key_variant)] = screenshot.get(key_variant)
	_pending_capture["screenshot"] = screenshot.get("screenshot", {})
	_overlay.open_capture(_pending_capture)
	_capture_in_progress = false
	overlay_visibility_changed.emit(true)

func _build_capture_context(click_position: Vector2, capture_method: String, input_kind: String, trigger_source: StringName) -> Dictionary:
	var viewport_size: Vector2 = _viewport_size()
	var point: Vector2 = Vector2(
		clampf(click_position.x, 0.0, maxf(viewport_size.x - 1.0, 0.0)),
		clampf(click_position.y, 0.0, maxf(viewport_size.y - 1.0, 0.0))
	)
	var target: Control = _pick_target_control(point)
	var overlapping_controls: Array[Control] = _controls_at_point(point)
	var page_context: Dictionary = {}
	if _page_context_provider.is_valid():
		var provided_page_context: Variant = _page_context_provider.call()
		if provided_page_context is Dictionary:
			page_context = provided_page_context as Dictionary
	var semantic_context: Dictionary = _merged_feedback_context(target)
	var issue_timestamp: String = Time.get_datetime_string_from_system(true)
	return {
		"surface": _surface_id,
		"captured_at": issue_timestamp,
		"capture_method": capture_method.strip_edges(),
		"input_kind": input_kind.strip_edges(),
		"trigger_source": str(trigger_source).strip_edges(),
		"page_summary": str(page_context.get("page_summary", "")).strip_edges(),
		"page_context": page_context.get("page_context", {}),
		"survey": page_context.get("survey", {}),
		"target_summary": _target_summary(target, semantic_context),
		"click": {
			"pixel_position": {
				"x": int(round(point.x)),
				"y": int(round(point.y))
			},
			"normalized_position": {
				"x": 0.0 if viewport_size.x <= 0.0 else point.x / viewport_size.x,
				"y": 0.0 if viewport_size.y <= 0.0 else point.y / viewport_size.y
			},
			"viewport_size": {
				"x": int(round(viewport_size.x)),
				"y": int(round(viewport_size.y))
			}
		},
		"target_control": _control_snapshot(target),
		"control_context": {
			"target": _control_snapshot(target),
			"overlapping": _control_snapshot_list(overlapping_controls, 5),
			"ancestor_chain": _ancestor_chain_snapshot(target)
		},
		"semantic_context": semantic_context,
		"nearby_text": _nearby_text_snippets(target, 8)
	}

func _capture_screenshot(click_context: Dictionary) -> Dictionary:
	var viewport: Viewport = null
	if _root_control != null:
		viewport = _root_control.get_viewport()
	var image: Image = null
	if viewport != null and viewport.get_texture() != null:
		image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		image = _placeholder_capture_image(click_context)
	var crop_width: int = mini(SCREENSHOT_WIDTH, image.get_width())
	var crop_height: int = mini(SCREENSHOT_HEIGHT, image.get_height())
	var pixel_position: Dictionary = click_context.get("pixel_position", {}) as Dictionary
	var click_x: int = int(pixel_position.get("x", 0))
	var click_y: int = int(pixel_position.get("y", 0))
	var origin_x: int = clampi(click_x - int(round(crop_width * 0.5)), 0, maxi(image.get_width() - crop_width, 0))
	var origin_y: int = clampi(click_y - int(round(crop_height * 0.5)), 0, maxi(image.get_height() - crop_height, 0))
	var crop: Image = image.get_region(Rect2i(origin_x, origin_y, crop_width, crop_height))
	var marker_position: Vector2i = Vector2i(click_x - origin_x, click_y - origin_y)
	_draw_click_marker(crop, marker_position)
	return {
		"_screenshot_image": crop,
		"_screenshot_png": crop.save_png_to_buffer(),
		"screenshot": {
			"file_path": "",
			"size": {"x": crop_width, "y": crop_height},
			"crop_rect": {
				"x": origin_x,
				"y": origin_y,
				"width": crop_width,
				"height": crop_height
			},
			"click_in_crop": {
				"x": marker_position.x,
				"y": marker_position.y
			}
		}
	}

func _draw_click_marker(image: Image, point: Vector2i) -> void:
	if image == null or image.is_empty():
		return
	var marker_color: Color = Color(1.0, 0.2, 0.2, 1.0)
	var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	for offset in range(-10, 11):
		_set_marker_pixel(image, Vector2i(point.x + offset, point.y), outline_color)
		_set_marker_pixel(image, Vector2i(point.x, point.y + offset), outline_color)
	for offset in range(-8, 9):
		_set_marker_pixel(image, Vector2i(point.x + offset, point.y), marker_color)
		_set_marker_pixel(image, Vector2i(point.x, point.y + offset), marker_color)

func _set_marker_pixel(image: Image, point: Vector2i, color: Color) -> void:
	if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
		return
	image.set_pixelv(point, color)

func _placeholder_capture_image(click_context: Dictionary) -> Image:
	var viewport_size: Dictionary = click_context.get("viewport_size", {}) as Dictionary
	var width: int = max(int(viewport_size.get("x", SCREENSHOT_WIDTH)), 1)
	var height: int = max(int(viewport_size.get("y", SCREENSHOT_HEIGHT)), 1)
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.14, 0.18, 1.0))
	return image

func _pick_target_control(point: Vector2) -> Control:
	var viewport: Viewport = null
	if _root_control != null:
		viewport = _root_control.get_viewport()
	if viewport != null:
		var hovered: Control = viewport.gui_get_hovered_control()
		if hovered != null and hovered.is_visible_in_tree() and hovered.get_global_rect().has_point(point) and not _is_overlay_control(hovered):
			return hovered
	var candidates: Array[Control] = _controls_at_point(point)
	if candidates.is_empty():
		return _root_control
	candidates.sort_custom(Callable(self, "_sort_control_candidates"))
	return candidates.back()

func _sort_control_candidates(left: Control, right: Control) -> bool:
	return _control_candidate_score(left) < _control_candidate_score(right)

func _control_candidate_score(control: Control) -> float:
	if control == null:
		return -1000000.0
	var score: float = float(_node_depth(control) * 10)
	match control.mouse_filter:
		Control.MOUSE_FILTER_STOP:
			score += 40.0
		Control.MOUSE_FILTER_PASS:
			score += 18.0
	if control.has_meta("feedback_context"):
		score += 30.0
	if control is BaseButton or control is LineEdit or control is TextEdit or control is OptionButton or control is HSlider:
		score += 90.0
	elif control is PanelContainer:
		score += 35.0
	elif control is Label:
		score += 20.0
	return score

func _node_depth(node: Node) -> int:
	var depth: int = 0
	var current: Node = node
	while current != null:
		depth += 1
		current = current.get_parent()
	return depth

func _controls_at_point(point: Vector2) -> Array[Control]:
	var controls: Array[Control] = []
	_collect_controls_at_point(_root_control, point, controls)
	return controls

func _collect_controls_at_point(node: Node, point: Vector2, collected: Array[Control]) -> void:
	if node == null:
		return
	if node is Control:
		var control: Control = node as Control
		if _is_overlay_control(control) or not control.is_visible_in_tree():
			return
		if control.get_global_rect().has_point(point):
			collected.append(control)
	for child in node.get_children():
		_collect_controls_at_point(child, point, collected)

func _is_overlay_control(control: Control) -> bool:
	return _overlay != null and (_overlay == control or _overlay.is_ancestor_of(control))

func _merged_feedback_context(target: Control) -> Dictionary:
	var merged: Dictionary = {}
	var current: Node = target
	while current != null:
		if current is Control:
			var control: Control = current as Control
			if control.has_meta("feedback_context"):
				var context_variant: Variant = control.get_meta("feedback_context")
				if context_variant is Dictionary:
					merged.merge((context_variant as Dictionary).duplicate(true), true)
		current = current.get_parent()
	return merged

func _target_summary(target: Control, semantic_context: Dictionary) -> String:
	var semantic_summary: String = str(semantic_context.get("summary", "")).strip_edges()
	if not semantic_summary.is_empty():
		return semantic_summary
	if target == null:
		return "Viewport background"
	var control_text: String = str(_control_snapshot(target).get("text_summary", "")).strip_edges()
	if not control_text.is_empty():
		return "%s (%s)" % [control_text, target.get_class()]
	return "%s (%s)" % [target.name, target.get_class()]

func _ancestor_chain_snapshot(target: Control) -> Array:
	var chain: Array = []
	var current: Node = target
	while current != null:
		if current is Control:
			chain.append(_control_snapshot(current as Control))
		current = current.get_parent()
	return chain

func _control_snapshot_list(controls: Array[Control], limit: int) -> Array:
	var snapshots: Array = []
	var sorted_controls: Array[Control] = []
	sorted_controls.assign(controls)
	sorted_controls.sort_custom(Callable(self, "_sort_control_candidates"))
	for index in range(sorted_controls.size() - 1, -1, -1):
		var control: Control = sorted_controls[index] as Control
		if control == null:
			continue
		snapshots.append(_control_snapshot(control))
		if snapshots.size() >= limit:
			break
	return snapshots

func _control_snapshot(control: Control) -> Dictionary:
	if control == null:
		return {}
	var rect: Rect2 = control.get_global_rect()
	var tooltip_text: String = str(control.get("tooltip_text")).strip_edges()
	var text_summary: String = _control_text_summary(control)
	var snapshot := {
		"name": control.name,
		"class_name": control.get_class(),
		"path": str(control.get_path()),
		"mouse_filter": int(control.mouse_filter),
		"visible": control.is_visible_in_tree(),
		"rect": {
			"x": rect.position.x,
			"y": rect.position.y,
			"width": rect.size.x,
			"height": rect.size.y
		},
		"tooltip_text": tooltip_text,
		"text_summary": text_summary
	}
	if control is BaseButton:
		snapshot["disabled"] = (control as BaseButton).disabled
	return snapshot

func _control_text_summary(control: Control) -> String:
	var snippets: Array[String] = []
	var primary_text: String = ""
	if control is BaseButton:
		primary_text = str((control as BaseButton).text).strip_edges()
	elif control is Label:
		primary_text = str((control as Label).text).strip_edges()
	elif control is LineEdit:
		var line_edit: LineEdit = control as LineEdit
		primary_text = str(line_edit.text).strip_edges()
		if primary_text.is_empty():
			primary_text = str(line_edit.placeholder_text).strip_edges()
	elif control is TextEdit:
		var text_edit: TextEdit = control as TextEdit
		primary_text = str(text_edit.text).strip_edges()
		if primary_text.is_empty():
			primary_text = str(text_edit.placeholder_text).strip_edges()
	elif control is OptionButton:
		var option_button: OptionButton = control as OptionButton
		if option_button.selected >= 0 and option_button.selected < option_button.item_count:
			primary_text = option_button.get_item_text(option_button.selected).strip_edges()
	elif control is HSlider:
		primary_text = str(snappedf((control as HSlider).value, 0.01))
	if not primary_text.is_empty():
		snippets.append(primary_text)
	var tooltip_text: String = str(control.get("tooltip_text")).strip_edges()
	if not tooltip_text.is_empty() and not snippets.has(tooltip_text):
		snippets.append(tooltip_text)
	return " | ".join(snippets)

func _nearby_text_snippets(target: Control, limit: int) -> Array:
	var snippets: Array[String] = []
	var anchor: Control = _nearest_feedback_ancestor(target)
	_collect_text_snippets(anchor if anchor != null else target, snippets, limit)
	return snippets

func _nearest_feedback_ancestor(target: Control) -> Control:
	var current: Node = target
	while current != null:
		if current is Control:
			var control: Control = current as Control
			if control.has_meta("feedback_context"):
				return control
		current = current.get_parent()
	return target

func _collect_text_snippets(node: Node, snippets: Array[String], limit: int) -> void:
	if node == null or snippets.size() >= limit:
		return
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			return
		var summary: String = _control_text_summary(control)
		if not summary.is_empty():
			for part in summary.split("|", false):
				var cleaned: String = part.strip_edges().replace("\n", " ")
				if cleaned.is_empty() or snippets.has(cleaned):
					continue
				snippets.append(cleaned)
				if snippets.size() >= limit:
					return
	for child in node.get_children():
		_collect_text_snippets(child, snippets, limit)

func _on_capture_saved(description: String) -> void:
	if _pending_capture.is_empty():
		return
	_issue_counter += 1
	var issue: Dictionary = _pending_capture.duplicate(true) as Dictionary
	var issue_id: String = "issue_%04d" % _issue_counter
	issue["id"] = issue_id
	issue["timestamp_unix"] = int(Time.get_unix_time_from_system())
	issue["timestamp"] = Time.get_datetime_string_from_system(true)
	issue["description"] = description.strip_edges()
	var screenshot: Dictionary = issue.get("screenshot", {}) as Dictionary
	screenshot["file_path"] = "screenshots/%s.png" % issue_id
	issue["screenshot"] = screenshot
	_issues.append(issue)
	_pending_capture.clear()
	issues_changed.emit(_issues.size())
	status_requested.emit("Saved playtest issue %s." % issue_id, false)
	if _overlay != null:
		_overlay.close_active()

func _on_capture_cancelled() -> void:
	_pending_capture.clear()
	if _overlay != null:
		_overlay.close_active()

func _on_review_delete_requested(issue_id: String) -> void:
	for index in range(_issues.size()):
		var issue_variant: Variant = _issues[index]
		if issue_variant is Dictionary and str((issue_variant as Dictionary).get("id", "")).strip_edges() == issue_id:
			_issues.remove_at(index)
			break
	if _overlay != null:
		_overlay.refresh_review(_issues_snapshot())
	issues_changed.emit(_issues.size())
	status_requested.emit("Deleted playtest issue %s." % issue_id, false)

func _on_overlay_closed() -> void:
	_armed_trigger_source = StringName()
	overlay_visibility_changed.emit(false)

func _issues_snapshot() -> Array:
	var snapshot: Array = []
	for issue_variant in _issues:
		if issue_variant is Dictionary:
			snapshot.append((issue_variant as Dictionary).duplicate(true))
	return snapshot

func _session_manifest() -> Dictionary:
	return SURVEY_PLAYTEST_FEEDBACK_SUPPORT.build_session_manifest(
		_surface_id,
		_session_started_unix,
		_session_started_at,
		_issues.size()
	)

func _viewport_size() -> Vector2:
	if _root_control == null or _root_control.get_viewport() == null:
		return Vector2.ZERO
	return _root_control.get_viewport().get_visible_rect().size
