class_name MatrixQuestionView
extends SurveyQuestionView

const ROW_LABEL_MIN_WIDTH := 220.0
const OPTION_LABEL_MIN_WIDTH := 92.0
@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _grid: GridContainer = $Panel/Stack/Grid

var _answers_by_row: Dictionary = {}
var _cell_panels: Dictionary = {}
var _primary_control: Control

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.style_heading(_title_label, 21)
	SurveyStyle.style_body(_description_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.gui_input.connect(_on_panel_gui_input)
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
	_refresh_layout_metrics()

func _apply_selection_state() -> void:
	var border_color := SurveyStyle.ACCENT if is_selected else SurveyStyle.ACCENT_ALT
	var fill_color := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE_ALT
	SurveyStyle.apply_panel(_panel, fill_color, border_color, 22, 1)

func focus_primary_control() -> void:
	if _primary_control != null:
		_primary_control.grab_focus()

func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.free()
	_primary_control = null
	_cell_panels.clear()
	_grid.columns = max(2, question.options.size() + 1)

	var blank_header := Control.new()
	blank_header.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0)
	blank_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blank_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(blank_header)

	for option in question.options:
		var option_label := Label.new()
		option_label.text = option
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_label.custom_minimum_size = Vector2(OPTION_LABEL_MIN_WIDTH, 0)
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		option_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_caption(option_label, SurveyStyle.TEXT_PRIMARY)
		_grid.add_child(option_label)

	for row_name in question.rows:
		var row_label := Label.new()
		row_label.text = row_name
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.custom_minimum_size = Vector2(ROW_LABEL_MIN_WIDTH, 0)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_body(row_label, SurveyStyle.TEXT_PRIMARY)
		_grid.add_child(row_label)

		var button_group := ButtonGroup.new()
		for option in question.options:
			var cell_panel := PanelContainer.new()
			cell_panel.custom_minimum_size = Vector2(52, 52)
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
			check_box.custom_minimum_size = Vector2(24, 24)
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





