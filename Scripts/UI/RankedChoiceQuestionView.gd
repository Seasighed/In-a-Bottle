class_name RankedChoiceQuestionView
extends SurveyQuestionView

const ROW_BADGE_WIDTH := 28.0
const COMPACT_ROW_BADGE_WIDTH := 24.0
const ACTION_BUTTON_WIDTH := 54.0
const COMPACT_ACTION_BUTTON_WIDTH := 48.0
const ACTION_BUTTON_HEIGHT := 34.0
const COMPACT_ACTION_BUTTON_HEIGHT := 30.0
const ROW_ACTIONS_RESERVED_WIDTH := 170.0
const COMPACT_ROW_ACTIONS_RESERVED_WIDTH := 148.0

@onready var _panel: PanelContainer = $Panel
@onready var _stack: VBoxContainer = $Panel/Stack
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _rank_list: VBoxContainer = $Panel/Stack/RankList

var _order: Array[String] = []
var _primary_control: Control
var _drag_index := -1
var _drop_slot := -1
var _rank_list_rebuild_queued := false
var _rank_list_layout_refresh_queued := false
var _rank_commit_queued := false
var _compact_layout := false
var _focus_top_spacer: Control
var _focus_bottom_spacer: Control
var _row_panels: Array[PanelContainer] = []
var _row_badges: Array[Label] = []
var _row_option_labels: Array[Label] = []
var _row_drag_labels: Array[Label] = []
var _row_move_up_buttons: Array[Button] = []
var _row_move_down_buttons: Array[Button] = []

func _ready() -> void:
	_ensure_focus_spacers()
	configure_question_chrome(_panel, _stack, _title_label, _rank_list)
	SurveyStyle.style_heading(_title_label, 21)
	SurveyStyle.style_body(_description_label)
	_panel.gui_input.connect(_on_panel_gui_input)
	set_process_input(true)
	refresh_responsive_layout(_resolved_viewport_size())
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
	_refresh_description_text()
	_refresh_question_chrome()
	_order = _build_rank_order()
	_cancel_drag()
	_rebuild_rank_list()
	_apply_selection_state()
	refresh_responsive_layout(_resolved_viewport_size())
	_refresh_layout_metrics()
	_refresh_question_chrome()

func _apply_selection_state() -> void:
	if is_focus_presentation():
		var panel_style := SurveyStyle.panel(SurveyStyle.SURFACE, Color(0, 0, 0, 0), 0, 0)
		panel_style.content_margin_left = 24
		panel_style.content_margin_right = 24
		panel_style.content_margin_top = 24
		panel_style.content_margin_bottom = 24
		_panel.add_theme_stylebox_override("panel", panel_style)
		return
	var border_color := SurveyStyle.ACCENT if is_selected else SurveyStyle.ACCENT_ALT
	var fill_color := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE_ALT
	SurveyStyle.apply_panel(_panel, fill_color, border_color, 22, 1)

func focus_primary_control() -> void:
	if _primary_control != null:
		_primary_control.grab_focus()

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	var compact_layout: bool = viewport_size.x <= 640.0
	var focus_layout := is_focus_presentation()
	var centered_focus_layout := uses_centered_focus_layout()
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size) if is_journey_focus_presentation() and compact_layout else 1.0
	_ensure_focus_spacers()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL if centered_focus_layout else Control.SIZE_FILL
	_focus_top_spacer.visible = centered_focus_layout
	_focus_bottom_spacer.visible = centered_focus_layout
	if _compact_layout == compact_layout:
		_apply_responsive_metrics()
		_refresh_description_text()
		_apply_selection_state()
		_refresh_layout_metrics()
		return
	_compact_layout = compact_layout
	_apply_responsive_metrics()
	_refresh_description_text()
	_apply_selection_state()
	if question != null and is_node_ready():
		_queue_rank_list_rebuild(true)
	else:
		_refresh_layout_metrics()

