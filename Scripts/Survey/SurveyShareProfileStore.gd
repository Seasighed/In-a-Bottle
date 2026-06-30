class_name SurveyShareProfileStore
extends RefCounted

const STORE_PATH := "user://survey_share_profile.json"
const DEFAULT_PROFILE_NAME := "Mushroom"
const MAX_PROFILE_NAME_LENGTH := 48
const MAX_FIELD_LABEL_LENGTH := 48
const MAX_FIELD_VALUE_LENGTH := 96
const MAX_PROFILE_FIELDS := 12

static func default_profile() -> Dictionary:
	return {
		"profile_name": DEFAULT_PROFILE_NAME,
		"fields": _default_fields(),
		"show_on_wrap": false,
		"include_in_upload": false,
		"updated_at": ""
	}

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return default_profile()
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return default_profile()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return default_profile()
	return normalize_profile(parsed as Dictionary, false)

static func save_profile(profile: Dictionary) -> bool:
	var normalized := normalize_profile(profile, true)
	var absolute_path := ProjectSettings.globalize_path(STORE_PATH)
	var ensure_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if ensure_error != OK and not DirAccess.dir_exists_absolute(absolute_path.get_base_dir()):
		return false
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true

static func purge_profile() -> bool:
	var absolute_path := ProjectSettings.globalize_path(STORE_PATH)
	if not FileAccess.file_exists(absolute_path):
		return true
	var directory := DirAccess.open(absolute_path.get_base_dir())
	if directory == null:
		return false
	return directory.remove(absolute_path.get_file()) == OK

static func normalize_profile(profile: Dictionary, stamp_update: bool = false) -> Dictionary:
	var normalized := default_profile()
	normalized["profile_name"] = _limited_text(profile.get("profile_name", DEFAULT_PROFILE_NAME), MAX_PROFILE_NAME_LENGTH)
	if str(normalized.get("profile_name", "")).strip_edges().is_empty():
		normalized["profile_name"] = DEFAULT_PROFILE_NAME
	normalized["fields"] = _normalized_fields(profile)
	normalized["show_on_wrap"] = bool(profile.get("show_on_wrap", false))
	normalized["include_in_upload"] = bool(profile.get("include_in_upload", false))
	var updated_at := str(profile.get("updated_at", "")).strip_edges()
	normalized["updated_at"] = Time.get_datetime_string_from_system(true) if stamp_update else updated_at
	return normalized

static func wrap_payload(profile: Dictionary) -> Dictionary:
	var normalized := normalize_profile(profile, false)
	if not bool(normalized.get("show_on_wrap", false)):
		return {}
	return _public_fields(normalized)

static func upload_payload(profile: Dictionary) -> Dictionary:
	var normalized := normalize_profile(profile, false)
	if not bool(normalized.get("include_in_upload", false)):
		return {}
	var payload := _public_fields(normalized)
	if payload.is_empty():
		return {}
	payload["volunteered_at"] = Time.get_datetime_string_from_system(true)
	return payload

static func has_public_fields(profile: Dictionary) -> bool:
	return not _public_fields(normalize_profile(profile, false)).is_empty()

static func _public_fields(profile: Dictionary) -> Dictionary:
	var fields: Array[Dictionary] = []
	for field_value in profile.get("fields", []) as Array:
		if not (field_value is Dictionary):
			continue
		var field: Dictionary = field_value as Dictionary
		var label := _limited_text(field.get("label", ""), MAX_FIELD_LABEL_LENGTH)
		var value := _limited_text(field.get("value", ""), MAX_FIELD_VALUE_LENGTH)
		if label.is_empty() or value.is_empty():
			continue
		fields.append({
			"label": label,
			"value": value
		})
	if fields.is_empty():
		return {}
	var payload := {
		"profile_name": _limited_text(profile.get("profile_name", DEFAULT_PROFILE_NAME), MAX_PROFILE_NAME_LENGTH),
		"fields": fields
	}
	if str(payload.get("profile_name", "")).strip_edges().is_empty():
		payload["profile_name"] = DEFAULT_PROFILE_NAME
	return payload

static func _normalized_fields(profile: Dictionary) -> Array[Dictionary]:
	if profile.has("fields") and profile.get("fields") is Array:
		return _normalized_field_array(profile.get("fields", []) as Array)
	var legacy_fields: Array[Dictionary] = []
	var display_name := _limited_text(profile.get("display_name", ""), MAX_FIELD_VALUE_LENGTH)
	var world_name := _limited_text(profile.get("world_name", ""), MAX_FIELD_VALUE_LENGTH)
	var game_region := _limited_text(profile.get("game_region", ""), MAX_FIELD_VALUE_LENGTH)
	if not display_name.is_empty() or not world_name.is_empty() or not game_region.is_empty():
		legacy_fields.append({"label": "Username", "value": display_name})
		legacy_fields.append({"label": "World", "value": world_name})
		legacy_fields.append({"label": "Region", "value": game_region})
		return _normalized_field_array(legacy_fields)
	return _default_fields()

static func _normalized_field_array(source: Array) -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	for item in source:
		if not (item is Dictionary):
			continue
		var field: Dictionary = item as Dictionary
		var label := _limited_text(field.get("label", ""), MAX_FIELD_LABEL_LENGTH)
		var value := _limited_text(field.get("value", ""), MAX_FIELD_VALUE_LENGTH)
		if label.is_empty() and value.is_empty():
			continue
		fields.append({
			"label": label,
			"value": value
		})
		if fields.size() >= MAX_PROFILE_FIELDS:
			break
	if fields.is_empty():
		return _default_fields()
	return fields

static func _default_fields() -> Array[Dictionary]:
	return [
		{"label": "Username", "value": ""},
		{"label": "World", "value": ""},
		{"label": "Region", "value": ""}
	]

static func _limited_text(value: Variant, limit: int) -> String:
	var text := str(value).strip_edges().replace("\t", " ")
	text = " ".join(text.split("\n", false))
	while text.contains("  "):
		text = text.replace("  ", " ")
	return text.substr(0, mini(text.length(), limit))
