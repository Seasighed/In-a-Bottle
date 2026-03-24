class_name RankedChoiceQuestionView
extends SurveyQuestionView

@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _rank_list: VBoxContainer = $Panel/Stack/RankList

var _order: Array[String] = []
var _primary_control: Control
var _drag_index := -1
var _drop_slot := -1
var _rank_list_rebuild_queued := false
var _rank_list_layout_refresh_queued := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SurveyStyle.style_heading(_title_label, 21)
	SurveyStyle.style_body(_description_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.gui_input.connect(_on_panel_gui_input)
	set_process_input(true)
	super()

func _input(event: InputEvent) -> void:
	if _drag_index < 0:
		return
	if event is InputEventMouseMotion:
		_update_drag_target(get_global_mouse_position().y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()

func _apply_question() -> void:
	if question == null:
		return

	_title_label.text = question.display_prompt()
	_description_label.text = question.description if not question.description.is_empty() else "Drag options into the order you want."
	_order = _build_rank_order()
	_cancel_drag()
	_rebuild_rank_list()
	_apply_selection_state()
	_refresh_layout_metrics()

func _apply_selection_state() -> void:
	var border_color := SurveyStyle.ACCENT if is_selected else SurveyStyle.ACCENT_ALT
	var fill_color := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE_ALT
	SurveyStyle.apply_panel(_panel, fill_color, border_color, 22, 1)

func focus_primary_control() -> void:
	if _primary_control != null:
		_primary_control.grab_focus()

func _build_rank_order() -> Array[String]:
	var ordered: Array[String] = []
	if current_value is Array:
		for item in current_value:
			var value: String = str(item)
			if question.options.has(value) and not ordered.has(value):
				ordered.append(value)
	for option in question.options:
		if not ordered.has(option):
			ordered.append(option)
	return ordered

func _rebuild_rank_list() -> void:
	for child in _rank_list.get_children():
		_rank_list.remove_child(child)
		child.queue_free()
	_primary_control = null

	var preview_index: int = _effective_drop_index()
	for index in range(_order.size()):
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row_panel.focus_mode = Control.FOCUS_ALL
		_apply_rank_row_style(row_panel, index == _drag_index, preview_index == index and index != _drag_index)
		row_panel.gui_input.connect(_on_row_gui_input.bind(index, row_panel))
		row_panel.mouse_entered.connect(_on_row_mouse_entered)
		row_panel.focus_entered.connect(_on_row_focus_entered)

		var row := HBoxContainer.new()
		row.layout_mode = 2
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)

		var badge := Label.new()
		badge.custom_minimum_size = Vector2(28, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.text = "%d" % [index + 1]
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_heading(badge, 18, SurveyStyle.ACCENT)

		var option_label := Label.new()
		option_label.text = _order[index]
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_body(option_label, SurveyStyle.TEXT_PRIMARY)

		var drag_label := Label.new()
		drag_label.text = "Drag"
		drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_caption(drag_label, SurveyStyle.ACCENT_ALT if index == _drag_index else SurveyStyle.SOFT_WHITE)

		row.add_child(badge)
		row.add_child(option_label)
		row.add_child(drag_label)
		_rank_list.add_child(row_panel)

		if _primary_control == null:
			_primary_control = row_panel

func _queue_rank_list_rebuild(refresh_layout: bool = false) -> void:
	_rank_list_layout_refresh_queued = _rank_list_layout_refresh_queued or refresh_layout
	if _rank_list_rebuild_queued:
		return
	_rank_list_rebuild_queued = true
	call_deferred("_flush_rank_list_rebuild")

func _flush_rank_list_rebuild() -> void:
	_rank_list_rebuild_queued = false
	_rebuild_rank_list()
	if _rank_list_layout_refresh_queued:
		_rank_list_layout_refresh_queued = false
		_refresh_layout_metrics()

func _apply_rank_row_style(row_panel: PanelContainer, is_dragged: bool, is_drop_target: bool) -> void:
	var fill: Color = SurveyStyle.SURFACE_ALT
	var border: Color = SurveyStyle.BORDER
	var border_width := 1
	if is_dragged:
		fill = SurveyStyle.SURFACE_MUTED
		border = SurveyStyle.ACCENT_ALT
		border_width = 2
	elif is_drop_target:
		fill = SurveyStyle.SURFACE_MUTED
		border = SurveyStyle.HIGHLIGHT_GOLD
		border_width = 2
	SurveyStyle.apply_panel(row_panel, fill, border, 16, border_width)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_row_gui_input(event: InputEvent, index: int, row_panel: Control) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_begin_drag(index, row_panel)

func _begin_drag(index: int, row_panel: Control) -> void:
	_drag_index = index
	_drop_slot = index
	SURVEY_UI_FEEDBACK.play_answer_select()
	SURVEY_UI_FEEDBACK.pulse(row_panel, 0.03, 0.12)
	emit_selected()
	_queue_rank_list_rebuild()

func _update_drag_target(mouse_y: float) -> void:
	var new_drop_slot: int = _drop_slot_for_global_y(mouse_y)
	if new_drop_slot == _drop_slot:
		return
	_drop_slot = new_drop_slot
	_queue_rank_list_rebuild()

func _drop_slot_for_global_y(mouse_y: float) -> int:
	var row_count: int = _rank_list.get_child_count()
	if row_count == 0:
		return -1
	for index in range(row_count):
		var row_control := _rank_list.get_child(index) as Control
		if row_control == null:
			continue
		var rect: Rect2 = row_control.get_global_rect()
		var midpoint: float = rect.position.y + rect.size.y * 0.5
		if mouse_y < midpoint:
			return index
	return row_count

func _effective_drop_index() -> int:
	if _drag_index < 0 or _drop_slot < 0 or _order.is_empty():
		return -1
	var effective_index: int = _drop_slot
	if effective_index > _drag_index:
		effective_index -= 1
	return clampi(effective_index, 0, _order.size() - 1)

func _finish_drag() -> void:
	if _drag_index < 0:
		return
	var source_index: int = _drag_index
	var target_index: int = _effective_drop_index()
	_cancel_drag()
	if target_index < 0 or target_index == source_index:
		_queue_rank_list_rebuild(true)
		return
	var value: String = _order[source_index]
	_order.remove_at(source_index)
	if target_index >= _order.size():
		_order.append(value)
	else:
		_order.insert(target_index, value)
	SURVEY_UI_FEEDBACK.play_answer_select()
	SURVEY_UI_FEEDBACK.pulse(_panel, 0.025, 0.16)
	_queue_rank_list_rebuild(true)
	emit_selected()
	emit_answer(_order.duplicate())

func _cancel_drag() -> void:
	_drag_index = -1
	_drop_slot = -1

func _on_row_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _on_row_focus_entered() -> void:
	emit_selected()
