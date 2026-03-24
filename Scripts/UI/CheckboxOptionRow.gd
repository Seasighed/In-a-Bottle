class_name CheckboxOptionRow
extends PanelContainer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal toggled(value: String, pressed: bool)

@onready var _check_box: CheckBox = $CheckBox

var _value: String = ""
var _is_configuring := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	SurveyStyle.style_check_box(_check_box)
	_check_box.toggled.connect(_on_check_box_toggled)
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

func _on_check_box_toggled(pressed: bool) -> void:
	_update_style()
	if _is_configuring:
		return
	SURVEY_UI_FEEDBACK.play_answer_select()
	if pressed:
		SURVEY_UI_FEEDBACK.pulse(self, 0.05, 0.16)
	toggled.emit(_value, pressed)

func _update_style() -> void:
	var fill: Color = SurveyStyle.SURFACE_MUTED if _check_box.button_pressed else SurveyStyle.SURFACE_ALT
	var border: Color = SurveyStyle.HIGHLIGHT_GOLD if _check_box.button_pressed else SurveyStyle.BORDER
	SurveyStyle.apply_panel(self, fill, border, 14, 2 if _check_box.button_pressed else 1)

