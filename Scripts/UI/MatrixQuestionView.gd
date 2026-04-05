class_name MatrixQuestionView
extends SurveyQuestionView

const ROW_LABEL_MIN_WIDTH := 220.0
const OPTION_LABEL_MIN_WIDTH := 92.0
const COMPACT_ROW_LABEL_MIN_WIDTH := 144.0
const COMPACT_OPTION_LABEL_MIN_WIDTH := 72.0
const CELL_SIZE := 52.0
const COMPACT_CELL_SIZE := 44.0
const MIN_OPTION_FONT_SIZE := 10
const MIN_ROW_FONT_SIZE := 12
const MIN_MOBILE_VALUE_FONT_SIZE := 12
const LOOT_BOX_RAINBOW_SHADER_CODE := """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.0, 8.0) = 2.4;

void fragment() {
	vec2 uv = UV * vec2(1.2, 0.9);
	float phase = uv.x * 5.4 + uv.y * 2.6 + TIME * speed;
	vec3 rainbow = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.188) + phase * 2.4);
	float vignette = smoothstep(1.2, 0.18, distance(uv, vec2(0.5, 0.5)));
	float alpha = intensity * 0.42 * vignette;
	COLOR = vec4(rainbow, alpha);
}
"""
@onready var _panel: PanelContainer = $Panel
@onready var _stack: VBoxContainer = $Panel/Stack
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _grid_scroll: ScrollContainer = $Panel/Stack/GridScroll
@onready var _grid: GridContainer = $Panel/Stack/GridScroll/Grid
@onready var _mobile_list: VBoxContainer = $Panel/Stack/MobileList

var _answers_by_row: Dictionary = {}
var _cell_panels: Dictionary = {}
var _check_boxes: Dictionary = {}
var _mobile_value_panels: Dictionary = {}
var _mobile_value_labels: Dictionary = {}
var _mobile_value_hint_labels: Dictionary = {}
var _mobile_value_glows: Dictionary = {}
var _mobile_prev_buttons: Dictionary = {}
var _mobile_next_buttons: Dictionary = {}
var _modifier_mobile_display_overrides: Dictionary = {}
var _modifier_mobile_panel_tweens: Dictionary = {}
var _primary_control: Control
var _compact_layout := false
var _use_mobile_cycle_layout := false
var _focus_top_spacer: Control
var _focus_bottom_spacer: Control
var _syncing_row_selection := false

func _ready() -> void:
	_ensure_focus_spacers()
	configure_question_chrome(_panel, _stack, _title_label, _grid_scroll)
	SurveyStyle.style_heading(_title_label, 21)
	SurveyStyle.style_body(_description_label)
	_panel.gui_input.connect(_on_panel_gui_input)
	refresh_responsive_layout(_resolved_viewport_size())
	super()

func _apply_question() -> void:
	if question == null:
		return

	_title_label.text = question.display_prompt()
	_description_label.text = question.description if not question.description.is_empty() else "Choose one answer for each row."
	_refresh_question_chrome()
	_answers_by_row = {}
	if current_value is Dictionary:
		for row_name in question.rows:
			if (current_value as Dictionary).has(row_name):
				_answers_by_row[row_name] = str((current_value as Dictionary).get(row_name, ""))
	_rebuild_active_layout()
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
	var available_width: float = size.x
	if available_width <= 0.0:
		available_width = viewport_size.x - 48.0
	var focus_layout := is_focus_presentation()
	var centered_focus_layout := uses_centered_focus_layout()
	var compact_layout: bool = available_width <= (720.0 if focus_layout else 640.0) or viewport_size.x <= (720.0 if focus_layout else 640.0)
	var mobile_cycle_layout := (is_journey_focus_presentation() and compact_layout) or modifier_requests_layout_hint(&"matrix_cycle_selector")
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size) if is_journey_focus_presentation() and mobile_cycle_layout else 1.0
	_ensure_focus_spacers()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL if centered_focus_layout else Control.SIZE_FILL
	_focus_top_spacer.visible = centered_focus_layout
	_focus_bottom_spacer.visible = centered_focus_layout
	if _compact_layout == compact_layout and _use_mobile_cycle_layout == mobile_cycle_layout:
		_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if centered_focus_layout else Control.SIZE_SHRINK_BEGIN
		_grid_scroll.visible = not _use_mobile_cycle_layout
		_mobile_list.visible = _use_mobile_cycle_layout
		_apply_grid_metrics()
		_apply_selection_state()
		if _use_mobile_cycle_layout:
			call_deferred("_refresh_mobile_value_fonts")
		_sync_grid_scroll_height()
		_refresh_layout_metrics()
		return
	_compact_layout = compact_layout
	_use_mobile_cycle_layout = mobile_cycle_layout
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if centered_focus_layout else Control.SIZE_SHRINK_BEGIN
	_grid_scroll.visible = not _use_mobile_cycle_layout
	_mobile_list.visible = _use_mobile_cycle_layout
	_apply_grid_metrics()
	if question != null and is_node_ready():
		_rebuild_active_layout()
		_apply_selection_state()
	_sync_grid_scroll_height()
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

