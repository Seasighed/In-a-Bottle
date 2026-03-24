extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const MODE_EXPLORE := "explore"
const MODE_SEARCH := "search"
const MODE_TOPICS := "topics"
const MODE_GUIDED := "guided"
const MODE_RANDOM := "random"
const MAX_RESULTS := 12
const RANDOM_SPIN_MIN_STEPS := 5
const RANDOM_SPIN_MAX_STEPS := 18
const RANDOM_SPIN_TARGET_STEP_SECONDS := 0.07

signal continue_requested
signal search_requested
signal template_picker_requested
signal template_selected_requested(template_path: String)
signal template_folder_requested
signal navigate_requested(section_index: int, question_id: String)
signal close_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _subtitle_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SubtitleLabel
@onready var _template_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/TemplateSection/TemplateHeadingLabel
@onready var _template_current_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/TemplateSection/TemplateCurrentLabel
@onready var _import_template_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/TemplateSection/TemplateActions/ImportTemplateButton
@onready var _template_folder_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/TemplateSection/TemplateActions/OpenTemplateFolderButton
@onready var _template_grid: GridContainer = $Bounds/Center/Panel/PanelScroll/Stack/TemplateSection/TemplateGrid
@onready var _mode_buttons: GridContainer = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons
@onready var _explore_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons/ExploreButton
@onready var _search_mode_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons/SearchModeButton
@onready var _topics_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons/TopicsButton
@onready var _guided_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons/GuidedButton
@onready var _random_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ModeButtons/RandomButton
@onready var _content_panel: PanelContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel
@onready var _mode_title_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ModeTitleLabel
@onready var _mode_description_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ModeDescriptionLabel
@onready var _explore_actions: HBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ExploreActions
@onready var _continue_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ExploreActions/ContinueButton
@onready var _search_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ExploreActions/SearchButton
@onready var _topic_group: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/TopicGroup
@onready var _topic_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/TopicGroup/TopicHeadingLabel
@onready var _topic_flow: FlowContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/TopicGroup/TopicFlow
@onready var _preset_group: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/PresetGroup
@onready var _preset_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/PresetGroup/PresetHeadingLabel
@onready var _preset_flow: FlowContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/PresetGroup/PresetFlow
@onready var _audience_group: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/AudienceGroup
@onready var _audience_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/AudienceGroup/AudienceHeadingLabel
@onready var _audience_flow: FlowContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/AudienceGroup/AudienceFlow
@onready var _guided_topic_group: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/GuidedTopicGroup
@onready var _guided_topic_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/GuidedTopicGroup/GuidedTopicHeadingLabel
@onready var _guided_topic_flow: FlowContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/GuidedTopicGroup/GuidedTopicFlow
@onready var _random_group: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup
@onready var _random_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomHeadingLabel
@onready var _random_section_flow: FlowContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomSectionFlow
@onready var _random_pick_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomActions/RandomPickButton
@onready var _random_faq_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomActions/RandomFaqButton
@onready var _random_spin_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomSpinLabel
@onready var _random_faq_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/RandomGroup/RandomFaqLabel
@onready var _result_summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ResultSummaryLabel
@onready var _empty_state_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/EmptyStateLabel
@onready var _results_list: VBoxContainer = $Bounds/Center/Panel/PanelScroll/Stack/ContentPanel/ContentStack/ResultsList

var _survey: SurveyDefinition
var _topic_tags: Array[Dictionary] = []
var _audience_profiles: Array[Dictionary] = []
var _guided_presets: Array[Dictionary] = []
var _question_entries: Array[Dictionary] = []
var _available_templates: Array[Dictionary] = []
var _current_mode := MODE_EXPLORE
var _current_template_path := ""
var _selected_topic_tag := ""
var _selected_guided_topic_tags: PackedStringArray = PackedStringArray()
var _selected_audience_id := ""
var _selected_preset_id := ""
var _random_section_whitelist: Array[int] = []
var _random_spin_token := 0
var _random_is_spinning := false
var _random_faq_revealed := false
var _result_cache: Array[Dictionary] = []
@export_range(0.2, 2.0, 0.05) var random_spin_duration := 0.5

func _ready() -> void:
	layer = 58
	visible = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_import_template_button.pressed.connect(_on_import_template_pressed)
	_template_folder_button.pressed.connect(_on_template_folder_pressed)
	_explore_button.pressed.connect(_on_explore_mode_pressed)
	_search_mode_button.pressed.connect(_on_search_mode_pressed)
	_topics_button.pressed.connect(_on_topics_mode_pressed)
	_guided_button.pressed.connect(_on_guided_mode_pressed)
	_random_button.pressed.connect(_on_random_mode_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_search_button.pressed.connect(_on_search_pressed)
	_random_pick_button.pressed.connect(_on_random_pick_pressed)
	_random_faq_button.mouse_entered.connect(_on_random_faq_entered)
	_random_faq_button.mouse_exited.connect(_on_random_faq_exited)
	_random_faq_button.focus_entered.connect(_on_random_faq_entered)
	_random_faq_button.focus_exited.connect(_on_random_faq_exited)

	for button in [_close_button, _import_template_button, _template_folder_button, _explore_button, _search_mode_button, _topics_button, _guided_button, _random_button, _continue_button, _search_button, _random_pick_button, _random_faq_button]:
		_wire_feedback(button)

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.apply_panel(_content_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 22, 1)
	SurveyStyle.style_heading(_heading_label, 26)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.style_heading(_template_heading_label, 18)
	SurveyStyle.style_caption(_template_current_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.apply_secondary_button(_import_template_button)
	SurveyStyle.apply_secondary_button(_template_folder_button)
	SurveyStyle.style_heading(_mode_title_label, 22)
	SurveyStyle.style_body(_mode_description_label)
	SurveyStyle.style_heading(_topic_heading_label, 17)
	SurveyStyle.style_heading(_preset_heading_label, 17)
	SurveyStyle.style_heading(_audience_heading_label, 17)
	SurveyStyle.style_heading(_guided_topic_heading_label, 17)
	SurveyStyle.style_heading(_random_heading_label, 17)
	SurveyStyle.style_body(_random_spin_label)
	SurveyStyle.style_caption(_random_faq_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_body(_result_summary_label)
	SurveyStyle.style_body(_empty_state_label)
	SurveyStyle.apply_secondary_button(_close_button)
	SurveyStyle.apply_primary_button(_continue_button)
	SurveyStyle.apply_secondary_button(_search_button)
	SurveyStyle.apply_primary_button(_random_pick_button)
	SurveyStyle.apply_secondary_button(_random_faq_button)
	_refresh_template_panel()
	_refresh_mode_buttons()
	_refresh_dynamic_content()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.06, 20.0, 72.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.05, 16.0, 56.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))

	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 380.0, 1020.0)
	var panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 360.0, 900.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_panel_scroll.scroll_horizontal = 0
	if viewport_size.x < 820.0:
		_mode_buttons.columns = 1
		_template_grid.columns = 1
	elif viewport_size.x < 1180.0:
		_mode_buttons.columns = 2
		_template_grid.columns = 2
	else:
		_mode_buttons.columns = 3
		_template_grid.columns = 3

