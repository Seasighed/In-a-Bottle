class_name SurveyExportOverlay
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal close_requested
signal save_progress_requested
signal load_progress_requested
signal copy_json_requested
signal save_json_requested
signal copy_csv_requested
signal save_csv_requested
signal upload_requested
signal copy_response_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SummaryLabel
@onready var _local_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/LocalHeadingLabel
@onready var _local_summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/LocalSummaryLabel
@onready var _save_progress_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/LocalActions/SaveProgressButton
@onready var _load_progress_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/LocalActions/LoadProgressButton
@onready var _answer_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/AnswerHeadingLabel
@onready var _answer_summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/AnswerSummaryLabel
@onready var _copy_json_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/AnswerActions/CopyJsonButton
@onready var _save_json_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/AnswerActions/SaveJsonButton
@onready var _copy_csv_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/AnswerActions/CopyCsvButton
@onready var _save_csv_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/AnswerActions/SaveCsvButton
@onready var _upload_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadHeadingLabel
@onready var _upload_summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadSummaryLabel
@onready var _upload_notice_panel: PanelContainer = $Bounds/Center/Panel/PanelScroll/Stack/UploadNoticePanel
@onready var _upload_use_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadNoticePanel/NoticeStack/UploadUseLabel
@onready var _upload_destination_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadNoticePanel/NoticeStack/UploadDestinationLabel
@onready var _upload_reason_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadNoticePanel/NoticeStack/UploadReasonLabel
@onready var _upload_metadata_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadNoticePanel/NoticeStack/UploadMetadataLabel
@onready var _upload_consent_checkbox: CheckBox = $Bounds/Center/Panel/PanelScroll/Stack/UploadConsentCheckBox
@onready var _upload_consent_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadConsentLabel
@onready var _upload_gate_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/UploadGateLabel
@onready var _upload_submit_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/UploadSubmitButton
@onready var _response_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ResponseHeadingLabel
@onready var _response_status_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/ResponseStatusLabel
@onready var _copy_response_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ResponseActions/CopyResponseButton
@onready var _response_text_edit: TextEdit = $Bounds/Center/Panel/PanelScroll/Stack/ResponseTextEdit

var _upload_ready := false
var _upload_busy := false
var _upload_consent_required := true
var _upload_status_is_error := false
var _upload_response_text := ""

func _ready() -> void:
	layer = 58
	visible = false
	_response_text_edit.editable = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_save_progress_button.pressed.connect(_on_save_progress_pressed)
	_load_progress_button.pressed.connect(_on_load_progress_pressed)
	_copy_json_button.pressed.connect(_on_copy_json_pressed)
	_save_json_button.pressed.connect(_on_save_json_pressed)
	_copy_csv_button.pressed.connect(_on_copy_csv_pressed)
	_save_csv_button.pressed.connect(_on_save_csv_pressed)
	_upload_consent_checkbox.toggled.connect(_on_upload_consent_toggled)
	_upload_submit_button.pressed.connect(_on_upload_submit_pressed)
	_copy_response_button.pressed.connect(_on_copy_response_pressed)

	for button in [_close_button, _save_progress_button, _load_progress_button, _copy_json_button, _save_json_button, _copy_csv_button, _save_csv_button, _upload_consent_checkbox, _upload_submit_button, _copy_response_button]:
		_wire_feedback(button)

func open_export_menu(state: Dictionary) -> void:
	_apply_state(state, true)
	show()
	call_deferred("_reset_scroll_position")

func update_state(state: Dictionary) -> void:
	_apply_state(state, false)

func close_export_menu() -> void:
	hide()

