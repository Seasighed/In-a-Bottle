class_name SurveyStyle
extends RefCounted

static var BACKGROUND := Color("1e1e1e")
static var SURFACE := Color("252526")
static var SURFACE_ALT := Color("2d2d30")
static var SURFACE_MUTED := Color("333337")
static var BORDER := Color("3e3e42")
static var ACCENT := Color("0e639c")
static var ACCENT_ALT := Color("3794ff")
static var TEXT_PRIMARY := Color("d4d4d4")
static var TEXT_MUTED := Color("a7a7a7")
static var TEXT_DARK := Color("161616")
static var TEXT_ON_ACCENT := Color("ffffff")
static var TEXT_OUTLINE := Color(0, 0, 0, 0.45)
static var DANGER := Color("c74e39")
static var SUCCESS := Color("3cab68")
static var OVERLAY_DIMMER := Color(0, 0, 0, 0.62)
static var HIGHLIGHT_GOLD := Color("d7b154")
static var SOFT_WHITE := Color(1, 1, 1, 0.58)

static var _dark_palette = null
static var _light_palette = null
static var _is_dark_mode := true

static func configure_palettes(dark_palette, light_palette, start_in_dark_mode: bool = true) -> void:
	_dark_palette = dark_palette
	_light_palette = light_palette
	set_dark_mode(start_in_dark_mode)

static func set_dark_mode(enabled: bool) -> void:
	_is_dark_mode = enabled
	var palette: Variant = _dark_palette if enabled else _light_palette
	if palette != null:
		_apply_palette(palette)

static func is_dark_mode() -> bool:
	return _is_dark_mode

static func _apply_palette(palette) -> void:
	BACKGROUND = palette.background
	SURFACE = palette.surface
	SURFACE_ALT = palette.surface_alt
	SURFACE_MUTED = palette.surface_muted
	BORDER = palette.border
	ACCENT = palette.accent
	ACCENT_ALT = palette.accent_alt
	TEXT_PRIMARY = palette.text_primary
	TEXT_MUTED = palette.text_muted
	TEXT_DARK = palette.text_dark
	TEXT_ON_ACCENT = palette.text_on_accent
	TEXT_OUTLINE = palette.text_outline
	DANGER = palette.danger
	OVERLAY_DIMMER = palette.overlay_dimmer

static func panel(fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 18, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

static func apply_panel(panel_node: PanelContainer, fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 18, border_width: int = 1) -> void:
	panel_node.add_theme_stylebox_override("panel", panel(fill, border, radius, border_width))

static func apply_text_outline(control: Control, outline_size: int = 3, outline_color: Color = Color(0, 0, 0, 0)) -> void:
	control.add_theme_color_override("font_outline_color", outline_color if outline_color != Color(0, 0, 0, 0) else TEXT_OUTLINE)
	control.add_theme_constant_override("outline_size", outline_size)

static func _ensure_control_minimum_height(control: Control, minimum_height: float = 44.0) -> void:
	var current_size := control.custom_minimum_size
	control.custom_minimum_size = Vector2(maxf(current_size.x, 0.0), maxf(current_size.y, minimum_height))

static func apply_primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel(ACCENT, ACCENT, 14, 0))
	button.add_theme_stylebox_override("focus", panel(ACCENT.lightened(0.05), ACCENT, 14, 0))
	button.add_theme_stylebox_override("hover", panel(ACCENT.lightened(0.08), ACCENT, 14, 0))
	button.add_theme_stylebox_override("pressed", panel(ACCENT.darkened(0.08), ACCENT, 14, 0))
	button.add_theme_color_override("font_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_focus_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_hover_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_pressed_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	apply_text_outline(button, 2)
	_ensure_control_minimum_height(button)

static func apply_secondary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel(SURFACE_ALT, BORDER, 14, 1))
	button.add_theme_stylebox_override("focus", panel(SURFACE_MUTED, ACCENT_ALT, 14, 1))
	button.add_theme_stylebox_override("hover", panel(SURFACE_MUTED, BORDER.lightened(0.08), 14, 1))
	button.add_theme_stylebox_override("pressed", panel(SURFACE, ACCENT_ALT, 14, 1))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	apply_text_outline(button, 2)
	_ensure_control_minimum_height(button)

