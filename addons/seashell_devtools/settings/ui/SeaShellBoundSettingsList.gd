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
	return get_child_count()

func _resolve_service() -> void:
	if _settings_service != null:
		return
	_settings_service = get_node_or_null("/root/SeaShellSettings")

func _rebuild() -> void:
	_resolve_service()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if SettingIds.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No Sea Shell settings were assigned."
		add_child(placeholder)
		return
	for setting_id in SettingIds:
		var field = BoundFieldScene.instantiate()
		field.SettingId = str(setting_id)
		field.ShowDescription = ShowDescription
		field.ShowItemId = ShowItemId
		field.ShowMetadataChips = ShowMetadataChips
		field.ShowToolbarActions = ShowToolbarActions
		if field.has_method("set_settings_service"):
			field.call("set_settings_service", _settings_service)
		field.connect("operation_completed", Callable(self, "_on_field_operation_completed"))
		field.connect("action_requested", Callable(self, "_on_field_action_requested"))
		add_child(field)

func _on_field_operation_completed(item_id: String, result: Dictionary) -> void:
	operation_completed.emit(item_id, result)

func _on_field_action_requested(item_id: String) -> void:
	action_requested.emit(item_id)