func open_onboarding(survey_definition: SurveyDefinition, preferred_topic_tag: String = "", preferred_audience_id: String = "", current_template_path: String = "", available_templates: Array[Dictionary] = []) -> void:
	_cancel_random_spin()
	_survey = survey_definition
	_topic_tags = []
	_audience_profiles = []
	_guided_presets = []
	_question_entries = []
	_available_templates = _sanitize_available_templates(available_templates)
	_current_template_path = current_template_path.strip_edges()
	_random_section_whitelist.clear()
	_random_faq_revealed = false
	_result_cache.clear()
	if _survey != null:
		_topic_tags = _survey.available_topic_tags()
		_audience_profiles = _survey.audience_profiles.duplicate(true)
		_guided_presets = _survey.guided_presets.duplicate(true)
		_question_entries = _build_question_entries()

	_selected_topic_tag = _resolve_topic_tag(preferred_topic_tag)
	_selected_guided_topic_tags = PackedStringArray()
	if not _selected_topic_tag.is_empty():
		_selected_guided_topic_tags.append(_selected_topic_tag)
	_selected_audience_id = _resolve_audience_id(preferred_audience_id)
	_selected_preset_id = ""
	_current_mode = _default_mode()

	_heading_label.text = "Section Crossroads"
	_subtitle_label.text = "Choose the fastest route into %s." % _search_subject()
	_refresh_template_panel()
	_refresh_mode_buttons()
	_refresh_dynamic_content()
	_panel_scroll.scroll_vertical = 0
	_panel_scroll.scroll_horizontal = 0
	show()

func close_onboarding() -> void:
	_cancel_random_spin()
	_random_faq_revealed = false
	hide()

func current_mode_name() -> String:
	return _current_mode

func current_topic_tag() -> String:
	match _current_mode:
		MODE_TOPICS:
			return _selected_topic_tag
		MODE_GUIDED:
			if not _selected_guided_topic_tags.is_empty():
				return _selected_guided_topic_tags[0]
	return ""

func current_audience_id() -> String:
	if _current_mode == MODE_GUIDED:
		return _selected_audience_id
	return ""

func _default_mode() -> String:
	if not _selected_audience_id.is_empty() or not _selected_guided_topic_tags.is_empty() or not _selected_preset_id.is_empty():
		return MODE_GUIDED
	if not _selected_topic_tag.is_empty():
		return MODE_TOPICS
	return MODE_EXPLORE

func _search_subject() -> String:
	if _survey == null:
		return "this questionnaire"
	return _survey.resolved_onboarding_subject()

func _sanitize_available_templates(templates: Array[Dictionary]) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	for template_info in templates:
		if template_info is Dictionary:
			sanitized.append((template_info as Dictionary).duplicate(true))
	return sanitized

func _refresh_template_panel() -> void:
	if not is_node_ready():
		return
	if _current_template_path.is_empty():
		_template_current_label.text = "Current template: pick from the built-in or imported survey templates below."
	else:
		_template_current_label.text = "Current template: %s" % _current_template_path.get_file()
	_rebuild_template_grid()

func _rebuild_template_grid() -> void:
	_clear_children(_template_grid)
	if _available_templates.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No valid templates were found yet. Import one or open the template folder to add more."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_caption(empty_label, SurveyStyle.TEXT_MUTED)
		_template_grid.add_child(empty_label)
		return
	for template_info in _available_templates:
		var template_path: String = str(template_info.get("path", "")).strip_edges()
		var title: String = str(template_info.get("title", template_info.get("filename", template_path.get_file()))).strip_edges()
		var source_label: String = str(template_info.get("source_label", "Template")).strip_edges()
		var filename: String = str(template_info.get("filename", template_path.get_file())).strip_edges()
		var description: String = str(template_info.get("description", "")).strip_edges()
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.text = "%s\n%s | %s" % [title, source_label, filename]
		button.tooltip_text = description if not description.is_empty() else filename
		SurveyStyle.apply_answer_button(button, template_path == _current_template_path)
		button.pressed.connect(_on_template_selected_pressed.bind(template_path))
		_wire_feedback(button)
		_template_grid.add_child(button)

func _refresh_mode_buttons() -> void:
	_explore_button.disabled = _question_entries.is_empty()
	_search_mode_button.disabled = _question_entries.is_empty()
	_topics_button.disabled = _topic_tags.is_empty()
	_guided_button.disabled = _guided_presets.is_empty() and _audience_profiles.is_empty() and _topic_tags.is_empty()
	_random_button.disabled = _question_entries.is_empty()
	_refresh_mode_button(_explore_button, _current_mode == MODE_EXPLORE, "Survey Scroll", "Open the full survey and move with the Survey Map.")
	_refresh_mode_button(_search_mode_button, _current_mode == MODE_SEARCH, "Search", "Look for matching questions by words, phrases, or topics.")
	_refresh_mode_button(_topics_button, _current_mode == MODE_TOPICS, "Browse Topics", "Pick one topic tag and jump to related questions.")
	_refresh_mode_button(_guided_button, _current_mode == MODE_GUIDED, "Guided Match", "Tailor the survey by preset, audience, and topics.")
	_refresh_mode_button(_random_button, _current_mode == MODE_RANDOM, "Gamble", "Spin for a random question from all or selected sections.")

