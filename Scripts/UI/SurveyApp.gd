class_name SurveyApp
extends Control

const DEFAULT_QUESTION_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/DefaultQuestionView.tscn")
const SCALE_CHIPS_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/ScaleChipQuestionView.tscn")
const RANKED_CHOICE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/RankedChoiceQuestionView.tscn")
const MATRIX_QUESTION_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/MatrixQuestionView.tscn")
const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_SESSION_CACHE = preload("res://Scripts/Survey/SurveySessionCache.gd")
const SURVEY_PREFERENCES_STORE = preload("res://Scripts/Survey/SurveyPreferencesStore.gd")
const SURVEY_SAVE_BUNDLE = preload("res://Scripts/Survey/SurveySaveBundle.gd")
const SURVEY_SUMMARY_ANALYZER = preload("res://Scripts/Survey/SurveySummaryAnalyzer.gd")
const SURVEY_SUBMISSION_BUNDLE = preload("res://Scripts/Survey/SurveySubmissionBundle.gd")
const SURVEY_UPLOAD_AUDIT_STORE = preload("res://Scripts/Survey/SurveyUploadAuditStore.gd")
const SURVEY_SETTINGS_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/SurveySettingsOverlay.tscn")
const SURVEY_SUMMARY_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/SurveySummaryOverlay.tscn")
const SURVEY_EXPORT_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/SurveyExportOverlay.tscn")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")
const SPRITE_ICON_HOST = preload("res://Scripts/UI/SpriteIconHost.gd")
const SURVEY_ICON_LIBRARY = preload("res://Scripts/UI/SurveyIconLibrary.gd")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const DEFAULT_CONTENT_SIZE := Vector2i(1440, 900)
const EXPORT_FORMAT_JSON := "json"
const EXPORT_FORMAT_CSV := "csv"
const TEMPLATE_SELECTION_STORE_PATH := "user://selected_survey_template.json"
const SURVEY_VIEW_MODE_AUTO := "auto"
const SURVEY_VIEW_MODE_SCROLL := "scroll"
const SURVEY_VIEW_MODE_FOCUS := "focus"

@export_file("*.json") var survey_template_path := "res://Dev/SurveyTemplates/studio_feedback.json"
@export var dark_palette: Resource = DEFAULT_DARK_PALETTE
@export var light_palette: Resource = DEFAULT_LIGHT_PALETTE
@export var use_dark_mode := true
@export var base_content_size := DEFAULT_CONTENT_SIZE
@export_range(640.0, 1200.0, 20.0) var focus_mode_breakpoint := 920.0
@export var launch_fullscreen := true
@export var use_saved_dev_data := true
@export_range(0.0, 1.0, 0.01) var sfx_volume := 0.35
@export var upload_endpoint_url := ""
@export var upload_destination_name := "Configured upload endpoint"
@export_multiline var upload_usage_summary := "Submitted answers are used to preserve legitimate survey responses and support aggregate review."
@export_multiline var upload_reason_summary := "Uploads help move completed answers into a Supabase-backed collection flow for analysis and follow-up."
@export var upload_request_headers: PackedStringArray = PackedStringArray()
@export var require_upload_consent := true
@export_range(0, 100, 1) var minimum_answered_questions_for_upload := 3
@export_range(0, 3600, 1) var upload_cooldown_seconds := 45
@export_range(1, 100, 1) var upload_max_attempts_per_window := 6
@export_range(60, 86400, 1) var upload_attempt_window_seconds := 3600

var survey: SurveyDefinition
var answers: Dictionary = {}
var current_section_index := 0
var _selected_question_id := ""
var _pending_navigation_question_id := ""
var _question_views: Dictionary = {}
var _section_blocks: Dictionary = {}
var _section_headers: Dictionary = {}
var _section_question_holders: Dictionary = {}
var _section_spacers: Dictionary = {}
var _question_to_section_index: Dictionary = {}
var _question_order: Array[String] = []
var _question_filter_entries: Array[Dictionary] = []
var _filtered_question_ids: Dictionary = {}
var _active_filter_query := ""
var _last_scroll_vertical := 0.0
var _feedback_hub
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _template_dialog: FileDialog
var _template_dialog_mode := "pick"
var _pending_save_text := ""
var _pending_save_image: Image = null
var _pending_save_extension := ""
var _pending_save_label := ""
var _survey_view_mode_preference := SURVEY_VIEW_MODE_AUTO
var _focus_mode_active := false
var _focus_question_view: SurveyQuestionView
var _focus_stage_question_id := ""
var _focus_transition_tween: Tween
var _web_progress_picker_active := false
var _web_progress_picker_success_callback = null
var _web_progress_picker_error_callback = null
var _restored_session_state: Dictionary = {}
var _onboarding_completed := false
var _onboarding_mode := ""
var _preferred_topic_tag := ""
var _preferred_audience_id := ""
var _remember_onboarding_preferences := true
var _allow_local_session_cache := true
var _hover_sfx_enabled := false
var _startup_onboarding_gate_active := false
var _loaded_global_preferences: Dictionary = {}
var _summary_adjective_text := ""
var _upload_request: HTTPRequest
var _upload_in_progress := false
var _pending_upload_payload_hash := ""
var _last_upload_response_text := ""
var _last_upload_status_text := ""
var _last_upload_status_is_error := false

@onready var _background: ColorRect = $Background
@onready var _margin: MarginContainer = $Margin
@onready var _shell: HBoxContainer = $Margin/Shell
@onready var _outline_panel: SectionOutlinePanel = $Margin/Shell/OutlinePanel
@onready var _main_column: VBoxContainer = $Margin/Shell/MainColumn
@onready var _content_card: PanelContainer = $Margin/Shell/MainColumn/ContentCard
@onready var _content_stack: VBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack
@onready var _section_title_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/SectionTitleLabel
@onready var _section_description_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/SectionDescriptionLabel
@onready var _section_header_host: VBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/SectionHeaderHost
@onready var _filter_row: HBoxContainer = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow") as HBoxContainer
@onready var _filter_field: LineEdit = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow/FilterField") as LineEdit
@onready var _clear_filter_button: Button = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow/ClearFilterButton") as Button
@onready var _filter_status_label: Label = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterStatusLabel") as Label
@onready var _question_scroll: ScrollContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/QuestionScroll
@onready var _question_stack: VBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/QuestionScroll/QuestionStack
@onready var _focus_mode_shell: VBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell
@onready var _focus_header_panel: PanelContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusHeaderPanel
@onready var _focus_section_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusHeaderPanel/FocusHeaderStack/FocusSectionLabel
@onready var _focus_progress_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusHeaderPanel/FocusHeaderStack/FocusProgressLabel
@onready var _focus_segment_row: HBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusHeaderPanel/FocusHeaderStack/FocusSegmentRow
@onready var _focus_question_scroll: ScrollContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusQuestionScroll
@onready var _focus_question_stage: Control = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusQuestionScroll/FocusQuestionStage
@onready var _focus_hint_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusHintLabel
@onready var _focus_nav_row: HBoxContainer = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusNavRow
@onready var _focus_previous_button: Button = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusNavRow/FocusPreviousButton
@onready var _focus_next_button: Button = $Margin/Shell/MainColumn/ContentCard/ContentStack/FocusModeShell/FocusNavRow/FocusNextButton
@onready var _status_label: Label = $Margin/Shell/MainColumn/ContentCard/ContentStack/StatusLabel
@onready var _nav_row: HBoxContainer = $Margin/Shell/MainColumn/NavRow
@onready var _previous_button: Button = $Margin/Shell/MainColumn/NavRow/PreviousButton
@onready var _next_button: Button = $Margin/Shell/MainColumn/NavRow/NextButton
@onready var _search_overlay = $SearchOverlay
@onready var _onboarding_overlay = $OnboardingOverlay
@onready var _settings_overlay = get_node_or_null("SettingsOverlay")
@onready var _summary_overlay = get_node_or_null("SummaryOverlay")
@onready var _export_overlay = get_node_or_null("ExportOverlay")
@onready var _overlay_menu: OverlayMenu = $OverlayMenu
@onready var _menu_access_layer: CanvasLayer = $MenuAccessLayer
@onready var _menu_access_button: Button = $MenuAccessLayer/MenuAccessButton

func _ensure_optional_ui_nodes() -> void:
	_ensure_filter_ui_nodes()
	_ensure_overlay_node("SettingsOverlay", SURVEY_SETTINGS_OVERLAY_SCENE)
	_ensure_overlay_node("SummaryOverlay", SURVEY_SUMMARY_OVERLAY_SCENE)
	_ensure_overlay_node("ExportOverlay", SURVEY_EXPORT_OVERLAY_SCENE)
	_settings_overlay = get_node_or_null("SettingsOverlay")
	_summary_overlay = get_node_or_null("SummaryOverlay")
	_export_overlay = get_node_or_null("ExportOverlay")

func _ensure_overlay_node(node_name: String, scene_resource: PackedScene) -> void:
	if get_node_or_null(node_name) != null or scene_resource == null:
		return
	var overlay = scene_resource.instantiate()
	if overlay == null:
		return
	overlay.name = node_name
	add_child(overlay)

func _ensure_filter_ui_nodes() -> void:
	if _content_stack == null or _question_scroll == null:
		return

	var row: HBoxContainer = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "FilterRow"
		row.add_theme_constant_override("separation", 10)
		_content_stack.add_child(row)
		var question_scroll_index: int = _content_stack.get_children().find(_question_scroll)
		if question_scroll_index >= 0:
			_content_stack.move_child(row, question_scroll_index)

	var filter_field: LineEdit = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow/FilterField") as LineEdit
	if filter_field == null:
		filter_field = LineEdit.new()
		filter_field.name = "FilterField"
		filter_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_field.placeholder_text = "Filter questions, sections, or answer options"
		filter_field.clear_button_enabled = true
		row.add_child(filter_field)

	var clear_button: Button = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterRow/ClearFilterButton") as Button
	if clear_button == null:
		clear_button = Button.new()
		clear_button.name = "ClearFilterButton"
		clear_button.text = "Clear"
		clear_button.disabled = true
		row.add_child(clear_button)

	var status_label: Label = get_node_or_null("Margin/Shell/MainColumn/ContentCard/ContentStack/FilterStatusLabel") as Label
	if status_label == null:
		status_label = Label.new()
		status_label.name = "FilterStatusLabel"
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.text = "Filter questions by keyword, section, or answer option."
		_content_stack.add_child(status_label)
		var target_index: int = _content_stack.get_children().find(_question_scroll)
		if target_index >= 0:
			_content_stack.move_child(status_label, target_index)

	_filter_row = row
	_filter_field = filter_field
	_clear_filter_button = clear_button
	_filter_status_label = status_label

func _ready() -> void:
	_configure_window_scaling()
	survey_template_path = _resolve_startup_template_path()
	_prime_preferences_from_store()
	dark_palette = _resolved_palette_resource(dark_palette, DEFAULT_DARK_PALETTE)
	light_palette = _resolved_palette_resource(light_palette, DEFAULT_LIGHT_PALETTE)
	SurveyStyle.configure_palettes(dark_palette, light_palette, use_dark_mode)
	_ensure_optional_ui_nodes()
	_refresh_static_theme_shell()
	_configure_feedback_hub()
	_configure_save_dialog()
	_ensure_upload_request()
	_connect_actions()
	_apply_platform_capabilities()
	_wire_static_feedback()
	_load_survey()
	set_process_unhandled_input(true)

func _resolved_palette_resource(candidate: Resource, fallback: Resource) -> Resource:
	return candidate if candidate != null else fallback
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_responsive_layout()
		_sync_question_stack_width()
		call_deferred("_sync_visible_location", true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist_session()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		if _search_overlay.visible:
			_close_search_overlay()
		elif _summary_overlay != null and _summary_overlay.visible:
			_close_summary_overlay()
		elif _settings_overlay != null and _settings_overlay.visible:
			_close_settings_overlay()
		elif _export_overlay != null and _export_overlay.visible:
			_close_export_overlay()
		elif _onboarding_overlay.visible:
			_on_onboarding_close_requested()
		elif _overlay_menu.visible:
			_close_overlay_menu()
		else:
			_open_overlay_menu()
		get_viewport().set_input_as_handled()
		return
	if key_event.ctrl_pressed and key_event.keycode == KEY_K:
		if _search_overlay.visible:
			_close_search_overlay()
		else:
			if _onboarding_overlay.visible:
				_remember_onboarding_preference("search")
			_open_search_overlay()
		get_viewport().set_input_as_handled()

func _configure_window_scaling() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = base_content_size
	window.content_scale_factor = 1.0
	if launch_fullscreen and not _is_web_platform():
		window.mode = Window.MODE_FULLSCREEN

func _is_web_platform() -> bool:
	return OS.has_feature("web")

func _supports_browser_downloads() -> bool:
	return _is_web_platform() and Engine.has_singleton("JavaScriptBridge")

func _supports_browser_progress_import() -> bool:
	return _is_web_platform() and Engine.has_singleton("JavaScriptBridge")

func _supports_image_clipboard_copy() -> bool:
	return OS.has_feature("windows") and not _is_web_platform()

func _download_buffer_to_browser(buffer: PackedByteArray, file_name: String, success_message: String) -> bool:
	if buffer.is_empty() or not _supports_browser_downloads():
		return false
	JavaScriptBridge.download_buffer(buffer, file_name)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message(success_message)
	return true

func _apply_platform_capabilities() -> void:
	var allow_native_file_actions: bool = not _is_web_platform()
	if _onboarding_overlay != null and _onboarding_overlay.has_method("set_external_template_actions_enabled"):
		_onboarding_overlay.set_external_template_actions_enabled(allow_native_file_actions, allow_native_file_actions)
	if _summary_overlay != null and _summary_overlay.has_method("set_png_action_capabilities"):
		var save_label: String = "Download PNG" if _supports_browser_downloads() else "Save PNG"
		_summary_overlay.set_png_action_capabilities(_supports_image_clipboard_copy(), save_label)
func _configure_feedback_hub() -> void:
	if _feedback_hub == null:
		_feedback_hub = SURVEY_UI_FEEDBACK.new()
		add_child(_feedback_hub)
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)
	SURVEY_UI_FEEDBACK.set_hover_sfx_enabled(_hover_sfx_enabled)

