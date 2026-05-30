class_name SurveyStyle
extends RefCounted

const CHARGE_GLOW_SHADER_CODE := """
shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_a : source_color = vec4(0.84, 0.69, 0.33, 1.0);
uniform vec4 color_b : source_color = vec4(0.22, 0.58, 1.0, 1.0);
uniform vec2 rect_size = vec2(1.0, 1.0);

void fragment() {
	float edge_px = min(
		min(UV.x * rect_size.x, UV.y * rect_size.y),
		min((1.0 - UV.x) * rect_size.x, (1.0 - UV.y) * rect_size.y)
	);
	float min_dimension = max(min(rect_size.x, rect_size.y), 1.0);
	float outline_width_px = clamp(min_dimension * 0.026, 4.0, 10.0);
	float outline_softness_px = clamp(min_dimension * 0.008, 1.5, 2.5);
	float halo_width_px = clamp(min_dimension * 0.015, 2.0, 5.0);
	float outline = 1.0 - smoothstep(
		outline_width_px - outline_softness_px,
		outline_width_px + outline_softness_px,
		edge_px
	);
	float halo = 1.0 - smoothstep(
		outline_width_px + outline_softness_px,
		outline_width_px + halo_width_px,
		edge_px
	);
	float shimmer = 0.5 + 0.5 * sin(TIME * (3.2 + (charge * 3.6)) + (UV.x * 8.0) + (UV.y * 5.0));
	vec3 gradient = mix(color_a.rgb, color_b.rgb, shimmer);
	float alpha = (outline * (0.28 + (charge * 0.34))) + (halo * 0.08 * charge);
	COLOR = vec4(gradient, clamp(alpha * charge, 0.0, 0.82));
}
"""

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
	SUCCESS = palette.success
	HIGHLIGHT_GOLD = palette.highlight_gold
	SOFT_WHITE = palette.soft_white
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

static func answer_panel(fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14, border_width: int = 1) -> StyleBoxFlat:
	var style := panel(fill, border, radius, border_width)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func apply_answer_panel(panel_node: PanelContainer, fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14, border_width: int = 1) -> void:
	panel_node.add_theme_stylebox_override("panel", answer_panel(fill, border, radius, border_width))

