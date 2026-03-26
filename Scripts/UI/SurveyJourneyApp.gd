class_name SurveyJourneyApp
extends Control

const SAMPLE_SURVEY = preload("res://Scripts/Survey/SampleSurvey.gd")
const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_EXPORTER = preload("res://Scripts/Survey/SurveyExporter.gd")
const SURVEY_SAVE_BUNDLE = preload("res://Scripts/Survey/SurveySaveBundle.gd")
const SURVEY_PREFERENCES_STORE = preload("res://Scripts/Survey/SurveyPreferencesStore.gd")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const SURVEY_ICON_LIBRARY = preload("res://Scripts/UI/SurveyIconLibrary.gd")
const OVERLAY_MENU_SCENE: PackedScene = preload("res://Scenes/UI/OverlayMenu.tscn")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")
const COMPLETE_STATUS_COLOR := Color("3cab68")
const PARTIAL_STATUS_COLOR := Color("d0a441")
const TEMPLATE_SELECTION_STORE_PATH := "user://selected_survey_template.json"
const EXPORT_FORMAT_JSON := "json"
const EXPORT_FORMAT_CSV := "csv"
const TRACE_LOG_PATH := "user://survey_journey_trace.log"
const VIEW_LANDING := &"landing"
const VIEW_SURVEY_SELECTION := &"survey_selection"
const VIEW_LORE := &"lore"
const VIEW_SECTION_SELECTION := &"section_selection"
const VIEW_FOCUS := &"focus"
const VIEW_THANKS := &"thanks"
const VIEW_EXPORT := &"export"
const PURPOSE_SURVEY := &"survey"
const PURPOSE_LORE := &"lore"

@export_file("*.json") var survey_template_path := "res://Dev/SurveyTemplates/studio_feedback.json"
@export var dark_palette: Resource = DEFAULT_DARK_PALETTE
@export var light_palette: Resource = DEFAULT_LIGHT_PALETTE
@export var use_dark_mode := true
@export_range(0.0, 1.0, 0.01) var sfx_volume := 0.35
@export var persist_selected_template := true

var survey: SurveyDefinition
var answers: Dictionary = {}
var _available_templates: Array[Dictionary] = []
var _selection_purpose: StringName = PURPOSE_SURVEY
var _current_view: StringName = VIEW_LANDING
var _current_template_path := ""
var _selected_template_path := ""
var _selected_section_index := -1
var _question_order: Array[String] = []
var _playable_question_ids: Array[String] = []
var _focus_index := 0
var _focus_start_section_index := 0
var _focus_navigation_pending := false
var _feedback_hub
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _pending_save_text := ""
var _pending_save_extension := ""
var _pending_save_label := ""
var _web_progress_picker_active := false
var _web_progress_picker_success_callback = null
var _web_progress_picker_error_callback = null

@onready var _background: ColorRect = $Background
@onready var _margin: MarginContainer = $Margin
@onready var _main_panel: PanelContainer = $Margin/MainPanel
@onready var _stack: VBoxContainer = $Margin/MainPanel/Stack
@onready var _status_label: Label = $Margin/MainPanel/Stack/StatusLabel
@onready var _landing_view: VBoxContainer = $Margin/MainPanel/Stack/LandingView
@onready var _landing_heading_label: Label = $Margin/MainPanel/Stack/LandingView/LandingHeadingLabel
@onready var _landing_subtitle_label: Label = $Margin/MainPanel/Stack/LandingView/LandingSubtitleLabel
@onready var _landing_actions: HBoxContainer = $Margin/MainPanel/Stack/LandingView/LandingActions
@onready var _take_survey_button: Button = $Margin/MainPanel/Stack/LandingView/LandingActions/TakeSurveyButton
@onready var _get_lore_button: Button = $Margin/MainPanel/Stack/LandingView/LandingActions/GetLoreButton
@onready var _survey_selection_view: VBoxContainer = $Margin/MainPanel/Stack/SurveySelectionView
@onready var _survey_selection_back_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionTopRow/SurveySelectionBackButton
@onready var _survey_selection_heading_label: Label = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionHeadingLabel
@onready var _survey_selection_subtitle_label: Label = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionSubtitleLabel
@onready var _survey_selection_grid: GridContainer = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionScroll/SurveySelectionGrid
@onready var _survey_selection_action_spacer: Control = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionActionRow/SurveySelectionActionSpacer
@onready var _survey_selection_next_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionActionRow/SurveySelectionNextButton
@onready var _lore_view: VBoxContainer = $Margin/MainPanel/Stack/LoreView
@onready var _lore_back_button: Button = $Margin/MainPanel/Stack/LoreView/LoreTopRow/LoreBackButton
@onready var _lore_heading_label: Label = $Margin/MainPanel/Stack/LoreView/LoreHeadingLabel
@onready var _lore_subtitle_label: Label = $Margin/MainPanel/Stack/LoreView/LoreSubtitleLabel
@onready var _lore_survey_label: Label = $Margin/MainPanel/Stack/LoreView/LoreSurveyLabel
@onready var _lore_list: VBoxContainer = $Margin/MainPanel/Stack/LoreView/LoreScroll/LoreList
@onready var _lore_take_survey_button: Button = $Margin/MainPanel/Stack/LoreView/LoreTakeSurveyButton
@onready var _section_selection_view: VBoxContainer = $Margin/MainPanel/Stack/SectionSelectionView
@onready var _section_selection_back_button: Button = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionTopRow/SectionSelectionBackButton
@onready var _section_selection_heading_label: Label = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionHeadingLabel
@onready var _section_selection_subtitle_label: Label = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionSubtitleLabel
@onready var _section_selection_survey_label: Label = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionSurveyLabel
@onready var _section_selection_grid: GridContainer = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionScroll/SectionSelectionGrid
@onready var _section_selection_action_spacer: Control = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionActionRow/SectionSelectionActionSpacer
@onready var _section_selection_next_button: Button = $Margin/MainPanel/Stack/SectionSelectionView/SectionSelectionActionRow/SectionSelectionNextButton
@onready var _focus_view: VBoxContainer = $Margin/MainPanel/Stack/FocusView
@onready var _focus_back_button: Button = $Margin/MainPanel/Stack/FocusView/FocusTopRow/FocusBackButton
@onready var _focus_section_label: Label = $Margin/MainPanel/Stack/FocusView/FocusSectionLabel
@onready var _focus_progress_label: Label = $Margin/MainPanel/Stack/FocusView/FocusProgressLabel
@onready var _focus_segment_row: HBoxContainer = $Margin/MainPanel/Stack/FocusView/FocusSegmentRow
@onready var _focus_question_scroll: ScrollContainer = $Margin/MainPanel/Stack/FocusView/FocusQuestionScroll
@onready var _focus_question_stage = $Margin/MainPanel/Stack/FocusView/FocusQuestionScroll/FocusQuestionStage
@onready var _focus_bottom_spacer: Control = $Margin/MainPanel/Stack/FocusView/FocusBottomSpacer
@onready var _focus_previous_button: Button = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusPreviousButton
@onready var _focus_nav_spacer: Control = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer
@onready var _focus_next_button: Button = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNextButton
@onready var _thanks_view: VBoxContainer = $Margin/MainPanel/Stack/ThanksView
@onready var _thanks_heading_label: Label = $Margin/MainPanel/Stack/ThanksView/ThanksHeadingLabel
@onready var _thanks_body_label: Label = $Margin/MainPanel/Stack/ThanksView/ThanksBodyLabel
@onready var _thanks_review_button: Button = $Margin/MainPanel/Stack/ThanksView/ThanksActions/ThanksReviewButton
@onready var _thanks_export_button: Button = $Margin/MainPanel/Stack/ThanksView/ThanksActions/ThanksExportButton
@onready var _export_view: VBoxContainer = $Margin/MainPanel/Stack/ExportView
@onready var _export_back_button: Button = $Margin/MainPanel/Stack/ExportView/ExportTopRow/ExportBackButton
@onready var _export_heading_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportHeadingLabel
@onready var _export_subtitle_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportSubtitleLabel
@onready var _export_body_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportBodyLabel
@onready var _export_action_grid: GridContainer = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid
@onready var _export_save_progress_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportSaveProgressButton
@onready var _export_load_progress_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportLoadProgressButton
@onready var _export_copy_json_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportCopyJsonButton
@onready var _export_save_json_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportSaveJsonButton
@onready var _export_copy_csv_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportCopyCsvButton
@onready var _export_save_csv_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportSaveCsvButton
@onready var _overlay_menu: OverlayMenu = get_node_or_null("OverlayMenu") as OverlayMenu
@onready var _menu_access_layer: CanvasLayer = get_node_or_null("MenuAccessLayer") as CanvasLayer
@onready var _menu_access_button: Button = get_node_or_null("MenuAccessLayer/MenuAccessButton") as Button

