class_name ScaleChipQuestionView
extends SurveyQuestionView

@onready var _panel: PanelContainer = $Panel
@onready var _stack: VBoxContainer = $Panel/Stack
@onready var _title_label: Label = $Panel/Stack/TitleLabel
@onready var _description_label: Label = $Panel/Stack/DescriptionLabel
@onready var _flow: HFlowContainer = $Panel/Stack/Flow

var _buttons: Array[Button] = []
var _compact_layout := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var border_color := SurveyStyle.ACCENT if is_selected else SurveyStyle.ACCENT_ALT
	var fill_color := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE_ALT
	SurveyStyle.apply_panel(_panel, fill_color, border_color, 22, 1)

func focus_primary_control() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	_compact_layout = viewport_size.x <= 560.0
	_stack.add_theme_constant_override("separation", 8 if _compact_layout else 10)
	_flow.add_theme_constant_override("h_separation", 8 if _compact_layout else 10)
	_flow.add_theme_constant_override("v_separation", 8 if _compact_layout else 10)
	SurveyStyle.style_heading(_title_label, 19 if _compact_layout else 21)
	SurveyStyle.style_body(_description_label)
	var button_size: float = 48.0 if _compact_layout else 56.0
	for button in _buttons:
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.add_theme_font_size_override("font_size", 15 if _compact_layout else 16)
	_refresh_layout_metrics()

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


