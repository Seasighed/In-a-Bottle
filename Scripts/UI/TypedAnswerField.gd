class_name TypedAnswerField
extends VBoxContainer

signal value_changed(value: String)

const INPUT_KIND_TEXT := &"text"
const INPUT_KIND_DATE := SurveyQuestion.TYPE_DATE

@onready var _field_row: HBoxContainer = $FieldRow
@onready var _line_edit: LineEdit = $FieldRow/LineEdit
@onready var _calendar_button: Button = $FieldRow/CalendarButton
@onready var _text_edit: TextEdit = $TextEdit
@onready var _date_picker_panel: SurveyDatePickerPanel = $DatePickerPanel

var _is_configuring := false
var _focus_presentation := false
var _journey_focus_presentation := false
var _configured_value := ""
var _configured_placeholder := ""
var _configured_multiline := false
var _configured_input_kind: StringName = INPUT_KIND_TEXT
var _signals_connected := false
var _charge_ratio := 0.0

func _ready() -> void:
	if not _ensure_controls():
		return
	SurveyStyle.style_line_edit(_line_edit)
	SurveyStyle.style_text_edit(_text_edit)
	_connect_signals_once()
	_apply_configured_state()
	refresh_responsive_layout(_resolved_viewport_size())

func configure(value: String, placeholder: String, multiline: bool = false, input_kind: StringName = INPUT_KIND_TEXT) -> void:
	_configured_value = value
	_configured_placeholder = placeholder
	_configured_multiline = multiline
	_configured_input_kind = input_kind
	_apply_configured_state()

func get_primary_control() -> Control:
	if not _ensure_controls():
		return null
	return _text_edit if _configured_multiline else _line_edit

func get_additional_selectable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _ensure_controls():
		return controls
	if _is_date_input():
		controls.append(_calendar_button)
	return controls

func set_focus_presentation(enabled: bool) -> void:
	if _focus_presentation == enabled:
		return
	_focus_presentation = enabled
	refresh_responsive_layout(_resolved_viewport_size())

func set_journey_focus_presentation(enabled: bool) -> void:
	if _journey_focus_presentation == enabled:
		return
	_journey_focus_presentation = enabled
	refresh_responsive_layout(_resolved_viewport_size())

func set_charge_ratio(ratio: float) -> void:
	var resolved_ratio := clampf(ratio, 0.0, 1.0)
	if is_equal_approx(_charge_ratio, resolved_ratio):
		return
	_charge_ratio = resolved_ratio
	_apply_charge_glow()

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	if not _ensure_controls():
		return
	var compact_layout: bool = viewport_size.x <= 640.0
	var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
	if _field_row != null:
		_field_row.add_theme_constant_override("separation", int(round(((10 if compact_layout else 12) * journey_scale) if _journey_focus_presentation else (8 if compact_layout else 10))))
	if _focus_presentation:
		if _journey_focus_presentation:
			add_theme_constant_override("separation", 12 if compact_layout else 14)
			_line_edit.custom_minimum_size = Vector2(0.0, (62.0 if compact_layout else 70.0) * journey_scale)
			_text_edit.custom_minimum_size = Vector2(0.0, (176.0 if compact_layout else 216.0) * journey_scale)
			_line_edit.add_theme_font_size_override("font_size", int(round((18 if compact_layout else 20) * journey_scale)))
			_text_edit.add_theme_font_size_override("font_size", int(round((17 if compact_layout else 19) * journey_scale)))
			_refresh_date_input_presentation(viewport_size)
			_apply_charge_glow()
			return
		add_theme_constant_override("separation", 14 if compact_layout else 18)
		_line_edit.custom_minimum_size = Vector2(0.0, 74.0 if compact_layout else 88.0)
		_text_edit.custom_minimum_size = Vector2(0.0, 220.0 if compact_layout else 280.0)
		_line_edit.add_theme_font_size_override("font_size", 22 if compact_layout else 26)
		_text_edit.add_theme_font_size_override("font_size", 20 if compact_layout else 24)
		_refresh_date_input_presentation(viewport_size)
		_apply_charge_glow()
		return
	add_theme_constant_override("separation", 6 if compact_layout else 8)
	_line_edit.custom_minimum_size = Vector2(0.0, 40.0 if compact_layout else 42.0)
	_text_edit.custom_minimum_size = Vector2(0.0, 108.0 if compact_layout else 132.0)
	_line_edit.remove_theme_font_size_override("font_size")
	_text_edit.remove_theme_font_size_override("font_size")
	_refresh_date_input_presentation(viewport_size)
	_apply_charge_glow()