func _rebuild_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_primary_control = null
	_cell_panels.clear()
	_check_boxes.clear()
	_clear_modifier_mobile_display_overrides()
	_grid.columns = max(2, question.options.size() + 1)

	var blank_header := Control.new()
	blank_header.custom_minimum_size = Vector2(_row_label_width(), 0)
	blank_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blank_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(blank_header)

	for option in question.options:
		var option_label := Label.new()
		option_label.text = option
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_label.custom_minimum_size = Vector2(_option_label_width(), 0)
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		option_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_caption(option_label, SurveyStyle.TEXT_PRIMARY)
		var option_font_size := (15 if _compact_layout else 18) if is_focus_presentation() else (12 if _compact_layout else 13)
		option_label.add_theme_font_size_override("font_size", _fit_label_font_size(option_label, option, _option_label_width(), option_font_size, MIN_OPTION_FONT_SIZE))
		_grid.add_child(option_label)

	for row_name in question.rows:
		var row_label := Label.new()
		row_label.text = row_name
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.custom_minimum_size = Vector2(_row_label_width(), 0)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_body(row_label, SurveyStyle.TEXT_PRIMARY)
		var row_font_size := (18 if _compact_layout else 22) if is_focus_presentation() else (14 if _compact_layout else 16)
		row_label.add_theme_font_size_override("font_size", _fit_label_font_size(row_label, row_name, _row_label_width(), row_font_size, MIN_ROW_FONT_SIZE))
		_grid.add_child(row_label)

		for option in question.options:
			var cell_panel := PanelContainer.new()
			cell_panel.custom_minimum_size = Vector2(_cell_size(), _cell_size())
			cell_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var is_selected_cell := str(_answers_by_row.get(row_name, "")) == option
			SurveyStyle.apply_panel(cell_panel, SurveyStyle.SURFACE, SurveyStyle.HIGHLIGHT_GOLD if is_selected_cell else SurveyStyle.BORDER, 14, 2 if is_selected_cell else 1)

			var center := CenterContainer.new()
			center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_panel.add_child(center)

			var check_box := CheckBox.new()
			check_box.text = ""
			check_box.tooltip_text = option
			check_box.custom_minimum_size = Vector2(28, 28) if is_focus_presentation() else Vector2(22, 22)
			check_box.button_pressed = is_selected_cell
			SurveyStyle.style_check_box(check_box)
			check_box.toggled.connect(_on_matrix_option_toggled.bind(row_name, option))
			center.add_child(check_box)
			cell_panel.gui_input.connect(_on_matrix_cell_gui_input.bind(check_box))
			cell_panel.mouse_entered.connect(_on_matrix_cell_mouse_entered)
			_grid.add_child(cell_panel)
			_cell_panels[_cell_key(row_name, option)] = cell_panel
			_check_boxes[_cell_key(row_name, option)] = check_box
			register_selectable(check_box)
			if _primary_control == null:
				_primary_control = check_box
	_sync_grid_scroll_height()

