class_name SurveyJourneyApp
extends Control

const SAMPLE_SURVEY = preload("res://Scripts/Survey/SampleSurvey.gd")
const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_EXPORTER = preload("res://Scripts/Survey/SurveyExporter.gd")
const SURVEY_SAVE_BUNDLE = preload("res://Scripts/Survey/SurveySaveBundle.gd")
const SURVEY_SUMMARY_ANALYZER = preload("res://Scripts/Survey/SurveySummaryAnalyzer.gd")
const SURVEY_SUBMISSION_BUNDLE = preload("res://Scripts/Survey/SurveySubmissionBundle.gd")
const SURVEY_UPLOAD_AUDIT_STORE = preload("res://Scripts/Survey/SurveyUploadAuditStore.gd")
const SURVEY_PREFERENCES_STORE = preload("res://Scripts/Survey/SurveyPreferencesStore.gd")
const SURVEY_SESSION_CACHE = preload("res://Scripts/Survey/SurveySessionCache.gd")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const SURVEY_ICON_LIBRARY = preload("res://Scripts/UI/SurveyIconLibrary.gd")
const OVERLAY_MENU_SCENE: PackedScene = preload("res://Scenes/UI/OverlayMenu.tscn")
const QUESTION_HELP_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/QuestionHelpOverlay.tscn")
const SECTION_OUTLINE_PANEL_SCENE: PackedScene = preload("res://Scenes/UI/SectionOutlinePanel.tscn")
const SURVEY_PROFILE_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/SurveyProfileOverlay.tscn")
const SURVEY_GAMIFICATION_HUD_SCENE: PackedScene = preload("res://Scenes/UI/SurveyGamificationHud.tscn")
const SURVEY_TOAST_OVERLAY_SCRIPT = preload("res://Scripts/UI/SurveyToastOverlay.gd")
const SURVEY_THEME_DRAWER_SCRIPT = preload("res://Scripts/UI/SurveyThemeDrawer.gd")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")
const DEFAULT_THEME_CATALOG = preload("res://Themes/SurveyThemeCatalog.tres")
const ACTION_TRASH_ICON_PATH := "res://Assets/UI/Icons/action-trash.svg"
const DEFAULT_QUESTION_XP_CONFIG: SurveyQuestionXpConfig = preload("res://Resources/Survey/DefaultQuestionXpConfig.tres")
const SURVEY_GAMIFICATION_HUB = preload("res://Scripts/UI/SurveyGamificationHub.gd")
const SURVEY_GAMIFICATION_STORE = preload("res://Scripts/Survey/SurveyGamificationStore.gd")
const SURVEY_PLATFORM_EXPORTS = preload("res://Scripts/UI/SurveyPlatformExports.gd")
const SURVEY_PREVIEW_CONFIG = preload("res://Scripts/UI/SurveyPreviewConfig.gd")
const COMPLETE_STATUS_COLOR := Color("3cab68")
const PARTIAL_STATUS_COLOR := Color("d0a441")
const UNANSWERED_STATUS_COLOR := Color("c55353")
const TEMPLATE_SELECTION_STORE_PATH := "user://selected_survey_template.json"
const EXPORT_FORMAT_JSON := "json"
const EXPORT_FORMAT_CSV := "csv"
const TRACE_LOG_PATH := "user://survey_journey_trace.log"
const SURVEY_BACKUP_DIR := "user://survey_backups"
const VIEW_LANDING := &"landing"
const VIEW_SURVEY_SELECTION := &"survey_selection"
const VIEW_LORE := &"lore"
const VIEW_SECTION_SELECTION := &"section_selection"
const VIEW_FOCUS := &"focus"
const VIEW_REVIEW := &"review"
const VIEW_THANKS := &"thanks"
const VIEW_EXPORT := &"export"
const VIEW_UPLOAD := &"upload"
const PURPOSE_SURVEY := &"survey"
const PURPOSE_LORE := &"lore"

@export_file("*.json") var survey_template_path := "res://Dev/SurveyTemplates/studio_feedback.json"
@export var dark_palette: Resource = DEFAULT_DARK_PALETTE
@export var light_palette: Resource = DEFAULT_LIGHT_PALETTE
@export var theme_catalog: Resource = DEFAULT_THEME_CATALOG
@export var default_theme_id := "classic"
@export var question_xp_config: SurveyQuestionXpConfig = DEFAULT_QUESTION_XP_CONFIG
@export var xp_system_enabled := false
@export var use_dark_mode := true
@export_range(0.0, 1.0, 0.01) var sfx_volume := 0.35
@export var persist_selected_template := true
@export_range(0, 250, 1) var max_xp_per_question := 0
@export var upload_endpoint_url := ""
@export var upload_destination_name := "Configured upload endpoint"
@export var upload_public_repo_name := "Configured public repository"
@export var upload_public_repo_url := ""
@export_multiline var upload_usage_summary := "Submitted answers are used to preserve legitimate survey responses and support aggregate review."
@export_multiline var upload_reason_summary := "Uploads help move completed answers into a Supabase-backed collection flow for analysis and follow-up."
@export var upload_request_headers: PackedStringArray = PackedStringArray()
@export var require_upload_consent := true
@export_range(0, 100, 1) var minimum_answered_questions_for_upload := 3
@export_range(0, 3600, 1) var upload_cooldown_seconds := 45
@export_range(1, 100, 1) var upload_max_attempts_per_window := 6
@export_range(60, 86400, 1) var upload_attempt_window_seconds := 3600
@export_range(0, 3600, 1) var minimum_upload_session_seconds := 45
@export_range(0.0, 60.0, 0.5) var minimum_upload_seconds_per_answer := 2.5
@export_range(0, 300, 1) var minimum_seconds_to_first_answer := 1
@export_range(0, 100, 1) var max_template_loads_per_window := 12
@export_range(60, 86400, 1) var template_load_window_seconds := 3600
@export_range(0, 20, 1) var max_successful_uploads_per_template := 2
@export_range(60, 604800, 1) var successful_uploads_per_template_window_seconds := 86400
@export_range(0, 50, 1) var max_successful_uploads_per_install := 6
@export_range(60, 604800, 1) var successful_uploads_per_install_window_seconds := 86400

var survey: SurveyDefinition
var answers: Dictionary = {}
var _available_templates: Array[Dictionary] = []
var _selection_purpose: StringName = PURPOSE_SURVEY
var _current_view: StringName = VIEW_LANDING
var _current_template_path := ""
var _selected_template_path := ""
var _lore_return_view: StringName = VIEW_SURVEY_SELECTION
var _section_selection_return_view: StringName = VIEW_SURVEY_SELECTION
var _selected_section_index := -1
var _question_order: Array[String] = []
var _playable_question_ids: Array[String] = []
var _focus_index := 0
var _focus_start_section_index := 0
var _focus_navigation_pending := false
var _feedback_hub
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _template_dialog: FileDialog
var _pending_save_text := ""
var _pending_save_image: Image = null
var _pending_save_extension := ""
var _pending_save_label := ""
var _web_progress_picker_active := false
var _web_progress_picker_success_callback = null
var _web_progress_picker_error_callback = null
var _web_template_picker_active := false
var _web_template_picker_success_callback = null
var _web_template_picker_error_callback = null
var _preview_mode_override := SURVEY_PREVIEW_CONFIG.MODE_AUTO
var _preview_resolution_preset := ""
var _selected_theme_id := ""
var _question_debug_ids_enabled := false
var _question_modifiers_enabled := true
var _action_trash_icon: Texture2D = null
var _focus_outline_overlay: Control
var _focus_outline_panel: SectionOutlinePanel
var _focus_outline_toggle_button: Button
var _focus_outline_bound_template_path := ""
var _review_return_view: StringName = VIEW_THANKS
var _export_return_view: StringName = VIEW_THANKS
var _upload_return_view: StringName = VIEW_EXPORT
var _gamification_hub
var _gamification_hud
var _gamification_completed_sections: Dictionary = {}
var _gamification_completed_questions: Dictionary = {}
var _gamification_survey_completed := false
var _focus_xp_segment_controls: Array[Control] = []
var _upload_request: HTTPRequest
var _upload_in_progress := false
var _pending_upload_payload_hash := ""
var _last_upload_response_text := ""
var _last_upload_status_text := ""
var _last_upload_status_is_error := false
var _response_session_started_at_unix := 0
var _response_first_answer_at_unix := 0
var _response_last_answer_at_unix := 0
var _response_answer_change_count := 0
var _response_restored_progress := false
var _confirmation_dialog: ConfirmationDialog
var _pending_confirmation_action: Callable = Callable()
var _pending_confirmation_option_action: Callable = Callable()
var _confirmation_option_checkbox: CheckBox
var _confirmation_dialog_is_destructive := true

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
@onready var _character_button: Button = $Margin/MainPanel/Stack/LandingView/LandingActions/CharacterButton
@onready var _landing_featured_survey_label: Label = $Margin/MainPanel/Stack/LandingView/LandingFeaturedSurveyLabel
@onready var _browse_surveys_button: Button = $Margin/MainPanel/Stack/LandingView/LandingBrowseSurveysButton
@onready var _survey_selection_view: VBoxContainer = $Margin/MainPanel/Stack/SurveySelectionView
@onready var _survey_selection_back_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionTopRow/SurveySelectionBackButton
@onready var _survey_selection_heading_label: Label = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionHeadingLabel
@onready var _survey_selection_subtitle_label: Label = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionSubtitleLabel
@onready var _survey_selection_scroll: ScrollContainer = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionScroll
@onready var _survey_selection_grid: GridContainer = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionScroll/SurveySelectionGrid
@onready var _survey_selection_manage_grid: GridContainer = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid
@onready var _survey_selection_import_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionImportButton
@onready var _survey_selection_export_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionExportButton
@onready var _survey_selection_clear_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionClearButton
@onready var _survey_selection_action_spacer: Control = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionActionRow/SurveySelectionActionSpacer
@onready var _survey_selection_next_button: Button = $Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionActionRow/SurveySelectionNextButton
@onready var _lore_view: VBoxContainer = $Margin/MainPanel/Stack/LoreView
@onready var _lore_back_button: Button = $Margin/MainPanel/Stack/LoreView/LoreTopRow/LoreBackButton
@onready var _lore_heading_label: Label = $Margin/MainPanel/Stack/LoreView/LoreHeadingLabel
@onready var _lore_subtitle_label: Label = $Margin/MainPanel/Stack/LoreView/LoreSubtitleLabel
@onready var _lore_survey_label: Label = $Margin/MainPanel/Stack/LoreView/LoreSurveyLabel
@onready var _lore_empty_panel: PanelContainer = $Margin/MainPanel/Stack/LoreView/LoreBody/LoreEmptyPanel
@onready var _lore_empty_label: Label = $Margin/MainPanel/Stack/LoreView/LoreBody/LoreEmptyPanel/LoreEmptyStack/LoreEmptyLabel
@onready var _lore_link_button: Button = $Margin/MainPanel/Stack/LoreView/LoreBody/LoreEmptyPanel/LoreEmptyStack/LoreLinkButton
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
@onready var _focus_xp_stack: VBoxContainer = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer/FocusXpAnchor/FocusXpStack
@onready var _focus_xp_level_label: Label = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer/FocusXpAnchor/FocusXpStack/FocusXpLevelLabel
@onready var _focus_xp_bar: PanelContainer = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer/FocusXpAnchor/FocusXpStack/FocusXpBar
@onready var _focus_xp_segment_row: HBoxContainer = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer/FocusXpAnchor/FocusXpStack/FocusXpBar/FocusXpSegmentRow
@onready var _focus_next_button: Button = $Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNextButton
@onready var _review_view: VBoxContainer = $Margin/MainPanel/Stack/ReviewView
@onready var _review_back_button: Button = $Margin/MainPanel/Stack/ReviewView/ReviewTopRow/ReviewBackButton
@onready var _review_heading_label: Label = $Margin/MainPanel/Stack/ReviewView/ReviewHeadingLabel
@onready var _review_subtitle_label: Label = $Margin/MainPanel/Stack/ReviewView/ReviewSubtitleLabel
@onready var _review_list: VBoxContainer = $Margin/MainPanel/Stack/ReviewView/ReviewScroll/ReviewList
@onready var _thanks_view: VBoxContainer = $Margin/MainPanel/Stack/ThanksView
@onready var _thanks_heading_label: Label = $Margin/MainPanel/Stack/ThanksView/ThanksHeadingLabel
@onready var _thanks_body_label: Label = $Margin/MainPanel/Stack/ThanksView/ThanksBodyLabel
@onready var _thanks_review_button: Button = $Margin/MainPanel/Stack/ThanksView/ThanksActions/ThanksReviewButton
@onready var _thanks_export_button: Button = $Margin/MainPanel/Stack/ThanksView/ThanksActions/ThanksExportButton
@onready var _export_view: VBoxContainer = $Margin/MainPanel/Stack/ExportView
@onready var _export_back_button: Button = $Margin/MainPanel/Stack/ExportView/ExportTopRow/ExportBackButton
@onready var _export_scroll: ScrollContainer = $Margin/MainPanel/Stack/ExportView/ExportScroll
@onready var _export_content: VBoxContainer = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent
@onready var _export_heading_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportHeadingLabel
@onready var _export_subtitle_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportSubtitleLabel
@onready var _export_body_label: Label = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportBodyLabel
@onready var _export_action_grid: GridContainer = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid
@onready var _export_json_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportJsonButton
@onready var _export_upload_answers_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportUploadAnswersButton
@onready var _export_copy_json_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportCopyJsonButton
@onready var _export_copy_csv_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportCopyCsvButton
@onready var _export_csv_button: Button = $Margin/MainPanel/Stack/ExportView/ExportScroll/ExportContent/ExportActionGrid/ExportCsvButton
@onready var _upload_view: VBoxContainer = $Margin/MainPanel/Stack/UploadView
@onready var _upload_back_button: Button = $Margin/MainPanel/Stack/UploadView/UploadTopRow/UploadBackButton
@onready var _upload_scroll: ScrollContainer = $Margin/MainPanel/Stack/UploadView/UploadScroll
@onready var _upload_content: VBoxContainer = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent
@onready var _upload_heading_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadHeadingLabel
@onready var _upload_subtitle_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadSubtitleLabel
@onready var _upload_body_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadBodyLabel
@onready var _upload_notice_panel: PanelContainer = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel
@onready var _upload_scrub_checkbox: CheckBox = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadScrubCheckBox
@onready var _upload_scrub_summary_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadScrubSummaryLabel
@onready var _upload_consent_checkbox: CheckBox = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadConsentCheckBox
@onready var _upload_disclosure_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadDisclosureLabel
@onready var _upload_status_label: Label = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadStatusLabel
@onready var _upload_submit_button: Button = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadSubmitButton
@onready var _upload_copy_response_button: Button = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadCopyResponseButton
@onready var _upload_response_text_edit: TextEdit = $Margin/MainPanel/Stack/UploadView/UploadScroll/UploadContent/UploadNoticePanel/UploadNoticeStack/UploadResponseTextEdit
@onready var _overlay_menu: OverlayMenu = get_node_or_null("OverlayMenu") as OverlayMenu
@onready var _profile_overlay = get_node_or_null("ProfileOverlay")
@onready var _menu_access_layer: CanvasLayer = get_node_or_null("MenuAccessLayer") as CanvasLayer
@onready var _menu_access_button: Button = get_node_or_null("MenuAccessLayer/MenuAccessButton") as Button
@onready var _help_access_button: Button = get_node_or_null("MenuAccessLayer/HelpAccessButton") as Button
@onready var _help_overlay = get_node_or_null("QuestionHelpOverlay")
@onready var _lore_link_prompt_overlay: Control = get_node_or_null("LoreLinkPromptOverlay") as Control
@onready var _lore_link_prompt_panel: PanelContainer = get_node_or_null("LoreLinkPromptOverlay/Center/Panel") as PanelContainer
@onready var _lore_link_prompt_heading_label: Label = get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/TopRow/HeadingLabel") as Label
@onready var _lore_link_prompt_close_button: Button = get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/TopRow/CloseButton") as Button
@onready var _lore_link_prompt_body_label: Label = get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/BodyLabel") as Label
@onready var _lore_link_prompt_copy_button: Button = get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/ActionRow/CopyButton") as Button
@onready var _lore_link_prompt_open_button: Button = get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/ActionRow/OpenButton") as Button
var _toast_overlay
var _theme_drawer

