class_name SurveySettingsOverlay
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal close_requested
signal theme_mode_requested(use_dark_mode: bool)
signal sfx_volume_requested(volume: float)
signal hover_sfx_requested(enabled: bool)
signal remember_onboarding_requested(enabled: bool)
signal local_session_cache_requested(enabled: bool)

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SummaryLabel
@onready var _theme_toggle_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ThemeToggleButton
@onready var _sfx_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxHeadingLabel
@onready var _sfx_volume_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxVolumeLabel
@onready var _sfx_volume_slider: HSlider = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxVolumeSlider
@onready var _sfx_value_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SfxRow/SfxValueLabel
@onready var _hover_sfx_checkbox: CheckBox = $Bounds/Center/Panel/PanelScroll/Stack/HoverSfxCheckBox
@onready var _hover_sfx_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HoverSfxLabel
@onready var _privacy_heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/PrivacyHeadingLabel
@onready var _privacy_summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/PrivacySummaryLabel
@onready var _remember_onboarding_checkbox: CheckBox = $Bounds/Center/Panel/PanelScroll/Stack/RememberOnboardingCheckBox
@onready var _remember_onboarding_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/RememberOnboardingLabel
@onready var _local_session_cache_checkbox: CheckBox = $Bounds/Center/Panel/PanelScroll/Stack/LocalSessionCacheCheckBox
@onready var _local_session_cache_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/LocalSessionCacheLabel

var _current_sfx_volume := SURVEY_UI_FEEDBACK.DEFAULT_SFX_VOLUME

func _ready() -> void:
	layer = 57
	visible = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_theme_toggle_button.toggled.connect(_on_theme_toggle_toggled)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_value_changed)
	_hover_sfx_checkbox.toggled.connect(_on_hover_sfx_toggled)
	_remember_onboarding_checkbox.toggled.connect(_on_remember_onboarding_toggled)
	_local_session_cache_checkbox.toggled.connect(_on_local_session_cache_toggled)

	for button in [_close_button, _theme_toggle_button, _hover_sfx_checkbox, _remember_onboarding_checkbox, _local_session_cache_checkbox]:
		_wire_feedback(button)

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.style_heading(_heading_label, 22 if _panel.custom_minimum_size.x <= 420.0 else 24)
	SurveyStyle.style_body(_summary_label)
	SurveyStyle.style_heading(_sfx_heading_label, 18)
	SurveyStyle.style_body(_sfx_volume_label)
	SurveyStyle.style_caption(_sfx_value_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_check_box(_hover_sfx_checkbox)
	SurveyStyle.style_caption(_hover_sfx_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_heading(_privacy_heading_label, 18)
	SurveyStyle.style_caption(_privacy_summary_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_caption(_remember_onboarding_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_caption(_local_session_cache_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	SurveyStyle.style_check_box(_remember_onboarding_checkbox)
	SurveyStyle.style_check_box(_local_session_cache_checkbox)
	_refresh_theme_toggle_button()
	_refresh_sfx_volume_display()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.04, 12.0, 64.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.04, 12.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))

	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 300.0, 720.0)
	var panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 300.0, 760.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_panel_scroll.scroll_horizontal = 0

func open_settings(use_dark_mode: bool, current_sfx_volume: float, hover_sfx_enabled: bool, remember_onboarding: bool, allow_local_session_cache: bool) -> void:
	_theme_toggle_button.set_pressed_no_signal(use_dark_mode)
	_refresh_theme_toggle_button()
	_current_sfx_volume = clampf(current_sfx_volume, 0.0, 1.0)
	_sfx_volume_slider.set_value_no_signal(_current_sfx_volume)
	_refresh_sfx_volume_display()
	_hover_sfx_checkbox.set_pressed_no_signal(hover_sfx_enabled)
	_remember_onboarding_checkbox.set_pressed_no_signal(remember_onboarding)
	_local_session_cache_checkbox.set_pressed_no_signal(allow_local_session_cache)
	show()
	call_deferred("_reset_scroll_position")

func close_settings() -> void:
	hide()

func _refresh_theme_toggle_button() -> void:
	_theme_toggle_button.text = "Theme: Dark" if _theme_toggle_button.button_pressed else "Theme: Light"
	if _theme_toggle_button.button_pressed:
		SurveyStyle.apply_primary_button(_theme_toggle_button)
	else:
		SurveyStyle.apply_secondary_button(_theme_toggle_button)

func _refresh_sfx_volume_display() -> void:
	if _sfx_volume_slider == null:
		return
	_current_sfx_volume = clampf(_sfx_volume_slider.value, 0.0, 1.0)
	_sfx_value_label.text = "%d%%" % int(round(_current_sfx_volume * 100.0))

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

func _on_theme_toggle_toggled(button_pressed: bool) -> void:
	_refresh_theme_toggle_button()
	theme_mode_requested.emit(button_pressed)

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	_current_sfx_volume = clampf(value, 0.0, 1.0)
	_refresh_sfx_volume_display()
	sfx_volume_requested.emit(_current_sfx_volume)

func _on_hover_sfx_toggled(enabled: bool) -> void:
	hover_sfx_requested.emit(enabled)

func _on_remember_onboarding_toggled(enabled: bool) -> void:
	remember_onboarding_requested.emit(enabled)

func _on_local_session_cache_toggled(enabled: bool) -> void:
	local_session_cache_requested.emit(enabled)
