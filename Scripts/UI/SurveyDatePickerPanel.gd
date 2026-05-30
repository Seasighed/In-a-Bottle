class_name SurveyDatePickerPanel
extends PanelContainer

signal date_picked(value: String)

const MONTH_DISPLAY_NAMES := [
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec"
]
const COLUMN_DAY := &"day"
const COLUMN_MONTH := &"month"
const COLUMN_YEAR := &"year"

@onready var _stack: VBoxContainer = $Stack
@onready var _picker_row: HBoxContainer = $Stack/PickerRow
@onready var _day_column: PanelContainer = $Stack/PickerRow/DayColumn
@onready var _day_stack: VBoxContainer = $Stack/PickerRow/DayColumn/ColumnStack
@onready var _day_header_label: Label = $Stack/PickerRow/DayColumn/ColumnStack/HeaderLabel
@onready var _day_previous_label: Label = $Stack/PickerRow/DayColumn/ColumnStack/PreviousLabel
@onready var _day_current_label: Label = $Stack/PickerRow/DayColumn/ColumnStack/CurrentLabel
@onready var _day_next_label: Label = $Stack/PickerRow/DayColumn/ColumnStack/NextLabel
@onready var _month_column: PanelContainer = $Stack/PickerRow/MonthColumn
@onready var _month_stack: VBoxContainer = $Stack/PickerRow/MonthColumn/ColumnStack
@onready var _month_header_label: Label = $Stack/PickerRow/MonthColumn/ColumnStack/HeaderLabel
@onready var _month_previous_label: Label = $Stack/PickerRow/MonthColumn/ColumnStack/PreviousLabel
@onready var _month_current_label: Label = $Stack/PickerRow/MonthColumn/ColumnStack/CurrentLabel
@onready var _month_next_label: Label = $Stack/PickerRow/MonthColumn/ColumnStack/NextLabel
@onready var _year_column: PanelContainer = $Stack/PickerRow/YearColumn
@onready var _year_stack: VBoxContainer = $Stack/PickerRow/YearColumn/ColumnStack
@onready var _year_header_label: Label = $Stack/PickerRow/YearColumn/ColumnStack/HeaderLabel
@onready var _year_previous_label: Label = $Stack/PickerRow/YearColumn/ColumnStack/PreviousLabel
@onready var _year_current_label: Label = $Stack/PickerRow/YearColumn/ColumnStack/CurrentLabel
@onready var _year_next_label: Label = $Stack/PickerRow/YearColumn/ColumnStack/NextLabel
@onready var _footer_row: HBoxContainer = $Stack/FooterRow
@onready var _today_button: Button = $Stack/FooterRow/TodayButton
@onready var _clear_button: Button = $Stack/FooterRow/ClearButton

var _column_views: Dictionary = {}
var _drag_states: Dictionary = {}
var _selected_year := 0
var _selected_month := 0
var _selected_day := 0
var _selected_date_text := ""
var _focus_presentation := false
var _journey_focus_presentation := false
var _drag_step_threshold := 20.0

func _ready() -> void:
	_configure_column_views()
	_connect_signals_once()
	_reset_selection_to_today()
	refresh_theme()
	refresh_layout(_resolved_viewport_size(), false, false)

func sync_selected_value(value: String, _align_display_month: bool = false) -> void:
	var parsed := _parse_date_text(value)
	if not parsed.is_empty():
		_selected_year = int(parsed.get("year", _selected_year))
		_selected_month = int(parsed.get("month", _selected_month))
		_selected_day = int(parsed.get("day", _selected_day))
		_selected_date_text = _format_date_parts(parsed)
	else:
		_selected_date_text = ""
		if _selected_year <= 0 or _selected_month <= 0 or _selected_day <= 0:
			_reset_selection_to_today()
	_clamp_day_to_month()
	_refresh_picker()

