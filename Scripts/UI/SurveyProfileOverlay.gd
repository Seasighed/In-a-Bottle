class_name SurveyProfileOverlay
extends CanvasLayer

const PROFILE_CARD_SCENE := preload("res://Scenes/UI/SurveyProfileCard.tscn")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal close_requested
signal copy_png_requested
signal save_png_requested
signal copy_json_requested
signal save_json_requested
signal copy_csv_requested
signal save_csv_requested
signal share_json_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _subtitle_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SubtitleLabel
@onready var _action_grid: GridContainer = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid
@onready var _copy_png_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/CopyPngButton
@onready var _save_png_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/SavePngButton
@onready var _copy_json_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/CopyJsonButton
@onready var _save_json_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/SaveJsonButton
@onready var _copy_csv_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/CopyCsvButton
@onready var _save_csv_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/SaveCsvButton
@onready var _share_json_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ActionGrid/ShareJsonButton
@onready var _profile_card: Control = $Bounds/Center/Panel/PanelScroll/Stack/ProfileCard

var _snapshot: Dictionary = {}
var _copy_png_enabled := true
var _save_png_label := "Save PNG"

func _ready() -> void:
	layer = 57
	visible = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_copy_png_button.pressed.connect(func() -> void: copy_png_requested.emit())
	_save_png_button.pressed.connect(func() -> void: save_png_requested.emit())
	_copy_json_button.pressed.connect(func() -> void: copy_json_requested.emit())
	_save_json_button.pressed.connect(func() -> void: save_json_requested.emit())
	_copy_csv_button.pressed.connect(func() -> void: copy_csv_requested.emit())
	_save_csv_button.pressed.connect(func() -> void: save_csv_requested.emit())
	_share_json_button.pressed.connect(func() -> void: share_json_requested.emit())
	for button in [_close_button, _copy_png_button, _save_png_button, _copy_json_button, _save_json_button, _copy_csv_button, _save_csv_button, _share_json_button]:
		_wire_feedback(button)

func open_profile(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if _profile_card != null and _profile_card.has_method("configure"):
		_profile_card.call("configure", _snapshot)
	show()
	call_deferred("_reset_scroll_position")

func update_profile(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if _profile_card != null and _profile_card.has_method("configure"):
		_profile_card.call("configure", _snapshot)

func close_profile() -> void:
	hide()

func set_png_action_capabilities(copy_enabled: bool, save_label: String = "Save PNG") -> void:
	_copy_png_enabled = copy_enabled
	_save_png_label = save_label.strip_edges()
	_apply_png_action_state()

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.apply_secondary_button(_close_button)
	SurveyStyle.apply_primary_button(_copy_png_button)
	SurveyStyle.apply_secondary_button(_save_png_button)
	SurveyStyle.apply_secondary_button(_copy_json_button)
	SurveyStyle.apply_secondary_button(_save_json_button)
	SurveyStyle.apply_secondary_button(_copy_csv_button)
	SurveyStyle.apply_secondary_button(_save_csv_button)
	SurveyStyle.apply_primary_button(_share_json_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	if _profile_card != null and _profile_card.has_method("refresh_theme"):
		_profile_card.call("refresh_theme")
	_apply_png_action_state()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin := clampf(viewport_size.x * 0.04, 12.0, 64.0)
	var vertical_margin := clampf(viewport_size.y * 0.04, 12.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))
	var panel_width := clampf(viewport_size.x - (horizontal_margin * 2.0), 320.0, 980.0)
	var panel_height := clampf(viewport_size.y - (vertical_margin * 2.0), 320.0, 820.0)
	var compact := panel_width <= 620.0
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_panel_scroll.scroll_horizontal = 0
	_action_grid.columns = 1 if compact else 3
	if _profile_card != null and _profile_card.has_method("refresh_layout"):
		_profile_card.call("refresh_layout", panel_width)

func capture_profile_image() -> Image:
	if _snapshot.is_empty():
		return null
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280, 320)
	add_child(viewport)
	var export_card: Control = PROFILE_CARD_SCENE.instantiate() as Control
	if export_card == null:
		viewport.queue_free()
		return null
	export_card.custom_minimum_size = Vector2(viewport.size.x, 0.0)
	viewport.add_child(export_card)
	if export_card.has_method("configure"):
		export_card.call("configure", _snapshot)
	if export_card.has_method("refresh_layout"):
		export_card.call("refresh_layout", float(viewport.size.x))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var export_height := int(ceil(maxf(export_card.get_combined_minimum_size().y, 320.0)))
	viewport.size = Vector2i(viewport.size.x, export_height)
	export_card.custom_minimum_size = Vector2(viewport.size.x, export_height)
	export_card.size = Vector2(viewport.size.x, export_height)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image

func _apply_png_action_state() -> void:
	_copy_png_button.disabled = not _copy_png_enabled
	_copy_png_button.tooltip_text = "" if _copy_png_enabled else "PNG clipboard copy is only available in the desktop Windows build."
	_save_png_button.text = _save_png_label if not _save_png_label.is_empty() else "Save PNG"

func _reset_scroll_position() -> void:
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
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()