func _rebuild_active_layout() -> void:
	if _use_mobile_cycle_layout:
		_rebuild_mobile_list()
	else:
		_rebuild_grid()

func _rebuild_mobile_list() -> void:
	for child in _mobile_list.get_children():
		child.queue_free()
	_stop_modifier_mobile_panel_tweens()
	_modifier_mobile_display_overrides.clear()
	_mobile_value_panels.clear()
	_mobile_value_labels.clear()
	_mobile_value_hint_labels.clear()
	_mobile_value_glows.clear()
	_mobile_prev_buttons.clear()
	_mobile_next_buttons.clear()
	_primary_control = null
	if question == null:
		return
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size())
	for row_name in question.rows:
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SurveyStyle.apply_panel(row_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)

		var row_stack := VBoxContainer.new()
		row_stack.layout_mode = 2
		row_stack.add_theme_constant_override("separation", 10)
		row_panel.add_child(row_stack)

		var row_label := Label.new()
		row_label.text = row_name
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_body(row_label, SurveyStyle.TEXT_PRIMARY)
		var mobile_row_font_size := int(round((18 if _compact_layout else 20) * journey_scale))
		row_label.add_theme_font_size_override("font_size", _fit_label_font_size(row_label, row_name, maxf(size.x - 40.0, 160.0), mobile_row_font_size, MIN_ROW_FONT_SIZE))
		row_stack.add_child(row_label)

		var selector_row := HBoxContainer.new()
		selector_row.layout_mode = 2
		selector_row.add_theme_constant_override("separation", 10)
		row_stack.add_child(selector_row)

		var prev_button := Button.new()
		prev_button.text = "<"
		prev_button.custom_minimum_size = Vector2(58.0 * journey_scale, 48.0 * journey_scale)
		SurveyStyle.apply_secondary_button(prev_button)
		prev_button.pressed.connect(_on_mobile_matrix_cycle.bind(row_name, -1))
		prev_button.mouse_entered.connect(_on_matrix_cell_mouse_entered)
		selector_row.add_child(prev_button)
		register_selectable(prev_button)

		var value_panel := PanelContainer.new()
		value_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_panel.clip_contents = true
		value_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		SurveyStyle.apply_panel(value_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 16, 1)
		selector_row.add_child(value_panel)

		var glow := ColorRect.new()
		glow.name = "ModifierGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.color = Color(1, 1, 1, 0.92)
		glow.anchor_right = 1.0
		glow.anchor_bottom = 1.0
		glow.grow_horizontal = Control.GROW_DIRECTION_BOTH
		glow.grow_vertical = Control.GROW_DIRECTION_BOTH
		glow.material = _create_modifier_glow_material()
		glow.visible = false
		value_panel.add_child(glow)

		var value_stack := VBoxContainer.new()
		value_stack.layout_mode = 2
		value_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		value_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		value_stack.add_theme_constant_override("separation", 2)
		value_panel.add_child(value_stack)

		var value_label := Label.new()
		value_label.layout_mode = 2
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_heading(value_label, int(round((19 if _compact_layout else 22) * journey_scale)), SurveyStyle.TEXT_PRIMARY)
		value_stack.add_child(value_label)

		var hint_label := Label.new()
		hint_label.layout_mode = 2
		hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_label.visible = false
		SurveyStyle.style_caption(hint_label, SurveyStyle.TEXT_MUTED)
		value_stack.add_child(hint_label)
		value_panel.gui_input.connect(_on_mobile_matrix_value_panel_gui_input.bind(row_name))
		value_panel.resized.connect(_on_mobile_value_panel_resized.bind(row_name))
		register_selectable(value_panel)

		var next_button := Button.new()
		next_button.text = ">"
		next_button.custom_minimum_size = Vector2(58.0 * journey_scale, 48.0 * journey_scale)
		SurveyStyle.apply_secondary_button(next_button)
		next_button.pressed.connect(_on_mobile_matrix_cycle.bind(row_name, 1))
		next_button.mouse_entered.connect(_on_matrix_cell_mouse_entered)
		selector_row.add_child(next_button)
		register_selectable(next_button)

		_mobile_list.add_child(row_panel)
		_mobile_value_panels[row_name] = value_panel
		_mobile_value_labels[row_name] = value_label
		_mobile_value_hint_labels[row_name] = hint_label
		_mobile_value_glows[row_name] = glow
		_mobile_prev_buttons[row_name] = prev_button
		_mobile_next_buttons[row_name] = next_button
		if _primary_control == null:
			_primary_control = prev_button
	_refresh_mobile_list_values()
	call_deferred("_refresh_mobile_value_fonts")
	modifier_intercept_action(&"matrix_layout_refreshed", {"layout": "cycle"})

