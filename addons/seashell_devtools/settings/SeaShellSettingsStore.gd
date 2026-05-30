@tool
extends RefCounted
class_name SeaShellSettingsStore

const RECENT_VALUE_LIMIT := 5

var store_path := "user://sea_shell_settings_values.json"
var _state := {"values": {}}

func configure(path: String) -> void:
	if not path.strip_edges().is_empty():
		store_path = path
	load_store()

func load_store() -> void:
	if not FileAccess.file_exists(store_path):
		_state = {"values": {}}
		return
	var raw := FileAccess.get_file_as_string(store_path)
	var parsed: Variant = JSON.parse_string(raw)
	_state = parsed if typeof(parsed) == TYPE_DICTIONARY else {"values": {}}
	if not _state.has("values") or typeof(_state.get("values")) != TYPE_DICTIONARY:
		_state["values"] = {}

func save_store() -> Error:
	var absolute_path := ProjectSettings.globalize_path(store_path)
	var directory := absolute_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(store_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_state, "\t"))
	return OK

func get_value(item: Resource) -> Variant:
	var record: Dictionary = _get_record(str(item.get("ItemId")))
	if record.has("value"):
		return _decode_value(record.get("value"), str(item.get("ValueType")))
	return item.get_default_value()

func set_value(item: Resource, value: Variant, source := "runtime") -> void:
	var item_id := str(item.get("ItemId"))
	var record: Dictionary = _get_record(item_id)
	var previous_value: Variant = record.get("value", null)
	if record.has("value"):
		_push_recent_value(record, previous_value)
	record["value"] = _encode_value(value)
	record["modified_unix"] = Time.get_unix_time_from_system()
	record["source"] = source
	_state["values"][item_id] = record
	save_store()

func reset_value(item: Resource) -> void:
	set_value(item, item.get_default_value(), "reset")

func get_value_modified_unix(item_id: String) -> int:
	var record: Dictionary = _get_record(item_id)
	return int(record.get("modified_unix", 0))

func get_recent_values(item: Resource) -> Array:
	var record: Dictionary = _get_record(str(item.get("ItemId")))
	var recent: Array = record.get("recent", [])
	var result: Array = []
	for entry in recent:
		result.append(_decode_value(entry, str(item.get("ValueType"))))
	return result

func build_profile(
	items: Array,
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	value_overrides: Dictionary = {},
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var values := {}
	for item in items:
		if not (item is Resource) or not item.has_method("get_default_value"):
			continue
		if str(item.get("Kind")) != "Setting":
			continue
		var item_id := str(item.get("ItemId"))
		if not full_snapshot and not _profile_filter_allows(item, selected_ids, selected_groups, selected_tags):
			continue
		var value: Variant = value_overrides[item_id] if value_overrides.has(item_id) else get_value(item)
		values[item_id] = {
			"value": _encode_value(value),
			"value_type": str(item.get("ValueType")),
			"display_name": item.display_name(),
			"group_path": str(item.get("GroupPath")),
			"tags": Array(item.get("Tags")),
		}
	return {
		"format": "SeaShellSettingsProfile",
		"version": 1,
		"exported_unix": Time.get_unix_time_from_system(),
		"mode": "full" if full_snapshot else "partial",
		"values": values,
	}

func apply_profile(profile: Dictionary, items_by_id: Dictionary, include_ids: PackedStringArray = PackedStringArray(), include_groups: PackedStringArray = PackedStringArray(), include_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var changed := PackedStringArray()
	var skipped := PackedStringArray()
	var values: Dictionary = profile.get("values", {})
	for item_id in values.keys():
		var typed_id := String(item_id)
		if not items_by_id.has(typed_id):
			skipped.append(typed_id)
			continue
		var item: Resource = items_by_id[typed_id]
		if not _profile_filter_allows(item, include_ids, include_groups, include_tags):
			skipped.append(typed_id)
			continue
		var record: Dictionary = values[item_id]
		set_value(item, _decode_value(record.get("value"), str(item.get("ValueType"))), "profile_import")
		changed.append(typed_id)
	return {"changed": Array(changed), "skipped": Array(skipped)}

func encode_value(value: Variant) -> Variant:
	return _encode_value(value)

func decode_value(value: Variant, value_type := "") -> Variant:
	return _decode_value(value, value_type)

func _profile_filter_allows(item: Resource, include_ids: PackedStringArray, include_groups: PackedStringArray, include_tags: PackedStringArray) -> bool:
	if include_ids.is_empty() and include_groups.is_empty() and include_tags.is_empty():
		return true
	if include_ids.has(str(item.get("ItemId"))):
		return true
	var item_group := str(item.get("GroupPath"))
	for group in include_groups:
		var typed_group := String(group)
		if item_group == typed_group or item_group.begins_with(typed_group + "/"):
			return true
	for tag in item.get("Tags"):
		if include_tags.has(String(tag)):
			return true
	return false

func _get_record(item_id: String) -> Dictionary:
	var values: Dictionary = _state.get("values", {})
	return values.get(item_id, {}).duplicate(true)

func _push_recent_value(record: Dictionary, encoded_value: Variant) -> void:
	var recent: Array = record.get("recent", [])
	var serialized := JSON.stringify(encoded_value)
	var filtered: Array = []
	for entry in recent:
		if JSON.stringify(entry) != serialized:
			filtered.append(entry)
	filtered.push_front(encoded_value)
	while filtered.size() > RECENT_VALUE_LIMIT:
		filtered.pop_back()
	record["recent"] = filtered

func _encode_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_COLOR:
		return {"__type": "Color", "value": (value as Color).to_html(true)}
	return value

func _decode_value(value: Variant, value_type := "") -> Variant:
	if typeof(value) == TYPE_DICTIONARY and String(value.get("__type", "")) == "Color":
		return Color.html(String(value.get("value", "ffffffff")))
	if value_type == "Color" and typeof(value) == TYPE_STRING:
		return Color.html(String(value))
	return value