func refresh_theme() -> void:
	var panel_style := SurveyStyle.panel(SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 16, 1)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", panel_style)
	SurveyStyle.apply_secondary_button(_today_button)
	SurveyStyle.apply_secondary_button(_clear_button)
	for button in [_today_button, _clear_button]:
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size = Vector2(0.0, 36.0)
		_tune_button_padding(button, 10.0, 6.0)
	for kind in _column_views.keys():
		_apply_column_theme(kind)
	_refresh_picker()

func refresh_layout(viewport_size: Vector2, focus_presentation: bool, journey_focus_presentation: bool) -> void:
	_focus_presentation = focus_presentation
	_journey_focus_presentation = journey_focus_presentation
	var compact_layout: bool = viewport_size.x <= 640.0
	var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
	var scale := journey_scale if journey_focus_presentation else 1.0
	var panel_padding := int(round(((12 if compact_layout else 14) * scale) if focus_presentation else (10 if compact_layout else 12)))
	var panel_style := get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var tuned_style := (panel_style as StyleBoxFlat).duplicate()
		tuned_style.content_margin_left = panel_padding
		tuned_style.content_margin_right = panel_padding
		tuned_style.content_margin_top = panel_padding
		tuned_style.content_margin_bottom = panel_padding
		add_theme_stylebox_override("panel", tuned_style)
	_stack.add_theme_constant_override("separation", int(round(((10 if compact_layout else 12) * scale) if focus_presentation else (8 if compact_layout else 10))))
	_picker_row.add_theme_constant_override("separation", int(round(((8 if compact_layout else 10) * scale) if focus_presentation else (6 if compact_layout else 8))))
	_footer_row.add_theme_constant_override("separation", int(round(((8 if compact_layout else 10) * scale) if focus_presentation else 8)))
	var column_height := ((122.0 if compact_layout else 132.0) * scale) if focus_presentation else ((92.0 if compact_layout else 100.0) * scale)
	var column_stack_separation := int(round(((4 if compact_layout else 5) * scale) if focus_presentation else 3))
	var header_font_size := int(round(((12 if compact_layout else 13) * scale) if focus_presentation else 10))
	var side_font_size := int(round(((14 if compact_layout else 15) * scale) if focus_presentation else 11))
	var current_font_size := int(round(((22 if compact_layout else 24) * scale) if focus_presentation else ((16 if compact_layout else 18) * scale)))
	var column_padding_horizontal := ((10.0 if compact_layout else 12.0) * scale) if focus_presentation else 8.0
	var column_padding_vertical := ((8.0 if compact_layout else 10.0) * scale) if focus_presentation else 6.0
	for kind in _column_views.keys():
		var view: Dictionary = _column_views[kind]
		var panel := view.get("panel") as PanelContainer
		var stack := view.get("stack") as VBoxContainer
		var header := view.get("header") as Label
		var previous := view.get("previous") as Label
		var current := view.get("current") as Label
		var next := view.get("next") as Label
		if panel != null:
			panel.custom_minimum_size = Vector2(0.0, column_height)
			var column_style := panel.get_theme_stylebox("panel")
			if column_style is StyleBoxFlat:
				var tuned_column_style := (column_style as StyleBoxFlat).duplicate()
				tuned_column_style.content_margin_left = column_padding_horizontal
				tuned_column_style.content_margin_right = column_padding_horizontal
				tuned_column_style.content_margin_top = column_padding_vertical
				tuned_column_style.content_margin_bottom = column_padding_vertical
				panel.add_theme_stylebox_override("panel", tuned_column_style)
		if stack != null:
			stack.add_theme_constant_override("separation", column_stack_separation)
		if header != null:
			header.add_theme_font_size_override("font_size", header_font_size)
		for label in [previous, next]:
			if label != null:
				label.add_theme_font_size_override("font_size", side_font_size)
		if current != null:
			current.add_theme_font_size_override("font_size", current_font_size)
	var footer_height := ((42.0 if compact_layout else 46.0) * scale) if focus_presentation else ((34.0 if compact_layout else 36.0) * scale)
	for button in [_today_button, _clear_button]:
		button.custom_minimum_size = Vector2(0.0, footer_height)
		button.add_theme_font_size_override("font_size", int(round(((14 if compact_layout else 15) * scale) if focus_presentation else ((12 if compact_layout else 13) * scale))))
		_tune_button_padding(
			button,
			((12.0 if compact_layout else 14.0) * scale) if focus_presentation else (10.0 if compact_layout else 12.0),
			((7.0 if compact_layout else 8.0) * scale) if focus_presentation else 6.0
		)
	_drag_step_threshold = ((24.0 if compact_layout else 28.0) * scale) if focus_presentation else ((18.0 if compact_layout else 20.0) * scale)
	_refresh_picker()