func _apply_grid_metrics() -> void:
	var focus_layout := is_focus_presentation()
	var journey_focus_layout := is_journey_focus_presentation()
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size()) if journey_focus_layout and _compact_layout else 1.0
	_grid.add_theme_constant_override("h_separation", int(round((((8 if _compact_layout else 10) * journey_scale) if journey_focus_layout else ((12 if _compact_layout else 16) if focus_layout else (8 if _compact_layout else 10))))))
	_grid.add_theme_constant_override("v_separation", int(round((((8 if _compact_layout else 10) * journey_scale) if journey_focus_layout else ((10 if _compact_layout else 14) if focus_layout else (6 if _compact_layout else 8))))))
	_mobile_list.add_theme_constant_override("separation", int(round((((11 if _compact_layout else 13) * journey_scale) if journey_focus_layout else (10 if _compact_layout else 12)))))
	SurveyStyle.style_heading(_title_label, int(round((((22 if _compact_layout else 28) * journey_scale) if journey_focus_layout else ((30 if _compact_layout else 38) if focus_layout else (19 if _compact_layout else 21))))))
	SurveyStyle.style_body(_description_label)
	_description_label.add_theme_font_size_override("font_size", int(round((((15 if _compact_layout else 17) * journey_scale) if journey_focus_layout else ((18 if _compact_layout else 22) if focus_layout else 15)))))

func _sync_grid_scroll_height() -> void:
	if not is_node_ready():
		return
	if _use_mobile_cycle_layout:
		_grid_scroll.custom_minimum_size = Vector2.ZERO
		_grid_scroll.update_minimum_size()
		return
	_grid.update_minimum_size()
	var grid_min_size := _grid.get_combined_minimum_size()
	var scroll_height := grid_min_size.y
	if grid_min_size.x > maxf(size.x - 24.0, 0.0):
		scroll_height += 18.0
	if uses_centered_focus_layout():
		scroll_height = maxf(scroll_height, size.y * 0.72)
	_grid_scroll.custom_minimum_size = Vector2(0.0, scroll_height)
	_grid_scroll.update_minimum_size()