func _refresh_mode_button(button: Button, is_selected: bool, title: String, description: String) -> void:
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0.0, 84.0)
	if is_selected:
		SurveyStyle.apply_primary_button(button)
	else:
		SurveyStyle.apply_secondary_button(button)

func _build_question_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _survey == null:
		return entries
	for section_index in range(_survey.sections.size()):
		var section: SurveySection = _survey.sections[section_index]
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var preview_text: String = question.description.strip_edges()
			if preview_text.is_empty():
				preview_text = _build_question_preview(question)
			var display_tags: PackedStringArray = question.topic_tags if not question.topic_tags.is_empty() else question.keywords
			entries.append({
				"section_index": section_index,
				"question_index": question_index,
				"question_id": question.id,
				"title": question.display_title(question_index),
				"section_label": section.display_title(section_index),
				"type_label": str(question.type).replace("_", " "),
				"preview": preview_text,
				"display_tags": display_tags,
				"normalized_prompt": _normalize_text(question.prompt),
				"normalized_haystack": _normalize_text("%s %s %s" % [section.title, section.description, question.searchable_text()]),
				"normalized_topic_tags": _normalize_identifier_array(question.topic_tags if not question.topic_tags.is_empty() else question.keywords),
				"normalized_keywords": _normalize_identifier_array(question.keywords),
				"normalized_audience_tags": _normalize_identifier_array(question.audience_tags)
			})
	return entries

func _build_question_preview(question: SurveyQuestion) -> String:
	if not question.options.is_empty():
		var preview_options: Array[String] = []
		for option_index in range(mini(question.options.size(), 3)):
			preview_options.append(question.options[option_index])
		return "Options: %s" % ", ".join(preview_options)
	if not question.rows.is_empty():
		var preview_rows: Array[String] = []
		for row_index in range(mini(question.rows.size(), 2)):
			preview_rows.append(question.rows[row_index])
		return "Rows: %s" % " | ".join(preview_rows)
	return "Question"

func _resolve_topic_tag(raw_value: String) -> String:
	var desired_id: String = _normalize_identifier(raw_value)
	if desired_id.is_empty():
		return ""
	for tag_info in _topic_tags:
		if str(tag_info.get("id", "")) == desired_id:
			return desired_id
	return ""

func _resolve_audience_id(raw_value: String) -> String:
	var desired_id: String = _normalize_identifier(raw_value)
	if desired_id.is_empty():
		return ""
	for profile in _audience_profiles:
		if str(profile.get("id", "")) == desired_id:
			return desired_id
	return ""

func _sanitize_guided_topic_tags(value: Variant) -> PackedStringArray:
	var resolved: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	if value is PackedStringArray:
		for raw_tag in value:
			var topic_id: String = _resolve_topic_tag(str(raw_tag))
			if topic_id.is_empty() or seen.has(topic_id):
				continue
			seen[topic_id] = true
			resolved.append(topic_id)
	elif value is Array:
		var raw_values: Array = value as Array
		for raw_tag in raw_values:
			var topic_id: String = _resolve_topic_tag(str(raw_tag))
			if topic_id.is_empty() or seen.has(topic_id):
				continue
			seen[topic_id] = true
			resolved.append(topic_id)
	else:
		var topic_id: String = _resolve_topic_tag(str(value))
		if not topic_id.is_empty():
			resolved.append(topic_id)
	return resolved

func _refresh_dynamic_content() -> void:
	if not is_node_ready():
		return
	if _current_mode != MODE_RANDOM:
		_cancel_random_spin()
	match _current_mode:
		MODE_EXPLORE:
			_mode_title_label.text = "Survey Scroll"
			_mode_description_label.text = "Open the full questionnaire, keep the Survey Map visible, and move at your own pace."
			_explore_actions.visible = true
			_continue_button.visible = true
			_search_button.visible = false
			_continue_button.text = "Open Survey Scroll"
			_topic_group.visible = false
			_preset_group.visible = false
			_audience_group.visible = false
			_guided_topic_group.visible = false
			_random_group.visible = false
			_show_no_results("")
		MODE_SEARCH:
			_mode_title_label.text = "Search"
			_mode_description_label.text = "Ask what is on your mind and jump straight to the questions that match the wording or topic."
			_explore_actions.visible = true
			_continue_button.visible = false
			_search_button.visible = true
			_search_button.text = "Open Search"
			_topic_group.visible = false
			_preset_group.visible = false
			_audience_group.visible = false
			_guided_topic_group.visible = false
			_random_group.visible = false
			_show_no_results("")
		MODE_TOPICS:
			_mode_title_label.text = "Browse Topics"
			_mode_description_label.text = "Pick one topic tag and jump straight to the questions that mention it or closely related wording."
			_explore_actions.visible = false
			_topic_group.visible = true
			_preset_group.visible = false
			_audience_group.visible = false
			_guided_topic_group.visible = false
			_random_group.visible = false
			_rebuild_topic_buttons(_topic_flow, true)
			_refresh_results()
		MODE_GUIDED:
			_mode_title_label.text = "Guided Match"
			_mode_description_label.text = "Start from a preset survey or tailor the questionnaire by choosing who you are and every topic that matters."
			_explore_actions.visible = false
			_topic_group.visible = false
			_preset_group.visible = not _guided_presets.is_empty()
			_audience_group.visible = not _audience_profiles.is_empty()
			_guided_topic_group.visible = not _topic_tags.is_empty()
			_random_group.visible = false
			_rebuild_preset_buttons(_preset_flow)
			_rebuild_audience_buttons(_audience_flow)
			_rebuild_guided_topic_buttons(_guided_topic_flow)
			_refresh_results()
		MODE_RANDOM:
			_mode_title_label.text = "Gamble"
			_mode_description_label.text = "Spin for a random question. Leave all sections open, or whitelist exactly where the gamble is allowed to land."
			_explore_actions.visible = false
			_topic_group.visible = false
			_preset_group.visible = false
			_audience_group.visible = false
			_guided_topic_group.visible = false
			_random_group.visible = true
			_rebuild_random_section_buttons(_random_section_flow)
			_refresh_random_mode()
	_refresh_mode_buttons()

