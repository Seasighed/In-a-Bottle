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
	SurveyStyle.style_check_box(_check_box)
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
	var journey_scale: float = SurveyStyle.journey_mobile_scale(get_viewport().get_visible_rect().size)
	if _focus_presentation and _journey_focus_presentation:
		custom_minimum_size = Vector2(0.0, 58.0 * journey_scale)
		_check_box.custom_minimum_size = Vector2(0.0, 50.0 * journey_scale)
	elif _focus_presentation:
		custom_minimum_size = Vector2(0.0, 68.0)
		_check_box.custom_minimum_size = Vector2(0.0, 60.0)
	else:
		custom_minimum_size = Vector2(0.0, 0.0)
		_check_box.custom_minimum_size = Vector2(0.0, 0.0)
	if _focus_presentation:
		_check_box.add_theme_font_size_override("font_size", int(round((18 if _journey_focus_presentation else 20) * (journey_scale if _journey_focus_presentation else 1.0))))
	else:
		_check_box.remove_theme_font_size_override("font_size")

