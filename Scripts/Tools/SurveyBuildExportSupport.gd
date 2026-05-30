class_name SurveyBuildExportSupport
extends RefCounted

const SETTINGS_PATH := "user://survey_tool_build_export.cfg"
const DEFAULT_BUILDS_DIRECTORY := "res://Builds"
const PRESETS_PATH := "res://export_presets.cfg"

static func default_builds_directory() -> String:
	return normalize_directory_path(DEFAULT_BUILDS_DIRECTORY)

static func load_builds_directory(fallback_path: String = DEFAULT_BUILDS_DIRECTORY) -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return normalize_directory_path(fallback_path)
	var saved_path := str(config.get_value("builds", "directory", fallback_path)).strip_edges()
	return normalize_directory_path(saved_path, fallback_path)

static func save_builds_directory(path: String, fallback_path: String = DEFAULT_BUILDS_DIRECTORY) -> int:
	var normalized_path := normalize_directory_path(path, fallback_path)
	var config := ConfigFile.new()
	config.set_value("builds", "directory", normalized_path)
	return config.save(SETTINGS_PATH)

static func normalize_directory_path(raw_path: String, fallback_path: String = DEFAULT_BUILDS_DIRECTORY) -> String:
	var requested_path := raw_path.strip_edges().replace("\\", "/")
	var fallback := fallback_path.strip_edges().replace("\\", "/")
	if requested_path.is_empty():
		requested_path = fallback if not fallback.is_empty() else DEFAULT_BUILDS_DIRECTORY
	if requested_path.begins_with("res://") or requested_path.begins_with("user://"):
		return ProjectSettings.globalize_path(requested_path).simplify_path()
	if requested_path.is_absolute_path():
		return requested_path.simplify_path()
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").replace("\\", "/")
	return ("%s/%s" % [project_root, requested_path]).simplify_path()

static func available_presets(config_path: String = PRESETS_PATH) -> Array[Dictionary]:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return []
	var presets: Array[Dictionary] = []
	var index := 0
	while true:
		var section := "preset.%d" % index
		if not config.has_section(section):
			break
		var name := str(config.get_value(section, "name", "Preset %d" % index)).strip_edges()
		var platform := str(config.get_value(section, "platform", "")).strip_edges()
		var export_path := str(config.get_value(section, "export_path", "")).strip_edges()
		presets.append({
			"index": index,
			"section": section,
			"name": name,
			"platform": platform,
			"export_path": export_path,
			"relative_export_path": relative_export_path(export_path, name, platform)
		})
		index += 1
	return presets

static func next_version_info(builds_directory: String) -> Dictionary:
	var normalized_directory := normalize_directory_path(builds_directory)
	var next_number := 1
	if DirAccess.dir_exists_absolute(normalized_directory):
		var directory := DirAccess.open(normalized_directory)
		if directory != null:
			directory.list_dir_begin()
			while true:
				var entry_name := directory.get_next()
				if entry_name.is_empty():
					break
				if not directory.current_is_dir():
					continue
				var parsed_number := parse_version_number(entry_name)
				if parsed_number >= next_number:
					next_number = parsed_number + 1
			directory.list_dir_end()
	var label := version_label(next_number)
	return {
		"number": next_number,
		"label": label,
		"path": ("%s/%s" % [normalized_directory.trim_suffix("/"), label]).simplify_path()
	}

static func version_label(version_number: int) -> String:
	return "v%03d" % maxi(version_number, 1)

static func parse_version_number(label: String) -> int:
	var normalized_label := label.strip_edges()
	if normalized_label.length() < 2 or not normalized_label.begins_with("v"):
		return 0
	var digits := normalized_label.substr(1)
	if not digits.is_valid_int():
		return 0
	return int(digits)

static func build_target_path(builds_directory: String, version_label_text: String, preset: Dictionary) -> String:
	var base_directory := normalize_directory_path(builds_directory)
	var relative_path := relative_export_path(
		str(preset.get("export_path", "")),
		str(preset.get("name", "")),
		str(preset.get("platform", ""))
	)
	return ("%s/%s/%s" % [base_directory.trim_suffix("/"), version_label_text.strip_edges(), relative_path]).simplify_path()

static func build_export_command(preset_name: String, target_path: String, executable_path: String = "") -> Dictionary:
	var resolved_executable := executable_path.strip_edges()
	if resolved_executable.is_empty():
		resolved_executable = OS.get_executable_path().strip_edges()
	return {
		"executable": resolved_executable,
		"arguments": PackedStringArray([
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--export-release",
			preset_name,
			target_path
		])
	}

static func ensure_parent_directory(path: String) -> int:
	var parent_directory := path.get_base_dir().strip_edges()
	if parent_directory.is_empty():
		return ERR_INVALID_PARAMETER
	var ensure_error := DirAccess.make_dir_recursive_absolute(parent_directory)
	if ensure_error == OK or DirAccess.dir_exists_absolute(parent_directory):
		return OK
	return ensure_error

static func relative_export_path(export_path: String, preset_name: String = "", platform: String = "") -> String:
	var normalized_path := export_path.strip_edges().replace("\\", "/")
	if normalized_path.begins_with("res://") or normalized_path.begins_with("user://"):
		normalized_path = ProjectSettings.localize_path(ProjectSettings.globalize_path(normalized_path)).replace("\\", "/")
	elif normalized_path.is_absolute_path():
		normalized_path = normalized_path.get_file()
	normalized_path = normalized_path.trim_prefix("./")
	var lower_path := normalized_path.to_lower()
	if lower_path.begins_with("build/"):
		normalized_path = normalized_path.substr(6)
	elif lower_path.begins_with("builds/"):
		normalized_path = normalized_path.substr(7)
	normalized_path = normalized_path.trim_prefix("/")
	if normalized_path.is_empty():
		var preset_slug := sanitize_path_component(preset_name if not preset_name.is_empty() else platform)
		if preset_slug.is_empty():
			preset_slug = "build"
		if platform.to_lower() == "web":
			normalized_path = "%s/index.html" % preset_slug
		else:
			normalized_path = "%s/%s" % [preset_slug, preset_slug]
	return normalized_path.simplify_path()

static func sanitize_path_component(raw_text: String) -> String:
	var sanitized := ""
	for character in raw_text.strip_edges().to_lower():
		var codepoint := character.unicode_at(0)
		var is_lower_alpha := codepoint >= 97 and codepoint <= 122
		var is_digit := codepoint >= 48 and codepoint <= 57
		if is_lower_alpha or is_digit:
			sanitized += character
		elif sanitized.is_empty() or sanitized.ends_with("_"):
			continue
		else:
			sanitized += "_"
	return sanitized.strip_edges().trim_prefix("_").trim_suffix("_")
