class_name SurveyPreviewConfig
extends RefCounted

const MODE_AUTO := "auto"
const MODE_DESKTOP := "desktop"
const MODE_MOBILE := "mobile"

const RESOLUTION_PRESETS: Array[Dictionary] = [
	{
		"id": "phone_390x844",
		"label": "Phone 390x844",
		"size": Vector2i(390, 844),
		"mode": MODE_MOBILE
	},
	{
		"id": "phone_430x932",
		"label": "Phone 430x932",
		"size": Vector2i(430, 932),
		"mode": MODE_MOBILE
	},
	{
		"id": "phone_landscape_844x390",
		"label": "Phone Landscape 844x390",
		"size": Vector2i(844, 390),
		"mode": MODE_MOBILE
	},
	{
		"id": "tablet_768x1024",
		"label": "Tablet 768x1024",
		"size": Vector2i(768, 1024),
		"mode": MODE_MOBILE
	},
	{
		"id": "tablet_landscape_1024x768",
		"label": "Tablet Landscape 1024x768",
		"size": Vector2i(1024, 768),
		"mode": MODE_DESKTOP
	},
	{
		"id": "laptop_1280x720",
		"label": "Laptop 1280x720",
		"size": Vector2i(1280, 720),
		"mode": MODE_DESKTOP
	},
	{
		"id": "desktop_1600x900",
		"label": "Desktop 1600x900",
		"size": Vector2i(1600, 900),
		"mode": MODE_DESKTOP
	},
	{
		"id": "desktop_1920x1080",
		"label": "Desktop 1920x1080",
		"size": Vector2i(1920, 1080),
		"mode": MODE_DESKTOP
	}
]

static func preview_mode_options() -> Array[Dictionary]:
	return [
		{"id": MODE_AUTO, "label": "Auto"},
		{"id": MODE_DESKTOP, "label": "Desktop"},
		{"id": MODE_MOBILE, "label": "Mobile"}
	]

static func normalized_mode(raw_mode: String) -> String:
	var normalized := raw_mode.to_lower().strip_edges()
	match normalized:
		MODE_DESKTOP:
			return MODE_DESKTOP
		MODE_MOBILE:
			return MODE_MOBILE
	return MODE_AUTO

static func normalized_resolution_id(raw_id: String) -> String:
	var candidate := raw_id.strip_edges()
	if candidate.is_empty():
		return ""
	for preset in RESOLUTION_PRESETS:
		if str(preset.get("id", "")) == candidate:
			return candidate
	return ""

static func resolution_presets() -> Array[Dictionary]:
	return RESOLUTION_PRESETS.duplicate(true)

static func resolution_size(resolution_id: String) -> Vector2i:
	var normalized_id := normalized_resolution_id(resolution_id)
	if normalized_id.is_empty():
		return Vector2i.ZERO
	for preset in RESOLUTION_PRESETS:
		if str(preset.get("id", "")) != normalized_id:
			continue
		var preset_size: Variant = preset.get("size", Vector2i.ZERO)
		if preset_size is Vector2i:
			return preset_size
	return Vector2i.ZERO

static func resolution_label(resolution_id: String) -> String:
	var normalized_id := normalized_resolution_id(resolution_id)
	if normalized_id.is_empty():
		return "Current Window"
	for preset in RESOLUTION_PRESETS:
		if str(preset.get("id", "")) == normalized_id:
			return str(preset.get("label", normalized_id))
	return "Current Window"
