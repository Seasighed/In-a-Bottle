class_name MatrixQuestionView
extends SurveyQuestionView

const ROW_LABEL_MIN_WIDTH := 220.0
const OPTION_LABEL_MIN_WIDTH := 92.0
const COMPACT_ROW_LABEL_MIN_WIDTH := 144.0
const COMPACT_OPTION_LABEL_MIN_WIDTH := 72.0
const CELL_SIZE := 52.0
const COMPACT_CELL_SIZE := 44.0
@onready var _panel: PanelContainer = $Panel
@onready var _stack: VBoxContainer = $Panel/Stack
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _grid_scroll: ScrollContainer = $Panel/Stack/GridScroll
@onready var _grid: GridContainer = $Panel/Stack/GridScroll/Grid

var _answers_by_row: Dictionary = {}
var _cell_panels: Dictionary = {}
var _primary_control: Control
var _compact_layout := false
var _focus_top_spacer: Control
var _focus_bottom_spacer: Control

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_focus_spacers()
	_grid_scroll.vertical_scroll_mode = 0
	_grid_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.style_heading(_title_label, 21)
	SurveyStyle.style_body(_description_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.gui_input.connect(_on_panel_gui_input)
	refresh_responsive_layout(get_viewport().get_visible_rect().size)
	super()

func _apply_question() -> void:
	if question == null:
		return

	_title_label.text = question.display_prompt()
	_description_label.text = question.description if not question.description.is_empty() else "Choose one answer for each row."
	_answers_by_row = {}
	if current_value is Dictionary:
		for row_name in question.rows:
			if (current_value as Dictionary).has(row_name):
				_answers_by_row[row_name] = str((current_value as Dictionary).get(row_name, ""))
	_rebuild_grid()
	_apply_selection_state()
	refresh_responsive_layout(get_viewport().get_visible_rect().size)
	_refresh_layout_metrics()

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
	_ensure_focus_spacers()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL if focus_layout else Control.SIZE_FILL
	_focus_top_spacer.visible = focus_layout
	_focus_bottom_spacer.visible = focus_layout
	var compact_layout: bool = available_width <= (720.0 if focus_layout else 640.0) or viewport_size.x <= (720.0 if focus_layout else 640.0)
	if _compact_layout == compact_layout:
		_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if focus_layout else Control.SIZE_SHRINK_BEGIN
		_apply_grid_metrics()
		_apply_selection_state()
		_sync_grid_scroll_height()
		_refresh_layout_metrics()
		return
	_compact_layout = compact_layout
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if focus_layout else Control.SIZE_SHRINK_BEGIN
	_apply_grid_metrics()
	if question != null and is_node_ready():
		_rebuild_grid()
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
		child.free()
	_primary_control = null
	_cell_panels.clear()
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
		option_label.add_theme_font_size_override("font_size", (15 if _compact_layout else 18) if is_focus_presentation() else (12 if _compact_layout else 13))
		_grid.add_child(option_label)

	for row_name in question.rows:
		var row_label := Label.new()
		row_label.text = row_name
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.custom_minimum_size = Vector2(_row_label_width(), 0)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_body(row_label, SurveyStyle.TEXT_PRIMARY)
		row_label.add_theme_font_size_override("font_size", (18 if _compact_layout else 22) if is_focus_presentation() else (14 if _compact_layout else 16))
		_grid.add_child(row_label)

		var button_group := ButtonGroup.new()
		for option in question.options:
			var cell_panel := PanelContainer.new()
			cell_panel.custom_minimum_size = Vector2(_cell_size(), _cell_size())
			cell_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var is_selected_cell := str(_answers_by_row.get(row_name, "")) == option
			SurveyStyle.apply_panel(cell_panel, SurveyStyle.SURFACE, SurveyStyle.HIGHLIGHT_GOLD if is_selected_cell else SurveyStyle.BORDER, 14, 2 if is_selected_cell else 1)

			var center := CenterContainer.new()
			center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			center.size_flags_vertical = Control.SIZE_EXPAND_FILL
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell_panel.add_child(center)

			var check_box := CheckBox.new()
			check_box.text = ""
			check_box.tooltip_text = option
			check_box.button_group = button_group
			check_box.custom_minimum_size = Vector2(28, 28) if is_focus_presentation() else Vector2(22, 22)
			check_box.button_pressed = is_selected_cell
			SurveyStyle.style_check_box(check_box)
			check_box.toggled.connect(_on_matrix_option_toggled.bind(row_name, option))
			center.add_child(check_box)
			cell_panel.gui_input.connect(_on_matrix_cell_gui_input.bind(check_box))
			cell_panel.mouse_entered.connect(_on_matrix_cell_mouse_entered)
			_grid.add_child(cell_panel)
			_cell_panels[_cell_key(row_name, option)] = cell_panel
			register_selectable(check_box)
			if _primary_control == null:
				_primary_control = check_box
	_sync_grid_scroll_height()

func _apply_grid_metrics() -> void:
	var focus_layout := is_focus_presentation()
	_grid.add_theme_constant_override("h_separation", (12 if _compact_layout else 16) if focus_layout else (8 if _compact_layout else 10))
	_grid.add_theme_constant_override("v_separation", (10 if _compact_layout else 14) if focus_layout else (6 if _compact_layout else 8))
	SurveyStyle.style_heading(_title_label, (30 if _compact_layout else 38) if focus_layout else (19 if _compact_layout else 21))
	SurveyStyle.style_body(_description_label)
	_description_label.add_theme_font_size_override("font_size", (18 if _compact_layout else 22) if focus_layout else 15)

func _sync_grid_scroll_height() -> void:
	if not is_node_ready():
		return
	_grid.update_minimum_size()
	var grid_min_size := _grid.get_combined_minimum_size()
	var scroll_height := grid_min_size.y
	if grid_min_size.x > maxf(size.x - 24.0, 0.0):
		scroll_height += 18.0
	if is_focus_presentation():
		scroll_height = maxf(scroll_height, size.y * 0.72)
	_grid_scroll.custom_minimum_size = Vector2(0.0, scroll_height)
	_grid_scroll.update_minimum_size()

func _row_label_width() -> float:
	if is_focus_presentation():
		return 180.0 if _compact_layout else 260.0
	return COMPACT_ROW_LABEL_MIN_WIDTH if _compact_layout else ROW_LABEL_MIN_WIDTH

func _option_label_width() -> float:
	if is_focus_presentation():
		return 90.0 if _compact_layout else 116.0
	return COMPACT_OPTION_LABEL_MIN_WIDTH if _compact_layout else OPTION_LABEL_MIN_WIDTH

func _cell_size() -> float:
	if is_focus_presentation():
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
	if check_box != null and not check_box.button_pressed:
		check_box.button_pressed = true

func _on_matrix_cell_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _on_matrix_option_toggled(pressed: bool, row_name: String, option: String) -> void:
	if pressed:
		_answers_by_row[row_name] = option
		SURVEY_UI_FEEDBACK.play_answer_select()
		var cell_panel := _cell_panels.get(_cell_key(row_name, option)) as Control
		if cell_panel != null:
			SURVEY_UI_FEEDBACK.pulse(cell_panel, 0.05, 0.16)
	else:
		if str(_answers_by_row.get(row_name, "")) == option:
			_answers_by_row.erase(row_name)
	_refresh_cell_styles()
	emit_selected()
	emit_answer(_answers_by_row.duplicate())

func _refresh_cell_styles() -> void:
	for row_name in question.rows:
		for option in question.options:
			var panel := _cell_panels.get(_cell_key(row_name, option)) as PanelContainer
			if panel == null:
				continue
			var is_selected_cell := str(_answers_by_row.get(row_name, "")) == option
			SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE, SurveyStyle.HIGHLIGHT_GOLD if is_selected_cell else SurveyStyle.BORDER, 14, 2 if is_selected_cell else 1)

func _cell_key(row_name: String, option: String) -> String:
	return "%s||%s" % [row_name, option]