func _configure_column_views() -> void:
	_column_views = {
		COLUMN_DAY: {
			"panel": _day_column,
			"stack": _day_stack,
			"header": _day_header_label,
			"previous": _day_previous_label,
			"current": _day_current_label,
			"next": _day_next_label
		},
		COLUMN_MONTH: {
			"panel": _month_column,
			"stack": _month_stack,
			"header": _month_header_label,
			"previous": _month_previous_label,
			"current": _month_current_label,
			"next": _month_next_label
		},
		COLUMN_YEAR: {
			"panel": _year_column,
			"stack": _year_stack,
			"header": _year_header_label,
			"previous": _year_previous_label,
			"current": _year_current_label,
			"next": _year_next_label
		}
	}
	for kind in _column_views.keys():
		var view: Dictionary = _column_views[kind]
		var panel := view.get("panel") as PanelContainer
		var header := view.get("header") as Label
		var previous := view.get("previous") as Label
		var current := view.get("current") as Label
		var next := view.get("next") as Label
		if panel != null:
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
		for label in [header, previous, current, next]:
			if label != null:
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_drag_states[kind] = {
			"mouse_active": false,
			"touch_active": false,
			"touch_index": -1,
			"last_y": 0.0,
			"accumulated": 0.0
		}

func _connect_signals_once() -> void:
	if _today_button != null and not _today_button.pressed.is_connected(_on_today_button_pressed):
		_today_button.pressed.connect(_on_today_button_pressed)
	if _clear_button != null and not _clear_button.pressed.is_connected(_on_clear_button_pressed):
		_clear_button.pressed.connect(_on_clear_button_pressed)
	for kind in _column_views.keys():
		var view: Dictionary = _column_views[kind]
		var panel := view.get("panel") as PanelContainer
		if panel != null and not panel.gui_input.is_connected(_on_column_gui_input.bind(kind)):
			panel.gui_input.connect(_on_column_gui_input.bind(kind))

func _apply_column_theme(kind: StringName) -> void:
	var view: Dictionary = _column_views.get(kind, {})
	var panel := view.get("panel") as PanelContainer
	var header := view.get("header") as Label
	var previous := view.get("previous") as Label
	var current := view.get("current") as Label
	var next := view.get("next") as Label
	if panel != null:
		var column_style := SurveyStyle.panel(SurveyStyle.SURFACE, SurveyStyle.BORDER, 14, 1)
		column_style.content_margin_left = 8
		column_style.content_margin_right = 8
		column_style.content_margin_top = 6
		column_style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", column_style)
	var header_text := "Day"
	var tooltip := "Swipe or scroll to adjust the day."
	match kind:
		COLUMN_MONTH:
			header_text = "Month"
			tooltip = "Swipe or scroll to adjust the month."
		COLUMN_YEAR:
			header_text = "Year"
			tooltip = "Swipe or scroll to adjust the year."
	if panel != null:
		panel.tooltip_text = tooltip
	if header != null:
		header.text = header_text
		header.add_theme_color_override("font_color", SurveyStyle.TEXT_MUTED)
		header.add_theme_constant_override("outline_size", 0)
	if previous != null:
		previous.add_theme_color_override("font_color", SurveyStyle.TEXT_MUTED)
		previous.add_theme_constant_override("outline_size", 0)
	if current != null:
		current.add_theme_color_override("font_color", SurveyStyle.HIGHLIGHT_GOLD)
		current.add_theme_constant_override("outline_size", 1)
	if next != null:
		next.add_theme_color_override("font_color", SurveyStyle.TEXT_MUTED)
		next.add_theme_constant_override("outline_size", 0)