func _ready() -> void:
	_start_trace_session()
	_prime_preferences_from_store()
	dark_palette = _resolved_palette_resource(dark_palette, DEFAULT_DARK_PALETTE)
	light_palette = _resolved_palette_resource(light_palette, DEFAULT_LIGHT_PALETTE)
	SurveyStyle.configure_palettes(dark_palette, light_palette, use_dark_mode)
	_configure_feedback_hub()
	_configure_file_dialogs()
	_ensure_optional_ui_nodes()
	_connect_actions()
	_load_available_templates()
	_load_initial_survey()
	_refresh_theme()
	_show_view(VIEW_LANDING)
	_refresh_menu_access_button()
	set_process_unhandled_input(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_responsive_layout()
		_refresh_focus_stage_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	if _overlay_menu != null and _overlay_menu.visible:
		_close_overlay_menu()
		return
	match _current_view:
		VIEW_SURVEY_SELECTION, VIEW_LORE, VIEW_SECTION_SELECTION:
			_show_view(VIEW_LANDING)
		VIEW_FOCUS:
			_show_view(VIEW_SECTION_SELECTION)
		VIEW_THANKS:
			_show_view(VIEW_LANDING)
		VIEW_EXPORT:
			_show_view(VIEW_THANKS)

func _resolved_palette_resource(candidate: Resource, fallback: Resource) -> Resource:
	return candidate if candidate != null else fallback

func _configure_feedback_hub() -> void:
	if _feedback_hub == null:
		_feedback_hub = SURVEY_UI_FEEDBACK.new()
		add_child(_feedback_hub)
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)

func _prime_preferences_from_store() -> void:
	var preferences: Dictionary = SURVEY_PREFERENCES_STORE.load_preferences()
	if preferences.has("use_dark_mode"):
		use_dark_mode = bool(preferences.get("use_dark_mode", use_dark_mode))
	if preferences.has("sfx_volume"):
		sfx_volume = clampf(float(preferences.get("sfx_volume", sfx_volume)), 0.0, 1.0)

func _persist_preferences() -> void:
	SURVEY_PREFERENCES_STORE.save_preferences(_current_preferences())

func _ensure_optional_ui_nodes() -> void:
	if _overlay_menu == null and OVERLAY_MENU_SCENE != null:
		var overlay_instance := OVERLAY_MENU_SCENE.instantiate() as OverlayMenu
		if overlay_instance != null:
			overlay_instance.name = "OverlayMenu"
			add_child(overlay_instance)
			_overlay_menu = overlay_instance
	if _menu_access_layer == null:
		var access_layer := CanvasLayer.new()
		access_layer.name = "MenuAccessLayer"
		access_layer.layer = 61
		add_child(access_layer)
		_menu_access_layer = access_layer
	if _menu_access_button == null and _menu_access_layer != null:
		var access_button := Button.new()
		access_button.name = "MenuAccessButton"
		access_button.text = "Menu"
		access_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		access_button.anchor_left = 1.0
		access_button.anchor_right = 1.0
		access_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		access_button.grow_vertical = Control.GROW_DIRECTION_BOTH
		_menu_access_layer.add_child(access_button)
		_menu_access_button = access_button

func _configure_file_dialogs() -> void:
	if _is_web_platform():
		return
	_save_dialog = FileDialog.new()
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.title = "Save Survey File"
	_save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	_save_dialog.canceled.connect(_on_save_dialog_canceled)
	add_child(_save_dialog)

	_load_dialog = FileDialog.new()
	_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.title = "Load Survey Progress"
	_load_dialog.file_selected.connect(_on_load_dialog_file_selected)
	_load_dialog.canceled.connect(_on_load_dialog_canceled)
	add_child(_load_dialog)

func _connect_actions() -> void:
	for button in [_take_survey_button, _get_lore_button, _survey_selection_back_button, _survey_selection_next_button, _lore_back_button, _lore_take_survey_button, _section_selection_back_button, _section_selection_next_button, _focus_back_button, _thanks_review_button, _thanks_export_button, _export_back_button, _export_save_progress_button, _export_load_progress_button, _export_copy_json_button, _export_save_json_button, _export_copy_csv_button, _export_save_csv_button]:
		_wire_button_feedback(button)
	for button in [_focus_previous_button, _focus_next_button]:
		_wire_button_hover_feedback(button)
	if _menu_access_button != null:
		_wire_button_feedback(_menu_access_button)
	_take_survey_button.pressed.connect(_on_take_survey_pressed)
	_get_lore_button.pressed.connect(_on_get_lore_pressed)
	_survey_selection_back_button.pressed.connect(_show_view.bind(VIEW_LANDING))
	_survey_selection_next_button.pressed.connect(_advance_from_survey_selection)
	_lore_back_button.pressed.connect(_show_view.bind(VIEW_SURVEY_SELECTION))
	_lore_take_survey_button.pressed.connect(_on_lore_take_survey_pressed)
	_section_selection_back_button.pressed.connect(_show_view.bind(VIEW_SURVEY_SELECTION))
	_section_selection_next_button.pressed.connect(_advance_from_section_selection)
	_focus_back_button.pressed.connect(_show_view.bind(VIEW_SECTION_SELECTION))
	_focus_previous_button.pressed.connect(_on_focus_previous_button_feedback)
	_focus_next_button.pressed.connect(_on_focus_next_button_feedback)
	_focus_previous_button.pressed.connect(_on_focus_previous_pressed)
	_focus_next_button.pressed.connect(_on_focus_next_pressed)
	_focus_question_stage.answer_changed.connect(_on_focus_answer_changed)
	_focus_question_stage.question_selected.connect(_on_focus_question_selected)
	_focus_question_stage.layout_stabilized.connect(_on_focus_stage_layout_stabilized)
	_thanks_review_button.pressed.connect(_on_thanks_review_pressed)
	_thanks_export_button.pressed.connect(_open_export_overlay)
	_export_back_button.pressed.connect(_close_export_overlay)
	_export_save_progress_button.pressed.connect(_save_progress_json)
	_export_load_progress_button.pressed.connect(_load_progress_json)
	_export_copy_json_button.pressed.connect(_copy_json)
	_export_save_json_button.pressed.connect(_save_json)
	_export_copy_csv_button.pressed.connect(_copy_csv)
	_export_save_csv_button.pressed.connect(_save_csv)
	if _menu_access_button != null:
		_menu_access_button.pressed.connect(_open_overlay_menu)
	if _overlay_menu != null:
		_overlay_menu.resume_requested.connect(_close_overlay_menu)
		_overlay_menu.restart_requested.connect(_on_menu_restart_requested)
		_overlay_menu.clear_section_requested.connect(_on_menu_clear_section_requested)
		_overlay_menu.jump_to_section_requested.connect(_on_menu_jump_to_section_requested)
		_overlay_menu.export_requested.connect(_on_menu_export_requested)
		_overlay_menu.theme_mode_requested.connect(_on_menu_theme_mode_requested)
		_overlay_menu.sfx_volume_requested.connect(_on_menu_sfx_volume_requested)

func _wire_button_feedback(button: BaseButton) -> void:
	if button == null:
		return
	_wire_button_hover_feedback(button)
	button.pressed.connect(_on_button_pressed_feedback)

func _wire_button_hover_feedback(button: BaseButton) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_on_button_hovered)
	button.focus_entered.connect(_on_button_hovered)

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _on_focus_previous_button_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_navigation_previous()

func _on_focus_next_button_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_navigation_next()

func _load_available_templates() -> void:
	_available_templates = SURVEY_TEMPLATE_LOADER.list_available_templates()

func _load_initial_survey() -> void:
	var initial_path := _resolve_startup_template_path()
	if initial_path.is_empty() and not _available_templates.is_empty():
		initial_path = str(_available_templates[0].get("path", "")).strip_edges()
	if initial_path.is_empty():
		survey = SAMPLE_SURVEY.build()
		_current_template_path = ""
		_selected_template_path = ""
		_selected_section_index = 0 if not survey.sections.is_empty() else -1
		survey_template_path = ""
		answers.clear()
		_rebuild_question_order()
		return
	_load_survey_from_path(initial_path, false)

func _resolve_startup_template_path() -> String:
	var root := get_tree().root
	if root != null and root.has_meta("survey_journey_template_path"):
		var handed_off_path := str(root.get_meta("survey_journey_template_path", "")).strip_edges()
		root.remove_meta("survey_journey_template_path")
		if not handed_off_path.is_empty():
			return handed_off_path
	if persist_selected_template:
		var persisted_path := _load_persisted_template_path()
		if not persisted_path.is_empty() and FileAccess.file_exists(persisted_path):
			return persisted_path
	return survey_template_path

func _load_persisted_template_path() -> String:
	if not FileAccess.file_exists(TEMPLATE_SELECTION_STORE_PATH):
		return ""
	var file := FileAccess.open(TEMPLATE_SELECTION_STORE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return ""
	return str((parsed as Dictionary).get("survey_template_path", "")).strip_edges()

func _persist_selected_template_path() -> void:
	if not persist_selected_template or _current_template_path.is_empty():
		return
	var file := FileAccess.open(TEMPLATE_SELECTION_STORE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"survey_template_path": _current_template_path}, "\t"))
	file.close()

