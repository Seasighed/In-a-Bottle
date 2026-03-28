class_name OverlayMenu
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const SURVEY_PREVIEW_CONFIG = preload("res://Scripts/UI/SurveyPreviewConfig.gd")

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
signal preview_mode_requested(mode: String)
signal preview_resolution_requested(resolution_id: String)
signal question_debug_ids_requested(enabled: bool)

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _stack: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack
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
@onready var _sfx_row: HBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow
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
var _menu_options: Dictionary = {}
var _preview_heading_label: Label
var _preview_mode_row: HBoxContainer
var _preview_mode_label: Label
var _preview_mode_picker: OptionButton
var _preview_resolution_row: HBoxContainer
var _preview_resolution_label: Label
var _preview_resolution_picker: OptionButton
var _question_chrome_toggle_button: Button
var _syncing_preview_controls := false

func _ready() -> void:
	layer = 50
	visible = false
	_ensure_preview_controls()
	_close_button.text = "X"
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
	if _preview_mode_picker != null:
		_preview_mode_picker.item_selected.connect(_on_preview_mode_picker_item_selected)
		_wire_option_button_feedback(_preview_mode_picker)
	if _preview_resolution_picker != null:
		_preview_resolution_picker.item_selected.connect(_on_preview_resolution_picker_item_selected)
		_wire_option_button_feedback(_preview_resolution_picker)
	if _question_chrome_toggle_button != null:
		_question_chrome_toggle_button.toggled.connect(_on_question_chrome_toggle_toggled)

	for button in [_close_button, _restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button, _question_chrome_toggle_button]:
		if button == null:
			continue
		_wire_feedback(button)

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	_heading_label.text = _option_text("heading_text", "Questionnaire Menu")
	SurveyStyle.style_heading(_heading_label, 22 if _compact_layout else 24)
	SurveyStyle.style_body(_position_label)
	SurveyStyle.style_heading(_sfx_heading_label, 18)
	SurveyStyle.style_body(_sfx_volume_label)
	SurveyStyle.style_caption(_sfx_value_label, SurveyStyle.SOFT_WHITE)
	if _preview_heading_label != null:
		_preview_heading_label.text = _option_text("preview_heading_text", "Testing Preview")
		SurveyStyle.style_heading(_preview_heading_label, 18)
	if _preview_mode_label != null:
		_preview_mode_label.text = _option_text("preview_mode_label", "Responsive Mode")
		SurveyStyle.style_body(_preview_mode_label)
	if _preview_resolution_label != null:
		_preview_resolution_label.text = _option_text("preview_resolution_label", "Window Preset")
		SurveyStyle.style_body(_preview_resolution_label)
	SurveyStyle.style_heading(_section_heading, 18)
	_restart_button.text = _option_text("restart_label", "Clear All Answers")
	_search_button.text = _option_text("search_label", "Search Questions")
	_onboarding_button.text = _option_text("onboarding_label", "Open Onboarding")
	_template_picker_button.text = _option_text("template_picker_label", "Choose Survey Template")
	_settings_button.text = _option_text("settings_label", "Open Settings")
	_summary_button.text = _option_text("summary_label", "Opinion Summary")
	_export_button.text = _option_text("export_label", "Open Export Menu")
	_section_heading.text = _option_text("section_heading_text", "Jump To Or Clear A Section")
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	SurveyStyle.apply_danger_button(_restart_button)
	SurveyStyle.apply_secondary_button(_search_button)
	SurveyStyle.apply_secondary_button(_onboarding_button)
	SurveyStyle.apply_secondary_button(_template_picker_button)
	SurveyStyle.apply_secondary_button(_settings_button)
	SurveyStyle.apply_secondary_button(_summary_button)
	SurveyStyle.apply_primary_button(_export_button)
	if _preview_mode_picker != null:
		SurveyStyle.style_option_button(_preview_mode_picker)
	if _preview_resolution_picker != null:
		SurveyStyle.style_option_button(_preview_resolution_picker)
	for button in [_restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button]:
		_clear_compact_button_treatment(button)
	_theme_toggle_button.set_pressed_no_signal(SurveyStyle.is_dark_mode())
	_refresh_theme_toggle_button()
	SurveyStyle.apply_secondary_button(_fill_test_answers_button)
	if _question_chrome_toggle_button != null:
		SurveyStyle.apply_secondary_button(_question_chrome_toggle_button)
		_clear_compact_button_treatment(_question_chrome_toggle_button)
		_refresh_question_chrome_toggle_button()
	_refresh_preview_controls()
	_refresh_sfx_volume_display()
	_apply_menu_option_state()
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
	_apply_menu_option_state()
	_apply_layout_button_treatment()
	if _preview_mode_row != null:
		_preview_mode_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	if _preview_resolution_row != null:
		_preview_resolution_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	if _survey != null:
		_refresh_sections()

