class_name SurveyQuestionView
extends Control

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const PRESENTATION_DOCUMENT := &"document"
const PRESENTATION_FOCUS := &"focus"
const PRESENTATION_JOURNEY_FOCUS := &"journey_focus"

signal answer_changed(question_id: String, value: Variant)
signal question_selected(question_id: String)
signal help_requested(question_id: String)

var question: SurveyQuestion
var current_value: Variant
var is_selected := false
var _presentation_mode: StringName = PRESENTATION_DOCUMENT
var _question_debug_ids_enabled := false
var _question_chrome_panel: PanelContainer
var _question_chrome_stack: VBoxContainer
var _question_chrome_title_label: Label
var _question_content_anchor: Control
var _question_type_bar: HBoxContainer
var _question_type_bar_label: Label
var _question_type_bar_left_separator: HSeparator
var _question_type_bar_right_separator: HSeparator
var _question_accent_rail: VSeparator
var _question_content_separator: HSeparator
var _question_help_button: Button

func _ready() -> void:
	if question != null:
		_apply_question()
	_refresh_layout_metrics()
	_apply_selection_state()

func configure(new_question: SurveyQuestion, initial_value: Variant = null) -> void:
	question = new_question
	current_value = initial_value if initial_value != null else question.default_value
	if is_node_ready():
		_apply_question()
		_refresh_layout_metrics()
		_apply_selection_state()

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_node_ready():
		_apply_selection_state()

func set_presentation_mode(mode: StringName) -> void:
	var resolved_mode: StringName = PRESENTATION_DOCUMENT
	if mode == PRESENTATION_FOCUS:
		resolved_mode = PRESENTATION_FOCUS
	elif mode == PRESENTATION_JOURNEY_FOCUS:
		resolved_mode = PRESENTATION_JOURNEY_FOCUS
	if _presentation_mode == resolved_mode:
		return
	_presentation_mode = resolved_mode
	if is_node_ready():
		refresh_responsive_layout(get_viewport().get_visible_rect().size)
		_refresh_layout_metrics()
		_apply_selection_state()

func is_focus_presentation() -> bool:
	return _presentation_mode == PRESENTATION_FOCUS or _presentation_mode == PRESENTATION_JOURNEY_FOCUS

func uses_centered_focus_layout() -> bool:
	return _presentation_mode == PRESENTATION_FOCUS

func is_journey_focus_presentation() -> bool:
	return _presentation_mode == PRESENTATION_JOURNEY_FOCUS

func set_question_debug_ids_enabled(enabled: bool) -> void:
	if _question_debug_ids_enabled == enabled:
		return
	_question_debug_ids_enabled = enabled
	if is_node_ready():
		_refresh_question_chrome()

func focus_primary_control() -> void:
	pass

func refresh_responsive_layout(_viewport_size: Vector2) -> void:
	pass

func configure_question_chrome(panel: PanelContainer, stack: VBoxContainer, title_label: Label, content_anchor: Control = null) -> void:
	_question_chrome_panel = panel
	_question_chrome_stack = stack
	_question_chrome_title_label = title_label
	_question_content_anchor = content_anchor
	_ensure_question_chrome_nodes()
	_refresh_question_chrome()

func emit_answer(value: Variant) -> void:
	current_value = value
	answer_changed.emit(question.id, value)
	call_deferred("_refresh_layout_metrics")

func emit_selected() -> void:
	if question != null:
		question_selected.emit(question.id)

func register_selectable(control: Control) -> void:
	if control == null:
		return
	control.focus_entered.connect(_on_selectable_focus_entered)
	control.gui_input.connect(_on_selectable_gui_input)
	control.mouse_entered.connect(_on_selectable_mouse_entered)

func _refresh_layout_metrics() -> void:
	update_minimum_size()
	var parent_container := get_parent() as Container
	if parent_container != null:
		parent_container.queue_sort()

func _get_minimum_size() -> Vector2:
	var min_size := custom_minimum_size
	var locked_width := is_journey_focus_presentation() and custom_minimum_size.x > 0.0
	for child in get_children():
		var child_control := child as Control
		if child_control != null and child_control.visible:
			var child_min_size := child_control.get_combined_minimum_size()
			if locked_width:
				min_size.y = maxf(min_size.y, child_min_size.y)
			else:
				min_size = min_size.max(child_min_size)
	return min_size

func _on_selectable_focus_entered() -> void:
	emit_selected()

func _on_selectable_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_selectable_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _apply_question() -> void:
	pass

func _apply_selection_state() -> void:
	pass