func _load_survey_from_path(raw_path: String, reset_answers: bool = true) -> bool:
	var requested_path := _normalize_template_path_input(raw_path)
	if requested_path.is_empty():
		_show_status_message("No survey template was selected.", true)
		return false
	var summary: Dictionary = SURVEY_TEMPLATE_LOADER.describe_template_file(requested_path)
	if not bool(summary.get("ok", false)):
		var errors := _messages_from_variant(summary.get("errors", PackedStringArray()))
		_show_status_message(errors[0] if not errors.is_empty() else "Failed to load %s." % requested_path.get_file(), true)
		return false
	var loaded_survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(requested_path)
	if loaded_survey == null:
		_show_status_message("Failed to build the survey from %s." % requested_path.get_file(), true)
		return false
	survey = loaded_survey
	_trace("Loaded survey template: %s" % requested_path)
	survey_template_path = requested_path
	_current_template_path = requested_path
	_selected_template_path = requested_path
	if reset_answers:
		answers.clear()
	_focus_start_section_index = 0
	_selected_section_index = 0 if not survey.sections.is_empty() else -1
	_focus_index = 0
	_playable_question_ids.clear()
	_focus_navigation_pending = false
	if is_node_ready():
		_focus_question_stage.reset()
	_rebuild_question_order()
	_refresh_all_views()
	_persist_selected_template_path()
	return true

func _rebuild_question_order() -> void:
	_question_order.clear()
	if survey == null:
		return
	for section in survey.sections:
		for question in section.questions:
			_question_order.append(question.id)

func _refresh_theme() -> void:
	_background.color = SurveyStyle.BACKGROUND
	SurveyStyle.apply_primary_button(_take_survey_button)
	SurveyStyle.apply_secondary_button(_get_lore_button)
	SurveyStyle.apply_secondary_button(_survey_selection_back_button)
	SurveyStyle.apply_primary_button(_survey_selection_next_button)
	SurveyStyle.apply_secondary_button(_lore_back_button)
	SurveyStyle.apply_primary_button(_lore_take_survey_button)
	SurveyStyle.apply_secondary_button(_section_selection_back_button)
	SurveyStyle.apply_primary_button(_section_selection_next_button)
	SurveyStyle.apply_secondary_button(_focus_back_button)
	SurveyStyle.apply_secondary_button(_focus_previous_button)
	SurveyStyle.apply_primary_button(_focus_next_button)
	SurveyStyle.apply_secondary_button(_thanks_review_button)
	SurveyStyle.apply_primary_button(_thanks_export_button)
	SurveyStyle.apply_secondary_button(_export_back_button)
	for button in [_export_save_progress_button, _export_load_progress_button, _export_copy_json_button, _export_save_json_button, _export_copy_csv_button, _export_save_csv_button]:
		SurveyStyle.apply_secondary_button(button)
	if _menu_access_button != null:
		SurveyStyle.apply_secondary_button(_menu_access_button)
	if not _playable_question_ids.is_empty():
		_rebuild_focus_question_stage()
	_refresh_all_views()
	_update_responsive_layout()
	if _overlay_menu != null:
		_overlay_menu.refresh_theme()

func _update_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var compact_layout := viewport_size.x <= 640.0
	var shortest_side := minf(viewport_size.x, viewport_size.y)
	var panel_margin := 10 if phone_layout else int(clampf(minf(viewport_size.x, viewport_size.y) * 0.02, 12.0, 32.0))
	_margin.add_theme_constant_override("margin_left", panel_margin)
	_margin.add_theme_constant_override("margin_right", panel_margin)
	_margin.add_theme_constant_override("margin_top", panel_margin)
	_margin.add_theme_constant_override("margin_bottom", panel_margin)
	_stack.add_theme_constant_override("separation", 14 if phone_layout else 18)
	_landing_view.add_theme_constant_override("separation", 14 if phone_layout else 18)
	_survey_selection_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_lore_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_section_selection_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_focus_view.add_theme_constant_override("separation", 8 if phone_layout else 10)
	_thanks_view.add_theme_constant_override("separation", 14 if phone_layout else 18)
	_export_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_landing_actions.add_theme_constant_override("separation", 10 if phone_layout else 14)
	_main_panel.add_theme_stylebox_override("panel", _panel_style(SurveyStyle.SURFACE, SurveyStyle.BORDER, 20 if phone_layout else 30, 1, 16.0 if phone_layout else 24.0))
	SurveyStyle.style_caption(_status_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_heading(_landing_heading_label, 30 if phone_layout else 40)
	SurveyStyle.style_body(_landing_subtitle_label)
	_landing_subtitle_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	SurveyStyle.style_heading(_survey_selection_heading_label, 24 if phone_layout else 28)
	SurveyStyle.style_body(_survey_selection_subtitle_label)
	_survey_selection_subtitle_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	SurveyStyle.style_heading(_lore_heading_label, 24 if phone_layout else 28)
	SurveyStyle.style_body(_lore_subtitle_label)
	_lore_subtitle_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	SurveyStyle.style_caption(_lore_survey_label, SurveyStyle.TEXT_PRIMARY)
	_lore_survey_label.add_theme_font_size_override("font_size", 13 if phone_layout else 15)
	SurveyStyle.style_heading(_section_selection_heading_label, 24 if phone_layout else 28)
	SurveyStyle.style_body(_section_selection_subtitle_label)
	_section_selection_subtitle_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	SurveyStyle.style_caption(_section_selection_survey_label, SurveyStyle.TEXT_PRIMARY)
	_section_selection_survey_label.add_theme_font_size_override("font_size", 13 if phone_layout else 15)
	SurveyStyle.style_heading(_focus_section_label, 24 if phone_layout else 28)
	SurveyStyle.style_caption(_focus_progress_label, SurveyStyle.TEXT_PRIMARY)
	_focus_progress_label.add_theme_font_size_override("font_size", 12 if phone_layout else 13)
	SurveyStyle.style_heading(_thanks_heading_label, 30 if phone_layout else 38)
	SurveyStyle.style_body(_thanks_body_label)
	_thanks_body_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	SurveyStyle.style_heading(_export_heading_label, 26 if phone_layout else 32)
	SurveyStyle.style_body(_export_subtitle_label)
	SurveyStyle.style_body(_export_body_label)
	_export_subtitle_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	_export_body_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	_survey_selection_grid.columns = 1 if viewport_size.x < 920.0 else 2
	_survey_selection_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 14)
	_survey_selection_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 14)
	if viewport_size.x < 760.0:
		_section_selection_grid.columns = 1
	elif viewport_size.x < 1240.0:
		_section_selection_grid.columns = 2
	else:
		_section_selection_grid.columns = 3
	_section_selection_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 14)
	_section_selection_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 14)
	_export_action_grid.columns = 1 if viewport_size.x < 860.0 else 2
	_export_action_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 12)
	_export_action_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 12)
	_survey_selection_action_spacer.visible = not phone_layout
	_section_selection_action_spacer.visible = not phone_layout
	_focus_nav_spacer.visible = not phone_layout
	_take_survey_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_get_lore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_survey_selection_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_section_selection_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_focus_previous_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_focus_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_thanks_review_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_thanks_export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_focus_question_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_focus_bottom_spacer.visible = false
	for button in [_take_survey_button, _get_lore_button, _survey_selection_back_button, _survey_selection_next_button, _lore_back_button, _lore_take_survey_button, _section_selection_back_button, _section_selection_next_button, _focus_back_button, _focus_previous_button, _focus_next_button, _thanks_review_button, _thanks_export_button, _export_back_button, _export_save_progress_button, _export_load_progress_button, _export_copy_json_button, _export_save_json_button, _export_copy_csv_button, _export_save_csv_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(button.custom_minimum_size.x if not phone_layout else 0.0, 50.0 if phone_layout else maxf(button.custom_minimum_size.y, 44.0))
	_focus_back_button.custom_minimum_size.x = 0.0
	_focus_previous_button.custom_minimum_size.x = 0.0 if phone_layout else 96.0
	_focus_next_button.custom_minimum_size.x = 0.0 if phone_layout else 96.0
	_focus_segment_row.add_theme_constant_override("separation", 3 if phone_layout else 4)
	if _menu_access_button != null:
		_menu_access_button.custom_minimum_size = Vector2(72.0 if compact_layout else 84.0, 42.0 if compact_layout else 48.0)
		_menu_access_button.add_theme_font_size_override("font_size", 14 if compact_layout else 15)
		var menu_button_width := clampf(viewport_size.x * 0.16, 72.0, 96.0)
		var menu_button_height := clampf(viewport_size.y * 0.05, 42.0, 50.0)
		var menu_inset := clampf(shortest_side * 0.02, 12.0, 24.0)
		_menu_access_button.offset_left = -menu_button_width - menu_inset
		_menu_access_button.offset_top = menu_inset
		_menu_access_button.offset_right = -menu_inset
		_menu_access_button.offset_bottom = menu_inset + menu_button_height
	_refresh_focus_stage_layout()
	_refresh_menu_access_button()
	if _overlay_menu != null:
		_overlay_menu.refresh_layout(viewport_size)

func _refresh_all_views() -> void:
	_refresh_survey_selection_view()
	_refresh_lore_view()
	_refresh_section_selection_view()
	_refresh_focus_view(false)
	_refresh_thanks_view()
	_refresh_export_view()

func _show_view(view_name: StringName) -> void:
	_current_view = view_name
	_landing_view.visible = view_name == VIEW_LANDING
	_survey_selection_view.visible = view_name == VIEW_SURVEY_SELECTION
	_lore_view.visible = view_name == VIEW_LORE
	_section_selection_view.visible = view_name == VIEW_SECTION_SELECTION
	_focus_view.visible = view_name == VIEW_FOCUS
	_thanks_view.visible = view_name == VIEW_THANKS
	_export_view.visible = view_name == VIEW_EXPORT
	match view_name:
		VIEW_SURVEY_SELECTION:
			_refresh_survey_selection_view()
		VIEW_LORE:
			_refresh_lore_view()
		VIEW_SECTION_SELECTION:
			_refresh_section_selection_view()
		VIEW_FOCUS:
			_refresh_focus_view(true)
		VIEW_THANKS:
			_refresh_thanks_view()
		VIEW_EXPORT:
			_refresh_export_view()
	_refresh_menu_access_button()

func _refresh_menu_access_button() -> void:
	if _menu_access_layer == null:
		return
	var overlay_blocking: bool = _overlay_menu != null and _overlay_menu.visible
	_menu_access_layer.visible = not overlay_blocking

func _open_overlay_menu() -> void:
	if _overlay_menu == null or survey == null:
		return
	_overlay_menu.open_menu(survey, _menu_section_index(), answers, sfx_volume, true, _journey_menu_options())
	_refresh_menu_access_button()

func _close_overlay_menu() -> void:
	if _overlay_menu == null:
		return
	_overlay_menu.close_menu()
	_refresh_menu_access_button()

func _menu_section_index() -> int:
	if survey == null or survey.sections.is_empty():
		return 0
	if _current_view == VIEW_FOCUS:
		var active_question_id := _current_focus_question_id()
		var active_section_index := _section_index_for_question_id(active_question_id)
		if active_section_index != -1:
			return active_section_index
	return clampi(_selected_section_index, 0, max(survey.sections.size() - 1, 0))

func _journey_menu_options() -> Dictionary:
	return {
		"heading_text": "Journey Menu",
		"restart_label": "Clear All Answers",
		"export_label": "Open Export Screen",
		"section_heading_text": "Jump To Or Clear A Section",
		"position_text": _journey_menu_position_text(),
		"show_search": false,
		"show_onboarding": false,
		"show_template_picker": false,
		"show_settings": false,
		"show_summary": false,
		"show_fill_test_answers": false,
		"show_export": survey != null,
		"show_theme_toggle": true,
		"show_sfx_controls": true,
		"show_section_tools": survey != null
	}

func _journey_menu_position_text() -> String:
	if survey == null:
		return "No survey is loaded yet."
	match _current_view:
		VIEW_LANDING:
			return "Loaded survey: %s. Start from landing or jump straight to a section." % survey.title
		VIEW_SURVEY_SELECTION:
			return "Choose which survey to open in Journey mode."
		VIEW_LORE:
			return "Reading the lore and framing for %s." % survey.title
		VIEW_SECTION_SELECTION:
			return "Choose where to begin in %s." % survey.title
		VIEW_THANKS:
			return "You have reached the thank-you screen for %s." % survey.title
		VIEW_EXPORT:
			return "You are on the export screen for %s." % survey.title
	var current_question_id := _current_focus_question_id()
	var section_index := _section_index_for_question_id(current_question_id)
	var answered_total := 0
	for question_id in _question_order:
		var question := _question_definition(question_id)
		if question != null and question.is_answer_complete(answers.get(question_id, null)):
			answered_total += 1
	return "Currently viewing section %d of %d. %d answered so far." % [clampi(section_index + 1, 1, max(survey.sections.size(), 1)), survey.sections.size(), answered_total]

func _on_take_survey_pressed() -> void:
	_selection_purpose = PURPOSE_SURVEY
	_selected_template_path = _default_template_selection_path()
	_show_view(VIEW_SURVEY_SELECTION)

func _on_get_lore_pressed() -> void:
	_selection_purpose = PURPOSE_LORE
	_selected_template_path = _default_template_selection_path()
	_show_view(VIEW_SURVEY_SELECTION)

func _on_menu_restart_requested() -> void:
	_close_overlay_menu()
	_clear_all_answers()

func _on_menu_clear_section_requested(section_index: int) -> void:
	_close_overlay_menu()
	_clear_section_answers(section_index)

func _on_menu_jump_to_section_requested(section_index: int) -> void:
	_close_overlay_menu()
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	_start_focus_from_section(section_index, "")

func _on_menu_export_requested() -> void:
	_close_overlay_menu()
	_open_export_overlay()

func _on_menu_theme_mode_requested(wants_dark_mode: bool) -> void:
	if use_dark_mode == wants_dark_mode:
		return
	use_dark_mode = wants_dark_mode
	SurveyStyle.set_dark_mode(use_dark_mode)
	_refresh_theme()
	_persist_preferences()

func _on_menu_sfx_volume_requested(volume: float) -> void:
	var resolved_volume := clampf(volume, 0.0, 1.0)
	if is_equal_approx(sfx_volume, resolved_volume):
		return
	sfx_volume = resolved_volume
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)
	_persist_preferences()

