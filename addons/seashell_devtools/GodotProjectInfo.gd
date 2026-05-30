@tool
extends RefCounted

static func load(project_root_absolute: String) -> Dictionary:
	var root := project_root_absolute.simplify_path()
	var project_file_absolute := root.path_join("project.godot")
	var has_top_level_csproj := false
	if DirAccess.dir_exists_absolute(root):
		for file_name in DirAccess.get_files_at(root):
			if String(file_name).to_lower().ends_with(".csproj"):
				has_top_level_csproj = true
				break

	var application_settings := _parse_application_settings(project_file_absolute) if FileAccess.file_exists(project_file_absolute) else {}
	var config_features := application_settings.get("config/features", [])
	var has_csharp_feature := false
	for feature in config_features:
		if String(feature).to_lower() == "c#":
			has_csharp_feature = true
			break

	return {
		"ProjectRootAbsolute": root,
		"ProjectFileAbsolute": project_file_absolute,
		"ProjectName": String(application_settings.get("config/name", "")),
		"ProjectVersion": String(application_settings.get("config/version", "")),
		"HasTopLevelCsproj": has_top_level_csproj,
		"ConfigFeatures": config_features,
		"HasCSharpFeature": has_csharp_feature,
		"LooksLikeCSharpProject": has_top_level_csproj or has_csharp_feature,
	}

static func _parse_application_settings(project_file_absolute: String) -> Dictionary:
	var current_section := ""
	var raw := FileAccess.get_file_as_string(project_file_absolute)
	var values := {
		"config/features": [],
		"config/name": "",
		"config/version": "",
	}
	for raw_line in raw.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue

		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			continue

		if current_section != "application":
			continue

		var separator_index := line.find("=")
		if separator_index <= 0:
			continue

		var key := line.substr(0, separator_index).strip_edges()
		if not values.has(key):
			continue

		var raw_value := line.substr(separator_index + 1).strip_edges()
		if key == "config/features":
			values[key] = _parse_packed_string_array(raw_value)
		else:
			values[key] = _parse_string_literal(raw_value)

	return values

static func _parse_packed_string_array(raw_value: String) -> Array:
	var regex := RegEx.new()
	regex.compile("^PackedStringArray\\((.*)\\)$")
	var array_match := regex.search(raw_value)
	var items := raw_value
	if array_match != null:
		items = array_match.get_string(1)

	var values: Array = []
	var quoted := RegEx.new()
	quoted.compile("\"((?:\\\\.|[^\"])*)\"")
	for match in quoted.search_all(items):
		var value := match.get_string(1)
		values.append(value.replace("\\\"", "\"").replace("\\\\", "\\"))
	return values

static func _parse_string_literal(raw_value: String) -> String:
	var trimmed := raw_value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2).replace("\\\"", "\"").replace("\\\\", "\\")
	return trimmed
