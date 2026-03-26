class_name CheckboxOptionRow
extends PanelContainer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal toggled(value: String, pressed: bool)

@onready var _check_box: CheckBox = $CheckBox

var _value: String = ""
var _is_configuring := false
var _focus_presentation := false
var _journey_focus_presentation := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	SurveyStyle.style_check_box(_check_box)
	_check_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check_box.toggled.connect(_on_check_box_toggled)
	_update_layout()
	_update_style()

func configure(value: String, pressed: bool = false) -> void:
	_is_configuring = true
	_value = value
	_check_box.text = value
	_check_box.button_pressed = pressed
	_is_configuring = false
	_update_style()

func is_checked() -> bool:
	return _check_box.button_pressed

func get_value() -> String:
	return _value

func get_primary_control() -> Control:
	return _check_box

func set_focus_presentation(enabled: bool) -> void:
	if _focus_presentation == enabled:
		return
	_focus_presentation = enabled
	_update_layout()
	_update_style()

func set_journey_focus_presentation(enabled: bool) -> void:
	if _journey_focus_presentation == enabled:
		return
	_journey_focus_presentation = enabled
	_update_layout()
	_update_style()

func _on_check_box_toggled(pressed: bool) -> void:
	_update_style()
	if _is_configuring:
		return
	if pressed:
		SURVEY_UI_FEEDBACK.play_answer_select()
	else:
		SURVEY_UI_FEEDBACK.play_answer_unselect()
	if pressed:
		SURVEY_UI_FEEDBACK.pulse(self, 0.05, 0.16)
	toggled.emit(_value, pressed)

func _update_style() -> void:
	var fill: Color = SurveyStyle.SURFACE_MUTED if _check_box.button_pressed else SurveyStyle.SURFACE_ALT
	var border: Color = SurveyStyle.HIGHLIGHT_GOLD if _check_box.button_pressed else SurveyStyle.BORDER
	SurveyStyle.apply_panel(self, fill, border, 14, 2 if _check_box.button_pressed else 1)

func _update_layout() -> void:
	if _focus_presentation and _journey_focus_presentation:
		custom_minimum_size = Vector2(0.0, 52.0)
		_check_box.custom_minimum_size = Vector2(0.0, 44.0)
	elif _focus_presentation:
		custom_minimum_size = Vector2(0.0, 68.0)
		_check_box.custom_minimum_size = Vector2(0.0, 60.0)
	else:
		custom_minimum_size = Vector2(0.0, 0.0)
		_check_box.custom_minimum_size = Vector2(0.0, 0.0)
	if _focus_presentation:
		_check_box.add_theme_font_size_override("font_size", 17 if _journey_focus_presentation else 20)
	else:
		_check_box.remove_theme_font_size_override("font_size")