func _configure_save_dialog() -> void:
	if _is_web_platform():
		_save_dialog = null
		_load_dialog = null
		_template_dialog = null
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

	_template_dialog = FileDialog.new()
	_template_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_template_dialog.title = "Choose Survey Template"
	_template_dialog.file_selected.connect(_on_template_dialog_file_selected)
	_template_dialog.canceled.connect(_on_template_dialog_canceled)
	add_child(_template_dialog)
func _ensure_upload_request() -> void:
	if _upload_request != null:
		return
	_upload_request = HTTPRequest.new()
	_upload_request.name = "ExportUploadRequest"
	_upload_request.timeout = 20.0
	_upload_request.request_completed.connect(_on_upload_request_completed)
	add_child(_upload_request)

func _wire_static_feedback() -> void:
	_wire_button_feedback(_previous_button)
	_wire_button_feedback(_next_button)
	_wire_button_feedback(_focus_previous_button)
	_wire_button_feedback(_focus_next_button)
	_wire_button_feedback(_menu_access_button)
	if _clear_filter_button != null:
		_wire_button_feedback(_clear_filter_button)

func _wire_button_feedback(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_button_hovered)
	button.pressed.connect(_on_button_pressed_feedback)

func _prime_preferences_from_store() -> void:
	_loaded_global_preferences = {}
	if not use_saved_dev_data:
		return
	_loaded_global_preferences = SURVEY_PREFERENCES_STORE.load_preferences()
	if _loaded_global_preferences.is_empty():
		return
	if _loaded_global_preferences.has("use_dark_mode"):
		use_dark_mode = bool(_loaded_global_preferences.get("use_dark_mode", use_dark_mode))
	if _loaded_global_preferences.has("sfx_volume"):
		sfx_volume = clampf(float(_loaded_global_preferences.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	if _loaded_global_preferences.has("hover_sfx_enabled"):
		_hover_sfx_enabled = bool(_loaded_global_preferences.get("hover_sfx_enabled", _hover_sfx_enabled))
	if _loaded_global_preferences.has("survey_view_mode"):
		_survey_view_mode_preference = _normalized_survey_view_mode(str(_loaded_global_preferences.get("survey_view_mode", _survey_view_mode_preference)))
	_remember_onboarding_preferences = bool(_loaded_global_preferences.get("remember_onboarding_preferences", _loaded_global_preferences.get("remember_onboarding", _remember_onboarding_preferences)))
	_allow_local_session_cache = bool(_loaded_global_preferences.get("allow_local_session_cache", _loaded_global_preferences.get("local_session_cache", _allow_local_session_cache)))
	if _remember_onboarding_preferences:
		_onboarding_completed = bool(_loaded_global_preferences.get("onboarding_completed", _onboarding_completed))
		_onboarding_mode = str(_loaded_global_preferences.get("onboarding_mode", _onboarding_mode)).strip_edges()
		_preferred_topic_tag = str(_loaded_global_preferences.get("preferred_topic_tag", _preferred_topic_tag)).strip_edges()
		_preferred_audience_id = str(_loaded_global_preferences.get("preferred_audience_id", _preferred_audience_id)).strip_edges()
	else:
		_onboarding_completed = false
		_onboarding_mode = ""
		_preferred_topic_tag = ""
		_preferred_audience_id = ""

func _resolve_startup_template_path() -> String:
	if not use_saved_dev_data:
		return survey_template_path
	var persisted_path: String = _load_persisted_template_path()
	if not persisted_path.is_empty() and FileAccess.file_exists(persisted_path):
		return persisted_path
	return survey_template_path

func _load_persisted_template_path() -> String:
	if not FileAccess.file_exists(TEMPLATE_SELECTION_STORE_PATH):
		return ""
	var file: FileAccess = FileAccess.open(TEMPLATE_SELECTION_STORE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return ""
	return str((parsed as Dictionary).get("survey_template_path", "")).strip_edges()

func _persist_selected_template_path() -> void:
	if not use_saved_dev_data:
		return
	var file: FileAccess = FileAccess.open(TEMPLATE_SELECTION_STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save selected survey template path.")
		return
	file.store_string(JSON.stringify({"survey_template_path": survey_template_path}, "\t"))
	file.close()

func _refresh_static_theme_shell() -> void:
	_apply_static_styles()
	_outline_panel.refresh_theme()
	_overlay_menu.refresh_theme()
	if _search_overlay != null:
		_search_overlay.refresh_theme()
	if _onboarding_overlay != null:
		_onboarding_overlay.refresh_theme()
	if _settings_overlay != null:
		_settings_overlay.refresh_theme()
	if _summary_overlay != null:
		_summary_overlay.refresh_theme()
	if _export_overlay != null:
		_export_overlay.refresh_theme()
	_refresh_menu_access_button()
	if is_node_ready():
		_refresh_focus_mode(true)

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _apply_static_styles() -> void:
	_background.color = SurveyStyle.BACKGROUND
	SurveyStyle.apply_panel(_content_card, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.apply_panel(_focus_header_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.ACCENT_ALT, 22, 1)
	SurveyStyle.style_heading(_section_title_label, 30)
	SurveyStyle.style_body(_section_description_label)
	SurveyStyle.style_heading(_focus_section_label, 24)
	SurveyStyle.style_caption(_focus_progress_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_caption(_focus_hint_label, SurveyStyle.TEXT_MUTED)
	if _filter_status_label != null:
		SurveyStyle.style_caption(_filter_status_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_caption(_status_label)
	if _filter_field != null:
		SurveyStyle.style_line_edit(_filter_field)
	if _clear_filter_button != null:
		SurveyStyle.apply_secondary_button(_clear_filter_button)
		_clear_filter_button.custom_minimum_size = Vector2(110, 42)
	SurveyStyle.apply_secondary_button(_previous_button)
	SurveyStyle.apply_primary_button(_next_button)
	SurveyStyle.apply_secondary_button(_focus_previous_button)
	SurveyStyle.apply_primary_button(_focus_next_button)
	SurveyStyle.apply_primary_button(_menu_access_button)
	_menu_access_button.custom_minimum_size = Vector2(92, 52)
	_section_title_label.visible = false
	_section_description_label.visible = false
	_section_header_host.visible = false
	if _filter_row != null:
		_filter_row.visible = true
	if _filter_status_label != null:
		_filter_status_label.visible = true
	_status_label.visible = false
	_refresh_menu_access_button()

func _refresh_question_view_layouts(viewport_size: Vector2) -> void:
	for value in _question_views.values():
		var view := value as SurveyQuestionView
		if view != null:
			view.refresh_responsive_layout(viewport_size)
	if _focus_question_view != null:
		_focus_question_view.refresh_responsive_layout(viewport_size)

func _connect_actions() -> void:
	_outline_panel.navigate_requested.connect(_on_outline_navigate_requested)
	_question_scroll.resized.connect(_on_question_scroll_resized)
	_focus_question_scroll.resized.connect(_on_focus_question_scroll_resized)
	if _filter_field != null:
		_filter_field.text_changed.connect(_on_filter_text_changed)
		_filter_field.text_submitted.connect(_on_filter_text_submitted)
	if _clear_filter_button != null:
		_clear_filter_button.pressed.connect(_on_clear_filter_pressed)
	var scroll_bar := _question_scroll.get_v_scroll_bar()
	if scroll_bar != null:
		scroll_bar.value_changed.connect(_on_question_scroll_value_changed)
	_previous_button.pressed.connect(_go_to_previous_section)
	_next_button.pressed.connect(_go_to_next_section)
	_focus_previous_button.pressed.connect(_on_focus_previous_pressed)
	_focus_next_button.pressed.connect(_on_focus_next_pressed)
	_menu_access_button.pressed.connect(_open_overlay_menu)
	_overlay_menu.resume_requested.connect(_close_overlay_menu)
	_overlay_menu.go_to_start_requested.connect(_go_to_start_from_overlay)
	_overlay_menu.restart_requested.connect(_clear_all_answers)
	_overlay_menu.clear_section_requested.connect(_clear_section_answers)
	_overlay_menu.jump_to_section_requested.connect(_jump_to_section_from_overlay)
	_overlay_menu.search_requested.connect(_open_search_from_overlay)
	_overlay_menu.onboarding_requested.connect(_open_onboarding_from_overlay)
	_overlay_menu.template_picker_requested.connect(_open_template_picker_from_overlay)
	_overlay_menu.settings_requested.connect(_open_settings_overlay)
	_overlay_menu.summary_requested.connect(_open_summary_overlay)
	_overlay_menu.export_requested.connect(_open_export_overlay)
	_overlay_menu.theme_mode_requested.connect(_on_theme_mode_requested)
	_overlay_menu.sfx_volume_requested.connect(_on_sfx_volume_requested)
	_overlay_menu.fill_test_answers_requested.connect(_fill_test_answers)
	_search_overlay.navigate_requested.connect(_on_search_navigate_requested)
	_search_overlay.close_requested.connect(_close_search_overlay)
	_onboarding_overlay.continue_requested.connect(_on_onboarding_continue_requested)
	_onboarding_overlay.search_requested.connect(_on_onboarding_search_requested)
	_onboarding_overlay.template_picker_requested.connect(_open_template_import_dialog_from_onboarding)
	_onboarding_overlay.template_selected_requested.connect(_on_onboarding_template_selected_requested)
	_onboarding_overlay.template_folder_requested.connect(_open_template_folder_from_onboarding)
	_onboarding_overlay.navigate_requested.connect(_on_onboarding_navigate_requested)
	_onboarding_overlay.close_requested.connect(_on_onboarding_close_requested)
	if _settings_overlay != null:
		_settings_overlay.close_requested.connect(_close_settings_overlay)
		_settings_overlay.theme_mode_requested.connect(_on_theme_mode_requested)
		_settings_overlay.sfx_volume_requested.connect(_on_sfx_volume_requested)
		_settings_overlay.hover_sfx_requested.connect(_on_hover_sfx_requested)
		_settings_overlay.remember_onboarding_requested.connect(_on_remember_onboarding_requested)
		_settings_overlay.local_session_cache_requested.connect(_on_local_session_cache_requested)
	if _summary_overlay != null:
		_summary_overlay.close_requested.connect(_close_summary_overlay)
		_summary_overlay.copy_png_requested.connect(_copy_summary_png)
		_summary_overlay.save_png_requested.connect(_save_summary_png)
		_summary_overlay.adjective_text_changed.connect(_on_summary_adjective_text_changed)
	if _export_overlay != null:
		_export_overlay.close_requested.connect(_close_export_overlay)
		_export_overlay.save_progress_requested.connect(_save_progress_json)
		_export_overlay.load_progress_requested.connect(_load_progress_json)
		_export_overlay.copy_json_requested.connect(_copy_json)
		_export_overlay.save_json_requested.connect(_save_json)
		_export_overlay.copy_csv_requested.connect(_copy_csv)
		_export_overlay.save_csv_requested.connect(_save_csv)
		_export_overlay.upload_requested.connect(_submit_export_upload)
		_export_overlay.copy_response_requested.connect(_copy_upload_response_to_clipboard)

func _load_survey() -> void:
	_close_summary_overlay()
	_close_export_overlay()
	_summary_adjective_text = ""
	_reset_upload_status(true)
	_reset_question_filter()
	survey = SURVEY_TEMPLATE_LOADER.load_from_file(survey_template_path)
	if survey == null:
		survey_template_path = ""
		survey = SampleSurvey.build()
	var cached_session: Dictionary = _load_cached_session()
	answers = _extract_dictionary(cached_session, "answers")
	_restored_session_state = {}
	var merged_preferences: Dictionary = _extract_dictionary(cached_session, "preferences")
	merged_preferences.merge(_loaded_global_preferences, true)
	var theme_changed: bool = _apply_loaded_preferences(merged_preferences)
	if theme_changed:
		_refresh_static_theme_shell()
	current_section_index = 0
	_selected_question_id = ""
	_pending_navigation_question_id = ""
	_last_scroll_vertical = 0.0
	_clear_pending_save_state()
	var recovered_count: int = answers.size()
	var recovered_message: String = ""
	if not use_saved_dev_data:
		recovered_message = "Developer override active: ignoring saved preferences and session data for this run."
	elif recovered_count > 0:
		recovered_message = "Recovered %d saved responses from your last session." % recovered_count
		if not _restored_session_state.is_empty():
			recovered_message = "%s Restored your last place in the questionnaire." % recovered_message
	_show_status_message(recovered_message)
	_populate_document()
	_outline_panel.bind_survey(survey)
	_update_responsive_layout()
	call_deferred("_apply_initial_location")

func _load_cached_session() -> Dictionary:
	if not use_saved_dev_data or survey == null or not _allow_local_session_cache:
		return {}
	var session_payload: Dictionary = SURVEY_SESSION_CACHE.load_session(survey, survey_template_path)
	if session_payload.is_empty():
		return {}
	session_payload["answers"] = _sanitize_cached_answers(_extract_dictionary(session_payload, "answers"))
	session_payload["preferences"] = _extract_dictionary(session_payload, "preferences")
	session_payload["session_state"] = _sanitize_session_state(_extract_dictionary(session_payload, "session_state"))
	return session_payload

func _extract_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _sanitize_cached_answers(cached_answers: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if survey == null:
		return sanitized
	for section in survey.sections:
		for question in section.questions:
			if cached_answers.has(question.id):
				sanitized[question.id] = _duplicate_answer_value(cached_answers.get(question.id))
	return sanitized

func _sanitize_session_state(session_state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if survey == null:
		return sanitized
	var max_section_index: int = max(survey.sections.size() - 1, 0)
	sanitized["current_section_index"] = clampi(int(session_state.get("current_section_index", 0)), 0, max_section_index)
	var selected_question_id: String = str(session_state.get("selected_question_id", "")).strip_edges()
	if selected_question_id.is_empty():
		return sanitized
	var section_index: int = _section_index_for_question_id(selected_question_id)
	if section_index == -1:
		return sanitized
	sanitized["selected_question_id"] = selected_question_id
	sanitized["current_section_index"] = section_index
	return sanitized

func _section_index_for_question_id(question_id: String) -> int:
	if question_id.is_empty() or survey == null:
		return -1
	if _question_to_section_index.has(question_id):
		return int(_question_to_section_index.get(question_id, -1))
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		for question in section.questions:
			if question.id == question_id:
				return section_index
	return -1

func _apply_loaded_preferences(preferences: Dictionary) -> bool:
	var theme_changed := false
	if preferences.has("use_dark_mode"):
		var desired_dark_mode: bool = bool(preferences.get("use_dark_mode", use_dark_mode))
		if use_dark_mode != desired_dark_mode:
			use_dark_mode = desired_dark_mode
			SurveyStyle.set_dark_mode(use_dark_mode)
			theme_changed = true
	_remember_onboarding_preferences = bool(preferences.get("remember_onboarding_preferences", preferences.get("remember_onboarding", _remember_onboarding_preferences)))
	_allow_local_session_cache = bool(preferences.get("allow_local_session_cache", preferences.get("local_session_cache", _allow_local_session_cache)))
	if _remember_onboarding_preferences:
		_onboarding_completed = bool(preferences.get("onboarding_completed", _onboarding_completed))
		_onboarding_mode = str(preferences.get("onboarding_mode", _onboarding_mode)).strip_edges()
		_preferred_topic_tag = str(preferences.get("preferred_topic_tag", _preferred_topic_tag)).strip_edges()
		_preferred_audience_id = str(preferences.get("preferred_audience_id", _preferred_audience_id)).strip_edges()
	else:
		_onboarding_completed = false
		_onboarding_mode = ""
		_preferred_topic_tag = ""
		_preferred_audience_id = ""
	if preferences.has("sfx_volume"):
		sfx_volume = clampf(float(preferences.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	if preferences.has("hover_sfx_enabled"):
		_hover_sfx_enabled = bool(preferences.get("hover_sfx_enabled", _hover_sfx_enabled))
	if preferences.has("survey_view_mode"):
		_survey_view_mode_preference = _normalized_survey_view_mode(str(preferences.get("survey_view_mode", _survey_view_mode_preference)))
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)
	SURVEY_UI_FEEDBACK.set_hover_sfx_enabled(_hover_sfx_enabled)
	return theme_changed

func _duplicate_answer_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return value

func _current_preferences() -> Dictionary:
	var preferences: Dictionary = {
		"use_dark_mode": use_dark_mode,
		"remember_onboarding_preferences": _remember_onboarding_preferences,
		"allow_local_session_cache": _allow_local_session_cache,
		"sfx_volume": snappedf(sfx_volume, 0.01),
		"hover_sfx_enabled": _hover_sfx_enabled,
		"survey_view_mode": _survey_view_mode_preference
	}
	if _remember_onboarding_preferences:
		preferences["onboarding_completed"] = _onboarding_completed
		preferences["onboarding_mode"] = _onboarding_mode
		preferences["preferred_topic_tag"] = _preferred_topic_tag
		preferences["preferred_audience_id"] = _preferred_audience_id
	return preferences

func _persist_preferences() -> void:
	if not use_saved_dev_data:
		return
	_loaded_global_preferences = _current_preferences().duplicate(true)
	if not SURVEY_PREFERENCES_STORE.save_preferences(_loaded_global_preferences):
		push_warning("Failed to save survey preferences.")

func _current_session_state() -> Dictionary:
	var state: Dictionary = {}
	if survey == null:
		return state
	state["current_section_index"] = clampi(current_section_index, 0, max(survey.sections.size() - 1, 0))
	if not _selected_question_id.is_empty():
		state["selected_question_id"] = _selected_question_id
	return state

func _persist_session() -> void:
	if not use_saved_dev_data:
		return
	_persist_preferences()
	if survey == null:
		return
	if not _allow_local_session_cache:
		SURVEY_SESSION_CACHE.clear_session(survey, survey_template_path)
		return
	if not SURVEY_SESSION_CACHE.save_session(survey, survey_template_path, answers, _current_preferences(), _current_session_state()):
		push_warning("Failed to save survey session cache.")

func _rebuild_document_preserving_state(status_message: String = "", is_error: bool = false) -> void:
	if survey == null:
		return
	var saved_scroll: int = _question_scroll.scroll_vertical
	var saved_section_index: int = current_section_index
	var saved_question_id: String = _selected_question_id
	var saved_pending_question_id: String = _pending_navigation_question_id
	var was_overlay_open: bool = _overlay_menu.visible
	_populate_document()
	var max_section_index: int = survey.sections.size() - 1
	if max_section_index < 0:
		max_section_index = 0
	current_section_index = clampi(saved_section_index, 0, max_section_index)
	_pending_navigation_question_id = saved_pending_question_id
	if not saved_question_id.is_empty() and _question_views.has(saved_question_id):
		_set_selected_question(saved_question_id)
	else:
		_set_selected_question(_first_question_id_in_section(current_section_index))
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_refresh_section_headers()
	_update_navigation_state()
	_refresh_focus_mode(true)
	call_deferred("_restore_document_state", saved_scroll, was_overlay_open)
	_refresh_summary_overlay()
	_refresh_export_overlay()
	_show_status_message(status_message, is_error)
	if not status_message.is_empty():
		print(status_message)

func _clear_all_answers() -> void:
	answers.clear()
	_clear_pending_save_state()
	_persist_session()
	_rebuild_document_preserving_state("Cleared all saved answers.")

func _clear_section_answers(section_index: int) -> void:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	var section: SurveySection = survey.sections[section_index]
	var cleared_count: int = 0
	for question in section.questions:
		if answers.has(question.id):
			answers.erase(question.id)
			cleared_count += 1
	_clear_pending_save_state()
	_persist_session()
	if cleared_count == 0:
		_show_status_message("Section %d already had no saved answers." % [section_index + 1])
		return
	_rebuild_document_preserving_state("Cleared %d saved responses from %s." % [cleared_count, section.display_title()])

func _apply_initial_location() -> void:
	var restored_state: Dictionary = _restored_session_state.duplicate(true)
	_restored_session_state.clear()
	var restored_question_id: String = str(restored_state.get("selected_question_id", "")).strip_edges()
	if not restored_question_id.is_empty():
		var restored_section_index: int = _section_index_for_question_id(restored_question_id)
		if restored_section_index != -1:
			_scroll_to_target(restored_section_index, restored_question_id)
			_show_onboarding_if_needed()
			return
	var restored_section_only: int = int(restored_state.get("current_section_index", 0))
	if survey != null and restored_section_only > 0 and restored_section_only < survey.sections.size():
		_scroll_to_target(restored_section_only)
		_show_onboarding_if_needed()
		return
	_question_scroll.scroll_vertical = 0
	_last_scroll_vertical = 0.0
	current_section_index = 0
	_set_selected_question(_first_question_id_in_section(0))
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_sync_outline_scroll_position()
	_update_navigation_state()
	_refresh_focus_mode(true)
	call_deferred("_ensure_question_scroll_top")
	_show_onboarding_if_needed()

func _ensure_question_scroll_top() -> void:
	if _question_scroll == null:
		return
	current_section_index = 0
	var first_question_id: String = _first_question_id_in_section(0)
	_pending_navigation_question_id = first_question_id
	if _focus_mode_active:
		_pending_navigation_question_id = ""
	_set_selected_question(first_question_id)
	_question_scroll.scroll_vertical = 0
	_last_scroll_vertical = 0.0
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_update_navigation_state()
	_sync_outline_scroll_position()
	_refresh_focus_mode(true)

func _populate_document() -> void:
	_clear_container(_question_stack)
	_question_views.clear()
	_section_blocks.clear()
	_section_headers.clear()
	_section_question_holders.clear()
	_section_spacers.clear()
	_question_to_section_index.clear()
	_question_order.clear()
	_question_filter_entries.clear()
	_filtered_question_ids.clear()

	if survey == null:
		return

	for section_index in range(survey.sections.size()):
		var section := survey.sections[section_index]
		var section_block := VBoxContainer.new()
		section_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_block.add_theme_constant_override("separation", 12)
		_question_stack.add_child(section_block)
		_section_blocks[section_index] = section_block

		var title_row := HBoxContainer.new()
		title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_theme_constant_override("separation", 12)
		section_block.add_child(title_row)

		var icon_host = SPRITE_ICON_HOST.new()
		icon_host.custom_minimum_size = Vector2(28, 28)
		icon_host.set_icon(SURVEY_ICON_LIBRARY.section_texture(section.icon_name), SurveyStyle.ACCENT_ALT, 24.0)
		title_row.add_child(icon_host)

		var title_label := Label.new()
		title_label.text = section.display_title(section_index)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.style_heading(title_label, 30)
		title_row.add_child(title_label)

		if not section.description.is_empty():
			var description_label := Label.new()
			description_label.text = section.description
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			SurveyStyle.style_body(description_label)
			section_block.add_child(description_label)

		if section.custom_header_scene != null:
			var header_node := section.custom_header_scene.instantiate()
			var header_control := header_node as Control
			if header_control != null:
				section_block.add_child(header_control)
				_section_headers[section_index] = header_control
				_configure_header(header_control, section)

		var question_holder := VBoxContainer.new()
		question_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_holder.add_theme_constant_override("separation", 14)
		section_block.add_child(question_holder)
		_section_question_holders[section_index] = question_holder

		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			if not answers.has(question.id) and question.default_value != null:
				answers[question.id] = question.default_value
			var view := _create_question_view(question)
			question_holder.add_child(view)
			view.answer_changed.connect(_on_answer_changed)
			view.question_selected.connect(_on_question_selected)
			view.configure(question, answers.get(question.id, question.default_value))
			_question_views[question.id] = view
			_question_to_section_index[question.id] = section_index
			_question_order.append(question.id)

		if section_index < survey.sections.size() - 1:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 10)
			_question_stack.add_child(spacer)
			_section_spacers[section_index] = spacer

	_build_question_filter_entries()
	_apply_question_filter(_active_filter_query, false)

func _build_question_filter_entries() -> void:
	_question_filter_entries.clear()
	if survey == null:
		return
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			_question_filter_entries.append({
				"section_index": section_index,
				"question_id": question.id,
				"normalized_prompt": _normalize_search_text(question.prompt),
				"normalized_section": _normalize_search_text("%s %s Section %d" % [section.title, section.description, section_index + 1]),
				"normalized_haystack": _normalize_search_text(_question_filter_haystack(section, question, section_index, question_index))
			})

func _question_filter_haystack(section: SurveySection, question: SurveyQuestion, section_index: int, question_index: int) -> String:
	var section_number := section_index + 1
	var question_number := question_index + 1
	var numbered_reference := "section %d question %d s%d q%d %d.%d" % [section_number, question_number, section_number, question_number, section_number, question_number]
	var display_reference := question.display_title(question_index)
	return "%s %s %s %s %s" % [section.display_title(section_index), section.description, display_reference, numbered_reference, question.searchable_text()]

func _reset_question_filter() -> void:
	_active_filter_query = ""
	_filtered_question_ids.clear()
	if is_node_ready():
		if _filter_field != null:
			_filter_field.text = ""
		if _clear_filter_button != null:
			_clear_filter_button.disabled = true
		if _filter_status_label != null:
			_filter_status_label.text = "Filter questions by keyword, section, or answer option."

func _clear_question_filter() -> void:
	_reset_question_filter()
	if survey != null:
		_apply_question_filter("", true)

func _on_filter_text_changed(new_text: String) -> void:
	_apply_question_filter(new_text, true)

func _on_filter_text_submitted(submitted_text: String) -> void:
	_apply_question_filter(submitted_text, true)
	if not _has_active_filter():
		return
	var first_match_id: String = _first_visible_question_id()
	if first_match_id.is_empty():
		return
	_scroll_to_target(_section_index_for_question_id(first_match_id), first_match_id)
	if _filter_field != null:
		_filter_field.grab_focus()
		_filter_field.select_all()

func _on_clear_filter_pressed() -> void:
	_clear_question_filter()
	if _filter_field != null:
		_filter_field.grab_focus()

func _apply_question_filter(raw_query: String, focus_first_match: bool = true) -> void:
	var normalized_query: String = _normalize_search_text(raw_query)
	_active_filter_query = normalized_query
	if normalized_query.is_empty():
		_filtered_question_ids.clear()
	else:
		_filtered_question_ids = _matching_question_ids_for_query(normalized_query)
	_apply_filter_visibility()
	if not is_node_ready():
		return
	if _clear_filter_button != null:
		_clear_filter_button.disabled = normalized_query.is_empty()
	if _filter_status_label != null:
		if normalized_query.is_empty():
			_filter_status_label.text = "Filter questions by keyword, section, or answer option."
		elif _filtered_question_ids.is_empty():
			_filter_status_label.text = "No questions match \"%s\"." % raw_query.strip_edges()
		else:
			_filter_status_label.text = "Showing %d matching question(s) for \"%s\"." % [_filtered_question_ids.size(), raw_query.strip_edges()]
	_sync_question_stack_width()
	if _has_active_filter():
		if focus_first_match or not _is_question_visible(_selected_question_id):
			var first_visible_question_id: String = _first_visible_question_id()
			if not first_visible_question_id.is_empty():
				current_section_index = _section_index_for_question_id(first_visible_question_id)
				_pending_navigation_question_id = first_visible_question_id
				_set_selected_question(first_visible_question_id)
				_question_scroll.scroll_vertical = 0
				_last_scroll_vertical = 0.0
			else:
				_pending_navigation_question_id = ""
	else:
		if _selected_question_id.is_empty() or not _question_views.has(_selected_question_id):
			_set_selected_question(_first_question_id_in_section(current_section_index))
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_update_navigation_state()
	if _focus_mode_active:
		_refresh_focus_mode(true)
	call_deferred("_sync_outline_scroll_position")
	call_deferred("_sync_visible_location", true)

func _apply_filter_visibility() -> void:
	if survey == null:
		return
	for section_index in range(survey.sections.size()):
		var section: SurveySection = survey.sections[section_index]
		var section_has_visible_question := false
		for question in section.questions:
			var view := _question_views.get(question.id) as Control
			if view == null:
				continue
			var is_visible: bool = _is_question_visible(question.id)
			view.visible = is_visible
			if is_visible:
				section_has_visible_question = true
		var section_block := _section_blocks.get(section_index) as Control
		if section_block != null:
			section_block.visible = section_has_visible_question
	_question_stack.queue_sort()
	_update_section_spacer_visibility()

func _update_section_spacer_visibility() -> void:
	var visible_sections: Array[int] = []
	for section_index in range(survey.sections.size()):
		var section_block := _section_blocks.get(section_index) as Control
		if section_block != null and section_block.visible:
			visible_sections.append(section_index)
	if visible_sections.is_empty():
		for spacer_value in _section_spacers.values():
			var empty_spacer := spacer_value as Control
			if empty_spacer != null:
				empty_spacer.visible = false
		return
	var last_visible_section: int = visible_sections[visible_sections.size() - 1]
	for section_index in _section_spacers.keys():
		var spacer := _section_spacers.get(section_index) as Control
		if spacer == null:
			continue
		spacer.visible = visible_sections.has(section_index) and int(section_index) != last_visible_section

func _matching_question_ids_for_query(normalized_query: String) -> Dictionary:
	var matched_ids: Dictionary = {}
	for entry in _question_filter_entries:
		if _filter_score_entry(entry, normalized_query) < 18.0:
			continue
		matched_ids[str(entry.get("question_id", ""))] = true
	return matched_ids

func _filter_score_entry(entry: Dictionary, normalized_query: String) -> float:
	var prompt_text: String = str(entry.get("normalized_prompt", ""))
	var section_text: String = str(entry.get("normalized_section", ""))
	var haystack_text: String = str(entry.get("normalized_haystack", ""))
	var score := 0.0
	if prompt_text.contains(normalized_query):
		score += 140.0
	if haystack_text.contains(normalized_query):
		score += 95.0
	if section_text.contains(normalized_query):
		score += 55.0
	var prompt_similarity: float = prompt_text.similarity(normalized_query)
	if prompt_similarity >= 0.26:
		score += prompt_similarity * 85.0
	var haystack_similarity: float = haystack_text.similarity(normalized_query)
	if haystack_similarity >= 0.22:
		score += haystack_similarity * 60.0
	var query_tokens: PackedStringArray = _tokenize_search_text(normalized_query)
	var haystack_tokens: PackedStringArray = _tokenize_search_text(haystack_text)
	for token in query_tokens:
		if haystack_tokens.has(token):
			score += 28.0
			continue
		var best_similarity: float = _best_filter_token_similarity(token, haystack_tokens)
		if best_similarity >= 0.82:
			score += best_similarity * 22.0
		elif token.length() >= 5 and best_similarity >= 0.66:
			score += best_similarity * 11.0
	return score

func _best_filter_token_similarity(query_token: String, haystack_tokens: PackedStringArray) -> float:
	var best_similarity := 0.0
	for candidate in haystack_tokens:
		if abs(candidate.length() - query_token.length()) > 4:
			continue
		var similarity: float = query_token.similarity(candidate)
		if similarity > best_similarity:
			best_similarity = similarity
	return best_similarity

func _normalize_search_text(raw_text: String) -> String:
	var normalized: String = raw_text.to_lower().strip_edges()
	for token in ["\n", "\t", ".", ",", ":", ";", "!", "?", "(", ")", "[", "]", "{", "}", "/", "\\", "-", "_", '"', "'", "|"]:
		normalized = normalized.replace(token, " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()

func _tokenize_search_text(raw_text: String) -> PackedStringArray:
	var normalized: String = _normalize_search_text(raw_text)
	if normalized.is_empty():
		return PackedStringArray()
	return PackedStringArray(normalized.split(" ", false))

func _has_active_filter() -> bool:
	return not _active_filter_query.is_empty()

func _is_question_visible(question_id: String) -> bool:
	if not _has_active_filter():
		return true
	return _filtered_question_ids.has(question_id)

func _first_visible_question_id() -> String:
	for question_id in _question_order:
		if _is_question_visible(question_id):
			return question_id
	return ""

func _first_visible_question_id_in_section(section_index: int) -> String:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return ""
	var section: SurveySection = survey.sections[section_index]
	for question in section.questions:
		if _is_question_visible(question.id):
			return question.id
	return ""

func _create_question_view(question: SurveyQuestion) -> SurveyQuestionView:
	if question.custom_view_scene != null:
		var custom_node := question.custom_view_scene.instantiate()
		var custom_view := custom_node as SurveyQuestionView
		if custom_view != null:
			return custom_view
	match question.type:
		SurveyQuestion.TYPE_NPS:
			var nps_node := SCALE_CHIPS_VIEW_SCENE.instantiate()
			var nps_view := nps_node as SurveyQuestionView
			if nps_view != null:
				return nps_view
		SurveyQuestion.TYPE_RANKED_CHOICE:
			var ranked_node := RANKED_CHOICE_VIEW_SCENE.instantiate()
			var ranked_view := ranked_node as SurveyQuestionView
			if ranked_view != null:
				return ranked_view
		SurveyQuestion.TYPE_MATRIX:
			var matrix_node := MATRIX_QUESTION_VIEW_SCENE.instantiate()
			var matrix_view := matrix_node as SurveyQuestionView
			if matrix_view != null:
				return matrix_view
	var fallback_node := DEFAULT_QUESTION_VIEW_SCENE.instantiate()
	var fallback_view := fallback_node as SurveyQuestionView
	if fallback_view != null:
		return fallback_view
	return DefaultQuestionView.new()

func _configure_header(header_instance: Control, section: SurveySection) -> void:
	if header_instance is SurveySectionHeaderView:
		(header_instance as SurveySectionHeaderView).configure_section(section, survey, answers)
	elif header_instance.has_method("configure_section"):
		header_instance.call("configure_section", section, survey, answers)

func _refresh_section_headers() -> void:
	for key in _section_headers.keys():
		var section_index := int(key)
		var header_instance := _section_headers[key] as Control
		if header_instance != null and section_index >= 0 and section_index < survey.sections.size():
			_configure_header(header_instance, survey.sections[section_index])

func _resolve_target_question_id(section_index: int, focus_question_id: String) -> String:
	if not focus_question_id.is_empty():
		return focus_question_id
	return _first_question_id_in_section(section_index)

func _first_question_id_in_section(section_index: int) -> String:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return ""
	var visible_question_id: String = _first_visible_question_id_in_section(section_index)
	if not visible_question_id.is_empty():
		return visible_question_id
	var section := survey.sections[section_index]
	if section.questions.is_empty():
		return ""
	return section.questions[0].id

func _question_definition(question_id: String) -> SurveyQuestion:
	if survey == null or question_id.is_empty():
		return null
	for section in survey.sections:
		for question in section.questions:
			if question.id == question_id:
				return question
	return null

func _question_index_within_section(section_index: int, question_id: String) -> int:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return -1
	if question_id.is_empty():
		return 0 if not survey.sections[section_index].questions.is_empty() else -1
	var questions := survey.sections[section_index].questions
	for question_index in range(questions.size()):
		if questions[question_index].id == question_id:
			return question_index
	return -1

func _visible_question_sequence() -> Array[String]:
	var question_ids: Array[String] = []
	for question_id in _question_order:
		if _is_question_visible(question_id):
			question_ids.append(question_id)
	return question_ids

func _question_type_label(kind: StringName) -> String:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_LONG_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_EMAIL:
			return "Email"
		SurveyQuestion.TYPE_DATE:
			return "Date"
		SurveyQuestion.TYPE_NUMBER:
			return "Number"
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return "Multiple choice"
		SurveyQuestion.TYPE_DROPDOWN:
			return "Dropdown"
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return "Checkbox"
		SurveyQuestion.TYPE_BOOLEAN:
			return "Yes/No"
		SurveyQuestion.TYPE_SCALE:
			return "Scale"
		SurveyQuestion.TYPE_NPS:
			return "NPS"
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return "Ranked choice"
		SurveyQuestion.TYPE_MATRIX:
			return "Matrix"
	return "Question"

func _normalized_survey_view_mode(raw_mode: String) -> String:
	var normalized: String = raw_mode.to_lower().strip_edges()
	match normalized:
		SURVEY_VIEW_MODE_SCROLL:
			return SURVEY_VIEW_MODE_SCROLL
		SURVEY_VIEW_MODE_FOCUS:
			return SURVEY_VIEW_MODE_FOCUS
	return SURVEY_VIEW_MODE_AUTO

func _current_survey_view_mode_name() -> String:
	return SURVEY_VIEW_MODE_FOCUS if _focus_mode_active else SURVEY_VIEW_MODE_SCROLL

func _set_survey_view_mode_preference(mode: String, persist: bool = true) -> void:
	var resolved_mode: String = _normalized_survey_view_mode(mode)
	if _survey_view_mode_preference == resolved_mode:
		if is_node_ready():
			_update_responsive_layout()
		return
	_survey_view_mode_preference = resolved_mode
	if is_node_ready():
		_update_responsive_layout()
	if persist:
		_persist_session()

func _should_use_focus_mode(viewport_size: Vector2) -> bool:
	match _survey_view_mode_preference:
		SURVEY_VIEW_MODE_FOCUS:
			return true
		SURVEY_VIEW_MODE_SCROLL:
			return false
	return OS.has_feature("mobile") or viewport_size.x <= focus_mode_breakpoint

func _set_focus_mode_active(enabled: bool) -> void:
	var mode_changed := _focus_mode_active != enabled
	_focus_mode_active = enabled
	if _question_scroll != null:
		_question_scroll.visible = not enabled
	if _nav_row != null:
		_nav_row.visible = not enabled
	if _filter_row != null:
		_filter_row.visible = not enabled
	if _filter_status_label != null:
		_filter_status_label.visible = not enabled
	if _focus_mode_shell != null:
		_focus_mode_shell.visible = enabled
	if not enabled:
		if mode_changed and _focus_transition_tween != null:
			_focus_transition_tween.kill()
			_focus_transition_tween = null
		if mode_changed:
			_clear_focus_question_stage()
		return
	if mode_changed:
		_refresh_focus_mode(true)
	else:
		_sync_focus_question_stage_size()
		_update_focus_navigation_state()

func _refresh_menu_access_button() -> void:
	if _menu_access_layer == null:
		return
	_menu_access_layer.visible = survey != null and (_overlay_menu == null or not _overlay_menu.visible)

func _refresh_focus_mode(force_rebuild: bool = false, transition_direction: int = 0) -> void:
	if not _focus_mode_active or _focus_mode_shell == null:
		return
	if survey == null or survey.sections.is_empty():
		_clear_focus_question_stage()
		return
	var current_question_id := _selected_question_id
	if current_question_id.is_empty() or _question_definition(current_question_id) == null or not _is_question_visible(current_question_id):
		current_question_id = _first_visible_question_id()
	if current_question_id.is_empty():
		current_question_id = _first_question_id_in_section(clampi(current_section_index, 0, max(survey.sections.size() - 1, 0)))
	if current_question_id.is_empty():
		_clear_focus_question_stage()
		_focus_section_label.text = "No question available"
		_focus_progress_label.text = ""
		_focus_hint_label.visible = false
		_focus_previous_button.disabled = true
		_focus_next_button.disabled = true
		_focus_next_button.text = "Next"
		return
	if current_question_id != _selected_question_id:
		_set_selected_question(current_question_id)
	current_section_index = _section_index_for_question_id(current_question_id)
	var section_index := clampi(current_section_index, 0, survey.sections.size() - 1)
	var section: SurveySection = survey.sections[section_index]
	var question_index: int = maxi(_question_index_within_section(section_index, current_question_id), 0)
	var question: SurveyQuestion = _question_definition(current_question_id)
	_focus_section_label.text = section.display_title(section_index)
	_focus_progress_label.text = "Question %d of %d | %s" % [question_index + 1, max(section.questions.size(), 1), _question_type_label(question.type)]
	_focus_hint_label.visible = true
	_rebuild_focus_segments(section_index, question_index)
	_update_focus_navigation_state()
	if force_rebuild or _focus_stage_question_id != current_question_id:
		_present_focus_question(current_question_id, transition_direction)
	else:
		if _focus_question_view != null:
			_focus_question_view.set_selected(true)
		_sync_focus_question_stage_size()

func _rebuild_focus_segments(section_index: int, active_question_index: int) -> void:
	_clear_container(_focus_segment_row)
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	var section: SurveySection = survey.sections[section_index]
	for question_index in range(section.questions.size()):
		var segment := PanelContainer.new()
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size = Vector2(0.0, 10.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var question: SurveyQuestion = section.questions[question_index]
		var is_answered := question.is_answer_complete(answers.get(question.id, null))
		var fill := SurveyStyle.SURFACE
		var border := SurveyStyle.BORDER
		if question_index == active_question_index:
			fill = SurveyStyle.HIGHLIGHT_GOLD
			border = SurveyStyle.HIGHLIGHT_GOLD
		elif is_answered:
			fill = SurveyStyle.ACCENT_ALT
			border = SurveyStyle.ACCENT_ALT
		SurveyStyle.apply_panel(segment, fill, border, 8, 1)
		_focus_segment_row.add_child(segment)

func _present_focus_question(question_id: String, direction: int = 0) -> void:
	var question: SurveyQuestion = _question_definition(question_id)
	if question == null:
		_clear_focus_question_stage()
		return
	if _focus_transition_tween != null:
		_focus_transition_tween.kill()
		_focus_transition_tween = null
	_cleanup_focus_question_stage(_focus_question_view)
	var new_view := _create_question_view(question)
	_focus_question_stage.add_child(new_view)
	new_view.answer_changed.connect(_on_answer_changed)
	new_view.question_selected.connect(_on_question_selected)
	new_view.configure(question, answers.get(question.id, question.default_value))
	new_view.set_selected(true)
	var old_view := _focus_question_view
	_focus_question_view = new_view
	_focus_stage_question_id = question_id
	_focus_question_scroll.scroll_vertical = 0
	_sync_focus_question_stage_size()
	call_deferred("_sync_focus_question_stage_size")
	var slide_width: float = _focus_question_stage.custom_minimum_size.x
	if slide_width <= 0.0:
		slide_width = maxf(_focus_question_scroll.size.x - 24.0, 280.0)
	_position_focus_question_view(new_view, slide_width, 0.0)
	if old_view == null or not is_instance_valid(old_view) or direction == 0:
		if old_view != null and old_view != new_view:
			old_view.queue_free()
		call_deferred("_focus_primary_focus_question_control")
		return
	_position_focus_question_view(old_view, slide_width, 0.0)
	_position_focus_question_view(new_view, slide_width, slide_width * float(direction))
	var target_offset := -slide_width * float(direction)
	_focus_transition_tween = create_tween()
	_focus_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_transition_tween.parallel().tween_property(old_view, "position:x", target_offset, 0.24)
	_focus_transition_tween.parallel().tween_property(new_view, "position:x", 0.0, 0.24)
	_focus_transition_tween.finished.connect(_on_focus_transition_finished.bind(old_view))

func _cleanup_focus_question_stage(retain_view: Control = null) -> void:
	if _focus_question_stage == null:
		return
	for child in _focus_question_stage.get_children():
		if child != retain_view:
			(child as Node).queue_free()

func _clear_focus_question_stage() -> void:
	_cleanup_focus_question_stage()
	_focus_question_view = null
	_focus_stage_question_id = ""
	if _focus_question_stage != null:
		_focus_question_stage.custom_minimum_size = Vector2(0.0, 320.0)

func _position_focus_question_view(view: SurveyQuestionView, width: float, position_x: float) -> void:
	if view == null:
		return
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.position = Vector2(position_x, 0.0)
	view.custom_minimum_size = Vector2(width, 0.0)
	view.size = Vector2(width, 0.0)
	view.reset_size()
	var view_height := maxf(maxf(view.size.y, view.get_combined_minimum_size().y), 240.0)
	view.size = Vector2(width, view_height)

func _sync_focus_question_stage_size() -> void:
	if not _focus_mode_active or _focus_question_stage == null or _focus_question_scroll == null:
		return
	var stage_width := maxf(maxf(_focus_question_scroll.size.x - 24.0, _content_card.size.x - 48.0), 280.0)
	var stage_height := maxf(_focus_question_scroll.size.y, 320.0)
	for child in _focus_question_stage.get_children():
		var view := child as SurveyQuestionView
		if view == null:
			continue
		var previous_x := view.position.x
		_position_focus_question_view(view, stage_width, previous_x)
		stage_height = maxf(stage_height, view.size.y)
	_focus_question_stage.custom_minimum_size = Vector2(stage_width, stage_height)

func _update_focus_navigation_state() -> void:
	var visible_question_ids := _visible_question_sequence()
	var current_index := visible_question_ids.find(_selected_question_id)
	if current_index == -1:
		current_index = 0
	var has_questions := not visible_question_ids.is_empty()
	_focus_previous_button.disabled = (not has_questions) or current_index <= 0
	_focus_next_button.disabled = not has_questions
	_focus_next_button.text = "Export Menu" if has_questions and current_index >= visible_question_ids.size() - 1 else "Next"

func _focus_transition_direction(target_question_id: String) -> int:
	if target_question_id.is_empty() or _selected_question_id.is_empty() or target_question_id == _selected_question_id:
		return 0
	var visible_question_ids := _visible_question_sequence()
	var current_index := visible_question_ids.find(_selected_question_id)
	var target_index := visible_question_ids.find(target_question_id)
	if current_index == -1 or target_index == -1:
		current_index = _question_order.find(_selected_question_id)
		target_index = _question_order.find(target_question_id)
	if current_index == -1 or target_index == -1:
		return 0
	return 1 if target_index > current_index else -1

func _focus_primary_focus_question_control() -> void:
	if _focus_question_view != null:
		_focus_question_view.focus_primary_control()

func _on_focus_transition_finished(old_view: SurveyQuestionView) -> void:
	if old_view != null and is_instance_valid(old_view):
		old_view.queue_free()
	_focus_transition_tween = null
	_sync_focus_question_stage_size()
	call_deferred("_focus_primary_focus_question_control")

func _on_focus_previous_pressed() -> void:
	_advance_focus_question(-1)

func _on_focus_next_pressed() -> void:
	_advance_focus_question(1)

func _advance_focus_question(step: int) -> void:
	var visible_question_ids := _visible_question_sequence()
	if visible_question_ids.is_empty():
		return
	var current_index := visible_question_ids.find(_selected_question_id)
	if current_index == -1:
		current_index = 0
	var target_index := current_index + step
	if target_index < 0:
		return
	if target_index >= visible_question_ids.size():
		_open_export_options()
		return
	var target_question_id: String = visible_question_ids[target_index]
	_scroll_to_target(_section_index_for_question_id(target_question_id), target_question_id)

func _scroll_to_target(section_index: int, question_id: String = "") -> void:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	if _has_active_filter():
		var requested_question_id: String = _resolve_target_question_id(section_index, question_id)
		if requested_question_id.is_empty() or not _is_question_visible(requested_question_id):
			_clear_question_filter()

	current_section_index = section_index
	var target_question_id := _resolve_target_question_id(section_index, question_id)
	var transition_direction := _focus_transition_direction(target_question_id)
	_pending_navigation_question_id = target_question_id
	_set_selected_question(target_question_id)
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_update_navigation_state()
	if _focus_mode_active:
		_pending_navigation_question_id = ""
		_refresh_focus_mode(false, transition_direction)
		return

	var target_control: Control = _section_blocks.get(section_index) as Control
	if not question_id.is_empty() and _question_views.has(question_id):
		target_control = _question_views[question_id] as Control
	elif target_control == null and _question_views.has(target_question_id):
		target_control = _question_views[target_question_id] as Control

	if target_control != null:
		_question_scroll.scroll_vertical = _compute_target_scroll_position(target_control)
		_last_scroll_vertical = float(_question_scroll.scroll_vertical)
		_sync_outline_scroll_position()
		call_deferred("_sync_visible_location", true)

func _compute_target_scroll_position(control: Control) -> int:
	var target_offset := _get_control_offset_y(control)
	var target_height := _get_control_height(control)
	var viewport_height := maxf(_question_scroll.size.y, 1.0)
	var desired_scroll := target_offset - (viewport_height * 0.5 - target_height * 0.5)
	var max_scroll := 0.0
	var scroll_bar := _question_scroll.get_v_scroll_bar()
	if scroll_bar != null:
		max_scroll = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	return int(clampf(desired_scroll, 0.0, max_scroll))

func _get_control_offset_y(control: Control) -> float:
	var offset := 0.0
	var current: Node = control
	while current != null and current != _question_stack:
		var current_control := current as Control
		if current_control != null:
			offset += current_control.position.y
		current = current.get_parent()
	return offset

func _get_control_height(control: Control) -> float:
	return maxf(control.size.y, control.get_combined_minimum_size().y)

func _is_control_visible_in_scroll(control: Control) -> bool:
	var scroll_top := float(_question_scroll.scroll_vertical)
	var scroll_bottom := scroll_top + _question_scroll.size.y
	var control_top := _get_control_offset_y(control)
	var control_bottom := control_top + _get_control_height(control)
	return control_bottom >= scroll_top and control_top <= scroll_bottom

func _find_midpoint_question_id() -> String:
	if survey == null:
		return ""

	var scroll_top := float(_question_scroll.scroll_vertical)
	var scroll_bottom := scroll_top + _question_scroll.size.y
	var midpoint := scroll_top + (_question_scroll.size.y * 0.5)
	var active_question_id := ""
	var fallback_question_id := ""
	var fallback_distance := INF

	for section in survey.sections:
		for question in section.questions:
			var view := _question_views.get(question.id) as Control
			if view == null or not view.visible:
				continue
			var control_top := _get_control_offset_y(view)
			var control_bottom := control_top + _get_control_height(view)
			var is_visible := control_bottom >= scroll_top and control_top <= scroll_bottom
			if is_visible and control_top <= midpoint and control_bottom >= scroll_top:
				active_question_id = question.id
			elif active_question_id.is_empty() and is_visible:
				var distance := absf(control_top - midpoint)
				if distance < fallback_distance:
					fallback_distance = distance
					fallback_question_id = question.id

	return active_question_id if not active_question_id.is_empty() else fallback_question_id

func _resolve_active_question_id() -> String:
	if not _pending_navigation_question_id.is_empty():
		var pending_question_id := _pending_navigation_question_id
		_pending_navigation_question_id = ""
		var pending_view := _question_views.get(pending_question_id) as Control
		if pending_view != null and _is_control_visible_in_scroll(pending_view):
			return pending_question_id
	if _is_question_scroll_at_end():
		return _last_question_id()
	return _find_midpoint_question_id()

func _is_question_scroll_at_end() -> bool:
	if _question_scroll == null:
		return false
	var scroll_bar := _question_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return true
	var max_scroll: float = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	if max_scroll <= 0.0:
		return true
	return float(_question_scroll.scroll_vertical) >= max_scroll - 2.0

func _clamp_scroll_resolved_question_id(question_id: String, scroll_delta: float) -> String:
	if question_id.is_empty() or _selected_question_id.is_empty() or is_zero_approx(scroll_delta) or _is_question_scroll_at_end():
		return question_id

	var current_index: int = _question_order.find(_selected_question_id)
	var resolved_index: int = _question_order.find(question_id)
	if current_index == -1 or resolved_index == -1:
		return question_id
	if abs(resolved_index - current_index) <= 1:
		return question_id

	var direction: int = 1 if scroll_delta > 0.0 else -1
	var adjacent_index: int = current_index + direction
	if adjacent_index < 0 or adjacent_index >= _question_order.size():
		return question_id

	var adjacent_question_id: String = _question_order[adjacent_index]
	var adjacent_view := _question_views.get(adjacent_question_id) as Control
	if adjacent_view != null and _is_control_visible_in_scroll(adjacent_view):
		return adjacent_question_id
	return question_id

func _last_question_id() -> String:
	if survey == null:
		return ""
	for section_index in range(survey.sections.size() - 1, -1, -1):
		var section: SurveySection = survey.sections[section_index]
		for question_index in range(section.questions.size() - 1, -1, -1):
			var question_id: String = section.questions[question_index].id
			if _is_question_visible(question_id):
				return question_id
	return ""

func _on_outline_navigate_requested(section_index: int, question_id: String) -> void:
	_scroll_to_target(section_index, question_id)

func _on_question_selected(question_id: String) -> void:
	current_section_index = int(_question_to_section_index.get(question_id, current_section_index))
	_set_selected_question(question_id)
	_outline_panel.refresh(answers, current_section_index, question_id)
	_update_navigation_state()

func _set_selected_question(question_id: String) -> void:
	_selected_question_id = question_id
	for key in _question_views.keys():
		var question_key := str(key)
		var view := _question_views[question_key] as SurveyQuestionView
		if view != null:
			view.set_selected(question_key == _selected_question_id)

func _sync_document_question_view(question_id: String) -> void:
	var view := _question_views.get(question_id) as SurveyQuestionView
	var question: SurveyQuestion = _question_definition(question_id)
	if view == null or question == null:
		return
	view.configure(question, answers.get(question_id, question.default_value))
	view.set_selected(question_id == _selected_question_id)

func _on_answer_changed(question_id: String, value: Variant) -> void:
	answers[question_id] = value
	current_section_index = int(_question_to_section_index.get(question_id, current_section_index))
	if question_id != _selected_question_id:
		_set_selected_question(question_id)
	if _focus_mode_active:
		_sync_document_question_view(question_id)
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_refresh_section_headers()
	_update_navigation_state()
	if _focus_mode_active:
		_refresh_focus_mode(false)
	_persist_session()
	_refresh_summary_overlay()
	_refresh_export_overlay()

func _on_question_scroll_resized() -> void:
	if _focus_mode_active:
		return
	_sync_question_stack_width()
	call_deferred("_sync_visible_location", true)
	call_deferred("_sync_outline_scroll_position")

func _on_focus_question_scroll_resized() -> void:
	if not _focus_mode_active:
		return
	_sync_focus_question_stage_size()

func _on_question_scroll_value_changed(value: float) -> void:
	if _focus_mode_active:
		return
	var scroll_delta: float = value - _last_scroll_vertical
	_last_scroll_vertical = value
	if not _pending_navigation_question_id.is_empty():
		_sync_visible_location()
	else:
		_sync_visible_location(false, scroll_delta)
	_sync_outline_scroll_position()

func _sync_visible_location(force: bool = false, scroll_delta: float = 0.0) -> void:
	if survey == null or survey.sections.is_empty():
		return
	if _focus_mode_active:
		_outline_panel.refresh(answers, current_section_index, _selected_question_id)
		_update_navigation_state()
		return
	if _has_active_filter() and _first_visible_question_id().is_empty():
		return

	var resolved_question_id := _resolve_active_question_id()
	if not force:
		resolved_question_id = _clamp_scroll_resolved_question_id(resolved_question_id, scroll_delta)
	if resolved_question_id.is_empty():
		return
	var resolved_section_index := int(_question_to_section_index.get(resolved_question_id, current_section_index))
	if not force and resolved_section_index == current_section_index and resolved_question_id == _selected_question_id:
		_sync_outline_scroll_position()
		return
	current_section_index = resolved_section_index
	_set_selected_question(resolved_question_id)
	_outline_panel.refresh(answers, current_section_index, _selected_question_id)
	_sync_outline_scroll_position()
	_update_navigation_state()

func _update_navigation_state() -> void:
	if survey == null or survey.sections.is_empty():
		return
	if _focus_mode_active:
		_update_focus_navigation_state()
		return
	if _has_active_filter():
		_previous_button.text = "Clear Filter"
		_previous_button.disabled = false
		_next_button.text = "Filtered View"
		_next_button.disabled = true
		return
	_previous_button.text = "Previous Section"
	_previous_button.disabled = current_section_index == 0
	_next_button.text = "Export Menu" if current_section_index == survey.sections.size() - 1 else "Next Section"
	_next_button.disabled = false

func _go_to_previous_section() -> void:
	if _has_active_filter():
		_clear_question_filter()
		return
	if current_section_index > 0:
		_scroll_to_target(current_section_index - 1)

func _go_to_next_section() -> void:
	if survey == null:
		return
	if _has_active_filter():
		return
	if current_section_index >= survey.sections.size() - 1:
		_open_export_options()
		return
	_scroll_to_target(current_section_index + 1)

func _open_overlay_menu() -> void:
	if survey == null:
		return
	_close_search_overlay()
	_close_onboarding_overlay()
	_close_settings_overlay()
	_close_summary_overlay()
	_close_export_overlay()
	_overlay_menu.open_menu(survey, current_section_index, answers, sfx_volume)
	_refresh_menu_access_button()

func _close_overlay_menu() -> void:
	_overlay_menu.close_menu()
	_refresh_menu_access_button()

func _open_search_overlay() -> void:
	if survey == null:
		return
	_close_overlay_menu()
	_close_onboarding_overlay()
	_close_settings_overlay()
	_close_summary_overlay()
	_close_export_overlay()
	_search_overlay.open_search(survey)

func _close_search_overlay() -> void:
	if _search_overlay != null:
		_search_overlay.close_search()

func _open_onboarding_overlay() -> void:
	if survey == null:
		return
	_close_overlay_menu()
	_close_search_overlay()
	_close_settings_overlay()
	_close_summary_overlay()
	_close_export_overlay()
	_onboarding_overlay.open_onboarding(survey, _preferred_topic_tag, _preferred_audience_id, survey_template_path, _available_template_summaries(), _current_survey_view_mode_name())

func _close_onboarding_overlay() -> void:
	if _onboarding_overlay != null:
		_onboarding_overlay.close_onboarding()
	_finish_startup_onboarding_gate()

func _open_settings_overlay() -> void:
	if _settings_overlay == null:
		return
	_close_overlay_menu()
	_close_search_overlay()
	_close_onboarding_overlay()
	_close_summary_overlay()
	_close_export_overlay()
	_settings_overlay.open_settings(use_dark_mode, sfx_volume, _hover_sfx_enabled, _remember_onboarding_preferences, _allow_local_session_cache)

func _close_settings_overlay() -> void:
	if _settings_overlay != null:
		_settings_overlay.close_settings()

func _open_summary_overlay() -> void:
	if survey == null or _summary_overlay == null:
		return
	_close_overlay_menu()
	_close_search_overlay()
	_close_onboarding_overlay()
	_close_settings_overlay()
	_close_export_overlay()
	_summary_overlay.open_summary(_build_summary_data(), _summary_adjective_text)

func _close_summary_overlay() -> void:
	if _summary_overlay != null:
		_summary_overlay.close_summary()

func _open_export_overlay() -> void:
	if survey == null or _export_overlay == null:
		return
	_close_overlay_menu()
	_close_search_overlay()
	_close_onboarding_overlay()
	_close_settings_overlay()
	_close_summary_overlay()
	_export_overlay.open_export_menu(_build_export_overlay_state())

func _close_export_overlay() -> void:
	if _export_overlay != null:
		_export_overlay.close_export_menu()

func _refresh_export_overlay() -> void:
	if _export_overlay == null or not _export_overlay.visible:
		return
	_export_overlay.update_state(_build_export_overlay_state())

func _upload_readiness_state() -> Dictionary:
	if survey == null:
		return {
			"ok": false,
			"message": "Load a survey before preparing an upload."
		}
	if _upload_in_progress:
		return {
			"ok": false,
			"message": "An upload is already in progress."
		}
	if not _is_upload_endpoint_configured():
		return {
			"ok": false,
			"message": "Server upload is not configured for this build."
		}
	var upload_package: Dictionary = _build_upload_package()
	if upload_package.is_empty():
		return {
			"ok": false,
			"message": "Unable to prepare a sanitized upload package yet."
		}
	var audit: Dictionary = upload_package.get("audit", {}) as Dictionary
	if not bool(audit.get("ok", false)):
		return {
			"ok": false,
			"message": str(audit.get("message", "Upload blocked by client-side checks.")).strip_edges()
		}
	var stats: Dictionary = upload_package.get("stats", {}) as Dictionary
	var valid_response_count: int = int(stats.get("valid_response_count", 0))
	var sections_with_responses_count: int = int(stats.get("sections_with_responses_count", 0))
	return {
		"ok": true,
		"message": "Ready to submit %d answer(s) across %d section(s)." % [valid_response_count, sections_with_responses_count]
	}
func _build_export_overlay_state() -> Dictionary:
	var readiness: Dictionary = _upload_readiness_state()
	var survey_title: String = survey.title if survey != null else ""
	var web_mode: bool = _is_web_platform()
	var browser_downloads: bool = _supports_browser_downloads()
	var browser_progress_import: bool = _supports_browser_progress_import()
	var progress_summary := "Save or load the full progress bundle, including local settings and where you left off."
	if web_mode:
		progress_summary = "Download the full progress bundle or import a saved progress JSON from your device with the browser file picker."
	var answer_summary := "Copy or save answer-only exports for manual review, debugging, or offline analysis."
	if browser_downloads:
		answer_summary = "Copy answer-only exports to the clipboard or download them directly from the browser."
	return {
		"survey_title": survey_title,
		"progress_summary": progress_summary,
		"answer_summary": answer_summary,
		"save_progress_enabled": true,
		"load_progress_enabled": browser_progress_import if web_mode else true,
		"load_progress_unavailable_reason": "This browser build cannot open the file picker because JavaScript bridge support is unavailable." if web_mode and not browser_progress_import else "",
		"save_progress_label": "Download Progress JSON" if browser_downloads else "Save Progress JSON",
		"load_progress_label": "Import Progress JSON" if web_mode else "Load Progress JSON",
		"save_json_label": "Download JSON" if browser_downloads else "Save JSON",
		"save_csv_label": "Download CSV" if browser_downloads else "Save CSV",
		"upload_destination_name": upload_destination_name.strip_edges(),
		"upload_destination_url": upload_endpoint_url.strip_edges(),
		"upload_usage_summary": upload_usage_summary.strip_edges(),
		"upload_reason_summary": upload_reason_summary.strip_edges(),
		"upload_metadata_summary": "Spam protection metadata includes an anonymous install ID, upload timestamps, answer counts, and a payload hash for duplicate suppression.",
		"upload_ready": bool(readiness.get("ok", false)),
		"upload_ready_message": str(readiness.get("message", "")).strip_edges(),
		"upload_busy": _upload_in_progress,
		"upload_status_text": _last_upload_status_text if not _last_upload_status_text.is_empty() else "Ready when you are.",
		"upload_status_error": _last_upload_status_is_error,
		"upload_response_text": _last_upload_response_text,
		"consent_required": require_upload_consent
	}
func _build_upload_package() -> Dictionary:
	if survey == null:
		return {}
	var install_id: String = SURVEY_UPLOAD_AUDIT_STORE.get_install_id()
	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(survey, survey_template_path, answers, _build_summary_data(), install_id)
	if upload_package.is_empty():
		return {}
	var stats: Dictionary = upload_package.get("stats", {}) as Dictionary
	var total_question_count: int = max(int(stats.get("total_question_count", 0)), 0)
	var min_required_answers: int = min(max(minimum_answered_questions_for_upload, 0), total_question_count)
	var audit: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		str(upload_package.get("payload_hash", "")).strip_edges(),
		int(stats.get("valid_response_count", 0)),
		min_required_answers,
		upload_cooldown_seconds,
		upload_max_attempts_per_window,
		upload_attempt_window_seconds
	)
	upload_package["min_required_answers"] = min_required_answers
	upload_package["audit"] = audit
	return upload_package

func _submit_export_upload() -> void:
	if survey == null or _export_overlay == null:
		return
	if _upload_in_progress:
		return
	if require_upload_consent and not _export_overlay.current_upload_consent():
		_last_upload_status_text = "Please confirm consent before submitting your answers to the server."
		_last_upload_status_is_error = true
		_refresh_export_overlay()
		_show_status_message(_last_upload_status_text, true)
		return
	if not _is_upload_endpoint_configured():
		_last_upload_status_text = "Server upload is not configured for this build."
		_last_upload_status_is_error = true
		_refresh_export_overlay()
		_show_status_message(_last_upload_status_text, true)
		return
	var upload_package: Dictionary = _build_upload_package()
	if upload_package.is_empty():
		_last_upload_status_text = "Unable to prepare the upload payload."
		_last_upload_status_is_error = true
		_refresh_export_overlay()
		_show_status_message(_last_upload_status_text, true)
		return
	var audit: Dictionary = upload_package.get("audit", {}) as Dictionary
	if not bool(audit.get("ok", false)):
		_last_upload_status_text = str(audit.get("message", "Upload blocked by client-side checks.")).strip_edges()
		_last_upload_status_is_error = true
		_refresh_export_overlay()
		_show_status_message(_last_upload_status_text, true)
		return
	var payload_text: String = str(upload_package.get("json", ""))
	if payload_text.is_empty():
		_last_upload_status_text = "The upload payload was empty after sanitization."
		_last_upload_status_is_error = true
		_refresh_export_overlay()
		_show_status_message(_last_upload_status_text, true)
		return
	_ensure_upload_request()
	_upload_in_progress = true
	_pending_upload_payload_hash = str(upload_package.get("payload_hash", "")).strip_edges()
	_last_upload_status_text = "Submitting survey answers to %s..." % (upload_destination_name.strip_edges() if not upload_destination_name.strip_edges().is_empty() else upload_endpoint_url.strip_edges())
	_last_upload_status_is_error = false
	_last_upload_response_text = ""
	_refresh_export_overlay()
	_show_status_message(_last_upload_status_text)
	var request_error: Error = _upload_request.request(upload_endpoint_url.strip_edges(), _configured_upload_headers(), HTTPClient.METHOD_POST, payload_text)
	if request_error != OK:
		_upload_in_progress = false
		var failure_text: String = "Failed to start the upload request (%s)." % error_string(request_error)
		_last_upload_status_text = failure_text
		_last_upload_status_is_error = true
		_last_upload_response_text = failure_text
		SURVEY_UPLOAD_AUDIT_STORE.record_attempt(_pending_upload_payload_hash, false, 0, failure_text)
		_pending_upload_payload_hash = ""
		_refresh_export_overlay()
		_show_status_message(failure_text, true)

func _copy_upload_response_to_clipboard() -> void:
	if _last_upload_response_text.strip_edges().is_empty():
		_show_status_message("No server response is available to copy yet.", true)
		return
	DisplayServer.clipboard_set(_last_upload_response_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("Server response copied to the clipboard.")

func _configured_upload_headers() -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	for raw_header in upload_request_headers:
		var header_text: String = str(raw_header).strip_edges()
		if header_text.is_empty():
			continue
		if header_text.to_lower().begins_with("content-type:"):
			continue
		headers.append(header_text)
	return headers

func _is_upload_endpoint_configured() -> bool:
	return not upload_endpoint_url.strip_edges().is_empty()

func _format_upload_response_body(body_text: String) -> String:
	var trimmed_body: String = body_text.strip_edges()
	if trimmed_body.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(trimmed_body)
	if parsed is Dictionary or parsed is Array:
		return JSON.stringify(parsed, "\t")
	return trimmed_body

func _format_upload_response(result: int, response_code: int, headers: PackedStringArray, body_text: String) -> String:
	var lines: Array[String] = []
	lines.append("Result: %s" % _http_request_result_label(result))
	lines.append("HTTP Status: %d" % response_code)
	if not headers.is_empty():
		lines.append("")
		lines.append("Headers:")
		for header in headers:
			lines.append(str(header))
	var formatted_body: String = _format_upload_response_body(body_text)
	if not formatted_body.is_empty():
		lines.append("")
		lines.append("Body:")
		lines.append(formatted_body)
	return "\n".join(lines).strip_edges()

func _http_request_result_label(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Body size limit exceeded"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "Body decompress failed"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Cannot write download file"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Redirect limit reached"
		HTTPRequest.RESULT_TIMEOUT:
			return "Timeout"
	return "Unknown result"

func _on_upload_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_upload_in_progress = false
	var body_text: String = body.get_string_from_utf8()
	var response_text: String = _format_upload_response(result, response_code, headers, body_text)
	var accepted: bool = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	_last_upload_response_text = response_text
	_last_upload_status_is_error = not accepted
	if accepted:
		_last_upload_status_text = "Upload accepted by the server."
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message(_last_upload_status_text)
	else:
		_last_upload_status_text = "Upload failed or was rejected by the server."
		_show_status_message(_last_upload_status_text, true)
	SURVEY_UPLOAD_AUDIT_STORE.record_attempt(_pending_upload_payload_hash, accepted, response_code, _last_upload_status_text)
	_pending_upload_payload_hash = ""
	_refresh_export_overlay()

func _reset_upload_status(clear_response: bool = false) -> void:
	_upload_in_progress = false
	_pending_upload_payload_hash = ""
	_last_upload_status_text = ""
	_last_upload_status_is_error = false
	if clear_response:
		_last_upload_response_text = ""

func _set_survey_shell_visible(visible: bool) -> void:
	if _shell != null:
		_shell.visible = visible

func _finish_startup_onboarding_gate() -> void:
	if not _startup_onboarding_gate_active:
		return
	_startup_onboarding_gate_active = false
	_set_survey_shell_visible(true)

func _show_onboarding_if_needed() -> void:
	if survey == null:
		return
	if _onboarding_completed:
		_startup_onboarding_gate_active = false
		_set_survey_shell_visible(true)
		return
	_startup_onboarding_gate_active = true
	_set_survey_shell_visible(false)
	_open_onboarding_overlay()

func _remember_onboarding_preference(mode: String = "") -> void:
	_onboarding_completed = _remember_onboarding_preferences
	if not _remember_onboarding_preferences:
		_onboarding_mode = ""
		_preferred_topic_tag = ""
		_preferred_audience_id = ""
		_persist_session()
		return
	if not mode.is_empty():
		_onboarding_mode = mode
	var selected_topic_tag: String = str(_onboarding_overlay.current_topic_tag()).strip_edges()
	if not selected_topic_tag.is_empty():
		_preferred_topic_tag = selected_topic_tag
	var selected_audience_id: String = str(_onboarding_overlay.current_audience_id()).strip_edges()
	if not selected_audience_id.is_empty():
		_preferred_audience_id = selected_audience_id
	_persist_session()

func _build_summary_data() -> Dictionary:
	if survey == null:
		return {}
	return SURVEY_SUMMARY_ANALYZER.build_summary(survey, answers)

func _refresh_summary_overlay() -> void:
	if _summary_overlay == null or not _summary_overlay.visible:
		return
	_summary_overlay.update_summary(_build_summary_data(), _summary_adjective_text)

func _on_summary_adjective_text_changed(text: String) -> void:
	_summary_adjective_text = text.strip_edges()

func _copy_summary_png() -> void:
	if not _supports_image_clipboard_copy():
		var unavailable_text := "PNG clipboard copy is only available in the desktop Windows build right now."
		if _supports_browser_downloads():
			unavailable_text = "PNG clipboard copy is not available in the browser build. Use Download PNG instead."
		_show_status_message(unavailable_text, true)
		return
	var image: Image = await _summary_overlay.capture_summary_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Unable to build the opinion summary PNG.", true)
		return
	if _copy_image_to_clipboard(image, "opinion_summary_clipboard.png"):
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message("Opinion summary PNG copied to the clipboard.")
		return
	_show_status_message("Failed to copy the opinion summary PNG to the clipboard.", true)
func _save_summary_png() -> void:
	var image: Image = await _summary_overlay.capture_summary_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Unable to build the opinion summary PNG.", true)
		return
	_prompt_save_image(image, "png", "Opinion summary PNG", "Save Opinion Summary PNG", SurveyExporter.suggested_filename("%s_summary" % survey.id, "png"))

func _prompt_save_image(image: Image, extension: String, label: String, dialog_title: String, suggested_file: String) -> void:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Nothing available to save for %s." % label, true)
		return
	if _supports_browser_downloads() and extension.to_lower() == "png":
		var png_buffer: PackedByteArray = image.save_png_to_buffer()
		if _download_buffer_to_browser(png_buffer, suggested_file, "%s download started." % label):
			return
		_show_status_message("Failed to start a browser download for %s." % label, true)
		return
	if _save_dialog == null:
		_show_status_message("Saving %s is not available in this build." % label, true)
		return
	_pending_save_text = ""
	_pending_save_image = image
	_pending_save_extension = extension
	_pending_save_label = label
	_save_dialog.title = dialog_title
	_save_dialog.clear_filters()
	if extension.to_lower() == "png":
		_save_dialog.add_filter("*.png", "PNG Files")
	_save_dialog.current_file = suggested_file
	_save_dialog.popup_centered_ratio(0.75)
func _copy_image_to_clipboard(image: Image, temp_file_name: String) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	if not _supports_image_clipboard_copy():
		return false
	var temp_path: String = _temporary_export_path(temp_file_name)
	if temp_path.is_empty():
		return false
	if image.save_png(temp_path) != OK:
		return false
	var escaped_path: String = temp_path.replace("'", "''")
	var command: String = "$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $image = $null; $stream = [System.IO.File]::OpenRead('%s'); try { $image = [System.Drawing.Image]::FromStream($stream); [System.Windows.Forms.Clipboard]::SetImage($image) } finally { if ($image -ne $null) { $image.Dispose() }; $stream.Dispose() }" % escaped_path
	var output: Array = []
	var exit_code: int = OS.execute("powershell.exe", PackedStringArray(["-NoProfile", "-STA", "-Command", command]), output, true)
	return exit_code == 0

func _temporary_export_path(file_name: String) -> String:
	var export_dir: String = ProjectSettings.globalize_path("user://exports")
	var ensure_error: Error = DirAccess.make_dir_recursive_absolute(export_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(export_dir):
		return ""
	return "%s/%s" % [export_dir.trim_suffix("/"), file_name]

func _open_export_options() -> void:
	_open_export_overlay()

func _go_to_start_from_overlay() -> void:
	_close_overlay_menu()
	_scroll_to_target(0)

func _jump_to_section_from_overlay(section_index: int) -> void:
	_close_overlay_menu()
	_scroll_to_target(section_index)

func _open_search_from_overlay() -> void:
	_open_search_overlay()

func _open_onboarding_from_overlay() -> void:
	_close_overlay_menu()
	_open_onboarding_overlay()

func _open_template_picker_from_overlay() -> void:
	_close_overlay_menu()
	if _is_web_platform():
		_show_status_message("Browser builds switch survey templates from Section Crossroads. Opening it now.")
		_open_onboarding_overlay()
		return
	_open_template_picker_dialog("pick")
func _on_onboarding_continue_requested(view_mode: String = SURVEY_VIEW_MODE_SCROLL) -> void:
	_set_survey_view_mode_preference(view_mode, false)
	_remember_onboarding_preference("explore")
	_close_onboarding_overlay()

func _on_onboarding_search_requested() -> void:
	_remember_onboarding_preference("search")
	_close_onboarding_overlay()
	_open_search_overlay()

func _on_onboarding_template_selected_requested(template_path: String) -> void:
	_load_template_from_path(template_path, true)

func _open_template_folder_from_onboarding() -> void:
	if _is_web_platform():
		_show_status_message("Browser builds cannot open a local template folder. Use the bundled templates in Section Crossroads instead.", true)
		return
	var folder_path: String = ProjectSettings.globalize_path(SURVEY_TEMPLATE_LOADER.user_template_directory())
	var ensure_error: Error = DirAccess.make_dir_recursive_absolute(folder_path)
	if ensure_error != OK:
		_show_status_message("Failed to prepare the template folder.", true)
		return
	var open_error: Error = OS.shell_open(folder_path)
	if open_error != OK:
		_show_status_message("Failed to open the template folder.", true)
		return
	_show_status_message("Opened the survey template folder.")
func _on_onboarding_navigate_requested(section_index: int, question_id: String) -> void:
	var mode: String = str(_onboarding_overlay.current_mode_name()).strip_edges()
	_remember_onboarding_preference(mode if not mode.is_empty() else "guided")
	_close_onboarding_overlay()
	_scroll_to_target(section_index, question_id)

func _on_onboarding_close_requested() -> void:
	_remember_onboarding_preference("explore")
	_close_onboarding_overlay()

func _on_search_navigate_requested(section_index: int, question_id: String) -> void:
	_scroll_to_target(section_index, question_id)

func _restart_survey() -> void:
	_clear_all_answers()

func _available_template_summaries() -> Array[Dictionary]:
	return SURVEY_TEMPLATE_LOADER.list_available_templates()

func _open_template_import_dialog_from_onboarding() -> void:
	if _is_web_platform():
		_show_status_message("Importing template files is disabled in the browser build. Use the bundled templates in Section Crossroads instead.", true)
		return
	_open_template_picker_dialog("import")
func _open_template_picker_dialog(mode: String) -> void:
	if _is_web_platform():
		_show_status_message("File-based template picking is disabled in the browser build.", true)
		return
	if _template_dialog == null:
		return
	_template_dialog_mode = mode
	_template_dialog.title = "Import Survey Template" if mode == "import" else "Choose Survey Template"
	_template_dialog.clear_filters()
	_template_dialog.add_filter("*.json", "JSON Files")
	_template_dialog.current_path = _template_dialog_start_path()
	_template_dialog.popup_centered_ratio(0.8)
func _template_dialog_start_path() -> String:
	var dialog_path: String = survey_template_path
	if dialog_path.is_empty():
		dialog_path = SURVEY_TEMPLATE_LOADER.built_in_template_directory()
	if dialog_path.begins_with("res://") or dialog_path.begins_with("user://"):
		return ProjectSettings.globalize_path(dialog_path)
	return dialog_path

func _normalize_template_path_input(raw_path: String) -> String:
	var requested_path: String = raw_path.strip_edges()
	if requested_path.is_empty():
		return ""
	var project_res_path: String = ProjectSettings.globalize_path("res://")
	var project_user_path: String = ProjectSettings.globalize_path("user://")
	if requested_path.begins_with(project_res_path):
		return ProjectSettings.localize_path(requested_path)
	if requested_path.begins_with(project_user_path):
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
	var text_value: String = str(value).strip_edges()
	if not text_value.is_empty():
		messages.append(text_value)
	return messages

func _load_template_from_path(raw_path: String, reopen_onboarding: bool = true) -> bool:
	var requested_path: String = _normalize_template_path_input(raw_path)
	if requested_path.is_empty():
		_show_status_message("No survey template was selected.", true)
		return false
	var summary: Dictionary = SURVEY_TEMPLATE_LOADER.describe_template_file(requested_path)
	if not bool(summary.get("ok", false)):
		var errors: PackedStringArray = _messages_from_variant(summary.get("errors", PackedStringArray()))
		var error_text: String = "Failed to load survey template %s." % requested_path.get_file()
		if not errors.is_empty():
			error_text = errors[0]
		_show_status_message(error_text, true)
		return false
	survey_template_path = requested_path
	_persist_selected_template_path()
	_load_survey()
	var warnings: PackedStringArray = _messages_from_variant(summary.get("warnings", PackedStringArray()))
	var status_message: String = "Loaded survey template %s." % requested_path.get_file()
	if not warnings.is_empty():
		status_message = "%s %d template warning(s) were normalized during load." % [status_message, warnings.size()]
	_show_status_message(status_message)
	if reopen_onboarding:
		call_deferred("_open_onboarding_overlay")
	return true

func _import_template_from_path(raw_path: String) -> bool:
	var requested_path: String = _normalize_template_path_input(raw_path)
	if requested_path.is_empty():
		_show_status_message("No survey template was selected.", true)
		return false
	var report: Dictionary = SURVEY_TEMPLATE_LOADER.import_template_file(requested_path)
	if not bool(report.get("ok", false)):
		var errors: PackedStringArray = _messages_from_variant(report.get("errors", PackedStringArray()))
		var error_text: String = "Failed to import survey template %s." % requested_path.get_file()
		if not errors.is_empty():
			error_text = errors[0]
		_show_status_message(error_text, true)
		return false
	var imported_path: String = str(report.get("path", "")).strip_edges()
	if imported_path.is_empty():
		_show_status_message("The survey template import did not produce a usable file.", true)
		return false
	return _load_template_from_path(imported_path, true)

func _save_progress_json() -> void:
	if survey == null:
		_show_status_message("No survey is loaded to save.", true)
		return
	var progress_text: String = SURVEY_SAVE_BUNDLE.build_json_text(
		survey,
		survey_template_path,
		answers,
		_current_preferences(),
		_current_session_state()
	)
	if progress_text.is_empty():
		_show_status_message("Unable to build survey progress.", true)
		return
	_prompt_save_text(
		progress_text,
		"json",
		"Survey progress",
		"Save Survey Progress",
		SURVEY_SAVE_BUNDLE.suggested_filename(survey.id)
	)

func _load_progress_json() -> void:
	if _is_web_platform():
		if not _open_web_progress_import_picker():
			_show_status_message("This browser build could not open a progress file picker.", true)
		return
	if _load_dialog == null:
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
	var export_text: String = _build_export_text(format)
	if export_text.is_empty():
		_show_status_message("Unable to build %s export." % _export_label(format), true)
		return
	DisplayServer.clipboard_set(export_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("%s copied to clipboard." % _export_label(format))
	print("%s copied to clipboard." % _export_label(format))

func _prompt_save_export(format: String) -> void:
	var export_text: String = _build_export_text(format)
	if export_text.is_empty():
		_show_status_message("Unable to build %s export." % _export_label(format), true)
		return
	_prompt_save_text(export_text, format, _export_label(format), "Save %s Export" % _export_label(format), SurveyExporter.suggested_filename(survey.id, format))

func _prompt_save_text(contents: String, extension: String, label: String, dialog_title: String, suggested_file: String) -> void:
	if contents.is_empty():
		_show_status_message("Nothing available to save for %s." % label, true)
		return
	if _supports_browser_downloads():
		if _download_buffer_to_browser(contents.to_utf8_buffer(), suggested_file, "%s download started." % label):
			return
		_show_status_message("Failed to start a browser download for %s." % label, true)
		return
	if _save_dialog == null:
		_show_status_message("Saving %s is not available in this build." % label, true)
		return
	_pending_save_text = contents
	_pending_save_image = null
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
			return SurveyExporter.build_json_text(survey, answers)
		EXPORT_FORMAT_CSV:
			return SurveyExporter.build_csv_text(survey, answers)
	return ""

func _export_label(format: String) -> String:
	return format.to_upper()

func _on_save_dialog_file_selected(path: String) -> void:
	var target_path: String = path
	if not _pending_save_extension.is_empty() and target_path.get_extension().to_lower() != _pending_save_extension:
		target_path = "%s.%s" % [target_path, _pending_save_extension]
	var save_ok := false
	if _pending_save_image != null:
		save_ok = SurveyExporter.save_image_file(target_path, _pending_save_image)
	else:
		save_ok = SurveyExporter.save_text_file(target_path, _pending_save_text)
	if save_ok:
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message("%s saved to %s" % [_pending_save_label, target_path])
		print("%s saved to %s" % [_pending_save_label, target_path])
	else:
		_show_status_message("Failed to save %s." % _pending_save_label, true)
	_clear_pending_save_state()

func _on_save_dialog_canceled() -> void:
	_clear_pending_save_state()

func _on_load_dialog_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_status_message("Failed to open %s." % path.get_file(), true)
		return
	_apply_loaded_progress_text(file.get_as_text(), path.get_file())

func _apply_loaded_progress_text(progress_text: String, source_name: String) -> void:
	var payload: Dictionary = SURVEY_SAVE_BUNDLE.parse_json_text(progress_text)
	if payload.is_empty():
		_show_status_message("No compatible survey data was found in %s." % source_name, true)
		return
	_apply_loaded_progress_payload(payload, source_name)

func _apply_loaded_progress_payload(payload: Dictionary, source_name: String) -> void:
	var loaded_answers: Dictionary = _sanitize_cached_answers(_extract_dictionary(payload, "answers"))
	var loaded_preferences: Dictionary = _extract_dictionary(payload, "preferences")
	var loaded_session_state: Dictionary = _sanitize_session_state(_extract_dictionary(payload, "session_state"))
	var has_preferences: bool = not loaded_preferences.is_empty()
	var has_session_state: bool = not loaded_session_state.is_empty()
	if loaded_answers.is_empty() and not has_preferences and not has_session_state:
		_show_status_message("No matching survey answers were found in %s." % source_name, true)
		return
	answers = loaded_answers
	_restored_session_state = loaded_session_state
	var theme_changed: bool = _apply_loaded_preferences(loaded_preferences)
	if theme_changed:
		_refresh_static_theme_shell()
	current_section_index = 0
	_selected_question_id = ""
	_pending_navigation_question_id = ""
	_last_scroll_vertical = 0.0
	_populate_document()
	_outline_panel.bind_survey(survey)
	_update_responsive_layout()
	call_deferred("_apply_initial_location")
	_persist_session()
	_refresh_summary_overlay()
	_refresh_export_overlay()
	var loaded_parts: Array[String] = []
	if not loaded_answers.is_empty():
		loaded_parts.append("restored %d answers" % loaded_answers.size())
	if has_preferences:
		loaded_parts.append("applied saved preferences")
	if has_session_state:
		loaded_parts.append("restored your place")
	_show_status_message("Loaded %s from %s." % [", ".join(loaded_parts), source_name])

func _on_load_dialog_canceled() -> void:
	return

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
	window.__surveyProgressImportSuccess = _web_progress_picker_success_callback
	window.__surveyProgressImportError = _web_progress_picker_error_callback
	_web_progress_picker_active = true
	JavaScriptBridge.eval("""
		(function () {
			const success = window.__surveyProgressImportSuccess;
			const failure = window.__surveyProgressImportError;
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
	var target_name: String = file_name if not file_name.is_empty() else "the selected progress file"
	var error_text := "Failed to import %s." % target_name
	if not message.is_empty():
		error_text = "%s %s" % [error_text, message]
	_show_status_message(error_text, true)

func _clear_web_progress_import_callbacks() -> void:
	_web_progress_picker_active = false
	if _supports_browser_progress_import():
		var window = JavaScriptBridge.get_interface("window")
		if window != null:
			window.__surveyProgressImportSuccess = null
			window.__surveyProgressImportError = null
	_web_progress_picker_success_callback = null
	_web_progress_picker_error_callback = null

func _on_template_dialog_file_selected(path: String) -> void:
	if _template_dialog_mode == "import":
		_import_template_from_path(path)
		return
	_load_template_from_path(path, true)

func _on_template_dialog_canceled() -> void:
	return

func _clear_pending_save_state() -> void:
	_pending_save_text = ""
	_pending_save_image = null
	_pending_save_extension = ""
	_pending_save_label = ""

func _fill_test_answers() -> void:
	if survey == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var filled_count: int = 0
	for section in survey.sections:
		for question in section.questions:
			answers[question.id] = _generate_random_answer(question, rng)
			filled_count += 1
	_persist_session()
	_rebuild_document_preserving_state("Filled %d questions with generated test answers." % filled_count)

func _generate_random_answer(question: SurveyQuestion, rng: RandomNumberGenerator) -> Variant:
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return _random_short_text_answer(question, rng)
		SurveyQuestion.TYPE_LONG_TEXT:
			return _random_long_text_answer(question, rng)
		SurveyQuestion.TYPE_EMAIL:
			return "tester_%03d@example.com" % rng.randi_range(1, 999)
		SurveyQuestion.TYPE_DATE:
			return _random_date_answer(rng)
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			return _random_option(question.options, rng)
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return _random_multi_choice_answer(question.options, rng)
		SurveyQuestion.TYPE_BOOLEAN:
			return rng.randf() >= 0.5
		SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			return _random_numeric_answer(question.min_value, question.max_value, question.step, rng)
		SurveyQuestion.TYPE_NUMBER:
			return _random_number_answer(question, rng)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return _random_ranked_choice_answer(question.options, rng)
		SurveyQuestion.TYPE_MATRIX:
			return _random_matrix_answer(question, rng)
	return _random_short_text_answer(question, rng)

func _random_short_text_answer(question: SurveyQuestion, rng: RandomNumberGenerator) -> String:
	var token: int = rng.randi_range(100, 999)
	return "%s sample %d" % [_question_stub(question), token]

func _random_long_text_answer(question: SurveyQuestion, rng: RandomNumberGenerator) -> String:
	var token: int = rng.randi_range(100, 999)
	return "%s generated response %d for export verification." % [_question_stub(question), token]

func _question_stub(question: SurveyQuestion) -> String:
	var prompt_text: String = question.prompt.strip_edges()
	if prompt_text.is_empty():
		return "Question"
	var fragments: PackedStringArray = prompt_text.split(" ", false)
	if fragments.is_empty():
		return "Question"
	return fragments[0]

func _random_date_answer(rng: RandomNumberGenerator) -> String:
	var year: int = rng.randi_range(2021, 2026)
	var month: int = rng.randi_range(1, 12)
	var day: int = rng.randi_range(1, 28)
	return "%04d-%02d-%02d" % [year, month, day]

func _random_option(options: PackedStringArray, rng: RandomNumberGenerator) -> String:
	if options.is_empty():
		return ""
	return options[rng.randi_range(0, options.size() - 1)]

func _random_multi_choice_answer(options: PackedStringArray, rng: RandomNumberGenerator) -> Array[String]:
	var selections: Array[String] = []
	for option in options:
		if rng.randf() >= 0.5:
			selections.append(option)
	if selections.is_empty() and not options.is_empty():
		selections.append(_random_option(options, rng))
	return selections

func _random_ranked_choice_answer(options: PackedStringArray, rng: RandomNumberGenerator) -> Array[String]:
	var ranked: Array[String] = []
	for option in options:
		ranked.append(option)
	for index in range(ranked.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: String = ranked[index]
		ranked[index] = ranked[swap_index]
		ranked[swap_index] = temp
	return ranked

func _random_matrix_answer(question: SurveyQuestion, rng: RandomNumberGenerator) -> Dictionary:
	var matrix_answers: Dictionary = {}
	for row_name in question.rows:
		matrix_answers[row_name] = _random_option(question.options, rng)
	return matrix_answers

func _random_number_answer(question: SurveyQuestion, rng: RandomNumberGenerator) -> Variant:
	var min_value: int = question.min_value
	var max_value: int = question.max_value
	if min_value <= -1000000 and max_value >= 1000000:
		min_value = 1
		max_value = 100
	return _random_numeric_answer(min_value, max_value, question.step, rng)

func _random_numeric_answer(min_value: int, max_value: int, step: float, rng: RandomNumberGenerator) -> Variant:
	var resolved_min: int = min_value
	var resolved_max: int = max_value
	if resolved_max < resolved_min:
		var swap: int = resolved_min
		resolved_min = resolved_max
		resolved_max = swap
	var resolved_step: float = step if step > 0.0 else 1.0
	var step_count: int = int(floor((float(resolved_max - resolved_min)) / resolved_step))
	if step_count < 0:
		step_count = 0
	var random_step: int = rng.randi_range(0, step_count)
	var value: float = float(resolved_min) + float(random_step) * resolved_step
	value = minf(value, float(resolved_max))
	if is_equal_approx(value, round(value)):
		return int(round(value))
	return value

func _show_status_message(message: String, is_error: bool = false) -> void:
	_status_label.text = message
	_status_label.visible = not message.is_empty()
	if message.is_empty():
		SurveyStyle.style_caption(_status_label)
		return
	if is_error:
		SurveyStyle.style_caption(_status_label, SurveyStyle.DANGER)
	else:
		SurveyStyle.style_caption(_status_label, SurveyStyle.TEXT_PRIMARY)

func _update_responsive_layout() -> void:
	if _outline_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var shortest_side := minf(viewport_size.x, viewport_size.y)
	var compact_layout: bool = viewport_size.x <= 640.0
	var phone_layout: bool = viewport_size.x <= 480.0
	var margin := int(clampf(shortest_side * (0.02 if compact_layout else 0.024), 8.0 if phone_layout else 12.0, 32.0))
	var shell_gap := int(clampf(viewport_size.x * 0.014, 8.0, 24.0))
	var column_gap := int(clampf(shell_gap * 0.9, 10.0, 20.0))
	var content_gap := int(clampf(shell_gap * 0.7, 8.0, 16.0))
	_margin.add_theme_constant_override("margin_left", margin)
	_margin.add_theme_constant_override("margin_top", margin)
	_margin.add_theme_constant_override("margin_right", margin)
	_margin.add_theme_constant_override("margin_bottom", margin)
	_shell.add_theme_constant_override("separation", shell_gap)
	_main_column.add_theme_constant_override("separation", column_gap)
	_content_stack.add_theme_constant_override("separation", content_gap)
	_nav_row.add_theme_constant_override("separation", int(clampf(shell_gap * 0.5, 8.0, 12.0)))
	_focus_mode_shell.add_theme_constant_override("separation", content_gap)
	_focus_nav_row.add_theme_constant_override("separation", int(clampf(shell_gap * 0.5, 8.0, 12.0)))
	_set_focus_mode_active(_should_use_focus_mode(viewport_size))
	_outline_panel.visible = viewport_size.x >= 1120.0 and not _focus_mode_active
	_outline_panel.custom_minimum_size.x = clampf(viewport_size.x * 0.24, 220.0, 300.0)
	_focus_question_scroll.custom_minimum_size.y = clampf(viewport_size.y * (0.42 if phone_layout else 0.46), 220.0 if phone_layout else 260.0, 560.0)
	SurveyStyle.style_heading(_focus_section_label, 20 if compact_layout else 24)
	SurveyStyle.style_caption(_focus_progress_label, SurveyStyle.SOFT_WHITE)
	if _clear_filter_button != null:
		_clear_filter_button.custom_minimum_size = Vector2(92.0 if compact_layout else 110.0, 40.0 if compact_layout else 42.0)
	if _menu_access_button != null:
		_menu_access_button.custom_minimum_size = Vector2(80.0 if compact_layout else 92.0, 46.0 if compact_layout else 52.0)
		_menu_access_button.add_theme_font_size_override("font_size", 14 if compact_layout else 15)
	var menu_button_width := clampf(viewport_size.x * 0.18, 72.0, 104.0)
	var menu_button_height := clampf(viewport_size.y * 0.06, 44.0, 56.0)
	var menu_inset := clampf(shortest_side * 0.022, 16.0, 26.0)
	_menu_access_button.offset_left = -menu_button_width - menu_inset
	_menu_access_button.offset_top = -menu_button_height - menu_inset
	_menu_access_button.offset_right = -menu_inset
	_menu_access_button.offset_bottom = -menu_inset
	_sync_focus_question_stage_size()
	_refresh_question_view_layouts(viewport_size)
	_refresh_menu_access_button()
	_overlay_menu.refresh_layout(viewport_size)
	if _search_overlay != null:
		_search_overlay.refresh_layout(viewport_size)
	if _onboarding_overlay != null:
		_onboarding_overlay.refresh_layout(viewport_size)
	if _settings_overlay != null:
		_settings_overlay.refresh_layout(viewport_size)
	if _summary_overlay != null:
		_summary_overlay.refresh_layout(viewport_size)
	if _export_overlay != null:
		_export_overlay.refresh_layout(viewport_size)

func _sync_question_stack_width() -> void:
	if _question_stack == null or _question_scroll == null:
		return
	_question_stack.custom_minimum_size.x = max(0.0, _question_scroll.size.x - 24.0)

func _sync_outline_scroll_position() -> void:
	if _outline_panel == null or _question_scroll == null:
		return
	var scroll_bar := _question_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		_outline_panel.sync_scroll_progress(0.0)
		return
	var max_scroll: float = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	if max_scroll <= 0.0:
		_outline_panel.sync_scroll_progress(0.0)
		return
	_outline_panel.sync_scroll_progress(float(_question_scroll.scroll_vertical) / max_scroll)

func _on_theme_mode_requested(enabled: bool) -> void:
	if use_dark_mode == enabled:
		return
	use_dark_mode = enabled
	SurveyStyle.set_dark_mode(use_dark_mode)
	_refresh_theme_mode()
	_persist_session()

func _on_sfx_volume_requested(volume: float) -> void:
	var clamped_volume: float = clampf(volume, 0.0, 1.0)
	if is_equal_approx(sfx_volume, clamped_volume):
		return
	sfx_volume = clamped_volume
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)
	_persist_session()

func _on_hover_sfx_requested(enabled: bool) -> void:
	if _hover_sfx_enabled == enabled:
		return
	_hover_sfx_enabled = enabled
	SURVEY_UI_FEEDBACK.set_hover_sfx_enabled(_hover_sfx_enabled)
	_show_status_message("Hover sound effects enabled." if enabled else "Hover sound effects disabled.")
	_persist_session()

func _on_remember_onboarding_requested(enabled: bool) -> void:
	if _remember_onboarding_preferences == enabled:
		return
	_remember_onboarding_preferences = enabled
	if not enabled:
		_onboarding_completed = false
		_onboarding_mode = ""
		_preferred_topic_tag = ""
		_preferred_audience_id = ""
		_show_status_message("Onboarding memory disabled for this device.")
	else:
		_show_status_message("Onboarding memory enabled for this device.")
	_persist_session()

func _on_local_session_cache_requested(enabled: bool) -> void:
	if _allow_local_session_cache == enabled:
		return
	_allow_local_session_cache = enabled
	if not enabled:
		if use_saved_dev_data and survey != null:
			SURVEY_SESSION_CACHE.clear_session(survey, survey_template_path)
		_show_status_message("Local session cache disabled. Progress will not be saved automatically.")
	else:
		_show_status_message("Local session cache enabled.")
	_persist_session()

func _refresh_theme_mode() -> void:
	var saved_scroll := _question_scroll.scroll_vertical
	var saved_section_index := current_section_index
	var saved_question_id := _selected_question_id
	var saved_pending_question_id := _pending_navigation_question_id
	var was_overlay_open := _overlay_menu.visible
	_refresh_static_theme_shell()
	if survey != null:
		_populate_document()
		current_section_index = saved_section_index
		_pending_navigation_question_id = saved_pending_question_id
		_set_selected_question(saved_question_id)
		_outline_panel.refresh(answers, current_section_index, _selected_question_id)
		_update_navigation_state()
		_refresh_focus_mode(true)
		call_deferred("_restore_document_state", saved_scroll, was_overlay_open)

func _restore_document_state(saved_scroll: int, was_overlay_open: bool) -> void:
	_sync_question_stack_width()
	if not _focus_mode_active:
		_question_scroll.scroll_vertical = saved_scroll
		_last_scroll_vertical = float(saved_scroll)
	_sync_visible_location(true)
	_sync_outline_scroll_position()
	_refresh_focus_mode(true)
	if was_overlay_open and survey != null:
		_overlay_menu.open_menu(survey, current_section_index, answers, sfx_volume, false)
	_refresh_menu_access_button()

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()