func _ensure_question_chrome_nodes() -> void:
	if _question_chrome_panel == null or _question_chrome_stack == null or _question_chrome_title_label == null:
		return
	if _question_accent_rail == null:
		_question_accent_rail = _question_chrome_panel.get_node_or_null("QuestionAccentRail") as VSeparator
	if _question_accent_rail == null:
		_question_accent_rail = VSeparator.new()
		_question_accent_rail.name = "QuestionAccentRail"
		_question_accent_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_accent_rail.anchor_top = 0.0
		_question_accent_rail.anchor_bottom = 1.0
		_question_accent_rail.offset_left = 0.0
		_question_accent_rail.offset_top = 12.0
		_question_accent_rail.offset_right = 0.0
		_question_accent_rail.offset_bottom = -12.0
		_question_chrome_panel.add_child(_question_accent_rail)
		_question_chrome_panel.move_child(_question_accent_rail, 0)
	if _question_type_bar == null:
		_question_type_bar = _question_chrome_stack.get_node_or_null("QuestionTypeBar") as HBoxContainer
	if _question_type_bar == null:
		_question_type_bar = HBoxContainer.new()
		_question_type_bar.name = "QuestionTypeBar"
		_question_type_bar.layout_mode = 2
		_question_type_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_question_type_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_type_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		_question_type_bar.add_theme_constant_override("separation", 8)
		_question_type_bar.custom_minimum_size = Vector2(0.0, 24.0)
		_question_type_bar_left_separator = HSeparator.new()
		_question_type_bar_left_separator.name = "QuestionTypeBarLeftSeparator"
		_question_type_bar_left_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_question_type_bar_left_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_type_bar.add_child(_question_type_bar_left_separator)
		_question_type_bar_label = Label.new()
		_question_type_bar_label.name = "QuestionTypeBarLabel"
		_question_type_bar_label.layout_mode = 2
		_question_type_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_question_type_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_question_type_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_type_bar.add_child(_question_type_bar_label)
		_question_help_button = Button.new()
		_question_help_button.name = "QuestionHelpButton"
		_question_help_button.layout_mode = 2
		_question_help_button.text = "?"
		_question_help_button.tooltip_text = "Open question help"
		_question_help_button.focus_mode = Control.FOCUS_ALL
		_question_help_button.pressed.connect(_on_question_help_button_pressed)
		_question_help_button.mouse_entered.connect(_on_selectable_mouse_entered)
		_question_type_bar.add_child(_question_help_button)
		_question_type_bar_right_separator = HSeparator.new()
		_question_type_bar_right_separator.name = "QuestionTypeBarRightSeparator"
		_question_type_bar_right_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_question_type_bar_right_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_type_bar.add_child(_question_type_bar_right_separator)
		_question_chrome_stack.add_child(_question_type_bar)
		var title_index := _question_chrome_stack.get_children().find(_question_chrome_title_label)
		if title_index != -1:
			_question_chrome_stack.move_child(_question_type_bar, title_index + 1)
	if _question_type_bar != null:
		_question_type_bar_left_separator = _question_type_bar.get_node_or_null("QuestionTypeBarLeftSeparator") as HSeparator
		_question_type_bar_label = _question_type_bar.get_node_or_null("QuestionTypeBarLabel") as Label
		_question_help_button = _question_type_bar.get_node_or_null("QuestionHelpButton") as Button
		_question_type_bar_right_separator = _question_type_bar.get_node_or_null("QuestionTypeBarRightSeparator") as HSeparator
		if _question_type_bar_label == null:
			_question_type_bar_label = Label.new()
			_question_type_bar_label.name = "QuestionTypeBarLabel"
			_question_type_bar.add_child(_question_type_bar_label)
		if _question_help_button == null:
			_question_help_button = Button.new()
			_question_help_button.name = "QuestionHelpButton"
			_question_help_button.layout_mode = 2
			_question_help_button.text = "?"
			_question_help_button.tooltip_text = "Open question help"
			_question_help_button.focus_mode = Control.FOCUS_ALL
			_question_help_button.pressed.connect(_on_question_help_button_pressed)
			_question_help_button.mouse_entered.connect(_on_selectable_mouse_entered)
			_question_type_bar.add_child(_question_help_button)
		if _question_type_bar_left_separator == null:
			_question_type_bar_left_separator = HSeparator.new()
			_question_type_bar_left_separator.name = "QuestionTypeBarLeftSeparator"
			_question_type_bar_left_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_question_type_bar.add_child(_question_type_bar_left_separator)
			_question_type_bar.move_child(_question_type_bar_left_separator, 0)
		if _question_type_bar_right_separator == null:
			_question_type_bar_right_separator = HSeparator.new()
			_question_type_bar_right_separator.name = "QuestionTypeBarRightSeparator"
			_question_type_bar_right_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_question_type_bar.add_child(_question_type_bar_right_separator)
	if _question_content_separator == null:
		_question_content_separator = _question_chrome_stack.get_node_or_null("QuestionContentSeparator") as HSeparator
	if _question_content_separator == null:
		_question_content_separator = HSeparator.new()
		_question_content_separator.name = "QuestionContentSeparator"
		_question_content_separator.layout_mode = 2
		_question_content_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_question_content_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_chrome_stack.add_child(_question_content_separator)
	if _question_content_anchor != null:
		var anchor_index := _question_chrome_stack.get_children().find(_question_content_anchor)
		if anchor_index != -1:
			_question_chrome_stack.move_child(_question_content_separator, anchor_index)

