@tool
extends Node

const PackScript = preload("res://addons/seashell_devtools/settings/SeaShellSettingsPack.gd")
const RegistryScript = preload("res://addons/seashell_devtools/settings/SeaShellSettingsRegistry.gd")
const StoreScript = preload("res://addons/seashell_devtools/settings/SeaShellSettingsStore.gd")
const MarkdownScript = preload("res://addons/seashell_devtools/settings/SeaShellSettingsMarkdown.gd")

const DEFAULT_PACK_PATHS := [
	"res://addons/seashell_devtools/settings/packs/SeaShellDevToolsSettings.tres",
	"res://addons/seashell_devtools/settings/packs/SeaShellCommonGameSettings.tres",
]
const DEFAULT_REGISTRY_PATH := "res://addons/seashell_devtools/settings/packs/SeaShellDefaultSettingsRegistry.tres"
const SETTINGS_PACK_PATHS := "seashell_devtools/settings/pack_paths"
const SETTINGS_REGISTRY_PATH := "seashell_devtools/settings/registry_path"
const SETTINGS_STORE_SCRIPT_PATH := "seashell_devtools/settings/store_script_path"
const SETTINGS_VALUE_STORE_PATH := "seashell_devtools/settings/value_store_path"
const DEFAULT_VALUE_STORE_PATH := "user://sea_shell_settings_values.json"
const DEFAULT_PRESET_DIRECTORY := "user://sea_shell_settings_presets"
const PROFILE_FORMAT := "SeaShellSettingsProfile"
const PROFILE_VERSION := 1
const IMPORT_KEEP_MINE := "KeepMine"
const IMPORT_KEEP_INCOMING := "KeepIncoming"

signal settings_changed
signal value_changed(item_id: String, value: Variant)
signal packs_changed

var _packs: Array = []
var _items_by_id: Dictionary = {}
var _pack_source_paths: Dictionary = {}
var _registry: Resource
var _store
var _markdown
var _staged_values: Dictionary = {}
var _restart_pending_items := PackedStringArray()
var _option_providers: Dictionary = {}
var _runtime_apply_handlers: Dictionary = {}
var _runtime_apply_enabled := true
var _is_initializing := false
var _is_initialized := false

func _ready() -> void:
	_initialize()

func refresh() -> void:
	_initialize()
	_rebuild_item_index()
	settings_changed.emit()

func _initialize() -> void:
	if _is_initialized or _is_initializing:
		return
	_is_initializing = true
	_register_builtin_option_providers()
	_register_builtin_runtime_apply_handlers()
	if _store == null:
		_store = _create_store()
		_store.configure(_project_string(SETTINGS_VALUE_STORE_PATH, DEFAULT_VALUE_STORE_PATH))
	if _markdown == null:
		_markdown = MarkdownScript.new()
		_markdown.load_state()
	if _registry == null:
		load_registry(_project_string(SETTINGS_REGISTRY_PATH, DEFAULT_REGISTRY_PATH))
	if _packs.is_empty():
		for pack_path in _project_string_array(SETTINGS_PACK_PATHS, PackedStringArray(DEFAULT_PACK_PATHS)):
			load_pack(pack_path)
	_is_initializing = false
	_is_initialized = true
	_apply_runtime_values_for_loaded_packs()

func reload_configuration() -> void:
	_packs.clear()
	_items_by_id.clear()
	_pack_source_paths.clear()
	_registry = null
	_store = null
	_markdown = null
	_staged_values.clear()
	_restart_pending_items.clear()
	_option_providers.clear()
	_runtime_apply_handlers.clear()
	_is_initialized = false
	_initialize()
	settings_changed.emit()

func set_runtime_apply_enabled(enabled: bool) -> void:
	_runtime_apply_enabled = enabled

func load_registry(resource_path: String) -> bool:
	var resource = ResourceLoader.load(resource_path)
	if resource is Resource and resource.has_method("get_control_scene"):
		_registry = resource
		return true
	_registry = RegistryScript.new()
	return false

func get_registry() -> Resource:
	_initialize()
	return _registry

func load_pack(resource_path: String) -> bool:
	var resource = ResourceLoader.load(resource_path)
	if not (resource is Resource) or not resource.has_method("get_items"):
		return false
	register_pack(resource, resource_path)
	return true

func register_pack(pack: Resource, source_path := "") -> void:
	if not _is_initializing:
		_initialize()
	if pack == null:
		return
	var pack_id := str(pack.get("PackId"))
	for existing in _packs:
		if not pack_id.is_empty() and str(existing.get("PackId")) == pack_id:
			return
	if not _packs.has(pack):
		_packs.append(pack)
	var resolved_source := source_path.strip_edges()
	if resolved_source.is_empty():
		resolved_source = str(pack.resource_path)
	if not resolved_source.is_empty():
		_pack_source_paths[pack.get_instance_id()] = resolved_source
	_rebuild_item_index()
	if not _is_initializing:
		_apply_runtime_values_for_pack(pack)
	packs_changed.emit()
	settings_changed.emit()

func register_option_provider(provider_id: String, handler: Callable) -> void:
	var normalized_id := provider_id.strip_edges()
	if normalized_id.is_empty() or not handler.is_valid():
		return
	_option_providers[normalized_id] = handler

func register_runtime_apply_handler(handler_id: String, handler: Callable) -> void:
	var normalized_id := handler_id.strip_edges()
	if normalized_id.is_empty() or not handler.is_valid():
		return
	_runtime_apply_handlers[normalized_id] = handler

func resolve_options(item_or_id) -> PackedStringArray:
	_initialize()
	var item: Resource = item_or_id if item_or_id is Resource else get_item(str(item_or_id))
	if item == null:
		return PackedStringArray()
	var provider_id := str(item.get("OptionProviderId")).strip_edges()
	if not provider_id.is_empty():
		var provider: Variant = _option_providers.get(provider_id)
		if provider is Callable and (provider as Callable).is_valid():
			var provider_args := item.get("OptionProviderArgs")
			var provider_result: Variant = provider.call(item, Dictionary(provider_args if typeof(provider_args) == TYPE_DICTIONARY else {}).duplicate(true))
			if typeof(provider_result) == TYPE_PACKED_STRING_ARRAY:
				return provider_result
			if typeof(provider_result) == TYPE_ARRAY:
				return PackedStringArray(provider_result)
	if PackedStringArray(item.get("Options")).is_empty():
		return _default_options_for_type(str(item.get("ValueType")))
	return PackedStringArray(item.get("Options"))

func get_resolved_options(item_or_id) -> PackedStringArray:
	return resolve_options(item_or_id)

func get_packs() -> Array:
	_initialize()
	return _packs.duplicate()

func get_items(include_hidden := false) -> Array:
	_initialize()
	var result: Array = []
	for item in _items_by_id.values():
		if item is Resource and item.has_method("display_name") and (include_hidden or not bool(item.get("IsHidden"))):
			result.append(item)
	result.sort_custom(_compare_items)
	return result

func get_item(item_id: String) -> Resource:
	_initialize()
	return _items_by_id.get(item_id)

func get_value(item_id: String) -> Variant:
	_initialize()
	var item = get_item(item_id)
	if item == null:
		return null
	if _staged_values.has(item_id):
		return _staged_values[item_id]
	return _store.get_value(item)

