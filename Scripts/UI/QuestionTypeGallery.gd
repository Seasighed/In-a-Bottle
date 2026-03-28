class_name QuestionTypeGallery
extends Control

const QUESTION_VIEW_REGISTRY = preload("res://Scripts/UI/QuestionViewRegistry.gd")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")

@export var dark_palette: Resource = DEFAULT_DARK_PALETTE
@export var light_palette: Resource = DEFAULT_LIGHT_PALETTE
@export var use_dark_mode := true
@export_range(320.0, 720.0, 10.0) var minimum_card_width := 420.0
@export_range(320.0, 840.0, 10.0) var maximum_card_width := 560.0
@export_range(8.0, 48.0, 1.0) var grid_gap := 20.0
@export var show_question_debug_ids := false

var _example_views: Array[SurveyQuestionView] = []

@onready var _background: ColorRect = $Background
@onready var _heading_label: Label = $Margin/Shell/HeadingLabel
@onready var _description_label: Label = $Margin/Shell/DescriptionLabel
@onready var _grid: GridContainer = $Margin/Shell/GalleryScroll/Grid

func _ready() -> void:
	dark_palette = dark_palette if dark_palette != null else DEFAULT_DARK_PALETTE
	light_palette = light_palette if light_palette != null else DEFAULT_LIGHT_PALETTE
	SurveyStyle.configure_palettes(dark_palette, light_palette, use_dark_mode)
	_build_gallery()
	_refresh_theme()
	call_deferred("_refresh_gallery_layout")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_refresh_gallery_layout")

func _build_gallery() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_example_views.clear()
	for definition in QUESTION_VIEW_REGISTRY.gallery_definitions():
		_grid.add_child(_build_gallery_card(definition))

func _build_gallery_card(definition: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var stack := VBoxContainer.new()
	stack.layout_mode = 2
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)

	var title_label := Label.new()
	title_label.text = str(definition.get("title", "Question Type"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title_label)

	var scene_path_label := Label.new()
	scene_path_label.text = str(definition.get("scene_path", ""))
	scene_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(scene_path_label)

	var question := SurveyQuestion.new(definition.get("question_config", {}))
	var answer_value: Variant = _duplicate_variant(definition.get("answer", question.default_value))
	var question_view := QUESTION_VIEW_REGISTRY.instantiate_for_question(question)
	if question_view != null:
		question_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_view.set_presentation_mode(SurveyQuestionView.PRESENTATION_DOCUMENT)
		question_view.set_question_debug_ids_enabled(show_question_debug_ids)
		question_view.configure(question, answer_value)
		stack.add_child(question_view)
		_example_views.append(question_view)
	else:
		var fallback_label := Label.new()
		fallback_label.text = "Unable to instantiate example view."
		fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(fallback_label)

	_style_gallery_card(card, title_label, scene_path_label)
	return card

func _refresh_theme() -> void:
	_background.color = SurveyStyle.BACKGROUND
	SurveyStyle.style_heading(_heading_label, 28)
	SurveyStyle.style_body(_description_label)
	_grid.add_theme_constant_override("h_separation", int(grid_gap))
	_grid.add_theme_constant_override("v_separation", int(grid_gap))
	for child in _grid.get_children():
		var card := child as PanelContainer
		if card == null:
			continue
		var stack := card.get_child(0) as VBoxContainer
		var title_label: Label = null
		var scene_path_label: Label = null
		if stack != null and stack.get_child_count() > 0:
			title_label = stack.get_child(0) as Label
		if stack != null and stack.get_child_count() > 1:
			scene_path_label = stack.get_child(1) as Label
		_style_gallery_card(card, title_label, scene_path_label)

func _style_gallery_card(card: PanelContainer, title_label: Label, scene_path_label: Label) -> void:
	if card == null:
		return
	SurveyStyle.apply_panel(card, SurveyStyle.SURFACE, SurveyStyle.BORDER, 18, 1)
	if title_label != null:
		SurveyStyle.style_heading(title_label, 20)
	if scene_path_label != null:
		SurveyStyle.style_caption(scene_path_label, SurveyStyle.TEXT_MUTED)
		scene_path_label.add_theme_constant_override("outline_size", 1)

func _refresh_gallery_layout() -> void:
	if _grid == null:
		return
	var available_width := _grid.size.x
	if available_width <= 0.0:
		available_width = size.x - 64.0
	if available_width <= 0.0:
		available_width = get_viewport().get_visible_rect().size.x - 64.0
	var gap: float = grid_gap
	var columns: int = maxi(1, int(floor((available_width + gap) / (minimum_card_width + gap))))
	_grid.columns = columns
	var usable_width: float = maxf(available_width - (gap * float(maxi(columns - 1, 0))), minimum_card_width)
	var card_width: float = clampf(usable_width / float(columns), minimum_card_width, maximum_card_width)
	for child in _grid.get_children():
		var card := child as Control
		if card == null:
			continue
		card.custom_minimum_size = Vector2(card_width, 0.0)
	for view in _example_views:
		if view == null or not is_instance_valid(view):
			continue
		view.refresh_responsive_layout(Vector2(card_width, get_viewport().get_visible_rect().size.y))
		view.set_question_debug_ids_enabled(show_question_debug_ids)

func _duplicate_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return value
