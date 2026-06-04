class_name SurveyQaOverlay
extends CanvasLayer

signal start_guided_requested
signal resume_requested
signal export_bundle_requested
signal export_visual_audit_requested
signal open_tutorial_requested
signal home_requested
signal close_requested
signal switch_surface_requested(target_surface_id: String)
signal page_selected(page_node_id: String)
signal capture_requested(reason: String)
signal focus_item_requested(item_id: String)
signal auto_item_requested(item_id: String)
signal item_status_requested(item_id: String, status: String)
signal tutorial_feedback_action_requested(action_id: String)

const COMPACT_WIDTH := 720.0

var _current_view := "home"
var _selected_page_node_id := ""
var _state: Dictionary = {}
var _item_rows: Dictionary = {}
var _page_ids: Array[String] = []

var _root: Control
var _panel: PanelContainer
var _stack: VBoxContainer
var _top_row: HBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _close_button: Button
var _status_label: Label
var _home_view: VBoxContainer
var _home_summary_label: Label
var _home_actions: GridContainer
var _start_button: Button
var _tutorial_button: Button
var _export_button: Button
var _visual_audit_button: Button
var _resume_button: Button
var _switch_surface_button: Button
var _tutorial_view: VBoxContainer
var _tutorial_body_label: Label
var _tutorial_actions: HFlowContainer
var _tutorial_capture_button: Button
var _tutorial_review_button: Button
var _tutorial_download_button: Button
var _tutorial_back_button: Button
var _checklist_view: VBoxContainer
var _page_row: HBoxContainer
var _page_prev_button: Button
var _page_picker: OptionButton
var _page_next_button: Button
var _page_title_label: Label
var _page_description_label: Label
var _page_status_label: Label
var _checklist_actions: HFlowContainer
var _capture_button: Button
var _checklist_export_button: Button
var _checklist_visual_audit_button: Button
var _checklist_home_button: Button
var _items_scroll: ScrollContainer
var _items_list: VBoxContainer