func set_value(item_id: String, value: Variant, source := "runtime") -> Dictionary:
	_initialize()
	var item = get_item(item_id)
	if item == null:
		return {"ok": false, "error": "Unknown settings item '%s'." % item_id}
	if str(item.get("Kind")) != "Setting":
		return {"ok": false, "error": "'%s' is not editable." % item_id}
	if bool(item.get("IsLocked")):
		return {"ok": false, "error": "'%s' is locked. %s" % [item_id, str(item.get("LockReason"))]}
	var validation := validate_value(item, value)
	if not bool(validation.get("ok", false)):
		return validation
	value = validation.get("value")
	var runtime_result := {"ok": true, "message": ""}
	if str(item.get("ApplyPolicy")) == "StagedApply":
		_staged_values[item_id] = value
	else:
		_store.set_value(item, value, source)
		_apply_known_project_setting(item, value)
		runtime_result = _apply_runtime_setting(item, value)
		if str(item.get("ApplyPolicy")) == "RestartRequired" and not _restart_pending_items.has(item_id):
			_restart_pending_items.append(item_id)
	value_changed.emit(item_id, value)
	settings_changed.emit()
	var message := "Updated %s" % item_id
	if str(runtime_result.get("message", "")).strip_edges() != "":
		message = "%s (%s)" % [message, str(runtime_result.get("message"))]
	return {
		"ok": true,
		"message": message,
		"requires_restart": str(item.get("ApplyPolicy")) == "RestartRequired",
		"staged": str(item.get("ApplyPolicy")) == "StagedApply",
		"runtime_warning": not bool(runtime_result.get("ok", true)),
	}

func apply_staged_values() -> Dictionary:
	_initialize()
	var applied := PackedStringArray()
	for item_id in _staged_values.keys():
		var item = get_item(String(item_id))
		if item == null:
			continue
		var value: Variant = _staged_values[item_id]
		var validation := validate_value(item, value)
		if not bool(validation.get("ok", false)):
			continue
		value = validation.get("value")
		_store.set_value(item, value, "staged_apply")
		_apply_known_project_setting(item, value)
		_apply_runtime_setting(item, value)
		applied.append(String(item_id))
	_staged_values.clear()
	settings_changed.emit()
	return {"ok": true, "applied": Array(applied), "message": "Applied %d staged value%s." % [applied.size(), "" if applied.size() == 1 else "s"]}

func discard_staged_values() -> Dictionary:
	var count := _staged_values.size()
	_staged_values.clear()
	settings_changed.emit()
	return {"ok": true, "discarded": count, "message": "Discarded %d staged value%s." % [count, "" if count == 1 else "s"]}

func reset_value(item_id: String) -> Dictionary:
	var item = get_item(item_id)
	if item == null:
		return {"ok": false, "error": "Unknown settings item '%s'." % item_id}
	_store.reset_value(item)
	_staged_values.erase(item_id)
	_apply_known_project_setting(item, item.get_default_value())
	_apply_runtime_setting(item, item.get_default_value())
	if _restart_pending_items.has(item_id):
		_restart_pending_items.remove_at(_restart_pending_items.find(item_id))
	value_changed.emit(item_id, item.get_default_value())
	settings_changed.emit()
	return {"ok": true, "message": "Reset %s to default." % item_id}

func reset_to_default(item_id: String) -> Dictionary:
	return reset_value(item_id)

func get_recent_values(item_id: String) -> Array:
	var item = get_item(item_id)
	return _store.get_recent_values(item) if item != null else []

func get_committed_value(item_id: String) -> Variant:
	_initialize()
	var item = get_item(item_id)
	return _store.get_value(item) if item != null else null

func get_restart_pending_items() -> PackedStringArray:
	return _restart_pending_items.duplicate()

func clear_restart_pending(item_id := "") -> void:
	if item_id.strip_edges().is_empty():
		_restart_pending_items.clear()
	elif _restart_pending_items.has(item_id):
		_restart_pending_items.remove_at(_restart_pending_items.find(item_id))
	settings_changed.emit()

func reapply_runtime_values() -> void:
	_initialize()
	_apply_runtime_values_for_loaded_packs()

func validate_value(item_or_id, value: Variant) -> Dictionary:
	_initialize()
	var item: Resource = item_or_id if item_or_id is Resource else get_item(str(item_or_id))
	if item == null:
		return {"ok": false, "error": "Unknown settings item '%s'." % str(item_or_id)}
	var value_type := str(item.get("ValueType"))
	var normalized: Variant = value
	match value_type:
		"Bool":
			if typeof(value) != TYPE_BOOL:
				return _validation_error(item, "Expected a boolean value.")
		"Float":
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return _validation_error(item, "Expected a numeric value.")
			normalized = float(value)
			var numeric_result := _validate_numeric_bounds(item, float(normalized), false)
			if not bool(numeric_result.get("ok", false)):
				return numeric_result
		"Integer":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return _validation_error(item, "Expected an integer value.")
			if not is_equal_approx(float(value), round(float(value))):
				return _validation_error(item, "Expected an integer value.")
			normalized = int(round(float(value)))
			var numeric_result := _validate_numeric_bounds(item, float(normalized), true)
			if not bool(numeric_result.get("ok", false)):
				return numeric_result
		"Enum", "Choice", "Segmented", "Resolution", "QualityMatrix", "Language":
			normalized = str(value)
			var options := resolve_options(item)
			if not options.is_empty() and not options.has(str(normalized)):
				return _validation_error(item, "Expected one of: %s." % ", ".join(Array(options)))
		"Color":
			var color_result := _normalize_color_value(value)
			if not bool(color_result.get("ok", false)):
				return _validation_error(item, str(color_result.get("error", "Expected a Color value.")))
			normalized = color_result.get("value")
		"Path", "Resource", "Text", "MultilineText", "Keybind", "SensitivityCurve":
			if typeof(value) != TYPE_STRING:
				return _validation_error(item, "Expected a text value.")
			normalized = str(value)
		"FontScale":
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return _validation_error(item, "Expected a numeric value.")
			normalized = float(value)
			var numeric_result := _validate_numeric_bounds(item, float(normalized), false)
			if not bool(numeric_result.get("ok", false)):
				return numeric_result
		"List", "TagPicker":
			if typeof(value) == TYPE_PACKED_STRING_ARRAY:
				normalized = value
			elif typeof(value) == TYPE_ARRAY:
				normalized = PackedStringArray(value)
			elif typeof(value) == TYPE_STRING:
				normalized = _split_csv(value)
			else:
				return _validation_error(item, "Expected a list or comma-separated text value.")
		"Action":
			return {"ok": true, "value": value}
		_:
			return {"ok": true, "value": value}
	return {"ok": true, "value": normalized}

func query_items(query := "", filters: Dictionary = {}) -> Array:
	return search_items(query, filters)

func search_items(query := "", filters: Dictionary = {}) -> Array:
	_initialize()
	var result: Array = []
	for item in get_items(bool(filters.get("include_hidden", false))):
		if not bool(item.call("matches_search", query)):
			continue
		if not _filter_allows_item(item, filters):
			continue
		result.append(item)
	return result