func _rebuild_topic_buttons(flow: FlowContainer, include_any_option: bool) -> void:
	_clear_children(flow)
	if include_any_option:
		var any_button: Button = Button.new()
		any_button.text = "Any Topic"
		_refresh_toggle_button(any_button, _selected_topic_tag.is_empty())
		any_button.pressed.connect(_on_topic_selected.bind(""))
		_wire_feedback(any_button)
		flow.add_child(any_button)
	for tag_info in _topic_tags:
		var tag_id: String = str(tag_info.get("id", ""))
		var count: int = int(tag_info.get("count", 0))
		var label: String = str(tag_info.get("label", ""))
		var button: Button = Button.new()
		button.text = "%s (%d)" % [label, count]
		_refresh_toggle_button(button, tag_id == _selected_topic_tag)
		button.pressed.connect(_on_topic_selected.bind(tag_id))
		_wire_feedback(button)
		flow.add_child(button)

func _rebuild_preset_buttons(flow: FlowContainer) -> void:
	_clear_children(flow)
	var custom_button: Button = Button.new()
	custom_button.text = "Custom Tailor"
	_refresh_toggle_button(custom_button, _selected_preset_id.is_empty())
	custom_button.pressed.connect(_on_preset_selected.bind(""))
	_wire_feedback(custom_button)
	flow.add_child(custom_button)
	for preset in _guided_presets:
		var preset_id: String = str(preset.get("id", ""))
		var button: Button = Button.new()
		button.text = str(preset.get("label", _friendly_label(preset_id)))
		button.tooltip_text = str(preset.get("description", "")).strip_edges()
		_refresh_toggle_button(button, preset_id == _selected_preset_id)
		button.pressed.connect(_on_preset_selected.bind(preset_id))
		_wire_feedback(button)
		flow.add_child(button)

func _rebuild_audience_buttons(flow: FlowContainer) -> void:
	_clear_children(flow)
	var any_button: Button = Button.new()
	any_button.text = "Anyone"
	_refresh_toggle_button(any_button, _selected_audience_id.is_empty())
	any_button.pressed.connect(_on_audience_selected.bind(""))
	_wire_feedback(any_button)
	flow.add_child(any_button)
	for profile in _audience_profiles:
		var button: Button = Button.new()
		button.text = str(profile.get("label", ""))
		_refresh_toggle_button(button, str(profile.get("id", "")) == _selected_audience_id)
		button.pressed.connect(_on_audience_selected.bind(str(profile.get("id", ""))))
		_wire_feedback(button)
		flow.add_child(button)

func _rebuild_guided_topic_buttons(flow: FlowContainer) -> void:
	_clear_children(flow)
	var clear_button: Button = Button.new()
	clear_button.text = "All Topics"
	_refresh_toggle_button(clear_button, _selected_guided_topic_tags.is_empty())
	clear_button.pressed.connect(_on_guided_topics_cleared)
	_wire_feedback(clear_button)
	flow.add_child(clear_button)
	for tag_info in _topic_tags:
		var tag_id: String = str(tag_info.get("id", ""))
		var count: int = int(tag_info.get("count", 0))
		var label: String = str(tag_info.get("label", ""))
		var button: Button = Button.new()
		button.text = "%s (%d)" % [label, count]
		_refresh_toggle_button(button, _selected_guided_topic_tags.has(tag_id))
		button.pressed.connect(_on_guided_topic_toggled.bind(tag_id))
		_wire_feedback(button)
		flow.add_child(button)

func _rebuild_random_section_buttons(flow: FlowContainer) -> void:
	_clear_children(flow)
	var all_button: Button = Button.new()
	all_button.text = "All Sections"
	_refresh_toggle_button(all_button, _random_section_whitelist.is_empty())
	all_button.pressed.connect(_on_random_sections_cleared)
	_wire_feedback(all_button)
	flow.add_child(all_button)
	if _survey == null:
		return
	for section_index in range(_survey.sections.size()):
		var section: SurveySection = _survey.sections[section_index]
		var button: Button = Button.new()
		button.text = "%s (%d)" % [section.display_title(section_index), section.questions.size()]
		_refresh_toggle_button(button, _random_section_whitelist.has(section_index))
		button.pressed.connect(_on_random_section_toggled.bind(section_index))
		_wire_feedback(button)
		flow.add_child(button)

func _refresh_toggle_button(button: Button, is_selected: bool) -> void:
	SurveyStyle.apply_answer_button(button, is_selected)
	button.custom_minimum_size = Vector2(0, 42.0)

func _refresh_results() -> void:
	_clear_results()
	_result_cache.clear()
	if _current_mode == MODE_EXPLORE or _current_mode == MODE_SEARCH:
		_show_no_results("")
		return

	if _current_mode == MODE_TOPICS and _selected_topic_tag.is_empty():
		_show_no_results("Choose a topic tag to surface matching questions.")
		return

	if _current_mode == MODE_GUIDED and _guided_match_is_empty():
		_show_no_results("Choose a preset survey, pick an audience, or select the topics that matter most.")
		return

	var results: Array[Dictionary] = _build_results()
	_result_cache = results
	if _result_cache.is_empty():
		_show_no_results("No close matches yet. Try a broader preset, a different audience, or a wider topic mix.")
		return

	_result_summary_label.visible = true
	_result_summary_label.text = _result_summary_text(_result_cache.size())
	_empty_state_label.visible = false
	_results_list.visible = true
	for result in _result_cache:
		_results_list.add_child(_build_result_row(result))

