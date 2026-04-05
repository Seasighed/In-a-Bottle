class_name CheckboxOptionRow
extends PanelContainer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal toggled(value: String, pressed: bool)

var _check_box: CheckBox = null

var _value: String = ""
var _pressed := false
var _is_configuring := false
var _focus_presentation := false
var _journey_focus_presentation := false

func _ready() -> void:
	var check_box := _ensure_check_box()
	if check_box == null:
		push_warning("CheckboxOptionRow is missing its CheckBox child.")
		return
	check_box.text = _value
	check_box.button_pressed = _pressed
	SurveyStyle.style_check_box(check_box)
	if not check_box.toggled.is_connected(_on_check_box_toggled):
		check_box.toggled.connect(_on_check_box_toggled)
	_update_layout()
	_update_style()

func configure(value: String, pressed: bool = false) -> void:
	_is_configuring = true
	_value = value
	_pressed = pressed
	var check_box := _ensure_check_box()
	if check_box != null:
		check_box.text = value
		check_box.button_pressed = _pressed
	_is_configuring = false
	_update_style()

func is_checked() -> bool:
	var check_box := _ensure_check_box()
	return check_box.button_pressed if check_box != null else _pressed

func get_value() -> String:
	return _value

func get_primary_control() -> Control:
	var check_box := _ensure_check_box()
	return check_box if check_box != null else self

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
	_pressed = pressed
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
	var check_box := _ensure_check_box()
	if check_box == null:
		return
	var fill: Color = SurveyStyle.SURFACE_MUTED if check_box.button_pressed else SurveyStyle.SURFACE_ALT
	var border: Color = SurveyStyle.HIGHLIGHT_GOLD if check_box.button_pressed else SurveyStyle.BORDER
	SurveyStyle.apply_panel(self, fill, border, 14, 2 if check_box.button_pressed else 1)

func _update_layout() -> void:
	var check_box := _ensure_check_box()
	if check_box == null:
		return
	var journey_scale: float = SurveyStyle.journey_mobile_scale(_resolved_viewport_size())
	if _focus_presentation and _journey_focus_presentation:
		custom_minimum_size = Vector2(0.0, 58.0 * journey_scale)
		check_box.custom_minimum_size = Vector2(0.0, 50.0 * journey_scale)
	elif _focus_presentation:
		custom_minimum_size = Vector2(0.0, 68.0)
		check_box.custom_minimum_size = Vector2(0.0, 60.0)
	else:
		custom_minimum_size = Vector2(0.0, 0.0)
		check_box.custom_minimum_size = Vector2(0.0, 0.0)
	if _focus_presentation:
		check_box.add_theme_font_size_override("font_size", int(round((18 if _journey_focus_presentation else 20) * (journey_scale if _journey_focus_presentation else 1.0))))
	else:
		check_box.remove_theme_font_size_override("font_size")

func _ensure_check_box() -> CheckBox:
	if _check_box == null:
		_check_box = get_node_or_null("CheckBox") as CheckBox
	if _check_box == null:
		var fallback := CheckBox.new()
		fallback.name = "CheckBox"
		fallback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(fallback)
		_check_box = fallback
	return _check_box

func _resolved_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	var fallback_size := Vector2(
		maxf(size.x, custom_minimum_size.x),
		maxf(size.y, custom_minimum_size.y)
	)
	if fallback_size.x <= 0.0:
		fallback_size.x = 1280.0
	if fallback_size.y <= 0.0:
		fallback_size.y = 720.0
	return fallback_size
