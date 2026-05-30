class_name SurveyPlaytestFeedbackOverlay
extends CanvasLayer

signal capture_saved(description: String)
signal capture_cancelled
signal review_delete_requested(issue_id: String)
signal review_clear_all_requested
signal overlay_closed

const SAFE_MARGIN := 12.0
const SCREENSHOT_SIZE := Vector2(320.0, 240.0)
const COMPACT_VIEWPORT_WIDTH := 620.0

var _capture_anchor_position: Vector2 = Vector2.ZERO
var _review_issues: Array = []
var _layout_viewport_size: Vector2 = Vector2.ZERO

var _root: Control
var _dimmer: ColorRect
var _armed_panel: PanelContainer
var _armed_heading_label: Label
var _armed_body_label: Label
var _armed_cancel_button: Button
var _capture_panel: PanelContainer
var _capture_scroll: ScrollContainer
var _capture_stack: VBoxContainer
var _capture_heading_label: Label
var _capture_close_button: Button
var _capture_page_label: Label
var _capture_target_label: Label
var _capture_coord_label: Label
var _capture_thumbnail_frame: PanelContainer
var _capture_thumbnail: TextureRect
var _capture_description_label: Label
var _capture_description_edit: TextEdit
var _capture_cancel_button: Button
var _capture_save_button: Button
var _review_panel: PanelContainer
var _review_heading_label: Label
var _review_close_button: Button
var _review_status_label: Label
var _review_scroll: ScrollContainer
var _review_list: VBoxContainer
var _review_empty_label: Label
var _review_clear_button: Button

