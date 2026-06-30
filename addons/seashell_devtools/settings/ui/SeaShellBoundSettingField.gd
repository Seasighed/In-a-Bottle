@tool
extends PanelContainer

const FallbackControlScene := preload("res://addons/seashell_devtools/settings/ui/SeaShellSettingControl.tscn")

signal operation_completed(item_id: String, result: Dictionary)
signal action_requested(item_id: String)

@export var SettingId := ""
@export var ShowDescription := true
@export var ShowItemId := false
@export var ShowMetadataChips := false
@export var ShowToolbarActions := false

var _settings_service: Node

func _ready() -> void:
	_resolve_service()
	_connect_service_signals()
	_rebuild()

func set_settings_service(service: Node) -> void:
	if _settings_service == service:
		return
	_disconnect_service_signals()
	_settings_service = service
	_connect_service_signals()
	if is_inside_tree():
		_rebuild()

func set_setting_id(setting_id: String) -> void:
	SettingId = setting_id
	if is_inside_tree():
		_rebuild()

func refresh() -> void:
	_rebuild()

func _resolve_service() -> void:
	if _settings_service != null:
		return
	_settings_service = get_node_or_null("/root/SeaShellSettings")

func _connect_service_signals() -> void:
	if _settings_service == null:
		return
	var settings_changed_callable := Callable(self, "_on_service_settings_changed")
	if _settings_service.has_signal("settings_changed") and not _settings_service.is_connected("settings_changed", settings_changed_callable):
		_settings_service.connect("settings_changed", settings_changed_callable)
	var packs_changed_callable := Callable(self, "_on_service_packs_changed")
	if _settings_service.has_signal("packs_changed") and not _settings_service.is_connected("packs_changed", packs_changed_callable):
		_settings_service.connect("packs_changed", packs_changed_callable)

func _disconnect_service_signals() -> void:
	if _settings_service == null:
		return
	var settings_changed_callable := Callable(self, "_on_service_settings_changed")
	if _settings_service.has_signal("settings_changed") and _settings_service.is_connected("settings_changed", settings_changed_callable):
		_settings_service.disconnect("settings_changed", settings_changed_callable)
	var packs_changed_callable := Callable(self, "_on_service_packs_changed")
	if _settings_service.has_signal("packs_changed") and _settings_service.is_connected("packs_changed", packs_changed_callable):
		_settings_service.disconnect("packs_changed", packs_changed_callable)

func _rebuild() -> void:
	_resolve_service()
	_clear_children()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var setting_item := _get_setting_item()
	if setting_item == null:
		var missing := Label.new()
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missing.text = "Sea Shell setting '%s' is not available." % SettingId
		box.add_child(missing)
		return

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	header.add_child(title_box)

	var title := Label.new()
	title.text = setting_item.display_name() if not ShowItemId else "%s  [%s]" % [setting_item.display_name(), str(setting_item.get("ItemId"))]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(title)

	if ShowDescription:
		var description := Label.new()
		description.text = str(setting_item.get("Description"))
		description.modulate = Color(0.72, 0.75, 0.8)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_box.add_child(description)

	var control := _create_setting_control(setting_item)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.connect("value_submitted", Callable(self, "_on_control_value_submitted"))
	if control.has_signal("action_requested"):
		control.connect("action_requested", Callable(self, "_on_control_action_requested"))
	header.add_child(control)

	if ShowMetadataChips:
		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 8)
		box.add_child(footer)
		_add_chip(footer, str(setting_item.get("Kind")), _registry_color("item_kind", str(setting_item.get("Kind"))))
		_add_chip(footer, str(setting_item.get("ValueType")), _registry_color("value_type", str(setting_item.get("ValueType"))))
		if setting_item.has_method("get_primary_input_device"):
			var primary_device := str(setting_item.call("get_primary_input_device"))
			if not primary_device.is_empty():
				_add_chip(footer, "Device: %s" % primary_device, Color(0.22, 0.58, 0.66))
			var supported_devices := PackedStringArray(setting_item.call("get_supported_input_devices"))
			if supported_devices.size() > 1:
				_add_chip(footer, "Supports: %s" % ", ".join(Array(supported_devices)), Color(0.18, 0.43, 0.50))
		_add_chip(footer, str(setting_item.get("ApplyPolicy")), Color(0.2, 0.35, 0.45))
		for tag in setting_item.get("Tags"):
			_add_chip(footer, str(tag), _registry_color("tag", str(tag)))

	if ShowToolbarActions:
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		box.add_child(buttons)
		_add_toolbar_button(buttons, "Default", func() -> void:
			_run_service_action("reset_to_default", [str(setting_item.get("ItemId"))], true)
		)
		_add_toolbar_button(buttons, "Export MD", func() -> void:
			_run_service_action("export_markdown_for_item", [str(setting_item.get("ItemId"))], false)
		)
		_add_toolbar_button(buttons, "Import MD", func() -> void:
			_run_service_action("import_markdown_for_item", [str(setting_item.get("ItemId"))], true)
		)
		_add_toolbar_button(buttons, "Resource Wins", func() -> void:
			_run_service_action("resolve_markdown_conflict", [str(setting_item.get("ItemId")), "resource_wins"], true)
		)
		_add_toolbar_button(buttons, "Markdown Wins", func() -> void:
			_run_service_action("resolve_markdown_conflict", [str(setting_item.get("ItemId")), "markdown_wins"], true)
		)

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _get_setting_item() -> Resource:
	if _settings_service == null or not _settings_service.has_method("get_item"):
		return null
	return _settings_service.call("get_item", SettingId)

func _create_setting_control(setting_item: Resource) -> Control:
	var scene: PackedScene
	if _settings_service != null and _settings_service.has_method("get_registry"):
		var registry = _settings_service.call("get_registry")
		if registry != null and registry.has_method("get_control_scene"):
			scene = registry.call("get_control_scene", str(setting_item.get("ValueType")))
	if scene == null:
		scene = FallbackControlScene
	var control := scene.instantiate()
	if control.has_method("bind_item"):
		control.call("bind_item", setting_item, _settings_service)
	return control

func _add_chip(parent: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = color.lightened(0.05)
	parent.add_child(label)

func _registry_color(bucket: String, key: String) -> Color:
	if _settings_service == null or not _settings_service.has_method("get_registry"):
		return Color(0.32, 0.36, 0.42)
	var registry = _settings_service.call("get_registry")
	if registry != null and registry.has_method("get_color"):
		return registry.call("get_color", bucket, key)
	return Color(0.32, 0.36, 0.42)

func _add_toolbar_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _run_service_action(method_name: String, args: Array, refresh_after := false) -> void:
	var item_id := SettingId
	if _settings_service == null or not _settings_service.has_method(method_name):
		operation_completed.emit(item_id, {"ok": false, "error": "Settings service cannot run '%s'." % method_name})
		return
	var result: Dictionary = _settings_service.callv(method_name, args)
	operation_completed.emit(item_id, result)
	if refresh_after:
		_rebuild()

func _on_control_value_submitted(item_id: String, value: Variant) -> void:
	if _settings_service == null or not _settings_service.has_method("set_value"):
		operation_completed.emit(item_id, {"ok": false, "error": "Settings service unavailable."})
		return
	var result: Dictionary = _settings_service.call("set_value", item_id, value)
	operation_completed.emit(item_id, result)

func _on_control_action_requested(item_id: String) -> void:
	action_requested.emit(item_id)

func _on_service_settings_changed() -> void:
	_rebuild()

func _on_service_packs_changed() -> void:
	_rebuild()
