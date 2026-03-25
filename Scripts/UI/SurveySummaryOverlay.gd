class_name SurveySummaryOverlay
extends CanvasLayer

const SUMMARY_CARD_SCENE := preload("res://Scenes/UI/SurveySummaryCard.tscn")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal close_requested
signal copy_png_requested
signal save_png_requested
signal adjective_text_changed(text: String)

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _panel_scroll: ScrollContainer = $Bounds/Center/Panel/PanelScroll
@onready var _heading_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/HeadingRow/CloseButton
@onready var _summary_label: Label = $Bounds/Center/Panel/PanelScroll/Stack/SummaryLabel
@onready var _copy_png_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ExportActions/CopyPngButton
@onready var _save_png_button: Button = $Bounds/Center/Panel/PanelScroll/Stack/ExportActions/SavePngButton
@onready var _summary_card = $Bounds/Center/Panel/PanelScroll/Stack/SummaryCard

var _summary_data: Dictionary = {}
var _adjective_text := ""
var _copy_png_enabled := true
var _save_png_label := "Save PNG"

func _ready() -> void:
	layer = 56
	visible = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_copy_png_button.pressed.connect(_on_copy_png_pressed)
	_save_png_button.pressed.connect(_on_save_png_pressed)
	_summary_card.adjective_text_changed.connect(_on_summary_card_adjective_text_changed)

	for button in [_close_button, _copy_png_button, _save_png_button]:
		_wire_feedback(button)

func open_summary(summary_data: Dictionary, adjective_text: String = "") -> void:
	_summary_data = summary_data.duplicate(true)
	_adjective_text = adjective_text.strip_edges()
	_summary_card.configure(_summary_data, _adjective_text)
	_summary_card.refresh_layout(_panel.size.x if _panel != null else get_viewport().get_visible_rect().size.x)
	show()
	call_deferred("_reset_scroll_position")

func update_summary(summary_data: Dictionary, adjective_text: String = "") -> void:
	_summary_data = summary_data.duplicate(true)
	_adjective_text = adjective_text.strip_edges()
	_summary_card.configure(_summary_data, _adjective_text)
	_summary_card.refresh_layout(_panel.size.x if _panel != null else get_viewport().get_visible_rect().size.x)

func close_summary() -> void:
	hide()

func set_png_action_capabilities(copy_enabled: bool, save_label: String = "Save PNG") -> void:
	_copy_png_enabled = copy_enabled
	_save_png_label = save_label.strip_edges()
	_apply_png_action_state()

func current_adjective_text() -> String:
	return _summary_card.current_adjective_text() if is_node_ready() else _adjective_text

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_body(_summary_label)
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.custom_minimum_size = Vector2(44, 44)
	SurveyStyle.apply_primary_button(_copy_png_button)
	SurveyStyle.apply_secondary_button(_save_png_button)
	_apply_png_action_state()
	_summary_card.refresh_theme()

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.04, 12.0, 64.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.04, 12.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))

	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 300.0, 980.0)
	var panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 300.0, 820.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_panel_scroll.custom_minimum_size = Vector2(0.0, panel_height)
	_panel_scroll.scroll_horizontal = 0
	_summary_card.refresh_layout(panel_width)

func _apply_png_action_state() -> void:
	if not is_node_ready():
		return
	_copy_png_button.disabled = not _copy_png_enabled
	_copy_png_button.tooltip_text = "" if _copy_png_enabled else "PNG clipboard copy is only available in the desktop Windows build."
	_save_png_button.text = _save_png_label if not _save_png_label.is_empty() else "Save PNG"

func capture_summary_image() -> Image:
	if _summary_data.is_empty():
		return null

	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280, 320)
	add_child(viewport)

	var export_card = SUMMARY_CARD_SCENE.instantiate()
	if export_card == null:
		viewport.queue_free()
		return null
	export_card.custom_minimum_size = Vector2(viewport.size.x, 0.0)
	viewport.add_child(export_card)
	export_card.configure(_summary_data, current_adjective_text())
	export_card.refresh_layout(float(viewport.size.x))

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var export_height: int = int(ceil(maxf(export_card.get_combined_minimum_size().y, 320.0)))
	viewport.size = Vector2i(viewport.size.x, export_height)
	export_card.custom_minimum_size = Vector2(viewport.size.x, export_height)
	export_card.size = Vector2(viewport.size.x, export_height)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image

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

func _on_copy_png_pressed() -> void:
	copy_png_requested.emit()

func _on_save_png_pressed() -> void:
	save_png_requested.emit()

func _on_summary_card_adjective_text_changed(text: String) -> void:
	_adjective_text = text.strip_edges()
	adjective_text_changed.emit(_adjective_text)