func _on_line_edit_text_changed(value: String) -> void:
	if _is_configuring:
		return
	if _is_date_input() and _date_picker_panel != null:
		_date_picker_panel.sync_selected_value(value, _date_picker_panel.visible)
	value_changed.emit(value)

func _on_text_edit_text_changed() -> void:
	if _is_configuring:
		return
	value_changed.emit(_text_edit.text)

func _ensure_controls() -> bool:
	if _field_row == null:
		_field_row = get_node_or_null("FieldRow") as HBoxContainer
	if _line_edit == null:
		_line_edit = get_node_or_null("FieldRow/LineEdit") as LineEdit
	if _calendar_button == null:
		_calendar_button = get_node_or_null("FieldRow/CalendarButton") as Button
	if _text_edit == null:
		_text_edit = get_node_or_null("TextEdit") as TextEdit
	if _date_picker_panel == null:
		_date_picker_panel = get_node_or_null("DatePickerPanel") as SurveyDatePickerPanel
	return _field_row != null and _line_edit != null and _calendar_button != null and _text_edit != null and _date_picker_panel != null

func _connect_signals_once() -> void:
	if _signals_connected or not _ensure_controls():
		return
	_line_edit.text_changed.connect(_on_line_edit_text_changed)
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	if _line_edit.has_signal("text_submitted"):
		_line_edit.text_submitted.connect(_on_line_edit_text_submitted)
	_text_edit.text_changed.connect(_on_text_edit_text_changed)
	_calendar_button.pressed.connect(_on_calendar_button_pressed)
	_date_picker_panel.date_picked.connect(_on_date_picker_value_picked)
	_signals_connected = true

func _apply_configured_state() -> void:
	if not _ensure_controls():
		return
	_connect_signals_once()
	_is_configuring = true
	_field_row.visible = not _configured_multiline
	_line_edit.visible = not _configured_multiline
	_text_edit.visible = _configured_multiline
	_line_edit.placeholder_text = _configured_placeholder if not _configured_placeholder.is_empty() else "Type your answer"
	_line_edit.text = _configured_value
	_text_edit.placeholder_text = _configured_placeholder if not _configured_placeholder.is_empty() else "Write as much detail as you need"
	_text_edit.text = _configured_value
	_calendar_button.visible = _is_date_input() and not _configured_multiline
	_calendar_button.text = "Pick"
	_calendar_button.tooltip_text = "Open the calendar date picker."
	_date_picker_panel.visible = false
	_date_picker_panel.sync_selected_value(_configured_value, true)
	set_process_unhandled_input(false)
	_is_configuring = false
	_refresh_date_input_presentation(_resolved_viewport_size())
	_apply_charge_glow()

func _apply_charge_glow() -> void:
	if not _ensure_controls():
		return
	var target: Control = _text_edit if _configured_multiline else _line_edit
	var accent := SurveyStyle.ACCENT_ALT
	if _journey_focus_presentation and _charge_ratio > 0.001:
		SurveyStyle.set_charge_glow(target, _charge_ratio, accent, SurveyStyle.HIGHLIGHT_GOLD)
	else:
		SurveyStyle.clear_charge_glow(_line_edit)
		SurveyStyle.clear_charge_glow(_text_edit)

