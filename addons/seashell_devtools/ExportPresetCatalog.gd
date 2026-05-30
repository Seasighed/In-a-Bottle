@tool
extends RefCounted

var SourcePath := ""
var Presets: Array = []

func _init(source_path := "", presets: Array = []) -> void:
	SourcePath = source_path
	Presets = presets

func find_by_name(name: String) -> Dictionary:
	for preset in Presets:
		if String(preset.get("Name", "")) == name:
			return preset
	return {}

static func create_empty(source_path: String) -> RefCounted:
	return preload("res://addons/seashell_devtools/ExportPresetCatalog.gd").new(source_path, [])

static func load(project_root_absolute: String) -> RefCounted:
	var source_path := project_root_absolute.path_join("export_presets.cfg")
	if not FileAccess.file_exists(source_path):
		return create_empty(source_path)

	var sections := {}
	var current_section := ""
	var raw := FileAccess.get_file_as_string(source_path)
	for raw_line in raw.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue

		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			continue

		if current_section.is_empty():
			continue

		var separator_index := line.find("=")
		if separator_index <= 0:
			continue

		var key := line.substr(0, separator_index).strip_edges()
		var value := line.substr(separator_index + 1).strip_edges()
		if not sections.has(current_section):
			sections[current_section] = {}
		sections[current_section][key] = value

	var presets: Array = []
	var preset_sections: Array = sections.keys()
	preset_sections.sort_custom(func(a, b): return _parse_preset_index(a) < _parse_preset_index(b))
	for section_name in preset_sections:
		var index := _parse_preset_index(String(section_name))
		if index < 0:
			continue

		var values: Dictionary = sections.get(section_name, {})
		if not values.has("name") or not values.has("platform"):
			continue

		presets.append({
			"Index": index,
			"SectionName": section_name,
			"Name": _unquote(String(values.get("name", ""))),
			"Platform": _unquote(String(values.get("platform", ""))),
			"ExportPath": _unquote(String(values.get("export_path", "\"\""))),
			"Runnable": _parse_bool(String(values.get("runnable", "false"))),
			"DedicatedServer": _parse_bool(String(values.get("dedicated_server", "false"))),
			"Options": sections.get("%s.options" % section_name, {}),
		})

	return preload("res://addons/seashell_devtools/ExportPresetCatalog.gd").new(source_path, presets)

static func _parse_preset_index(section_name: String) -> int:
	var regex := RegEx.new()
	regex.compile("^preset\\.(\\d+)$")
	var match := regex.search(section_name)
	if match == null:
		return -1
	return int(match.get_string(1))

static func _unquote(raw_value: String) -> String:
	var trimmed := raw_value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed

static func _parse_bool(raw_value: String) -> bool:
	return raw_value.strip_edges().to_lower() in ["true", "1"]