func _clear_all_answers() -> void:
	answers.clear()
	if _focus_question_stage != null:
		_focus_question_stage.sync_answers(answers)
	_refresh_all_views()
	if _current_view == VIEW_FOCUS and not _playable_question_ids.is_empty():
		_refresh_focus_view(true)
	_show_status_message("Cleared all answers for this survey.")

func _clear_section_answers(section_index: int) -> void:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	var cleared_count := 0
	for question in survey.sections[section_index].questions:
		if answers.has(question.id):
			answers.erase(question.id)
			cleared_count += 1
	if _focus_question_stage != null:
		_focus_question_stage.sync_answers(answers)
	_refresh_all_views()
	if _current_view == VIEW_FOCUS and not _playable_question_ids.is_empty():
		_refresh_focus_view(true)
	_show_status_message("Cleared %d answer(s) from %s." % [cleared_count, survey.sections[section_index].display_title(section_index)])

func _refresh_survey_selection_view() -> void:
	_survey_selection_heading_label.text = "Choose Your Survey" if _selection_purpose == PURPOSE_SURVEY else "Choose Your Lore Thread"
	_survey_selection_subtitle_label.text = "Pick a survey to enter the new focus-first flow." if _selection_purpose == PURPOSE_SURVEY else "Pick a survey to browse its framing, themes, and sections before you dive in."
	_survey_selection_next_button.text = "Choose Sections" if _selection_purpose == PURPOSE_SURVEY else "Open Lore"
	_clear_container(_survey_selection_grid)
	if _available_templates.is_empty():
		_selected_template_path = ""
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No survey templates were found."
		SurveyStyle.style_body(empty_label)
		_survey_selection_grid.add_child(empty_label)
		_survey_selection_next_button.disabled = true
		return
	if _selected_template_path.is_empty() or not _has_template_path(_selected_template_path):
		_selected_template_path = _default_template_selection_path()
	_survey_selection_next_button.disabled = _selected_template_path.is_empty()
	for template_summary in _available_templates:
		var template_path := str(template_summary.get("path", "")).strip_edges()
		var title := str(template_summary.get("title", "Survey")).strip_edges()
		var description := str(template_summary.get("description", "")).strip_edges()
		var caption := str(template_summary.get("source_label", "Template")).strip_edges()
		var card := _create_card_panel(SURVEY_ICON_LIBRARY.section_texture("generic"), title, description if not description.is_empty() else "Choose this survey to continue.", caption, template_path == _selected_template_path, SurveyStyle.ACCENT_ALT)
		_make_card_interactive(card, _on_template_card_selected.bind(template_path), _on_template_card_activated.bind(template_path))
		_survey_selection_grid.add_child(card)

func _on_template_card_selected(template_path: String) -> void:
	if _selected_template_path == template_path:
		return
	_selected_template_path = template_path
	_refresh_survey_selection_view()

func _on_template_card_activated(template_path: String) -> void:
	_selected_template_path = template_path
	_advance_from_survey_selection()

func _default_template_selection_path() -> String:
	if _available_templates.is_empty():
		return ""
	return str(_available_templates[0].get("path", "")).strip_edges()

func _has_template_path(template_path: String) -> bool:
	var normalized_path := template_path.strip_edges()
	if normalized_path.is_empty():
		return false
	for template_summary in _available_templates:
		if str(template_summary.get("path", "")).strip_edges() == normalized_path:
			return true
	return false

func _advance_from_survey_selection() -> void:
	if _selected_template_path.is_empty():
		_show_status_message("Choose a survey first.", true)
		return
	if not _load_survey_from_path(_selected_template_path, true):
		return
	if _selection_purpose == PURPOSE_SURVEY:
		_show_view(VIEW_SECTION_SELECTION)
	else:
		_show_view(VIEW_LORE)

