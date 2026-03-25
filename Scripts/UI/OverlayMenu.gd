class_name OverlayMenu
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal resume_requested
signal go_to_start_requested
signal restart_requested
signal clear_section_requested(section_index: int)
signal jump_to_section_requested(section_index: int)
signal search_requested
signal onboarding_requested
signal template_picker_requested
signal settings_requested
signal summary_requested
signal export_requested
signal theme_mode_requested(use_dark_mode: bool)
signal sfx_volume_requested(volume: float)
signal fill_test_answers_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _position_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/PositionLabel
@onready var _restart_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/RestartButton
@onready var _search_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/SearchQuestionsButton
@onready var _navigation_actions: GridContainer = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions
@onready var _onboarding_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions/OnboardingButton
@onready var _template_picker_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions/TemplatePickerButton
@onready var _settings_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions/SettingsButton
@onready var _summary_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions/SummaryButton
@onready var _export_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/NavigationActions/ExportButton
@onready var _theme_toggle_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ThemeToggleButton
@onready var _sfx_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxHeadingLabel
@onready var _sfx_volume_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxVolumeLabel
@onready var _sfx_volume_slider: HSlider = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxVolumeSlider
@onready var _sfx_value_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxValueLabel
@onready var _fill_test_answers_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/FillTestAnswersButton
@onready var _section_heading: Label = $Bounds/Center/Panel/PanelScroll/Stack/SectionHeadingLabel
@onready var _section_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll/Stack/SectionScroll
@onready var _section_list: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/SectionScroll/SectionList

var _survey: SurveyDefinition
var _answers: Dictionary = {}
var _current_section_index := 0
var _current_sfx_volume := SurveyUiFeedback.DEFAULT_SFX_VOLUME
var _compact_layout := false

func _ready() -> void:
	layer = 50
	visible = false
	_restart_button.text = "Clear All Answers"
	_close_button.text = "X"
	_section_heading.text = "Jump To Or Clear A Section"
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_search_button.pressed.connect(_on_search_pressed)
	_onboarding_button.pressed.connect(_on_onboarding_pressed)
	_template_picker_button.pressed.connect(_on_template_picker_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_summary_button.pressed.connect(_on_summary_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_theme_toggle_button.toggled.connect(_on_theme_toggle_toggled)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_value_changed)
	_fill_test_answers_button.pressed.connect(_on_fill_test_answers_pressed)

	for button in [_close_button, _restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button]:
		_wire_feedback(button)

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.style_heading(_heading_label, 22 if _compact_layout else 24)
	SurveyStyle.style_body(_position_label)
	SurveyStyle.style_heading(_sfx_heading_label, 18)
	SurveyStyle.style_body(_sfx_volume_label)
	SurveyStyle.style_caption(_sfx_value_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_heading(_section_heading, 18)
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	SurveyStyle.apply_danger_button(_restart_button)
	SurveyStyle.apply_secondary_button(_search_button)
	SurveyStyle.apply_secondary_button(_onboarding_button)
	SurveyStyle.apply_secondary_button(_template_picker_button)
	SurveyStyle.apply_secondary_button(_settings_button)
	SurveyStyle.apply_secondary_button(_summary_button)
	SurveyStyle.apply_primary_button(_export_button)
	for button in [_restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button]:
		_clear_compact_button_treatment(button)
	_theme_toggle_button.set_pressed_no_signal(SurveyStyle.is_dark_mode())
	_refresh_theme_toggle_button()
	SurveyStyle.apply_secondary_button(_fill_test_answers_button)
	_refresh_sfx_volume_display()
	_apply_layout_button_treatment()
	if _survey != null:
		_refresh_sections()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.04, 12.0, 64.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.04, 12.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))

	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 300.0, 620.0)
	var panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 300.0, 760.0)
	var compact_layout: bool = panel_width <= 420.0
	if _compact_layout != compact_layout:
		_compact_layout = compact_layout
		refresh_theme()
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_section_scroll.custom_minimum_size.y = clampf(panel_height * 0.3, 120.0, 260.0)
	_navigation_actions.columns = 1 if _compact_layout else 2
	_apply_layout_button_treatment()
	if _survey != null:
		_refresh_sections()

func open_menu(survey_definition: SurveyDefinition, current_section_index: int, current_answers: Dictionary, current_sfx_volume: float = SurveyUiFeedback.DEFAULT_SFX_VOLUME, play_feedback: bool = true) -> void:
	var was_visible := visible
	_survey = survey_definition
	_answers = current_answers.duplicate(true)
	_current_section_index = current_section_index
	_current_sfx_volume = clampf(current_sfx_volume, 0.0, 1.0)
	_theme_toggle_button.set_pressed_no_signal(SurveyStyle.is_dark_mode())
	_refresh_theme_toggle_button()
	_sfx_volume_slider.set_value_no_signal(_current_sfx_volume)
	_refresh_sfx_volume_display()
	_refresh_sections()
	show()
	if play_feedback and not was_visible:
		SURVEY_UI_FEEDBACK.play_menu_open()
	call_deferred("_reset_scroll_position")

func close_menu(play_feedback: bool = true) -> void:
	if not visible:
		return
	hide()
	if play_feedback:
		SURVEY_UI_FEEDBACK.play_menu_close()