func _refresh_picker() -> void:
	if _selected_year <= 0 or _selected_month <= 0 or _selected_day <= 0:
		_reset_selection_to_today()
	_refresh_column(
		COLUMN_DAY,
		_day_display_value(_wrapped_day(_selected_day, -1)),
		_day_display_value(_selected_day),
		_day_display_value(_wrapped_day(_selected_day, 1))
	)
	_refresh_column(
		COLUMN_MONTH,
		_month_display_name(_wrapped_value(_selected_month, -1, 1, 12)),
		_month_display_name(_selected_month),
		_month_display_name(_wrapped_value(_selected_month, 1, 1, 12))
	)
	_refresh_column(
		COLUMN_YEAR,
		_year_display_value(max(_selected_year - 1, 1)),
		_year_display_value(_selected_year),
		_year_display_value(_selected_year + 1)
	)

func _refresh_column(kind: StringName, previous_text: String, current_text: String, next_text: String) -> void:
	var view: Dictionary = _column_views.get(kind, {})
	var previous := view.get("previous") as Label
	var current := view.get("current") as Label
	var next := view.get("next") as Label
	if previous != null:
		previous.text = previous_text
	if current != null:
		current.text = current_text
	if next != null:
		next.text = next_text

func _on_today_button_pressed() -> void:
	var today := _today_date_parts()
	_selected_year = int(today.get("year", _selected_year))
	_selected_month = int(today.get("month", _selected_month))
	_selected_day = int(today.get("day", _selected_day))
	_emit_selected_date()

func _on_clear_button_pressed() -> void:
	_selected_date_text = ""
	_refresh_picker()
	date_picked.emit("")

