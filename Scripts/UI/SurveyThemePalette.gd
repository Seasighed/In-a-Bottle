@tool
class_name SurveyThemePalette
extends Resource

const _COLOR_FIELD_NAMES := {
	"background": true,
	"surface": true,
	"surface_alt": true,
	"surface_muted": true,
	"border": true,
	"accent": true,
	"accent_alt": true,
	"text_primary": true,
	"text_muted": true,
	"text_dark": true,
	"text_on_accent": true,
	"text_outline": true,
	"danger": true,
	"success": true,
	"highlight_gold": true,
	"soft_white": true,
	"overlay_dimmer": true
}

const _KEY_ALIASES := {
	"name": "mode_name",
	"label": "mode_name",
	"mode": "mode_name",
	"surfacealt": "surface_alt",
	"surfacemuted": "surface_muted",
	"accentalt": "accent_alt",
	"textprimary": "text_primary",
	"textmuted": "text_muted",
	"textdark": "text_dark",
	"textonaccent": "text_on_accent",
	"textoutline": "text_outline",
	"highlight": "highlight_gold",
	"gold": "highlight_gold",
	"overlay": "overlay_dimmer"
}

@export var mode_name := "Dark"
@export var background := Color("1e1e1e")
@export var surface := Color("252526")
@export var surface_alt := Color("2d2d30")
@export var surface_muted := Color("333337")
@export var border := Color("3e3e42")
@export var accent := Color("0e639c")
@export var accent_alt := Color("3794ff")
@export var text_primary := Color("d4d4d4")
@export var text_muted := Color("a7a7a7")
@export var text_dark := Color("161616")
@export var text_on_accent := Color("ffffff")
@export var text_outline := Color(0, 0, 0, 0.45)
@export var danger := Color("c74e39")
@export var success := Color("3cab68")
@export var highlight_gold := Color("d7b154")
@export var soft_white := Color(1, 1, 1, 0.58)
@export var overlay_dimmer := Color(0, 0, 0, 0.62)
@export_multiline var palette_import_text := "":
	set(value):
		palette_import_text = value
		if Engine.is_editor_hint() and not value.strip_edges().is_empty():
			import_from_text(value)

func import_from_text(raw_text: String) -> bool:
	var parsed_values: Dictionary = _parsed_import_dictionary(raw_text)
	if parsed_values.is_empty():
		return false
	_apply_import_dictionary(parsed_values)
	emit_changed()
	return true

func to_import_text() -> String:
	var lines := PackedStringArray()
	lines.append("mode_name = %s" % mode_name)
	for key in _ordered_export_keys():
		if key == "mode_name":
			continue
		lines.append("%s = #%s" % [key, _color_for_key(key).to_html(true)])
	return "\n".join(lines)

func _ordered_export_keys() -> PackedStringArray:
	return PackedStringArray([
		"mode_name",
		"background",
		"surface",
		"surface_alt",
		"surface_muted",
		"border",
		"accent",
		"accent_alt",
		"text_primary",
		"text_muted",
		"text_dark",
		"text_on_accent",
		"text_outline",
		"danger",
		"success",
		"highlight_gold",
		"soft_white",
		"overlay_dimmer"
	])

func _parsed_import_dictionary(raw_text: String) -> Dictionary:
	var trimmed := raw_text.strip_edges()
	if trimmed.is_empty():
		return {}
	if trimmed.begins_with("{"):
		var parsed_json: Variant = JSON.parse_string(trimmed)
		if parsed_json is Dictionary:
			return _normalized_assignment_dictionary(parsed_json as Dictionary)
	return _normalized_assignment_dictionary(_dictionary_from_lines(trimmed))

func _dictionary_from_lines(raw_text: String) -> Dictionary:
	var assignments := {}
	for raw_line in raw_text.split("\n", false):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("//"):
			continue
		var separator_index := line.find("=")
		var colon_index := line.find(":")
		if separator_index == -1 or (colon_index != -1 and colon_index < separator_index):
			separator_index = colon_index
		if separator_index == -1:
			continue
		var raw_key := line.substr(0, separator_index).strip_edges()
		var raw_value := line.substr(separator_index + 1).strip_edges()
		if raw_key.is_empty() or raw_value.is_empty():
			continue
		assignments[raw_key] = raw_value
	return assignments

func _normalized_assignment_dictionary(source: Dictionary) -> Dictionary:
	var assignments := {}
	for raw_key in source.keys():
		var normalized_key := _normalized_import_key(str(raw_key))
		if normalized_key.is_empty():
			continue
		var raw_value: Variant = source.get(raw_key)
		if normalized_key == "mode_name":
			assignments[normalized_key] = str(raw_value).strip_edges()
			continue
		if not _COLOR_FIELD_NAMES.has(normalized_key):
			continue
		var parsed_color: Variant = _variant_to_color(raw_value)
		if parsed_color == null:
			continue
		assignments[normalized_key] = parsed_color
	return assignments

func _normalized_import_key(raw_key: String) -> String:
	var normalized := raw_key.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	normalized = normalized.replace("-", "_").replace(" ", "_")
	while normalized.contains("__"):
		normalized = normalized.replace("__", "_")
	if _KEY_ALIASES.has(normalized):
		return str(_KEY_ALIASES.get(normalized, ""))
	if normalized.ends_with("_color"):
		normalized = normalized.trim_suffix("_color")
	if _COLOR_FIELD_NAMES.has(normalized) or normalized == "mode_name":
		return normalized
	return ""

func _variant_to_color(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is Array:
		var values: Array = value as Array
		if values.size() == 3 or values.size() == 4:
			var red := float(values[0])
			var green := float(values[1])
			var blue := float(values[2])
			var alpha := float(values[3]) if values.size() == 4 else 1.0
			return Color(red, green, blue, alpha)
	var invalid := Color(-1.0, -1.0, -1.0, -1.0)
	var parsed := Color.from_string(str(value).strip_edges(), invalid)
	if parsed == invalid:
		return null
	return parsed

func _apply_import_dictionary(assignments: Dictionary) -> void:
	for key in assignments.keys():
		var value: Variant = assignments.get(key)
		match String(key):
			"mode_name":
				mode_name = str(value).strip_edges()
			"background":
				background = value
			"surface":
				surface = value
			"surface_alt":
				surface_alt = value
			"surface_muted":
				surface_muted = value
			"border":
				border = value
			"accent":
				accent = value
			"accent_alt":
				accent_alt = value
			"text_primary":
				text_primary = value
			"text_muted":
				text_muted = value
			"text_dark":
				text_dark = value
			"text_on_accent":
				text_on_accent = value
			"text_outline":
				text_outline = value
			"danger":
				danger = value
			"success":
				success = value
			"highlight_gold":
				highlight_gold = value
			"soft_white":
				soft_white = value
			"overlay_dimmer":
				overlay_dimmer = value

func _color_for_key(key: String) -> Color:
	match key:
		"background":
			return background
		"surface":
			return surface
		"surface_alt":
			return surface_alt
		"surface_muted":
			return surface_muted
		"border":
			return border
		"accent":
			return accent
		"accent_alt":
			return accent_alt
		"text_primary":
			return text_primary
		"text_muted":
			return text_muted
		"text_dark":
			return text_dark
		"text_on_accent":
			return text_on_accent
		"text_outline":
			return text_outline
		"danger":
			return danger
		"success":
			return success
		"highlight_gold":
			return highlight_gold
		"soft_white":
			return soft_white
		"overlay_dimmer":
			return overlay_dimmer
	return Color.WHITE