func _refresh_sections() -> void:
	_clear_section_list()
	if _survey == null:
		_position_label.text = ""
		_restart_button.disabled = true
		return

	var section_count: int = _survey.sections.size()
	var answered_total: int = _total_answered_count()
	var stored_total: int = _total_stored_response_count()
	var visible_section_number: int = clampi(_current_section_index + 1, 1, max(section_count, 1))
	_position_label.text = "Currently viewing section %d of %d. %d answered so far." % [visible_section_number, section_count, answered_total]
	_restart_button.disabled = stored_total == 0

	for index in range(section_count):
		var section: SurveySection = _survey.sections[index]
		var answered_count: int = section.answered_count(_answers)
		var stored_count: int = _stored_response_count(section)

		var row: BoxContainer = VBoxContainer.new() if _compact_layout else HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6 if _compact_layout else 8)

		var jump_button: Button = Button.new()
		jump_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jump_button.text = "%s (%d/%d)" % [section.display_title(index), answered_count, section.questions.size()]
		if index == _current_section_index:
			SurveyStyle.apply_primary_button(jump_button)
		else:
			SurveyStyle.apply_secondary_button(jump_button)
		if _compact_layout:
			_apply_compact_button_treatment(jump_button)
		jump_button.pressed.connect(_on_section_pressed.bind(index))
		_wire_feedback(jump_button)
		row.add_child(jump_button)

		var clear_button: Button = Button.new()
		clear_button.text = "Clear"
		clear_button.disabled = stored_count == 0
		SurveyStyle.apply_danger_button(clear_button)
		if _compact_layout:
			clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_compact_button_treatment(clear_button)
		else:
			clear_button.custom_minimum_size.x = 86.0
		clear_button.pressed.connect(_on_clear_section_pressed.bind(index))
		_wire_feedback(clear_button)
		row.add_child(clear_button)

		_section_list.add_child(row)

func _clear_section_list() -> void:
	for child in _section_list.get_children():
		child.free()

func _refresh_theme_toggle_button() -> void:
	_theme_toggle_button.text = "Theme: Dark" if _theme_toggle_button.button_pressed else "Theme: Light"
	if _theme_toggle_button.button_pressed:
		SurveyStyle.apply_primary_button(_theme_toggle_button)
	else:
		SurveyStyle.apply_secondary_button(_theme_toggle_button)
	_apply_compact_button_treatment(_theme_toggle_button)

func _refresh_sfx_volume_display() -> void:
	if _sfx_volume_slider == null:
		return
	_current_sfx_volume = clampf(_sfx_volume_slider.value, 0.0, 1.0)
	_sfx_value_label.text = "%d%%" % int(round(_current_sfx_volume * 100.0))

func _apply_layout_button_treatment() -> void:
	if not is_node_ready() or not _compact_layout:
		return
	for button in [_restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button]:
		_apply_compact_button_treatment(button)

func _clear_compact_button_treatment(button: Button) -> void:
	button.custom_minimum_size = Vector2.ZERO
	button.remove_theme_font_size_override("font_size")
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.remove_theme_stylebox_override(state_name)

func _apply_compact_button_treatment(button: Button) -> void:
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.add_theme_font_size_override("font_size", 14)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = button.get_theme_stylebox(state_name)
		if style is StyleBoxFlat:
			var compact_style: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
			compact_style.content_margin_left = 12
			compact_style.content_margin_right = 12
			compact_style.content_margin_top = 7
			compact_style.content_margin_bottom = 7
			button.add_theme_stylebox_override(state_name, compact_style)

func _reset_scroll_position() -> void:
	if _panel_scroll == null:
		return
	_panel_scroll.scroll_vertical = 0
	_panel_scroll.scroll_horizontal = 0

func _wire_feedback(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_button_hovered)
	button.pressed.connect(_on_button_pressed_feedback)

func _total_answered_count() -> int:
	if _survey == null:
		return 0
	var total := 0
	for section in _survey.sections:
		total += section.answered_count(_answers)
	return total

func _total_stored_response_count() -> int:
	if _survey == null:
		return 0
	var total := 0
	for section in _survey.sections:
		total += _stored_response_count(section)
	return total

func _stored_response_count(section: SurveySection) -> int:
	var total := 0
	for question in section.questions:
		if _answers.has(question.id):
			total += 1
	return total

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			resume_requested.emit()

func _on_close_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_search_pressed() -> void:
	search_requested.emit()

func _on_onboarding_pressed() -> void:
	onboarding_requested.emit()

func _on_template_picker_pressed() -> void:
	template_picker_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_summary_pressed() -> void:
	summary_requested.emit()

func _on_export_pressed() -> void:
	export_requested.emit()

func _on_clear_section_pressed(section_index: int) -> void:
	clear_section_requested.emit(section_index)

func _on_theme_toggle_toggled(button_pressed: bool) -> void:
	_refresh_theme_toggle_button()
	theme_mode_requested.emit(button_pressed)

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	_current_sfx_volume = clampf(value, 0.0, 1.0)
	_refresh_sfx_volume_display()
	sfx_volume_requested.emit(_current_sfx_volume)

func _on_fill_test_answers_pressed() -> void:
	fill_test_answers_requested.emit()

func _on_section_pressed(section_index: int) -> void:
	jump_to_section_requested.emit(section_index)