static func apply_answer_button(button: Button, is_selected: bool) -> void:
	if is_selected:
		button.add_theme_stylebox_override("normal", panel(SURFACE_MUTED, HIGHLIGHT_GOLD, 14, 2))
		button.add_theme_stylebox_override("focus", panel(SURFACE_MUTED, HIGHLIGHT_GOLD.lightened(0.06), 14, 2))
		button.add_theme_stylebox_override("hover", panel(SURFACE_MUTED.lightened(0.03), HIGHLIGHT_GOLD.lightened(0.08), 14, 2))
		button.add_theme_stylebox_override("pressed", panel(SURFACE, HIGHLIGHT_GOLD, 14, 2))
		button.add_theme_color_override("font_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
		apply_text_outline(button, 2)
		_ensure_control_minimum_height(button)
		return
	button.add_theme_stylebox_override("normal", panel(SURFACE_ALT, BORDER, 14, 2))
	button.add_theme_stylebox_override("focus", panel(SURFACE_MUTED, ACCENT_ALT, 14, 2))
	button.add_theme_stylebox_override("hover", panel(SURFACE_MUTED, BORDER.lightened(0.08), 14, 2))
	button.add_theme_stylebox_override("pressed", panel(SURFACE, ACCENT_ALT, 14, 2))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	apply_text_outline(button, 2)
	_ensure_control_minimum_height(button)

static func apply_danger_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel(DANGER, DANGER, 14, 0))
	button.add_theme_stylebox_override("focus", panel(DANGER.lightened(0.04), DANGER, 14, 0))
	button.add_theme_stylebox_override("hover", panel(DANGER.lightened(0.06), DANGER, 14, 0))
	button.add_theme_stylebox_override("pressed", panel(DANGER.darkened(0.08), DANGER, 14, 0))
	button.add_theme_color_override("font_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_focus_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_hover_color", TEXT_ON_ACCENT)
	button.add_theme_color_override("font_pressed_color", TEXT_ON_ACCENT)
	apply_text_outline(button, 2)
	_ensure_control_minimum_height(button)

static func style_heading(label: Label, size: int = 26, color: Color = Color(0, 0, 0, 0)) -> void:
	label.add_theme_color_override("font_color", color if color != Color(0, 0, 0, 0) else TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", size)
	apply_text_outline(label, 3)

static func style_body(label: Label, color: Color = Color(0, 0, 0, 0)) -> void:
	label.add_theme_color_override("font_color", color if color != Color(0, 0, 0, 0) else TEXT_MUTED)
	label.add_theme_font_size_override("font_size", 15)
	apply_text_outline(label, 2)

static func style_caption(label: Label, color: Color = Color(0, 0, 0, 0)) -> void:
	label.add_theme_color_override("font_color", color if color != Color(0, 0, 0, 0) else TEXT_MUTED)
	label.add_theme_font_size_override("font_size", 13)
	apply_text_outline(label, 1)

static func style_tree(tree: Tree) -> void:
	tree.add_theme_color_override("font_color", TEXT_PRIMARY)
	tree.add_theme_color_override("font_selected_color", TEXT_PRIMARY)
	tree.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	tree.add_theme_color_override("guide_color", BORDER)
	tree.add_theme_constant_override("outline_size", 2)

static func style_line_edit(field: LineEdit) -> void:
	field.custom_minimum_size = Vector2(0, 42)
	field.add_theme_color_override("font_color", TEXT_PRIMARY)
	field.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	apply_text_outline(field, 1)
	field.add_theme_stylebox_override("normal", panel(SURFACE_ALT, BORDER, 14, 1))
	field.add_theme_stylebox_override("focus", panel(SURFACE_MUTED, ACCENT_ALT, 14, 1))

static func style_text_edit(field: TextEdit) -> void:
	field.add_theme_color_override("font_color", TEXT_PRIMARY)
	field.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	apply_text_outline(field, 1)
	field.add_theme_stylebox_override("normal", panel(SURFACE_ALT, BORDER, 14, 1))
	field.add_theme_stylebox_override("focus", panel(SURFACE_MUTED, ACCENT_ALT, 14, 1))

static func style_option_button(button: OptionButton) -> void:
	_ensure_control_minimum_height(button)
	button.add_theme_stylebox_override("normal", panel(SURFACE_ALT, BORDER, 14, 1))
	button.add_theme_stylebox_override("hover", panel(SURFACE_MUTED, BORDER, 14, 1))
	button.add_theme_stylebox_override("pressed", panel(SURFACE, ACCENT_ALT, 14, 1))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	apply_text_outline(button, 1)

static func style_check_box(check_box: CheckBox) -> void:
	check_box.add_theme_color_override("font_color", TEXT_PRIMARY)
	check_box.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	check_box.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	check_box.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	apply_text_outline(check_box, 1)
