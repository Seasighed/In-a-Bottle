class_name TypedAnswerField
extends VBoxContainer

signal value_changed(value: String)

@onready var _line_edit: LineEdit = $LineEdit
@onready var _text_edit: TextEdit = $TextEdit

var _is_configuring := false
var _focus_presentation := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	SurveyStyle.style_line_edit(_line_edit)
	SurveyStyle.style_text_edit(_text_edit)
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.custom_minimum_size = Vector2(0, 132)
	_line_edit.text_changed.connect(_on_line_edit_text_changed)
	_text_edit.text_changed.connect(_on_text_edit_text_changed)
	refresh_responsive_layout(get_viewport().get_visible_rect().size)

func configure(value: String, placeholder: String, multiline: bool = false) -> void:
	_is_configuring = true
	_line_edit.visible = not multiline
	_text_edit.visible = multiline
	_line_edit.placeholder_text = placeholder if not placeholder.is_empty() else "Type your answer"
	_line_edit.text = value
	_text_edit.placeholder_text = placeholder if not placeholder.is_empty() else "Write as much detail as you need"
	_text_edit.text = value
	_is_configuring = false

func get_primary_control() -> Control:
	return _text_edit if _text_edit.visible else _line_edit

func set_focus_presentation(enabled: bool) -> void:
	if _focus_presentation == enabled:
		return
	_focus_presentation = enabled
	refresh_responsive_layout(get_viewport().get_visible_rect().size)

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	var compact_layout: bool = viewport_size.x <= 640.0
	if _focus_presentation:
		add_theme_constant_override("separation", 14 if compact_layout else 18)
		_line_edit.custom_minimum_size = Vector2(0.0, 74.0 if compact_layout else 88.0)
		_text_edit.custom_minimum_size = Vector2(0.0, 220.0 if compact_layout else 280.0)
		_line_edit.add_theme_font_size_override("font_size", 22 if compact_layout else 26)
		_text_edit.add_theme_font_size_override("font_size", 20 if compact_layout else 24)
		return
	add_theme_constant_override("separation", 6 if compact_layout else 8)
	_line_edit.custom_minimum_size = Vector2(0.0, 40.0 if compact_layout else 42.0)
	_text_edit.custom_minimum_size = Vector2(0.0, 108.0 if compact_layout else 132.0)
	_line_edit.remove_theme_font_size_override("font_size")
	_text_edit.remove_theme_font_size_override("font_size")

func _on_line_edit_text_changed(value: String) -> void:
	if _is_configuring:
		return
	value_changed.emit(value)

func _on_text_edit_text_changed() -> void:
	if _is_configuring:
		return
	value_changed.emit(_text_edit.text)