func open_menu(survey_definition: SurveyDefinition, current_section_index: int, current_answers: Dictionary, current_sfx_volume: float = SurveyUiFeedback.DEFAULT_SFX_VOLUME, play_feedback: bool = true, menu_options: Dictionary = {}) -> void:
	var was_visible := visible
	_survey = survey_definition
	_answers = current_answers.duplicate(true)
	_current_section_index = current_section_index
	_current_sfx_volume = clampf(current_sfx_volume, 0.0, 1.0)
	_menu_options = menu_options.duplicate(true)
	_theme_toggle_button.set_pressed_no_signal(SurveyStyle.is_dark_mode())
	_refresh_theme_toggle_button()
	_sfx_volume_slider.set_value_no_signal(_current_sfx_volume)
	_refresh_sfx_volume_display()
	_apply_menu_option_state()
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

func _option_bool(key: String, default_value: bool) -> bool:
	if not _menu_options.has(key):
		return default_value
	return bool(_menu_options.get(key, default_value))

func _option_text(key: String, default_value: String = "") -> String:
	if not _menu_options.has(key):
		return default_value
	return str(_menu_options.get(key, default_value)).strip_edges()

func _apply_menu_option_state() -> void:
	if not is_node_ready():
		return
	var show_restart: bool = _option_bool("show_restart", true)
	var show_search: bool = _option_bool("show_search", true)
	var show_onboarding: bool = _option_bool("show_onboarding", true)
	var show_template_picker: bool = _option_bool("show_template_picker", true)
	var show_settings: bool = _option_bool("show_settings", true)
	var show_summary: bool = _option_bool("show_summary", true)
	var show_export: bool = _option_bool("show_export", true)
	var show_theme_toggle: bool = _option_bool("show_theme_toggle", true)
	var show_sfx_controls: bool = _option_bool("show_sfx_controls", true)
	var show_fill_test_answers: bool = _option_bool("show_fill_test_answers", true)
	var show_section_tools: bool = _option_bool("show_section_tools", true)
	var show_position: bool = _option_bool("show_position", true)
	var show_preview_controls: bool = _option_bool("show_preview_controls", false)
	_position_label.visible = show_position
	_restart_button.visible = show_restart
	_search_button.visible = show_search
	_onboarding_button.visible = show_onboarding
	_template_picker_button.visible = show_template_picker
	_settings_button.visible = show_settings
	_summary_button.visible = show_summary
	_export_button.visible = show_export
	_theme_toggle_button.visible = show_theme_toggle
	_sfx_heading_label.visible = show_sfx_controls
	_sfx_row.visible = show_sfx_controls
	_fill_test_answers_button.visible = show_fill_test_answers
	_section_heading.visible = show_section_tools
	_section_scroll.visible = show_section_tools
	_navigation_actions.visible = show_onboarding or show_template_picker or show_settings or show_summary or show_export
	if _preview_heading_label != null:
		_preview_heading_label.visible = show_preview_controls
	if _preview_mode_row != null:
		_preview_mode_row.visible = show_preview_controls
	if _preview_resolution_row != null:
		_preview_resolution_row.visible = show_preview_controls
	if _question_chrome_toggle_button != null:
		_question_chrome_toggle_button.visible = show_preview_controls