static func apply_answer_button(button: Button, is_selected: bool) -> void:
	if is_selected:
		button.add_theme_stylebox_override("normal", answer_panel(SURFACE_MUTED, HIGHLIGHT_GOLD, 14, 2))
		button.add_theme_stylebox_override("focus", answer_panel(SURFACE_MUTED, HIGHLIGHT_GOLD.lightened(0.06), 14, 2))
		button.add_theme_stylebox_override("hover", answer_panel(SURFACE_MUTED.lightened(0.03), HIGHLIGHT_GOLD.lightened(0.08), 14, 2))
		button.add_theme_stylebox_override("pressed", answer_panel(SURFACE, HIGHLIGHT_GOLD, 14, 2))
		button.add_theme_color_override("font_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
		button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
		apply_text_outline(button, 2)
		_ensure_control_minimum_height(button)
		return
	button.add_theme_stylebox_override("normal", answer_panel(SURFACE_ALT, BORDER, 14, 2))
	button.add_theme_stylebox_override("focus", answer_panel(SURFACE_MUTED, ACCENT_ALT, 14, 2))
	button.add_theme_stylebox_override("hover", answer_panel(SURFACE_MUTED, BORDER.lightened(0.08), 14, 2))
	button.add_theme_stylebox_override("pressed", answer_panel(SURFACE, ACCENT_ALT, 14, 2))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	apply_text_outline(button, 2)
	_ensure_control_minimum_height(button)

static func ensure_charge_glow(control: Control) -> ColorRect:
	if control == null:
		return null
	var glow := control.get_node_or_null("ChargeGlowOverlay") as ColorRect
	if glow != null:
		return glow
	glow = ColorRect.new()
	glow.name = "ChargeGlowOverlay"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	glow.grow_horizontal = Control.GROW_DIRECTION_BOTH
	glow.grow_vertical = Control.GROW_DIRECTION_BOTH
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color.WHITE
	glow.material = _create_charge_glow_material()
	control.add_child(glow)
	control.move_child(glow, control.get_child_count() - 1)
	return glow

static func set_charge_glow(control: Control, charge_ratio: float, accent: Color = Color(0, 0, 0, 0), secondary: Color = Color(0, 0, 0, 0)) -> void:
	var glow := ensure_charge_glow(control)
	if glow == null:
		return
	var resolved_ratio := clampf(charge_ratio, 0.0, 1.0)
	var control_size := _resolved_control_draw_size(control)
	glow.visible = resolved_ratio > 0.01
	if glow.material is ShaderMaterial:
		var glow_material := glow.material as ShaderMaterial
		var primary_color := accent if accent != Color(0, 0, 0, 0) else HIGHLIGHT_GOLD
		var secondary_color := secondary if secondary != Color(0, 0, 0, 0) else ACCENT_ALT
		glow_material.set_shader_parameter("charge", resolved_ratio)
		glow_material.set_shader_parameter("color_a", primary_color)
		glow_material.set_shader_parameter("color_b", secondary_color)
		glow_material.set_shader_parameter("rect_size", control_size)

static func clear_charge_glow(control: Control) -> void:
	if control == null:
		return
	var glow := control.get_node_or_null("ChargeGlowOverlay") as ColorRect
	if glow != null:
		glow.visible = false

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

static func separator_gradient_style(colors: PackedColorArray, offsets: PackedFloat32Array, horizontal: bool = true) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.gradient = gradient
	texture.width = 256 if horizontal else 12
	texture.height = 12 if horizontal else 256
	texture.fill_from = Vector2(0.0, 0.5) if horizontal else Vector2(0.5, 0.0)
	texture.fill_to = Vector2(1.0, 0.5) if horizontal else Vector2(0.5, 1.0)
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style

static func question_type_color(kind: StringName) -> Color:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return Color("4ec9b0")
		SurveyQuestion.TYPE_LONG_TEXT:
			return Color("3fb68f")
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return Color("3794ff")
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return Color("46b6d9")
		SurveyQuestion.TYPE_BOOLEAN:
			return Color("d7b154")
		SurveyQuestion.TYPE_SCALE:
			return Color("c586c0")
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return Color("e06c75")
		SurveyQuestion.TYPE_DROPDOWN:
			return Color("ce9178")
		SurveyQuestion.TYPE_EMAIL:
			return Color("d16d9e")
		SurveyQuestion.TYPE_NUMBER:
			return Color("9cdc78")
		SurveyQuestion.TYPE_DATE:
			return Color("dcdcaa")
		SurveyQuestion.TYPE_NPS:
			return Color("7aa2f7")
		SurveyQuestion.TYPE_MATRIX:
			return Color("f29e74")
	return ACCENT_ALT

static func journey_mobile_scale(viewport_size: Vector2) -> float:
	if viewport_size == Vector2.ZERO:
		return 1.0
	var width_scale: float = viewport_size.x / 320.0
	var height_scale: float = viewport_size.y / 700.0
	return clampf(minf(width_scale, height_scale), 1.0, 1.28)

static func _create_charge_glow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CHARGE_GLOW_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("charge", 0.0)
	material.set_shader_parameter("color_a", HIGHLIGHT_GOLD)
	material.set_shader_parameter("color_b", ACCENT_ALT)
	material.set_shader_parameter("rect_size", Vector2.ONE)
	return material

static func _resolved_control_draw_size(control: Control) -> Vector2:
	if control == null:
		return Vector2.ONE
	var resolved_size := control.size
	if resolved_size.x <= 0.0 or resolved_size.y <= 0.0:
		resolved_size = resolved_size.max(control.custom_minimum_size)
	if resolved_size.x <= 0.0 or resolved_size.y <= 0.0:
		resolved_size = resolved_size.max(control.get_combined_minimum_size())
	resolved_size.x = maxf(resolved_size.x, 1.0)
	resolved_size.y = maxf(resolved_size.y, 1.0)
	return resolved_size