func _refresh_lore_view() -> void:
	_lore_heading_label.text = "Get Lore"
	_lore_subtitle_label.text = "Survey framing, section intent, and the shape of the journey before you answer."
	if survey == null:
		_lore_survey_label.text = "No survey is loaded yet."
		_lore_take_survey_button.disabled = true
		_clear_container(_lore_list)
		return
	_lore_take_survey_button.disabled = false
	_lore_survey_label.text = "%s\n%s" % [survey.title, survey.description.strip_edges() if not survey.description.strip_edges().is_empty() else survey.subtitle.strip_edges()]
	_clear_container(_lore_list)
	var overview_card := _create_card_panel(SURVEY_ICON_LIBRARY.section_texture("review"), "Survey Overview", survey.description.strip_edges() if not survey.description.strip_edges().is_empty() else "This survey is ready to explore.", "%d section(s) • %d question(s)" % [survey.sections.size(), survey.total_questions()], true, SurveyStyle.ACCENT)
	_lore_list.add_child(overview_card)
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var description := section.description.strip_edges() if not section.description.strip_edges().is_empty() else "This section opens a different angle of the survey."
		var caption := "Section %d • %d question(s)" % [section_index + 1, section.questions.size()]
		_lore_list.add_child(_create_card_panel(SURVEY_ICON_LIBRARY.section_texture(section.icon_name), section.display_title(section_index), description, caption, false, SurveyStyle.BORDER))

func _on_lore_take_survey_pressed() -> void:
	_selection_purpose = PURPOSE_SURVEY
	_show_view(VIEW_SECTION_SELECTION)

func _refresh_section_selection_view() -> void:
	_section_selection_heading_label.text = "Choose Your Starting Section"
	_section_selection_subtitle_label.text = "Pick where you want to jump in. The redesign uses Focus Mode all the way through."
	_section_selection_survey_label.text = survey.title if survey != null else "No survey loaded."
	if survey != null and (_selected_section_index < 0 or _selected_section_index >= survey.sections.size()):
		_selected_section_index = 0 if not survey.sections.is_empty() else -1
	_section_selection_next_button.text = "Start Section"
	_section_selection_next_button.disabled = _selected_section_index < 0
	_clear_container(_section_selection_grid)
	if survey == null:
		_section_selection_next_button.disabled = true
		return
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var answered_count := _section_answered_count(section)
		var completion_state := _section_completion_state(section)
		var accent_color := _completion_color(completion_state)
		var description := section.description.strip_edges() if not section.description.strip_edges().is_empty() else "Start here when you want this section's questions first."
		var caption := "%d question(s) • %d answered" % [section.questions.size(), answered_count]
		var is_active := section_index == _selected_section_index
		var card := _create_card_panel(SURVEY_ICON_LIBRARY.section_texture(section.icon_name), section.display_title(section_index), description, caption, is_active, accent_color)
		_make_card_interactive(card, _on_section_card_selected.bind(section_index), _on_section_card_activated.bind(section_index))
		_section_selection_grid.add_child(card)

func _on_section_card_selected(section_index: int) -> void:
	if _selected_section_index == section_index:
		return
	_selected_section_index = section_index
	_refresh_section_selection_view()

func _on_section_card_activated(section_index: int) -> void:
	_selected_section_index = section_index
	_advance_from_section_selection()

func _advance_from_section_selection() -> void:
	if survey == null or _selected_section_index < 0 or _selected_section_index >= survey.sections.size():
		_show_status_message("Choose a section first.", true)
		return
	_start_focus_from_section(_selected_section_index, "")

func _start_focus_from_section(section_index: int, question_id: String = "") -> void:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	_focus_start_section_index = section_index
	_selected_section_index = section_index
	_playable_question_ids.clear()
	for next_section_index in range(section_index, survey.sections.size()):
		for question in survey.sections[next_section_index].questions:
			_playable_question_ids.append(question.id)
	_focus_index = 0
	if not question_id.is_empty():
		var restored_index := _playable_question_ids.find(question_id)
		if restored_index != -1:
			_focus_index = restored_index
	_trace("Start focus from section=%d question=%s playable=%d" % [section_index, question_id if not question_id.is_empty() else "<auto>", _playable_question_ids.size()])
	_rebuild_focus_question_stage()
	_show_view(VIEW_FOCUS)

func _refresh_focus_view(force_rebuild: bool = false, transition_direction: int = 0) -> void:
	if _current_view != VIEW_FOCUS and not force_rebuild:
		return
	if survey == null or _playable_question_ids.is_empty():
		_refresh_thanks_view()
		return
	_focus_index = clampi(_focus_index, 0, _playable_question_ids.size() - 1)
	var question_id := _playable_question_ids[_focus_index]
	var section_index := _section_index_for_question_id(question_id)
	if section_index == -1:
		return
	var section: SurveySection = survey.sections[section_index]
	var section_question_index := _question_index_in_section(question_id)
	_focus_section_label.text = section.display_title(section_index)
	_focus_progress_label.text = "Question %d of %d" % [section_question_index + 1, max(section.questions.size(), 1)]
	_rebuild_focus_segments(section_index, question_id)
	_update_focus_navigation_state()
	if _focus_question_stage == null:
		return
	if force_rebuild or _focus_question_stage.active_question_id() != question_id:
		_trace("Show focus question index=%d id=%s force=%s dir=%d" % [_focus_index, question_id, str(force_rebuild), transition_direction])
		_focus_question_scroll.scroll_vertical = 0
		_focus_question_stage.show_question(question_id)
		_update_focus_scroll_height(get_viewport().get_visible_rect().size)

func _rebuild_focus_segments(section_index: int, active_question_id: String) -> void:
	_clear_container(_focus_segment_row)
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	var section: SurveySection = survey.sections[section_index]
	var phone_layout := _is_phone_layout_for_size(get_viewport().get_visible_rect().size)
	for question in section.questions:
		var completion_state: StringName = question.answer_completion_state(answers.get(question.id, null))
		var fill := _segment_fill_color(completion_state)
		var border := _segment_border_color(completion_state)
		if question.id == active_question_id:
			fill = fill.darkened(0.18)
			border = border.lightened(0.06)
		var segment := PanelContainer.new()
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size = Vector2(0.0, 5.0 if phone_layout else 6.0)
		segment.add_theme_stylebox_override("panel", _panel_style(fill, border, 6, 1, 0.0))
		_focus_segment_row.add_child(segment)

func _rebuild_focus_question_stage() -> void:
	if _focus_question_stage == null:
		return
	if _playable_question_ids.is_empty():
		_focus_question_stage.reset()
		return
	var focus_questions: Array = []
	for question_id in _playable_question_ids:
		var question := _question_definition(question_id)
		if question != null:
			focus_questions.append(question)
	_focus_question_stage.prepare_questions(focus_questions, answers, get_viewport().get_visible_rect().size)

func _refresh_focus_stage_layout() -> void:
	if _focus_question_stage != null:
		_focus_question_stage.refresh_stage_layout(get_viewport().get_visible_rect().size)
	_update_focus_scroll_height(get_viewport().get_visible_rect().size)

func _update_focus_scroll_height(viewport_size: Vector2) -> void:
	if _focus_question_scroll == null:
		return
	var stage_content_height := 0.0
	if _focus_question_stage != null:
		stage_content_height = maxf(stage_content_height, _focus_question_stage.size.y)
		stage_content_height = maxf(stage_content_height, _focus_question_stage.custom_minimum_size.y)
		stage_content_height = maxf(stage_content_height, _focus_question_stage.get_combined_minimum_size().y)
		var active_view: SurveyQuestionView = _focus_question_stage.active_view()
		if active_view != null:
			stage_content_height = maxf(stage_content_height, active_view.size.y)
			stage_content_height = maxf(stage_content_height, active_view.custom_minimum_size.y)
			stage_content_height = maxf(stage_content_height, active_view.get_combined_minimum_size().y)
	var top_row := _focus_back_button.get_parent() as Control
	var nav_row := _focus_previous_button.get_parent() as Control
	var reserved_height := 0.0
	reserved_height += _control_layout_height(top_row)
	reserved_height += _control_layout_height(_focus_section_label)
	reserved_height += _control_layout_height(_focus_progress_label)
	reserved_height += _control_layout_height(_focus_segment_row)
	reserved_height += _control_layout_height(nav_row)
	reserved_height += float(_focus_view.get_theme_constant("separation")) * 4.0
	reserved_height += float(_margin.get_theme_constant("margin_top") + _margin.get_theme_constant("margin_bottom"))
	var max_scroll_height := maxf(viewport_size.y - reserved_height - (24.0 if _is_phone_layout_for_size(viewport_size) else 56.0), 180.0)
	var target_height := clampf((stage_content_height + 8.0) if stage_content_height > 0.0 else max_scroll_height, 140.0, max_scroll_height)
	_focus_question_scroll.custom_minimum_size.y = target_height

func _control_layout_height(control: Control) -> float:
	if control == null or not control.visible:
		return 0.0
	return maxf(control.size.y, control.get_combined_minimum_size().y)

