class_name SpotlightHeader
extends SurveySectionHeaderView

const SPRITE_ICON_HOST = preload("res://Scripts/UI/SpriteIconHost.gd")
const SURVEY_ICON_LIBRARY = preload("res://Scripts/UI/SurveyIconLibrary.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _badge: Label = $Panel/Stack/BadgeLabel
@onready var _icon_slot: Control = $Panel/Stack/TitleRow/IconSlot
@onready var _title: Label = $Panel/Stack/TitleRow/TitleLabel
@onready var _body: Label = $Panel/Stack/BodyLabel

var _icon_host

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.ACCENT_ALT, 24, 1)
	SurveyStyle.style_caption(_badge, SurveyStyle.ACCENT)
	SurveyStyle.style_heading(_title, 28)
	SurveyStyle.style_body(_body)
	_ensure_icon_host()
	super()

func _apply_section() -> void:
	if section == null or survey == null:
		return
	_ensure_icon_host()
	_badge.text = "Section %d of %d" % [survey.sections.find(section) + 1, survey.sections.size()]
	_icon_host.set_icon(SURVEY_ICON_LIBRARY.section_texture(section.icon_name), SurveyStyle.ACCENT_ALT, 24.0)
	_title.text = section.display_title()
	_body.text = "%s Answered so far: %d/%d." % [section.description, section.answered_count(answers), section.questions.size()]
	_refresh_layout_metrics()

func _ensure_icon_host() -> void:
	if _icon_host != null:
		return
	_icon_host = SPRITE_ICON_HOST.new()
	_icon_host.custom_minimum_size = Vector2(28, 28)
	_icon_slot.add_child(_icon_host)

