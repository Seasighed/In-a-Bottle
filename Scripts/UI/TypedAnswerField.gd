class_name TypedAnswerField
extends VBoxContainer

signal value_changed(value: String)

@onready var _line_edit: LineEdit = $LineEdit
@onready var _text_edit: TextEdit = $TextEdit

var _is_configuring := false
var _focus_presentation := false
var _journey_focus_presentation := false
var _configured_value := ""
var _configured_placeholder := ""
var _configured_multiline := false
var _signals_connected := false

func _ready() -> void:
	if not _ensure_controls():
		return
	SurveyStyle.style_line_edit(_line_edit)
	SurveyStyle.style_text_edit(_text_edit)
	_connect_signals_once()
	_apply_configured_state()
	refresh_responsive_layout(get_viewport().get_visible_rect().size)

func configure(value: String, placeholder: String, multiline: bool = false) -> void:
	_configured_value = value
	_configured_placeholder = placeholder
	_configured_multiline = multiline
	_apply_configured_state()

func get_primary_control() -> Control:
	if not _ensure_controls():
		return null
	return _text_edit if _configured_multiline else _line_edit

func set_focus_presentation(enabled: bool) -> void:
	if _focus_presentation == enabled:
		return
	_focus_presentation = enabled
	refresh_responsive_layout(get_viewport().get_visible_rect().size)

func set_journey_focus_presentation(enabled: bool) -> void:
	if _journey_focus_presentation == enabled:
		return
	_journey_focus_presentation = enabled
	refresh_responsive_layout(get_viewport().get_visible_rect().size)

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	if not _ensure_controls():
		return
	var compact_layout: bool = viewport_size.x <= 640.0
	var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
	if _focus_presentation:
		if _journey_focus_presentation:
			add_theme_constant_override("separation", 12 if compact_layout else 14)
			_line_edit.custom_minimum_size = Vector2(0.0, (62.0 if compact_layout else 70.0) * journey_scale)
			_text_edit.custom_minimum_size = Vector2(0.0, (176.0 if compact_layout else 216.0) * journey_scale)
			_line_edit.add_theme_font_size_override("font_size", int(round((18 if compact_layout else 20) * journey_scale)))
			_text_edit.add_theme_font_size_override("font_size", int(round((17 if compact_layout else 19) * journey_scale)))
			return
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

func _ensure_controls() -> bool:
	if _line_edit == null:
		_line_edit = get_node_or_null("LineEdit") as LineEdit
	if _text_edit == null:
		_text_edit = get_node_or_null("TextEdit") as TextEdit
	return _line_edit != null and _text_edit != null

func _connect_signals_once() -> void:
	if _signals_connected or not _ensure_controls():
		return
	_line_edit.text_changed.connect(_on_line_edit_text_changed)
	_text_edit.text_changed.connect(_on_text_edit_text_changed)
	_signals_connected = true

func _apply_configured_state() -> void:
	if not _ensure_controls():
		return
	_connect_signals_once()
	_is_configuring = true
	_line_edit.visible = not _configured_multiline
	_text_edit.visible = _configured_multiline
	_line_edit.placeholder_text = _configured_placeholder if not _configured_placeholder.is_empty() else "Type your answer"
	_line_edit.text = _configured_value
	_text_edit.placeholder_text = _configured_placeholder if not _configured_placeholder.is_empty() else "Write as much detail as you need"
	_text_edit.text = _configured_value
	_is_configuring = false