func _on_focus_answer_changed(question_id: String, value: Variant) -> void:
	answers[question_id] = _duplicate_answer_value(value)
	_trace("Answer changed question=%s type=%s" % [question_id, typeof(value)])
	_refresh_focus_view(false)

func _on_focus_question_selected(_question_id: String) -> void:
	return

func _on_focus_stage_layout_stabilized() -> void:
	call_deferred("_refresh_focus_scroll_height_after_layout_stabilized")

func _refresh_focus_scroll_height_after_layout_stabilized() -> void:
	_update_focus_scroll_height(get_viewport().get_visible_rect().size)

func _on_focus_previous_pressed() -> void:
	_queue_focus_navigation(-1)

func _on_focus_next_pressed() -> void:
	_queue_focus_navigation(1)

func _update_focus_navigation_state() -> void:
	if _focus_navigation_pending:
		_focus_previous_button.disabled = true
		_focus_next_button.disabled = true
		return
	_focus_previous_button.disabled = _focus_index <= 0
	_focus_next_button.disabled = false
	_focus_next_button.text = "Finish" if _focus_index >= _playable_question_ids.size() - 1 else "Next"

func _refresh_thanks_view() -> void:
	_thanks_heading_label.text = "Thank You"
	if survey == null:
		_thanks_body_label.text = "Your survey session has wrapped."
		_thanks_review_button.disabled = true
		_thanks_export_button.disabled = true
		return
	var answered_questions := 0
	for question_id in _question_order:
		var question := _question_definition(question_id)
		if question != null and question.is_answer_complete(answers.get(question_id, null)):
			answered_questions += 1
	_thanks_review_button.disabled = _playable_question_ids.is_empty()
	_thanks_export_button.disabled = false
	_thanks_body_label.text = "Thanks for participating in %s.\n\nYou answered %d question(s). When you're ready, open the export screen to save or share your results." % [survey.title, answered_questions]

func _open_export_overlay() -> void:
	if survey == null:
		_show_status_message("Load a survey before exporting.", true)
		return
	_show_view(VIEW_EXPORT)

func _close_export_overlay() -> void:
	_show_view(VIEW_THANKS)

func _on_thanks_review_pressed() -> void:
	if survey == null:
		_show_view(VIEW_LANDING)
		return
	if _playable_question_ids.is_empty():
		_show_view(VIEW_SECTION_SELECTION)
		return
	_focus_index = clampi(_focus_index, 0, _playable_question_ids.size() - 1)
	_show_view(VIEW_FOCUS)

func _refresh_export_view() -> void:
	var state := _build_export_overlay_state()
	var has_survey := survey != null
	_export_heading_label.text = "Export Your Answers"
	_export_subtitle_label.text = survey.title if has_survey else "No survey is loaded."
	var body_lines: Array[String] = []
	var progress_summary := str(state.get("progress_summary", "")).strip_edges()
	if not progress_summary.is_empty():
		body_lines.append(progress_summary)
	var answer_summary := str(state.get("answer_summary", "")).strip_edges()
	if not answer_summary.is_empty():
		body_lines.append(answer_summary)
	var progress_reason := str(state.get("load_progress_unavailable_reason", "")).strip_edges()
	if not progress_reason.is_empty():
		body_lines.append(progress_reason)
	var upload_summary := str(state.get("upload_ready_message", "")).strip_edges()
	if not upload_summary.is_empty():
		body_lines.append(upload_summary)
	var body_text := ""
	for line in body_lines:
		if body_text.is_empty():
			body_text = line
		else:
			body_text += "\n\n%s" % line
	_export_body_label.text = body_text
	_export_save_progress_button.text = str(state.get("save_progress_label", "Save Progress JSON"))
	_export_load_progress_button.text = str(state.get("load_progress_label", "Load Progress JSON"))
	_export_save_json_button.text = str(state.get("save_json_label", "Save JSON"))
	_export_save_csv_button.text = str(state.get("save_csv_label", "Save CSV"))
	_export_save_progress_button.disabled = not bool(state.get("save_progress_enabled", false))
	_export_load_progress_button.disabled = not bool(state.get("load_progress_enabled", false))
	_export_copy_json_button.disabled = not has_survey
	_export_save_json_button.disabled = not has_survey
	_export_copy_csv_button.disabled = not has_survey
	_export_save_csv_button.disabled = not has_survey

func _build_export_overlay_state() -> Dictionary:
	var browser_downloads := _supports_browser_downloads()
	var web_progress_import := _supports_browser_progress_import()
	return {
		"survey_title": survey.title if survey != null else "",
		"progress_summary": "Save the redesign-flow progress bundle, including your current position in the focus journey.",
		"answer_summary": "Copy or save answer-only exports for review, debugging, or offline analysis.",
		"save_progress_enabled": survey != null,
		"load_progress_enabled": web_progress_import if _is_web_platform() else _load_dialog != null,
		"load_progress_unavailable_reason": "This build cannot open a progress import picker right now." if _is_web_platform() and not web_progress_import else "",
		"save_progress_label": "Download Progress JSON" if browser_downloads else "Save Progress JSON",
		"load_progress_label": "Import Progress JSON" if _is_web_platform() else "Load Progress JSON",
		"save_json_label": "Download JSON" if browser_downloads else "Save JSON",
		"save_csv_label": "Download CSV" if browser_downloads else "Save CSV",
		"upload_destination_name": "",
		"upload_destination_url": "",
		"upload_usage_summary": "Upload is not configured in this redesign flow yet.",
		"upload_reason_summary": "Use the local export actions for now.",
		"upload_metadata_summary": "Client-side upload wiring can be added later once this new flow is locked in.",
		"upload_ready": false,
		"upload_ready_message": "Server upload is disabled in this redesign prototype.",
		"upload_busy": false,
		"upload_status_text": "Upload unavailable in this redesign flow.",
		"upload_status_error": false,
		"upload_response_text": "",
		"consent_required": false
	}

func _save_progress_json() -> void:
	if survey == null:
		_show_status_message("No survey is loaded to save.", true)
		return
	var progress_text := SURVEY_SAVE_BUNDLE.build_json_text(survey, _current_template_path, answers, _current_preferences(), _current_session_state())
	if progress_text.is_empty():
		_show_status_message("Unable to build survey progress.", true)
		return
	_prompt_save_text(progress_text, "json", "Survey progress", "Save Survey Progress", SURVEY_SAVE_BUNDLE.suggested_filename(survey.id))

func _load_progress_json() -> void:
	if _is_web_platform():
		if not _open_web_progress_import_picker():
			_show_status_message("This browser build could not open a progress file picker.", true)
		return
	if _load_dialog == null:
		_show_status_message("Progress import is unavailable in this build.", true)
		return
	_load_dialog.title = "Load Survey Progress"
	_load_dialog.clear_filters()
	_load_dialog.add_filter("*.json", "JSON Files")
	_load_dialog.current_path = ProjectSettings.globalize_path("user://")
	_load_dialog.popup_centered_ratio(0.75)

func _copy_json() -> void:
	_copy_export_to_clipboard(EXPORT_FORMAT_JSON)

func _save_json() -> void:
	_prompt_save_export(EXPORT_FORMAT_JSON)

func _copy_csv() -> void:
	_copy_export_to_clipboard(EXPORT_FORMAT_CSV)

func _save_csv() -> void:
	_prompt_save_export(EXPORT_FORMAT_CSV)