func _ready() -> void:
	layer = 70
	visible = false
	_build_ui()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if _panel == null:
		return
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.style_heading(_title_label, 22)
	SurveyStyle.style_caption(_subtitle_label, SurveyStyle.ACCENT_ALT)
	SurveyStyle.style_caption(_status_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.apply_secondary_button(_close_button)
	SurveyStyle.style_body(_home_summary_label)
	SurveyStyle.style_body(_tutorial_body_label)
	SurveyStyle.style_heading(_page_title_label, 18)
	SurveyStyle.style_body(_page_description_label)
	SurveyStyle.style_caption(_page_status_label, SurveyStyle.TEXT_PRIMARY)
	for button in [_start_button, _export_button, _capture_button, _checklist_export_button]:
		if button != null:
			SurveyStyle.apply_primary_button(button)
	for button in [_visual_audit_button, _checklist_visual_audit_button, _tutorial_button, _resume_button, _switch_surface_button, _tutorial_capture_button, _tutorial_review_button, _tutorial_download_button, _tutorial_back_button, _page_prev_button, _page_next_button, _checklist_home_button]:
		if button != null:
			SurveyStyle.apply_secondary_button(button)
	if _page_picker != null:
		SurveyStyle.style_option_button(_page_picker)
	for row_value in _item_rows.values():
		if row_value is Dictionary:
			_style_item_row(row_value as Dictionary)

func refresh_layout(viewport_size: Vector2) -> void:
	if _root == null or _panel == null:
		return
	_root.size = viewport_size
	var compact_layout := viewport_size.x <= COMPACT_WIDTH
	var horizontal_inset := clampf(viewport_size.x * 0.03, 12.0, 28.0)
	var vertical_inset := clampf(viewport_size.y * 0.03, 12.0, 28.0)
	var panel_width := viewport_size.x - (horizontal_inset * 2.0) if compact_layout else clampf(viewport_size.x * 0.34, 340.0, 500.0)
	var panel_height := clampf(viewport_size.y - (vertical_inset * 2.0), 320.0, 820.0)
	_panel.position = Vector2(horizontal_inset, vertical_inset)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_stack.add_theme_constant_override("separation", 10 if compact_layout else 12)
	_top_row.add_theme_constant_override("separation", 8)
	_home_actions.columns = 1 if compact_layout else 2
	_checklist_actions.add_theme_constant_override("h_separation", 8)
	_checklist_actions.add_theme_constant_override("v_separation", 8)
	_tutorial_actions.add_theme_constant_override("h_separation", 8)
	_tutorial_actions.add_theme_constant_override("v_separation", 8)
	_items_scroll.custom_minimum_size = Vector2(0.0, maxf(panel_height - 280.0, 180.0))
	if _page_row != null:
		_page_row.add_theme_constant_override("separation", 8)

func open_home(state: Dictionary) -> void:
	_current_view = "home"
	set_meta("qa_view", _current_view)
	_state = state.duplicate(true)
	visible = true
	_home_view.visible = true
	_tutorial_view.visible = false
	_checklist_view.visible = false
	_apply_home_state()

func open_tutorial(state: Dictionary) -> void:
	_current_view = "tutorial"
	set_meta("qa_view", _current_view)
	_state = state.duplicate(true)
	visible = true
	_home_view.visible = false
	_tutorial_view.visible = true
	_checklist_view.visible = false
	_apply_tutorial_state()

func open_checklist(state: Dictionary) -> void:
	_current_view = "checklist"
	set_meta("qa_view", _current_view)
	_state = state.duplicate(true)
	visible = true
	_home_view.visible = false
	_tutorial_view.visible = false
	_checklist_view.visible = true
	_selected_page_node_id = str(_state.get("selected_page_node_id", "")).strip_edges()
	_apply_checklist_state()

func refresh_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	match _current_view:
		"tutorial":
			_apply_tutorial_state()
		"checklist":
			_apply_checklist_state()
		_:
			_apply_home_state()

func close_overlay() -> void:
	visible = false
	close_requested.emit()

func _build_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "QaOverlayRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "QaPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	margin.add_child(_stack)

	_top_row = HBoxContainer.new()
	_top_row.name = "TopRow"
	_stack.add_child(_top_row)

	var heading_stack := VBoxContainer.new()
	heading_stack.name = "HeadingStack"
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	_top_row.add_child(heading_stack)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "QA Guide"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_stack.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = "Guided testing"
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_stack.add_child(_subtitle_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Hide"
	_close_button.pressed.connect(close_overlay)
	_top_row.add_child(_close_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_status_label)

	_build_home_view()
	_build_tutorial_view()
	_build_checklist_view()

func _build_home_view() -> void:
	_home_view = VBoxContainer.new()
	_home_view.name = "HomeView"
	_home_view.add_theme_constant_override("separation", 10)
	_stack.add_child(_home_view)

	_home_summary_label = Label.new()
	_home_summary_label.name = "HomeSummaryLabel"
	_home_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_view.add_child(_home_summary_label)

	_home_actions = GridContainer.new()
	_home_actions.name = "HomeActions"
	_home_actions.columns = 2
	_home_actions.add_theme_constant_override("h_separation", 10)
	_home_actions.add_theme_constant_override("v_separation", 10)
	_home_view.add_child(_home_actions)

	_start_button = _build_button("StartGuidedButton", "Start Guided Test", _on_start_guided_pressed)
	_tutorial_button = _build_button("TutorialButton", "How To Report An Issue", _on_tutorial_pressed)
	_export_button = _build_button("ExportBundleButton", "Export QA Bundle", _on_export_bundle_pressed)
	_visual_audit_button = _build_button("ExportVisualAuditButton", "Export Visual Audit", _on_export_visual_audit_pressed)
	_resume_button = _build_button("ResumeButton", "Resume Last Session", _on_resume_pressed)
	_switch_surface_button = _build_button("SwitchSurfaceButton", "Switch Surface", _on_switch_surface_pressed)
	_home_actions.add_child(_start_button)
	_home_actions.add_child(_tutorial_button)
	_home_actions.add_child(_export_button)
	_home_actions.add_child(_visual_audit_button)
	_home_actions.add_child(_resume_button)
	_home_actions.add_child(_switch_surface_button)

func _build_tutorial_view() -> void:
	_tutorial_view = VBoxContainer.new()
	_tutorial_view.name = "TutorialView"
	_tutorial_view.visible = false
	_tutorial_view.add_theme_constant_override("separation", 10)
	_stack.add_child(_tutorial_view)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.name = "TutorialBodyLabel"
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_view.add_child(_tutorial_body_label)

	_tutorial_actions = HFlowContainer.new()
	_tutorial_actions.name = "TutorialActions"
	_tutorial_actions.add_theme_constant_override("h_separation", 10)
	_tutorial_actions.add_theme_constant_override("v_separation", 10)
	_tutorial_view.add_child(_tutorial_actions)

	_tutorial_capture_button = _build_button("TutorialCaptureButton", "Start Issue Tagging", _on_tutorial_capture_pressed)
	_tutorial_review_button = _build_button("TutorialReviewButton", "Open Issue Review", _on_tutorial_review_pressed)
	_tutorial_download_button = _build_button("TutorialDownloadButton", "Export Feedback ZIP", _on_tutorial_download_pressed)
	_tutorial_back_button = _build_button("TutorialBackButton", "Back To Home", _on_tutorial_back_pressed)
	_tutorial_actions.add_child(_tutorial_capture_button)
	_tutorial_actions.add_child(_tutorial_review_button)
	_tutorial_actions.add_child(_tutorial_download_button)
	_tutorial_actions.add_child(_tutorial_back_button)

func _build_checklist_view() -> void:
	_checklist_view = VBoxContainer.new()
	_checklist_view.name = "ChecklistView"
	_checklist_view.visible = false
	_checklist_view.add_theme_constant_override("separation", 10)
	_stack.add_child(_checklist_view)

	_page_row = HBoxContainer.new()
	_page_row.name = "PageRow"
	_checklist_view.add_child(_page_row)

	_page_prev_button = _build_button("PagePrevButton", "<", _on_page_prev_pressed)
	_page_prev_button.custom_minimum_size = Vector2(42.0, 42.0)
	_page_row.add_child(_page_prev_button)

	_page_picker = OptionButton.new()
	_page_picker.name = "PagePicker"
	_page_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_picker.item_selected.connect(_on_page_picker_item_selected)
	_page_row.add_child(_page_picker)

	_page_next_button = _build_button("PageNextButton", ">", _on_page_next_pressed)
	_page_next_button.custom_minimum_size = Vector2(42.0, 42.0)
	_page_row.add_child(_page_next_button)

	_page_title_label = Label.new()
	_page_title_label.name = "PageTitleLabel"
	_page_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checklist_view.add_child(_page_title_label)

	_page_description_label = Label.new()
	_page_description_label.name = "PageDescriptionLabel"
	_page_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checklist_view.add_child(_page_description_label)

	_page_status_label = Label.new()
	_page_status_label.name = "PageStatusLabel"
	_page_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checklist_view.add_child(_page_status_label)

	_checklist_actions = HFlowContainer.new()
	_checklist_actions.name = "ChecklistActions"
	_checklist_view.add_child(_checklist_actions)

	_capture_button = _build_button("CapturePageButton", "Capture Current Page", _on_capture_page_pressed)
	_checklist_export_button = _build_button("ChecklistExportButton", "Export QA Bundle", _on_export_bundle_pressed)
	_checklist_visual_audit_button = _build_button("ChecklistVisualAuditButton", "Export Visual Audit", _on_export_visual_audit_pressed)
	_checklist_home_button = _build_button("ChecklistHomeButton", "Back To Home", _on_checklist_home_pressed)
	_checklist_actions.add_child(_capture_button)
	_checklist_actions.add_child(_checklist_export_button)
	_checklist_actions.add_child(_checklist_visual_audit_button)
	_checklist_actions.add_child(_checklist_home_button)

	_items_scroll = ScrollContainer.new()
	_items_scroll.name = "ItemsScroll"
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_checklist_view.add_child(_items_scroll)

	_items_list = VBoxContainer.new()
	_items_list.name = "ItemsList"
	_items_list.add_theme_constant_override("separation", 10)
	_items_scroll.add_child(_items_list)

func _build_button(name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(callback)
	return button

func _apply_home_state() -> void:
	_title_label.text = str(_state.get("title", "QA Guide")).strip_edges()
	_subtitle_label.text = str(_state.get("subtitle", "Guided testing")).strip_edges()
	_status_label.text = str(_state.get("status_text", "")).strip_edges()
	_home_summary_label.text = str(_state.get("summary_text", "")).strip_edges()
	_resume_button.disabled = not bool(_state.get("can_resume", false))
	_resume_button.text = str(_state.get("resume_label", "Resume Last Session")).strip_edges()
	var switch_label := str(_state.get("switch_surface_label", "")).strip_edges()
	_switch_surface_button.visible = not switch_label.is_empty()
	_switch_surface_button.disabled = switch_label.is_empty()
	if not switch_label.is_empty():
		_switch_surface_button.text = switch_label
		_switch_surface_button.set_meta("target_surface_id", str(_state.get("switch_surface_id", "")).strip_edges())

func _apply_tutorial_state() -> void:
	_title_label.text = str(_state.get("title", "How To Report An Issue")).strip_edges()
	_subtitle_label.text = str(_state.get("subtitle", "Use the feedback system")).strip_edges()
	_status_label.text = str(_state.get("status_text", "")).strip_edges()
	_tutorial_body_label.text = str(_state.get("tutorial_text", "")).strip_edges()
	_tutorial_download_button.disabled = not bool(_state.get("can_export_feedback_zip", false))

func _apply_checklist_state() -> void:
	_title_label.text = str(_state.get("title", "Guided QA Checklist")).strip_edges()
	_subtitle_label.text = str(_state.get("subtitle", "Expected behavior by page")).strip_edges()
	_status_label.text = str(_state.get("status_text", "")).strip_edges()
	var sections_value: Variant = _state.get("sections", [])
	var sections: Array = sections_value if sections_value is Array else []
	_page_ids.clear()
	_page_picker.clear()
	for section_value in sections:
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value as Dictionary
		var page_node_id := str(section.get("page_node_id", "")).strip_edges()
		if page_node_id.is_empty():
			continue
		_page_ids.append(page_node_id)
		_page_picker.add_item(str(section.get("title", page_node_id)).strip_edges())
		_page_picker.set_item_metadata(_page_picker.item_count - 1, page_node_id)
	if _selected_page_node_id.is_empty() and not _page_ids.is_empty():
		_selected_page_node_id = _page_ids[0]
	var selected_index := maxi(_page_ids.find(_selected_page_node_id), 0)
	if _page_picker.item_count > 0:
		_page_picker.select(selected_index)
		_selected_page_node_id = str(_page_picker.get_item_metadata(selected_index)).strip_edges()
	_page_prev_button.disabled = selected_index <= 0
	_page_next_button.disabled = selected_index < 0 or selected_index >= _page_ids.size() - 1
	var selected_section := _selected_section_dict(sections)
	_page_title_label.text = str(selected_section.get("title", "Checklist")).strip_edges()
	_page_description_label.text = str(selected_section.get("description", "")).strip_edges()
	_page_status_label.text = str(_state.get("page_status_text", "")).strip_edges()
	_rebuild_item_rows(selected_section.get("items", []) as Array)

func _selected_section_dict(sections: Array) -> Dictionary:
	for section_value in sections:
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value as Dictionary
		if str(section.get("page_node_id", "")).strip_edges() == _selected_page_node_id:
			return section
	if not sections.is_empty() and sections[0] is Dictionary:
		return sections[0] as Dictionary
	return {}

func _rebuild_item_rows(items: Array) -> void:
	_item_rows.clear()
	for child in _items_list.get_children():
		child.queue_free()
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value as Dictionary
		var row := _build_item_row(item)
		_items_list.add_child(row.get("panel"))
		_item_rows[str(item.get("id", ""))] = row
		_style_item_row(row)

func _build_item_row(item: Dictionary) -> Dictionary:
	var item_id := str(item.get("id", "")).strip_edges()
	var panel := PanelContainer.new()
	panel.name = "Item_%s" % item_id

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = str(item.get("label", "")).strip_edges()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)

	var expected := Label.new()
	expected.name = "ExpectedLabel"
	expected.text = str(item.get("expected_result", "")).strip_edges()
	expected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(expected)

	var note := Label.new()
	note.name = "NoteLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)

	var status := Label.new()
	status.name = "StatusLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status)

	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	stack.add_child(actions)

	var focus_button := _build_item_action_button("Focus Me", _on_item_focus_pressed.bind(item_id))
	var auto_button := _build_item_action_button("Try For Me", _on_item_auto_pressed.bind(item_id))
	var pass_button := _build_item_action_button("Pass", _on_item_status_pressed.bind(item_id, "pass"))
	var fail_button := _build_item_action_button("Fail", _on_item_status_pressed.bind(item_id, "fail"))
	var skip_button := _build_item_action_button("Skip", _on_item_status_pressed.bind(item_id, "skip"))
	actions.add_child(focus_button)
	actions.add_child(auto_button)
	actions.add_child(pass_button)
	actions.add_child(fail_button)
	actions.add_child(skip_button)

	return {
		"panel": panel,
		"title": title,
		"expected": expected,
		"note": note,
		"status": status,
		"focus_button": focus_button,
		"auto_button": auto_button,
		"pass_button": pass_button,
		"fail_button": fail_button,
		"skip_button": skip_button,
		"item": item.duplicate(true)
	}

func _build_item_action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.pressed.connect(callback)
	return button

func _style_item_row(row: Dictionary) -> void:
	var item: Dictionary = row.get("item", {}) as Dictionary
	var panel := row.get("panel") as PanelContainer
	var title := row.get("title") as Label
	var expected := row.get("expected") as Label
	var note := row.get("note") as Label
	var status_label := row.get("status") as Label
	var focus_button := row.get("focus_button") as Button
	var auto_button := row.get("auto_button") as Button
	var pass_button := row.get("pass_button") as Button
	var fail_button := row.get("fail_button") as Button
	var skip_button := row.get("skip_button") as Button
	if panel != null:
		SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	if title != null:
		SurveyStyle.style_heading(title, 16)
	if expected != null:
		SurveyStyle.style_body(expected)
	if note != null:
		SurveyStyle.style_caption(note, SurveyStyle.TEXT_MUTED)
	if status_label != null:
		SurveyStyle.style_caption(status_label, _status_color(str(item.get("status", "pending")).strip_edges()))
	var note_lines: Array[String] = []
	var manual_reason := str(item.get("manual_reason", "")).strip_edges()
	var conditional_message := str(item.get("conditional_message", "")).strip_edges()
	if not manual_reason.is_empty():
		note_lines.append("Manual-only: %s" % manual_reason)
	if not conditional_message.is_empty():
		note_lines.append(conditional_message)
	if note != null:
		note.visible = not note_lines.is_empty()
		note.text = "\n".join(note_lines)
	if status_label != null:
		status_label.text = _item_status_text(item)
	if focus_button != null:
		SurveyStyle.apply_secondary_button(focus_button)
	if auto_button != null:
		SurveyStyle.apply_secondary_button(auto_button)
		auto_button.disabled = str(item.get("auto_action_id", "")).strip_edges().is_empty()
	if pass_button != null:
		SurveyStyle.apply_primary_button(pass_button)
	if fail_button != null:
		SurveyStyle.apply_danger_button(fail_button)
	if skip_button != null:
		SurveyStyle.apply_secondary_button(skip_button)

func _item_status_text(item: Dictionary) -> String:
	var status := str(item.get("status", "pending")).strip_edges().to_lower()
	match status:
		"pass":
			return "Status: Passed"
		"fail":
			return "Status: Failed"
		"skip":
			return "Status: Skipped"
	return "Status: Pending"

func _status_color(status: String) -> Color:
	match status.to_lower():
		"pass":
			return SurveyStyle.SUCCESS
		"fail":
			return SurveyStyle.DANGER
		"skip":
			return SurveyStyle.TEXT_MUTED
	return SurveyStyle.TEXT_PRIMARY

func _on_start_guided_pressed() -> void:
	start_guided_requested.emit()

func _on_tutorial_pressed() -> void:
	open_tutorial_requested.emit()

func _on_export_bundle_pressed() -> void:
	export_bundle_requested.emit()

func _on_export_visual_audit_pressed() -> void:
	export_visual_audit_requested.emit()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_switch_surface_pressed() -> void:
	var target_surface_id := str(_switch_surface_button.get_meta("target_surface_id", "")).strip_edges()
	if target_surface_id.is_empty():
		return
	switch_surface_requested.emit(target_surface_id)

func _on_tutorial_capture_pressed() -> void:
	tutorial_feedback_action_requested.emit("capture")

func _on_tutorial_review_pressed() -> void:
	tutorial_feedback_action_requested.emit("review")

func _on_tutorial_download_pressed() -> void:
	tutorial_feedback_action_requested.emit("download")

func _on_tutorial_back_pressed() -> void:
	home_requested.emit()

func _on_page_prev_pressed() -> void:
	var current_index := _page_ids.find(_selected_page_node_id)
	if current_index <= 0:
		return
	_selected_page_node_id = _page_ids[current_index - 1]
	page_selected.emit(_selected_page_node_id)

func _on_page_next_pressed() -> void:
	var current_index := _page_ids.find(_selected_page_node_id)
	if current_index < 0 or current_index >= _page_ids.size() - 1:
		return
	_selected_page_node_id = _page_ids[current_index + 1]
	page_selected.emit(_selected_page_node_id)

func _on_page_picker_item_selected(index: int) -> void:
	if index < 0 or index >= _page_picker.item_count:
		return
	_selected_page_node_id = str(_page_picker.get_item_metadata(index)).strip_edges()
	page_selected.emit(_selected_page_node_id)

func _on_capture_page_pressed() -> void:
	capture_requested.emit("manual_page_capture")

func _on_checklist_home_pressed() -> void:
	home_requested.emit()

func _on_item_focus_pressed(item_id: String) -> void:
	focus_item_requested.emit(item_id)

func _on_item_auto_pressed(item_id: String) -> void:
	auto_item_requested.emit(item_id)

func _on_item_status_pressed(item_id: String, status: String) -> void:
	item_status_requested.emit(item_id, status)
