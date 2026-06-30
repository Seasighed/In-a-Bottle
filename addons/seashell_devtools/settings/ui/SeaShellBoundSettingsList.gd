@tool
extends VBoxContainer

const BoundFieldScene := preload("res://addons/seashell_devtools/settings/ui/SeaShellBoundSettingField.tscn")

signal operation_completed(item_id: String, result: Dictionary)
signal action_requested(item_id: String)

@export var SettingIds := PackedStringArray()
@export var ShowDescription := true
@export var ShowItemId := false
@export var ShowMetadataChips := false
@export var ShowToolbarActions := false
@export_enum("Manual", "InputDeviceBatch") var ViewMode := "Manual"
@export var ShowInputDeviceGroupHeaders := true
@export var DeviceFilters := PackedStringArray()
@export var SearchQuery := ""

var _settings_service: Node

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_resolve_service()
	_rebuild()

func set_settings_service(service: Node) -> void:
	_settings_service = service
	if is_inside_tree():
		_rebuild()

func refresh() -> void:
	_rebuild()

func get_field_count() -> int:
	var count := 0
	for child in get_children():
		if child.has_method("set_setting_id"):
			count += 1
	return count

func _resolve_service() -> void:
	if _settings_service != null:
		return
	_settings_service = get_node_or_null("/root/SeaShellSettings")

func _rebuild() -> void:
	_resolve_service()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var items := _resolve_items()
	if items.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No Sea Shell settings were assigned."
		add_child(placeholder)
		return
	var group_by_input_device := ViewMode == "InputDeviceBatch"
	var view_data := {
		"items": items,
		"batches": [{"key": "all", "label": "", "items": items, "count": items.size()}],
	}
	if _settings_service != null and _settings_service.has_method("build_item_view"):
		view_data = _settings_service.call("build_item_view", items, {
			"group_by_input_device": group_by_input_device,
			"device_filters": DeviceFilters,
		})
	for batch_variant in Array(view_data.get("batches", [])):
		var batch: Dictionary = batch_variant
		if group_by_input_device and ShowInputDeviceGroupHeaders:
			_add_input_device_batch_header(batch)
		for item in Array(batch.get("items", [])):
			_add_bound_field(str(item.get("ItemId")))

func _resolve_items() -> Array:
	var items: Array = []
	if _settings_service == null or not _settings_service.has_method("get_item"):
		return items
	if SettingIds.is_empty():
		if SearchQuery.strip_edges().is_empty() and DeviceFilters.is_empty():
			return items
		var filters := {}
		if not DeviceFilters.is_empty():
			filters["input_devices"] = DeviceFilters
		if _settings_service.has_method("search_items"):
			return _settings_service.call("search_items", SearchQuery, filters)
		return items
	for setting_id in SettingIds:
		var item = _settings_service.call("get_item", str(setting_id))
		if item == null:
			continue
		if not SearchQuery.strip_edges().is_empty() and item.has_method("matches_search") and not bool(item.call("matches_search", SearchQuery)):
			continue
		items.append(item)
	return items

func _add_bound_field(setting_id: String) -> void:
	var field = BoundFieldScene.instantiate()
	field.SettingId = setting_id
	field.ShowDescription = ShowDescription
	field.ShowItemId = ShowItemId
	field.ShowMetadataChips = ShowMetadataChips
	field.ShowToolbarActions = ShowToolbarActions
	if field.has_method("set_settings_service"):
		field.call("set_settings_service", _settings_service)
	field.connect("operation_completed", Callable(self, "_on_field_operation_completed"))
	field.connect("action_requested", Callable(self, "_on_field_action_requested"))
	add_child(field)

func _add_input_device_batch_header(batch: Dictionary) -> void:
	var label := Label.new()
	var batch_label := str(batch.get("label", batch.get("key", "Input device"))).strip_edges()
	var count := int(batch.get("count", Array(batch.get("items", [])).size()))
	label.text = "%s (%d)" % [batch_label, count]
	label.modulate = Color(0.58, 0.86, 0.92)
	add_child(label)

func _on_field_operation_completed(item_id: String, result: Dictionary) -> void:
	operation_completed.emit(item_id, result)

func _on_field_action_requested(item_id: String) -> void:
	action_requested.emit(item_id)