func _refresh_question_chrome() -> void:
	if _question_chrome_panel == null or _question_type_bar == null or _question_type_bar_label == null or _question_accent_rail == null:
		return
	var accent_color := SurveyStyle.question_type_color(question.type if question != null else StringName())
	var compact_layout := get_viewport().get_visible_rect().size.x <= 640.0
	var accent_width := 5.0 if is_focus_presentation() else 4.0
	_question_accent_rail.custom_minimum_size = Vector2(accent_width, 0.0)
	_question_accent_rail.visible = question != null
	_question_type_bar.visible = question != null
	if _question_content_separator != null:
		_question_content_separator.visible = question != null
	if question == null:
		return
	var rail_top := accent_color
	rail_top.a = 0.0
	var rail_mid := accent_color.lightened(0.06)
	rail_mid.a = 0.92
	var rail_bottom := accent_color.darkened(0.18)
	rail_bottom.a = 0.0
	_question_accent_rail.add_theme_stylebox_override("separator", SurveyStyle.separator_gradient_style(PackedColorArray([rail_top, rail_mid, rail_bottom]), PackedFloat32Array([0.0, 0.5, 1.0]), false))
	_question_type_bar.custom_minimum_size = Vector2(0.0, 24.0 if not is_focus_presentation() else 26.0)
	_question_type_bar_label.text = question.accent_label(_question_debug_ids_enabled)
	_question_type_bar_label.add_theme_color_override("font_color", accent_color.lightened(0.1))
	_question_type_bar_label.add_theme_font_size_override("font_size", 12 if compact_layout else 13)
	_question_type_bar_label.add_theme_constant_override("outline_size", 0)
	if _question_help_button != null:
		var help_size := 22.0 if compact_layout else 24.0
		_question_help_button.visible = true
		_question_help_button.custom_minimum_size = Vector2(help_size, help_size)
		_question_help_button.text = "?"
		_question_help_button.add_theme_font_size_override("font_size", 12 if compact_layout else 13)
		_question_help_button.add_theme_color_override("font_color", accent_color.lightened(0.16))
		_question_help_button.add_theme_color_override("font_focus_color", accent_color.lightened(0.22))
		_question_help_button.add_theme_color_override("font_hover_color", accent_color.lightened(0.24))
		_question_help_button.add_theme_color_override("font_pressed_color", accent_color.lightened(0.08))
		_question_help_button.add_theme_color_override("font_disabled_color", SurveyStyle.TEXT_MUTED)
		_question_help_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		_question_help_button.add_theme_constant_override("outline_size", 0)
		var normal_style := SurveyStyle.panel(accent_color.darkened(0.46), accent_color.darkened(0.08), 11, 1)
		var hover_style := SurveyStyle.panel(accent_color.darkened(0.36), accent_color.lightened(0.08), 11, 1)
		var pressed_style := SurveyStyle.panel(accent_color.darkened(0.56), accent_color.darkened(0.18), 11, 1)
		for style in [normal_style, hover_style, pressed_style]:
			style.content_margin_left = 0
			style.content_margin_right = 0
			style.content_margin_top = 0
			style.content_margin_bottom = 0
		_question_help_button.add_theme_stylebox_override("normal", normal_style)
		_question_help_button.add_theme_stylebox_override("focus", hover_style)
		_question_help_button.add_theme_stylebox_override("hover", hover_style)
		_question_help_button.add_theme_stylebox_override("pressed", pressed_style)
		_question_help_button.add_theme_stylebox_override("disabled", normal_style)
	var left_start := accent_color
	left_start.a = 0.0
	var left_end := accent_color
	left_end.a = 0.95
	var right_start := accent_color
	right_start.a = 0.95
	var right_end := accent_color
	right_end.a = 0.0
	if _question_type_bar_left_separator != null:
		_question_type_bar_left_separator.custom_minimum_size = Vector2(0.0, 10.0)
		_question_type_bar_left_separator.add_theme_stylebox_override("separator", SurveyStyle.separator_gradient_style(PackedColorArray([left_start, left_end]), PackedFloat32Array([0.0, 1.0]), true))
	if _question_type_bar_right_separator != null:
		_question_type_bar_right_separator.custom_minimum_size = Vector2(0.0, 10.0)
		_question_type_bar_right_separator.add_theme_stylebox_override("separator", SurveyStyle.separator_gradient_style(PackedColorArray([right_start, right_end]), PackedFloat32Array([0.0, 1.0]), true))
	if _question_content_separator != null:
		var content_start := accent_color
		content_start.a = 0.0
		var content_mid := accent_color
		content_mid.a = 0.9
		var content_end := accent_color
		content_end.a = 0.0
		_question_content_separator.custom_minimum_size = Vector2(0.0, 12.0 if is_focus_presentation() else 10.0)
		_question_content_separator.add_theme_stylebox_override("separator", SurveyStyle.separator_gradient_style(PackedColorArray([content_start, content_mid, content_end]), PackedFloat32Array([0.0, 0.5, 1.0]), true))

func _on_question_help_button_pressed() -> void:
	if question == null:
		return
	help_requested.emit(question.id)