func _ready() -> void:
	_start_trace_session()
	_prime_preferences_from_store()
	_apply_selected_theme_palette()
	_configure_feedback_hub()
	_ensure_upload_request()
	_configure_file_dialogs()
	_ensure_optional_ui_nodes()
	_prepare_survey_selection_shell()
	_connect_actions()
	_load_available_templates()
	_load_initial_survey()
	_refresh_theme()
	if _upload_response_text_edit != null:
		_upload_response_text_edit.editable = false
	_show_view(VIEW_LANDING)
	call_deferred("_sync_scroll_content_widths")
	_refresh_menu_access_button()
	set_process_unhandled_input(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_responsive_layout()
		_refresh_focus_stage_layout()
		call_deferred("_sync_scroll_content_widths")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	if _lore_link_prompt_overlay != null and _lore_link_prompt_overlay.visible:
		_close_lore_link_prompt()
		return
	if _help_overlay != null and _help_overlay.visible:
		_close_question_help()
		return
	if _profile_overlay != null and _profile_overlay.visible:
		_close_profile_overlay()
		return
	if _overlay_menu != null and _overlay_menu.visible:
		_close_overlay_menu()
		return
	if _focus_outline_overlay != null and _focus_outline_overlay.visible:
		_set_focus_outline_visible(false)
		return
	match _current_view:
		VIEW_SURVEY_SELECTION, VIEW_LORE, VIEW_SECTION_SELECTION:
			_show_view(VIEW_LANDING)
		VIEW_FOCUS:
			_on_focus_back_pressed()
		VIEW_REVIEW:
			_close_review_view()
		VIEW_THANKS:
			_show_view(VIEW_LANDING)
		VIEW_EXPORT:
			_close_export_overlay()
		VIEW_UPLOAD:
			_close_upload_view()

func _resolved_palette_resource(candidate: Resource, fallback: Resource) -> Resource:
	return candidate if candidate != null else fallback

func _resolved_theme_catalog_resource(candidate: Resource, fallback: Resource) -> Resource:
	return candidate if candidate != null else fallback

func _available_theme_sets() -> Array:
	var catalog = _resolved_theme_catalog_resource(theme_catalog, DEFAULT_THEME_CATALOG)
	return catalog.available_themes() if catalog != null else []

func _selected_theme_set():
	var catalog = _resolved_theme_catalog_resource(theme_catalog, DEFAULT_THEME_CATALOG)
	if catalog == null:
		return null
	return catalog.resolve_theme(_selected_theme_id if not _selected_theme_id.is_empty() else default_theme_id)

func _apply_selected_theme_palette() -> void:
	var theme_set = _selected_theme_set()
	if theme_set != null:
		_selected_theme_id = theme_set.normalized_theme_id()
		dark_palette = _resolved_palette_resource(theme_set.resolved_dark_palette(DEFAULT_DARK_PALETTE), DEFAULT_DARK_PALETTE)
		light_palette = _resolved_palette_resource(theme_set.resolved_light_palette(DEFAULT_LIGHT_PALETTE), DEFAULT_LIGHT_PALETTE)
	else:
		dark_palette = _resolved_palette_resource(dark_palette, DEFAULT_DARK_PALETTE)
		light_palette = _resolved_palette_resource(light_palette, DEFAULT_LIGHT_PALETTE)
	SurveyStyle.configure_palettes(dark_palette, light_palette, use_dark_mode)

func _refresh_theme_drawer() -> void:
	if _theme_drawer == null:
		return
	var theme_sets = _available_theme_sets()
	_theme_drawer.configure(theme_sets, _selected_theme_id, use_dark_mode)
	_theme_drawer.visible = _current_view == VIEW_LANDING and not theme_sets.is_empty()
	_theme_drawer.refresh_theme()
	_theme_drawer.refresh_layout(get_viewport().get_visible_rect().size)

func _configure_feedback_hub() -> void:
	if _feedback_hub == null:
		_feedback_hub = SURVEY_UI_FEEDBACK.new()
		add_child(_feedback_hub)
	SURVEY_UI_FEEDBACK.set_sfx_volume(sfx_volume)

func _ensure_upload_request() -> void:
	if _upload_request != null:
		return
	_upload_request = HTTPRequest.new()
	_upload_request.name = "JourneyUploadRequest"
	_upload_request.timeout = 20.0
	_upload_request.request_completed.connect(_on_upload_request_completed)
	add_child(_upload_request)

func _prime_preferences_from_store() -> void:
	var preferences: Dictionary = SURVEY_PREFERENCES_STORE.load_preferences()
	_selected_theme_id = str(preferences.get("selected_theme_id", default_theme_id)).strip_edges()
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
	if _help_overlay == null and QUESTION_HELP_OVERLAY_SCENE != null:
		var help_overlay_instance = QUESTION_HELP_OVERLAY_SCENE.instantiate()
		if help_overlay_instance != null:
			help_overlay_instance.name = "QuestionHelpOverlay"
			add_child(help_overlay_instance)
			_help_overlay = help_overlay_instance
	if _theme_drawer == null and SURVEY_THEME_DRAWER_SCRIPT != null:
		var theme_drawer_instance = SURVEY_THEME_DRAWER_SCRIPT.new()
		if theme_drawer_instance != null:
			theme_drawer_instance.name = "ThemeDrawer"
			add_child(theme_drawer_instance)
			var prompt_index := get_children().find(_lore_link_prompt_overlay)
			if prompt_index > 0:
				move_child(theme_drawer_instance, prompt_index)
			_theme_drawer = theme_drawer_instance
	if _profile_overlay == null and SURVEY_PROFILE_OVERLAY_SCENE != null:
		var profile_overlay_instance = SURVEY_PROFILE_OVERLAY_SCENE.instantiate()
		if profile_overlay_instance != null:
			profile_overlay_instance.name = "ProfileOverlay"
			add_child(profile_overlay_instance)
			_profile_overlay = profile_overlay_instance
	if get_node_or_null("SurveyToastOverlay") == null and SURVEY_TOAST_OVERLAY_SCRIPT != null:
		var toast_overlay = SURVEY_TOAST_OVERLAY_SCRIPT.new()
		if toast_overlay != null:
			toast_overlay.name = "SurveyToastOverlay"
			add_child(toast_overlay)
	if _confirmation_dialog == null:
		var existing_confirmation := get_node_or_null("ActionConfirmationDialog") as ConfirmationDialog
		if existing_confirmation != null:
			_confirmation_dialog = existing_confirmation
		else:
			_confirmation_dialog = ConfirmationDialog.new()
			_confirmation_dialog.name = "ActionConfirmationDialog"
			_confirmation_dialog.title = "Confirm Action"
			_confirmation_dialog.dialog_text = ""
			add_child(_confirmation_dialog)
			_confirmation_dialog.confirmed.connect(_on_confirmation_dialog_confirmed)
			_confirmation_dialog.canceled.connect(_on_confirmation_dialog_canceled)
			_wire_button_feedback(_confirmation_dialog.get_ok_button())
			_wire_button_feedback(_confirmation_dialog.get_cancel_button())
	if _confirmation_dialog != null and _confirmation_option_checkbox == null:
		_confirmation_option_checkbox = _confirmation_dialog.get_node_or_null("OptionCheckbox") as CheckBox
		if _confirmation_option_checkbox == null:
			var option_checkbox := CheckBox.new()
			option_checkbox.name = "OptionCheckbox"
			option_checkbox.visible = false
			option_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_confirmation_dialog.add_child(option_checkbox)
			_confirmation_option_checkbox = option_checkbox
	_ensure_gamification_nodes()
	_toast_overlay = get_node_or_null("SurveyToastOverlay")
	if _menu_access_layer == null:
		var access_layer := CanvasLayer.new()
		access_layer.name = "MenuAccessLayer"
		access_layer.layer = 61
		add_child(access_layer)
		_menu_access_layer = access_layer
	if _menu_access_button == null and _menu_access_layer != null:
		var access_button := Button.new()
		access_button.name = "MenuAccessButton"
		access_button.text = "☰"
		access_button.tooltip_text = "Open menu"
		access_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		access_button.anchor_left = 1.0
		access_button.anchor_right = 1.0
		access_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		access_button.grow_vertical = Control.GROW_DIRECTION_BOTH
		_menu_access_layer.add_child(access_button)
		_menu_access_button = access_button
	if _help_access_button == null and _menu_access_layer != null:
		var help_button := Button.new()
		help_button.name = "HelpAccessButton"
		help_button.text = "?"
		help_button.tooltip_text = "Open question help"
		help_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		help_button.anchor_left = 1.0
		help_button.anchor_right = 1.0
		help_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		help_button.grow_vertical = Control.GROW_DIRECTION_BOTH
		_menu_access_layer.add_child(help_button)
		_help_access_button = help_button
	_ensure_focus_outline_nodes()

func _prepare_survey_selection_shell() -> void:
	if _survey_selection_view == null:
		return
	if _survey_selection_manage_grid != null and _survey_selection_scroll != null:
		var target_index := _survey_selection_view.get_children().find(_survey_selection_scroll)
		if target_index >= 0 and _survey_selection_view.get_children().find(_survey_selection_manage_grid) != target_index:
			_survey_selection_view.move_child(_survey_selection_manage_grid, target_index)
	if _survey_selection_clear_button != null:
		_survey_selection_clear_button.visible = false

func _ensure_focus_outline_nodes() -> void:
	if _focus_outline_toggle_button == null and _focus_back_button != null:
		var top_row := _focus_back_button.get_parent() as HBoxContainer
		if top_row != null:
			var outline_button := Button.new()
			outline_button.name = "FocusOutlineToggleButton"
			outline_button.text = "Outline"
			outline_button.tooltip_text = "Toggle the section outline."
			outline_button.toggle_mode = true
			top_row.add_child(outline_button)
			var spacer_index: int = mini(1, maxi(top_row.get_child_count() - 1, 0))
			if spacer_index <= 0:
				spacer_index = mini(1, maxi(top_row.get_child_count() - 1, 0))
			top_row.move_child(outline_button, spacer_index)
			_focus_outline_toggle_button = outline_button
	if _focus_outline_overlay == null:
		var overlay := Control.new()
		overlay.name = "FocusOutlineOverlay"
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
		overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(overlay)
		_focus_outline_overlay = overlay
	if _focus_outline_panel == null and _focus_outline_overlay != null and SECTION_OUTLINE_PANEL_SCENE != null:
		var outline_panel := SECTION_OUTLINE_PANEL_SCENE.instantiate() as SectionOutlinePanel
		if outline_panel != null:
			outline_panel.name = "FocusOutlinePanel"
			outline_panel.configure_display("Section Outline", "Tap any section to jump there.", false)
			outline_panel.mouse_filter = Control.MOUSE_FILTER_STOP
			outline_panel.visible = true
			_focus_outline_overlay.add_child(outline_panel)
			_focus_outline_panel = outline_panel

func _ensure_gamification_nodes() -> void:
	if not _is_xp_system_enabled():
		var existing_hub := get_node_or_null("SurveyGamificationHub")
		if existing_hub != null:
			existing_hub.queue_free()
		var existing_hud := get_node_or_null("SurveyGamificationHud")
		if existing_hud != null:
			existing_hud.queue_free()
		_gamification_hub = null
		_gamification_hud = null
		return
	if _gamification_hub == null:
		var existing_hub := get_node_or_null("SurveyGamificationHub")
		if existing_hub != null:
			_gamification_hub = existing_hub
		else:
			_gamification_hub = SURVEY_GAMIFICATION_HUB.new()
			_gamification_hub.name = "SurveyGamificationHub"
			add_child(_gamification_hub)
	if _gamification_hud == null:
		var existing_hud := get_node_or_null("SurveyGamificationHud")
		if existing_hud != null:
			_gamification_hud = existing_hud
		elif SURVEY_GAMIFICATION_HUD_SCENE != null:
			_gamification_hud = SURVEY_GAMIFICATION_HUD_SCENE.instantiate()
			if _gamification_hud != null:
				_gamification_hud.name = "SurveyGamificationHud"
				add_child(_gamification_hud)

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

	_template_dialog = FileDialog.new()
	_template_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_template_dialog.title = "Import Survey Template"
	_template_dialog.file_selected.connect(_on_template_dialog_file_selected)
	_template_dialog.canceled.connect(_on_template_dialog_canceled)
	add_child(_template_dialog)

func _connect_actions() -> void:
	for button in [_take_survey_button, _get_lore_button, _character_button, _browse_surveys_button, _survey_selection_back_button, _survey_selection_import_button, _survey_selection_export_button, _survey_selection_clear_button, _survey_selection_next_button, _lore_back_button, _lore_link_button, _lore_take_survey_button, _lore_link_prompt_close_button, _lore_link_prompt_copy_button, _lore_link_prompt_open_button, _section_selection_back_button, _section_selection_next_button, _focus_back_button, _review_back_button, _thanks_review_button, _thanks_export_button, _export_back_button, _export_json_button, _export_upload_answers_button, _export_copy_json_button, _export_copy_csv_button, _export_csv_button, _upload_back_button, _upload_scrub_checkbox, _upload_consent_checkbox, _upload_submit_button, _upload_copy_response_button]:
		_wire_button_feedback(button)
	for button in [_focus_previous_button, _focus_next_button]:
		_wire_button_hover_feedback(button)
	if _menu_access_button != null:
		_wire_button_feedback(_menu_access_button)
	if _help_access_button != null:
		_wire_button_feedback(_help_access_button)
	_take_survey_button.pressed.connect(_on_take_survey_pressed)
	_get_lore_button.pressed.connect(_on_get_lore_pressed)
	_character_button.pressed.connect(_open_profile_overlay)
	_browse_surveys_button.pressed.connect(_open_survey_browser)
	_survey_selection_back_button.pressed.connect(_show_view.bind(VIEW_LANDING))
	_survey_selection_import_button.pressed.connect(_open_template_import_workflow)
	_survey_selection_export_button.pressed.connect(_open_template_export_workflow)
	_survey_selection_clear_button.pressed.connect(_confirm_clear_selected_template_answers)
	_survey_selection_next_button.pressed.connect(_advance_from_survey_selection)
	_lore_back_button.pressed.connect(_on_lore_back_pressed)
	_lore_link_button.pressed.connect(_open_lore_link_prompt)
	_lore_take_survey_button.pressed.connect(_on_lore_take_survey_pressed)
	if _lore_link_prompt_close_button != null:
		_lore_link_prompt_close_button.pressed.connect(_close_lore_link_prompt)
	if _lore_link_prompt_copy_button != null:
		_lore_link_prompt_copy_button.pressed.connect(_copy_current_lore_url_to_clipboard)
	if _lore_link_prompt_open_button != null:
		_lore_link_prompt_open_button.pressed.connect(_open_current_lore_url)
	_section_selection_back_button.pressed.connect(_on_section_selection_back_pressed)
	_section_selection_next_button.pressed.connect(_advance_from_section_selection)
	_focus_back_button.pressed.connect(_on_focus_back_pressed)
	_focus_previous_button.pressed.connect(_on_focus_previous_button_feedback)
	_focus_next_button.pressed.connect(_on_focus_next_button_feedback)
	_focus_previous_button.pressed.connect(_on_focus_previous_pressed)
	_focus_next_button.pressed.connect(_on_focus_next_pressed)
	_focus_question_stage.answer_changed.connect(_on_focus_answer_changed)
	_focus_question_stage.question_selected.connect(_on_focus_question_selected)
	_focus_question_stage.help_requested.connect(_on_focus_help_requested)
	_focus_question_stage.modifier_fatigue_detected.connect(_on_focus_modifier_fatigue_detected)
	_focus_question_stage.layout_stabilized.connect(_on_focus_stage_layout_stabilized)
	_review_back_button.pressed.connect(_close_review_view)
	_thanks_review_button.pressed.connect(_open_review_view)
	_thanks_export_button.pressed.connect(_open_export_overlay)
	_export_back_button.pressed.connect(_close_export_overlay)
	_export_json_button.pressed.connect(_export_json)
	_export_upload_answers_button.pressed.connect(_open_upload_view)
	_export_copy_json_button.pressed.connect(_copy_json)
	_export_copy_csv_button.pressed.connect(_copy_csv)
	_export_csv_button.pressed.connect(_export_csv)
	_upload_back_button.pressed.connect(_close_upload_view)
	_upload_scrub_checkbox.toggled.connect(_on_upload_scrub_toggled)
	_upload_consent_checkbox.toggled.connect(_on_upload_consent_toggled)
	_upload_submit_button.pressed.connect(_submit_upload_answers)
	_upload_copy_response_button.pressed.connect(_copy_upload_response_to_clipboard)
	if _menu_access_button != null:
		_menu_access_button.pressed.connect(_open_overlay_menu)
	if _help_access_button != null:
		_help_access_button.pressed.connect(_open_question_help)
	if _overlay_menu != null:
		_overlay_menu.resume_requested.connect(_close_overlay_menu)
		_overlay_menu.restart_requested.connect(_on_menu_restart_requested)
		_overlay_menu.clear_section_requested.connect(_on_menu_clear_section_requested)
		_overlay_menu.jump_to_section_requested.connect(_on_menu_jump_to_section_requested)
		_overlay_menu.summary_requested.connect(_on_menu_review_requested)
		_overlay_menu.profile_requested.connect(_open_profile_overlay)
		_overlay_menu.export_requested.connect(_on_menu_export_requested)
		_overlay_menu.theme_mode_requested.connect(_on_menu_theme_mode_requested)
		_overlay_menu.sfx_volume_requested.connect(_on_menu_sfx_volume_requested)
		_overlay_menu.preview_mode_requested.connect(_on_menu_preview_mode_requested)
		_overlay_menu.preview_resolution_requested.connect(_on_menu_preview_resolution_requested)
		_overlay_menu.question_debug_ids_requested.connect(_on_menu_question_debug_ids_requested)
	if _help_overlay != null:
		_help_overlay.closed.connect(_refresh_menu_access_button)
	if _focus_outline_toggle_button != null:
		_wire_button_feedback(_focus_outline_toggle_button)
		_focus_outline_toggle_button.toggled.connect(_on_focus_outline_toggled)
	if _focus_outline_panel != null:
		_focus_outline_panel.navigate_requested.connect(_on_focus_outline_navigate_requested)
	if _theme_drawer != null:
		_theme_drawer.theme_selected.connect(_on_theme_drawer_theme_selected)
		_theme_drawer.theme_mode_requested.connect(_on_menu_theme_mode_requested)
	if _toast_overlay != null:
		_toast_overlay.action_requested.connect(_on_toast_overlay_action_requested)
	if _profile_overlay != null:
		_profile_overlay.close_requested.connect(_close_profile_overlay)
		_profile_overlay.copy_png_requested.connect(_copy_profile_png)
		_profile_overlay.save_png_requested.connect(_save_profile_png)
		_profile_overlay.copy_json_requested.connect(_copy_profile_json)
		_profile_overlay.save_json_requested.connect(_save_profile_json)
		_profile_overlay.copy_csv_requested.connect(_copy_profile_csv)
		_profile_overlay.save_csv_requested.connect(_save_profile_csv)
		_profile_overlay.share_json_requested.connect(_copy_profile_share_json)
	if _gamification_hub != null:
		_gamification_hub.award_resolved.connect(_on_gamification_award_resolved)
		_gamification_hub.profile_changed.connect(_on_gamification_profile_changed)

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

func _trash_action_icon() -> Texture2D:
	if _action_trash_icon != null:
		return _action_trash_icon
	if not FileAccess.file_exists(ACTION_TRASH_ICON_PATH):
		return null
	var svg_text := FileAccess.get_file_as_string(ACTION_TRASH_ICON_PATH)
	if svg_text.strip_edges().is_empty():
		return null
	var image := Image.new()
	if image.load_svg_from_string(svg_text, 1.0) != OK:
		return null
	_action_trash_icon = ImageTexture.create_from_image(image)
	return _action_trash_icon

func _on_focus_back_pressed() -> void:
	_set_focus_outline_visible(false)
	_show_view(_section_selection_return_view)

func _on_focus_outline_toggled(pressed: bool) -> void:
	_set_focus_outline_visible(pressed)

func _on_focus_outline_navigate_requested(section_index: int, question_id: String) -> void:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	_start_focus_from_section(section_index, question_id)

func _set_focus_outline_visible(visible: bool) -> void:
	var should_show := visible and _current_view == VIEW_FOCUS and survey != null and not survey.sections.is_empty()
	if _focus_outline_overlay != null:
		_focus_outline_overlay.visible = should_show
	if _focus_outline_toggle_button != null and _focus_outline_toggle_button.button_pressed != should_show:
		_focus_outline_toggle_button.set_pressed_no_signal(should_show)
	_refresh_focus_outline_toggle_state()
	if should_show:
		_refresh_focus_outline_state()
		call_deferred("_refresh_focus_outline_layout", get_viewport().get_visible_rect().size)

func _refresh_focus_outline_toggle_state() -> void:
	if _focus_outline_toggle_button == null:
		return
	var outline_visible := _focus_outline_overlay != null and _focus_outline_overlay.visible
	_focus_outline_toggle_button.text = "Hide Outline" if outline_visible else "Outline"
	_focus_outline_toggle_button.tooltip_text = "Hide the section outline." if outline_visible else "Show the section outline."
	if outline_visible:
		SurveyStyle.apply_primary_button(_focus_outline_toggle_button)
	else:
		SurveyStyle.apply_secondary_button(_focus_outline_toggle_button)

func _refresh_focus_outline_state() -> void:
	if _focus_outline_panel == null:
		return
	if survey == null or survey.sections.is_empty():
		_focus_outline_bound_template_path = ""
		if _focus_outline_overlay != null:
			_focus_outline_overlay.visible = false
		return
	_focus_outline_panel.configure_display("Section Outline", "Tap any section to jump there.", false)
	if _focus_outline_bound_template_path != _current_template_path:
		_focus_outline_panel.bind_survey(survey)
		_focus_outline_bound_template_path = _current_template_path
	var current_question_id := _current_focus_question_id()
	var current_section_index := _section_index_for_question_id(current_question_id)
	if current_section_index < 0:
		current_section_index = clampi(_focus_start_section_index, 0, max(survey.sections.size() - 1, 0))
	_focus_outline_panel.refresh(answers, current_section_index, current_question_id)
	_sync_focus_outline_scroll_position()

func _sync_focus_outline_scroll_position() -> void:
	if _focus_outline_panel == null or survey == null or survey.sections.is_empty():
		return
	if survey.sections.size() <= 1:
		_focus_outline_panel.sync_scroll_progress(0.0)
		return
	var current_question_id := _current_focus_question_id()
	var current_section_index := _section_index_for_question_id(current_question_id)
	if current_section_index < 0:
		current_section_index = clampi(_focus_start_section_index, 0, max(survey.sections.size() - 1, 0))
	var progress := float(current_section_index) / float(max(1, survey.sections.size() - 1))
	_focus_outline_panel.sync_scroll_progress(progress)

func _refresh_focus_outline_layout(viewport_size: Vector2) -> void:
	if _focus_outline_overlay == null or _focus_outline_panel == null:
		return
	_focus_outline_overlay.visible = _focus_outline_overlay.visible and _current_view == VIEW_FOCUS and survey != null and not survey.sections.is_empty()
	if not _focus_outline_overlay.visible:
		return
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var main_rect := _main_panel.get_global_rect()
	var width := clampf(viewport_size.x * (0.9 if phone_layout else 0.38), 220.0, 380.0)
	var max_height := clampf(viewport_size.y * (0.54 if phone_layout else 0.6), 220.0, 540.0)
	var top_anchor_rect := _focus_section_label.get_global_rect() if _focus_section_label != null else main_rect
	var panel_x := main_rect.position.x + (main_rect.size.x - width) * 0.5 if phone_layout else main_rect.position.x + main_rect.size.x - width - 18.0
	var panel_y := clampf(top_anchor_rect.position.y + 4.0, main_rect.position.y + 14.0, main_rect.position.y + maxf(main_rect.size.y - max_height - 14.0, 14.0))
	_focus_outline_panel.position = Vector2(panel_x, panel_y)
	_focus_outline_panel.custom_minimum_size = Vector2(width, max_height)
	_focus_outline_panel.size = Vector2(width, max_height)

func _refresh_confirmation_dialog_theme() -> void:
	if _confirmation_dialog == null:
		return
	var ok_button := _confirmation_dialog.get_ok_button()
	if ok_button != null:
		if _confirmation_dialog_is_destructive:
			SurveyStyle.apply_danger_button(ok_button)
		else:
			SurveyStyle.apply_primary_button(ok_button)
		ok_button.custom_minimum_size = Vector2(maxf(ok_button.custom_minimum_size.x, 120.0), maxf(ok_button.custom_minimum_size.y, 42.0))
	var cancel_button := _confirmation_dialog.get_cancel_button()
	if cancel_button != null:
		SurveyStyle.apply_secondary_button(cancel_button)
		cancel_button.custom_minimum_size = Vector2(maxf(cancel_button.custom_minimum_size.x, 96.0), maxf(cancel_button.custom_minimum_size.y, 42.0))
	if _confirmation_option_checkbox != null:
		SurveyStyle.style_check_box(_confirmation_option_checkbox)

func _request_confirmation(title: String, body: String, confirm_label: String, on_confirm: Callable, is_destructive: bool = true) -> void:
	if _confirmation_dialog == null or not on_confirm.is_valid():
		return
	_pending_confirmation_action = on_confirm
	_pending_confirmation_option_action = Callable()
	_confirmation_dialog_is_destructive = is_destructive
	_confirmation_dialog.title = title.strip_edges() if not title.strip_edges().is_empty() else "Confirm Action"
	_confirmation_dialog.dialog_text = body.strip_edges()
	_reset_confirmation_dialog_option()
	var ok_button := _confirmation_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = confirm_label.strip_edges() if not confirm_label.strip_edges().is_empty() else "Confirm"
	var cancel_button := _confirmation_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.text = "Cancel"
	_refresh_confirmation_dialog_theme()
	_confirmation_dialog.popup_centered_ratio(0.34)

func _request_confirmation_with_checkbox(title: String, body: String, confirm_label: String, checkbox_text: String, checkbox_default: bool, on_confirm: Callable, is_destructive: bool = true) -> void:
	if _confirmation_dialog == null or not on_confirm.is_valid():
		return
	_pending_confirmation_action = Callable()
	_pending_confirmation_option_action = on_confirm
	_confirmation_dialog_is_destructive = is_destructive
	_confirmation_dialog.title = title.strip_edges() if not title.strip_edges().is_empty() else "Confirm Action"
	_confirmation_dialog.dialog_text = body.strip_edges()
	if _confirmation_option_checkbox != null:
		_confirmation_option_checkbox.visible = true
		_confirmation_option_checkbox.text = checkbox_text.strip_edges()
		_confirmation_option_checkbox.button_pressed = checkbox_default
	var ok_button := _confirmation_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = confirm_label.strip_edges() if not confirm_label.strip_edges().is_empty() else "Confirm"
	var cancel_button := _confirmation_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.text = "Cancel"
	_refresh_confirmation_dialog_theme()
	_confirmation_dialog.popup_centered_ratio(0.34)

func _reset_confirmation_dialog_option() -> void:
	if _confirmation_option_checkbox == null:
		return
	_confirmation_option_checkbox.visible = false
	_confirmation_option_checkbox.text = ""
	_confirmation_option_checkbox.button_pressed = false

func _on_confirmation_dialog_confirmed() -> void:
	var pending_action := _pending_confirmation_action
	var pending_option_action := _pending_confirmation_option_action
	var option_value := _confirmation_option_checkbox.button_pressed if _confirmation_option_checkbox != null else false
	_pending_confirmation_action = Callable()
	_pending_confirmation_option_action = Callable()
	_confirmation_dialog_is_destructive = true
	_reset_confirmation_dialog_option()
	if pending_option_action.is_valid():
		pending_option_action.call(option_value)
	elif pending_action.is_valid():
		pending_action.call()

func _on_confirmation_dialog_canceled() -> void:
	_pending_confirmation_action = Callable()
	_pending_confirmation_option_action = Callable()
	_confirmation_dialog_is_destructive = true
	_reset_confirmation_dialog_option()

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

func _featured_template_summary() -> Dictionary:
	if _available_templates.is_empty():
		return {}
	return (_available_templates[0] as Dictionary).duplicate(true)

func _is_single_survey_landing_active() -> bool:
	return bool(_featured_template_summary().get("single_survey_mode", false))

func _featured_template_path() -> String:
	return str(_featured_template_summary().get("path", "")).strip_edges()

func _featured_template_title() -> String:
	return str(_featured_template_summary().get("title", "Featured Survey")).strip_edges()

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
		_prime_gamification_trackers()
		_refresh_gamification_surfaces()
		return
	_load_survey_from_path(initial_path, false)

func _resolve_startup_template_path() -> String:
	var root := get_tree().root
	if root != null and root.has_meta("survey_journey_template_path"):
		var handed_off_path := str(root.get_meta("survey_journey_template_path", "")).strip_edges()
		root.remove_meta("survey_journey_template_path")
		if not handed_off_path.is_empty():
			return handed_off_path
	var featured_path := _featured_template_path()
	if _is_single_survey_landing_active() and not featured_path.is_empty():
		return featured_path
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
	_persist_current_session_cache()
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
	_focus_outline_bound_template_path = ""
	SURVEY_UPLOAD_AUDIT_STORE.record_template_load(_current_upload_template_key())
	answers = _sanitize_answers_for_survey_definition(survey, SURVEY_SESSION_CACHE.load_answers(survey, requested_path))
	var restored_session_state := _sanitize_session_state(SURVEY_SESSION_CACHE.load_session_state(survey, requested_path))
	if reset_answers and answers.is_empty():
		answers.clear()
	_restore_response_quality_tracking(restored_session_state, not answers.is_empty() or not restored_session_state.is_empty())
	_focus_start_section_index = 0
	_selected_section_index = 0 if not survey.sections.is_empty() else -1
	_focus_index = 0
	_playable_question_ids.clear()
	_focus_navigation_pending = false
	if is_node_ready():
		_focus_question_stage.reset()
		_reset_upload_form_state()
	_rebuild_question_order()
	_prime_gamification_trackers()
	_reset_upload_status(true)
	_refresh_all_views()
	_refresh_gamification_surfaces()
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
	SurveyStyle.apply_secondary_button(_character_button)
	SurveyStyle.apply_secondary_button(_browse_surveys_button)
	SurveyStyle.apply_secondary_button(_survey_selection_back_button)
	SurveyStyle.apply_secondary_button(_survey_selection_import_button)
	SurveyStyle.apply_secondary_button(_survey_selection_export_button)
	SurveyStyle.apply_danger_button(_survey_selection_clear_button)
	SurveyStyle.apply_primary_button(_survey_selection_next_button)
	_refresh_survey_selection_next_button_theme()
	SurveyStyle.apply_secondary_button(_lore_back_button)
	SurveyStyle.apply_secondary_button(_lore_link_button)
	SurveyStyle.apply_primary_button(_lore_take_survey_button)
	if _lore_link_prompt_close_button != null:
		SurveyStyle.apply_secondary_button(_lore_link_prompt_close_button)
	if _lore_link_prompt_copy_button != null:
		SurveyStyle.apply_secondary_button(_lore_link_prompt_copy_button)
	if _lore_link_prompt_open_button != null:
		SurveyStyle.apply_primary_button(_lore_link_prompt_open_button)
	SurveyStyle.apply_secondary_button(_section_selection_back_button)
	SurveyStyle.apply_primary_button(_section_selection_next_button)
	SurveyStyle.apply_secondary_button(_focus_back_button)
	_refresh_focus_outline_toggle_state()
	SurveyStyle.apply_secondary_button(_focus_previous_button)
	SurveyStyle.apply_primary_button(_focus_next_button)
	SurveyStyle.apply_secondary_button(_review_back_button)
	SurveyStyle.apply_secondary_button(_thanks_review_button)
	SurveyStyle.apply_primary_button(_thanks_export_button)
	SurveyStyle.apply_secondary_button(_export_back_button)
	SurveyStyle.apply_secondary_button(_upload_back_button)
	SurveyStyle.apply_primary_button(_export_upload_answers_button)
	SurveyStyle.apply_panel(_upload_notice_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 20, 1)
	SurveyStyle.style_check_box(_upload_scrub_checkbox)
	SurveyStyle.style_check_box(_upload_consent_checkbox)
	SurveyStyle.style_caption(_upload_scrub_summary_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_caption(_upload_disclosure_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_upload_status_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.apply_primary_button(_upload_submit_button)
	SurveyStyle.apply_secondary_button(_upload_copy_response_button)
	SurveyStyle.style_text_edit(_upload_response_text_edit)
	for button in [_export_json_button, _export_copy_json_button, _export_copy_csv_button, _export_csv_button]:
		SurveyStyle.apply_secondary_button(button)
	if _menu_access_button != null:
		SurveyStyle.apply_secondary_button(_menu_access_button)
		_menu_access_button.text = "☰"
		_menu_access_button.tooltip_text = "Open menu"
	if _help_access_button != null:
		SurveyStyle.apply_secondary_button(_help_access_button)
		_help_access_button.tooltip_text = "Open question help"
	SurveyStyle.style_caption(_landing_featured_survey_label, SurveyStyle.TEXT_PRIMARY)
	if not _playable_question_ids.is_empty():
		_rebuild_focus_question_stage()
	_refresh_all_views()
	_update_responsive_layout()
	if _overlay_menu != null:
		_overlay_menu.refresh_theme()
	if _help_overlay != null:
		_help_overlay.refresh_theme()
	if _profile_overlay != null:
		_profile_overlay.refresh_theme()
		var profile_save_label := "Download PNG" if _supports_browser_downloads() else "Save PNG"
		_profile_overlay.set_png_action_capabilities(SURVEY_PLATFORM_EXPORTS.supports_image_clipboard_copy(), profile_save_label)
	if _gamification_hud != null:
		_gamification_hud.refresh_theme()
	if _toast_overlay != null:
		_toast_overlay.refresh_theme()
	_refresh_theme_drawer()
	_refresh_lore_surface_theme(_is_phone_layout_for_size(get_viewport().get_visible_rect().size), SurveyStyle.journey_mobile_scale(get_viewport().get_visible_rect().size), get_viewport().get_visible_rect().size)
	_refresh_focus_xp_theme()
	if _focus_outline_panel != null:
		_focus_outline_panel.refresh_theme()
	_refresh_confirmation_dialog_theme()

func _refresh_survey_selection_next_button_theme() -> void:
	if _survey_selection_next_button == null:
		return
	var disabled_fill := SurveyStyle.ACCENT.lerp(SurveyStyle.SURFACE_MUTED, 0.72)
	var disabled_border := SurveyStyle.ACCENT.lerp(SurveyStyle.BORDER, 0.4)
	_survey_selection_next_button.add_theme_stylebox_override("disabled", SurveyStyle.panel(disabled_fill, disabled_border, 14, 0))
	_survey_selection_next_button.add_theme_color_override("font_disabled_color", SurveyStyle.SOFT_WHITE.lerp(SurveyStyle.TEXT_MUTED, 0.3))
	SurveyStyle.apply_text_outline(_survey_selection_next_button, 2)

func _update_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var compact_layout := _is_compact_layout_for_size(viewport_size)
	var shortest_side := minf(viewport_size.x, viewport_size.y)
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size)
	var panel_margin := 6 if phone_layout else int(clampf(minf(viewport_size.x, viewport_size.y) * 0.02, 12.0, 32.0))
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
	_review_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_thanks_view.add_theme_constant_override("separation", 14 if phone_layout else 18)
	_export_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_upload_view.add_theme_constant_override("separation", 12 if phone_layout else 14)
	_landing_actions.add_theme_constant_override("separation", 10 if phone_layout else 14)
	_main_panel.add_theme_stylebox_override("panel", _panel_style(SurveyStyle.SURFACE, SurveyStyle.BORDER, 18 if phone_layout else 30, 1, (12.0 if phone_layout else 24.0)))
	SurveyStyle.style_caption(_status_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_heading(_landing_heading_label, int(round((30 if phone_layout else 40) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_landing_subtitle_label)
	_landing_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	_landing_featured_survey_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_survey_selection_heading_label, int(round((24 if phone_layout else 28) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_survey_selection_subtitle_label)
	_survey_selection_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_lore_heading_label, int(round((24 if phone_layout else 28) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_lore_subtitle_label)
	_lore_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_caption(_lore_survey_label, SurveyStyle.TEXT_PRIMARY)
	_lore_survey_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	_refresh_lore_surface_theme(phone_layout, journey_scale, viewport_size)
	SurveyStyle.style_heading(_section_selection_heading_label, int(round((24 if phone_layout else 28) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_section_selection_subtitle_label)
	_section_selection_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_caption(_section_selection_survey_label, SurveyStyle.TEXT_PRIMARY)
	_section_selection_survey_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_focus_section_label, int(round((24 if phone_layout else 28) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_caption(_focus_progress_label, SurveyStyle.TEXT_PRIMARY)
	_focus_progress_label.add_theme_font_size_override("font_size", int(round((12 if phone_layout else 13) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_review_heading_label, int(round((24 if phone_layout else 28) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_review_subtitle_label)
	_review_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_thanks_heading_label, int(round((30 if phone_layout else 38) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_thanks_body_label)
	_thanks_body_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_export_heading_label, int(round((26 if phone_layout else 32) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_export_subtitle_label)
	SurveyStyle.style_body(_export_body_label)
	_export_body_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_export_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	_export_body_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_heading(_upload_heading_label, int(round((26 if phone_layout else 32) * (journey_scale if phone_layout else 1.0))))
	SurveyStyle.style_body(_upload_subtitle_label)
	SurveyStyle.style_body(_upload_body_label)
	_upload_body_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_upload_scrub_summary_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_upload_disclosure_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_upload_status_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_upload_subtitle_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	_upload_body_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	_upload_scrub_summary_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	_upload_disclosure_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	_upload_status_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	_upload_response_text_edit.custom_minimum_size = Vector2(0.0, clampf(viewport_size.y * (0.24 if phone_layout else 0.2), 120.0, 240.0))
	_survey_selection_grid.columns = 1 if viewport_size.x < 920.0 else 2
	_survey_selection_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 14)
	_survey_selection_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 14)
	_survey_selection_manage_grid.columns = 1 if viewport_size.x < 360.0 else 2
	_survey_selection_manage_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 12)
	_survey_selection_manage_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 12)
	_survey_selection_manage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	if viewport_size.x < 760.0:
		_section_selection_grid.columns = 1
	elif viewport_size.x < 1240.0:
		_section_selection_grid.columns = 2
	else:
		_section_selection_grid.columns = 3
	_section_selection_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 14)
	_section_selection_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 14)
	_export_action_grid.columns = 1 if phone_layout or viewport_size.x < 860.0 else 2
	_export_action_grid.add_theme_constant_override("h_separation", 10 if phone_layout else 12)
	_export_action_grid.add_theme_constant_override("v_separation", 10 if phone_layout else 12)
	for width_control in [_export_heading_label, _export_subtitle_label, _export_body_label, _upload_heading_label, _upload_subtitle_label, _upload_body_label, _upload_scrub_summary_label, _upload_disclosure_label, _upload_status_label]:
		if width_control == null:
			continue
		width_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_survey_selection_action_spacer.visible = not phone_layout
	_section_selection_action_spacer.visible = not phone_layout
	_focus_nav_spacer.visible = true
	_take_survey_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_get_lore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_browse_surveys_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_survey_selection_import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_survey_selection_export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_survey_selection_clear_button.size_flags_horizontal = 0
	_survey_selection_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_section_selection_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_focus_previous_button.size_flags_horizontal = 0
	_focus_next_button.size_flags_horizontal = 0
	if _focus_outline_toggle_button != null:
		_focus_outline_toggle_button.size_flags_horizontal = 0
	_review_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_thanks_review_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_thanks_export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_layout else 0
	_focus_question_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_focus_bottom_spacer.visible = false
	for button in [_take_survey_button, _get_lore_button, _character_button, _browse_surveys_button, _survey_selection_back_button, _survey_selection_import_button, _survey_selection_export_button, _survey_selection_clear_button, _survey_selection_next_button, _lore_back_button, _lore_take_survey_button, _lore_link_prompt_close_button, _lore_link_prompt_copy_button, _lore_link_prompt_open_button, _section_selection_back_button, _section_selection_next_button, _focus_back_button, _focus_previous_button, _focus_next_button, _review_back_button, _thanks_review_button, _thanks_export_button, _export_back_button, _export_json_button, _export_upload_answers_button, _export_copy_json_button, _export_copy_csv_button, _export_csv_button, _upload_back_button, _upload_submit_button, _upload_copy_response_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(button.custom_minimum_size.x if not phone_layout else 0.0, (56.0 * journey_scale) if phone_layout else maxf(button.custom_minimum_size.y, 44.0))
		button.add_theme_font_size_override("font_size", int(round((15 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	for manage_button in [_survey_selection_import_button, _survey_selection_export_button]:
		if manage_button == null:
			continue
		manage_button.custom_minimum_size = Vector2(0.0 if phone_layout else 118.0, (44.0 * journey_scale) if phone_layout else 34.0)
		manage_button.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 12) * (journey_scale if phone_layout else 1.0))))
	if _survey_selection_clear_button != null:
		_survey_selection_clear_button.custom_minimum_size = Vector2(0.0 if phone_layout else 118.0, (44.0 * journey_scale) if phone_layout else 34.0)
		_survey_selection_clear_button.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 12) * (journey_scale if phone_layout else 1.0))))
		_survey_selection_clear_button.visible = false
	if _lore_link_button != null:
		_lore_link_button.custom_minimum_size = Vector2((56.0 * journey_scale) if phone_layout else 52.0, (56.0 * journey_scale) if phone_layout else 52.0)
	_focus_back_button.custom_minimum_size.x = 0.0
	if _focus_outline_toggle_button != null:
		_focus_outline_toggle_button.custom_minimum_size = Vector2(0.0, (44.0 * journey_scale) if phone_layout else 40.0)
		_focus_outline_toggle_button.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 12) * (journey_scale if phone_layout else 1.0))))
	_focus_previous_button.custom_minimum_size.x = (88.0 * journey_scale) if phone_layout else 96.0
	_focus_next_button.custom_minimum_size.x = (88.0 * journey_scale) if phone_layout else 96.0
	_focus_segment_row.add_theme_constant_override("separation", 3 if phone_layout else 4)
	_refresh_focus_xp_layout(viewport_size)
	_refresh_focus_outline_layout(viewport_size)
	if _menu_access_button != null:
		var menu_button_size := (48.0 * journey_scale) if phone_layout else (42.0 if compact_layout else 48.0)
		_menu_access_button.custom_minimum_size = Vector2(menu_button_size, menu_button_size)
		_menu_access_button.add_theme_font_size_override("font_size", int(round((20 if phone_layout else 18) * (journey_scale if phone_layout else 1.0))))
		var menu_button_width := menu_button_size
		var menu_button_height := menu_button_size
		var menu_inset := clampf(shortest_side * 0.015, 8.0, 20.0)
		_menu_access_button.offset_left = -menu_button_width - menu_inset
		_menu_access_button.offset_top = menu_inset
		_menu_access_button.offset_right = -menu_inset
		_menu_access_button.offset_bottom = menu_inset + menu_button_height
		if _help_access_button != null:
			_help_access_button.custom_minimum_size = Vector2((46.0 * journey_scale) if phone_layout else 44.0, (46.0 * journey_scale) if phone_layout else 44.0)
			_help_access_button.add_theme_font_size_override("font_size", int(round((18 if phone_layout else 18) * (journey_scale if phone_layout else 1.0))))
			var help_gap := 8.0
			var help_button_size := menu_button_height
			_help_access_button.offset_left = -menu_button_width - help_button_size - menu_inset - help_gap
			_help_access_button.offset_top = menu_inset
			_help_access_button.offset_right = -menu_button_width - menu_inset - help_gap
			_help_access_button.offset_bottom = menu_inset + help_button_size
	call_deferred("_sync_scroll_content_widths")
	_refresh_focus_stage_layout()
	_refresh_menu_access_button()
	_refresh_theme_drawer()
	if _overlay_menu != null:
		_overlay_menu.refresh_layout(viewport_size)
	if _help_overlay != null:
		_help_overlay.refresh_layout(viewport_size)
	if _profile_overlay != null:
		_profile_overlay.refresh_layout(viewport_size)
	if _gamification_hud != null:
		_gamification_hud.refresh_layout(viewport_size)
	if _toast_overlay != null:
		_toast_overlay.refresh_layout(viewport_size)
	_refresh_gamification_surfaces()

func _refresh_all_views() -> void:
	_refresh_landing_view()
	_refresh_survey_selection_view()
	_refresh_lore_view()
	_refresh_section_selection_view()
	_refresh_focus_view(false)
	_refresh_focus_outline_state()
	_refresh_review_view()
	_refresh_thanks_view()
	_refresh_export_view()
	_refresh_upload_view()
	_refresh_theme_drawer()

func _show_view(view_name: StringName) -> void:
	if view_name != VIEW_FOCUS:
		_close_question_help()
		_set_focus_outline_visible(false)
	if view_name != VIEW_LORE:
		_close_lore_link_prompt()
	_current_view = view_name
	_landing_view.visible = view_name == VIEW_LANDING
	_survey_selection_view.visible = view_name == VIEW_SURVEY_SELECTION
	_lore_view.visible = view_name == VIEW_LORE
	_section_selection_view.visible = view_name == VIEW_SECTION_SELECTION
	_focus_view.visible = view_name == VIEW_FOCUS
	_review_view.visible = view_name == VIEW_REVIEW
	_thanks_view.visible = view_name == VIEW_THANKS
	_export_view.visible = view_name == VIEW_EXPORT
	_upload_view.visible = view_name == VIEW_UPLOAD
	match view_name:
		VIEW_LANDING:
			_refresh_landing_view()
		VIEW_SURVEY_SELECTION:
			_refresh_survey_selection_view()
		VIEW_LORE:
			_refresh_lore_view()
		VIEW_SECTION_SELECTION:
			_refresh_section_selection_view()
		VIEW_FOCUS:
			_refresh_focus_view(true)
			_refresh_focus_outline_state()
		VIEW_REVIEW:
			_refresh_review_view()
		VIEW_THANKS:
			_refresh_thanks_view()
		VIEW_EXPORT:
			_refresh_export_view()
		VIEW_UPLOAD:
			_refresh_upload_view()
	call_deferred("_sync_scroll_content_widths")
	_refresh_menu_access_button()
	_refresh_theme_drawer()
	_refresh_gamification_surfaces()

func _sync_scroll_content_widths() -> void:
	_sync_scroll_content_width(_export_scroll, _export_content)
	_sync_scroll_content_width(_upload_scroll, _upload_content)

func _sync_scroll_content_width(scroll: ScrollContainer, content: Control) -> void:
	if scroll == null or content == null:
		return
	var target_width := maxf(scroll.size.x - 2.0, 0.0)
	if target_width <= 0.0:
		return
	content.custom_minimum_size = Vector2(target_width, content.custom_minimum_size.y)

func _refresh_landing_view() -> void:
	var single_survey_mode_active := _is_single_survey_landing_active()
	if single_survey_mode_active:
		_landing_heading_label.text = "Start Survey"
		_landing_subtitle_label.text = "This build is featuring a single playtest survey first, so you can jump straight into the opening question flow or check your Character."
		_take_survey_button.text = "Start Survey"
		_get_lore_button.text = "Get Lore"
		_character_button.text = "Character"
		_character_button.tooltip_text = "Open your social profile with stats, titles, and accolades."
		_browse_surveys_button.text = "Browse Other Surveys"
		_browse_surveys_button.visible = true
		_landing_featured_survey_label.visible = true
		_landing_featured_survey_label.text = "Featured survey: %s" % _featured_template_title()
		return
	_landing_heading_label.text = "Choose Your Path"
	_landing_subtitle_label.text = "Jump into a survey, browse the lore first, open your Character, or explore the full template list."
	_take_survey_button.text = "Take Survey"
	_get_lore_button.text = "Get Lore"
	_character_button.text = "Character"
	_character_button.tooltip_text = "Open your social profile with stats, titles, and accolades."
	_browse_surveys_button.visible = false
	_landing_featured_survey_label.visible = false
	_landing_featured_survey_label.text = ""

func _refresh_menu_access_button() -> void:
	if _menu_access_layer == null:
		return
	var overlay_blocking: bool = (_overlay_menu != null and _overlay_menu.visible) or (_help_overlay != null and _help_overlay.visible) or (_profile_overlay != null and _profile_overlay.visible) or (_lore_link_prompt_overlay != null and _lore_link_prompt_overlay.visible)
	var can_show_access := not overlay_blocking
	if _menu_access_button != null:
		_menu_access_button.visible = can_show_access
	var help_available := _current_view == VIEW_FOCUS and _current_focus_question() != null
	if _help_access_button != null:
		_help_access_button.visible = false and can_show_access and help_available
	_menu_access_layer.visible = can_show_access and (_menu_access_button != null and _menu_access_button.visible)

func _open_overlay_menu() -> void:
	if _overlay_menu == null or survey == null:
		return
	_set_focus_outline_visible(false)
	_close_question_help()
	_close_profile_overlay()
	_overlay_menu.open_menu(survey, _menu_section_index(), answers, sfx_volume, true, _journey_menu_options())
	_refresh_menu_access_button()

func _close_overlay_menu() -> void:
	if _overlay_menu == null:
		return
	_overlay_menu.close_menu()
	_refresh_menu_access_button()

func _refresh_overlay_menu_if_open() -> void:
	if _overlay_menu == null or survey == null or not _overlay_menu.visible:
		return
	_overlay_menu.open_menu(survey, _menu_section_index(), answers, sfx_volume, false, _journey_menu_options())

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
		"profile_label": "Social Profile",
		"export_label": "Open Export Screen",
		"section_heading_text": "Jump To Or Clear A Section",
		"position_text": _journey_menu_position_text(),
		"show_search": false,
		"show_onboarding": false,
		"show_template_picker": false,
		"show_settings": false,
		"summary_label": "Review Answers",
		"show_summary": survey != null,
		"show_profile": true,
		"show_fill_test_answers": false,
		"show_export": survey != null,
		"show_theme_toggle": true,
		"show_sfx_controls": true,
		"show_section_tools": survey != null,
		"show_preview_controls": true,
		"preview_mode_options": _preview_mode_option_dictionaries(),
		"preview_mode": _preview_mode_override,
		"preview_resolution_options": _preview_resolution_option_dictionaries(),
		"preview_resolution": _preview_resolution_preset,
		"question_debug_ids": _question_debug_ids_enabled
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
		VIEW_REVIEW:
			return "Reviewing answers across %s before jumping back into focus mode." % survey.title
		VIEW_THANKS:
			return "You have reached the thank-you screen for %s." % survey.title
		VIEW_EXPORT:
			return "You are on the export screen for %s." % survey.title
		VIEW_UPLOAD:
			return "You are on the upload handoff screen for %s." % survey.title
	var current_question_id := _current_focus_question_id()
	var section_index := _section_index_for_question_id(current_question_id)
	var answered_total := 0
	for question_id in _question_order:
		var question := _question_definition(question_id)
		if question != null and question.is_answer_complete(answers.get(question_id, null)):
			answered_total += 1
	return "Currently viewing section %d of %d. %d answered so far." % [clampi(section_index + 1, 1, max(survey.sections.size(), 1)), survey.sections.size(), answered_total]

func _normalized_preview_mode(raw_mode: String) -> String:
	return SURVEY_PREVIEW_CONFIG.normalized_mode(raw_mode)

func _normalized_preview_resolution_id(raw_id: String) -> String:
	return SURVEY_PREVIEW_CONFIG.normalized_resolution_id(raw_id)

func _preview_mode_option_dictionaries() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option in SURVEY_PREVIEW_CONFIG.preview_mode_options():
		options.append({
			"value": str(option.get("id", SURVEY_PREVIEW_CONFIG.MODE_AUTO)),
			"label": str(option.get("label", "Auto"))
		})
	return options

func _preview_resolution_option_dictionaries() -> Array[Dictionary]:
	var options: Array[Dictionary] = [{
		"value": "",
		"label": "Current Window"
	}]
	for preset in SURVEY_PREVIEW_CONFIG.resolution_presets():
		options.append({
			"value": str(preset.get("id", "")),
			"label": str(preset.get("label", ""))
		})
	return options

func _effective_preview_mode(viewport_size: Vector2) -> String:
	match _preview_mode_override:
		SURVEY_PREVIEW_CONFIG.MODE_MOBILE:
			return SURVEY_PREVIEW_CONFIG.MODE_MOBILE
		SURVEY_PREVIEW_CONFIG.MODE_DESKTOP:
			return SURVEY_PREVIEW_CONFIG.MODE_DESKTOP
	return SURVEY_PREVIEW_CONFIG.MODE_MOBILE if viewport_size.x <= 480.0 else SURVEY_PREVIEW_CONFIG.MODE_DESKTOP

func _on_take_survey_pressed() -> void:
	if _start_featured_survey_from_landing():
		return
	_open_survey_browser()

func _open_survey_browser() -> void:
	_selection_purpose = PURPOSE_SURVEY
	_selected_template_path = ""
	_show_view(VIEW_SURVEY_SELECTION)

func _on_get_lore_pressed() -> void:
	if _open_featured_lore_from_landing():
		return
	_selection_purpose = PURPOSE_LORE
	_selected_template_path = ""
	_show_view(VIEW_SURVEY_SELECTION)

func _start_featured_survey_from_landing() -> bool:
	if not _is_single_survey_landing_active():
		return false
	var featured_path := _featured_template_path()
	if featured_path.is_empty():
		return false
	if not _load_survey_from_path(featured_path, false):
		return true
	_selection_purpose = PURPOSE_SURVEY
	_section_selection_return_view = VIEW_LANDING
	if survey == null or survey.sections.is_empty():
		_show_status_message("The featured survey does not contain any sections yet.", true)
		return true
	_start_focus_from_section(0, "")
	return true

func _open_featured_lore_from_landing() -> bool:
	if not _is_single_survey_landing_active():
		return false
	var featured_path := _featured_template_path()
	if featured_path.is_empty():
		return false
	if not _load_survey_from_path(featured_path, false):
		return true
	_selection_purpose = PURPOSE_LORE
	_lore_return_view = VIEW_LANDING
	_show_view(VIEW_LORE)
	return true

func _on_menu_restart_requested() -> void:
	_close_overlay_menu()
	_clear_all_answers()

func _on_menu_clear_section_requested(section_index: int) -> void:
	_clear_section_answers(section_index)

func _on_menu_jump_to_section_requested(section_index: int) -> void:
	_close_overlay_menu()
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return
	_start_focus_from_section(section_index, "")

func _on_menu_review_requested() -> void:
	_close_overlay_menu()
	_open_review_view()

func _on_menu_export_requested() -> void:
	_close_overlay_menu()
	_open_export_overlay()

func _on_theme_drawer_theme_selected(theme_id: String) -> void:
	var resolved_theme_id := theme_id.strip_edges().to_lower()
	if resolved_theme_id.is_empty() or _selected_theme_id == resolved_theme_id:
		return
	_selected_theme_id = resolved_theme_id
	_apply_selected_theme_palette()
	_refresh_theme()
	_persist_preferences()
	var active_theme = _selected_theme_set()
	_show_status_message("Theme set to %s." % (active_theme.display_title() if active_theme != null else "the selected palette"))

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

func _on_menu_preview_mode_requested(mode: String) -> void:
	var resolved_mode := _normalized_preview_mode(mode)
	if _preview_mode_override == resolved_mode:
		return
	_preview_mode_override = resolved_mode
	_update_responsive_layout()
	_refresh_overlay_menu_if_open()
	_show_status_message("Journey preview mode set to %s." % ("auto" if resolved_mode == SURVEY_PREVIEW_CONFIG.MODE_AUTO else resolved_mode).capitalize())

func _on_menu_preview_resolution_requested(resolution_id: String) -> void:
	_apply_preview_resolution_preset(resolution_id)
	_refresh_overlay_menu_if_open()

func _on_menu_question_debug_ids_requested(enabled: bool) -> void:
	if _question_debug_ids_enabled == enabled:
		return
	_question_debug_ids_enabled = enabled
	if _focus_question_stage != null:
		_focus_question_stage.set_question_debug_ids_enabled(enabled)
	_refresh_question_help_overlay()
	_refresh_overlay_menu_if_open()
	_show_status_message("Journey question chrome now shows %s." % ("IDs" if enabled else "types"))

func _set_question_modifiers_enabled(enabled: bool) -> void:
	if _question_modifiers_enabled == enabled:
		return
	_question_modifiers_enabled = enabled
	if _focus_question_stage != null:
		_focus_question_stage.set_question_modifiers_enabled(enabled)

func _on_focus_modifier_fatigue_detected(_question_id: String, _modifier_key: String, message: String) -> void:
	if not _question_modifiers_enabled:
		return
	_set_question_modifiers_enabled(false)
	_show_modifier_restore_toast(message)

func _show_modifier_restore_toast(message: String) -> void:
	if _toast_overlay == null:
		return
	var resolved_message := message.strip_edges()
	if resolved_message.is_empty():
		resolved_message = "Question modifiers were paused for this run. You can turn them back on any time."
	_toast_overlay.show_toast(resolved_message, "modifier", "restore_question_modifiers", "Turn Modifiers Back On", true)

func _on_toast_overlay_action_requested(action_id: String) -> void:
	if action_id != "restore_question_modifiers":
		return
	_set_question_modifiers_enabled(true)
	if _toast_overlay != null:
		_toast_overlay.show_toast("Question modifiers are back on for this run.", "success")

func _apply_preview_resolution_preset(resolution_id: String) -> void:
	var normalized_id := _normalized_preview_resolution_id(resolution_id)
	_preview_resolution_preset = normalized_id
	if normalized_id.is_empty():
		_update_responsive_layout()
		_show_status_message("Using the current window size for Journey preview.")
		return
	if _is_web_platform() or OS.has_feature("mobile"):
		_update_responsive_layout()
		_show_status_message("Window presets are only available in desktop/editor builds.")
		return
	var preview_window := get_window()
	if preview_window == null:
		return
	var preview_size := SURVEY_PREVIEW_CONFIG.resolution_size(normalized_id)
	if preview_size == Vector2i.ZERO:
		return
	preview_window.mode = Window.MODE_WINDOWED
	preview_window.size = preview_size
	_show_status_message("Journey preview window set to %s." % SURVEY_PREVIEW_CONFIG.resolution_label(normalized_id))
	call_deferred("_update_responsive_layout")

func _current_focus_question() -> SurveyQuestion:
	return _question_definition(_current_focus_question_id())

func _open_question_help() -> void:
	if _help_overlay == null or _current_view != VIEW_FOCUS:
		return
	var question := _current_focus_question()
	if question == null:
		_show_status_message("No question help is available yet.", true)
		return
	_set_focus_outline_visible(false)
	_close_overlay_menu()
	_help_overlay.open_help(question, _question_debug_ids_enabled)
	_refresh_menu_access_button()

func _on_focus_help_requested(question_id: String) -> void:
	if question_id.is_empty():
		return
	var requested_index := _playable_question_ids.find(question_id)
	if requested_index != -1:
		_focus_index = requested_index
	_open_question_help()

func _close_question_help() -> void:
	if _help_overlay != null:
		_help_overlay.close_help()
	_refresh_menu_access_button()

func _refresh_question_help_overlay() -> void:
	if _help_overlay == null or not _help_overlay.visible:
		_refresh_menu_access_button()
		return
	var question := _current_focus_question()
	if question == null:
		_close_question_help()
		return
	_help_overlay.open_help(question, _question_debug_ids_enabled)
	_refresh_menu_access_button()

func _clear_all_answers() -> void:
	answers.clear()
	_restore_response_quality_tracking({}, false)
	if survey != null and not _current_template_path.is_empty():
		SURVEY_SESSION_CACHE.clear_session(survey, _current_template_path)
	if _focus_question_stage != null:
		_focus_question_stage.sync_answers(answers)
	_prime_gamification_trackers()
	_refresh_all_views()
	_refresh_gamification_surfaces()
	if _current_view == VIEW_FOCUS and not _playable_question_ids.is_empty():
		_refresh_focus_view(true)
	_refresh_overlay_menu_if_open()
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
	_persist_current_session_cache()
	_prime_gamification_trackers()
	_refresh_all_views()
	_refresh_gamification_surfaces()
	if _current_view == VIEW_FOCUS and not _playable_question_ids.is_empty():
		_refresh_focus_view(true)
	_refresh_overlay_menu_if_open()
	_show_status_message("Cleared %d answer(s) from %s." % [cleared_count, survey.sections[section_index].display_title(section_index)])

func _refresh_survey_selection_view() -> void:
	_survey_selection_heading_label.text = "Choose Survey" if _selection_purpose == PURPOSE_SURVEY else "Choose Your Lore Thread"
	_survey_selection_subtitle_label.text = "Pick a survey" if _selection_purpose == PURPOSE_SURVEY else "Pick a survey to browse its framing, themes, and sections before you dive in."
	_survey_selection_next_button.text = "DIVE IN!" if _selection_purpose == PURPOSE_SURVEY else "Open Lore"
	_survey_selection_import_button.text = "Import"
	_survey_selection_export_button.text = "Export"
	_clear_container(_survey_selection_grid)
	_survey_selection_import_button.disabled = not _supports_template_import()
	_survey_selection_import_button.tooltip_text = "Import a packaged survey template JSON." if _supports_template_import() else "This build cannot open a template picker right now."
	if _available_templates.is_empty():
		_selected_template_path = ""
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No survey templates were found."
		SurveyStyle.style_body(empty_label)
		_survey_selection_grid.add_child(empty_label)
		_survey_selection_next_button.disabled = true
		_survey_selection_export_button.disabled = true
		_survey_selection_clear_button.disabled = true
		_survey_selection_next_button.tooltip_text = "Import or add a survey template first."
		_survey_selection_export_button.tooltip_text = "Select a survey with saved answers to export."
		return
	if not _selected_template_path.is_empty() and not _has_template_path(_selected_template_path):
		_selected_template_path = ""
	_survey_selection_next_button.disabled = _selected_template_path.is_empty()
	_survey_selection_next_button.tooltip_text = "Select a survey to continue." if _survey_selection_next_button.disabled else ""
	var selected_template_state := _template_selection_state(_selected_template_path) if not _selected_template_path.is_empty() else {}
	_survey_selection_export_button.disabled = _selected_template_path.is_empty() or not bool(selected_template_state.get("has_saved_answers", false))
	_survey_selection_export_button.tooltip_text = "Select a survey with saved answers to export." if _survey_selection_export_button.disabled else "Open the export flow for the selected survey."
	_survey_selection_clear_button.disabled = _selected_template_path.is_empty() or not bool(selected_template_state.get("has_saved_answers", false))
	for template_summary in _available_templates:
		var template_path := str(template_summary.get("path", "")).strip_edges()
		var title := str(template_summary.get("title", "Survey")).strip_edges()
		var description := str(template_summary.get("description", "")).strip_edges()
		var template_state := _template_selection_state(template_path)
		var answered_count := int(template_state.get("answered_count", 0))
		var total_sections := int(template_state.get("total_sections", 0))
		var total_questions := int(template_state.get("total_questions", 0))
		var stored_count := int(template_state.get("stored_count", 0))
		var source_label := str(template_summary.get("source_label", "Template")).strip_edges()
		var card := _create_template_selection_card(
			SURVEY_ICON_LIBRARY.section_texture("generic"),
			title,
			description if not description.is_empty() else "Choose this survey to continue.",
			source_label,
			max(total_sections, 0),
			max(total_questions, 0),
			answered_count,
			stored_count,
			bool(template_state.get("has_saved_answers", false)),
			template_path == _selected_template_path,
			template_path
		)
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
		_section_selection_return_view = VIEW_SURVEY_SELECTION
		if survey == null or survey.sections.is_empty():
			_show_status_message("This survey does not contain any sections yet.", true)
			return
		_start_focus_from_section(0, "")
	else:
		_lore_return_view = VIEW_SURVEY_SELECTION
		_show_view(VIEW_LORE)

func _export_selected_template_answers() -> void:
	if _selected_template_path.is_empty():
		_show_status_message("Choose a survey first.", true)
		return
	var template_state := _template_selection_state(_selected_template_path)
	if not bool(template_state.get("has_saved_answers", false)):
		_show_status_message("That survey does not have any saved answers yet.", true)
		return
	if not _load_survey_from_path(_selected_template_path, true):
		return
	_export_return_view = VIEW_SURVEY_SELECTION
	_show_view(VIEW_EXPORT)

func _open_template_export_workflow() -> void:
	if _selected_template_path.is_empty():
		_show_status_message("Select a survey before opening export.", true)
		return
	var template_state := _template_selection_state(_selected_template_path)
	if not bool(template_state.get("has_saved_answers", false)):
		_show_status_message("That survey does not have any saved answers yet.", true)
		return
	var template_summary := _template_summary_for_path(_selected_template_path)
	var survey_name := str(template_summary.get("title", "this survey")).strip_edges()
	_request_confirmation(
		"Export Answers",
		"Export opens the answer screen for %s.\n\nFrom there you can save JSON or CSV, copy the bundle, or continue to the upload flow." % survey_name,
		"Continue",
		_export_selected_template_answers,
		false
	)

func _confirm_clear_selected_template_answers() -> void:
	_confirm_clear_template_answers(_selected_template_path)

func _clear_selected_template_answers() -> void:
	_clear_template_answers_for_path(false, _selected_template_path)

func _supports_template_import() -> bool:
	if _is_web_platform():
		return Engine.has_singleton("JavaScriptBridge")
	return _template_dialog != null

func _open_template_import_workflow() -> void:
	if not _supports_template_import():
		_show_status_message("Template import is unavailable in this build.", true)
		return
	_request_confirmation(
		"Import Survey",
		"Import adds a packaged survey template JSON to this device so it appears in the survey browser.\n\nThe file is checked before it is added.",
		"Choose File",
		_open_template_import_picker,
		false
	)

func _open_template_import_picker() -> void:
	if _is_web_platform():
		if not _open_web_template_import_picker():
			_show_status_message("This browser build could not open a template picker.", true)
		return
	if _template_dialog == null:
		_show_status_message("Template import is unavailable in this build.", true)
		return
	_template_dialog.title = "Import Survey Template"
	_template_dialog.clear_filters()
	_template_dialog.add_filter("*.json", "JSON Files")
	_template_dialog.current_path = ProjectSettings.globalize_path(SURVEY_TEMPLATE_LOADER.user_template_directory())
	_template_dialog.popup_centered_ratio(0.8)

func _import_template_from_path(raw_path: String) -> bool:
	var requested_path := _normalize_template_path_input(raw_path)
	if requested_path.is_empty():
		_show_status_message("No survey template was selected.", true)
		return false
	var report := SURVEY_TEMPLATE_LOADER.import_template_file(requested_path)
	return _finish_template_import(report, requested_path.get_file())

func _import_template_from_text(source_text: String, source_name: String) -> bool:
	var report := SURVEY_TEMPLATE_LOADER.import_template_json_text(source_text, source_name)
	return _finish_template_import(report, source_name)

func _finish_template_import(report: Dictionary, source_name: String) -> bool:
	if not bool(report.get("ok", false)):
		var errors := _messages_from_variant(report.get("errors", PackedStringArray()))
		_show_status_message(errors[0] if not errors.is_empty() else "Failed to import %s." % source_name, true)
		return false
	_load_available_templates()
	var imported_path := str(report.get("path", "")).strip_edges()
	if not imported_path.is_empty():
		_selected_template_path = imported_path
	_show_view(VIEW_SURVEY_SELECTION)
	_show_status_message("Imported survey template %s." % source_name)
	return true

func _confirm_clear_template_answers(template_path: String) -> void:
	var normalized_path := template_path.strip_edges()
	if normalized_path.is_empty():
		_show_status_message("Select a survey first.", true)
		return
	var template_survey := SURVEY_TEMPLATE_LOADER.load_from_file(normalized_path)
	if template_survey == null:
		_show_status_message("Failed to load the selected survey.", true)
		return
	var survey_name := template_survey.title.strip_edges()
	if survey_name.is_empty():
		survey_name = str(_template_summary_for_path(normalized_path).get("title", "this survey")).strip_edges()
	if survey_name.is_empty():
		survey_name = "this survey"
	_request_confirmation_with_checkbox(
		"Clear Saved Answers",
		"Delete the local saved answers for %s?\n\nLeave the checkbox off to make a backup JSON first so you can change your mind later." % survey_name,
		"Clear Answers",
		"Delete permanently and skip the backup",
		false,
		_clear_template_answers_for_path.bind(normalized_path),
		true
	)

func _clear_template_answers_for_path(skip_backup: bool, template_path: String) -> void:
	var normalized_path := template_path.strip_edges()
	if normalized_path.is_empty():
		_show_status_message("Select a survey first.", true)
		return
	var template_survey := SURVEY_TEMPLATE_LOADER.load_from_file(normalized_path)
	if template_survey == null:
		_show_status_message("Failed to load the selected survey.", true)
		return
	var backup_report: Dictionary = {}
	if not skip_backup:
		backup_report = _backup_template_session(template_survey, normalized_path)
		if not bool(backup_report.get("ok", false)):
			_show_status_message(str(backup_report.get("message", "Failed to back up the saved answers.")).strip_edges(), true)
			return
	SURVEY_SESSION_CACHE.clear_session(template_survey, normalized_path)
	if survey != null and _current_template_path == normalized_path:
		answers.clear()
		_restore_response_quality_tracking({}, false)
		if _focus_question_stage != null:
			_focus_question_stage.sync_answers(answers)
	_prime_gamification_trackers()
	_refresh_all_views()
	_refresh_gamification_surfaces()
	var status_message := "Cleared saved answers for %s." % template_survey.title
	var backup_message := str(backup_report.get("message", "")).strip_edges()
	if not backup_message.is_empty():
		status_message += " %s" % backup_message
	_show_status_message(status_message)

func _template_summary_for_path(template_path: String) -> Dictionary:
	var normalized_path := template_path.strip_edges()
	if normalized_path.is_empty():
		return {}
	for template_summary in _available_templates:
		if str(template_summary.get("path", "")).strip_edges() == normalized_path:
			return (template_summary as Dictionary).duplicate(true)
	var template_survey := SURVEY_TEMPLATE_LOADER.load_from_file(normalized_path)
	if template_survey == null:
		return {"path": normalized_path}
	return {
		"path": normalized_path,
		"title": template_survey.title,
		"description": template_survey.description,
		"source_label": "Template"
	}

func _template_session_snapshot(template_survey: SurveyDefinition, template_path: String) -> Dictionary:
	var normalized_path := template_path.strip_edges()
	if template_survey == null or normalized_path.is_empty():
		return {
			"answers": {},
			"preferences": {},
			"session_state": {}
		}
	if survey != null and _current_template_path == normalized_path and survey.id == template_survey.id:
		return {
			"answers": answers.duplicate(true),
			"preferences": _current_preferences(),
			"session_state": _current_session_state()
		}
	var session_payload := SURVEY_SESSION_CACHE.load_session(template_survey, normalized_path)
	var cached_answers_value: Variant = session_payload.get("answers", {})
	var cached_answers: Dictionary = cached_answers_value as Dictionary if cached_answers_value is Dictionary else {}
	var preferences_value: Variant = session_payload.get("preferences", {})
	var preferences_payload: Dictionary = preferences_value as Dictionary if preferences_value is Dictionary else {}
	var session_state_value: Variant = session_payload.get("session_state", {})
	var session_state_payload: Dictionary = session_state_value as Dictionary if session_state_value is Dictionary else {}
	return {
		"answers": _sanitize_answers_for_survey_definition(template_survey, cached_answers),
		"preferences": preferences_payload.duplicate(true),
		"session_state": session_state_payload.duplicate(true)
	}

func _backup_template_session(template_survey: SurveyDefinition, template_path: String) -> Dictionary:
	if template_survey == null:
		return {
			"ok": false,
			"message": "Failed to load the selected survey for backup."
		}
	var snapshot := _template_session_snapshot(template_survey, template_path)
	var backup_text := SURVEY_SAVE_BUNDLE.build_json_text(
		template_survey,
		template_path,
		snapshot.get("answers", {}),
		snapshot.get("preferences", {}),
		snapshot.get("session_state", {})
	)
	if backup_text.strip_edges().is_empty():
		return {
			"ok": false,
			"message": "Failed to build the backup JSON."
		}
	var survey_segment := _safe_backup_segment(template_survey.title if not template_survey.title.strip_edges().is_empty() else template_survey.id)
	var backup_file := "%s_backup_%d.json" % [survey_segment, int(Time.get_unix_time_from_system())]
	if _supports_browser_downloads():
		if _download_buffer_to_browser(backup_text.to_utf8_buffer(), backup_file, "Backup JSON download started."):
			return {
				"ok": true,
				"message": "Backup JSON download started."
			}
		return {
			"ok": false,
			"message": "Failed to start the backup download."
		}
	var backup_dir := ProjectSettings.globalize_path(SURVEY_BACKUP_DIR)
	var ensure_error := DirAccess.make_dir_recursive_absolute(backup_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(backup_dir):
		return {
			"ok": false,
			"message": "Failed to prepare the backup folder."
		}
	var backup_path := "%s/%s" % [backup_dir.trim_suffix("/"), backup_file]
	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"message": "Failed to write the backup file."
		}
	file.store_string(backup_text)
	file.close()
	return {
		"ok": true,
		"message": "Backup saved to %s." % backup_path
	}

func _safe_backup_segment(raw_value: String) -> String:
	var value := raw_value.to_lower().strip_edges()
	if value.is_empty():
		return "survey"
	for token in ["/", "\\", ":", ".", " ", "-", "(", ")", "[", "]"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	while value.begins_with("_"):
		value = value.substr(1)
	while value.ends_with("_"):
		value = value.left(value.length() - 1)
	return value if not value.is_empty() else "survey"

func _template_selection_state(template_path: String) -> Dictionary:
	var normalized_path := template_path.strip_edges()
	if normalized_path.is_empty():
		return {
			"total_sections": 0,
			"total_questions": 0,
			"stored_count": 0,
			"answered_count": 0,
			"has_saved_answers": false
		}
	var template_survey := SURVEY_TEMPLATE_LOADER.load_from_file(normalized_path)
	if template_survey == null:
		return {
			"total_sections": 0,
			"total_questions": 0,
			"stored_count": 0,
			"answered_count": 0,
			"has_saved_answers": false
		}
	var cached_answers := _sanitize_answers_for_survey_definition(template_survey, SURVEY_SESSION_CACHE.load_answers(template_survey, normalized_path))
	var answered_count := 0
	for section in template_survey.sections:
		for question in section.questions:
			if question.is_answer_complete(cached_answers.get(question.id, null)):
				answered_count += 1
	return {
		"total_sections": template_survey.sections.size(),
		"total_questions": template_survey.total_questions(),
		"stored_count": cached_answers.size(),
		"answered_count": answered_count,
		"has_saved_answers": not cached_answers.is_empty()
	}

func _refresh_lore_view() -> void:
	_lore_heading_label.text = "Get Lore"
	_lore_subtitle_label.text = ""
	if survey == null:
		_lore_survey_label.text = "No survey is loaded yet."
		_lore_empty_label.text = "There is no lore at this time."
		_lore_link_button.visible = false
		_lore_link_button.disabled = true
		_lore_take_survey_button.disabled = true
		_close_lore_link_prompt()
		return
	_lore_take_survey_button.disabled = false
	_lore_survey_label.text = survey.title
	_lore_empty_label.text = "There is no lore at this time."
	var lore_url := _current_lore_url()
	_lore_link_button.visible = not lore_url.is_empty()
	_lore_link_button.disabled = lore_url.is_empty()
	_lore_link_button.tooltip_text = "Open or copy %s" % _current_lore_url_label()
	_refresh_lore_link_prompt()
	if lore_url.is_empty():
		_close_lore_link_prompt()

func _on_lore_back_pressed() -> void:
	_show_view(_lore_return_view)

func _on_lore_take_survey_pressed() -> void:
	_selection_purpose = PURPOSE_SURVEY
	_section_selection_return_view = _lore_return_view
	if survey == null or survey.sections.is_empty():
		_show_status_message("This survey does not contain any sections yet.", true)
		return
	_start_focus_from_section(0, "")

func _current_lore_url() -> String:
	if survey == null:
		return ""
	return survey.lore_url.strip_edges()

func _current_lore_url_label() -> String:
	if survey == null:
		return "associated URL"
	var label := survey.lore_url_label.strip_edges()
	if not label.is_empty():
		return label
	return "associated URL"

func _open_lore_link_prompt() -> void:
	if _lore_link_prompt_overlay == null:
		return
	var lore_url := _current_lore_url()
	if lore_url.is_empty():
		_show_status_message("No lore URL is associated with this survey yet.", true)
		return
	_refresh_lore_link_prompt()
	_lore_link_prompt_overlay.visible = true
	_refresh_menu_access_button()

func _close_lore_link_prompt() -> void:
	if _lore_link_prompt_overlay != null:
		_lore_link_prompt_overlay.visible = false
	_refresh_menu_access_button()

func _refresh_lore_link_prompt() -> void:
	if _lore_link_prompt_heading_label == null or _lore_link_prompt_body_label == null:
		return
	var lore_url := _current_lore_url()
	if lore_url.is_empty():
		_lore_link_prompt_heading_label.text = "Open Lore URL"
		_lore_link_prompt_body_label.text = "No lore URL is associated with this survey yet."
		return
	var survey_title := survey.title.strip_edges() if survey != null else "this survey"
	_lore_link_prompt_heading_label.text = "Open %s" % _current_lore_url_label()
	_lore_link_prompt_body_label.text = "Open the associated URL for %s in your browser, or copy it to the clipboard instead.\n\n%s" % [survey_title, lore_url]

func _copy_current_lore_url_to_clipboard() -> void:
	var lore_url := _current_lore_url()
	if lore_url.is_empty():
		_show_status_message("No lore URL is associated with this survey yet.", true)
		return
	DisplayServer.clipboard_set(lore_url)
	_close_lore_link_prompt()
	_show_status_message("%s copied to the clipboard." % _current_lore_url_label())

func _open_current_lore_url() -> void:
	var lore_url := _current_lore_url()
	if lore_url.is_empty():
		_show_status_message("No lore URL is associated with this survey yet.", true)
		return
	var open_error: Error = OS.shell_open(lore_url)
	_close_lore_link_prompt()
	if open_error == OK:
		_show_status_message("%s opened." % _current_lore_url_label())
		return
	_show_status_message("Failed to open the associated URL.", true)

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

func _on_section_selection_back_pressed() -> void:
	_show_view(_section_selection_return_view)

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
	_focus_back_button.text = "Back"
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
	_refresh_focus_outline_state()
	_refresh_question_help_overlay()

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
	_focus_question_stage.set_question_debug_ids_enabled(_question_debug_ids_enabled)
	_focus_question_stage.set_question_modifiers_enabled(_question_modifiers_enabled)

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
	var max_scroll_height := maxf(viewport_size.y - reserved_height - (16.0 if _is_phone_layout_for_size(viewport_size) else 56.0), 180.0)
	if _is_phone_layout_for_size(viewport_size):
		max_scroll_height = maxf(viewport_size.y - reserved_height - 4.0, 220.0)
	var target_height := clampf((stage_content_height + 8.0) if stage_content_height > 0.0 else max_scroll_height, 140.0, max_scroll_height)
	_focus_question_scroll.custom_minimum_size.y = target_height

func _control_layout_height(control: Control) -> float:
	if control == null or not control.visible:
		return 0.0
	return maxf(control.size.y, control.get_combined_minimum_size().y)

func _on_focus_answer_changed(question_id: String, value: Variant) -> void:
	var question := _question_definition(question_id)
	var previous_value: Variant = answers.get(question_id, null)
	_register_response_answer_change(question, previous_value, value)
	answers[question_id] = _duplicate_answer_value(value)
	_trace("Answer changed question=%s type=%s" % [question_id, typeof(value)])
	if question != null and question.is_answer_complete(answers.get(question_id, null)):
		_gamification_completed_questions[question_id] = true
	elif question != null:
		_gamification_completed_questions.erase(question_id)
	_persist_current_session_cache()
	_refresh_focus_view(false)
	_refresh_profile_overlay()

func _on_focus_question_selected(question_id: String) -> void:
	_refresh_question_help_overlay()

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

func _open_review_view() -> void:
	if survey == null:
		_show_view(VIEW_LANDING)
		return
	if _current_view != VIEW_REVIEW:
		_review_return_view = _current_view
	_show_view(VIEW_REVIEW)

func _close_review_view() -> void:
	var return_view := _review_return_view
	if return_view == VIEW_REVIEW:
		return_view = VIEW_THANKS if survey != null else VIEW_LANDING
	_show_view(return_view)

func _refresh_review_view() -> void:
	_clear_container(_review_list)
	_review_heading_label.text = "Review Answers"
	if survey == null:
		_review_subtitle_label.text = "Load a survey to review answers section by section."
		return
	var answered_questions := 0
	for question_id in _question_order:
		var question := _question_definition(question_id)
		if question != null and question.is_answer_complete(answers.get(question_id, null)):
			answered_questions += 1
	_review_subtitle_label.text = "Browse every section, skim your current answers, and jump straight back to any question. %d of %d question(s) are complete." % [answered_questions, _question_order.size()]
	for section_index in range(survey.sections.size()):
		var section := survey.sections[section_index]
		var section_block := VBoxContainer.new()
		section_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_block.add_theme_constant_override("separation", 10)
		_review_list.add_child(section_block)

		var header_panel := PanelContainer.new()
		header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_panel.add_theme_stylebox_override("panel", _panel_style(SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1, 14.0))
		section_block.add_child(header_panel)

		var header_stack := VBoxContainer.new()
		header_stack.layout_mode = 2
		header_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_stack.add_theme_constant_override("separation", 4)
		header_panel.add_child(header_stack)

		var section_heading := Label.new()
		section_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section_heading.text = section.display_title(section_index)
		SurveyStyle.style_heading(section_heading, 18, SurveyStyle.TEXT_PRIMARY)
		header_stack.add_child(section_heading)

		var section_caption := Label.new()
		section_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section_caption.text = "%d question(s) • %d answered" % [section.questions.size(), _section_answered_count(section)]
		SurveyStyle.style_caption(section_caption, _completion_color(_section_completion_state(section)))
		header_stack.add_child(section_caption)

		if not section.description.strip_edges().is_empty():
			var section_description := Label.new()
			section_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			section_description.text = section.description.strip_edges()
			SurveyStyle.style_body(section_description)
			section_description.add_theme_font_size_override("font_size", 14)
			header_stack.add_child(section_description)

		for question_index in range(section.questions.size()):
			var question := section.questions[question_index]
			section_block.add_child(_create_review_question_card(section_index, question_index, question))

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
	_thanks_review_button.disabled = false
	_thanks_export_button.disabled = false
	_thanks_body_label.text = "Thanks for participating in %s.\n\nYou answered %d question(s). When you're ready, open the export screen to save or share your results." % [survey.title, answered_questions]

func _open_export_overlay() -> void:
	if survey == null:
		_show_status_message("Load a survey before exporting.", true)
		return
	_close_profile_overlay()
	if _current_view != VIEW_EXPORT:
		_export_return_view = _current_view
	_show_view(VIEW_EXPORT)

func _close_export_overlay() -> void:
	var return_view := _export_return_view
	if return_view == VIEW_EXPORT:
		return_view = VIEW_THANKS if survey != null else VIEW_LANDING
	_show_view(return_view)

func _open_upload_view() -> void:
	if survey == null:
		_show_status_message("Load a survey before uploading answers.", true)
		return
	_close_profile_overlay()
	if _current_view != VIEW_UPLOAD:
		_upload_return_view = _current_view
	if not _upload_in_progress:
		_reset_upload_form_state()
	_show_view(VIEW_UPLOAD)

func _close_upload_view() -> void:
	var return_view := _upload_return_view
	if return_view == VIEW_UPLOAD:
		return_view = VIEW_EXPORT if survey != null else VIEW_LANDING
	_show_view(return_view)

func _open_profile_overlay() -> void:
	if _profile_overlay == null:
		return
	_set_focus_outline_visible(false)
	_close_overlay_menu()
	_close_question_help()
	_profile_overlay.open_profile(_build_profile_snapshot())
	_refresh_menu_access_button()

func _close_profile_overlay() -> void:
	if _profile_overlay != null:
		_profile_overlay.close_profile()
	_refresh_menu_access_button()

func _refresh_export_view() -> void:
	var state := _build_export_overlay_state()
	var has_survey := survey != null
	_export_heading_label.text = "Export Your Answers"
	_export_subtitle_label.text = survey.title if has_survey else "No survey is loaded."
	var body_lines: Array[String] = []
	var export_summary := str(state.get("export_summary", "")).strip_edges()
	if not export_summary.is_empty():
		body_lines.append(export_summary)
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
	_export_json_button.text = str(state.get("export_json_label", "Export JSON"))
	_export_upload_answers_button.text = str(state.get("upload_answers_label", "Upload Answers"))
	_export_csv_button.text = str(state.get("export_csv_label", "Export CSV"))
	_export_json_button.disabled = not bool(state.get("export_json_enabled", false))
	_export_upload_answers_button.disabled = not bool(state.get("upload_answers_enabled", false))
	_export_copy_json_button.disabled = not has_survey
	_export_copy_csv_button.disabled = not has_survey
	_export_csv_button.disabled = not has_survey
	call_deferred("_sync_scroll_content_widths")

func _refresh_upload_view() -> void:
	var state := _build_upload_view_state()
	var has_survey := survey != null
	_upload_heading_label.text = "Upload Answers"
	_upload_subtitle_label.text = survey.title if has_survey else "No survey is loaded."
	var body_lines: Array[String] = []
	var upload_usage_summary := str(state.get("upload_usage_summary", "")).strip_edges()
	if not upload_usage_summary.is_empty():
		body_lines.append(upload_usage_summary)
	var destination_summary := str(state.get("upload_destination_summary", "")).strip_edges()
	if not destination_summary.is_empty():
		body_lines.append(destination_summary)
	var upload_reason_summary := str(state.get("upload_reason_summary", "")).strip_edges()
	if not upload_reason_summary.is_empty():
		body_lines.append(upload_reason_summary)
	_upload_body_label.text = "\n\n".join(body_lines)
	_upload_notice_panel.visible = has_survey
	_upload_scrub_checkbox.visible = bool(state.get("show_scrub_option", false))
	_upload_scrub_checkbox.disabled = not bool(state.get("scrub_option_enabled", false)) or _upload_in_progress
	_upload_scrub_checkbox.text = str(state.get("scrub_checkbox_label", "Scrub identifying answers from this upload")).strip_edges()
	_upload_scrub_summary_label.text = str(state.get("scrub_summary", "")).strip_edges()
	_upload_consent_checkbox.disabled = _upload_in_progress or not bool(state.get("consent_enabled", false))
	_upload_consent_checkbox.text = str(state.get("consent_label", "I agree to send these survey answers.")).strip_edges()
	_upload_disclosure_label.text = str(state.get("public_repo_acknowledgement", "")).strip_edges()
	_upload_status_label.text = str(state.get("upload_status_text", "")).strip_edges()
	_upload_submit_button.text = "Uploading..." if _upload_in_progress else "Upload Answers"
	_upload_submit_button.disabled = not bool(state.get("upload_submit_enabled", false))
	_upload_copy_response_button.disabled = str(state.get("upload_response_text", "")).strip_edges().is_empty()
	_upload_response_text_edit.text = str(state.get("upload_response_text", "")).strip_edges()
	if _upload_response_text_edit.text.is_empty():
		_upload_response_text_edit.text = "No server response yet."
	_apply_upload_status_styles()
	call_deferred("_sync_scroll_content_widths")

func _build_export_overlay_state() -> Dictionary:
	var scrub_identifying_info: bool = _default_upload_scrub_enabled()
	var readiness: Dictionary = _upload_readiness_state(scrub_identifying_info)
	var destination_name := _upload_destination_display_name()
	var identifying_note := ""
	if survey != null and survey.asks_identifying_info:
		identifying_note = " The upload flow can scrub answers from questions marked as identifying before submission."
	return {
		"survey_title": survey.title if survey != null else "",
		"export_summary": "Export a JSON bundle or CSV snapshot of your answers. JSON exports include your current answers and journey context.",
		"export_json_enabled": survey != null,
		"upload_answers_enabled": survey != null,
		"export_json_label": "Export JSON",
		"upload_answers_label": "Upload Answers",
		"export_csv_label": "Export CSV",
		"upload_destination_name": upload_destination_name.strip_edges(),
		"upload_destination_url": upload_endpoint_url.strip_edges(),
		"upload_usage_summary": upload_usage_summary.strip_edges(),
		"upload_reason_summary": upload_reason_summary.strip_edges(),
		"upload_metadata_summary": "Spam protection metadata includes an anonymous install ID, upload timestamps, template identity, session timing signals, answer counts, reload history, and a payload hash for duplicate suppression.",
		"upload_ready": bool(readiness.get("ok", false)),
		"upload_ready_message": "%s%s" % [str(readiness.get("message", "")).strip_edges(), identifying_note],
		"upload_busy": _upload_in_progress,
		"upload_status_text": _last_upload_status_text if not _last_upload_status_text.is_empty() else "Upload to %s once you are ready." % destination_name,
		"upload_status_error": _last_upload_status_is_error,
		"upload_response_text": _last_upload_response_text,
		"consent_required": require_upload_consent
	}

func _build_upload_view_state() -> Dictionary:
	var scrub_identifying_info: bool = _current_upload_scrub_selection()
	var readiness: Dictionary = _upload_readiness_state(scrub_identifying_info)
	var upload_package: Dictionary = _build_upload_package(scrub_identifying_info)
	var stats: Dictionary = {}
	if not upload_package.is_empty():
		stats = upload_package.get("stats", {}) as Dictionary
	var identifying_question_count: int = survey.identifying_question_count() if survey != null else 0
	var identifying_answered_count: int = survey.identifying_answered_count(answers) if survey != null else 0
	var scrubbed_response_count: int = int(stats.get("scrubbed_identifying_response_count", identifying_answered_count if scrub_identifying_info else 0))
	var valid_response_count: int = int(stats.get("valid_response_count", 0))
	var destination_name := _upload_destination_display_name()
	var public_repo_name := _upload_public_repo_display_name()
	var scrub_summary := "No questions in this survey are marked as identifying."
	var scrub_option_enabled := identifying_answered_count > 0
	if identifying_question_count > 0:
		if identifying_answered_count <= 0:
			scrub_summary = "This survey marks %d question(s) as identifying, but none of those questions have answers yet." % identifying_question_count
		elif scrub_identifying_info:
			scrub_summary = "%d answered identifying question(s) will be removed before upload." % scrubbed_response_count
		else:
			scrub_summary = "%d answered identifying question(s) will be included in the uploaded payload." % identifying_answered_count
	var consent_summary := "This upload will send %d survey answer(s) to %s." % [valid_response_count, destination_name]
	var public_repo_acknowledgement := "%s\nUploaded answer data will be publicly available at %s." % [consent_summary, public_repo_name]
	if not upload_public_repo_url.strip_edges().is_empty():
		public_repo_acknowledgement += "\n%s" % upload_public_repo_url.strip_edges()
	var consent_label := "I agree to this public upload."
	var destination_url_summary := "Endpoint URL: %s" % upload_endpoint_url.strip_edges() if not upload_endpoint_url.strip_edges().is_empty() else "No endpoint URL is configured for this build."
	return {
		"upload_usage_summary": upload_usage_summary.strip_edges(),
		"upload_destination_summary": "Upload destination: %s\n%s" % [destination_name, destination_url_summary],
		"upload_reason_summary": upload_reason_summary.strip_edges(),
		"show_scrub_option": identifying_question_count > 0,
		"scrub_option_enabled": scrub_option_enabled,
		"scrub_checkbox_label": "Scrub identifying answers",
		"scrub_summary": scrub_summary,
		"consent_enabled": valid_response_count > 0,
		"consent_label": consent_label,
		"public_repo_acknowledgement": public_repo_acknowledgement,
		"upload_status_text": _last_upload_status_text if not _last_upload_status_text.is_empty() else str(readiness.get("message", "")).strip_edges(),
		"upload_response_text": _last_upload_response_text,
		"upload_submit_enabled": bool(readiness.get("ok", false)) and ((not require_upload_consent) or _upload_consent_checkbox.button_pressed) and not _upload_in_progress,
		"upload_ready_message": str(readiness.get("message", "")).strip_edges()
	}

func _apply_upload_status_styles() -> void:
	if _upload_in_progress:
		SurveyStyle.style_caption(_upload_status_label, SurveyStyle.ACCENT_ALT)
	elif _last_upload_status_is_error:
		SurveyStyle.style_caption(_upload_status_label, SurveyStyle.DANGER)
	else:
		SurveyStyle.style_caption(_upload_status_label, SurveyStyle.TEXT_PRIMARY)

func _reset_upload_form_state() -> void:
	if _upload_scrub_checkbox != null:
		_upload_scrub_checkbox.set_pressed_no_signal(_default_upload_scrub_enabled())
	if _upload_consent_checkbox != null:
		_upload_consent_checkbox.set_pressed_no_signal(false)

func _default_upload_scrub_enabled() -> bool:
	return survey != null and survey.identifying_answered_count(answers) > 0

func _current_upload_scrub_selection() -> bool:
	if _upload_scrub_checkbox == null:
		return _default_upload_scrub_enabled()
	return _upload_scrub_checkbox.button_pressed

func _build_summary_data() -> Dictionary:
	if survey == null:
		return {}
	return SURVEY_SUMMARY_ANALYZER.build_summary(survey, answers)

func _upload_readiness_state(scrub_identifying_info: bool) -> Dictionary:
	if survey == null:
		return {
			"ok": false,
			"message": "Load a survey before preparing an upload."
		}
	if survey.template_version <= 0 or survey.schema_hash.is_empty():
		return {
			"ok": false,
			"message": "This survey is missing template identity metadata needed for server validation."
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
	var upload_package: Dictionary = _build_upload_package(scrub_identifying_info)
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
	var scrubbed_response_count: int = int(stats.get("scrubbed_identifying_response_count", 0))
	var message := "Ready to submit %d answer(s) across %d section(s)." % [valid_response_count, sections_with_responses_count]
	if scrubbed_response_count > 0:
		message += " %d identifying answer(s) will be scrubbed first." % scrubbed_response_count
	return {
		"ok": true,
		"message": message
	}

func _build_upload_package(scrub_identifying_info: bool) -> Dictionary:
	if survey == null:
		return {}
	var install_id: String = SURVEY_UPLOAD_AUDIT_STORE.get_install_id()
	var session_metrics: Dictionary = _current_upload_quality_metadata()
	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(
		survey,
		_current_template_path,
		answers,
		_build_summary_data(),
		install_id,
		scrub_identifying_info,
		session_metrics
	)
	if upload_package.is_empty():
		return {}
	var stats: Dictionary = upload_package.get("stats", {}) as Dictionary
	var total_question_count: int = max(int(stats.get("total_question_count", 0)), 0)
	var min_required_answers: int = min(max(minimum_answered_questions_for_upload, 0), total_question_count)
	var audit_context: Dictionary = _current_upload_audit_context(session_metrics)
	var audit: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		str(upload_package.get("payload_hash", "")).strip_edges(),
		int(stats.get("valid_response_count", 0)),
		min_required_answers,
		upload_cooldown_seconds,
		upload_max_attempts_per_window,
		upload_attempt_window_seconds,
		audit_context
	)
	upload_package["min_required_answers"] = min_required_answers
	upload_package["session_metrics"] = session_metrics
	upload_package["audit_context"] = audit_context
	upload_package["audit"] = audit
	return upload_package

func _on_upload_scrub_toggled(_enabled: bool) -> void:
	if _upload_consent_checkbox != null:
		_upload_consent_checkbox.set_pressed_no_signal(false)
	_refresh_upload_view()

func _on_upload_consent_toggled(_enabled: bool) -> void:
	_refresh_upload_view()

func _submit_upload_answers() -> void:
	if survey == null:
		return
	if _upload_in_progress:
		return
	if require_upload_consent and not _upload_consent_checkbox.button_pressed:
		_last_upload_status_text = "Please confirm consent before submitting your answers to the server."
		_last_upload_status_is_error = true
		_refresh_upload_view()
		_show_status_message(_last_upload_status_text, true)
		return
	if not _is_upload_endpoint_configured():
		_last_upload_status_text = "Server upload is not configured for this build."
		_last_upload_status_is_error = true
		_refresh_upload_view()
		_show_status_message(_last_upload_status_text, true)
		return
	var scrub_identifying_info: bool = _current_upload_scrub_selection()
	var upload_package: Dictionary = _build_upload_package(scrub_identifying_info)
	if upload_package.is_empty():
		_last_upload_status_text = "Unable to prepare the upload payload."
		_last_upload_status_is_error = true
		_refresh_upload_view()
		_show_status_message(_last_upload_status_text, true)
		return
	var audit: Dictionary = upload_package.get("audit", {}) as Dictionary
	if not bool(audit.get("ok", false)):
		_last_upload_status_text = str(audit.get("message", "Upload blocked by client-side checks.")).strip_edges()
		_last_upload_status_is_error = true
		_refresh_upload_view()
		_show_status_message(_last_upload_status_text, true)
		return
	var payload_text: String = str(upload_package.get("json", ""))
	if payload_text.is_empty():
		_last_upload_status_text = "The upload payload was empty after sanitization."
		_last_upload_status_is_error = true
		_refresh_upload_view()
		_show_status_message(_last_upload_status_text, true)
		return
	_ensure_upload_request()
	_upload_in_progress = true
	_pending_upload_payload_hash = str(upload_package.get("payload_hash", "")).strip_edges()
	_last_upload_status_text = "Submitting survey answers to %s..." % _upload_destination_display_name()
	_last_upload_status_is_error = false
	_last_upload_response_text = ""
	_refresh_upload_view()
	_show_status_message(_last_upload_status_text)
	var request_error: Error = _upload_request.request(upload_endpoint_url.strip_edges(), _configured_upload_headers(), HTTPClient.METHOD_POST, payload_text)
	if request_error != OK:
		_upload_in_progress = false
		var failure_text: String = "Failed to start the upload request (%s)." % error_string(request_error)
		_last_upload_status_text = failure_text
		_last_upload_status_is_error = true
		_last_upload_response_text = failure_text
		SURVEY_UPLOAD_AUDIT_STORE.record_attempt(_pending_upload_payload_hash, false, 0, failure_text, _current_upload_audit_context())
		_pending_upload_payload_hash = ""
		_refresh_upload_view()
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

func _upload_destination_display_name() -> String:
	if not upload_destination_name.strip_edges().is_empty():
		return upload_destination_name.strip_edges()
	if not upload_endpoint_url.strip_edges().is_empty():
		return upload_endpoint_url.strip_edges()
	return "the configured upload destination"

func _upload_public_repo_display_name() -> String:
	if not upload_public_repo_name.strip_edges().is_empty():
		return upload_public_repo_name.strip_edges()
	if not upload_public_repo_url.strip_edges().is_empty():
		return upload_public_repo_url.strip_edges()
	return "the configured public repository"

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
	SURVEY_UPLOAD_AUDIT_STORE.record_attempt(_pending_upload_payload_hash, accepted, response_code, _last_upload_status_text, _current_upload_audit_context())
	_pending_upload_payload_hash = ""
	_refresh_upload_view()

func _reset_upload_status(clear_response: bool = false) -> void:
	_upload_in_progress = false
	_pending_upload_payload_hash = ""
	_last_upload_status_text = ""
	_last_upload_status_is_error = false
	if clear_response:
		_last_upload_response_text = ""

func _build_profile_json_text() -> String:
	return SURVEY_GAMIFICATION_STORE.build_profile_json(_build_profile_snapshot())

func _build_profile_csv_text() -> String:
	return SURVEY_GAMIFICATION_STORE.build_profile_csv(_build_profile_snapshot())

func _build_profile_share_text() -> String:
	if _gamification_hub == null:
		return SURVEY_GAMIFICATION_STORE.build_share_json({})
	return SURVEY_GAMIFICATION_STORE.build_share_json(_gamification_hub.current_profile())

func _copy_profile_png() -> void:
	if _profile_overlay == null:
		return
	if not SURVEY_PLATFORM_EXPORTS.supports_image_clipboard_copy():
		var unavailable_text := "PNG clipboard copy is only available in the desktop Windows build right now."
		if _supports_browser_downloads():
			unavailable_text = "PNG clipboard copy is not available in the browser build. Use Download PNG instead."
		_show_status_message(unavailable_text, true)
		return
	var image: Image = await _profile_overlay.capture_profile_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Unable to build the social profile PNG.", true)
		return
	if SURVEY_PLATFORM_EXPORTS.copy_image_to_clipboard(image, "social_profile_clipboard.png"):
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message("Social profile PNG copied to the clipboard.")
		return
	_show_status_message("Failed to copy the social profile PNG to the clipboard.", true)

func _save_profile_png() -> void:
	if _profile_overlay == null:
		return
	var image: Image = await _profile_overlay.capture_profile_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Unable to build the social profile PNG.", true)
		return
	_prompt_save_image(image, "png", "Social profile PNG", "Save Social Profile PNG", SURVEY_GAMIFICATION_STORE.suggested_filename("social_profile", "png"))

func _copy_profile_json() -> void:
	var export_text := _build_profile_json_text()
	if export_text.is_empty():
		_show_status_message("Unable to build the social profile JSON.", true)
		return
	DisplayServer.clipboard_set(export_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("Social profile JSON copied to the clipboard.")

func _save_profile_json() -> void:
	var export_text := _build_profile_json_text()
	if export_text.is_empty():
		_show_status_message("Unable to build the social profile JSON.", true)
		return
	_prompt_save_text(export_text, "json", "Social profile JSON", "Save Social Profile JSON", SURVEY_GAMIFICATION_STORE.suggested_filename("social_profile", "json"))

func _copy_profile_csv() -> void:
	var export_text := _build_profile_csv_text()
	if export_text.is_empty():
		_show_status_message("Unable to build the social profile CSV.", true)
		return
	DisplayServer.clipboard_set(export_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("Social profile CSV copied to the clipboard.")

func _save_profile_csv() -> void:
	var export_text := _build_profile_csv_text()
	if export_text.is_empty():
		_show_status_message("Unable to build the social profile CSV.", true)
		return
	_prompt_save_text(export_text, "csv", "Social profile CSV", "Save Social Profile CSV", SURVEY_GAMIFICATION_STORE.suggested_filename("social_profile", "csv"))

func _copy_profile_share_json() -> void:
	var export_text := _build_profile_share_text()
	if export_text.is_empty():
		_show_status_message("Unable to build shareable profile JSON.", true)
		return
	DisplayServer.clipboard_set(export_text)
	SURVEY_UI_FEEDBACK.play_export()
	_show_status_message("Shareable profile JSON copied to the clipboard.")

func _export_json() -> void:
	_prompt_save_export(EXPORT_FORMAT_JSON)

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

func _copy_csv() -> void:
	_copy_export_to_clipboard(EXPORT_FORMAT_CSV)

func _export_csv() -> void:
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
	_prompt_save_text(export_text, format, _export_label(format), "Export %s" % _export_label(format), _export_filename(format))

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

func _prompt_save_image(image: Image, extension: String, label: String, dialog_title: String, suggested_file: String) -> void:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_show_status_message("Nothing is available to save for %s." % label, true)
		return
	if _supports_browser_downloads() and extension.to_lower() == "png":
		var png_buffer: PackedByteArray = image.save_png_to_buffer()
		if _download_buffer_to_browser(png_buffer, suggested_file, "%s download started." % label):
			return
		_show_status_message("Failed to start a browser download for %s." % label, true)
		return
	if _save_dialog == null:
		_show_status_message("Save dialogs are unavailable in this build.", true)
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

func _build_export_text(format: String) -> String:
	if survey == null:
		return ""
	match format:
		EXPORT_FORMAT_JSON:
			return SURVEY_SAVE_BUNDLE.build_json_text(survey, _current_template_path, answers, _current_preferences(), _current_session_state())
		EXPORT_FORMAT_CSV:
			return SURVEY_EXPORTER.build_csv_text(survey, answers)
	return ""

func _export_label(format: String) -> String:
	return format.to_upper()

func _export_filename(format: String) -> String:
	if format == EXPORT_FORMAT_JSON:
		return SURVEY_SAVE_BUNDLE.suggested_filename(survey.id)
	return SURVEY_EXPORTER.suggested_filename(survey.id, format)

func _on_save_dialog_file_selected(path: String) -> void:
	var target_path := path
	if not _pending_save_extension.is_empty() and target_path.get_extension().to_lower() != _pending_save_extension:
		target_path = "%s.%s" % [target_path, _pending_save_extension]
	var save_ok := false
	if _pending_save_image != null and _pending_save_extension.to_lower() == "png":
		save_ok = SURVEY_EXPORTER.save_image_file(target_path, _pending_save_image)
	else:
		save_ok = SURVEY_EXPORTER.save_text_file(target_path, _pending_save_text)
	if save_ok:
		SURVEY_UI_FEEDBACK.play_export()
		_show_status_message("%s exported to %s" % [_pending_save_label, target_path])
	else:
		_show_status_message("Failed to save %s." % _pending_save_label, true)
	_clear_pending_save_state()

func _on_save_dialog_canceled() -> void:
	_clear_pending_save_state()

func _clear_pending_save_state() -> void:
	_pending_save_text = ""
	_pending_save_image = null
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

func _on_template_dialog_file_selected(path: String) -> void:
	_import_template_from_path(path)

func _on_template_dialog_canceled() -> void:
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
	_restore_response_quality_tracking(loaded_session_state, not loaded_answers.is_empty() or not loaded_session_state.is_empty())
	_reset_upload_status(true)
	_reset_upload_form_state()
	_prime_gamification_trackers()
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
	_refresh_gamification_surfaces()
	_persist_current_session_cache()
	_show_status_message("Loaded progress from %s." % source_name)

func _sanitize_loaded_answers(source: Dictionary) -> Dictionary:
	return _sanitize_answers_for_survey_definition(survey, source)

func _sanitize_answers_for_survey_definition(survey_definition: SurveyDefinition, source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	if survey_definition == null:
		return sanitized
	for section in survey_definition.sections:
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
	for numeric_key in ["session_started_at_unix", "first_answer_at_unix", "last_answer_at_unix", "answer_change_count"]:
		if source.has(numeric_key):
			sanitized[numeric_key] = max(0, int(source.get(numeric_key, 0)))
	if source.has("restored_progress"):
		sanitized["restored_progress"] = bool(source.get("restored_progress", false))
	return sanitized

func _extract_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _apply_loaded_preferences(preferences: Dictionary) -> bool:
	var theme_changed := false
	if preferences.has("selected_theme_id"):
		var desired_theme_id := str(preferences.get("selected_theme_id", _selected_theme_id)).strip_edges().to_lower()
		if not desired_theme_id.is_empty() and _selected_theme_id != desired_theme_id:
			_selected_theme_id = desired_theme_id
			_apply_selected_theme_palette()
			theme_changed = true
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
		"selected_theme_id": _selected_theme_id,
		"use_dark_mode": use_dark_mode,
		"sfx_volume": sfx_volume,
		"survey_view_mode": "focus"
	}

func _persist_current_session_cache() -> void:
	if survey == null or _current_template_path.is_empty():
		return
	SURVEY_SESSION_CACHE.save_session(survey, _current_template_path, answers, _current_preferences(), _current_session_state())

func _restore_response_quality_tracking(restored_state: Dictionary, restored_progress: bool) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_response_session_started_at_unix = max(0, int(restored_state.get("session_started_at_unix", now)))
	if _response_session_started_at_unix <= 0 or _response_session_started_at_unix > now:
		_response_session_started_at_unix = now
	_response_first_answer_at_unix = clampi(int(restored_state.get("first_answer_at_unix", 0)), 0, now)
	_response_last_answer_at_unix = clampi(int(restored_state.get("last_answer_at_unix", 0)), 0, now)
	if _response_first_answer_at_unix > 0 and _response_first_answer_at_unix < _response_session_started_at_unix:
		_response_first_answer_at_unix = _response_session_started_at_unix
	if _response_last_answer_at_unix > 0 and _response_last_answer_at_unix < _response_first_answer_at_unix:
		_response_last_answer_at_unix = _response_first_answer_at_unix
	_response_answer_change_count = max(0, int(restored_state.get("answer_change_count", 0)))
	if _response_answer_change_count <= 0:
		_response_answer_change_count = _current_answered_question_count()
	_response_restored_progress = restored_progress or bool(restored_state.get("restored_progress", false))

func _register_response_answer_change(question: SurveyQuestion, previous_value: Variant, next_value: Variant) -> void:
	if question == null or previous_value == next_value:
		return
	var now: int = int(Time.get_unix_time_from_system())
	if _response_session_started_at_unix <= 0:
		_response_session_started_at_unix = now
	_response_answer_change_count += 1
	if not question.is_answer_empty(next_value):
		if _response_first_answer_at_unix <= 0:
			_response_first_answer_at_unix = now
		_response_last_answer_at_unix = now
	elif _response_last_answer_at_unix <= 0:
		_response_last_answer_at_unix = now

func _current_answered_question_count() -> int:
	if survey == null:
		return 0
	var count := 0
	for section in survey.sections:
		for question in section.questions:
			if not question.is_answer_empty(answers.get(question.id, null)):
				count += 1
	return count

func _current_completed_answer_count() -> int:
	if survey == null:
		return 0
	var count := 0
	for section in survey.sections:
		for question in section.questions:
			if question.is_answer_complete(answers.get(question.id, null)):
				count += 1
	return count

func _current_upload_quality_metadata() -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var session_started_at_unix: int = _response_session_started_at_unix if _response_session_started_at_unix > 0 else now
	var answered_question_count: int = _current_answered_question_count()
	var completed_answer_count: int = _current_completed_answer_count()
	var session_duration_seconds: int = max(now - session_started_at_unix, 0)
	var seconds_to_first_answer: int = -1
	if _response_first_answer_at_unix > 0:
		seconds_to_first_answer = max(_response_first_answer_at_unix - session_started_at_unix, 0)
	var seconds_since_last_answer: int = -1
	if _response_last_answer_at_unix > 0:
		seconds_since_last_answer = max(now - _response_last_answer_at_unix, 0)
	var answers_per_minute := 0.0
	if session_duration_seconds > 0:
		answers_per_minute = (float(answered_question_count) * 60.0) / float(session_duration_seconds)
	return {
		"session_duration_seconds": session_duration_seconds,
		"seconds_to_first_answer": seconds_to_first_answer,
		"seconds_since_last_answer": seconds_since_last_answer,
		"answer_change_count": _response_answer_change_count,
		"distinct_answered_question_count": answered_question_count,
		"completed_answered_question_count": completed_answer_count,
		"answers_per_minute": answers_per_minute,
		"template_load_count_this_session": 1,
		"restored_progress": _response_restored_progress
	}

func _current_upload_template_key() -> String:
	if survey == null:
		return ""
	return SURVEY_UPLOAD_AUDIT_STORE.template_key_for_values(survey.id, survey.template_version, survey.schema_hash)

func _current_upload_audit_context(session_metrics: Dictionary = {}) -> Dictionary:
	var context: Dictionary = session_metrics.duplicate(true)
	context["template_key"] = _current_upload_template_key()
	context["min_session_duration_seconds"] = minimum_upload_session_seconds
	context["min_seconds_per_answer"] = minimum_upload_seconds_per_answer
	context["min_seconds_to_first_answer"] = minimum_seconds_to_first_answer
	context["max_template_loads_per_window"] = max_template_loads_per_window
	context["template_load_window_seconds"] = template_load_window_seconds
	context["max_successful_uploads_per_template"] = max_successful_uploads_per_template
	context["successful_uploads_per_template_window_seconds"] = successful_uploads_per_template_window_seconds
	context["max_successful_uploads_per_install"] = max_successful_uploads_per_install
	context["successful_uploads_per_install_window_seconds"] = successful_uploads_per_install_window_seconds
	return context

func _current_session_state() -> Dictionary:
	var selected_question_id := _current_focus_question_id()
	return {
		"current_section_index": _section_index_for_question_id(selected_question_id),
		"selected_question_id": selected_question_id,
		"session_started_at_unix": _response_session_started_at_unix,
		"first_answer_at_unix": _response_first_answer_at_unix,
		"last_answer_at_unix": _response_last_answer_at_unix,
		"answer_change_count": _response_answer_change_count,
		"restored_progress": _response_restored_progress
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

func _open_web_template_import_picker() -> bool:
	if not _supports_template_import():
		return false
	if _web_template_picker_active:
		_show_status_message("The browser template picker is already open.")
		return true
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	_web_template_picker_success_callback = JavaScriptBridge.create_callback(_on_web_template_import_success)
	_web_template_picker_error_callback = JavaScriptBridge.create_callback(_on_web_template_import_error)
	window.__surveyJourneyTemplateImportSuccess = _web_template_picker_success_callback
	window.__surveyJourneyTemplateImportError = _web_template_picker_error_callback
	_web_template_picker_active = true
	JavaScriptBridge.eval("""
		(function () {
			const success = window.__surveyJourneyTemplateImportSuccess;
			const failure = window.__surveyJourneyTemplateImportError;
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
				success(fileName || 'survey_template.json', text || '');
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
					succeed(file && file.name ? file.name : 'survey_template.json', typeof reader.result === 'string' ? reader.result : '');
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
	_show_status_message("Select a survey template JSON file to import.")
	return true

func _on_web_template_import_success(args: Array) -> void:
	var file_name := "survey_template.json"
	var source_text := ""
	if args.size() >= 1:
		file_name = str(args[0]).strip_edges()
	if args.size() >= 2:
		source_text = str(args[1])
	_clear_web_template_import_callbacks()
	if source_text.strip_edges().is_empty():
		_show_status_message("The selected survey template file was empty.", true)
		return
	_import_template_from_text(source_text, file_name if not file_name.is_empty() else "survey_template.json")

func _on_web_template_import_error(args: Array) -> void:
	var error_kind := ""
	var file_name := ""
	var message := ""
	if args.size() >= 1:
		error_kind = str(args[0]).strip_edges()
	if args.size() >= 2:
		file_name = str(args[1]).strip_edges()
	if args.size() >= 3:
		message = str(args[2]).strip_edges()
	_clear_web_template_import_callbacks()
	if error_kind == "cancel":
		return
	var target_name := file_name if not file_name.is_empty() else "the selected survey template"
	var error_text := "Failed to import %s." % target_name
	if not message.is_empty():
		error_text = "%s %s" % [error_text, message]
	_show_status_message(error_text, true)

func _clear_web_template_import_callbacks() -> void:
	_web_template_picker_active = false
	if _supports_template_import():
		var window = JavaScriptBridge.get_interface("window")
		if window != null:
			window.__surveyJourneyTemplateImportSuccess = null
			window.__surveyJourneyTemplateImportError = null
	_web_template_picker_success_callback = null
	_web_template_picker_error_callback = null

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

func _create_template_selection_card(texture: Texture2D, title: String, description: String, source_label: String, total_sections: int, total_questions: int, answered_count: int, stored_count: int, has_saved_answers: bool, is_active: bool, template_path: String) -> PanelContainer:
	var viewport_size := get_viewport().get_visible_rect().size
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size)
	var accent_color := SurveyStyle.ACCENT_ALT
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, (164.0 * journey_scale) if phone_layout else 170.0)
	var fill := SurveyStyle.SURFACE_MUTED if is_active else SurveyStyle.SURFACE_ALT
	var border := accent_color if is_active else SurveyStyle.BORDER
	card.add_theme_stylebox_override("panel", _panel_style(fill, border, 18 if phone_layout else 22, 2 if is_active else 1, (14.0 * journey_scale) if phone_layout else 16.0))

	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.add_theme_constant_override("separation", int(round((12 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	card.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2((50.0 * journey_scale), (50.0 * journey_scale)) if phone_layout else Vector2(56.0, 56.0)
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
	SurveyStyle.style_heading(title_label, int(round((18 if phone_layout else 20) * (journey_scale if phone_layout else 1.0))), SurveyStyle.TEXT_PRIMARY)
	content.add_child(title_label)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = description
	SurveyStyle.style_body(description_label)
	description_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	content.add_child(description_label)

	var caption_parts: Array[String] = []
	if not source_label.strip_edges().is_empty():
		caption_parts.append(source_label.strip_edges())
	caption_parts.append("%d section(s)" % max(total_sections, 0))
	caption_parts.append("%d question(s)" % max(total_questions, 0))
	if stored_count > 0:
		caption_parts.append("%d saved" % stored_count)

	var caption_label := Label.new()
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.text = " | ".join(caption_parts)
	SurveyStyle.style_caption(caption_label, accent_color if is_active else SurveyStyle.TEXT_PRIMARY)
	caption_label.add_theme_font_size_override("font_size", int(round((12 if phone_layout else 13) * (journey_scale if phone_layout else 1.0))))
	content.add_child(caption_label)

	var action_row := HBoxContainer.new()
	action_row.layout_mode = 2
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8 if phone_layout else 10)
	content.add_child(action_row)

	var answered_label := Label.new()
	answered_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answered_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	answered_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	answered_label.text = "%d/%d answered" % [max(answered_count, 0), max(total_questions, 0)]
	var answered_color := accent_color if is_active else SurveyStyle.TEXT_MUTED.lerp(SurveyStyle.TEXT_PRIMARY, 0.28)
	SurveyStyle.style_caption(answered_label, answered_color)
	answered_label.add_theme_font_size_override("font_size", int(round((13 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	action_row.add_child(answered_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(spacer)

	if has_saved_answers and _selection_purpose == PURPOSE_SURVEY:
		var trash_button := Button.new()
		trash_button.focus_mode = Control.FOCUS_ALL
		trash_button.tooltip_text = "Clear saved answers for this survey"
		trash_button.icon = _trash_action_icon()
		trash_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trash_button.custom_minimum_size = Vector2((34.0 * journey_scale) if phone_layout else 34.0, (34.0 * journey_scale) if phone_layout else 34.0)
		SurveyStyle.apply_danger_button(trash_button)
		trash_button.add_theme_constant_override("h_separation", 0)
		trash_button.pressed.connect(_confirm_clear_template_answers.bind(template_path))
		_wire_button_feedback(trash_button)
		action_row.add_child(trash_button)

	return card

func _create_card_panel(texture: Texture2D, title: String, description: String, caption: String, is_active: bool, accent_color: Color) -> PanelContainer:
	var viewport_size := get_viewport().get_visible_rect().size
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var journey_scale := SurveyStyle.journey_mobile_scale(viewport_size)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, (140.0 * journey_scale) if phone_layout else 152.0)
	var fill := SurveyStyle.SURFACE_MUTED if is_active else SurveyStyle.SURFACE_ALT
	var border := accent_color if is_active else SurveyStyle.BORDER
	card.add_theme_stylebox_override("panel", _panel_style(fill, border, 18 if phone_layout else 22, 2 if is_active else 1, (14.0 * journey_scale) if phone_layout else 16.0))
	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.add_theme_constant_override("separation", int(round((12 if phone_layout else 14) * (journey_scale if phone_layout else 1.0))))
	card.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2((50.0 * journey_scale), (50.0 * journey_scale)) if phone_layout else Vector2(56.0, 56.0)
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
	SurveyStyle.style_heading(title_label, int(round((18 if phone_layout else 20) * (journey_scale if phone_layout else 1.0))), SurveyStyle.TEXT_PRIMARY)
	content.add_child(title_label)
	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = description
	SurveyStyle.style_body(description_label)
	description_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	content.add_child(description_label)
	if not caption.is_empty():
		var caption_label := Label.new()
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption_label.text = caption
		SurveyStyle.style_caption(caption_label, accent_color if is_active else SurveyStyle.TEXT_PRIMARY)
		caption_label.add_theme_font_size_override("font_size", int(round((12 if phone_layout else 13) * (journey_scale if phone_layout else 1.0))))
		content.add_child(caption_label)
	return card

func _create_review_question_card(section_index: int, question_index: int, question: SurveyQuestion) -> PanelContainer:
	var viewport_size := get_viewport().get_visible_rect().size
	var phone_layout := _is_phone_layout_for_size(viewport_size)
	var completion_state: StringName = question.answer_completion_state(answers.get(question.id, null))
	var state_color := _completion_color(completion_state)
	var type_color := SurveyStyle.question_type_color(question.type)
	var has_saved_answer := not question.is_answer_empty(answers.get(question.id, null))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(SurveyStyle.SURFACE_MUTED, SurveyStyle.BORDER, 16 if phone_layout else 18, 1, 14.0))
	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var state_rect := ColorRect.new()
	state_rect.custom_minimum_size = Vector2(18.0, 18.0)
	state_rect.color = state_color
	state_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state_rect)

	var content := VBoxContainer.new()
	content.layout_mode = 2
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	row.add_child(content)

	var title_label := Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = question.display_title(question_index)
	SurveyStyle.style_heading(title_label, 16 if phone_layout else 18, SurveyStyle.TEXT_PRIMARY)
	content.add_child(title_label)

	var type_row := HFlowContainer.new()
	type_row.layout_mode = 2
	type_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_theme_constant_override("h_separation", 6)
	type_row.add_theme_constant_override("v_separation", 2)
	content.add_child(type_row)

	var type_label := Label.new()
	type_label.name = "QuestionTypeLabel"
	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.text = question.accent_label(_question_debug_ids_enabled)
	SurveyStyle.style_caption(type_label, type_color.lightened(0.1))
	type_row.add_child(type_label)

	var requirement_label := Label.new()
	requirement_label.name = "QuestionRequirementLabel"
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	requirement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	requirement_label.text = "| %s" % question.requirement_label()
	var requirement_color := type_color.lerp(SurveyStyle.TEXT_MUTED, 0.58)
	requirement_color.a = 0.86 if SurveyStyle.is_dark_mode() else 0.92
	SurveyStyle.style_caption(requirement_label, requirement_color)
	type_row.add_child(requirement_label)

	var meta_label := Label.new()
	meta_label.name = "QuestionStateLabel"
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.text = "%s • %s" % [question.display_type_label(), _completion_state_label(completion_state)]
	SurveyStyle.style_caption(meta_label, state_color)
	content.add_child(meta_label)
	meta_label.text = _completion_state_label(completion_state)

	var summary_label := Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_label.text = _review_answer_summary(question, answers.get(question.id, null))
	SurveyStyle.style_body(summary_label)
	summary_label.add_theme_font_size_override("font_size", 14 if phone_layout else 15)
	content.add_child(summary_label)

	var action_column := VBoxContainer.new()
	action_column.layout_mode = 2
	action_column.add_theme_constant_override("separation", 6)
	row.add_child(action_column)

	var clear_button := Button.new()
	clear_button.name = "ClearAnswerButton"
	clear_button.text = "Clear" if phone_layout else "Clear Answer"
	clear_button.tooltip_text = "Clear this saved answer."
	clear_button.focus_mode = Control.FOCUS_ALL
	clear_button.disabled = not has_saved_answer
	if clear_button.disabled:
		clear_button.tooltip_text = "No saved answer to clear."
	SurveyStyle.apply_danger_button(clear_button)
	clear_button.custom_minimum_size = Vector2(0.0, (40.0 * SurveyStyle.journey_mobile_scale(viewport_size)) if phone_layout else 34.0)
	clear_button.add_theme_font_size_override("font_size", 12 if phone_layout else 11)
	_wire_button_feedback(clear_button)
	clear_button.pressed.connect(_confirm_clear_review_question_answer.bind(question.id))
	action_column.add_child(clear_button)

	_make_card_interactive(card, _on_review_question_selected.bind(section_index, question.id), _on_review_question_selected.bind(section_index, question.id))
	return card

func _confirm_clear_review_question_answer(question_id: String) -> void:
	var question := _question_definition(question_id)
	if question == null:
		_show_status_message("That question could not be found.", true)
		return
	if question.is_answer_empty(answers.get(question_id, null)):
		_show_status_message("That question does not have a saved answer yet.")
		return
	var prompt_text := question.prompt.strip_edges() if not question.prompt.strip_edges().is_empty() else question_id
	_request_confirmation(
		"Clear Saved Answer",
		"Clear the saved answer for \"%s\"?\n\nYou can answer it again later." % prompt_text,
		"Clear Answer",
		_clear_review_question_answer.bind(question_id)
	)

func _clear_review_question_answer(question_id: String) -> void:
	var question := _question_definition(question_id)
	if question == null:
		_show_status_message("That question could not be found.", true)
		return
	if question.is_answer_empty(answers.get(question_id, null)):
		_show_status_message("That question does not have a saved answer yet.")
		return
	answers.erase(question_id)
	if _focus_question_stage != null:
		_focus_question_stage.sync_answers(answers)
	_persist_current_session_cache()
	_prime_gamification_trackers()
	_refresh_all_views()
	_refresh_gamification_surfaces()
	var cleared_label := question.prompt.strip_edges() if not question.prompt.strip_edges().is_empty() else question_id
	_show_status_message("Cleared the saved answer for %s." % cleared_label)

func _completion_state_label(state: StringName) -> String:
	match state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return "Complete"
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return "Partial"
	return "Unanswered"

func _review_answer_summary(question: SurveyQuestion, value: Variant) -> String:
	if question == null or question.is_answer_empty(value):
		return "No answer yet."
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return _truncate_text(str(value).replace("\n", " ").strip_edges(), 140)
		TYPE_BOOL:
			return "Yes" if bool(value) else "No"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_ARRAY:
			var items := value as Array
			var summary_parts: Array[String] = []
			for item in items:
				var text := str(item).strip_edges()
				if text.is_empty():
					continue
				summary_parts.append(text)
				if summary_parts.size() >= 3:
					break
			var summary := ", ".join(summary_parts)
			if items.size() > summary_parts.size():
				summary += " ..."
			return _truncate_text(summary, 140)
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			if question.type == SurveyQuestion.TYPE_MATRIX:
				var answered_rows := 0
				var row_parts: Array[String] = []
				for row_name in question.rows:
					var row_value := str(dict.get(row_name, "")).strip_edges()
					if row_value.is_empty():
						continue
					answered_rows += 1
					if row_parts.size() < 2:
						row_parts.append("%s: %s" % [_truncate_text(row_name, 28), row_value])
				var matrix_summary := "; ".join(row_parts)
				if answered_rows > row_parts.size():
					matrix_summary += " ..."
				return _truncate_text(matrix_summary, 140)
			var dict_parts: Array[String] = []
			for key in dict.keys():
				var text := str(dict.get(key, "")).strip_edges()
				if text.is_empty():
					continue
				dict_parts.append("%s: %s" % [str(key), text])
				if dict_parts.size() >= 2:
					break
			return _truncate_text("; ".join(dict_parts), 140)
	return _truncate_text(str(value).strip_edges(), 140)

func _truncate_text(text: String, max_length: int = 120) -> String:
	var trimmed := text.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return "%s…" % trimmed.substr(0, max_length - 1)

func _on_review_question_selected(section_index: int, question_id: String) -> void:
	if survey == null or question_id.is_empty():
		return
	_start_focus_from_section(section_index, question_id)

func _is_phone_layout_for_size(viewport_size: Vector2) -> bool:
	match _preview_mode_override:
		SURVEY_PREVIEW_CONFIG.MODE_MOBILE:
			return true
		SURVEY_PREVIEW_CONFIG.MODE_DESKTOP:
			return false
	return viewport_size.x <= 480.0

func _is_compact_layout_for_size(viewport_size: Vector2) -> bool:
	match _preview_mode_override:
		SURVEY_PREVIEW_CONFIG.MODE_MOBILE:
			return true
		SURVEY_PREVIEW_CONFIG.MODE_DESKTOP:
			return false
	return viewport_size.x <= 640.0

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
	_commit_current_focus_question_progress()
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
	return UNANSWERED_STATUS_COLOR

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
		container.remove_child(child)
		child.queue_free()

func _duplicate_answer_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return value

func _prime_gamification_trackers() -> void:
	_gamification_completed_sections.clear()
	_gamification_completed_questions.clear()
	_gamification_survey_completed = false
	if survey == null:
		return
	for section_index in range(survey.sections.size()):
		var section := survey.sections[section_index]
		var section_complete := true
		for question in section.questions:
			if question.is_answer_complete(answers.get(question.id, null)):
				_gamification_completed_questions[question.id] = true
			else:
				section_complete = false
		if section_complete and not section.questions.is_empty():
			_gamification_completed_sections[section_index] = true
	_gamification_survey_completed = _is_survey_complete()
	_refresh_profile_overlay()

func _is_section_complete(section_index: int) -> bool:
	if survey == null or section_index < 0 or section_index >= survey.sections.size():
		return false
	var section := survey.sections[section_index]
	if section.questions.is_empty():
		return false
	for question in section.questions:
		if not question.is_answer_complete(answers.get(question.id, null)):
			return false
	return true

func _is_survey_complete() -> bool:
	if survey == null or survey.sections.is_empty():
		return false
	for section_index in range(survey.sections.size()):
		if not _is_section_complete(section_index):
			return false
	return true

func _current_pointer_position() -> Vector2:
	return get_viewport().get_mouse_position()

func _resolved_question_xp_config() -> SurveyQuestionXpConfig:
	var config: Resource = question_xp_config if question_xp_config != null else DEFAULT_QUESTION_XP_CONFIG
	return config as SurveyQuestionXpConfig

func _resolved_question_xp_amount(question: SurveyQuestion) -> int:
	var config := _resolved_question_xp_config()
	return config.xp_for_question(question) if config != null else 0

func _resolved_max_xp_for_question(question: SurveyQuestion) -> int:
	if max_xp_per_question > 0:
		return max_xp_per_question
	return _resolved_question_xp_amount(question)

func _award_question_lock(question: SurveyQuestion) -> void:
	if not _is_xp_system_enabled() or _gamification_hub == null or question == null:
		return
	if question.answer_completion_state(answers.get(question.id, null)) == SurveyQuestion.ANSWER_STATE_UNANSWERED:
		return
	var base_xp: int = _resolved_question_xp_amount(question)
	if base_xp <= 0:
		return
	_gamification_hub.award_question_lock(question, base_xp, _current_pointer_position(), _question_reward_key(question.id), _resolved_max_xp_for_question(question))

func _commit_current_focus_question_progress() -> void:
	var question := _current_focus_question()
	if question == null:
		return
	_award_question_lock(question)
	_handle_completion_awards()

func _handle_completion_awards() -> void:
	if not _is_xp_system_enabled() or survey == null or _gamification_hub == null:
		return
	for section_index in range(survey.sections.size()):
		if not _gamification_completed_sections.has(section_index) and _is_section_complete(section_index):
			_gamification_completed_sections[section_index] = true
			var section := survey.sections[section_index]
			_gamification_hub.award_section_complete(section.id, section.display_title(section_index), _current_pointer_position())
	if not _gamification_survey_completed and _is_survey_complete():
		_gamification_survey_completed = true
		_gamification_hub.award_survey_complete(survey.id, survey.title, _current_pointer_position())

func _on_gamification_award_resolved(result: Dictionary) -> void:
	if _gamification_hud != null:
		_gamification_hud.handle_award_result(result)
	_refresh_profile_overlay()

func _on_gamification_profile_changed(profile: Dictionary) -> void:
	_configure_gamification_progress(SURVEY_GAMIFICATION_STORE.build_progress_state(profile))
	_refresh_profile_overlay()

func _build_profile_snapshot() -> Dictionary:
	if _gamification_hub == null:
		return SURVEY_GAMIFICATION_STORE.build_profile_snapshot({}, survey, answers)
	return _gamification_hub.current_snapshot(survey, answers)

func _refresh_profile_overlay() -> void:
	if _profile_overlay == null:
		return
	if _profile_overlay.visible:
		_profile_overlay.update_profile(_build_profile_snapshot())

func _refresh_lore_surface_theme(phone_layout: bool, journey_scale: float, viewport_size: Vector2) -> void:
	if _lore_empty_panel != null:
		SurveyStyle.apply_panel(_lore_empty_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 24, 1)
		_lore_empty_panel.custom_minimum_size = Vector2(maxf(minf(viewport_size.x - 48.0, 520.0), 280.0), 0.0)
	if _lore_empty_label != null:
		SurveyStyle.style_body(_lore_empty_label)
		_lore_empty_label.add_theme_font_size_override("font_size", int(round((17 if phone_layout else 20) * (journey_scale if phone_layout else 1.0))))
	if _lore_link_button != null:
		_lore_link_button.text = ""
		_lore_link_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _lore_link_prompt_panel != null:
		SurveyStyle.apply_panel(_lore_link_prompt_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
		_lore_link_prompt_panel.custom_minimum_size = Vector2(maxf(minf(viewport_size.x - 48.0, 480.0), 280.0), 0.0)
	if _lore_link_prompt_heading_label != null:
		SurveyStyle.style_heading(_lore_link_prompt_heading_label, int(round((20 if phone_layout else 22) * (journey_scale if phone_layout else 1.0))))
	if _lore_link_prompt_body_label != null:
		SurveyStyle.style_body(_lore_link_prompt_body_label)
		_lore_link_prompt_body_label.add_theme_font_size_override("font_size", int(round((14 if phone_layout else 15) * (journey_scale if phone_layout else 1.0))))
	if _lore_link_prompt_close_button != null:
		_lore_link_prompt_close_button.custom_minimum_size = Vector2((44.0 * journey_scale) if phone_layout else 40.0, (44.0 * journey_scale) if phone_layout else 40.0)
	if _lore_link_prompt_copy_button != null:
		_lore_link_prompt_copy_button.custom_minimum_size = Vector2(0.0, (50.0 * journey_scale) if phone_layout else 42.0)
	if _lore_link_prompt_open_button != null:
		_lore_link_prompt_open_button.custom_minimum_size = Vector2(0.0, (50.0 * journey_scale) if phone_layout else 42.0)

func _journey_should_show_hud() -> bool:
	if not _is_xp_system_enabled():
		return false
	var overlay_blocking: bool = (_overlay_menu != null and _overlay_menu.visible) or (_profile_overlay != null and _profile_overlay.visible) or (_help_overlay != null and _help_overlay.visible) or (_lore_link_prompt_overlay != null and _lore_link_prompt_overlay.visible)
	return survey != null and _current_view in [VIEW_FOCUS, VIEW_REVIEW, VIEW_THANKS] and not overlay_blocking

func _journey_should_show_focus_xp() -> bool:
	if not _is_xp_system_enabled():
		return false
	var overlay_blocking: bool = (_overlay_menu != null and _overlay_menu.visible) or (_profile_overlay != null and _profile_overlay.visible) or (_help_overlay != null and _help_overlay.visible) or (_lore_link_prompt_overlay != null and _lore_link_prompt_overlay.visible)
	return survey != null and _current_view == VIEW_FOCUS and not overlay_blocking

func _configure_gamification_progress(progress: Dictionary) -> void:
	if _gamification_hud != null:
		_gamification_hud.configure_progress(progress)
	if _focus_xp_stack != null:
		_apply_focus_xp_progress(progress)
		_focus_xp_stack.visible = _journey_should_show_focus_xp()

func _refresh_gamification_surfaces() -> void:
	if not _is_xp_system_enabled():
		if _focus_xp_stack != null:
			_apply_focus_xp_progress({})
			_focus_xp_stack.visible = false
		if _gamification_hud != null:
			_gamification_hud.configure_progress({})
			_gamification_hud.set_hud_visible(false)
		_refresh_profile_overlay()
		return
	if _gamification_hub != null:
		_configure_gamification_progress(SURVEY_GAMIFICATION_STORE.build_progress_state(_gamification_hub.current_profile()))
	elif _focus_xp_stack != null:
		_apply_focus_xp_progress({})
		_focus_xp_stack.visible = false
	if _gamification_hud != null:
		_gamification_hud.set_hud_visible(_journey_should_show_hud())
	_refresh_profile_overlay()

func _is_xp_system_enabled() -> bool:
	return xp_system_enabled

func _refresh_focus_xp_theme() -> void:
	if _focus_xp_stack == null:
		return
	_focus_xp_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_nav_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_heading(_focus_xp_level_label, 16, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.apply_text_outline(_focus_xp_level_label, 3, Color(0, 0, 0, 0.95))
	var bar_style: StyleBoxFlat = SurveyStyle.panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 999, 0)
	bar_style.content_margin_left = 0
	bar_style.content_margin_right = 0
	bar_style.content_margin_top = 0
	bar_style.content_margin_bottom = 0
	_focus_xp_bar.add_theme_stylebox_override("panel", bar_style)
	if _gamification_hub != null:
		_apply_focus_xp_progress(SURVEY_GAMIFICATION_STORE.build_progress_state(_gamification_hub.current_profile()))
	else:
		_apply_focus_xp_progress({})

func _refresh_focus_xp_layout(viewport_size: Vector2) -> void:
	if _focus_xp_stack == null:
		return
	var compact_layout: bool = viewport_size.x <= 640.0
	var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
	_focus_xp_stack.custom_minimum_size = Vector2((148.0 if compact_layout else 220.0) * (journey_scale if compact_layout else 1.0), 0.0)
	_focus_xp_stack.add_theme_constant_override("separation", int(round((2 if compact_layout else 3) * (journey_scale if compact_layout else 1.0))))
	_focus_xp_bar.custom_minimum_size = Vector2(0.0, (10.0 if compact_layout else 12.0) * (journey_scale if compact_layout else 1.0))
	_focus_xp_level_label.add_theme_font_size_override("font_size", int(round((14 if compact_layout else 16) * (journey_scale if compact_layout else 1.0))))
	_focus_xp_segment_row.add_theme_constant_override("separation", 2 if compact_layout else 3)

func _apply_focus_xp_progress(progress: Dictionary) -> void:
	if _focus_xp_stack == null:
		return
	var level: int = max(1, int(progress.get("level", 1)))
	var segment_count: int = max(8, int(progress.get("segment_count", 20)))
	var progress_ratio: float = clampf(float(progress.get("progress_ratio", 0.0)), 0.0, 1.0)
	var active_buff_label: String = str(progress.get("active_buff_label", "")).strip_edges()
	_focus_xp_level_label.text = "Level %d" % level
	_focus_xp_stack.tooltip_text = active_buff_label
	_ensure_focus_xp_segments(segment_count)
	var filled_segments: int = int(round(progress_ratio * float(segment_count)))
	for segment_index in range(_focus_xp_segment_controls.size()):
		var segment: Control = _focus_xp_segment_controls[segment_index]
		if segment == null:
			continue
		var fill: ColorRect = segment.get_node_or_null("Fill") as ColorRect
		if fill == null:
			continue
		fill.color = SurveyStyle.HIGHLIGHT_GOLD if segment_index < filled_segments else SurveyStyle.BORDER

func _ensure_focus_xp_segments(target_count: int) -> void:
	while _focus_xp_segment_controls.size() > target_count:
		var control: Control = _focus_xp_segment_controls.pop_back()
		if control != null:
			control.queue_free()
	while _focus_xp_segment_controls.size() < target_count:
		var segment := PanelContainer.new()
		segment.clip_contents = true
		segment.custom_minimum_size = Vector2(0.0, 8.0)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_style: StyleBoxFlat = SurveyStyle.panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 999, 0)
		segment_style.content_margin_left = 0
		segment_style.content_margin_right = 0
		segment_style.content_margin_top = 0
		segment_style.content_margin_bottom = 0
		segment.add_theme_stylebox_override("panel", segment_style)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.anchors_preset = Control.PRESET_FULL_RECT
		fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		fill.grow_vertical = Control.GROW_DIRECTION_BOTH
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = SurveyStyle.BORDER
		segment.add_child(fill)
		_focus_xp_segment_row.add_child(segment)
		_focus_xp_segment_controls.append(segment)

func _question_reward_key(question_id: String) -> String:
	var normalized_question_id: String = question_id.strip_edges()
	if normalized_question_id.is_empty():
		return ""
	var survey_id: String = survey.id.strip_edges() if survey != null else ""
	return "%s::%s" % [survey_id if not survey_id.is_empty() else "survey", normalized_question_id]

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