func _row_label_width() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (172.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 220.0
		return 180.0 if _compact_layout else 260.0
	return COMPACT_ROW_LABEL_MIN_WIDTH if _compact_layout else ROW_LABEL_MIN_WIDTH

func _option_label_width() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (82.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 100.0
		return 90.0 if _compact_layout else 116.0
	return COMPACT_OPTION_LABEL_MIN_WIDTH if _compact_layout else OPTION_LABEL_MIN_WIDTH

func _cell_size() -> float:
	if is_focus_presentation():
		if is_journey_focus_presentation():
			return (52.0 * SurveyStyle.journey_mobile_scale(_resolved_viewport_size())) if _compact_layout else 58.0
		return 54.0 if _compact_layout else 64.0
	return COMPACT_CELL_SIZE if _compact_layout else CELL_SIZE

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_matrix_cell_gui_input(event: InputEvent, check_box: CheckBox) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	emit_selected()
	if check_box != null:
		check_box.button_pressed = not check_box.button_pressed

func _on_matrix_cell_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _on_matrix_option_toggled(pressed: bool, row_name: String, option: String) -> void:
	if _syncing_row_selection:
		return
	if pressed:
		_syncing_row_selection = true
		for sibling_option in question.options:
			if sibling_option == option:
				continue
			var sibling_checkbox := _check_boxes.get(_cell_key(row_name, sibling_option)) as CheckBox
			if sibling_checkbox != null and sibling_checkbox.button_pressed:
				sibling_checkbox.button_pressed = false
		_syncing_row_selection = false
		_answers_by_row[row_name] = option
		SURVEY_UI_FEEDBACK.play_answer_select()
		var cell_panel := _cell_panels.get(_cell_key(row_name, option)) as Control
		if cell_panel != null:
			SURVEY_UI_FEEDBACK.pulse(cell_panel, 0.05, 0.16)
	else:
		SURVEY_UI_FEEDBACK.play_answer_unselect()
		if str(_answers_by_row.get(row_name, "")) == option:
			_answers_by_row.erase(row_name)
	_refresh_cell_styles()
	emit_selected()
	emit_answer(_answers_by_row.duplicate())
	_refresh_mobile_list_values()

func _refresh_cell_styles() -> void:
	for row_name in question.rows:
		for option in question.options:
			var panel := _cell_panels.get(_cell_key(row_name, option)) as PanelContainer
			if panel == null:
				continue
			var is_selected_cell := str(_answers_by_row.get(row_name, "")) == option
			SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE, SurveyStyle.HIGHLIGHT_GOLD if is_selected_cell else SurveyStyle.BORDER, 14, 2 if is_selected_cell else 1)

func _refresh_mobile_list_values() -> void:
	if question == null:
		return
	for row_name in question.rows:
		_refresh_mobile_row_value(row_name)

func _on_mobile_matrix_cycle(row_name: String, direction: int) -> void:
	if question == null or question.options.is_empty():
		return
	var modifier_result: Dictionary = modifier_intercept_action(&"matrix_cycle", {
		"row_name": row_name,
		"direction": direction,
		"current_value": str(_answers_by_row.get(row_name, "")).strip_edges()
	})
	if bool(modifier_result.get("handled", false)):
		emit_selected()
		return
	var current_option := str(_answers_by_row.get(row_name, "")).strip_edges()
	var current_index := question.options.find(current_option)
	if current_index == -1:
		current_index = 0 if direction >= 0 else question.options.size() - 1
	else:
		current_index = wrapi(current_index + direction, 0, question.options.size())
	_commit_mobile_matrix_value(row_name, question.options[current_index])

func _on_mobile_matrix_value_panel_gui_input(event: InputEvent, row_name: String) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var modifier_result: Dictionary = modifier_intercept_action(&"matrix_value_tap", {
		"row_name": row_name,
		"current_value": str(_answers_by_row.get(row_name, "")).strip_edges()
	})
	if bool(modifier_result.get("handled", false)):
		emit_selected()
		return
	emit_selected()

func _cell_key(row_name: String, option: String) -> String:
	return "%s||%s" % [row_name, option]

func modifier_matrix_options() -> PackedStringArray:
	if question == null:
		return PackedStringArray()
	return PackedStringArray(question.options)

func modifier_current_matrix_value(row_name: String) -> String:
	return str(_answers_by_row.get(row_name, "")).strip_edges()

func modifier_show_pending_matrix_value(row_name: String, option: String, prompt_text: String = "Tap to accept", play_pulse: bool = true) -> void:
	var resolved_row_name: String = row_name.strip_edges()
	if resolved_row_name.is_empty():
		return
	var resolved_option: String = option.strip_edges()
	if resolved_option.is_empty():
		modifier_clear_pending_matrix_value(resolved_row_name)
		return
	_modifier_mobile_display_overrides[resolved_row_name] = {
		"value": resolved_option,
		"prompt": prompt_text.strip_edges()
	}
	_refresh_mobile_row_value(resolved_row_name)
	_apply_modifier_mobile_pending_visual(resolved_row_name, true, play_pulse)

func modifier_clear_pending_matrix_value(row_name: String) -> void:
	var resolved_row_name: String = row_name.strip_edges()
	if resolved_row_name.is_empty():
		return
	_modifier_mobile_display_overrides.erase(resolved_row_name)
	_refresh_mobile_row_value(resolved_row_name)
	_apply_modifier_mobile_pending_visual(resolved_row_name, false, false)

func modifier_clear_all_pending_matrix_values() -> void:
	var row_names: Array = _modifier_mobile_display_overrides.keys()
	for row_name_variant in row_names:
		modifier_clear_pending_matrix_value(str(row_name_variant))
	_stop_modifier_mobile_panel_tweens()

func modifier_commit_matrix_value(row_name: String, option: String) -> void:
	var resolved_row_name: String = row_name.strip_edges()
	var resolved_option: String = option.strip_edges()
	if resolved_row_name.is_empty() or resolved_option.is_empty():
		return
	modifier_clear_pending_matrix_value(resolved_row_name)
	_commit_mobile_matrix_value(resolved_row_name, resolved_option)

func _commit_mobile_matrix_value(row_name: String, option: String) -> void:
	_answers_by_row[row_name] = option
	emit_selected()
	emit_answer(_answers_by_row.duplicate())
	SURVEY_UI_FEEDBACK.play_answer_select()
	var value_panel := _mobile_value_panels.get(row_name) as Control
	if value_panel != null and is_instance_valid(value_panel):
		SURVEY_UI_FEEDBACK.pulse(value_panel, 0.05, 0.16)
	_refresh_mobile_list_values()
	_refresh_cell_styles()

func _refresh_mobile_row_value(row_name: String) -> void:
	var value_label := _mobile_value_labels.get(row_name) as Label
	if value_label == null:
		return
	var hint_label := _mobile_value_hint_labels.get(row_name) as Label
	var value_panel := _mobile_value_panels.get(row_name) as PanelContainer
	var glow := _mobile_value_glows.get(row_name) as ColorRect
	var override_data: Dictionary = (_modifier_mobile_display_overrides.get(row_name, {}) as Dictionary)
	var selected_option := str(_answers_by_row.get(row_name, "")).strip_edges()
	var override_option := str(override_data.get("value", "")).strip_edges()
	var display_value := override_option if not override_option.is_empty() else selected_option
	var prompt_text := str(override_data.get("prompt", "")).strip_edges()
	var pending_modifier_value := not override_option.is_empty()
	value_label.text = display_value if not display_value.is_empty() else "Choose a value"
	_apply_mobile_value_font_size(row_name)
	if hint_label != null:
		hint_label.text = prompt_text
		hint_label.visible = pending_modifier_value and not prompt_text.is_empty()
		SurveyStyle.style_caption(hint_label, SurveyStyle.HIGHLIGHT_GOLD.lightened(0.06) if pending_modifier_value else SurveyStyle.TEXT_MUTED)
	if value_panel != null:
		var fill_color := SurveyStyle.SURFACE if not pending_modifier_value else SurveyStyle.SURFACE_ALT.lerp(SurveyStyle.ACCENT_ALT, 0.18)
		var border_color := SurveyStyle.BORDER if not pending_modifier_value else SurveyStyle.HIGHLIGHT_GOLD.lightened(0.1)
		SurveyStyle.apply_panel(value_panel, fill_color, border_color, 16, 2 if pending_modifier_value else 1)
	if glow != null:
		glow.visible = pending_modifier_value
		var glow_material := glow.material as ShaderMaterial
		if glow_material != null:
			glow_material.set_shader_parameter("intensity", 1.0 if pending_modifier_value else 0.0)

func _refresh_mobile_value_fonts() -> void:
	if question == null:
		return
	for row_name in question.rows:
		_apply_mobile_value_font_size(row_name)

func _apply_mobile_value_font_size(row_name: String) -> void:
	var value_label := _mobile_value_labels.get(row_name) as Label
	if value_label == null:
		return
	var value_panel := _mobile_value_panels.get(row_name) as Control
	var available_width := _estimated_mobile_value_width()
	if value_panel != null:
		available_width = maxf(available_width, value_panel.size.x)
		available_width = maxf(available_width, value_panel.get_combined_minimum_size().x)
	var fitted_font_size := _fit_label_font_size(
		value_label,
		value_label.text,
		maxf(available_width - 24.0, 48.0),
		_base_mobile_value_font_size(),
		MIN_MOBILE_VALUE_FONT_SIZE
	)
	value_label.add_theme_font_size_override("font_size", fitted_font_size)

func _base_mobile_value_font_size() -> int:
	var journey_scale := SurveyStyle.journey_mobile_scale(_resolved_viewport_size())
	return int(round((19 if _compact_layout else 22) * journey_scale))

func _estimated_mobile_value_width() -> float:
	var viewport_size := _resolved_viewport_size()
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size)
	var total_width := maxf(size.x, viewport_size.x - 48.0)
	var row_padding := 28.0
	var selector_gap := 20.0
	var nav_button_width := 116.0 * journey_scale
	return maxf(total_width - row_padding - selector_gap - nav_button_width, 96.0)

