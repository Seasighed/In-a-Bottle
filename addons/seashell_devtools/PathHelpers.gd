@tool
extends RefCounted

static func resolve_directory(raw_path: String, project_root_absolute: String) -> String:
	var trimmed := raw_path.strip_edges()
	if trimmed.is_empty():
		push_error("Output directory cannot be blank.")
		return ""

	if trimmed.begins_with("user://"):
		push_error("The v1 build tool supports relative paths, absolute paths, or res:// paths, but not user:// paths.")
		return ""

	if trimmed.begins_with("res://"):
		var relative := trimmed.trim_prefix("res://")
		return project_root_absolute.path_join(relative).simplify_path()

	if trimmed.is_absolute_path():
		return trimmed.simplify_path()

	return project_root_absolute.path_join(trimmed).simplify_path()

static func to_res_path(absolute_path: String, project_root_absolute: String) -> String:
	var full_path := absolute_path.simplify_path().replace("\\", "/")
	var full_root := project_root_absolute.simplify_path().replace("\\", "/").trim_suffix("/")
	if not full_path.to_lower().begins_with(full_root.to_lower()):
		push_error("Path '%s' is outside this Godot project." % full_path)
		return ""

	var relative := full_path.substr(full_root.length())
	relative = relative.trim_prefix("/")
	return "res://%s" % relative

static func slugify(value: String, fallback := "build-profile") -> String:
	if value.strip_edges().is_empty():
		return fallback

	var lowered := value.strip_edges().to_lower()
	var builder := ""
	for character in lowered:
		var codepoint := character.unicode_at(0)
		var is_letter := codepoint >= 97 and codepoint <= 122
		var is_digit := codepoint >= 48 and codepoint <= 57
		builder += character if is_letter or is_digit else "-"

	var regex := RegEx.new()
	regex.compile("-{2,}")
	var collapsed := regex.sub(builder, "-", true).strip_edges()
	collapsed = collapsed.trim_prefix("-").trim_suffix("-")
	return fallback if collapsed.is_empty() else collapsed

static func ensure_output_file_name(raw_name: String, required_extension: String, artifact_label: String) -> Dictionary:
	var file_name := raw_name.strip_edges()
	if file_name.is_empty():
		return {
			"ok": false,
			"error": "Output file name cannot be blank.",
		}

	var invalid_name := RegEx.new()
	invalid_name.compile("[\\\\/:*?\"<>|]")
	if invalid_name.search(file_name):
		return {
			"ok": false,
			"error": "Output file name '%s' contains an invalid character." % file_name,
		}

	if not file_name.to_lower().ends_with(required_extension.to_lower()):
		return {
			"ok": false,
			"error": "Output file name must end with %s for %s exports." % [required_extension, artifact_label],
		}

	return {
		"ok": true,
		"value": file_name,
	}