func _refresh_sections() -> void:
	_clear_section_list()
	if _survey == null:
		_position_label.text = _option_text("position_text", "")
		_restart_button.disabled = true
		return

	var section_count: int = _survey.sections.size()
	var answered_total: int = _total_answered_count()
	var stored_total: int = _total_stored_response_count()
	var visible_section_number: int = clampi(_current_section_index + 1, 1, max(section_count, 1))
	var custom_position_text: String = _option_text("position_text", "")
	_position_label.text = custom_position_text if not custom_position_text.is_empty() else "Currently viewing section %d of %d. %d answered so far." % [visible_section_number, section_count, answered_total]
	_restart_button.disabled = stored_total == 0
	if not _option_bool("show_section_tools", true):
		return

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
	for button in [_restart_button, _search_button, _onboarding_button, _template_picker_button, _settings_button, _summary_button, _export_button, _theme_toggle_button, _fill_test_answers_button, _question_chrome_toggle_button]:
		if button == null:
			continue
		_apply_compact_button_treatment(button)
	for picker in [_preview_mode_picker, _preview_resolution_picker]:
		if picker == null:
			continue
		picker.custom_minimum_size = Vector2(0.0, 34.0)
		picker.add_theme_font_size_override("font_size", 14)

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

func _wire_option_button_feedback(button: OptionButton) -> void:
	button.mouse_entered.connect(_on_button_hovered)

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

func _ensure_preview_controls() -> void:
	if _stack == null:
		return
	_preview_heading_label = _stack.get_node_or_null("PreviewHeadingLabel") as Label
	if _preview_heading_label == null:
		_preview_heading_label = Label.new()
		_preview_heading_label.name = "PreviewHeadingLabel"
		_stack.add_child(_preview_heading_label)
		_stack.move_child(_preview_heading_label, _preview_insert_index())

	_preview_mode_row = _stack.get_node_or_null("PreviewModeRow") as HBoxContainer
	if _preview_mode_row == null:
		_preview_mode_row = HBoxContainer.new()
		_preview_mode_row.name = "PreviewModeRow"
		_preview_mode_row.add_theme_constant_override("separation", 10)
		_stack.add_child(_preview_mode_row)
		_stack.move_child(_preview_mode_row, _preview_insert_index())
	_preview_mode_label = _preview_mode_row.get_node_or_null("PreviewModeLabel") as Label
	if _preview_mode_label == null:
		_preview_mode_label = Label.new()
		_preview_mode_label.name = "PreviewModeLabel"
		_preview_mode_row.add_child(_preview_mode_label)
	_preview_mode_picker = _preview_mode_row.get_node_or_null("PreviewModePicker") as OptionButton
	if _preview_mode_picker == null:
		_preview_mode_picker = OptionButton.new()
		_preview_mode_picker.name = "PreviewModePicker"
		_preview_mode_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preview_mode_row.add_child(_preview_mode_picker)

	_preview_resolution_row = _stack.get_node_or_null("PreviewResolutionRow") as HBoxContainer
	if _preview_resolution_row == null:
		_preview_resolution_row = HBoxContainer.new()
		_preview_resolution_row.name = "PreviewResolutionRow"
		_preview_resolution_row.add_theme_constant_override("separation", 10)
		_stack.add_child(_preview_resolution_row)
		_stack.move_child(_preview_resolution_row, _preview_insert_index())
	_preview_resolution_label = _preview_resolution_row.get_node_or_null("PreviewResolutionLabel") as Label
	if _preview_resolution_label == null:
		_preview_resolution_label = Label.new()
		_preview_resolution_label.name = "PreviewResolutionLabel"
		_preview_resolution_row.add_child(_preview_resolution_label)
	_preview_resolution_picker = _preview_resolution_row.get_node_or_null("PreviewResolutionPicker") as OptionButton
	if _preview_resolution_picker == null:
		_preview_resolution_picker = OptionButton.new()
		_preview_resolution_picker.name = "PreviewResolutionPicker"
		_preview_resolution_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preview_resolution_row.add_child(_preview_resolution_picker)

	_question_chrome_toggle_button = _stack.get_node_or_null("QuestionChromeToggleButton") as Button
	if _question_chrome_toggle_button == null:
		_question_chrome_toggle_button = Button.new()
		_question_chrome_toggle_button.name = "QuestionChromeToggleButton"
		_question_chrome_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_question_chrome_toggle_button.toggle_mode = true
		_stack.add_child(_question_chrome_toggle_button)
		_stack.move_child(_question_chrome_toggle_button, _preview_insert_index())

