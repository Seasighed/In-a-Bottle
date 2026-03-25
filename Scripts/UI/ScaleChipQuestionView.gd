class_name ScaleChipQuestionView
extends SurveyQuestionView

@onready var _panel: PanelContainer = $Panel
@onready var _stack: VBoxContainer = $Panel/Stack
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _flow: HFlowContainer = $Panel/Stack/Flow

var _buttons: Array[Button] = []
var _compact_layout := false
var _focus_top_spacer: Control
var _focus_bottom_spacer: Control

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_focus_spacers()
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
	_description_label.text = question.description if not question.description.is_empty() else "Tap a score to answer quickly."

	for child in _flow.get_children():
		child.free()
	_buttons.clear()

	for value in range(question.min_value, question.max_value + 1):
		var score := value
		var button := Button.new()
		button.text = str(score)
		button.pressed.connect(_on_score_pressed.bind(score))
		_flow.add_child(button)
		register_selectable(button)
		_buttons.append(button)

	_sync_selection(int(current_value) if current_value != null else -1)
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
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	_compact_layout = viewport_size.x <= 560.0
	var focus_layout := is_focus_presentation()
	_ensure_focus_spacers()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL if focus_layout else Control.SIZE_FILL
	_focus_top_spacer.visible = focus_layout
	_focus_bottom_spacer.visible = focus_layout
	_stack.add_theme_constant_override("separation", (16 if _compact_layout else 20) if focus_layout else (8 if _compact_layout else 10))
	_flow.add_theme_constant_override("h_separation", (14 if _compact_layout else 18) if focus_layout else (8 if _compact_layout else 10))
	_flow.add_theme_constant_override("v_separation", (14 if _compact_layout else 18) if focus_layout else (8 if _compact_layout else 10))
	SurveyStyle.style_heading(_title_label, (30 if _compact_layout else 38) if focus_layout else (19 if _compact_layout else 21))
	SurveyStyle.style_body(_description_label)
	_description_label.add_theme_font_size_override("font_size", (18 if _compact_layout else 22) if focus_layout else 15)
	var button_size: float = (72.0 if _compact_layout else 88.0) if focus_layout else (48.0 if _compact_layout else 56.0)
	for button in _buttons:
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.add_theme_font_size_override("font_size", (22 if _compact_layout else 26) if focus_layout else (15 if _compact_layout else 16))
	_apply_selection_state()
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

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_score_pressed(score: int) -> void:
	SURVEY_UI_FEEDBACK.play_answer_select()
	emit_answer(score)
	emit_selected()
	_sync_selection(score)
	for button in _buttons:
		if int(button.text) == score:
			SURVEY_UI_FEEDBACK.pulse(button, 0.08, 0.18)
			break

func _sync_selection(selected_value: int) -> void:
	for button in _buttons:
		SurveyStyle.apply_answer_button(button, int(button.text) == selected_value)


