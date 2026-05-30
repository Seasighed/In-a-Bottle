@tool
extends RefCounted

const PROJECT_NAME_SETTING_KEY := "application/config/name"
const PROJECT_VERSION_SETTING_KEY := "application/config/version"

static func resolve_next_build_directory(project_info: Dictionary, collection_root_absolute: String, build_mode: int) -> Dictionary:
	var normalized_collection_root := collection_root_absolute.simplify_path()
	var project_name := _resolve_project_name(project_info)
	var sanitized_project_name := sanitize_folder_segment(project_name, "BuildOutput")
	var history: Dictionary = scan_build_history(project_info, normalized_collection_root)
	var project_version: Dictionary = parse_semver(String(project_info.get("ProjectVersion", "")))
	var highest_known_version: Dictionary = {}

	if project_version.get("ok", false):
		highest_known_version = project_version
	if history.get("LatestVersion", {}).get("ok", false):
		if highest_known_version.is_empty() or compare_semver(history.get("LatestVersion", {}), highest_known_version) > 0:
			highest_known_version = history.get("LatestVersion", {})

	var next_version: Dictionary = bump_patch(highest_known_version) if not highest_known_version.is_empty() else parse_semver("0.0.1")
	if not next_version.get("ok", false):
		return {
			"ok": false,
			"error": "Sea Shell DevTools could not determine the next semantic version for this build.",
		}

	var build_mode_label := get_build_mode_label(build_mode)
	var version_string := format_semver(next_version)
	var folder_name := "%s_v%s-%s" % [sanitized_project_name, version_string, build_mode_label]
	return {
		"ok": true,
		"ProjectName": project_name,
		"SanitizedProjectName": sanitized_project_name,
		"CollectionRootAbsolute": normalized_collection_root,
		"CurrentProjectVersion": project_version,
		"LatestHistoryRecord": history.get("LatestRecord", {}),
		"LatestHistoryVersion": history.get("LatestVersion", {}),
		"ResolvedVersion": next_version,
		"ResolvedVersionString": version_string,
		"BuildModeLabel": build_mode_label,
		"FolderName": folder_name,
		"FolderAbsolute": normalized_collection_root.path_join(folder_name),
	}

static func find_latest_build_directory(project_info: Dictionary, collection_root_absolute: String) -> Dictionary:
	var history: Dictionary = scan_build_history(project_info, collection_root_absolute)
	var latest_record: Dictionary = history.get("LatestRecord", {})
	if latest_record.is_empty():
		return {
			"ok": false,
			"error": "No previous Sea Shell build folders were found in '%s'." % collection_root_absolute,
		}

	return {
		"ok": true,
		"record": latest_record,
		"directory_absolute": String(latest_record.get("DirectoryAbsolute", "")),
		"version_string": String(latest_record.get("VersionString", "")),
		"build_mode_label": String(latest_record.get("BuildModeLabel", "")),
	}

static func scan_build_history(project_info: Dictionary, collection_root_absolute: String) -> Dictionary:
	var normalized_collection_root := collection_root_absolute.simplify_path()
	var project_name := _resolve_project_name(project_info)
	var sanitized_project_name := sanitize_folder_segment(project_name, "BuildOutput")
	var records: Array = []

	if DirAccess.dir_exists_absolute(normalized_collection_root):
		for directory_name in DirAccess.get_directories_at(normalized_collection_root):
			var parsed_record: Dictionary = _parse_build_directory_name(String(directory_name), sanitized_project_name)
			if not parsed_record.get("ok", false):
				continue
			parsed_record["DirectoryName"] = String(directory_name)
			parsed_record["DirectoryAbsolute"] = normalized_collection_root.path_join(String(directory_name))
			records.append(parsed_record)

	var latest_record: Dictionary = {}
	var latest_version: Dictionary = {}
	for record in records:
		var typed_record: Dictionary = record
		var version_info: Dictionary = typed_record.get("Version", {})
		if latest_record.is_empty():
			latest_record = typed_record
			latest_version = version_info
			continue
		var comparison := compare_semver(version_info, latest_version)
		if comparison > 0:
			latest_record = typed_record
			latest_version = version_info
			continue
		if comparison == 0 and String(typed_record.get("DirectoryName", "")) > String(latest_record.get("DirectoryName", "")):
			latest_record = typed_record
			latest_version = version_info

	return {
		"ProjectName": project_name,
		"SanitizedProjectName": sanitized_project_name,
		"Records": records,
		"LatestRecord": latest_record,
		"LatestVersion": latest_version,
	}