func _copy_export_to_clipboard(format: String) -> void:
	var export_text := _build_export_text(format)
	if export_text.is_empty():
		_show_status_message("Unable to build %s export." % _export_label(format), true)
		return
	DisplayServer.clipboard_set(export_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("%s copied to clipboard." % _export_label(format))

func _prompt_save_export(format: String) -> void:
	var export_text := _build_export_text(format)
	if export_text.is_empty():
		_show_status_message("Unable to build %s export." % _export_label(format), true)
		return
	_prompt_save_text(export_text, format, _export_label(format), "Save %s Export" % _export_label(format), SURVEY_EXPORTER.suggested_filename(survey.id, format))

func _prompt_save_text(contents: String, extension: String, label: String, dialog_title: String, suggested_file: String) -> void:
	if contents.is_empty():
		_show_status_message("Nothing is available to save for %s." % label, true)
		return
	if _supports_browser_downloads():
		if _download_buffer_to_browser(contents.to_utf8_buffer(), suggested_file, "%s download started." % label):
			return
	if _save_dialog == null:
		_show_status_message("Save dialogs are unavailable in this build.", true)
		return
	_pending_save_text = contents
	_pending_save_extension = extension
	_pending_save_label = label
	_save_dialog.title = dialog_title
	_save_dialog.clear_filters()
	if extension.to_lower() == "json":
		_save_dialog.add_filter("*.json", "JSON Files")
	elif extension.to_lower() == "csv":
		_save_dialog.add_filter("*.csv", "CSV Files")
	_save_dialog.current_file = suggested_file
	_save_dialog.popup_centered_ratio(0.75)

func _build_export_text(format: String) -> String:
	if survey == null:
		return ""
	match format:
		EXPORT_FORMAT_JSON:
			return SURVEY_EXPORTER.build_json_text(survey, answers)
		EXPORT_FORMAT_CSV:
			return SURVEY_EXPORTER.build_csv_text(survey, answers)
	return ""

func _export_label(format: String) -> String:
	return format.to_upper()

func _on_save_dialog_file_selected(path: String) -> void:
	var target_path := path
	if not _pending_save_extension.is_empty() and target_path.get_extension().to_lower() != _pending_save_extension:
		target_path = "%s.%s" % [target_path, _pending_save_extension]
	var save_ok := SURVEY_EXPORTER.save_text_file(target_path, _pending_save_text)
	if save_ok:
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message("%s saved to %s" % [_pending_save_label, target_path])
	else:
		_show_status_message("Failed to save %s." % _pending_save_label, true)
	_clear_pending_save_state()

func _on_save_dialog_canceled() -> void:
	_clear_pending_save_state()

func _clear_pending_save_state() -> void:
	_pending_save_text = ""
	_pending_save_extension = ""
	_pending_save_label = ""

func _on_load_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_status_message("Failed to open %s." % path.get_file(), true)
		return
	_apply_loaded_progress_text(file.get_as_text(), path.get_file())

func _on_load_dialog_canceled() -> void:
	return

func _apply_loaded_progress_text(progress_text: String, source_name: String) -> void:
	var payload := SURVEY_SAVE_BUNDLE.parse_json_text(progress_text)
	if payload.is_empty():
		_show_status_message("No compatible survey data was found in %s." % source_name, true)
		return
	_apply_loaded_progress_payload(payload, source_name)

func _apply_loaded_progress_payload(payload: Dictionary, source_name: String) -> void:
	var payload_template_path := _normalize_template_path_input(str(payload.get("template_path", "")).strip_edges())
	if not payload_template_path.is_empty() and payload_template_path != _current_template_path and FileAccess.file_exists(payload_template_path):
		if not _load_survey_from_path(payload_template_path, false):
			return
	var loaded_answers := _sanitize_loaded_answers(_extract_dictionary(payload, "answers"))
	var loaded_preferences := _extract_dictionary(payload, "preferences")
	var loaded_session_state := _sanitize_session_state(_extract_dictionary(payload, "session_state"))
	if loaded_answers.is_empty() and loaded_preferences.is_empty() and loaded_session_state.is_empty():
		_show_status_message("No matching survey answers were found in %s." % source_name, true)
		return
	answers = loaded_answers
	var theme_changed := _apply_loaded_preferences(loaded_preferences)
	if theme_changed:
		_refresh_theme()
	else:
		_refresh_all_views()
	if not loaded_session_state.is_empty():
		var restored_question_id := str(loaded_session_state.get("selected_question_id", "")).strip_edges()
		if not restored_question_id.is_empty():
			var restored_section_index := _section_index_for_question_id(restored_question_id)
			if restored_section_index != -1:
				_start_focus_from_section(restored_section_index, restored_question_id)
			else:
				_show_view(VIEW_SECTION_SELECTION)
		else:
			var restored_section_index := clampi(int(loaded_session_state.get("current_section_index", 0)), 0, max(survey.sections.size() - 1, 0))
			_start_focus_from_section(restored_section_index, "")
	else:
		_show_view(VIEW_SECTION_SELECTION)
	_refresh_export_view()
	_show_status_message("Loaded progress from %s." % source_name)

func _sanitize_loaded_answers(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if survey == null:
		return sanitized
	for section in survey.sections:
		for question in section.questions:
			if source.has(question.id):
				sanitized[question.id] = _duplicate_answer_value(source.get(question.id))
	return sanitized

func _sanitize_session_state(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if survey == null:
		return sanitized
	var max_section_index: int = max(survey.sections.size() - 1, 0)
	sanitized["current_section_index"] = clampi(int(source.get("current_section_index", 0)), 0, max_section_index)
	var selected_question_id := str(source.get("selected_question_id", "")).strip_edges()
	if not selected_question_id.is_empty() and _section_index_for_question_id(selected_question_id) != -1:
		sanitized["selected_question_id"] = selected_question_id
		sanitized["current_section_index"] = _section_index_for_question_id(selected_question_id)
	return sanitized

func _extract_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _apply_loaded_preferences(preferences: Dictionary) -> bool:
	var theme_changed := false
	if preferences.has("use_dark_mode"):
		var desired_dark_mode := bool(preferences.get("use_dark_mode", use_dark_mode))
		if use_dark_mode != desired_dark_mode:
			use_dark_mode = desired_dark_mode
			SurveyStyle.set_dark_mode(use_dark_mode)
			theme_changed = true
	if preferences.has("sfx_volume"):
		sfx_volume = clampf(float(preferences.get("sfx_volume", sfx_volume)), 0.0, 1.0)
		SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)
	return theme_changed

func _current_preferences() -> Dictionary:
	return {
		"use_dark_mode": use_dark_mode,
		"sfx_volume": sfx_volume,
		"survey_view_mode": "focus"
	}

func _current_session_state() -> Dictionary:
	var selected_question_id := _current_focus_question_id()
	return {
		"current_section_index": _section_index_for_question_id(selected_question_id),
		"selected_question_id": selected_question_id
	}

func _current_focus_question_id() -> String:
	if not _playable_question_ids.is_empty() and _focus_index >= 0 and _focus_index < _playable_question_ids.size():
		return _playable_question_ids[_focus_index]
	if _focus_question_stage != null and not _focus_question_stage.active_question_id().is_empty():
		return _focus_question_stage.active_question_id()
	return _question_order.back() if not _question_order.is_empty() else ""

func _is_web_platform() -> bool:
	return OS.has_feature("web")

func _supports_browser_downloads() -> bool:
	return _is_web_platform() and Engine.has_singleton("JavaScriptBridge")

func _supports_browser_progress_import() -> bool:
	return _is_web_platform() and Engine.has_singleton("JavaScriptBridge")

func _download_buffer_to_browser(buffer: PackedByteArray, file_name: String, success_message: String) -> bool:
	if buffer.is_empty() or not _supports_browser_downloads():
		return false
	JavaScriptBridge.download_buffer(buffer, file_name)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message(success_message)
	return true

func _open_web_progress_import_picker() -> bool:
	if not _supports_browser_progress_import():
		return false
	if _web_progress_picker_active:
		_show_status_message("The browser file picker is already open.")
		return true
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	_web_progress_picker_success_callback = JavaScriptBridge.create_callback(_on_web_progress_import_success)
	_web_progress_picker_error_callback = JavaScriptBridge.create_callback(_on_web_progress_import_error)
	window.__surveyJourneyProgressImportSuccess = _web_progress_picker_success_callback
	window.__surveyJourneyProgressImportError = _web_progress_picker_error_callback
	_web_progress_picker_active = true
	JavaScriptBridge.eval("""
		(function () {
			const success = window.__surveyJourneyProgressImportSuccess;
			const failure = window.__surveyJourneyProgressImportError;
			if (!success || !failure) {
				return;
			}
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.style.display = 'none';
			let finished = false;
			const cleanup = () => {
				window.removeEventListener('focus', onWindowFocus);
				if (input.parentNode) {
					input.parentNode.removeChild(input);
				}
			};
			const fail = (kind, fileName, message) => {
				if (finished) {
					return;
				}
				finished = true;
				failure(kind || 'error', fileName || '', message || '');
				cleanup();
			};
			const succeed = (fileName, text) => {
				if (finished) {
					return;
				}
				finished = true;
				success(fileName || 'progress.json', text || '');
				cleanup();
			};
			const onWindowFocus = () => {
				window.setTimeout(() => {
					if (!finished && (!input.files || input.files.length === 0)) {
						fail('cancel', '', 'No file selected.');
					}
				}, 250);
			};
			window.addEventListener('focus', onWindowFocus, { once: true });
			input.addEventListener('change', () => {
				if (!input.files || input.files.length === 0) {
					fail('cancel', '', 'No file selected.');
					return;
				}
				const file = input.files[0];
				const reader = new FileReader();
				reader.onload = () => {
					succeed(file && file.name ? file.name : 'progress.json', typeof reader.result === 'string' ? reader.result : '');
				};
				reader.onerror = () => {
					const errorText = reader.error ? String(reader.error) : 'Failed to read the selected file.';
					fail('read_error', file && file.name ? file.name : '', errorText);
				};
				reader.readAsText(file);
			}, { once: true });
			document.body.appendChild(input);
			input.click();
		})();
	""", true)
	_show_status_message("Select a saved progress JSON file to import.")
	return true

func _on_web_progress_import_success(args: Array) -> void:
	var file_name := "progress.json"
	var progress_text := ""
	if args.size() >= 1:
		file_name = str(args[0]).strip_edges()
	if args.size() >= 2:
		progress_text = str(args[1])
	_clear_web_progress_import_callbacks()
	if progress_text.strip_edges().is_empty():
		_show_status_message("The selected progress file was empty.", true)
		return
	_apply_loaded_progress_text(progress_text, file_name if not file_name.is_empty() else "progress.json")

func _on_web_progress_import_error(args: Array) -> void:
	var error_kind := ""
	var file_name := ""
	var message := ""
	if args.size() >= 1:
		error_kind = str(args[0]).strip_edges()
	if args.size() >= 2:
		file_name = str(args[1]).strip_edges()
	if args.size() >= 3:
		message = str(args[2]).strip_edges()
	_clear_web_progress_import_callbacks()
	if error_kind == "cancel":
		return
	var target_name := file_name if not file_name.is_empty() else "the selected progress file"
	var error_text := "Failed to import %s." % target_name
	if not message.is_empty():
		error_text = "%s %s" % [error_text, message]
	_show_status_message(error_text, true)

func _clear_web_progress_import_callbacks() -> void:
	_web_progress_picker_active = false
	if _supports_browser_progress_import():
		var window = JavaScriptBridge.get_interface("window")
		if window != null:
			window.__surveyJourneyProgressImportSuccess = null
			window.__surveyJourneyProgressImportError = null
	_web_progress_picker_success_callback = null
	_web_progress_picker_error_callback = null

func _section_index_for_question_id(question_id: String) -> int:
	if question_id.is_empty() or survey == null:
		return -1
	for section_index in range(survey.sections.size()):
		for question in survey.sections[section_index].questions:
			if question.id == question_id:
				return section_index
	return -1

func _question_index_in_section(question_id: String) -> int:
	var section_index := _section_index_for_question_id(question_id)
	if section_index == -1:
		return -1
	var section: SurveySection = survey.sections[section_index]
	for question_index in range(section.questions.size()):
		if section.questions[question_index].id == question_id:
			return question_index
	return -1

func _question_definition(question_id: String) -> SurveyQuestion:
	if survey == null:
		return null
	for section in survey.sections:
		for question in section.questions:
			if question.id == question_id:
				return question
	return null

func _create_card_panel(texture: Texture2D, title: String, description: String, caption: String, is_active: bool, accent_color: Color) -> PanelContainer:
	var phone_layout := _is_phone_layout_for_size(get_viewport().get_visible_rect().size)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 128.0 if phone_layout else 152.0)
	var fill := SurveyStyle.SURFACE_MUTED if is_active else SurveyStyle.SURFACE_ALT
	var border := accent_color if is_active else SurveyStyle.BORDER
	card.add_theme_stylebox_override("panel", _panel_style(fill, border, 18 if phone_layout else 22, 2 if is_active else 1, 14.0 if phone_layout else 16.0))
	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 12 if phone_layout else 14)
	card.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44.0, 44.0) if phone_layout else Vector2(56.0, 56.0)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = texture
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6 if phone_layout else 8)
	row.add_child(content)
	var title_label := Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = title
	SurveyStyle.style_heading(title_label, 18 if phone_layout else 20, SurveyStyle.TEXT_PRIMARY)
	content.add_child(title_label)
	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = description
	SurveyStyle.style_body(description_label)
	description_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	content.add_child(description_label)
	if not caption.is_empty():
		var caption_label := Label.new()
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption_label.text = caption
		SurveyStyle.style_caption(caption_label, accent_color if is_active else SurveyStyle.TEXT_PRIMARY)
		caption_label.add_theme_font_size_override("font_size", 12 if phone_layout else 13)
		content.add_child(caption_label)
	return card