func _ensure_focus_spacers() -> void:
	if _focus_top_spacer == null:
		_focus_top_spacer = Control.new()
		_focus_top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_focus_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stack.add_child(_focus_top_spacer)
		_stack.move_child(_focus_top_spacer, 0)
	if _focus_bottom_spacer == null:
		_focus_bottom_spacer = Control.new()
		_focus_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_focus_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stack.add_child(_focus_bottom_spacer)
	_focus_top_spacer.visible = false
	_focus_bottom_spacer.visible = false

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
	if _row_panels.size() != _order.size():
		_recreate_rank_rows()
	_primary_control = null
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size()) if is_journey_focus_presentation() and _compact_layout else 1.0

	var preview_index: int = _effective_drop_index()
	for index in range(_order.size()):
		var row_panel := _row_panels[index]
		var badge := _row_badges[index]
		var option_label := _row_option_labels[index]
		var drag_label := _row_drag_labels[index]
		var move_up_button := _row_move_up_buttons[index]
		var move_down_button := _row_move_down_buttons[index]
		row_panel.set_meta("rank_row_index", index)
		move_up_button.set_meta("rank_row_index", index)
		move_down_button.set_meta("rank_row_index", index)
		_apply_rank_row_style(row_panel, index == _drag_index, preview_index == index and index != _drag_index)
		badge.custom_minimum_size = Vector2(_badge_width(), 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.text = "%d" % [index + 1]
		SurveyStyle.style_heading(badge, int(round((((18 if _compact_layout else 20) * journey_scale) if is_journey_focus_presentation() else ((20 if _compact_layout else 24) if is_focus_presentation() else (16 if _compact_layout else 18))))), SurveyStyle.ACCENT)
		option_label.text = _order[index]
		SurveyStyle.style_body(option_label, SurveyStyle.TEXT_PRIMARY)
		option_label.add_theme_font_size_override("font_size", int(round((((17 if _compact_layout else 19) * journey_scale) if is_journey_focus_presentation() else ((18 if _compact_layout else 22) if is_focus_presentation() else (14 if _compact_layout else 15))))))
		drag_label.visible = false
		drag_label.text = ""
		move_up_button.disabled = index <= 0
		_style_rank_action_button(move_up_button)
		move_down_button.disabled = index >= _order.size() - 1
		_style_rank_action_button(move_down_button)
		if _primary_control == null:
			_primary_control = row_panel

func _recreate_rank_rows() -> void:
	for child in _rank_list.get_children():
		child.queue_free()
	_row_panels.clear()
	_row_badges.clear()
	_row_option_labels.clear()
	_row_drag_labels.clear()
	_row_move_up_buttons.clear()
	_row_move_down_buttons.clear()
	for _index in range(_order.size()):
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row_panel.focus_mode = Control.FOCUS_ALL
		row_panel.gui_input.connect(_on_row_gui_input.bind(row_panel))
		row_panel.mouse_entered.connect(_on_row_mouse_entered)
		row_panel.focus_entered.connect(_on_row_focus_entered)

		var row := HBoxContainer.new()
		row.layout_mode = 2
		row.add_theme_constant_override("separation", (10 if _compact_layout else 12) if is_journey_focus_presentation() else ((12 if _compact_layout else 16) if is_focus_presentation() else (8 if _compact_layout else 10)))
		var row_stack: VBoxContainer = null
		if _uses_stacked_mobile_actions():
			row_stack = VBoxContainer.new()
			row_stack.layout_mode = 2
			row_stack.add_theme_constant_override("separation", 8)
			row_panel.add_child(row_stack)
			row_stack.add_child(row)
		else:
			row_panel.add_child(row)

		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var option_label := Label.new()
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _uses_stacked_mobile_actions() else Control.SIZE_SHRINK_END
		actions.add_theme_constant_override("separation", 6 if is_journey_focus_presentation() else (8 if is_focus_presentation() else 6))

		var drag_label := Label.new()
		drag_label.text = ""
		drag_label.visible = false
		drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var move_up_button := Button.new()
		move_up_button.text = "Up"
		SurveyStyle.apply_secondary_button(move_up_button)
		move_up_button.pressed.connect(_on_move_up_pressed.bind(move_up_button))
		_wire_rank_button_feedback(move_up_button)

		var move_down_button := Button.new()
		move_down_button.text = "Down"
		SurveyStyle.apply_secondary_button(move_down_button)
		move_down_button.pressed.connect(_on_move_down_pressed.bind(move_down_button))
		_wire_rank_button_feedback(move_down_button)

		row.add_child(badge)
		row.add_child(option_label)
		actions.add_child(drag_label)
		actions.add_child(move_up_button)
		actions.add_child(move_down_button)
		if _uses_stacked_mobile_actions():
			row_stack.add_child(actions)
		else:
			row.add_child(actions)
		_rank_list.add_child(row_panel)

		_row_panels.append(row_panel)
		_row_badges.append(badge)
		_row_option_labels.append(option_label)
		_row_drag_labels.append(drag_label)
		_row_move_up_buttons.append(move_up_button)
		_row_move_down_buttons.append(move_down_button)

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

func _queue_rank_commit() -> void:
	if _rank_commit_queued:
		return
	_rank_commit_queued = true
	call_deferred("_flush_rank_commit")

func _flush_rank_commit() -> void:
	_rank_commit_queued = false
	_queue_rank_list_rebuild(true)
	emit_selected()
	emit_answer(_order.duplicate())

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
	SurveyStyle.apply_panel(row_panel, fill, border, 18 if is_focus_presentation() else 16, border_width)
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size()) if is_journey_focus_presentation() and _compact_layout else 1.0
	if _uses_stacked_mobile_actions():
		row_panel.custom_minimum_size = Vector2(0.0, 112.0 * journey_scale)
	else:
		row_panel.custom_minimum_size = Vector2(0.0, ((76.0 * journey_scale) if is_journey_focus_presentation() else (82.0 if is_focus_presentation() else 0.0)))

