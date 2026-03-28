class_name QuestionHelpOverlay
extends CanvasLayer

const SURVEY_MARKDOWN = preload("res://Scripts/UI/SurveyMarkdown.gd")

signal closed

@onready var _dimmer: ColorRect = $Dimmer
@onready var _bounds: MarginContainer = $Bounds
@onready var _panel: PanelContainer = $Bounds/Center/Panel
@onready var _stack: VBoxContainer = $Bounds/Center/Panel/Stack
@onready var _heading_label: Label = $Bounds/Center/Panel/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Bounds/Center/Panel/Stack/HeadingRow/CloseButton
@onready var _subtitle_label: Label = $Bounds/Center/Panel/Stack/SubtitleLabel
@onready var _body_scroll: ScrollContainer = $Bounds/Center/Panel/Stack/BodyScroll
@onready var _body_label: RichTextLabel = $Bounds/Center/Panel/Stack/BodyScroll/BodyLabel

func _ready() -> void:
	layer = 55
	visible = false
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(close_help)

func open_help(question: SurveyQuestion, show_debug_ids: bool = false) -> void:
	if question == null:
		return
	var type_label := question.display_type_label()
	var debug_line := "ID: %s" % question.id if show_debug_ids and not question.id.is_empty() else ""
	_heading_label.text = question.prompt.strip_edges() if not question.prompt.strip_edges().is_empty() else "Question Help"
	_subtitle_label.text = "%s%s" % [type_label, " | %s" % debug_line if not debug_line.is_empty() else ""]
	_body_label.clear()
	_body_label.append_text(SURVEY_MARKDOWN.to_bbcode(question.help_markdown_text()))
	show()
	call_deferred("_refresh_content_height")
	call_deferred("_reset_scroll_position")

func close_help() -> void:
	if not visible:
		return
	hide()
	closed.emit()

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.style_heading(_heading_label, 22)
	SurveyStyle.style_caption(_subtitle_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.apply_secondary_button(_close_button)
	_close_button.text = "Close"
	_body_label.add_theme_color_override("default_color", SurveyStyle.TEXT_PRIMARY)
	_body_label.add_theme_color_override("font_outline_color", SurveyStyle.TEXT_OUTLINE)
	_body_label.add_theme_constant_override("outline_size", 1)
	_body_label.add_theme_font_size_override("normal_font_size", 15)

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.05, 12.0, 80.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.05, 12.0, 56.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))
	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 300.0, 880.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	call_deferred("_refresh_content_height")

func _reset_scroll_position() -> void:
	_body_scroll.scroll_vertical = 0

func _refresh_content_height() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var horizontal_margin: float = clampf(viewport_size.x * 0.05, 12.0, 80.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.05, 12.0, 56.0)
	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 300.0, 880.0)
	var max_panel_height: float = clampf(viewport_size.y - (vertical_margin * 2.0), 220.0, 760.0)
	var body_width := maxf(panel_width - 36.0, 220.0)
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_body_label.custom_minimum_size.x = body_width
	_body_label.size = Vector2(body_width, 0.0)
	_body_label.reset_size()
	var stack_separation := float(_stack.get_theme_constant("separation"))
	var heading_row_height := maxf(_heading_label.get_combined_minimum_size().y, _close_button.get_combined_minimum_size().y)
	var subtitle_height := 0.0 if _subtitle_label.text.strip_edges().is_empty() else _subtitle_label.get_combined_minimum_size().y
	var body_height := maxf(float(_body_label.get_content_height()), _body_label.get_combined_minimum_size().y)
	var chrome_height := 36.0 + heading_row_height + stack_separation
	if subtitle_height > 0.0:
		chrome_height += subtitle_height + stack_separation
	var max_body_height := maxf(max_panel_height - chrome_height, 72.0)
	var target_body_height := clampf(body_height + 6.0, 48.0, max_body_height)
	_body_scroll.custom_minimum_size = Vector2(0.0, target_body_height)

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_help()