func _refresh_random_mode() -> void:
	_clear_results()
	var candidates: Array[Dictionary] = _build_random_candidates()
	_refresh_random_faq(candidates)
	_random_spin_label.visible = true
	if _random_is_spinning:
		_result_summary_label.visible = false
		_results_list.visible = false
		_empty_state_label.visible = false
		return
	_random_pick_button.disabled = candidates.is_empty()
	if candidates.is_empty():
		_random_spin_label.text = "Choose at least one section with questions for the random draw."
		_show_no_results("No eligible random questions are available in the current section list.")
		return
	if _result_cache.is_empty():
		_random_spin_label.text = "Ready to gamble across %s." % _random_section_summary()
		_show_no_results("Press Spin Gamble Pick to let the survey pick one for you.")
		return
	_random_spin_label.text = "Picked from %s." % _random_section_summary()
	_result_summary_label.visible = true
	_result_summary_label.text = _random_result_summary()
	_empty_state_label.visible = false
	_results_list.visible = true
	for result in _result_cache:
		_results_list.add_child(_build_result_row(result))

func _refresh_random_faq(candidates: Array[Dictionary]) -> void:
	var faq_item: Dictionary = _resolved_random_faq_item()
	var question_text: String = str(faq_item.get("question", "How does Gamble calculate the odds?")).strip_edges()
	var answer_template: String = str(faq_item.get("answer", "")).strip_edges()
	_random_faq_button.text = "Gamble Odds FAQ"
	_random_faq_button.tooltip_text = question_text
	_random_faq_label.text = "Q: %s\nA: %s" % [question_text, _resolved_random_faq_answer(answer_template, candidates)]
	_random_faq_label.visible = _random_faq_revealed and _current_mode == MODE_RANDOM

func _resolved_random_faq_item() -> Dictionary:
	if _survey == null:
		return {}
	var faq_item: Dictionary = _survey.find_faq_item("random_mode_probability")
	if faq_item.is_empty():
		faq_item = _survey.find_faq_item("random_odds")
	return faq_item

func _resolved_random_faq_answer(answer_template: String, candidates: Array[Dictionary]) -> String:
	var template_text: String = answer_template
	if template_text.is_empty():
		template_text = "Gamble samples uniformly from the eligible question pool. There are {eligible_question_count} eligible questions across {eligible_section_count} section(s) in {whitelist_summary}, so each question currently has {per_question_fraction} = {per_question_probability} chance per spin. {section_probability_breakdown}"
	var counts_by_section: Dictionary = _random_candidate_counts_by_section(candidates)
	var eligible_question_count: int = candidates.size()
	var eligible_section_count: int = counts_by_section.size()
	var per_question_fraction: String = "0 / 0"
	var per_question_probability: String = "0.00%"
	if eligible_question_count > 0:
		per_question_fraction = "1 / %d" % eligible_question_count
		per_question_probability = _format_probability(1, eligible_question_count)
	var resolved_text: String = template_text
	resolved_text = resolved_text.replace("{eligible_question_count}", str(eligible_question_count))
	resolved_text = resolved_text.replace("{eligible_section_count}", str(eligible_section_count))
	resolved_text = resolved_text.replace("{whitelist_summary}", _random_section_summary())
	resolved_text = resolved_text.replace("{per_question_fraction}", per_question_fraction)
	resolved_text = resolved_text.replace("{per_question_probability}", per_question_probability)
	resolved_text = resolved_text.replace("{section_probability_breakdown}", _section_probability_breakdown(counts_by_section, eligible_question_count))
	return resolved_text.strip_edges()

func _random_candidate_counts_by_section(candidates: Array[Dictionary]) -> Dictionary:
	var counts_by_section: Dictionary = {}
	for candidate in candidates:
		var section_index: int = int(candidate.get("section_index", -1))
		if section_index < 0:
			continue
		counts_by_section[section_index] = int(counts_by_section.get(section_index, 0)) + 1
	return counts_by_section

func _section_probability_breakdown(counts_by_section: Dictionary, eligible_question_count: int) -> String:
	if eligible_question_count <= 0 or counts_by_section.is_empty():
		return "No questions are currently eligible."
	var section_indexes: Array = counts_by_section.keys()
	section_indexes.sort()
	if section_indexes.size() == 1:
		var section_index: int = int(section_indexes[0])
		return "Only %s is eligible, so every spin stays in that section." % _section_probability_label(section_index)
	var parts: Array[String] = []
	for section_value in section_indexes:
		var section_index: int = int(section_value)
		var section_count: int = int(counts_by_section.get(section_index, 0))
		parts.append("%s %s" % [_section_probability_label(section_index), _format_probability(section_count, eligible_question_count)])
	return "Section chances: %s." % ", ".join(parts)

func _section_probability_label(section_index: int) -> String:
	if _survey == null or section_index < 0 or section_index >= _survey.sections.size():
		return "Section %d" % [section_index + 1]
	var section: SurveySection = _survey.sections[section_index]
	return section.display_title(section_index)

func _format_probability(numerator: int, denominator: int) -> String:
	if denominator <= 0:
		return "0.00%"
	return "%.2f%%" % ((float(numerator) / float(denominator)) * 100.0)

func _build_random_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for entry in _question_entries:
		var section_index: int = int(entry.get("section_index", -1))
		if _random_section_whitelist.is_empty() or _random_section_whitelist.has(section_index):
			candidates.append(entry.duplicate(true))
	return candidates

func _random_section_summary() -> String:
	if _survey == null or _random_section_whitelist.is_empty():
		return "all sections"
	if _random_section_whitelist.size() == 1:
		var section_index: int = _random_section_whitelist[0]
		if section_index >= 0 and section_index < _survey.sections.size():
			return _survey.sections[section_index].display_title(section_index)
	return "%d sections" % _random_section_whitelist.size()