func _preview_insert_index() -> int:
	if _fill_test_answers_button != null:
		var fill_index := _stack.get_children().find(_fill_test_answers_button)
		if fill_index != -1:
			return fill_index
	return _stack.get_child_count()

func _refresh_preview_controls() -> void:
	if _preview_mode_picker == null or _preview_resolution_picker == null:
		return
	_syncing_preview_controls = true
	_populate_preview_picker(_preview_mode_picker, _preview_mode_options(), str(_menu_options.get("preview_mode", SURVEY_PREVIEW_CONFIG.MODE_AUTO)))
	_populate_preview_picker(_preview_resolution_picker, _preview_resolution_options(), str(_menu_options.get("preview_resolution", "")))
	_preview_resolution_picker.disabled = _preview_resolution_picker.get_item_count() == 0
	if _question_chrome_toggle_button != null:
		_question_chrome_toggle_button.set_pressed_no_signal(_option_bool("question_debug_ids", false))
		_refresh_question_chrome_toggle_button()
	_syncing_preview_controls = false

func _preview_mode_options() -> Array:
	var configured: Variant = _menu_options.get("preview_mode_options", [])
	if configured is Array and not (configured as Array).is_empty():
		return configured as Array
	return SURVEY_PREVIEW_CONFIG.preview_mode_options()

func _preview_resolution_options() -> Array:
	var configured: Variant = _menu_options.get("preview_resolution_options", [])
	if configured is Array:
		return configured as Array
	return []

func _populate_preview_picker(picker: OptionButton, options: Array, selected_value: String) -> void:
	picker.clear()
	var selected_index := -1
	for index in range(options.size()):
		var option_variant: Variant = options[index]
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		var label := str(option.get("label", option.get("value", option.get("id", "")))).strip_edges()
		var value := str(option.get("value", option.get("id", ""))).strip_edges()
		if label.is_empty():
			continue
		picker.add_item(label)
		var item_index := picker.get_item_count() - 1
		picker.set_item_metadata(item_index, value)
		if value == selected_value:
			selected_index = item_index
	if picker.get_item_count() == 0:
		return
	if selected_index == -1:
		selected_index = 0
	picker.select(selected_index)

func _refresh_question_chrome_toggle_button() -> void:
	if _question_chrome_toggle_button == null:
		return
	_question_chrome_toggle_button.text = "Question Type Labels: IDs" if _question_chrome_toggle_button.button_pressed else "Question Type Labels: Types"

func _on_preview_mode_picker_item_selected(index: int) -> void:
	if _syncing_preview_controls or _preview_mode_picker == null:
		return
	var value := str(_preview_mode_picker.get_item_metadata(index)).strip_edges()
	if value.is_empty():
		return
	preview_mode_requested.emit(value)

func _on_preview_resolution_picker_item_selected(index: int) -> void:
	if _syncing_preview_controls or _preview_resolution_picker == null:
		return
	var value := str(_preview_resolution_picker.get_item_metadata(index)).strip_edges()
	preview_resolution_requested.emit(value)

func _on_question_chrome_toggle_toggled(button_pressed: bool) -> void:
	_refresh_question_chrome_toggle_button()
	if _syncing_preview_controls:
		return
	question_debug_ids_requested.emit(button_pressed)
