class_name TypedAnswerField
extends VBoxContainer

signal value_changed(value: String)

@onready var _line_edit: LineEdit = $LineEdit
@onready var _text_edit: TextEdit = $TextEdit

var _is_configuring := false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	SurveyStyle.style_line_edit(_line_edit)
	SurveyStyle.style_text_edit(_text_edit)
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.custom_minimum_size = Vector2(0, 132)
	_line_edit.text_changed.connect(_on_line_edit_text_changed)
	_text_edit.text_changed.connect(_on_text_edit_text_changed)

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

func _on_line_edit_text_changed(value: String) -> void:
	if _is_configuring:
		return
	value_changed.emit(value)

func _on_text_edit_text_changed() -> void:
	if _is_configuring:
		return
	value_changed.emit(_text_edit.text)
