@tool
extends RefCounted
class_name SeaShellSettingsMarkdown

const SYNC_STATE_PATH := "user://sea_shell_settings_sync_state.json"

var _sync_state := {"items": {}}

func load_state() -> void:
	if not FileAccess.file_exists(SYNC_STATE_PATH):
		_sync_state = {"items": {}}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SYNC_STATE_PATH))
	_sync_state = parsed if typeof(parsed) == TYPE_DICTIONARY else {"items": {}}
	if not _sync_state.has("items") or typeof(_sync_state.get("items")) != TYPE_DICTIONARY:
		_sync_state["items"] = {}

func save_state() -> void:
	var file := FileAccess.open(SYNC_STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_sync_state, "\t"))

func export_item(item: Resource, absolute_path: String) -> Dictionary:
	var directory := absolute_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var content := build_markdown(item)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write markdown file '%s'." % absolute_path}
	file.store_string(content)
	_record_baseline(item, content)
	return {"ok": true, "path": absolute_path}

func import_item(item: Resource, absolute_path: String) -> Dictionary:
	if not FileAccess.file_exists(absolute_path):
		return {"ok": false, "error": "Markdown file '%s' does not exist." % absolute_path}
	var content := FileAccess.get_file_as_string(absolute_path)
	var parsed := parse_markdown(content)
	if not parsed.get("ok", false):
		return parsed
	item.apply_dictionary(parsed.get("frontmatter", {}))
	_record_baseline(item, content)
	return {"ok": true, "path": absolute_path}

func get_sync_status(item: Resource, absolute_path: String) -> Dictionary:
	var resource_hash := _hash_dictionary(item.to_dictionary())
	var markdown_exists := FileAccess.file_exists(absolute_path)
	var markdown_content := FileAccess.get_file_as_string(absolute_path) if markdown_exists else ""
	var markdown_hash := markdown_content.hash()
	var baseline: Dictionary = Dictionary(_sync_state.get("items", {})).get(str(item.get("ItemId")), {})
	if baseline.is_empty():
		return {"status": "untracked" if markdown_exists else "missing_markdown", "resource_changed": false, "markdown_changed": false, "conflict": false}
	var resource_changed := int(baseline.get("resource_hash", 0)) != resource_hash
	var markdown_changed := int(baseline.get("markdown_hash", 0)) != markdown_hash
	var status := "clean"
	if resource_changed and markdown_changed:
		status = "conflict"
	elif resource_changed:
		status = "resource_dirty"
	elif markdown_changed:
		status = "markdown_dirty"
	return {"status": status, "resource_changed": resource_changed, "markdown_changed": markdown_changed, "conflict": status == "conflict"}

func build_markdown(item: Resource) -> String:
	var frontmatter: Dictionary = item.to_dictionary()
	var lines := PackedStringArray()
	lines.append("---")
	for key in frontmatter.keys():
		lines.append("%s: %s" % [key, JSON.stringify(frontmatter[key])])
	lines.append("---")
	lines.append("")
	lines.append("# %s" % item.display_name())
	lines.append("")
	lines.append("## Description")
	lines.append("")
	lines.append(str(item.get("Description")).strip_edges())
	lines.append("")
	lines.append("## Rationale")
	lines.append("")
	lines.append("Explain why this item exists and when someone should change it.")
	lines.append("")
	lines.append("## Examples")
	lines.append("")
	lines.append("- Add examples here.")
	lines.append("")
	lines.append("## Change Log")
	lines.append("")
	lines.append("- %s - Exported from Sea Shell Settings." % Time.get_datetime_string_from_system(false, true))
	lines.append("")
	return "\n".join(lines)

func parse_markdown(content: String) -> Dictionary:
	if not content.begins_with("---"):
		return {"ok": false, "error": "Markdown does not contain frontmatter."}
	var end_index := content.find("\n---", 3)
	if end_index < 0:
		return {"ok": false, "error": "Markdown frontmatter was not closed."}
	var frontmatter_text := content.substr(3, end_index - 3).strip_edges()
	var frontmatter := {}
	for raw_line in frontmatter_text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.is_empty():
			continue
		var separator := line.find(":")
		if separator <= 0:
			continue
		var key := line.substr(0, separator).strip_edges()
		var raw_value := line.substr(separator + 1).strip_edges()
		frontmatter[key] = _parse_frontmatter_value(raw_value)
	return {"ok": true, "frontmatter": frontmatter}

func _record_baseline(item: Resource, markdown_content: String) -> void:
	load_state()
	_sync_state["items"][str(item.get("ItemId"))] = {
		"resource_hash": _hash_dictionary(item.to_dictionary()),
		"markdown_hash": markdown_content.hash(),
		"updated_unix": Time.get_unix_time_from_system(),
	}
	save_state()

func _hash_dictionary(data: Dictionary) -> int:
	return JSON.stringify(data).hash()

func _parse_frontmatter_value(raw_value: String) -> Variant:
	var value := raw_value.strip_edges()
	if value.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(value)
	if parsed != null or value == "null":
		return parsed
	var lowered := value.to_lower()
	if lowered == "true":
		return true
	if lowered == "false":
		return false
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	if (value.begins_with("\"") and value.ends_with("\"")) or (value.begins_with("'") and value.ends_with("'")):
		return value.substr(1, value.length() - 2)
	if value.begins_with("[") and value.ends_with("]"):
		var inner := value.substr(1, value.length() - 2)
		var parts := []
		for part in inner.split(",", false):
			parts.append(_parse_frontmatter_value(part))
		return parts
	return value