func _random_result_summary() -> String:
	if _result_cache.is_empty():
		return ""
	return "Gamble pick from %s." % _random_section_summary()

func _guided_match_is_empty() -> bool:
	return _selected_preset_id.is_empty() and _selected_audience_id.is_empty() and _selected_guided_topic_tags.is_empty()

func _build_results() -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in _question_entries:
		var score: float = 0.0
		if _current_mode == MODE_TOPICS:
			if _selected_topic_tag.is_empty():
				continue
			var topic_score: float = _score_topic_match(entry, _selected_topic_tag)
			if topic_score <= 0.0:
				continue
			score += topic_score
		elif _current_mode == MODE_GUIDED:
			if not _selected_guided_topic_tags.is_empty():
				var guided_topic_score: float = _score_multi_topic_match(entry, _selected_guided_topic_tags)
				if guided_topic_score <= 0.0:
					continue
				score += guided_topic_score
			if not _selected_audience_id.is_empty():
				var audience_score: float = _score_audience_match(entry, _selected_audience_id)
				if audience_score < 0.0:
					continue
				score += audience_score
			if not _selected_preset_id.is_empty():
				score += 10.0

		var result: Dictionary = entry.duplicate(true)
		result["score"] = score
		matches.append(result)
	matches.sort_custom(Callable(self, "_sort_results"))
	if matches.size() > MAX_RESULTS:
		matches.resize(MAX_RESULTS)
	return matches

func _score_multi_topic_match(entry: Dictionary, topic_tags: PackedStringArray) -> float:
	var score: float = 0.0
	var matched_count: int = 0
	for topic_tag in topic_tags:
		var topic_score: float = _score_topic_match(entry, topic_tag)
		if topic_score <= 0.0:
			continue
		matched_count += 1
		score += topic_score
	if matched_count == 0:
		return 0.0
	if matched_count > 1:
		score += float((matched_count - 1) * 60)
	return score

func _score_topic_match(entry: Dictionary, topic_tag: String) -> float:
	var topic_id: String = _normalize_identifier(topic_tag)
	if topic_id.is_empty():
		return 0.0
	var topic_tags: PackedStringArray = _packed_string_array_from_dict(entry, "normalized_topic_tags")
	var keywords: PackedStringArray = _packed_string_array_from_dict(entry, "normalized_keywords")
	var prompt_text: String = str(entry.get("normalized_prompt", ""))
	var haystack_text: String = str(entry.get("normalized_haystack", ""))
	var score: float = 0.0
	if topic_tags.has(topic_id):
		score += 170.0
	if keywords.has(topic_id):
		score += 110.0

	var query_text: String = _normalize_text(_friendly_label(topic_id))
	if prompt_text.contains(query_text):
		score += 100.0
	if haystack_text.contains(query_text):
		score += 72.0

	var prompt_similarity: float = prompt_text.similarity(query_text)
	if prompt_similarity >= 0.24:
		score += prompt_similarity * 80.0
	var haystack_similarity: float = haystack_text.similarity(query_text)
	if haystack_similarity >= 0.2:
		score += haystack_similarity * 52.0

	var query_tokens: PackedStringArray = _tokenize_text(query_text)
	var haystack_tokens: PackedStringArray = _tokenize_text(haystack_text)
	for token in query_tokens:
		if haystack_tokens.has(token):
			score += 24.0
			continue
		var best_similarity: float = _best_token_similarity(token, haystack_tokens)
		if best_similarity >= 0.82:
			score += best_similarity * 20.0
		elif token.length() >= 5 and best_similarity >= 0.66:
			score += best_similarity * 9.0

	return score

func _score_audience_match(entry: Dictionary, audience_id: String) -> float:
	var desired_id: String = _normalize_identifier(audience_id)
	if desired_id.is_empty():
		return 0.0
	var audience_tags: PackedStringArray = _packed_string_array_from_dict(entry, "normalized_audience_tags")
	if audience_tags.is_empty():
		return 18.0
	return 64.0 if audience_tags.has(desired_id) else -1.0