func get_setting_groups() -> PackedStringArray:
	var groups := PackedStringArray()
	for item in get_items(true):
		var group_path := str(item.get("GroupPath"))
		if not group_path.is_empty() and not groups.has(group_path):
			groups.append(group_path)
	groups.sort()
	return groups

func get_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for item in get_items(true):
		for tag in item.get("Tags"):
			var typed_tag := String(tag)
			if not tags.has(typed_tag):
				tags.append(typed_tag)
	tags.sort()
	return tags

func export_markdown_for_all() -> Dictionary:
	_initialize()
	var exported := []
	var errors := []
	for pack in _packs:
		var docs_root := _resolve_pack_docs_root(pack)
		for item in pack.get_items():
			var path := _resolve_item_docs_path(item, docs_root)
			var result = _markdown.export_item(item, path)
			if result.get("ok", false):
				exported.append(path)
			else:
				errors.append(result.get("error", "Unknown markdown export error."))
	return {"ok": errors.is_empty(), "exported": exported, "errors": errors, "message": "Exported %d markdown item file%s%s" % [exported.size(), "" if exported.size() == 1 else "s", "." if errors.is_empty() else " with %d error%s." % [errors.size(), "" if errors.size() == 1 else "s"]]}

func export_markdown_for_item(item_id: String) -> Dictionary:
	_initialize()
	var item = get_item(item_id)
	if item == null:
		return {"ok": false, "error": "Unknown item '%s'." % item_id}
	var pack = _find_pack_for_item(item_id)
	if pack == null:
		return {"ok": false, "error": "Could not find pack for '%s'." % item_id}
	var path := _resolve_item_docs_path(item, _resolve_pack_docs_root(pack))
	var result = _markdown.export_item(item, path)
	if result.get("ok", false):
		result["message"] = "Exported markdown for %s." % item_id
	return result

func import_markdown_for_item(item_id: String) -> Dictionary:
	_initialize()
	var item = get_item(item_id)
	if item == null:
		return {"ok": false, "error": "Unknown item '%s'." % item_id}
	var pack = _find_pack_for_item(item_id)
	if pack == null:
		return {"ok": false, "error": "Could not find pack for '%s'." % item_id}
	var path := _resolve_item_docs_path(item, _resolve_pack_docs_root(pack))
	var result = _markdown.import_item(item, path)
	if result.get("ok", false):
		var save_result := _save_pack_if_possible(pack)
		result["pack_saved"] = save_result.get("ok", false)
		if not bool(save_result.get("ok", false)):
			result["pack_save_error"] = save_result.get("error", "")
		result["message"] = "Imported markdown for %s." % item_id
		settings_changed.emit()
	return result

func detect_markdown_sync() -> Dictionary:
	_initialize()
	var statuses := []
	var conflicted := 0
	for pack in _packs:
		var docs_root := _resolve_pack_docs_root(pack)
		for item in pack.get_items():
			var path := _resolve_item_docs_path(item, docs_root)
			var status = _markdown.get_sync_status(item, path)
			status["id"] = str(item.get("ItemId"))
			status["path"] = path
			if str(status.get("status", "")) == "conflict":
				conflicted += 1
			statuses.append(status)
	return {"ok": conflicted == 0, "statuses": statuses, "conflicts": conflicted, "message": "%d settings item%s checked, %d conflict%s." % [statuses.size(), "" if statuses.size() == 1 else "s", conflicted, "" if conflicted == 1 else "s"]}

func resolve_markdown_conflict(item_id: String, decision: String) -> Dictionary:
	var normalized := decision.strip_edges().to_lower()
	match normalized:
		"resource_wins", "resource", "export":
			return export_markdown_for_item(item_id)
		"markdown_wins", "markdown", "import":
			return import_markdown_for_item(item_id)
		"skip":
			return {"ok": true, "message": "Skipped markdown conflict for %s." % item_id}
		_:
			return {"ok": false, "error": "Unknown markdown conflict decision '%s'. Use resource_wins, markdown_wins, or skip." % decision}

