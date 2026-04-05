@tool
class_name SurveyThemeSet
extends Resource

@export var theme_id := "classic"
@export var display_name := "Classic Blue"
@export_multiline var description := ""
@export var dark_palette: SurveyThemePalette
@export var light_palette: SurveyThemePalette
@export_multiline var dark_palette_import_text := "":
	set(value):
		dark_palette_import_text = value
		if Engine.is_editor_hint() and not value.strip_edges().is_empty():
			_ensure_palettes()
			if dark_palette != null:
				dark_palette.palette_import_text = value
				dark_palette.import_from_text(value)
			emit_changed()
@export_multiline var light_palette_import_text := "":
	set(value):
		light_palette_import_text = value
		if Engine.is_editor_hint() and not value.strip_edges().is_empty():
			_ensure_palettes()
			if light_palette != null:
				light_palette.palette_import_text = value
				light_palette.import_from_text(value)
			emit_changed()

func _init() -> void:
	_ensure_palettes()

func normalized_theme_id() -> String:
	return theme_id.strip_edges().to_lower()

func display_title() -> String:
	var trimmed_name := display_name.strip_edges()
	if not trimmed_name.is_empty():
		return trimmed_name
	var trimmed_id := theme_id.strip_edges()
	return trimmed_id.capitalize() if not trimmed_id.is_empty() else "Theme"

func resolved_dark_palette(fallback: SurveyThemePalette = null) -> SurveyThemePalette:
	return dark_palette if dark_palette != null else fallback

func resolved_light_palette(fallback: SurveyThemePalette = null) -> SurveyThemePalette:
	return light_palette if light_palette != null else fallback

func resolved_palette(use_dark_mode: bool, fallback_dark: SurveyThemePalette = null, fallback_light: SurveyThemePalette = null) -> SurveyThemePalette:
	return resolved_dark_palette(fallback_dark) if use_dark_mode else resolved_light_palette(fallback_light)

func preview_gradient_colors(use_dark_mode: bool) -> PackedColorArray:
	var palette := resolved_palette(use_dark_mode, dark_palette, light_palette)
	if palette == null:
		return PackedColorArray([
			Color("6e7681"),
			Color("4b5563"),
			Color("1f2937")
		])
	var preview_shadow: Color = palette.background.lerp(palette.surface, 0.45).darkened(0.08)
	return PackedColorArray([
		palette.accent_alt.lightened(0.16),
		palette.accent,
		preview_shadow
	])

func _ensure_palettes() -> void:
	if dark_palette == null:
		dark_palette = SurveyThemePalette.new()
		dark_palette.mode_name = "Dark"
	if light_palette == null:
		light_palette = SurveyThemePalette.new()
		light_palette.mode_name = "Light"
	if dark_palette.mode_name.strip_edges().is_empty():
		dark_palette.mode_name = "Dark"
	if light_palette.mode_name.strip_edges().is_empty():
		light_palette.mode_name = "Light"