func _ready() -> void:
	layer = 80
	visible = false
	_build_ui()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if _root == null:
		return
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_armed_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 22, 1)
	SurveyStyle.apply_panel(_capture_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 22, 1)
	SurveyStyle.apply_panel(_capture_thumbnail_frame, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 14, 1)
	SurveyStyle.apply_panel(_review_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.style_heading(_armed_heading_label, 20)
	SurveyStyle.style_body(_armed_body_label)
	SurveyStyle.style_heading(_capture_heading_label, 20)
	SurveyStyle.style_heading(_review_heading_label, 22)
	for label in [_capture_page_label, _capture_target_label, _capture_coord_label, _capture_description_label]:
		if label == null:
			continue
		SurveyStyle.style_body(label)
	_capture_coord_label.add_theme_color_override("font_color", SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_caption(_review_status_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_review_empty_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_body(_capture_description_label)
	SurveyStyle.style_text_edit(_capture_description_edit)
	for button in [_armed_cancel_button, _capture_close_button, _capture_cancel_button, _review_close_button]:
		if button == null:
			continue
		SurveyStyle.apply_secondary_button(button)
	for button in [_capture_save_button]:
		if button == null:
			continue
		SurveyStyle.apply_primary_button(button)
	for button in [_review_clear_button]:
		if button == null:
			continue
		SurveyStyle.apply_danger_button(button)

func refresh_layout(viewport_size: Vector2) -> void:
	if _root == null:
		return
	_layout_viewport_size = viewport_size
	_root.size = viewport_size
	var compact_sheet: bool = _is_compact_sheet_viewport(viewport_size)
	var capture_width: float = viewport_size.x - (SAFE_MARGIN * 2.0) if compact_sheet else clampf(viewport_size.x * 0.34, 320.0, 460.0)
	var capture_thumb_width: float = clampf(capture_width - 36.0, 180.0, SCREENSHOT_SIZE.x)
	var capture_thumb_height: float = capture_thumb_width * (SCREENSHOT_SIZE.y / SCREENSHOT_SIZE.x)
	var capture_max_height: float = clampf(viewport_size.y * (0.72 if compact_sheet else 0.66), 280.0, maxf(viewport_size.y - (SAFE_MARGIN * 2.0), 280.0))
	_capture_panel.custom_minimum_size = Vector2(capture_width, 0.0)
	_capture_scroll.custom_minimum_size = Vector2(0.0, capture_max_height)
	_capture_thumbnail_frame.custom_minimum_size = Vector2(capture_thumb_width, capture_thumb_height)
	_capture_thumbnail.custom_minimum_size = Vector2(capture_thumb_width, capture_thumb_height)
	_capture_description_edit.custom_minimum_size.y = clampf(viewport_size.y * (0.18 if compact_sheet else 0.22), 110.0, 180.0)
	var review_width: float = viewport_size.x - (SAFE_MARGIN * 2.0) if compact_sheet else clampf(viewport_size.x * 0.72, 340.0, 920.0)
	var review_height: float = clampf(viewport_size.y * (0.82 if compact_sheet else 0.72), 320.0, maxf(viewport_size.y - (SAFE_MARGIN * 2.0), 320.0))
	_review_panel.custom_minimum_size = Vector2(review_width, 0.0)
	_review_scroll.custom_minimum_size = Vector2(0.0, maxf(review_height - 140.0, 160.0))
	var armed_width: float = viewport_size.x - (SAFE_MARGIN * 2.0) if compact_sheet else clampf(viewport_size.x * 0.38, 280.0, 460.0)
	_armed_panel.custom_minimum_size = Vector2(armed_width, 0.0)
	call_deferred("_reposition_visible_panels")

func has_open_ui() -> bool:
	return visible and (_armed_panel.visible or _capture_panel.visible or _review_panel.visible)

func is_armed_capture_active() -> bool:
	return visible and _armed_panel.visible

func open_armed_capture() -> void:
	_capture_panel.visible = false
	_review_panel.visible = false
	_armed_panel.visible = true
	visible = true
	call_deferred("_reposition_visible_panels")

func dismiss_armed_capture() -> void:
	_armed_panel.visible = false
	if not (_capture_panel.visible or _review_panel.visible):
		visible = false

func is_armed_capture_point_allowed(point: Vector2) -> bool:
	if not _armed_panel.visible:
		return false
	return not _armed_panel.get_global_rect().has_point(point)

func open_capture(capture_context: Dictionary) -> void:
	var screenshot_image: Image = capture_context.get("_screenshot_image") as Image
	_capture_heading_label.text = "Report Playtest Issue"
	_capture_page_label.text = str(capture_context.get("page_summary", "")).strip_edges()
	_capture_target_label.text = str(capture_context.get("target_summary", "")).strip_edges()
	_capture_coord_label.text = _coordinate_text(capture_context.get("click", {}) as Dictionary)
	_capture_description_edit.text = ""
	_capture_save_button.disabled = true
	if screenshot_image != null and not screenshot_image.is_empty():
		_capture_thumbnail.texture = ImageTexture.create_from_image(screenshot_image)
	else:
		_capture_thumbnail.texture = null
	var click_context: Dictionary = capture_context.get("click", {}) as Dictionary
	var pixel_position: Dictionary = click_context.get("pixel_position", {}) as Dictionary
	_capture_anchor_position = Vector2(
		float(pixel_position.get("x", 0.0)),
		float(pixel_position.get("y", 0.0))
	)
	_armed_panel.visible = false
	_review_panel.visible = false
	_capture_panel.visible = true
	visible = true
	call_deferred("_reposition_visible_panels")
	call_deferred("_focus_description_field")

func open_review(issues: Array) -> void:
	_review_issues = issues.duplicate(true)
	_refresh_review_list()
	_armed_panel.visible = false
	_capture_panel.visible = false
	_review_panel.visible = true
	visible = true
	call_deferred("_reposition_visible_panels")

func refresh_review(issues: Array) -> void:
	_review_issues = issues.duplicate(true)
	if _review_panel.visible:
		_refresh_review_list()
		call_deferred("_reposition_visible_panels")

func close_active() -> bool:
	if not has_open_ui():
		return false
	_armed_panel.visible = false
	_capture_panel.visible = false
	_review_panel.visible = false
	visible = false
	overlay_closed.emit()
	return true

func _build_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "FeedbackRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_root.add_child(_dimmer)

	_armed_panel = PanelContainer.new()
	_armed_panel.name = "ArmedPanel"
	_armed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_armed_panel.visible = false
	_root.add_child(_armed_panel)

	var armed_margin := MarginContainer.new()
	armed_margin.name = "ArmedMargin"
	armed_margin.add_theme_constant_override("margin_left", 16)
	armed_margin.add_theme_constant_override("margin_top", 16)
	armed_margin.add_theme_constant_override("margin_right", 16)
	armed_margin.add_theme_constant_override("margin_bottom", 16)
	_armed_panel.add_child(armed_margin)

	var armed_stack := VBoxContainer.new()
	armed_stack.name = "ArmedStack"
	armed_stack.add_theme_constant_override("separation", 10)
	armed_margin.add_child(armed_stack)

	_armed_heading_label = Label.new()
	_armed_heading_label.name = "ArmedHeadingLabel"
	_armed_heading_label.text = "Report An Issue"
	_armed_heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armed_stack.add_child(_armed_heading_label)

	_armed_body_label = Label.new()
	_armed_body_label.name = "ArmedBodyLabel"
	_armed_body_label.text = "Tap anywhere on the app to tag the problem spot. The next tap will capture the point without triggering the app underneath."
	_armed_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	armed_stack.add_child(_armed_body_label)

	var armed_actions := HBoxContainer.new()
	armed_actions.name = "ArmedActions"
	armed_actions.alignment = BoxContainer.ALIGNMENT_END
	armed_actions.add_theme_constant_override("separation", 10)
	armed_stack.add_child(armed_actions)

	_armed_cancel_button = Button.new()
	_armed_cancel_button.name = "ArmedCancelButton"
	_armed_cancel_button.text = "Cancel"
	_armed_cancel_button.pressed.connect(_on_armed_cancel_pressed)
	armed_actions.add_child(_armed_cancel_button)

	_capture_panel = PanelContainer.new()
	_capture_panel.name = "CapturePanel"
	_capture_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_capture_panel.visible = false
	_root.add_child(_capture_panel)

	var capture_margin := MarginContainer.new()
	capture_margin.name = "CaptureMargin"
	capture_margin.add_theme_constant_override("margin_left", 16)
	capture_margin.add_theme_constant_override("margin_top", 16)
	capture_margin.add_theme_constant_override("margin_right", 16)
	capture_margin.add_theme_constant_override("margin_bottom", 16)
	_capture_panel.add_child(capture_margin)

	_capture_scroll = ScrollContainer.new()
	_capture_scroll.name = "CaptureScroll"
	capture_margin.add_child(_capture_scroll)

	_capture_stack = VBoxContainer.new()
	_capture_stack.name = "CaptureStack"
	_capture_stack.add_theme_constant_override("separation", 10)
	_capture_scroll.add_child(_capture_stack)

	var capture_heading_row := HBoxContainer.new()
	capture_heading_row.name = "CaptureHeadingRow"
	capture_heading_row.add_theme_constant_override("separation", 10)
	_capture_stack.add_child(capture_heading_row)

	_capture_heading_label = Label.new()
	_capture_heading_label.name = "CaptureHeadingLabel"
	_capture_heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capture_heading_row.add_child(_capture_heading_label)

	_capture_close_button = Button.new()
	_capture_close_button.name = "CaptureCloseButton"
	_capture_close_button.text = "X"
	_capture_close_button.custom_minimum_size = Vector2(40.0, 40.0)
	_capture_close_button.pressed.connect(_on_capture_cancel_pressed)
	capture_heading_row.add_child(_capture_close_button)

	_capture_page_label = Label.new()
	_capture_page_label.name = "CapturePageLabel"
	_capture_page_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capture_stack.add_child(_capture_page_label)

	_capture_target_label = Label.new()
	_capture_target_label.name = "CaptureTargetLabel"
	_capture_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capture_stack.add_child(_capture_target_label)

	_capture_coord_label = Label.new()
	_capture_coord_label.name = "CaptureCoordLabel"
	_capture_coord_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capture_stack.add_child(_capture_coord_label)

	_capture_thumbnail_frame = PanelContainer.new()
	_capture_thumbnail_frame.name = "CaptureThumbnailFrame"
	_capture_stack.add_child(_capture_thumbnail_frame)

	_capture_thumbnail = TextureRect.new()
	_capture_thumbnail.name = "CaptureThumbnail"
	_capture_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capture_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_capture_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_thumbnail_frame.add_child(_capture_thumbnail)

	_capture_description_label = Label.new()
	_capture_description_label.name = "CaptureDescriptionLabel"
	_capture_description_label.text = "Describe what seems wrong here:"
	_capture_stack.add_child(_capture_description_label)

	_capture_description_edit = TextEdit.new()
	_capture_description_edit.name = "CaptureDescriptionEdit"
	_capture_description_edit.placeholder_text = "What did you expect? What happened instead? Why is it confusing or incorrect?"
	_capture_description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_capture_description_edit.text_changed.connect(_on_capture_description_changed)
	_capture_stack.add_child(_capture_description_edit)

	var capture_action_row := HBoxContainer.new()
	capture_action_row.name = "CaptureActionRow"
	capture_action_row.alignment = BoxContainer.ALIGNMENT_END
	capture_action_row.add_theme_constant_override("separation", 10)
	_capture_stack.add_child(capture_action_row)

	_capture_cancel_button = Button.new()
	_capture_cancel_button.name = "CaptureCancelButton"
	_capture_cancel_button.text = "Cancel"
	_capture_cancel_button.pressed.connect(_on_capture_cancel_pressed)
	capture_action_row.add_child(_capture_cancel_button)

	_capture_save_button = Button.new()
	_capture_save_button.name = "CaptureSaveButton"
	_capture_save_button.text = "Save Issue"
	_capture_save_button.disabled = true
	_capture_save_button.pressed.connect(_on_capture_save_pressed)
	capture_action_row.add_child(_capture_save_button)

	_review_panel = PanelContainer.new()
	_review_panel.name = "ReviewPanel"
	_review_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_review_panel.visible = false
	_root.add_child(_review_panel)

	var review_margin := MarginContainer.new()
	review_margin.name = "ReviewMargin"
	review_margin.add_theme_constant_override("margin_left", 18)
	review_margin.add_theme_constant_override("margin_top", 18)
	review_margin.add_theme_constant_override("margin_right", 18)
	review_margin.add_theme_constant_override("margin_bottom", 18)
	_review_panel.add_child(review_margin)

	var review_stack := VBoxContainer.new()
	review_stack.name = "ReviewStack"
	review_stack.add_theme_constant_override("separation", 12)
	review_margin.add_child(review_stack)

	var review_heading_row := HBoxContainer.new()
	review_heading_row.name = "ReviewHeadingRow"
	review_heading_row.add_theme_constant_override("separation", 10)
	review_stack.add_child(review_heading_row)

	_review_heading_label = Label.new()
	_review_heading_label.name = "ReviewHeadingLabel"
	_review_heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_heading_label.text = "Captured Issues"
	review_heading_row.add_child(_review_heading_label)

	_review_close_button = Button.new()
	_review_close_button.name = "ReviewCloseButton"
	_review_close_button.text = "Close"
	_review_close_button.pressed.connect(_on_review_close_pressed)
	review_heading_row.add_child(_review_close_button)

	_review_status_label = Label.new()
	_review_status_label.name = "ReviewStatusLabel"
	review_stack.add_child(_review_status_label)

	_review_scroll = ScrollContainer.new()
	_review_scroll.name = "ReviewScroll"
	review_stack.add_child(_review_scroll)

	_review_list = VBoxContainer.new()
	_review_list.name = "ReviewList"
	_review_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_list.add_theme_constant_override("separation", 10)
	_review_scroll.add_child(_review_list)

	_review_empty_label = Label.new()
	_review_empty_label.name = "ReviewEmptyLabel"
	_review_empty_label.text = "No issues captured yet."
	_review_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_list.add_child(_review_empty_label)

	var review_action_row := HBoxContainer.new()
	review_action_row.name = "ReviewActionRow"
	review_action_row.alignment = BoxContainer.ALIGNMENT_END
	review_action_row.add_theme_constant_override("separation", 10)
	review_stack.add_child(review_action_row)

	_review_clear_button = Button.new()
	_review_clear_button.name = "ReviewClearButton"
	_review_clear_button.text = "Clear All"
	_review_clear_button.pressed.connect(_on_review_clear_pressed)
	review_action_row.add_child(_review_clear_button)

func _coordinate_text(click_context: Dictionary) -> String:
	var pixel_position: Dictionary = click_context.get("pixel_position", {}) as Dictionary
	var normalized_position: Dictionary = click_context.get("normalized_position", {}) as Dictionary
	return "Clicked at (%d, %d) | %.1f%% x %.1f%% of the viewport" % [
		int(pixel_position.get("x", 0)),
		int(pixel_position.get("y", 0)),
		float(normalized_position.get("x", 0.0)) * 100.0,
		float(normalized_position.get("y", 0.0)) * 100.0
	]

func _refresh_review_list() -> void:
	for child in _review_list.get_children():
		child.queue_free()
	_review_empty_label = Label.new()
	_review_empty_label.name = "ReviewEmptyLabel"
	_review_empty_label.text = "No issues captured yet." if _review_issues.is_empty() else ""
	_review_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(_review_empty_label, SurveyStyle.TEXT_MUTED)
	_review_list.add_child(_review_empty_label)
	_review_status_label.text = "%d captured issue(s) in this debug session." % _review_issues.size()
	_review_clear_button.disabled = _review_issues.is_empty()
	if _review_issues.is_empty():
		return
	for issue_variant in _review_issues:
		if not (issue_variant is Dictionary):
			continue
		_review_list.add_child(_build_issue_row(issue_variant as Dictionary))
	_review_scroll.scroll_vertical = 0

func _build_issue_row(issue: Dictionary) -> Control:
	var compact_layout: bool = _is_compact_sheet_viewport(_effective_viewport_size())
	var row := PanelContainer.new()
	row.name = "IssueRow_%s" % str(issue.get("id", "issue")).strip_edges()
	SurveyStyle.apply_panel(row, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	row.add_child(margin)
	var content: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var screenshot_image: Image = issue.get("_screenshot_image") as Image
	var thumb := TextureRect.new()
	thumb.name = "IssueThumbnail"
	thumb.custom_minimum_size = Vector2(128.0, 96.0) if not compact_layout else Vector2(0.0, 120.0)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if screenshot_image != null and not screenshot_image.is_empty():
		thumb.texture = ImageTexture.create_from_image(screenshot_image)
	content.add_child(thumb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	content.add_child(info)

	var title := Label.new()
	title.name = "IssueTitleLabel"
	title.text = "%s | %s" % [
		str(issue.get("id", "issue")).strip_edges(),
		str(issue.get("timestamp", "")).strip_edges()
	]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_heading(title, 16)
	info.add_child(title)

	var page := Label.new()
	page.name = "IssuePageLabel"
	page.text = str(issue.get("page_summary", "")).strip_edges()
	page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(page, SurveyStyle.TEXT_PRIMARY)
	info.add_child(page)

	var target := Label.new()
	target.name = "IssueTargetLabel"
	target.text = str(issue.get("target_summary", "")).strip_edges()
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_body(target)
	info.add_child(target)

	var description := Label.new()
	description.name = "IssueDescriptionLabel"
	description.text = _truncate_text(str(issue.get("description", "")).strip_edges(), 220)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(description, SurveyStyle.TEXT_MUTED)
	info.add_child(description)

	var delete_button := Button.new()
	delete_button.name = "IssueDeleteButton"
	delete_button.text = "Delete"
	SurveyStyle.apply_danger_button(delete_button)
	delete_button.pressed.connect(_on_review_delete_pressed.bind(str(issue.get("id", "")).strip_edges()))
	if compact_layout:
		var action_row := HBoxContainer.new()
		action_row.alignment = BoxContainer.ALIGNMENT_END
		info.add_child(action_row)
		action_row.add_child(delete_button)
	else:
		content.add_child(delete_button)
	return row

func _truncate_text(text: String, max_length: int) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return "%s..." % trimmed.substr(0, max_length - 3)

func _reposition_visible_panels() -> void:
	if not has_open_ui():
		return
	var viewport_size: Vector2 = _effective_viewport_size()
	var compact_sheet: bool = _is_compact_sheet_viewport(viewport_size)
	if _armed_panel.visible:
		_armed_panel.reset_size()
		var armed_size: Vector2 = _armed_panel.get_combined_minimum_size()
		_armed_panel.position = _sheet_or_centered_position(viewport_size, armed_size, compact_sheet)
	if _capture_panel.visible:
		_capture_panel.reset_size()
		var capture_size: Vector2 = _capture_panel.get_combined_minimum_size()
		if compact_sheet:
			_capture_panel.position = _sheet_or_centered_position(viewport_size, capture_size, true)
		else:
			var preferred_position: Vector2 = _capture_anchor_position + Vector2(18.0, 18.0)
			if preferred_position.x + capture_size.x > viewport_size.x - SAFE_MARGIN:
				preferred_position.x = _capture_anchor_position.x - capture_size.x - 18.0
			if preferred_position.y + capture_size.y > viewport_size.y - SAFE_MARGIN:
				preferred_position.y = _capture_anchor_position.y - capture_size.y - 18.0
			preferred_position.x = clampf(preferred_position.x, SAFE_MARGIN, maxf(SAFE_MARGIN, viewport_size.x - capture_size.x - SAFE_MARGIN))
			preferred_position.y = clampf(preferred_position.y, SAFE_MARGIN, maxf(SAFE_MARGIN, viewport_size.y - capture_size.y - SAFE_MARGIN))
			_capture_panel.position = preferred_position
	if _review_panel.visible:
		_review_panel.reset_size()
		var review_size: Vector2 = _review_panel.get_combined_minimum_size()
		_review_panel.position = _sheet_or_centered_position(viewport_size, review_size, compact_sheet)

func _sheet_or_centered_position(viewport_size: Vector2, panel_size: Vector2, compact_sheet: bool) -> Vector2:
	if compact_sheet:
		return Vector2(
			SAFE_MARGIN,
			clampf(viewport_size.y - panel_size.y - SAFE_MARGIN, SAFE_MARGIN, maxf(SAFE_MARGIN, viewport_size.y - panel_size.y - SAFE_MARGIN))
		)
	return Vector2(
		clampf((viewport_size.x - panel_size.x) * 0.5, SAFE_MARGIN, maxf(SAFE_MARGIN, viewport_size.x - panel_size.x - SAFE_MARGIN)),
		clampf((viewport_size.y - panel_size.y) * 0.5, SAFE_MARGIN, maxf(SAFE_MARGIN, viewport_size.y - panel_size.y - SAFE_MARGIN))
	)

func _focus_description_field() -> void:
	if not _capture_panel.visible:
		return
	_capture_description_edit.grab_focus()

func _effective_viewport_size() -> Vector2:
	if _layout_viewport_size != Vector2.ZERO:
		return _layout_viewport_size
	return get_viewport().get_visible_rect().size

func _is_compact_sheet_viewport(viewport_size: Vector2) -> bool:
	return viewport_size.x <= COMPACT_VIEWPORT_WIDTH

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if _armed_panel.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _capture_panel.visible:
				_on_capture_cancel_pressed()
			elif _review_panel.visible:
				_on_review_close_pressed()

func _on_armed_cancel_pressed() -> void:
	close_active()

func _on_capture_description_changed() -> void:
	_capture_save_button.disabled = _capture_description_edit.text.strip_edges().is_empty()

func _on_capture_cancel_pressed() -> void:
	capture_cancelled.emit()

func _on_capture_save_pressed() -> void:
	var description: String = _capture_description_edit.text.strip_edges()
	if description.is_empty():
		return
	capture_saved.emit(description)

func _on_review_close_pressed() -> void:
	close_active()

func _on_review_clear_pressed() -> void:
	review_clear_all_requested.emit()

func _on_review_delete_pressed(issue_id: String) -> void:
	if issue_id.is_empty():
		return
	review_delete_requested.emit(issue_id)