func _refresh_date_input_presentation(viewport_size: Vector2) -> void:
	if not _ensure_controls():
		return
	if _calendar_button != null:
		if _is_date_input() and not _configured_multiline:
			SurveyStyle.apply_secondary_button(_calendar_button)
			var compact_layout: bool = viewport_size.x <= 640.0
			var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
			_calendar_button.text = "Done" if _date_picker_panel != null and _date_picker_panel.visible else "Pick"
			_calendar_button.tooltip_text = "Close the date picker." if _date_picker_panel != null and _date_picker_panel.visible else "Open the compact date picker."
			if _focus_presentation:
				var button_height := ((60.0 if compact_layout else 68.0) * journey_scale) if _journey_focus_presentation else (72.0 if compact_layout else 88.0)
				_calendar_button.custom_minimum_size = Vector2((90.0 if compact_layout else 98.0) * (journey_scale if _journey_focus_presentation else 1.0), button_height)
				_calendar_button.add_theme_font_size_override("font_size", int(round((16 if compact_layout else 18) * (journey_scale if _journey_focus_presentation else 1.0))))
			else:
				_calendar_button.custom_minimum_size = Vector2(72.0, 40.0 if compact_layout else 42.0)
				_calendar_button.add_theme_font_size_override("font_size", 13)
			_tune_calendar_button_padding(_calendar_button, _focus_presentation)
		else:
			_calendar_button.visible = false
	if _date_picker_panel != null:
		_date_picker_panel.refresh_theme()
		_date_picker_panel.refresh_layout(viewport_size, _focus_presentation, _journey_focus_presentation)

func _tune_calendar_button_padding(button: Button, focus_presentation: bool) -> void:
	var horizontal_padding := 12.0 if focus_presentation else 10.0
	var vertical_padding := 6.0 if focus_presentation else 4.0
	for state_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state_name)
		if style is not StyleBoxFlat:
			continue
		var tuned_style := (style as StyleBoxFlat).duplicate()
		tuned_style.content_margin_left = horizontal_padding
		tuned_style.content_margin_right = horizontal_padding
		tuned_style.content_margin_top = vertical_padding
		tuned_style.content_margin_bottom = vertical_padding
		button.add_theme_stylebox_override(state_name, tuned_style)

func _is_date_input() -> bool:
	return _configured_input_kind == INPUT_KIND_DATE and not _configured_multiline

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not _is_date_input():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_open_date_picker()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_open_date_picker()

func _on_line_edit_text_submitted(_value: String) -> void:
	if _is_date_input():
		_hide_date_picker()

func _on_calendar_button_pressed() -> void:
	if not _is_date_input():
		return
	if _date_picker_panel != null and _date_picker_panel.visible:
		_hide_date_picker()
		return
	_open_date_picker()
	_line_edit.grab_focus()

func _on_date_picker_value_picked(value: String) -> void:
	_set_line_edit_value(value, true)

func _set_line_edit_value(value: String, emit_change: bool) -> void:
	if not _ensure_controls():
		return
	var resolved_value := value.strip_edges()
	_is_configuring = true
	_line_edit.text = resolved_value
	_is_configuring = false
	if _date_picker_panel != null:
		_date_picker_panel.sync_selected_value(resolved_value, true)
	if emit_change:
		value_changed.emit(resolved_value)

func _open_date_picker() -> void:
	if not _is_date_input() or _date_picker_panel == null:
		return
	_date_picker_panel.sync_selected_value(_line_edit.text, true)
	if _date_picker_panel.visible:
		return
	_date_picker_panel.visible = true
	set_process_unhandled_input(true)
	_refresh_date_input_presentation(_resolved_viewport_size())
	_request_layout_refresh()

func _hide_date_picker() -> void:
	if _date_picker_panel == null or not _date_picker_panel.visible:
		set_process_unhandled_input(false)
		return
	_date_picker_panel.visible = false
	set_process_unhandled_input(false)
	_refresh_date_input_presentation(_resolved_viewport_size())
	_request_layout_refresh()

func _request_layout_refresh() -> void:
	update_minimum_size()
	var parent_container := get_parent() as Container
	if parent_container != null:
		parent_container.queue_sort()

func _unhandled_input(event: InputEvent) -> void:
	if _date_picker_panel == null or not _date_picker_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_hide_date_picker()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and not get_global_rect().has_point(mouse_event.position):
			_hide_date_picker()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and not get_global_rect().has_point(touch_event.position):
			_hide_date_picker()

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