func _on_column_gui_input(event: InputEvent, kind: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_step_column(kind, 1)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_step_column(kind, -1)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_mouse_drag(kind, mouse_event.position.y)
			else:
				_end_mouse_drag(kind)
			accept_event()
			return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if _is_mouse_drag_active(kind):
			_continue_drag(kind, motion_event.position.y)
			accept_event()
			return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_touch_drag(kind, touch_event.index, touch_event.position.y)
		else:
			_end_touch_drag(kind, touch_event.index)
		accept_event()
		return
	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if _is_touch_drag_active(kind, drag_event.index):
			_continue_drag(kind, drag_event.position.y)
			accept_event()

func _begin_mouse_drag(kind: StringName, y_position: float) -> void:
	var state: Dictionary = _drag_states.get(kind, {}).duplicate(true)
	state["mouse_active"] = true
	state["last_y"] = y_position
	state["accumulated"] = 0.0
	_drag_states[kind] = state

func _end_mouse_drag(kind: StringName) -> void:
	var state: Dictionary = _drag_states.get(kind, {}).duplicate(true)
	state["mouse_active"] = false
	state["accumulated"] = 0.0
	_drag_states[kind] = state

func _begin_touch_drag(kind: StringName, touch_index: int, y_position: float) -> void:
	var state: Dictionary = _drag_states.get(kind, {}).duplicate(true)
	state["touch_active"] = true
	state["touch_index"] = touch_index
	state["last_y"] = y_position
	state["accumulated"] = 0.0
	_drag_states[kind] = state

func _end_touch_drag(kind: StringName, touch_index: int) -> void:
	if not _is_touch_drag_active(kind, touch_index):
		return
	var state: Dictionary = _drag_states.get(kind, {}).duplicate(true)
	state["touch_active"] = false
	state["touch_index"] = -1
	state["accumulated"] = 0.0
	_drag_states[kind] = state

func _continue_drag(kind: StringName, y_position: float) -> void:
	var state: Dictionary = _drag_states.get(kind, {}).duplicate(true)
	var delta := y_position - float(state.get("last_y", y_position))
	state["last_y"] = y_position
	state["accumulated"] = float(state.get("accumulated", 0.0)) + delta
	while float(state.get("accumulated", 0.0)) <= -_drag_step_threshold:
		_step_column(kind, 1)
		state["accumulated"] = float(state.get("accumulated", 0.0)) + _drag_step_threshold
	while float(state.get("accumulated", 0.0)) >= _drag_step_threshold:
		_step_column(kind, -1)
		state["accumulated"] = float(state.get("accumulated", 0.0)) - _drag_step_threshold
	_drag_states[kind] = state

func _is_mouse_drag_active(kind: StringName) -> bool:
	var state := _drag_states.get(kind, {}) as Dictionary
	return bool(state.get("mouse_active", false))

func _is_touch_drag_active(kind: StringName, touch_index: int) -> bool:
	var state := _drag_states.get(kind, {}) as Dictionary
	return bool(state.get("touch_active", false)) and int(state.get("touch_index", -1)) == touch_index

func _step_column(kind: StringName, delta: int) -> void:
	if delta == 0:
		return
	match kind:
		COLUMN_DAY:
			_selected_day = _wrapped_day(_selected_day, delta)
		COLUMN_MONTH:
			_selected_month = _wrapped_value(_selected_month, delta, 1, 12)
			_clamp_day_to_month()
		COLUMN_YEAR:
			_selected_year = max(_selected_year + delta, 1)
			_clamp_day_to_month()
	_emit_selected_date()

func _tune_button_padding(button: Button, horizontal_padding: float, vertical_padding: float) -> void:
	if button == null:
		return
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

func _reset_selection_to_today() -> void:
	var today := _today_date_parts()
	_selected_year = int(today.get("year", 1970))
	_selected_month = int(today.get("month", 1))
	_selected_day = int(today.get("day", 1))

func _today_date_parts() -> Dictionary:
	return Time.get_date_dict_from_system()

func _emit_selected_date() -> void:
	_clamp_day_to_month()
	_selected_date_text = _format_date_parts({
		"year": _selected_year,
		"month": _selected_month,
		"day": _selected_day
	})
	_refresh_picker()
	date_picked.emit(_selected_date_text)

func _clamp_day_to_month() -> void:
	var max_day := _days_in_month(_selected_year, _selected_month)
	_selected_day = clampi(_selected_day, 1, max_day)

func _wrapped_day(day: int, delta: int) -> int:
	var max_day := _days_in_month(_selected_year, _selected_month)
	return _wrapped_value(day, delta, 1, max_day)

func _wrapped_value(value: int, delta: int, minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	var range_size := maximum - minimum + 1
	return minimum + posmod((value - minimum) + delta, range_size)

func _day_display_value(value: int) -> String:
	return "%02d" % value

func _month_display_name(value: int) -> String:
	return MONTH_DISPLAY_NAMES[clampi(value, 1, 12) - 1]

func _year_display_value(value: int) -> String:
	return "%04d" % max(value, 1)

func _parse_date_text(value: String) -> Dictionary:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return {}
	var normalized := trimmed.replace("/", "-")
	var parts := normalized.split("-", false)
	if parts.size() != 3:
		return {}
	for part in parts:
		if not str(part).is_valid_int():
			return {}
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year <= 0 or month < 1 or month > 12:
		return {}
	var max_day := _days_in_month(year, month)
	if day < 1 or day > max_day:
		return {}
	return {
		"year": year,
		"month": month,
		"day": day
	}

func _format_date_parts(parts: Dictionary) -> String:
	if parts.is_empty():
		return ""
	return "%04d-%02d-%02d" % [
		int(parts.get("year", 0)),
		int(parts.get("month", 0)),
		int(parts.get("day", 0))
	]

func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
	return 30

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

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