func _packed_string_array_from_dict(source: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = source.get(key, PackedStringArray())
	if value is PackedStringArray:
		return value as PackedStringArray
	if value is Array:
		var resolved: PackedStringArray = PackedStringArray()
		for item in value:
			resolved.append(str(item))
		return resolved
	return PackedStringArray()

func _result_summary_text(count: int) -> String:
	match _current_mode:
		MODE_TOPICS:
			return "%d questions match %s." % [count, _friendly_label(_selected_topic_tag)]
		MODE_GUIDED:
			if not _selected_preset_id.is_empty():
				return "%d questions match %s." % [count, _guided_preset_label(_selected_preset_id)]
			var parts: Array[String] = []
			if not _selected_audience_id.is_empty():
				parts.append(_friendly_label(_selected_audience_id))
			if not _selected_guided_topic_tags.is_empty():
				parts.append(", ".join(_friendly_labels(_selected_guided_topic_tags)))
			var summary_suffix: String = " + ".join(parts)
			if summary_suffix.is_empty():
				return "%d tailored questions ready." % count
			return "%d questions match %s." % [count, summary_suffix]
	return ""

func _guided_preset_label(preset_id: String) -> String:
	if _survey != null:
		var preset: Dictionary = _survey.find_guided_preset(preset_id)
		if not preset.is_empty():
			return str(preset.get("label", _friendly_label(preset_id)))
	return _friendly_label(preset_id)

func _friendly_labels(values: PackedStringArray) -> Array[String]:
	var labels: Array[String] = []
	for value in values:
		labels.append(_friendly_label(value))
	return labels

func _show_no_results(message: String) -> void:
	_result_summary_label.visible = false
	_results_list.visible = false
	_empty_state_label.text = message
	_empty_state_label.visible = not message.is_empty()

func _build_result_row(result: Dictionary) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	SurveyStyle.apply_panel(row, SurveyStyle.SURFACE, SurveyStyle.BORDER, 18, 1)
	row.gui_input.connect(_on_result_gui_input.bind(int(result.get("section_index", 0)), str(result.get("question_id", "")), row))
	row.mouse_entered.connect(_on_result_mouse_entered)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	row.add_child(stack)

	var title_label: Label = Label.new()
	title_label.text = str(result.get("title", ""))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_body(title_label, SurveyStyle.TEXT_PRIMARY)
	stack.add_child(title_label)

	var meta_label: Label = Label.new()
	meta_label.text = "%s - %s" % [str(result.get("section_label", "")), str(result.get("type_label", ""))]
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(meta_label, SurveyStyle.SOFT_WHITE)
	stack.add_child(meta_label)

	var preview_label: Label = Label.new()
	preview_label.text = str(result.get("preview", ""))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(preview_label, SurveyStyle.TEXT_MUTED)
	stack.add_child(preview_label)

	var display_tags: PackedStringArray = _packed_string_array_from_dict(result, "display_tags")
	if not display_tags.is_empty():
		var tag_label: Label = Label.new()
		var preview_tags: Array[String] = []
		for tag_index in range(mini(display_tags.size(), 3)):
			preview_tags.append(_friendly_label(display_tags[tag_index]))
		tag_label.text = "Topics: %s" % ", ".join(preview_tags)
		tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_caption(tag_label, SurveyStyle.TEXT_MUTED)
		stack.add_child(tag_label)

	return row

func _sort_results(left: Dictionary, right: Dictionary) -> bool:
	var left_score: float = float(left.get("score", 0.0))
	var right_score: float = float(right.get("score", 0.0))
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score
	var left_section: int = int(left.get("section_index", 0))
	var right_section: int = int(right.get("section_index", 0))
	if left_section != right_section:
		return left_section < right_section
	return int(left.get("question_index", 0)) < int(right.get("question_index", 0))

func _best_token_similarity(query_token: String, haystack_tokens: PackedStringArray) -> float:
	var best_similarity: float = 0.0
	for candidate in haystack_tokens:
		if abs(candidate.length() - query_token.length()) > 4:
			continue
		var similarity: float = query_token.similarity(candidate)
		if similarity > best_similarity:
			best_similarity = similarity
	return best_similarity

func _normalize_identifier_array(values: PackedStringArray) -> PackedStringArray:
	var normalized: PackedStringArray = PackedStringArray()
	for value in values:
		var normalized_value: String = _normalize_identifier(value)
		if not normalized_value.is_empty():
			normalized.append(normalized_value)
	return normalized

func _normalize_identifier(raw_value: String) -> String:
	return raw_value.to_lower().strip_edges().replace("-", "_").replace(" ", "_")

func _normalize_text(raw_text: String) -> String:
	var normalized: String = raw_text.to_lower().strip_edges()
	for token in ["\n", "\t", ".", ",", ":", ";", "!", "?", "(", ")", "[", "]", "{", "}", "/", "\\", "-", "_", '"', "'", "|"]:
		normalized = normalized.replace(token, " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()

func _tokenize_text(raw_text: String) -> PackedStringArray:
	var normalized: String = _normalize_text(raw_text)
	if normalized.is_empty():
		return PackedStringArray()
	return PackedStringArray(normalized.split(" ", false))

func _friendly_label(raw_value: String) -> String:
	var text: String = raw_value.strip_edges().replace("_", " ").replace("-", " ")
	while text.contains("  "):
		text = text.replace("  ", " ")
	var parts: PackedStringArray = text.split(" ", false)
	for index in range(parts.size()):
		parts[index] = parts[index].capitalize()
	return " ".join(parts).strip_edges()

func _clear_results() -> void:
	for child in _results_list.get_children():
		child.queue_free()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _wire_feedback(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_button_hovered)
	button.pressed.connect(_on_button_pressed_feedback)

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _cancel_random_spin() -> void:
	_random_spin_token += 1
	_random_is_spinning = false
	if is_node_ready():
		_random_pick_button.disabled = false
		_random_faq_label.visible = _random_faq_revealed and _current_mode == MODE_RANDOM

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _on_explore_mode_pressed() -> void:
	_cancel_random_spin()
	_current_mode = MODE_EXPLORE
	call_deferred("_refresh_dynamic_content")

func _on_search_mode_pressed() -> void:
	if _question_entries.is_empty():
		return
	_cancel_random_spin()
	_current_mode = MODE_SEARCH
	call_deferred("_refresh_dynamic_content")

func _on_topics_mode_pressed() -> void:
	if _topic_tags.is_empty():
		return
	_cancel_random_spin()
	_current_mode = MODE_TOPICS
	if _selected_topic_tag.is_empty() and not _selected_guided_topic_tags.is_empty():
		_selected_topic_tag = _selected_guided_topic_tags[0]
	call_deferred("_refresh_dynamic_content")

func _on_guided_mode_pressed() -> void:
	if _guided_presets.is_empty() and _audience_profiles.is_empty() and _topic_tags.is_empty():
		return
	_cancel_random_spin()
	_current_mode = MODE_GUIDED
	if _selected_guided_topic_tags.is_empty() and not _selected_topic_tag.is_empty():
		_selected_guided_topic_tags.append(_selected_topic_tag)
	call_deferred("_refresh_dynamic_content")

func _on_random_mode_pressed() -> void:
	if _question_entries.is_empty():
		return
	_cancel_random_spin()
	_current_mode = MODE_RANDOM
	call_deferred("_refresh_dynamic_content")

func _on_continue_pressed() -> void:
	continue_requested.emit()

func _on_search_pressed() -> void:
	search_requested.emit()

func _on_import_template_pressed() -> void:
	template_picker_requested.emit()

func _on_template_folder_pressed() -> void:
	template_folder_requested.emit()

func _on_template_selected_pressed(template_path: String) -> void:
	if template_path.is_empty():
		return
	template_selected_requested.emit(template_path)

func _on_topic_selected(topic_tag: String) -> void:
	_selected_topic_tag = _resolve_topic_tag(topic_tag)
	call_deferred("_refresh_dynamic_content")

func _on_preset_selected(preset_id: String) -> void:
	_selected_preset_id = _normalize_identifier(preset_id)
	if _selected_preset_id.is_empty():
		call_deferred("_refresh_dynamic_content")
		return
	var preset: Dictionary = {}
	if _survey != null:
		preset = _survey.find_guided_preset(_selected_preset_id)
	if preset.is_empty():
		_selected_preset_id = ""
		call_deferred("_refresh_dynamic_content")
		return
	_selected_audience_id = _resolve_audience_id(str(preset.get("audience_id", "")))
	_selected_guided_topic_tags = _sanitize_guided_topic_tags(preset.get("topic_tags", PackedStringArray()))
	call_deferred("_refresh_dynamic_content")

func _on_guided_topic_toggled(topic_tag: String) -> void:
	var resolved_topic_tag: String = _resolve_topic_tag(topic_tag)
	if resolved_topic_tag.is_empty():
		return
	var selected_tags: PackedStringArray = _selected_guided_topic_tags
	var topic_index: int = selected_tags.find(resolved_topic_tag)
	if topic_index >= 0:
		selected_tags.remove_at(topic_index)
	else:
		selected_tags.append(resolved_topic_tag)
	_selected_guided_topic_tags = selected_tags
	_selected_preset_id = ""
	call_deferred("_refresh_dynamic_content")

func _on_guided_topics_cleared() -> void:
	_selected_guided_topic_tags = PackedStringArray()
	_selected_preset_id = ""
	call_deferred("_refresh_dynamic_content")

func _on_audience_selected(audience_id: String) -> void:
	_selected_audience_id = _resolve_audience_id(audience_id)
	_selected_preset_id = ""
	call_deferred("_refresh_dynamic_content")

func _on_random_section_toggled(section_index: int) -> void:
	var existing_index: int = _random_section_whitelist.find(section_index)
	if existing_index >= 0:
		_random_section_whitelist.remove_at(existing_index)
	else:
		_random_section_whitelist.append(section_index)
		_random_section_whitelist.sort()
	_result_cache.clear()
	_cancel_random_spin()
	call_deferred("_refresh_dynamic_content")

func _on_random_sections_cleared() -> void:
	_random_section_whitelist.clear()
	_result_cache.clear()
	_cancel_random_spin()
	call_deferred("_refresh_dynamic_content")

func _on_random_pick_pressed() -> void:
	if _random_is_spinning:
		return
	_random_faq_revealed = false
	var candidates: Array[Dictionary] = _build_random_candidates()
	if candidates.is_empty():
		_result_cache.clear()
		_refresh_random_mode()
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_random_is_spinning = true
	_random_spin_token += 1
	var spin_token: int = _random_spin_token
	_random_pick_button.disabled = true
	_result_cache.clear()
	_clear_results()
	_result_summary_label.visible = false
	_results_list.visible = false
	_empty_state_label.visible = false
	var step_count: int = _resolved_random_spin_step_count()
	var step_delays: Array[float] = _random_spin_step_delays(step_count)
	for step in range(step_count):
		var preview: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var spin_progress: float = float(step) / float(max(step_count - 1, 1))
		_random_spin_label.text = _random_spin_label_text(preview, step)
		SURVEY_UI_FEEDBACK.play_gamble_spin_tick(spin_progress)
		await get_tree().create_timer(step_delays[step]).timeout
		if spin_token != _random_spin_token or not visible or _current_mode != MODE_RANDOM:
			return
	var picked_result: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	_random_is_spinning = false
	_random_pick_button.disabled = false
	_result_cache.clear()
	_result_cache.append(picked_result)
	_random_spin_label.text = "Gamble pick: %s" % str(picked_result.get("title", "Question"))
	_refresh_random_mode()
	SURVEY_UI_FEEDBACK.play_select()
	SURVEY_UI_FEEDBACK.pulse(_random_spin_label, 0.05, 0.18)

func _resolved_random_spin_step_count() -> int:
	var duration: float = maxf(random_spin_duration, 0.2)
	return clampi(int(round(duration / RANDOM_SPIN_TARGET_STEP_SECONDS)), RANDOM_SPIN_MIN_STEPS, RANDOM_SPIN_MAX_STEPS)

func _random_spin_step_delays(step_count: int) -> Array[float]:
	var resolved_step_count: int = max(step_count, 1)
	var total_duration: float = maxf(random_spin_duration, 0.2)
	var weights: Array[float] = []
	var weight_total := 0.0
	for step in range(resolved_step_count):
		var progress: float = float(step) / float(max(resolved_step_count - 1, 1))
		var weight: float = lerpf(0.45, 1.85, progress * progress)
		weights.append(weight)
		weight_total += weight
	var delays: Array[float] = []
	if weight_total <= 0.0:
		for _step in range(resolved_step_count):
			delays.append(total_duration / float(resolved_step_count))
		return delays
	for weight in weights:
		delays.append((weight / weight_total) * total_duration)
	return delays

func _random_spin_label_text(preview: Dictionary, step: int) -> String:
	var suffix: String = "."
	match step % 3:
		1:
			suffix = ".."
		2:
			suffix = "..."
	return "Rolling%s %s" % [suffix, str(preview.get("title", "Question"))]

func _on_random_faq_entered() -> void:
	_random_faq_revealed = true
	if _current_mode == MODE_RANDOM:
		_random_faq_label.visible = true

func _on_random_faq_exited() -> void:
	_random_faq_revealed = false
	_random_faq_label.visible = false

func _on_result_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_result_gui_input(event: InputEvent, section_index: int, question_id: String, row: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_result_selected(section_index, question_id, row)

func _on_result_selected(section_index: int, question_id: String, row: Control) -> void:
	if question_id.is_empty():
		return
	SURVEY_UI_FEEDBACK.play_select()
	if row != null:
		SURVEY_UI_FEEDBACK.pulse(row, 0.04, 0.18)
	navigate_requested.emit(section_index, question_id)