func build_profile_data(
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	include_staged := false,
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	_initialize()
	var overrides := _staged_values if include_staged else {}
	var profile: Dictionary = _store.build_profile(
		get_items(true),
		full_snapshot,
		selected_ids,
		overrides,
		selected_groups,
		selected_tags
	)
	profile["format"] = PROFILE_FORMAT
	profile["version"] = PROFILE_VERSION
	return profile

func export_profile_text(
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	include_staged := false,
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var profile := build_profile_data(full_snapshot, selected_ids, include_staged, selected_groups, selected_tags)
	return {"ok": true, "profile": profile, "text": JSON.stringify(profile, "\t")}

func parse_profile_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return {
			"ok": false,
			"error": "Profile JSON parse failed at line %d: %s." % [parser.get_error_line(), parser.get_error_message()],
		}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Profile JSON root must be an object."}
	var profile: Dictionary = parsed
	if str(profile.get("format", PROFILE_FORMAT)) != PROFILE_FORMAT:
		return {"ok": false, "error": "Unsupported profile format '%s'." % str(profile.get("format", ""))}
	if int(profile.get("version", PROFILE_VERSION)) > PROFILE_VERSION:
		return {"ok": false, "error": "Unsupported profile version %d." % int(profile.get("version", 0))}
	if typeof(profile.get("values", {})) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Profile JSON is missing a 'values' object."}
	return {"ok": true, "profile": profile}

func load_profile_data(path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	if not FileAccess.file_exists(absolute_path):
		return {"ok": false, "error": "Profile '%s' does not exist." % absolute_path}
	var text := FileAccess.get_file_as_string(absolute_path)
	var parsed := parse_profile_text(text)
	if not bool(parsed.get("ok", false)):
		parsed["error"] = "%s (%s)" % [str(parsed.get("error", "Profile parse failed.")), absolute_path]
		return parsed
	parsed["path"] = absolute_path
	parsed["text"] = text
	return parsed

func preview_profile_data(profile: Dictionary) -> Dictionary:
	_initialize()
	var preview_items: Array = []
	var values: Dictionary = profile.get("values", {})
	for item_id in values.keys():
		var typed_id := str(item_id)
		var record_raw: Variant = values[item_id]
		var item = get_item(typed_id)
		var display_name: String = item.display_name() if item != null else typed_id
		if typeof(record_raw) != TYPE_DICTIONARY:
			preview_items.append({
				"id": typed_id,
				"display_name": display_name,
				"exists": item != null,
				"valid": false,
				"error": "Profile entry is not an object.",
				"value": null,
				"raw_value": record_raw,
				"group_path": str(item.get("GroupPath")) if item != null else "",
				"tags": Array(item.get("Tags")) if item != null else [],
				"value_type": str(item.get("ValueType")) if item != null else "",
				"apply_policy": str(item.get("ApplyPolicy")) if item != null else "",
				"kind": str(item.get("Kind")) if item != null else "",
			})
			continue
		var record: Dictionary = record_raw
		var entry_tags: Array = Array(record.get("tags", []))
		if item != null and entry_tags.is_empty():
			entry_tags = Array(item.get("Tags"))
		var group_path := str(record.get("group_path", str(item.get("GroupPath")) if item != null else ""))
		var value_type := str(record.get("value_type", str(item.get("ValueType")) if item != null else ""))
		if item == null:
			display_name = str(record.get("display_name", typed_id))
		var entry := {
			"id": typed_id,
			"display_name": display_name,
			"exists": item != null,
			"valid": false,
			"error": "Unknown setting.",
			"value": record.get("value"),
			"raw_value": record.get("value"),
			"group_path": group_path,
			"tags": entry_tags,
			"value_type": value_type,
			"apply_policy": str(item.get("ApplyPolicy")) if item != null else "",
			"kind": str(item.get("Kind")) if item != null else "",
		}
		if item != null:
			var validation := validate_value(item, record.get("value"))
			entry["valid"] = bool(validation.get("ok", false))
			entry["error"] = str(validation.get("error", ""))
			entry["value"] = validation.get("value") if bool(validation.get("ok", false)) else record.get("value")
		preview_items.append(entry)
	preview_items.sort_custom(_compare_profile_preview_entries)
	return {
		"ok": true,
		"profile": profile,
		"items": preview_items,
		"count": preview_items.size(),
	}

func preview_profile_text(text: String) -> Dictionary:
	var parsed := parse_profile_text(text)
	if not bool(parsed.get("ok", false)):
		return parsed
	return preview_profile_data(parsed.get("profile", {}))

func build_profile_import_diff(
	profile: Dictionary,
	include_ids: PackedStringArray = PackedStringArray(),
	include_groups: PackedStringArray = PackedStringArray(),
	include_tags: PackedStringArray = PackedStringArray(),
	default_preference := IMPORT_KEEP_INCOMING
) -> Dictionary:
	var preview := preview_profile_data(profile)
	if not bool(preview.get("ok", false)):
		return preview
	var changed: Array = []
	var unknown: Array = []
	var invalid: Array = []
	var unchanged_count := 0
	var eligible_count := 0
	var normalized_preference := _normalize_import_preference(default_preference)
	var default_use_incoming := _preference_uses_incoming(normalized_preference)
	for entry_variant in preview.get("items", []):
		var entry: Dictionary = entry_variant
		if not _profile_entry_allows(entry, include_ids, include_groups, include_tags):
			continue
		eligible_count += 1
		if not bool(entry.get("exists", false)):
			unknown.append(_build_nonimportable_profile_row(entry, "Unknown"))
			continue
		if not bool(entry.get("valid", false)):
			invalid.append(_build_nonimportable_profile_row(entry, "Invalid"))
			continue
		var item_id := str(entry.get("id", ""))
		var item = get_item(item_id)
		if item == null:
			unknown.append(_build_nonimportable_profile_row(entry, "Unknown"))
			continue
		var incoming_value: Variant = entry.get("value")
		var current_value: Variant = get_committed_value(item_id)
		if _profile_values_equal(item, current_value, incoming_value):
			unchanged_count += 1
			continue
		changed.append({
			"id": item_id,
			"display_name": str(entry.get("display_name", item_id)),
			"group_path": str(entry.get("group_path", "")),
			"tags": Array(entry.get("tags", [])),
			"value_type": str(entry.get("value_type", str(item.get("ValueType")))),
			"apply_policy": str(item.get("ApplyPolicy")),
			"current_value": current_value,
			"current_value_text": _describe_profile_value(current_value, str(item.get("ValueType"))),
			"incoming_value": incoming_value,
			"incoming_value_text": _describe_profile_value(incoming_value, str(item.get("ValueType"))),
			"use_incoming": default_use_incoming,
		})
	changed.sort_custom(_compare_profile_diff_rows)
	return {
		"ok": true,
		"profile": profile,
		"preview": preview,
		"changed": changed,
		"unknown": unknown,
		"invalid": invalid,
		"exact_match_count": unchanged_count,
		"eligible_count": eligible_count,
		"default_preference": normalized_preference,
		"message": "Found %d changed setting%s, %d unchanged, %d unknown, and %d invalid." % [
			changed.size(),
			"" if changed.size() == 1 else "s",
			unchanged_count,
			unknown.size(),
			invalid.size(),
		],
	}

func apply_profile_data(
	profile: Dictionary,
	include_ids: PackedStringArray = PackedStringArray(),
	include_groups: PackedStringArray = PackedStringArray(),
	include_tags: PackedStringArray = PackedStringArray(),
	resolution_by_id: Dictionary = {},
	default_preference := IMPORT_KEEP_INCOMING
) -> Dictionary:
	var diff := build_profile_import_diff(profile, include_ids, include_groups, include_tags, default_preference)
	if not bool(diff.get("ok", false)):
		return diff
	var imported := PackedStringArray()
	var skipped := PackedStringArray()
	var staged := PackedStringArray()
	var restart_pending := PackedStringArray()
	var effective_default := _preference_uses_incoming(str(diff.get("default_preference", IMPORT_KEEP_INCOMING)))
	for row_variant in diff.get("changed", []):
		var row: Dictionary = row_variant
		var item_id := str(row.get("id", ""))
		var use_incoming := effective_default
		if resolution_by_id.has(item_id):
			use_incoming = _resolution_prefers_incoming(resolution_by_id[item_id], effective_default)
		else:
			use_incoming = bool(row.get("use_incoming", effective_default))
		if not use_incoming:
			skipped.append(item_id)
			continue
		var item = get_item(item_id)
		if item == null:
			continue
		var value: Variant = row.get("incoming_value")
		var apply_policy := str(item.get("ApplyPolicy"))
		if apply_policy == "StagedApply":
			_staged_values[item_id] = value
			staged.append(item_id)
		else:
			_store.set_value(item, value, "profile_import")
			_apply_known_project_setting(item, value)
			_apply_runtime_setting(item, value)
			if apply_policy == "RestartRequired" and not _restart_pending_items.has(item_id):
				_restart_pending_items.append(item_id)
			if apply_policy == "RestartRequired":
				restart_pending.append(item_id)
		value_changed.emit(item_id, value)
		imported.append(item_id)
	if imported.size() > 0 or staged.size() > 0:
		settings_changed.emit()
	return {
		"ok": true,
		"has_warnings": not Array(diff.get("unknown", [])).is_empty() or not Array(diff.get("invalid", [])).is_empty(),
		"result": {
			"changed": Array(imported),
			"skipped": Array(skipped),
			"staged": Array(staged),
			"restart_pending": Array(restart_pending),
			"unknown": Array(diff.get("unknown", [])),
			"invalid": Array(diff.get("invalid", [])),
			"unchanged": int(diff.get("exact_match_count", 0)),
			"available_changes": Array(diff.get("changed", [])).size(),
		},
		"message": "Imported %d setting%s, staged %d, skipped %d, unchanged %d." % [
			imported.size(),
			"" if imported.size() == 1 else "s",
			staged.size(),
			skipped.size(),
			int(diff.get("exact_match_count", 0)),
		],
	}

func export_profile_json(
	path: String,
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	include_staged := false,
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var export_result := export_profile_text(full_snapshot, selected_ids, include_staged, selected_groups, selected_tags)
	if not bool(export_result.get("ok", false)):
		return export_result
	var write_result := _write_profile_text(path, str(export_result.get("text", "")))
	if not bool(write_result.get("ok", false)):
		return write_result
	write_result["profile"] = export_result.get("profile", {})
	return write_result

func export_profile(
	path: String,
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	include_staged := false,
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var json_result := export_profile_json(path, full_snapshot, selected_ids, include_staged, selected_groups, selected_tags)
	if not bool(json_result.get("ok", false)):
		return json_result
	var markdown_path := path.get_basename() + ".md"
	var markdown_result := export_profile_markdown(markdown_path, json_result.get("profile", {}))
	return {
		"ok": bool(markdown_result.get("ok", false)),
		"path": json_result.get("path", path),
		"markdown_path": markdown_result.get("path", markdown_path),
		"profile": json_result.get("profile", {}),
		"message": "Exported %s profile." % ("full" if full_snapshot else "partial"),
	}

func export_profile_markdown(path: String, profile: Dictionary) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	var directory := absolute_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var lines := PackedStringArray()
	lines.append("# Sea Shell Settings Profile")
	lines.append("")
	lines.append("- Mode: `%s`" % String(profile.get("mode", "")))
	lines.append("- Exported: `%s`" % Time.get_datetime_string_from_unix_time(int(profile.get("exported_unix", 0)), true))
	lines.append("")
	lines.append("## Values")
	lines.append("")
	var values: Dictionary = profile.get("values", {})
	for item_id in values.keys():
		var item = get_item(String(item_id))
		var label = item.display_name() if item != null else String(item_id)
		lines.append("- `%s` - %s" % [item_id, label])
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write markdown profile '%s'." % absolute_path}
	file.store_string("\n".join(lines))
	return {"ok": true, "path": absolute_path}

func import_profile_text(
	text: String,
	include_ids: PackedStringArray = PackedStringArray(),
	include_groups: PackedStringArray = PackedStringArray(),
	include_tags: PackedStringArray = PackedStringArray(),
	resolution_by_id: Dictionary = {},
	default_preference := IMPORT_KEEP_INCOMING
) -> Dictionary:
	var parsed := parse_profile_text(text)
	if not bool(parsed.get("ok", false)):
		return parsed
	var result := apply_profile_data(parsed.get("profile", {}), include_ids, include_groups, include_tags, resolution_by_id, default_preference)
	result["ok"] = bool(result.get("ok", false)) and Array(result.get("result", {}).get("invalid", [])).is_empty()
	return result

func import_profile_json(
	path: String,
	include_ids: PackedStringArray = PackedStringArray(),
	include_groups: PackedStringArray = PackedStringArray(),
	include_tags: PackedStringArray = PackedStringArray(),
	resolution_by_id: Dictionary = {},
	default_preference := IMPORT_KEEP_INCOMING
) -> Dictionary:
	var loaded := load_profile_data(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var result := apply_profile_data(loaded.get("profile", {}), include_ids, include_groups, include_tags, resolution_by_id, default_preference)
	result["path"] = loaded.get("path", "")
	result["ok"] = bool(result.get("ok", false)) and Array(result.get("result", {}).get("invalid", [])).is_empty()
	return result

func import_profile(
	path: String,
	include_ids: PackedStringArray = PackedStringArray(),
	include_groups: PackedStringArray = PackedStringArray(),
	include_tags: PackedStringArray = PackedStringArray(),
	resolution_by_id: Dictionary = {},
	default_preference := IMPORT_KEEP_INCOMING
) -> Dictionary:
	return import_profile_json(path, include_ids, include_groups, include_tags, resolution_by_id, default_preference)

func preview_profile(path: String) -> Dictionary:
	var loaded := load_profile_data(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var preview := preview_profile_data(loaded.get("profile", {}))
	preview["path"] = loaded.get("path", "")
	return preview

func list_presets() -> Array:
	_initialize()
	_ensure_directory(DEFAULT_PRESET_DIRECTORY)
	var absolute_root := ProjectSettings.globalize_path(DEFAULT_PRESET_DIRECTORY)
	var dir := DirAccess.open(absolute_root)
	if dir == null:
		return []
	var presets: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			var absolute_path := absolute_root.path_join(file_name)
			var load_result := load_profile_data(absolute_path)
			if bool(load_result.get("ok", false)):
				var profile: Dictionary = load_result.get("profile", {})
				var meta: Dictionary = profile.get("meta", {})
				var values: Dictionary = profile.get("values", {})
				presets.append({
					"name": str(meta.get("preset_name", file_name.get_basename())),
					"path": absolute_path,
					"saved_unix": int(meta.get("saved_unix", profile.get("exported_unix", 0))),
					"item_count": values.size(),
					"mode": str(profile.get("mode", "partial")),
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	presets.sort_custom(_compare_presets)
	return presets

func save_preset(
	name: String,
	full_snapshot := true,
	selected_ids: PackedStringArray = PackedStringArray(),
	selected_groups: PackedStringArray = PackedStringArray(),
	selected_tags: PackedStringArray = PackedStringArray(),
	overwrite := false
) -> Dictionary:
	var trimmed_name := name.strip_edges()
	if trimmed_name.is_empty():
		return {"ok": false, "error": "Preset name cannot be empty."}
	var path := _preset_path_for_name(trimmed_name)
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) and not overwrite:
		return {"ok": false, "error": "Preset '%s' already exists." % trimmed_name, "path": absolute_path}
	var profile := build_profile_data(full_snapshot, selected_ids, false, selected_groups, selected_tags)
	profile["meta"] = {
		"preset_name": trimmed_name,
		"saved_unix": Time.get_unix_time_from_system(),
	}
	var write_result := _write_profile_text(path, JSON.stringify(profile, "\t"))
	if not bool(write_result.get("ok", false)):
		return write_result
	write_result["profile"] = profile
	write_result["message"] = "Saved preset '%s'." % trimmed_name
	return write_result

func load_preset(preset_name_or_path: String) -> Dictionary:
	var trimmed := preset_name_or_path.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "Preset name cannot be empty."}
	var path := trimmed if FileAccess.file_exists(trimmed) else _preset_path_for_name(trimmed)
	var loaded := load_profile_data(path)
	if bool(loaded.get("ok", false)):
		var profile: Dictionary = loaded.get("profile", {})
		var meta: Dictionary = profile.get("meta", {})
		loaded["preset_name"] = str(meta.get("preset_name", trimmed.get_file().get_basename()))
	return loaded

func _filter_allows_item(item: Resource, filters: Dictionary) -> bool:
	var group := String(filters.get("group_path", filters.get("group", ""))).strip_edges()
	if not group.is_empty() and not str(item.get("GroupPath")).begins_with(group):
		return false
	var kind := String(filters.get("kind", "")).strip_edges()
	if not kind.is_empty() and kind != str(item.get("Kind")):
		return false
	var value_type := String(filters.get("value_type", "")).strip_edges()
	if not value_type.is_empty() and value_type != str(item.get("ValueType")):
		return false
	var tags: PackedStringArray = filters.get("tags", PackedStringArray())
	for tag in tags:
		if not item.get("Tags").has(tag):
			return false
	var modified_filter := String(filters.get("modified", "Any"))
	if modified_filter == "Definition" and int(item.call("get_definition_modified_unix")) <= 0:
		return false
	if modified_filter == "Value" and _store.get_value_modified_unix(str(item.get("ItemId"))) <= 0:
		return false
	if filters.has("definition_modified_after_unix") and int(item.call("get_definition_modified_unix")) <= int(filters.get("definition_modified_after_unix", 0)):
		return false
	if filters.has("value_modified_after_unix") and _store.get_value_modified_unix(str(item.get("ItemId"))) <= int(filters.get("value_modified_after_unix", 0)):
		return false
	return true

func _rebuild_item_index() -> void:
	_items_by_id.clear()
	for pack in _packs:
		for item in pack.get_items():
			var item_id := str(item.get("ItemId")).strip_edges()
			if not item_id.is_empty():
				_items_by_id[item_id] = item

func _compare_items(left, right) -> bool:
	var left_key := "%s/%s" % [str(left.get("GroupPath")), left.display_name()]
	var right_key := "%s/%s" % [str(right.get("GroupPath")), right.display_name()]
	return left_key.nocasecmp_to(right_key) < 0

func _compare_profile_preview_entries(left, right) -> bool:
	var left_key := "%s/%s" % [str(left.get("group_path", "")), str(left.get("display_name", left.get("id", "")))]
	var right_key := "%s/%s" % [str(right.get("group_path", "")), str(right.get("display_name", right.get("id", "")))]
	return left_key.nocasecmp_to(right_key) < 0

func _compare_profile_diff_rows(left, right) -> bool:
	var left_key := "%s/%s" % [str(left.get("group_path", "")), str(left.get("display_name", left.get("id", "")))]
	var right_key := "%s/%s" % [str(right.get("group_path", "")), str(right.get("display_name", right.get("id", "")))]
	return left_key.nocasecmp_to(right_key) < 0

func _compare_presets(left, right) -> bool:
	var left_saved := int(left.get("saved_unix", 0))
	var right_saved := int(right.get("saved_unix", 0))
	if left_saved != right_saved:
		return left_saved > right_saved
	return str(left.get("name", "")).nocasecmp_to(str(right.get("name", ""))) < 0

func _write_profile_text(path: String, text: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	_ensure_directory(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write profile '%s'." % absolute_path}
	file.store_string(text)
	return {"ok": true, "path": absolute_path}

func _ensure_directory(path: String) -> void:
	if path.strip_edges().is_empty():
		return
	if path.begins_with("res://") or path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	else:
		DirAccess.make_dir_recursive_absolute(path)

func _preset_path_for_name(name: String) -> String:
	_ensure_directory(DEFAULT_PRESET_DIRECTORY)
	var safe_name := _sanitize_file_name(name)
	if safe_name.is_empty():
		safe_name = "preset"
	return DEFAULT_PRESET_DIRECTORY.path_join("%s.json" % safe_name)

func _sanitize_file_name(name: String) -> String:
	var safe_name := name.strip_edges()
	for token in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe_name = safe_name.replace(token, "_")
	safe_name = safe_name.replace("  ", " ").replace(" ", "_")
	return safe_name.strip_edges().to_lower()

func _build_nonimportable_profile_row(entry: Dictionary, row_kind: String) -> Dictionary:
	return {
		"id": str(entry.get("id", "")),
		"display_name": str(entry.get("display_name", entry.get("id", ""))),
		"group_path": str(entry.get("group_path", "")),
		"tags": Array(entry.get("tags", [])),
		"value_type": str(entry.get("value_type", "")),
		"kind": row_kind,
		"error": str(entry.get("error", "")),
		"incoming_value": entry.get("value"),
		"incoming_value_text": _describe_profile_value(entry.get("value"), str(entry.get("value_type", ""))),
	}

func _profile_values_equal(item: Resource, left: Variant, right: Variant) -> bool:
	if item == null:
		return JSON.stringify(_encode_profile_value(left)) == JSON.stringify(_encode_profile_value(right))
	return JSON.stringify(_encode_profile_value(validate_value(item, left).get("value", left))) == JSON.stringify(_encode_profile_value(validate_value(item, right).get("value", right)))

func _encode_profile_value(value: Variant) -> Variant:
	return _store.encode_value(value) if _store != null and _store.has_method("encode_value") else value

func _describe_profile_value(value: Variant, value_type := "") -> String:
	match typeof(value):
		TYPE_NIL:
			return "(unset)"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_COLOR:
			return "#%s" % (value as Color).to_html(true)
		TYPE_PACKED_STRING_ARRAY:
			return ", ".join(Array(value))
		TYPE_ARRAY, TYPE_DICTIONARY:
			return JSON.stringify(value)
		TYPE_STRING:
			var text := str(value)
			if value_type == "Color":
				text = text.strip_edges()
				if text.begins_with("#"):
					text = text.substr(1)
				return "#%s" % text
			return text
		_:
			return str(value)

func _normalize_import_preference(preference: String) -> String:
	var normalized := preference.strip_edges().to_lower()
	return IMPORT_KEEP_MINE if normalized in ["keepmine", "mine", "local", "keep_mine"] else IMPORT_KEEP_INCOMING

func _preference_uses_incoming(preference: String) -> bool:
	return _normalize_import_preference(preference) == IMPORT_KEEP_INCOMING

func _resolution_prefers_incoming(choice: Variant, default_value: bool) -> bool:
	match typeof(choice):
		TYPE_BOOL:
			return bool(choice)
		TYPE_STRING:
			var normalized := str(choice).strip_edges().to_lower()
			if normalized in ["incoming", "keepincoming", "keep_incoming", "theirs"]:
				return true
			if normalized in ["mine", "keepmine", "keep_mine", "local"]:
				return false
		TYPE_DICTIONARY:
			if choice.has("use_incoming"):
				return bool(choice.get("use_incoming", default_value))
	return default_value

func _profile_entry_allows(entry: Dictionary, include_ids: PackedStringArray, include_groups: PackedStringArray, include_tags: PackedStringArray) -> bool:
	if include_ids.is_empty() and include_groups.is_empty() and include_tags.is_empty():
		return true
	if include_ids.has(str(entry.get("id", ""))):
		return true
	var entry_group := str(entry.get("group_path", ""))
	for group in include_groups:
		if _group_path_matches_scope(entry_group, String(group)):
			return true
	for tag in entry.get("tags", []):
		if include_tags.has(str(tag)):
			return true
	return false

func _group_path_matches_scope(group_path: String, scope_group: String) -> bool:
	var normalized_scope := scope_group.strip_edges()
	if normalized_scope.is_empty():
		return false
	var normalized_group := group_path.strip_edges()
	return normalized_group == normalized_scope or normalized_group.begins_with(normalized_scope + "/")

func _find_pack_for_item(item_id: String) -> Resource:
	for pack in _packs:
		if pack.get_item(item_id) != null:
			return pack
	return null

func _resolve_item_docs_path(item: Resource, docs_root: String) -> String:
	var docs_path := str(item.get("DocsPath")).strip_edges()
	if not docs_path.is_empty():
		return ProjectSettings.globalize_path(docs_path)
	var file_name = str(item.get("ItemId")).replace(".", " ").replace("/", " ").strip_edges()
	if file_name.is_empty():
		file_name = item.display_name()
	return docs_root.path_join("%s.md" % file_name)

func _resolve_pack_docs_root(pack: Resource) -> String:
	var docs_path := ""
	if pack != null and pack.has_method("get_docs_directory"):
		docs_path = str(pack.call("get_docs_directory"))
	elif pack != null:
		docs_path = str(pack.get("DocsDirectory"))
	return ProjectSettings.globalize_path(docs_path)

func _get_pack_source_path(pack: Resource) -> String:
	if pack == null:
		return ""
	var source := str(_pack_source_paths.get(pack.get_instance_id(), ""))
	return source if not source.is_empty() else str(pack.resource_path)

func _save_pack_if_possible(pack: Resource) -> Dictionary:
	var source := _get_pack_source_path(pack)
	if source.is_empty():
		return {"ok": false, "error": "Pack has no source path."}
	if not source.begins_with("res://"):
		return {"ok": false, "error": "Pack source is not inside res://."}
	var error := ResourceSaver.save(pack, source)
	return {"ok": error == OK, "error": error_string(error), "path": source}

func _apply_known_project_setting(item: Resource, value: Variant) -> void:
	if str(item.get("ItemId")) == "SeaShell.UiLayers.DebugOverlay":
		var setting_name := "seashell_devtools/ui_layers/debug_overlay_enabled"
		var enabled := bool(value)
		if bool(ProjectSettings.get_setting(setting_name, false)) == enabled:
			return
		ProjectSettings.set_setting(setting_name, enabled)
		ProjectSettings.save()
	elif str(item.get("ItemId")) == "SeaShell.Performance.OverlayEnabled":
		var performance_setting_name := "seashell_devtools/performance/debug_overlay_enabled"
		var performance_enabled := bool(value)
		if bool(ProjectSettings.get_setting(performance_setting_name, false)) == performance_enabled:
			return
		ProjectSettings.set_setting(performance_setting_name, performance_enabled)
		ProjectSettings.save()

func _apply_runtime_values_for_loaded_packs() -> void:
	if not _runtime_apply_enabled:
		return
	for pack in _packs:
		_apply_runtime_values_for_pack(pack)

func _apply_runtime_values_for_pack(pack: Resource) -> void:
	if not _runtime_apply_enabled or pack == null:
		return
	for item in pack.get_items():
		if item == null or str(item.get("Kind")) != "Setting":
			continue
		_apply_runtime_setting(item, _store.get_value(item))

func _apply_runtime_setting(item: Resource, value: Variant) -> Dictionary:
	if not _runtime_apply_enabled or item == null:
		return {"ok": true, "message": ""}
	var handler_id := str(item.get("RuntimeApplyId")).strip_edges()
	if handler_id.is_empty():
		return {"ok": true, "message": ""}
	var handler: Variant = _runtime_apply_handlers.get(handler_id)
	if not (handler is Callable) or not (handler as Callable).is_valid():
		return {"ok": false, "message": "Runtime handler '%s' is unavailable." % handler_id}
	var runtime_apply_args := item.get("RuntimeApplyArgs")
	var result: Variant = (handler as Callable).call(item, value, Dictionary(runtime_apply_args if typeof(runtime_apply_args) == TYPE_DICTIONARY else {}).duplicate(true))
	return _normalize_runtime_apply_result(handler_id, result)

func _normalize_runtime_apply_result(handler_id: String, result: Variant) -> Dictionary:
	match typeof(result):
		TYPE_DICTIONARY:
			var typed_result := Dictionary(result).duplicate(true)
			if not typed_result.has("ok"):
				typed_result["ok"] = true
			if not typed_result.has("message"):
				typed_result["message"] = ""
			return typed_result
		TYPE_BOOL:
			return {
				"ok": bool(result),
				"message": "" if bool(result) else "Runtime handler '%s' reported a soft failure." % handler_id,
			}
		_:
			return {"ok": true, "message": ""}

func _register_builtin_option_providers() -> void:
	if not _option_providers.has("common_resolutions"):
		register_option_provider("common_resolutions", Callable(self, "_provide_common_resolutions"))
	if not _option_providers.has("display_monitors"):
		register_option_provider("display_monitors", Callable(self, "_provide_display_monitors"))
	if not _option_providers.has("audio_buses"):
		register_option_provider("audio_buses", Callable(self, "_provide_audio_buses"))

func _register_builtin_runtime_apply_handlers() -> void:
	if not _runtime_apply_handlers.has("audio_bus_volume"):
		register_runtime_apply_handler("audio_bus_volume", Callable(self, "_apply_audio_bus_volume"))
	if not _runtime_apply_handlers.has("frame_rate_cap"):
		register_runtime_apply_handler("frame_rate_cap", Callable(self, "_apply_frame_rate_cap"))
	if not _runtime_apply_handlers.has("vsync_mode"):
		register_runtime_apply_handler("vsync_mode", Callable(self, "_apply_vsync_mode"))
	if not _runtime_apply_handlers.has("window_mode"):
		register_runtime_apply_handler("window_mode", Callable(self, "_apply_window_mode"))
	if not _runtime_apply_handlers.has("window_resolution"):
		register_runtime_apply_handler("window_resolution", Callable(self, "_apply_window_resolution"))
	if not _runtime_apply_handlers.has("display_monitor"):
		register_runtime_apply_handler("display_monitor", Callable(self, "_apply_display_monitor"))

func _provide_common_resolutions(_item: Resource, args: Dictionary) -> PackedStringArray:
	var options := PackedStringArray(["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"])
	for extra_option in args.get("extra_options", []):
		var typed_option := str(extra_option).strip_edges()
		if not typed_option.is_empty() and not options.has(typed_option):
			options.append(typed_option)
	return options

func _provide_display_monitors(_item: Resource, args: Dictionary) -> PackedStringArray:
	var prefix := str(args.get("label_prefix", "Monitor")).strip_edges()
	if prefix.is_empty():
		prefix = "Monitor"
	var count := max(DisplayServer.get_screen_count(), 1)
	var options := PackedStringArray()
	for screen_index in range(count):
		options.append("%s %d" % [prefix, screen_index + 1])
	return options

func _provide_audio_buses(_item: Resource, args: Dictionary) -> PackedStringArray:
	var options := PackedStringArray()
	for bus_index in range(AudioServer.get_bus_count()):
		var bus_name := str(AudioServer.get_bus_name(bus_index)).strip_edges()
		if not bus_name.is_empty() and not options.has(bus_name):
			options.append(bus_name)
	var fallback_bus := str(args.get("fallback_bus", "Master")).strip_edges()
	if options.is_empty() and not fallback_bus.is_empty():
		options.append(fallback_bus)
	return options

func _apply_audio_bus_volume(_item: Resource, value: Variant, args: Dictionary) -> Dictionary:
	var bus_name := str(args.get("bus_name", "Master")).strip_edges()
	if bus_name.is_empty():
		return {"ok": false, "message": "No audio bus name was configured."}
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return {"ok": false, "message": "Audio bus '%s' was not found." % bus_name}
	AudioServer.set_bus_volume_linear(bus_index, clampf(float(value), 0.0, 1.0))
	return {"ok": true, "message": ""}

func _apply_frame_rate_cap(_item: Resource, value: Variant, _args: Dictionary) -> Dictionary:
	Engine.max_fps = max(0, int(value))
	return {"ok": true, "message": ""}

func _apply_vsync_mode(_item: Resource, value: Variant, _args: Dictionary) -> Dictionary:
	if _display_runtime_unavailable():
		return {"ok": true, "message": ""}
	var vsync_mode := _vsync_mode_from_value(str(value))
	if vsync_mode < 0:
		return {"ok": false, "message": "Unknown V-Sync mode '%s'." % str(value)}
	DisplayServer.window_set_vsync_mode(vsync_mode)
	return {"ok": true, "message": ""}

func _apply_window_mode(_item: Resource, value: Variant, _args: Dictionary) -> Dictionary:
	if _display_runtime_unavailable():
		return {"ok": true, "message": ""}
	var window := get_window()
	if window == null:
		return {"ok": false, "message": "Main window was unavailable."}
	var mode_name := str(value).strip_edges().to_lower()
	match mode_name:
		"fullscreen":
			window.mode = Window.MODE_FULLSCREEN
			window.borderless = true
		"borderless":
			window.mode = Window.MODE_WINDOWED
			window.borderless = true
		"windowed":
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
		_:
			return {"ok": false, "message": "Unknown window mode '%s'." % str(value)}
	return {"ok": true, "message": ""}

func _apply_window_resolution(_item: Resource, value: Variant, _args: Dictionary) -> Dictionary:
	if _display_runtime_unavailable():
		return {"ok": true, "message": ""}
	var window := get_window()
	if window == null:
		return {"ok": false, "message": "Main window was unavailable."}
	var parsed_size := _parse_resolution_value(str(value))
	if not bool(parsed_size.get("ok", false)):
		return parsed_size
	if window.mode != Window.MODE_WINDOWED or window.borderless:
		return {"ok": true, "message": ""}
	window.size = parsed_size.get("size")
	return {"ok": true, "message": ""}

func _apply_display_monitor(_item: Resource, value: Variant, _args: Dictionary) -> Dictionary:
	if _display_runtime_unavailable():
		return {"ok": true, "message": ""}
	var screen_index := _monitor_index_from_value(str(value))
	var screen_count := max(DisplayServer.get_screen_count(), 1)
	if screen_index < 0 or screen_index >= screen_count:
		return {"ok": false, "message": "Display monitor '%s' is unavailable." % str(value)}
	DisplayServer.window_set_current_screen(screen_index)
	return {"ok": true, "message": ""}

func _display_runtime_unavailable() -> bool:
	return DisplayServer.get_name().strip_edges().to_lower() == "headless"

func _parse_resolution_value(text: String) -> Dictionary:
	var normalized := text.strip_edges().to_lower()
	var separator_index := normalized.find("x")
	if separator_index <= 0 or separator_index >= normalized.length() - 1:
		return {"ok": false, "message": "Resolution '%s' is invalid." % text}
	var width_text := normalized.substr(0, separator_index).strip_edges()
	var height_text := normalized.substr(separator_index + 1).strip_edges()
	if not width_text.is_valid_int() or not height_text.is_valid_int():
		return {"ok": false, "message": "Resolution '%s' is invalid." % text}
	return {"ok": true, "size": Vector2i(int(width_text), int(height_text))}

func _monitor_index_from_value(text: String) -> int:
	var normalized := text.strip_edges()
	if normalized.is_valid_int():
		return int(normalized)
	var parts := normalized.split(" ", false)
	if parts.is_empty():
		return -1
	var last_part := str(parts[parts.size() - 1]).strip_edges()
	if not last_part.is_valid_int():
		return -1
	return int(last_part) - 1

func _vsync_mode_from_value(text: String) -> int:
	match text.strip_edges().to_lower():
		"disabled":
			return DisplayServer.VSYNC_DISABLED
		"enabled":
			return DisplayServer.VSYNC_ENABLED
		"adaptive":
			return DisplayServer.VSYNC_ADAPTIVE
		"mailbox":
			return DisplayServer.VSYNC_MAILBOX
		_:
			return -1

func _create_store():
	var script_path := _project_string(SETTINGS_STORE_SCRIPT_PATH, "")
	var store_script = null
	if not script_path.is_empty():
		store_script = load(script_path)
	if store_script == null or not (store_script is Script) or not store_script.can_instantiate():
		store_script = StoreScript
	var store = store_script.new()
	if not store.has_method("configure"):
		store = StoreScript.new()
	return store

func _project_string(setting_name: String, default_value: String) -> String:
	return str(ProjectSettings.get_setting(setting_name, default_value)).strip_edges()

func _project_string_array(setting_name: String, default_value: PackedStringArray) -> PackedStringArray:
	var raw = ProjectSettings.get_setting(setting_name, default_value)
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		return raw
	if typeof(raw) == TYPE_ARRAY:
		return PackedStringArray(raw)
	var result := PackedStringArray()
	for part in str(raw).split(",", false):
		var path := part.strip_edges()
		if not path.is_empty():
			result.append(path)
	return result if not result.is_empty() else default_value

func _validation_error(item: Resource, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": "%s: %s" % [str(item.get("ItemId")), message],
	}

func _validate_numeric_bounds(item: Resource, value: float, integer_only: bool) -> Dictionary:
	var min_value := float(item.get("MinValue"))
	var max_value := float(item.get("MaxValue"))
	if not is_equal_approx(min_value, max_value):
		if value < min_value or value > max_value:
			return _validation_error(item, "Expected value between %s and %s." % [min_value, max_value])
	var step := float(item.get("Step"))
	if step > 0.0 and not is_equal_approx(step, 0.01):
		var base := min_value if not is_equal_approx(min_value, max_value) else 0.0
		var steps := (value - base) / step
		if not is_equal_approx(steps, round(steps)):
			return _validation_error(item, "Expected value to follow step %s." % step)
	if integer_only and not is_equal_approx(value, round(value)):
		return _validation_error(item, "Expected an integer value.")
	return {"ok": true}

func _normalize_color_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_COLOR:
		return {"ok": true, "value": value}
	if typeof(value) == TYPE_DICTIONARY and str(value.get("__type", "")) == "Color":
		return _normalize_color_value(str(value.get("value", "ffffffff")))
	if typeof(value) == TYPE_STRING:
		var text := str(value).strip_edges()
		if text.begins_with("#"):
			text = text.substr(1)
		if text.length() == 6 or text.length() == 8:
			return {"ok": true, "value": Color.html(text)}
	return {"ok": false, "error": "Expected a Color or hex color string."}

func _default_options_for_type(value_type: String) -> PackedStringArray:
	match value_type:
		"Resolution":
			return PackedStringArray(["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"])
		"QualityMatrix":
			return PackedStringArray(["Low", "Medium", "High", "Ultra"])
		"Language":
			return PackedStringArray(["English", "Spanish", "French", "German", "Japanese", "Korean", "Chinese"])
		_:
			return PackedStringArray()

func _split_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for part in value.split(",", false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result

func _profile_filter_allows(item: Resource, include_ids: PackedStringArray, include_groups: PackedStringArray, include_tags: PackedStringArray) -> bool:
	if include_ids.is_empty() and include_groups.is_empty() and include_tags.is_empty():
		return true
	if include_ids.has(str(item.get("ItemId"))):
		return true
	for group in include_groups:
		if _group_path_matches_scope(str(item.get("GroupPath")), String(group)):
			return true
	for tag in item.get("Tags"):
		if include_tags.has(str(tag)):
			return true
	return false