static func parse_semver(raw_value: String) -> Dictionary:
	var trimmed := raw_value.strip_edges()
	if trimmed.is_empty():
		return {}

	var regex := RegEx.new()
	regex.compile("^v?(\\d+)\\.(\\d+)\\.(\\d+)$")
	var version_match := regex.search(trimmed)
	if version_match == null:
		return {}

	var major := int(version_match.get_string(1))
	var minor := int(version_match.get_string(2))
	var patch := int(version_match.get_string(3))
	return {
		"ok": true,
		"major": major,
		"minor": minor,
		"patch": patch,
	}

static func bump_patch(version_info: Dictionary) -> Dictionary:
	if version_info.is_empty():
		return parse_semver("0.0.1")

	if not version_info.get("ok", false):
		return {}

	return {
		"ok": true,
		"major": int(version_info.get("major", 0)),
		"minor": int(version_info.get("minor", 0)),
		"patch": int(version_info.get("patch", 0)) + 1,
	}

static func compare_semver(left: Dictionary, right: Dictionary) -> int:
	if left.is_empty() and right.is_empty():
		return 0
	if left.is_empty():
		return -1
	if right.is_empty():
		return 1

	for key in ["major", "minor", "patch"]:
		var left_value := int(left.get(String(key), 0))
		var right_value := int(right.get(String(key), 0))
		if left_value == right_value:
			continue
		return 1 if left_value > right_value else -1
	return 0

static func format_semver(version_info: Dictionary) -> String:
	if version_info.is_empty():
		return ""
	return "%d.%d.%d" % [
		int(version_info.get("major", 0)),
		int(version_info.get("minor", 0)),
		int(version_info.get("patch", 0)),
	]

static func get_build_mode_label(build_mode: int) -> String:
	return "debug" if int(build_mode) == 1 else "release"

static func sanitize_folder_segment(raw_value: String, fallback: String) -> String:
	var value := raw_value.strip_edges()
	if value.is_empty():
		value = fallback

	var builder := ""
	var invalid_characters := "<>:\"/\\|?*"
	for character in value:
		if invalid_characters.contains(character):
			continue
		if character.unicode_at(0) < 32:
			continue
		builder += character

	builder = builder.strip_edges().trim_suffix(".")
	while builder.ends_with("."):
		builder = builder.substr(0, builder.length() - 1)
	return fallback if builder.is_empty() else builder

static func _resolve_project_name(project_info: Dictionary) -> String:
	var project_name := String(project_info.get("ProjectName", "")).strip_edges()
	if not project_name.is_empty():
		return project_name

	var project_root := String(project_info.get("ProjectRootAbsolute", "")).simplify_path()
	var folder_name := project_root.get_file().strip_edges()
	return folder_name if not folder_name.is_empty() else "BuildOutput"

static func _parse_build_directory_name(directory_name: String, sanitized_project_name: String) -> Dictionary:
	var escaped_project_name := _escape_regex(sanitized_project_name)
	var regex := RegEx.new()
	regex.compile("^%s_v(\\d+)\\.(\\d+)\\.(\\d+)-(debug|release)$" % escaped_project_name)
	var directory_match := regex.search(directory_name)
	if directory_match == null:
		return {}

	var version_info := {
		"ok": true,
		"major": int(directory_match.get_string(1)),
		"minor": int(directory_match.get_string(2)),
		"patch": int(directory_match.get_string(3)),
	}
	return {
		"ok": true,
		"Version": version_info,
		"VersionString": format_semver(version_info),
		"BuildModeLabel": directory_match.get_string(4),
	}

static func _escape_regex(value: String) -> String:
	var builder := ""
	var special_characters := ".^$*+?()[]{}|\\"
	for character in value:
		builder += "\\%s" % character if special_characters.contains(character) else character
	return builder
