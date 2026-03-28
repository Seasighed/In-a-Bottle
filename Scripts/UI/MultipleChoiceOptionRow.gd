class_name MultipleChoiceOptionRow
extends Button

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal selected(value: String)
signal toggled_value(value: String, pressed: bool)

var _value: String = ""
var _is_configuring := false
var _focus_presentation := false
var _journey_focus_presentation := false

func _ready() -> void:
	toggled.connect(_on_toggled)
	_update_style()

func configure(value: String, pressed: bool = false, group: ButtonGroup = null) -> void:
	_is_configuring = true
	_value = value
	text = value
	button_group = group
	button_pressed = pressed
	_is_configuring = false
	_update_style()

func get_value() -> String:
	return _value

func get_primary_control() -> Control:
	return self

func is_option_pressed() -> bool:
	return button_pressed

func set_pressed_silently(pressed: bool) -> void:
	if button_pressed == pressed:
		_update_style()
		return
	_is_configuring = true
	button_pressed = pressed
	_is_configuring = false
	_update_style()

func set_focus_presentation(enabled: bool) -> void:
	if _focus_presentation == enabled:
		return
	_focus_presentation = enabled
	_update_style()

func set_journey_focus_presentation(enabled: bool) -> void:
	if _journey_focus_presentation == enabled:
		return
	_journey_focus_presentation = enabled
	_update_style()

func _on_toggled(pressed: bool) -> void:
	_update_style()
	if _is_configuring:
		return
	if pressed:
		SURVEY_UI_FEEDBACK.play_answer_select()
		SURVEY_UI_FEEDBACK.pulse(self, 0.05, 0.16)
		selected.emit(_value)
	else:
		SURVEY_UI_FEEDBACK.play_answer_unselect()
	toggled_value.emit(_value, pressed)

func _update_style() -> void:
	SurveyStyle.apply_answer_button(self, button_pressed)
	var journey_scale: float = SurveyStyle.journey_mobile_scale(get_viewport().get_visible_rect().size)
	if _focus_presentation and _journey_focus_presentation:
		custom_minimum_size = Vector2(0.0, 58.0 * journey_scale)
	else:
		custom_minimum_size = Vector2(0.0, 68.0 if _focus_presentation else 44.0)
	if _focus_presentation:
		add_theme_font_size_override("font_size", int(round((18 if _journey_focus_presentation else 20) * (journey_scale if _journey_focus_presentation else 1.0))))
	else:
		remove_theme_font_size_override("font_size")