func _apply_responsive_metrics() -> void:
	var focus_layout := is_focus_presentation()
	var journey_focus_layout := is_journey_focus_presentation()
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size()) if journey_focus_layout and _compact_layout else 1.0
	_stack.add_theme_constant_override("separation", int(round((((12 if _compact_layout else 16) * journey_scale) if journey_focus_layout else ((16 if _compact_layout else 20) if focus_layout else (8 if _compact_layout else 10))))))
	_rank_list.add_theme_constant_override("separation", int(round((((9 if _compact_layout else 11) * journey_scale) if journey_focus_layout else ((12 if _compact_layout else 16) if focus_layout else (6 if _compact_layout else 8))))))
	SurveyStyle.style_heading(_title_label, int(round((((22 if _compact_layout else 28) * journey_scale) if journey_focus_layout else ((30 if _compact_layout else 38) if focus_layout else (19 if _compact_layout else 21))))))
	SurveyStyle.style_body(_description_label)
	_description_label.add_theme_font_size_override("font_size", int(round((((15 if _compact_layout else 17) * journey_scale) if journey_focus_layout else ((18 if _compact_layout else 22) if focus_layout else 15)))))

func _style_rank_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(_action_button_width(), _action_button_height())
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size()) if is_journey_focus_presentation() and _compact_layout else 1.0
	button.add_theme_font_size_override("font_size", int(round((((14 if _compact_layout else 15) * journey_scale) if is_journey_focus_presentation() else ((15 if _compact_layout else 17) if is_focus_presentation() else (13 if _compact_layout else 14))))))

func _wire_rank_button_feedback(button: Button) -> void:
	button.mouse_entered.connect(_on_row_mouse_entered)
	button.focus_entered.connect(_on_row_focus_entered)

func _badge_width() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (34.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 34.0
		return 34.0 if _compact_layout else 40.0
	return COMPACT_ROW_BADGE_WIDTH if _compact_layout else ROW_BADGE_WIDTH

func _action_button_width() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (58.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 60.0
		return 62.0 if _compact_layout else 70.0
	return COMPACT_ACTION_BUTTON_WIDTH if _compact_layout else ACTION_BUTTON_WIDTH

func _action_button_height() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (38.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 38.0
		return 40.0 if _compact_layout else 46.0
	return COMPACT_ACTION_BUTTON_HEIGHT if _compact_layout else ACTION_BUTTON_HEIGHT

func _row_actions_reserved_width() -> float:
	if _uses_stacked_mobile_actions():
		return 0.0
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return 176.0 if _compact_layout else 196.0
		return 210.0 if _compact_layout else 232.0
	return COMPACT_ROW_ACTIONS_RESERVED_WIDTH if _compact_layout else ROW_ACTIONS_RESERVED_WIDTH

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_row_gui_input(event: InputEvent, row_panel: Control) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var index := _row_index_from_control(row_panel)
		if index < 0:
			return
		if _uses_stacked_mobile_actions():
			emit_selected()
			return
		if mouse_event.position.x >= row_panel.size.x - _row_actions_reserved_width():
			emit_selected()
			return
		_begin_drag(index, row_panel)

func _begin_drag(index: int, row_panel: Control) -> void:
	_drag_index = index
	_drop_slot = index
	SURVEY_UI_FEEDBACK.play_answer_select()
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
	_queue_rank_commit()

func _cancel_drag() -> void:
	_drag_index = -1
	_drop_slot = -1

func _move_rank_item(source_index: int, direction: int) -> void:
	if source_index < 0 or source_index >= _order.size():
		return
	var target_index: int = source_index + direction
	if target_index < 0 or target_index >= _order.size():
		return
	var value: String = _order[source_index]
	_order.remove_at(source_index)
	_order.insert(target_index, value)
	_cancel_drag()
	SURVEY_UI_FEEDBACK.play_answer_select()
	_queue_rank_commit()

func _on_move_up_pressed(button: Button) -> void:
	var index := _row_index_from_control(button)
	if index < 0:
		return
	_move_rank_item(index, -1)

func _on_move_down_pressed(button: Button) -> void:
	var index := _row_index_from_control(button)
	if index < 0:
		return
	_move_rank_item(index, 1)

func _on_row_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _on_row_focus_entered() -> void:
	emit_selected()

func _row_index_from_control(control: Control) -> int:
	if control == null or not is_instance_valid(control):
		return -1
	return int(control.get_meta("rank_row_index", -1))

func _uses_stacked_mobile_actions() -> bool:
	return is_journey_focus_presentation() and _compact_layout

func _refresh_description_text() -> void:
	if question == null:
		return
	if not question.description.is_empty():
		_description_label.text = question.description
		return
	_description_label.text = "Use the arrow buttons to reorder your picks." if _uses_stacked_mobile_actions() else "Drag options into place or use Up and Down to reorder them."