func current_upload_consent() -> bool:
	return _upload_consent_checkbox.button_pressed if is_node_ready() else false

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.apply_panel(_upload_notice_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_body(_summary_label)
	SurveyStyle.style_heading(_local_heading_label, 18)
	SurveyStyle.style_caption(_local_summary_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_heading(_answer_heading_label, 18)
	SurveyStyle.style_caption(_answer_summary_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_heading(_upload_heading_label, 18)
	SurveyStyle.style_body(_upload_summary_label)
	SurveyStyle.style_caption(_upload_use_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_upload_destination_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_upload_reason_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_upload_metadata_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_check_box(_upload_consent_checkbox)
	SurveyStyle.style_caption(_upload_consent_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_heading(_response_heading_label, 18)
	SurveyStyle.style_text_edit(_response_text_edit)
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	SurveyStyle.apply_primary_button(_save_progress_button)
	SurveyStyle.apply_secondary_button(_load_progress_button)
	SurveyStyle.apply_secondary_button(_copy_json_button)
	SurveyStyle.apply_secondary_button(_save_json_button)
	SurveyStyle.apply_secondary_button(_copy_csv_button)
	SurveyStyle.apply_secondary_button(_save_csv_button)
	SurveyStyle.apply_primary_button(_upload_submit_button)
	SurveyStyle.apply_secondary_button(_copy_response_button)
	_apply_dynamic_label_styles()
	_refresh_upload_button_state()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.04, 20.0, 64.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.04, 16.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))

	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 420.0, 920.0)
	var panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 320.0, 820.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_panel_scroll.scroll_horizontal = 0
	_response_text_edit.custom_minimum_size.y = clampf(panel_height * 0.26, 140.0, 260.0)

func _apply_state(state: Dictionary, reset_consent: bool) -> void:
	_heading_label.text = "Export Menu"
	var survey_title: String = str(state.get("survey_title", "survey")).strip_edges()
	_summary_label.text = "Save progress, export answers, or upload a sanitized submission for %s." % (survey_title if not survey_title.is_empty() else "the active survey")
	_local_summary_label.text = str(state.get("progress_summary", "Save or load the full progress bundle, including local settings and where you left off.")).strip_edges()
	_answer_summary_label.text = str(state.get("answer_summary", "Copy or save answer-only exports for manual review, debugging, or offline analysis.")).strip_edges()
	_upload_summary_label.text = "Review the disclosure below before submitting answers to the configured server endpoint."

	_save_progress_button.text = str(state.get("save_progress_label", "Save Progress JSON")).strip_edges()
	_load_progress_button.text = str(state.get("load_progress_label", "Load Progress JSON")).strip_edges()
	_save_json_button.text = str(state.get("save_json_label", "Save JSON")).strip_edges()
	_save_csv_button.text = str(state.get("save_csv_label", "Save CSV")).strip_edges()
	_save_progress_button.disabled = not bool(state.get("save_progress_enabled", true))
	_load_progress_button.disabled = not bool(state.get("load_progress_enabled", true))
	_load_progress_button.tooltip_text = str(state.get("load_progress_unavailable_reason", "")).strip_edges()

	var use_text: String = str(state.get("upload_usage_summary", "")).strip_edges()
	var destination_name: String = str(state.get("upload_destination_name", "")).strip_edges()
	var destination_url: String = str(state.get("upload_destination_url", "")).strip_edges()
	var reason_text: String = str(state.get("upload_reason_summary", "")).strip_edges()
	var metadata_text: String = str(state.get("upload_metadata_summary", "")).strip_edges()
	_upload_use_label.text = "Used for: %s" % (use_text if not use_text.is_empty() else "No upload use summary has been configured yet.")
	var destination_lines: Array[String] = []
	if not destination_name.is_empty():
		destination_lines.append(destination_name)
	if not destination_url.is_empty():
		destination_lines.append(destination_url)
	if destination_lines.is_empty():
		destination_lines.append("Upload endpoint not configured.")
	_upload_destination_label.text = "Uploaded to: %s" % "\n".join(destination_lines)
	_upload_reason_label.text = "Why: %s" % (reason_text if not reason_text.is_empty() else "No upload purpose text has been configured yet.")
	_upload_metadata_label.text = metadata_text if not metadata_text.is_empty() else "Spam protection metadata includes an anonymous install ID, upload timestamps, answer counts, and a payload hash."

	_upload_ready = bool(state.get("upload_ready", false))
	_upload_busy = bool(state.get("upload_busy", false))
	_upload_consent_required = bool(state.get("consent_required", true))
	_upload_status_is_error = bool(state.get("upload_status_error", false))
	_upload_response_text = str(state.get("upload_response_text", ""))
	_response_text_edit.text = _upload_response_text if not _upload_response_text.is_empty() else "No upload response yet."
	_copy_response_button.disabled = _upload_response_text.is_empty()
	_response_status_label.text = str(state.get("upload_status_text", "Ready when you are.")).strip_edges()
	_upload_gate_label.text = str(state.get("upload_ready_message", "Review the notice, confirm consent, then submit.")).strip_edges()

	_upload_consent_checkbox.visible = _upload_consent_required
	_upload_consent_label.visible = _upload_consent_required
	if reset_consent:
		_upload_consent_checkbox.set_pressed_no_signal(false)
	_upload_notice_panel.visible = true
	_apply_dynamic_label_styles()
	_refresh_upload_button_state()

func _apply_dynamic_label_styles() -> void:
	SurveyStyle.style_caption(_upload_gate_label, SurveyStyle.TEXT_MUTED if _upload_ready and not _upload_busy else SurveyStyle.DANGER)
	if _upload_busy:
		SurveyStyle.style_caption(_response_status_label, SurveyStyle.ACCENT_ALT)
	elif _upload_status_is_error:
		SurveyStyle.style_caption(_response_status_label, SurveyStyle.DANGER)
	else:
		SurveyStyle.style_caption(_response_status_label, SurveyStyle.TEXT_PRIMARY)

func _refresh_upload_button_state() -> void:
	var has_consent: bool = (not _upload_consent_required) or _upload_consent_checkbox.button_pressed
	_upload_submit_button.disabled = (not _upload_ready) or _upload_busy or (not has_consent)
	_upload_submit_button.text = "Submitting..." if _upload_busy else "Submit To Server"

func _reset_scroll_position() -> void:
	if _panel_scroll == null:
		return
	_panel_scroll.scroll_vertical = 0
	_panel_scroll.scroll_horizontal = 0

func _wire_feedback(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_button_hovered)
	button.pressed.connect(_on_button_pressed_feedback)

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _on_save_progress_pressed() -> void:
	save_progress_requested.emit()

func _on_load_progress_pressed() -> void:
	load_progress_requested.emit()

func _on_copy_json_pressed() -> void:
	copy_json_requested.emit()

func _on_save_json_pressed() -> void:
	save_json_requested.emit()

func _on_copy_csv_pressed() -> void:
	copy_csv_requested.emit()

func _on_save_csv_pressed() -> void:
	save_csv_requested.emit()

func _on_upload_consent_toggled(_enabled: bool) -> void:
	_refresh_upload_button_state()

func _on_upload_submit_pressed() -> void:
	upload_requested.emit()

func _on_copy_response_pressed() -> void:
	copy_response_requested.emit()

