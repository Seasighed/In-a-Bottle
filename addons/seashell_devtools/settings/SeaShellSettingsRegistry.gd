@tool
extends Resource
class_name SeaShellSettingsRegistry

@export var RegistryId := "SeaShell.DefaultSettingsRegistry"
@export var ControlScenes: Dictionary = {}
@export var ValueTypeColors: Dictionary = {}
@export var TagColors: Dictionary = {}
@export var KindColors: Dictionary = {
	"Setting": Color(0.28, 0.62, 1.0, 1.0),
	"Info": Color(0.38, 0.78, 0.56, 1.0),
	"Poll": Color(0.88, 0.62, 0.25, 1.0),
}
@export var Icons: Dictionary = {}
@export var Hints: Dictionary = {}

func get_control_scene(value_type: String) -> PackedScene:
	var scene: Variant = ControlScenes.get(value_type)
	return scene if scene is PackedScene else null

func get_value_type_color(value_type: String) -> Color:
	var color: Variant = ValueTypeColors.get(value_type)
	return color if typeof(color) == TYPE_COLOR else Color(0.45, 0.58, 0.76, 1.0)

func get_kind_color(kind: String) -> Color:
	var color: Variant = KindColors.get(kind)
	return color if typeof(color) == TYPE_COLOR else Color(0.55, 0.55, 0.55, 1.0)

func get_tag_color(tag: String) -> Color:
	var color: Variant = TagColors.get(tag)
	if typeof(color) == TYPE_COLOR:
		return color
	var hue := float(abs(tag.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.45, 0.85, 1.0)

func get_color(bucket: String, key: String) -> Color:
	match bucket:
		"item_kind", "kind":
			return get_kind_color(key)
		"value_type", "type":
			return get_value_type_color(key)
		"tag", "tags":
			return get_tag_color(key)
		_:
			return Color(0.32, 0.36, 0.42, 1.0)

func get_icon(key: String) -> String:
	return String(Icons.get(key, ""))

func get_hint(key: String) -> String:
	return String(Hints.get(key, ""))