func _is_phone_layout_for_size(viewport_size: Vector2) -> bool:
	return viewport_size.x <= 480.0

func _make_card_interactive(card: Control, select_callback: Callable, activate_callback: Callable) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_card_gui_input.bind(select_callback, activate_callback))
	card.mouse_entered.connect(_on_button_hovered)
	card.focus_entered.connect(_on_card_focus_entered.bind(select_callback))

func _on_card_focus_entered(select_callback: Callable) -> void:
	_on_button_hovered()
	if select_callback.is_valid():
		call_deferred("_invoke_card_callback", select_callback)

func _on_card_gui_input(event: InputEvent, select_callback: Callable, activate_callback: Callable) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			SURVEY_UI_FEEDBACK.play_select()
			call_deferred("_invoke_card_callback", select_callback)
			if mouse_event.double_click:
				call_deferred("_invoke_card_callback", activate_callback)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			SURVEY_UI_FEEDBACK.play_select()
			call_deferred("_invoke_card_callback", activate_callback if activate_callback.is_valid() else select_callback)

func _invoke_card_callback(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

func _queue_focus_navigation(direction: int) -> void:
	if _focus_navigation_pending:
		return
	if direction < 0 and _focus_index <= 0:
		return
	_release_focus_before_navigation()
	_focus_navigation_pending = true
	_focus_previous_button.disabled = true
	_focus_next_button.disabled = true
	_trace("Queue navigation direction=%d current_index=%d current_question=%s" % [direction, _focus_index, _current_focus_question_id()])
	call_deferred("_begin_focus_navigation", direction)

func _release_focus_before_navigation() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	var focus_control := focus_owner as Control
	if focus_control != null:
		focus_control.release_focus()

func _begin_focus_navigation(direction: int) -> void:
	_trace("Begin navigation direction=%d current_index=%d current_question=%s" % [direction, _focus_index, _current_focus_question_id()])
	call_deferred("_apply_focus_navigation", direction)

func _apply_focus_navigation(direction: int) -> void:
	_focus_navigation_pending = false
	if direction >= 0 and _focus_index >= _playable_question_ids.size() - 1:
		_trace("Navigation reached thanks screen from question=%s" % _current_focus_question_id())
		_show_view(VIEW_THANKS)
		return
	if direction < 0:
		_focus_index = max(_focus_index - 1, 0)
	else:
		_focus_index = min(_focus_index + 1, max(_playable_question_ids.size() - 1, 0))
	_trace("Apply navigation direction=%d new_index=%d target_question=%s" % [direction, _focus_index, _current_focus_question_id()])
	_refresh_focus_view(true, direction)

func _panel_style(fill: Color, border: Color, radius: int, border_width: int, content_margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style

func _section_answered_count(section: SurveySection) -> int:
	var total := 0
	for question in section.questions:
		if question.is_answer_complete(answers.get(question.id, null)):
			total += 1
	return total

func _section_completion_state(section: SurveySection) -> StringName:
	if section.questions.is_empty():
		return SurveyQuestion.ANSWER_STATE_UNANSWERED
	var answered_count := _section_answered_count(section)
	if answered_count == 0:
		return SurveyQuestion.ANSWER_STATE_UNANSWERED
	if answered_count >= section.questions.size():
		return SurveyQuestion.ANSWER_STATE_COMPLETE
	return SurveyQuestion.ANSWER_STATE_PARTIAL

func _completion_color(state: StringName) -> Color:
	match state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return COMPLETE_STATUS_COLOR
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return PARTIAL_STATUS_COLOR
	return SurveyStyle.ACCENT_ALT

func _segment_fill_color(state: StringName) -> Color:
	match state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return COMPLETE_STATUS_COLOR.darkened(0.12)
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return PARTIAL_STATUS_COLOR.darkened(0.12)
	return SurveyStyle.SURFACE_ALT

func _segment_border_color(state: StringName) -> Color:
	match state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return COMPLETE_STATUS_COLOR
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return PARTIAL_STATUS_COLOR
	return SurveyStyle.BORDER

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _duplicate_answer_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return value

func _normalize_template_path_input(raw_path: String) -> String:
	var requested_path := raw_path.strip_edges()
	if requested_path.is_empty():
		return ""
	var project_res_path := ProjectSettings.globalize_path("res://")
	var project_user_path := ProjectSettings.globalize_path("user://")
	if requested_path.begins_with(project_res_path) or requested_path.begins_with(project_user_path):
		return ProjectSettings.localize_path(requested_path)
	return requested_path

func _messages_from_variant(value: Variant) -> PackedStringArray:
	var messages: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			messages.append(str(item))
		return messages
	if value is Array:
		for item in value:
			messages.append(str(item))
		return messages
	var text_value := str(value).strip_edges()
	if not text_value.is_empty():
		messages.append(text_value)
	return messages

func _start_trace_session() -> void:
	var timestamp := Time.get_datetime_string_from_system(true)
	var header := "\n=== SurveyJourney Session %s ===\n" % timestamp
	_append_trace_text(header)

func _trace(message: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	_append_trace_text("[%s] %s\n" % [timestamp, message])

func _append_trace_text(text: String) -> void:
	var existing := ""
	if FileAccess.file_exists(TRACE_LOG_PATH):
		var read_file := FileAccess.open(TRACE_LOG_PATH, FileAccess.READ)
		if read_file != null:
			existing = read_file.get_as_text()
			read_file.close()
	var write_file := FileAccess.open(TRACE_LOG_PATH, FileAccess.WRITE)
	if write_file == null:
		return
	write_file.store_string(existing + text)
	write_file.close()

func _show_status_message(message: String, is_error: bool = false) -> void:
	var trimmed := message.strip_edges()
	_status_label.visible = not trimmed.is_empty()
	_status_label.text = trimmed
	if trimmed.is_empty():
		return
	SurveyStyle.style_caption(_status_label, SurveyStyle.DANGER if is_error else SurveyStyle.TEXT_PRIMARY)