func _on_mobile_value_panel_resized(row_name: String) -> void:
	_apply_mobile_value_font_size(row_name)

func _apply_modifier_mobile_pending_visual(row_name: String, is_pending: bool, play_pulse: bool) -> void:
	var value_panel := _mobile_value_panels.get(row_name) as Control
	if value_panel == null or not is_instance_valid(value_panel):
		return
	var existing_tween := _modifier_mobile_panel_tweens.get(row_name) as Tween
	if existing_tween != null:
		existing_tween.kill()
	_modifier_mobile_panel_tweens.erase(row_name)
	value_panel.pivot_offset = value_panel.size * 0.5
	if not is_pending:
		var settle_tween := value_panel.create_tween()
		settle_tween.tween_property(value_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_modifier_mobile_panel_tweens[row_name] = settle_tween
		return
	if not play_pulse:
		value_panel.scale = Vector2.ONE * 1.03
		return
	var pulse_tween := value_panel.create_tween()
	pulse_tween.tween_property(value_panel, "scale", Vector2.ONE * 1.11, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(value_panel, "scale", Vector2.ONE * 1.04, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_modifier_mobile_panel_tweens[row_name] = pulse_tween

func _stop_modifier_mobile_panel_tweens() -> void:
	for tween_variant in _modifier_mobile_panel_tweens.values():
		var tween := tween_variant as Tween
		if tween != null:
			tween.kill()
	_modifier_mobile_panel_tweens.clear()

func _clear_modifier_mobile_display_overrides() -> void:
	_stop_modifier_mobile_panel_tweens()
	_modifier_mobile_display_overrides.clear()
	for row_name_variant in _mobile_value_panels.keys():
		var row_name: String = str(row_name_variant)
		var value_panel := _mobile_value_panels.get(row_name) as Control
		if value_panel != null and is_instance_valid(value_panel):
			value_panel.scale = Vector2.ONE
		var glow := _mobile_value_glows.get(row_name) as ColorRect
		if glow != null and is_instance_valid(glow):
			glow.visible = false
			var glow_material := glow.material as ShaderMaterial
			if glow_material != null:
				glow_material.set_shader_parameter("intensity", 0.0)
	_refresh_mobile_list_values()

func _create_modifier_glow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = LOOT_BOX_RAINBOW_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("intensity", 0.0)
	material.set_shader_parameter("speed", 2.4)
	return material

func _fit_label_font_size(label: Label, text: String, width: float, base_font_size: int, min_font_size: int) -> int:
	var resolved_text := text.strip_edges()
	if resolved_text.is_empty():
		return base_font_size
	var font: Font = label.get_theme_font("font")
	if font == null:
		return base_font_size
	var target_width := maxf(width - 10.0, 24.0)
	var longest_word := _longest_label_word(resolved_text)
	if longest_word.is_empty():
		return base_font_size
	for font_size in range(base_font_size, min_font_size - 1, -1):
		var measured_width := font.get_string_size(longest_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if measured_width <= target_width:
			return font_size
	return min_font_size

func _longest_label_word(text: String) -> String:
	var longest_word := ""
	var normalized := text.replace("\n", " ").replace("\t", " ")
	for word in normalized.split(" ", false):
		var candidate := word.strip_edges()
		if candidate.length() > longest_word.length():
			longest_word = candidate
	return longest_word





