@tool
extends PanelContainer

const SeaShellSettingsScript := preload("res://addons/seashell_devtools/settings/SeaShellSettings.gd")
const BoundSettingFieldScene := preload("res://addons/seashell_devtools/settings/ui/SeaShellBoundSettingField.tscn")
const FallbackControlScene := preload("res://addons/seashell_devtools/settings/ui/SeaShellSettingControl.tscn")

const IMPORT_KEEP_INCOMING := "KeepIncoming"
const IMPORT_KEEP_MINE := "KeepMine"
const DEFAULT_EXPORT_PATH := "user://sea_shell_settings_profiles/settings_export.json"
const DEFAULT_IMPORT_PATH := "user://sea_shell_settings_profiles/settings_export.json"
const SEARCH_SUGGESTION_LIMIT := 10
const SEARCH_MODIFIER_ORDER := ["group", "device", "tag", "type", "kind", "sync", "modified", "id"]
const SEARCH_MODIFIER_LABELS := {
	"group": "Group",
	"device": "Device",
	"tag": "Tag",
	"type": "Type",
	"kind": "Kind",
	"sync": "Sync",
	"modified": "Modified",
	"id": "Item ID",
}
const SEARCH_MODIFIER_ALIASES := {
	"section": "group",
	"groups": "group",
	"path": "group",
	"input": "device",
	"inputs": "device",
	"input_device": "device",
	"input_devices": "device",
	"primary_device": "device",
	"supported_device": "device",
	"mouse": "device",
	"keyboard": "device",
	"controller": "device",
	"joystick": "device",
	"tags": "tag",
	"label": "tag",
	"value_type": "type",
	"kind": "kind",
	"state": "sync",
	"changed": "modified",
	"item": "id",
}
const SEARCH_SYNC_SUGGESTIONS := [
	{"value": "dirty", "label": "Dirty Or Conflicted"},
	{"value": "conflict", "label": "Conflicts Only"},
	{"value": "resource_dirty", "label": "Resource Dirty"},
	{"value": "markdown_dirty", "label": "Markdown Dirty"},
	{"value": "clean", "label": "Clean"},
]
const SEARCH_MODIFIED_SUGGESTIONS := [
	{"value": "definition", "label": "Definition Modified"},
	{"value": "value", "label": "Value Modified"},
]
const SEARCH_DEVICE_SUGGESTIONS := [
	{"value": "Cursor", "label": "Cursor", "aliases": ["mouse", "pointer", "trackpad", "touchpad"]},
	{"value": "Keyboard", "label": "Keyboard", "aliases": ["key", "keys", "text"]},
	{"value": "Gamepad", "label": "Gamepad", "aliases": ["controller", "joypad", "joystick"]},
	{"value": "Touch", "label": "Touch", "aliases": ["touchscreen", "screen"]},
	{"value": "Mixed", "label": "Mixed", "aliases": ["multi", "multiple"]},
	{"value": "None", "label": "None", "aliases": ["readonly", "read-only", "no input"]},
]
const SEARCH_CHIP_LABELS := {
	"text": "Text",
	"group": "Group",
	"device": "Device",
	"tag": "Tag",
	"type": "Type",
	"kind": "Kind",
	"sync": "Sync",
	"modified": "Modified",
	"id": "Item ID",
}
const SEARCH_CATEGORY_COLORS := {
	"Modifier": Color(0.47, 0.63, 0.95, 1.0),
	"Group": Color(0.31, 0.74, 0.55, 1.0),
	"Device": Color(0.35, 0.78, 0.86, 1.0),
	"Tag": Color(0.93, 0.64, 0.28, 1.0),
	"Type": Color(0.68, 0.56, 0.96, 1.0),
	"Kind": Color(0.96, 0.54, 0.72, 1.0),
	"Sync": Color(0.96, 0.44, 0.44, 1.0),
	"Modified": Color(0.92, 0.83, 0.38, 1.0),
	"Setting": Color(0.70, 0.76, 0.82, 1.0),
}
const SEARCH_SUGGESTION_BG := Color(0.10, 0.12, 0.16, 1.0)
const SEARCH_SUGGESTION_BG_SELECTED := Color(0.18, 0.24, 0.35, 1.0)
const SEARCH_SUGGESTION_BG_HOVER := Color(0.14, 0.18, 0.26, 1.0)
const SEARCH_HIGHLIGHT_COLOR := Color(1.0, 0.82, 0.40, 1.0)

signal action_requested(item_id: String)

var settings_service: Node
var _search_edit: LineEdit
var _search_chip_row: HFlowContainer
var _search_suggestion_panel: PanelContainer
var _search_suggestion_scroll: ScrollContainer
var _search_suggestion_container: VBoxContainer
var _tag_filter_edit: LineEdit
var _kind_filter: OptionButton
var _type_filter: OptionButton
var _modified_filter: OptionButton
var _sync_filter: OptionButton
var _view_mode_filter: OptionButton
var _group_tree: Tree
var _item_container: VBoxContainer
var _status_label: Label
var _selected_group := ""
var _visible_items: Array = []
var _search_suggestions: Array = []
var _search_suggestion_rows: Array = []
var _selected_search_suggestion_index := -1
var _search_context := {
	"entry_by_id": {},
	"item_entries": [],
	"groups": PackedStringArray(),
	"tags": PackedStringArray(),
	"types": PackedStringArray(),
	"input_devices": PackedStringArray(),
	"sync_status_by_id": {},
	"definition_modified_ids": {},
	"value_modified_ids": {},
}


func _ready() -> void:
	_build_ui()
	_resolve_service()
	refresh()


func set_settings_service(service: Node) -> void:
	settings_service = service
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if settings_service == null:
		return
	if settings_service.has_method("refresh"):
		settings_service.call("refresh")
	_populate_type_filter()
	_populate_group_tree()
	_refresh_search_context()
	_refresh_search_chips()
	_refresh_search_suggestions()
	_refresh_items()


func _build_ui() -> void:
	_clear_children()
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280.0
	split.add_child(left)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search settings or use modifiers like group:, device:, tag:, type:"
	_search_edit.text_changed.connect(_on_search_text_changed)
	_search_edit.gui_input.connect(_on_search_edit_gui_input)
	left.add_child(_search_edit)

	_search_chip_row = HFlowContainer.new()
	_search_chip_row.visible = false
	_search_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_search_chip_row)

	_search_suggestion_panel = PanelContainer.new()
	_search_suggestion_panel.visible = false
	left.add_child(_search_suggestion_panel)
	var suggestion_box := VBoxContainer.new()
	_search_suggestion_panel.add_child(suggestion_box)
	var suggestion_label := Label.new()
	suggestion_label.text = "Search suggestions"
	suggestion_box.add_child(suggestion_label)
	_search_suggestion_scroll = ScrollContainer.new()
	_search_suggestion_scroll.custom_minimum_size.y = 180.0
	suggestion_box.add_child(_search_suggestion_scroll)
	_search_suggestion_container = VBoxContainer.new()
	_search_suggestion_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_suggestion_scroll.add_child(_search_suggestion_container)

	_tag_filter_edit = LineEdit.new()
	_tag_filter_edit.placeholder_text = "Tags"
	_tag_filter_edit.text_changed.connect(func(_text: String) -> void: _refresh_items())
	left.add_child(_tag_filter_edit)

	_kind_filter = OptionButton.new()
	for label in ["Any kind", "Setting", "Info", "Poll"]:
		_kind_filter.add_item(label)
	_kind_filter.item_selected.connect(func(_index: int) -> void: _refresh_items())
	left.add_child(_kind_filter)

	_type_filter = OptionButton.new()
	_type_filter.item_selected.connect(func(_index: int) -> void: _refresh_items())
	left.add_child(_type_filter)

	_modified_filter = OptionButton.new()
	for label in ["Any modified date", "Definition modified", "Value modified"]:
		_modified_filter.add_item(label)
	_modified_filter.item_selected.connect(func(_index: int) -> void: _refresh_items())
	left.add_child(_modified_filter)

	_sync_filter = OptionButton.new()
	for label in ["Any sync state", "Dirty or conflicted", "Conflicts only"]:
		_sync_filter.add_item(label)
	_sync_filter.item_selected.connect(func(_index: int) -> void: _refresh_items())
	left.add_child(_sync_filter)

	_view_mode_filter = OptionButton.new()
	for label in ["Default order", "Batch by input device"]:
		_view_mode_filter.add_item(label)
	_view_mode_filter.item_selected.connect(func(_index: int) -> void: _refresh_items())
	left.add_child(_view_mode_filter)

	_group_tree = Tree.new()
	_group_tree.hide_root = true
	_group_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_group_tree.item_selected.connect(_on_group_selected)
	left.add_child(_group_tree)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var action_row := HBoxContainer.new()
	right.add_child(action_row)
	_add_toolbar_button(action_row, "Refresh", refresh)
	_add_toolbar_button(action_row, "Export MD", _export_markdown)
	_add_toolbar_button(action_row, "Conflicts", _detect_conflicts)
	_add_toolbar_button(action_row, "Export...", _open_export_dialog)
	_add_toolbar_button(action_row, "Import...", _open_import_dialog)
	_add_toolbar_button(action_row, "Presets...", _open_preset_manager)
	_add_toolbar_button(action_row, "Apply", _apply_staged)
	_add_toolbar_button(action_row, "Discard", _discard_staged)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	_item_container = VBoxContainer.new()
	_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_container)

	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)


func _resolve_service() -> void:
	if settings_service != null:
		return
	settings_service = get_node_or_null("/root/SeaShellSettings")
	if settings_service != null:
		return
	settings_service = SeaShellSettingsScript.new()
	settings_service.name = "SeaShellSettingsPreview"
	if settings_service.has_method("set_runtime_apply_enabled") and Engine.is_editor_hint():
		settings_service.call("set_runtime_apply_enabled", false)
	add_child(settings_service)


func _populate_type_filter() -> void:
	if _type_filter == null:
		return
	var previous := _type_filter.get_item_text(_type_filter.selected) if _type_filter.item_count > 0 and _type_filter.selected >= 0 else ""
	_type_filter.clear()
	_type_filter.add_item("Any type")
	if settings_service == null or not settings_service.has_method("get_items"):
		return
	var types := PackedStringArray()
	for item in settings_service.call("get_items"):
		var type_name := str(item.get("ValueType"))
		if not types.has(type_name):
			types.append(type_name)
	types.sort()
	for type_name in types:
		_type_filter.add_item(type_name)
	for index in range(_type_filter.item_count):
		if _type_filter.get_item_text(index) == previous:
			_type_filter.select(index)
			return
	_type_filter.select(0)


func _populate_group_tree() -> void:
	if _group_tree == null:
		return
	_group_tree.clear()
	var root := _group_tree.create_item()
	var all_item := _group_tree.create_item(root)
	all_item.set_text(0, "All")
	all_item.set_metadata(0, "")
	all_item.select(0)
	if settings_service == null or not settings_service.has_method("get_setting_groups"):
		return
	var groups = settings_service.call("get_setting_groups")
	var nodes := {"": root}
	for group_path in groups:
		var parts := str(group_path).split("/", false)
		var cursor := ""
		var parent: TreeItem = root
		for part in parts:
			cursor = part if cursor.is_empty() else cursor + "/" + part
			if not nodes.has(cursor):
				var child := _group_tree.create_item(parent)
				child.set_text(0, part)
				child.set_metadata(0, cursor)
				nodes[cursor] = child
			parent = nodes[cursor]
	for key in nodes.keys():
		if key != "":
			nodes[key].collapsed = false


func _refresh_items() -> void:
	if _item_container == null:
		return
	for child in _item_container.get_children():
		_item_container.remove_child(child)
		child.queue_free()
	_visible_items.clear()
	if settings_service == null or not settings_service.has_method("query_items"):
		return
	var parsed_search := _parse_search_query(_search_edit.text)
	var filters := _build_filters()
	_visible_items = settings_service.call("query_items", "", filters)
	_visible_items = _apply_search_query_filters(_visible_items, parsed_search)
	_visible_items = _apply_sync_filter(_visible_items)
	var group_by_input_device := _view_mode_filter != null and _view_mode_filter.selected == 1
	var view_data := {
		"items": _visible_items,
		"batches": [{"key": "all", "label": "", "items": _visible_items, "count": _visible_items.size()}],
		"count": _visible_items.size(),
	}
	if settings_service.has_method("build_item_view"):
		view_data = settings_service.call("build_item_view", _visible_items, {"group_by_input_device": group_by_input_device})
	_visible_items = Array(view_data.get("items", _visible_items))
	var batches: Array = view_data.get("batches", [])
	for batch_variant in batches:
		var batch: Dictionary = batch_variant
		if group_by_input_device:
			_add_input_device_batch_header(batch)
		for item in Array(batch.get("items", [])):
			_add_item_row(item)
	var count := int(view_data.get("count", _visible_items.size()))
	if group_by_input_device:
		_status_label.text = "%d item%s in %d input batch%s" % [count, "" if count == 1 else "s", batches.size(), "" if batches.size() == 1 else "es"]
	else:
		_status_label.text = "%d item%s" % [count, "" if count == 1 else "s"]


func _build_filters() -> Dictionary:
	var filters := {}
	if not _selected_group.is_empty():
		filters["group_path"] = _selected_group
	var tags := PackedStringArray()
	for raw_tag in _tag_filter_edit.text.split(",", false):
		var tag := raw_tag.strip_edges()
		if not tag.is_empty():
			tags.append(tag)
	if not tags.is_empty():
		filters["tags"] = tags
	if _kind_filter.selected > 0:
		filters["kind"] = _kind_filter.get_item_text(_kind_filter.selected)
	if _type_filter.item_count > 0 and _type_filter.selected > 0:
		filters["value_type"] = _type_filter.get_item_text(_type_filter.selected)
	if _modified_filter.selected == 1:
		filters["definition_modified_after_unix"] = 0
	elif _modified_filter.selected == 2:
		filters["value_modified_after_unix"] = 0
	return filters


func _on_search_text_changed(_text: String) -> void:
	_refresh_search_chips()
	_refresh_search_suggestions()
	_refresh_items()


func _on_search_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if not _search_suggestion_panel.visible or _search_suggestions.is_empty():
		return
	match key_event.keycode:
		KEY_DOWN:
			_move_search_suggestion_selection(1)
			accept_event()
		KEY_UP:
			_move_search_suggestion_selection(-1)
			accept_event()
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			if _apply_selected_search_suggestion():
				accept_event()
		KEY_ESCAPE:
			_hide_search_suggestions()
			accept_event()


func _refresh_search_suggestions() -> void:
	if _search_edit == null or _search_suggestion_container == null:
		return
	_clear_search_suggestion_rows()
	_search_suggestions.clear()
	_selected_search_suggestion_index = -1
	if _search_edit.text.strip_edges().is_empty():
		_hide_search_suggestions()
		return
	_search_suggestions = _build_search_suggestions(_search_edit.text)
	if _search_suggestions.is_empty():
		_hide_search_suggestions()
		return
	_search_suggestion_panel.visible = true
	for index in range(_search_suggestions.size()):
		var suggestion: Dictionary = _search_suggestions[index]
		var row := _create_search_suggestion_row(index, suggestion)
		_search_suggestion_rows.append(row)
		_search_suggestion_container.add_child(row)
	_set_selected_search_suggestion_index(0)


func _hide_search_suggestions() -> void:
	if _search_suggestion_panel != null:
		_search_suggestion_panel.visible = false
	_selected_search_suggestion_index = -1


func _move_search_suggestion_selection(delta: int) -> void:
	if _search_suggestions.is_empty():
		return
	var index := _selected_search_suggestion_index
	if index < 0:
		index = 0
	index = wrapi(index + delta, 0, _search_suggestions.size())
	_set_selected_search_suggestion_index(index)


func _apply_selected_search_suggestion() -> bool:
	if _selected_search_suggestion_index < 0:
		return false
	return _apply_search_suggestion(_selected_search_suggestion_index)


func _on_search_suggestion_selected(_index: int) -> void:
	pass


func _on_search_suggestion_activated(index: int) -> void:
	_apply_search_suggestion(index)


func _on_search_suggestion_clicked(index: int, _position: Vector2, _mouse_button_index: int) -> void:
	_apply_search_suggestion(index)


func _apply_search_suggestion(index: int) -> bool:
	if index < 0 or index >= _search_suggestions.size():
		return false
	var suggestion: Dictionary = _search_suggestions[index]
	var replacement := str(suggestion.get("insert_text", ""))
	if replacement.is_empty():
		return false
	var text := _search_edit.text
	var active_fragment := _get_active_search_fragment(text)
	var new_text := ""
	if active_fragment.is_empty():
		new_text = text
		if not new_text.is_empty() and not new_text.ends_with(" "):
			new_text += " "
		new_text += replacement
	else:
		new_text = text.substr(0, text.length() - active_fragment.length()) + replacement
	if bool(suggestion.get("append_space", true)) and not new_text.ends_with(" "):
		new_text += " "
	_search_edit.text = new_text
	_search_edit.caret_column = _search_edit.text.length()
	_refresh_search_chips()
	_refresh_search_suggestions()
	_refresh_items()
	_search_edit.grab_focus()
	return true


func _build_search_suggestions(query: String) -> Array:
	if Array(_search_context.get("item_entries", [])).is_empty() and settings_service != null:
		_refresh_search_context()
	var parsed := _parse_search_query(query)
	var active_fragment := str(parsed.get("active_fragment", ""))
	if active_fragment.strip_edges().is_empty():
		return []
	var active_token := _parse_search_fragment(active_fragment)
	var is_negated := bool(active_token.get("negated", false))
	var active_modifier := str(active_token.get("modifier", ""))
	var active_value := str(active_token.get("value", "")).strip_edges().to_lower()
	var suggestions: Array = []
	if not active_modifier.is_empty():
		match active_modifier:
			"group":
				suggestions.append_array(_build_group_search_suggestions(active_value, is_negated))
			"device":
				suggestions.append_array(_build_device_search_suggestions(active_value, is_negated))
			"tag":
				suggestions.append_array(_build_tag_search_suggestions(active_value, is_negated))
			"type":
				suggestions.append_array(_build_type_search_suggestions(active_value, is_negated))
			"kind":
				suggestions.append_array(_build_kind_search_suggestions(active_value, is_negated))
			"sync":
				suggestions.append_array(_build_sync_search_suggestions(active_value, is_negated))
			"modified":
				suggestions.append_array(_build_modified_search_suggestions(active_value, is_negated))
			"id":
				suggestions.append_array(_build_item_id_search_suggestions(active_value, is_negated))
	else:
		suggestions.append_array(_build_modifier_search_suggestions(active_value, is_negated))
		suggestions.append_array(_build_group_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_device_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_tag_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_type_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_kind_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_sync_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_modified_search_suggestions(active_value, is_negated, true))
		suggestions.append_array(_build_item_id_search_suggestions(active_value, is_negated, true))
	var deduped := []
	var seen := {}
	for suggestion_variant in suggestions:
		var suggestion: Dictionary = suggestion_variant
		var key := "%s|%s" % [str(suggestion.get("category", "")), str(suggestion.get("insert_text", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		deduped.append(suggestion)
		if deduped.size() >= SEARCH_SUGGESTION_LIMIT:
			break
	return deduped


func _build_modifier_search_suggestions(fragment: String, negated := false) -> Array:
	var suggestions: Array = []
	for modifier in SEARCH_MODIFIER_ORDER:
		var label := "%s:" % modifier
		if fragment.is_empty() or label.to_lower().contains(fragment):
			var insert_text := ("-" if negated else "") + label
			suggestions.append(_make_search_suggestion(insert_text, "Modifier", insert_text, fragment, false))
	return suggestions


func _build_group_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for group_path_variant in _search_context.get("groups", PackedStringArray()):
		var group_path := str(group_path_variant)
		var typed_group := str(group_path)
		if not fragment.is_empty() and not typed_group.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(typed_group, "Group", _build_modifier_token("group", typed_group, negated), fragment))
		if suggestions.size() >= SEARCH_SUGGESTION_LIMIT:
			break
	return suggestions


func _build_device_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	var available := {}
	for device_variant in _search_context.get("input_devices", PackedStringArray()):
		available[str(device_variant)] = true
	for entry_variant in SEARCH_DEVICE_SUGGESTIONS:
		var entry: Dictionary = entry_variant
		var value := str(entry.get("value", ""))
		if not available.is_empty() and not available.has(value):
			continue
		var label := str(entry.get("label", value))
		var aliases: Array = entry.get("aliases", [])
		if not fragment.is_empty() and not value.to_lower().contains(fragment) and not label.to_lower().contains(fragment) and not _device_aliases_match(aliases, fragment):
			continue
		suggestions.append(_make_search_suggestion(label, "Device", _build_modifier_token("device", value, negated), fragment))
	return suggestions


func _device_aliases_match(aliases: Array, fragment: String) -> bool:
	var normalized_fragment := fragment.strip_edges().to_lower()
	for alias in aliases:
		if String(alias).to_lower().contains(normalized_fragment):
			return true
	return false


func _build_tag_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for tag_variant in _search_context.get("tags", PackedStringArray()):
		var tag := str(tag_variant)
		var typed_tag := str(tag)
		if not fragment.is_empty() and not typed_tag.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(typed_tag, "Tag", _build_modifier_token("tag", typed_tag, negated), fragment))
		if suggestions.size() >= SEARCH_SUGGESTION_LIMIT:
			break
	return suggestions


func _build_type_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for value_variant in _search_context.get("types", PackedStringArray()):
		var value := str(value_variant)
		if not fragment.is_empty() and not value.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(value, "Type", _build_modifier_token("type", value, negated), fragment))
	return suggestions


func _build_kind_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for value in ["Setting", "Info", "Poll"]:
		if not fragment.is_empty() and not value.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(value, "Kind", _build_modifier_token("kind", value, negated), fragment))
	return suggestions


func _build_sync_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for entry_variant in SEARCH_SYNC_SUGGESTIONS:
		var entry: Dictionary = entry_variant
		var value := str(entry.get("value", ""))
		var label := str(entry.get("label", value))
		if not fragment.is_empty() and not value.to_lower().contains(fragment) and not label.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(label, "Sync", _build_modifier_token("sync", value, negated), fragment))
	return suggestions


func _build_modified_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for entry_variant in SEARCH_MODIFIED_SUGGESTIONS:
		var entry: Dictionary = entry_variant
		var value := str(entry.get("value", ""))
		var label := str(entry.get("label", value))
		if not fragment.is_empty() and not value.to_lower().contains(fragment) and not label.to_lower().contains(fragment):
			continue
		suggestions.append(_make_search_suggestion(label, "Modified", _build_modifier_token("modified", value, negated), fragment))
	return suggestions


func _build_item_id_search_suggestions(fragment: String, negated := false, _direct := false) -> Array:
	var suggestions: Array = []
	for entry_variant in _search_context.get("item_entries", []):
		var entry: Dictionary = entry_variant
		if not _search_entry_matches_suggestion(entry, fragment):
			continue
		var item_id := str(entry.get("id", ""))
		var display_name := str(entry.get("display_name", item_id))
		suggestions.append(_make_search_suggestion(
			"%s  [%s]" % [display_name, item_id],
			"Setting",
			_build_modifier_token("id", item_id, negated),
			fragment
		))
		if suggestions.size() >= SEARCH_SUGGESTION_LIMIT:
			break
	return suggestions


func _make_search_suggestion(label: String, category: String, insert_text: String, fragment := "", append_space := true) -> Dictionary:
	return {
		"label": label,
		"category": category,
		"insert_text": insert_text,
		"append_space": append_space,
		"match_terms": PackedStringArray([] if str(fragment).strip_edges().is_empty() else [str(fragment)]),
	}


func _build_modifier_token(modifier: String, value: String, negated := false) -> String:
	var prefix := "-" if negated else ""
	return "%s%s:%s" % [prefix, modifier, _quote_search_value(value, true)]


func _parse_search_query(query: String) -> Dictionary:
	var fragments := _split_search_fragments(query)
	var tokens: Array = []
	var positive := _empty_search_term_map()
	var negative := _empty_search_term_map()
	for fragment_variant in fragments.get("fragments", []):
		var fragment := str(fragment_variant)
		var token := _parse_search_fragment(fragment)
		tokens.append(token)
		var value := str(token.get("value", "")).strip_edges()
		if value.is_empty():
			continue
		var target := negative if bool(token.get("negated", false)) else positive
		if str(token.get("modifier", "")).is_empty():
			_append_search_term(target, "free_text", value)
			continue
		match str(token.get("modifier", "")):
			"group":
				_append_search_term(target, "groups", value)
			"device":
				_append_search_term(target, "devices", value)
			"tag":
				_append_search_term(target, "tags", value)
			"id":
				_append_search_term(target, "ids", value)
			"kind":
				_append_search_term(target, "kinds", value)
			"type":
				_append_search_term(target, "types", value)
			"sync":
				_append_search_term(target, "sync", value)
			"modified":
				_append_search_term(target, "modified", value)
	return {
		"tokens": tokens,
		"positive": positive,
		"negative": negative,
		"free_text": positive.get("free_text", PackedStringArray()),
		"excluded_free_text": negative.get("free_text", PackedStringArray()),
		"groups": positive.get("groups", PackedStringArray()),
		"excluded_groups": negative.get("groups", PackedStringArray()),
		"devices": positive.get("devices", PackedStringArray()),
		"excluded_devices": negative.get("devices", PackedStringArray()),
		"tags": positive.get("tags", PackedStringArray()),
		"excluded_tags": negative.get("tags", PackedStringArray()),
		"ids": positive.get("ids", PackedStringArray()),
		"excluded_ids": negative.get("ids", PackedStringArray()),
		"kinds": positive.get("kinds", PackedStringArray()),
		"excluded_kinds": negative.get("kinds", PackedStringArray()),
		"types": positive.get("types", PackedStringArray()),
		"excluded_types": negative.get("types", PackedStringArray()),
		"sync": positive.get("sync", PackedStringArray()),
		"excluded_sync": negative.get("sync", PackedStringArray()),
		"modified": positive.get("modified", PackedStringArray()),
		"excluded_modified": negative.get("modified", PackedStringArray()),
		"active_fragment": str(fragments.get("active_fragment", "")),
	}


func _split_search_fragments(query: String) -> Dictionary:
	var fragments: Array = []
	var current := ""
	var in_quotes := false
	for index in range(query.length()):
		var character := query.substr(index, 1)
		if character == "\"":
			in_quotes = not in_quotes
			current += character
		elif character == " " and not in_quotes:
			if not current.is_empty():
				fragments.append(current)
				current = ""
		else:
			current += character
	var trailing_space := query.ends_with(" ")
	if not current.is_empty():
		fragments.append(current)
	return {
		"fragments": fragments,
		"active_fragment": "" if trailing_space else current,
	}


func _get_active_search_fragment(query: String) -> String:
	return str(_split_search_fragments(query).get("active_fragment", ""))


func _parse_search_fragment(fragment: String) -> Dictionary:
	var negated := fragment.begins_with("-")
	var body := fragment.substr(1) if negated else fragment
	var token := {
		"raw": fragment,
		"body": body,
		"modifier": "",
		"value": _strip_search_quotes(body),
		"negated": negated,
	}
	var separator_index := body.find(":")
	if separator_index <= 0:
		return token
	var modifier := _normalize_search_modifier(body.substr(0, separator_index))
	if modifier.is_empty():
		return token
	token["modifier"] = modifier
	token["value"] = _strip_search_quotes(body.substr(separator_index + 1))
	return token


func _normalize_search_modifier(modifier: String) -> String:
	var normalized := modifier.strip_edges().to_lower()
	if SEARCH_MODIFIER_LABELS.has(normalized):
		return normalized
	return str(SEARCH_MODIFIER_ALIASES.get(normalized, ""))


func _normalize_input_device(device: String) -> String:
	var normalized := device.strip_edges()
	if normalized.is_empty():
		return ""
	match normalized.to_lower():
		"auto", "infer", "inferred", "default":
			return ""
		"cursor", "pointer", "mouse", "trackpad", "touchpad":
			return "Cursor"
		"keyboard", "key", "keys", "text":
			return "Keyboard"
		"gamepad", "controller", "joypad", "joystick":
			return "Gamepad"
		"touch", "touchscreen", "screen":
			return "Touch"
		"none", "readonly", "read-only", "no input", "no_input":
			return "None"
		"mixed", "multi", "multiple":
			return "Mixed"
		_:
			for entry_variant in SEARCH_DEVICE_SUGGESTIONS:
				var entry: Dictionary = entry_variant
				var value := str(entry.get("value", ""))
				if normalized.nocasecmp_to(value) == 0:
					return value
	return ""


func _normalize_input_devices(devices: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	var raw_values: Array = []
	match typeof(devices):
		TYPE_PACKED_STRING_ARRAY:
			raw_values = Array(devices)
		TYPE_ARRAY:
			raw_values = devices
		TYPE_STRING:
			raw_values = String(devices).split(",", false)
		_:
			raw_values = []
	for raw_device in raw_values:
		var device := _normalize_input_device(str(raw_device))
		if not device.is_empty() and not result.has(device):
			result.append(device)
	return result


func _item_primary_input_device(item: Resource) -> String:
	if item != null and item.has_method("get_primary_input_device"):
		return _normalize_input_device(str(item.call("get_primary_input_device")))
	if item != null:
		return _normalize_input_device(str(item.get("PrimaryInputDevice")))
	return ""


func _item_supported_input_devices(item: Resource) -> PackedStringArray:
	if item != null and item.has_method("get_supported_input_devices"):
		return _normalize_input_devices(item.call("get_supported_input_devices"))
	if item != null:
		return _normalize_input_devices(item.get("SupportedInputDevices"))
	return PackedStringArray()


func _strip_search_quotes(value: String) -> String:
	var text := value.strip_edges()
	if text.begins_with("\""):
		text = text.substr(1)
		if text.ends_with("\""):
			text = text.substr(0, text.length() - 1)
	return text.replace("\\\"", "\"")


func _empty_search_term_map() -> Dictionary:
	return {
		"free_text": PackedStringArray(),
		"groups": PackedStringArray(),
		"devices": PackedStringArray(),
		"tags": PackedStringArray(),
		"ids": PackedStringArray(),
		"kinds": PackedStringArray(),
		"types": PackedStringArray(),
		"sync": PackedStringArray(),
		"modified": PackedStringArray(),
	}


func _append_search_term(bucket: Dictionary, key: String, value: String) -> void:
	var values: PackedStringArray = bucket.get(key, PackedStringArray())
	values.append(value)
	bucket[key] = values


func _build_search_chip_data(parsed: Dictionary) -> Array:
	var chips: Array = []
	var tokens: Array = parsed.get("tokens", [])
	for token_index in range(tokens.size()):
		var token: Dictionary = tokens[token_index]
		var value := str(token.get("value", "")).strip_edges()
		if value.is_empty():
			continue
		var modifier := str(token.get("modifier", ""))
		var label_key := modifier if not modifier.is_empty() else "text"
		var label := str(SEARCH_CHIP_LABELS.get(label_key, label_key.capitalize()))
		chips.append({
			"token_index": token_index,
			"modifier": modifier,
			"label": label,
			"value": value,
			"negated": bool(token.get("negated", false)),
			"serialized": _serialize_search_token(token),
		})
	return chips


func _serialize_search_token(token: Dictionary) -> String:
	var value := str(token.get("value", "")).strip_edges()
	if value.is_empty():
		return ""
	var modifier := str(token.get("modifier", ""))
	var negated := bool(token.get("negated", false))
	if modifier.is_empty():
		return ("-" if negated else "") + _quote_search_value(value)
	return _build_modifier_token(modifier, value, negated)


func _quote_search_value(value: String, quote_paths := false) -> String:
	var trimmed := value.strip_edges()
	var escaped := trimmed.replace("\"", "\\\"")
	if trimmed.contains(" ") or (quote_paths and trimmed.contains("/")):
		return "\"%s\"" % escaped
	return escaped


func _refresh_search_chips() -> void:
	if _search_chip_row == null or _search_edit == null:
		return
	for child in _search_chip_row.get_children():
		_search_chip_row.remove_child(child)
		child.queue_free()
	var chips := _build_search_chip_data(_parse_search_query(_search_edit.text))
	_search_chip_row.visible = not chips.is_empty()
	for chip_variant in chips:
		var chip: Dictionary = chip_variant
		_search_chip_row.add_child(_create_search_chip(chip))


func _create_search_chip(chip: Dictionary) -> Control:
	var token_index := int(chip.get("token_index", -1))
	var negated := bool(chip.get("negated", false))
	var modifier := str(chip.get("modifier", ""))
	var label := str(chip.get("label", "Token"))
	var value := str(chip.get("value", ""))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_search_chip_style(_color_for_search_chip(modifier, negated)))
	var box := HBoxContainer.new()
	panel.add_child(box)
	var text_label := Label.new()
	text_label.text = "%s%s: %s" % ["-" if negated else "", label, value]
	box.add_child(text_label)
	var remove_button := Button.new()
	remove_button.text = "x"
	remove_button.flat = true
	remove_button.tooltip_text = "Remove this search token"
	remove_button.pressed.connect(func() -> void:
		_remove_search_token(token_index)
	)
	box.add_child(remove_button)
	return panel


func _remove_search_token(token_index: int) -> void:
	if _search_edit == null:
		return
	var parsed := _parse_search_query(_search_edit.text)
	var tokens: Array = parsed.get("tokens", [])
	if token_index < 0 or token_index >= tokens.size():
		return
	tokens.remove_at(token_index)
	var fragments: Array = []
	for token_variant in tokens:
		var token: Dictionary = token_variant
		var serialized := _serialize_search_token(token)
		if serialized.is_empty():
			continue
		fragments.append(serialized)
	_search_edit.text = _join_search_fragments(fragments)
	_search_edit.caret_column = _search_edit.text.length()
	_refresh_search_chips()
	_refresh_search_suggestions()
	_refresh_items()
	_search_edit.grab_focus()


func _join_search_fragments(fragments: Array) -> String:
	var result := ""
	for fragment_variant in fragments:
		var fragment := str(fragment_variant).strip_edges()
		if fragment.is_empty():
			continue
		if not result.is_empty():
			result += " "
		result += fragment
	return result


func _clear_search_suggestion_rows() -> void:
	if _search_suggestion_container == null:
		return
	for child in _search_suggestion_container.get_children():
		_search_suggestion_container.remove_child(child)
		child.queue_free()
	_search_suggestion_rows.clear()


func _create_search_suggestion_row(index: int, suggestion: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size.y = 36.0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_entered.connect(func() -> void:
		_set_selected_search_suggestion_index(index)
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_set_selected_search_suggestion_index(index)
				_apply_search_suggestion(index)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	var title := RichTextLabel.new()
	title.scroll_active = false
	title.fit_content = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_search_highlight_label(title, str(suggestion.get("label", "")), Array(suggestion.get("match_terms", PackedStringArray())))
	content.add_child(title)
	var category_label := Label.new()
	category_label.text = str(suggestion.get("category", ""))
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_label.add_theme_color_override("font_color", _color_for_search_category(category_label.text))
	content.add_child(category_label)
	row.tooltip_text = str(suggestion.get("insert_text", ""))
	return row


func _set_selected_search_suggestion_index(index: int) -> void:
	if _search_suggestions.is_empty():
		_selected_search_suggestion_index = -1
		return
	_selected_search_suggestion_index = clampi(index, 0, _search_suggestions.size() - 1)
	_refresh_search_suggestion_row_styles()
	if _search_suggestion_scroll != null and _selected_search_suggestion_index < _search_suggestion_rows.size():
		_search_suggestion_scroll.ensure_control_visible(_search_suggestion_rows[_selected_search_suggestion_index])


func _refresh_search_suggestion_row_styles() -> void:
	for index in range(_search_suggestion_rows.size()):
		var row = _search_suggestion_rows[index]
		var suggestion: Dictionary = _search_suggestions[index]
		var selected := index == _selected_search_suggestion_index
		row.add_theme_stylebox_override("panel", _build_search_suggestion_style(str(suggestion.get("category", "")), selected))


func _build_search_suggestion_style(category: String, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SEARCH_SUGGESTION_BG_SELECTED if selected else SEARCH_SUGGESTION_BG
	style.border_width_left = 3
	style.border_color = _color_for_search_category(category)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _build_search_chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _fill_search_highlight_label(label: RichTextLabel, text: String, match_terms: Array) -> void:
	label.clear()
	var match_term := _find_search_highlight_term(text, match_terms)
	if match_term.is_empty():
		label.add_text(text)
		return
	var normalized_text := text.to_lower()
	var normalized_term := match_term.to_lower()
	var cursor := 0
	while true:
		var found := normalized_text.find(normalized_term, cursor)
		if found < 0:
			break
		if found > cursor:
			label.add_text(text.substr(cursor, found - cursor))
		label.push_color(SEARCH_HIGHLIGHT_COLOR)
		label.add_text(text.substr(found, normalized_term.length()))
		label.pop()
		cursor = found + normalized_term.length()
	if cursor < text.length():
		label.add_text(text.substr(cursor))


func _find_search_highlight_term(text: String, match_terms: Array) -> String:
	var normalized_text := text.to_lower()
	for term_variant in match_terms:
		var term := str(term_variant).strip_edges()
		if term.is_empty():
			continue
		if normalized_text.contains(term.to_lower()):
			return term
	return ""


func _color_for_search_category(category: String) -> Color:
	return SEARCH_CATEGORY_COLORS.get(category, Color(0.65, 0.70, 0.78, 1.0))


func _color_for_search_chip(modifier: String, negated: bool) -> Color:
	var category := "Setting"
	match modifier:
		"group":
			category = "Group"
		"device":
			category = "Device"
		"tag":
			category = "Tag"
		"type":
			category = "Type"
		"kind":
			category = "Kind"
		"sync":
			category = "Sync"
		"modified":
			category = "Modified"
		"id":
			category = "Setting"
		_:
			category = "Modifier"
	var color := _color_for_search_category(category)
	return color.lerp(Color(0.95, 0.34, 0.34, 1.0), 0.35) if negated else color


func _refresh_search_context() -> void:
	_search_context = {
		"entry_by_id": {},
		"item_entries": [],
		"groups": PackedStringArray(),
		"tags": PackedStringArray(),
		"types": PackedStringArray(),
		"input_devices": PackedStringArray(),
		"sync_status_by_id": {},
		"definition_modified_ids": {},
		"value_modified_ids": {},
	}
	if settings_service == null or not settings_service.has_method("get_items"):
		return
	var item_entries: Array = []
	var entry_by_id := {}
	var groups := PackedStringArray()
	var tags := PackedStringArray()
	var types := PackedStringArray()
	var input_devices := PackedStringArray()
	if settings_service.has_method("get_input_devices"):
		for device_variant in settings_service.call("get_input_devices"):
			var device := str(device_variant)
			if not device.is_empty() and not input_devices.has(device):
				input_devices.append(device)
	for item in settings_service.call("get_items"):
		var entry := _build_search_context_entry(item)
		item_entries.append(entry)
		entry_by_id[str(entry.get("id", ""))] = entry
		var group_path := str(entry.get("group_path", ""))
		if not group_path.is_empty() and not groups.has(group_path):
			groups.append(group_path)
		var value_type := str(entry.get("value_type", ""))
		if not value_type.is_empty() and not types.has(value_type):
			types.append(value_type)
		var primary_input_device := str(entry.get("primary_input_device", ""))
		if not primary_input_device.is_empty() and not input_devices.has(primary_input_device):
			input_devices.append(primary_input_device)
		for device_variant in entry.get("supported_input_devices", PackedStringArray()):
			var supported_device := str(device_variant)
			if not supported_device.is_empty() and not input_devices.has(supported_device):
				input_devices.append(supported_device)
		for tag_variant in entry.get("tags", PackedStringArray()):
			var tag := str(tag_variant)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	groups.sort()
	tags.sort()
	types.sort()
	var sync_status_by_id := {}
	if settings_service.has_method("detect_markdown_sync"):
		var sync_result: Dictionary = settings_service.call("detect_markdown_sync")
		for status_variant in sync_result.get("statuses", []):
			var status: Dictionary = status_variant
			sync_status_by_id[str(status.get("id", ""))] = str(status.get("status", ""))
	var definition_modified_ids := {}
	var value_modified_ids := {}
	if settings_service.has_method("search_items"):
		for candidate in settings_service.call("search_items", "", {"definition_modified_after_unix": 0, "include_hidden": true}):
			definition_modified_ids[str(candidate.get("ItemId"))] = true
		for candidate in settings_service.call("search_items", "", {"value_modified_after_unix": 0, "include_hidden": true}):
			value_modified_ids[str(candidate.get("ItemId"))] = true
	for index in range(item_entries.size()):
		var entry: Dictionary = item_entries[index]
		var entry_id := str(entry.get("id", ""))
		entry["sync_status"] = str(sync_status_by_id.get(entry_id, ""))
		entry["definition_modified"] = bool(definition_modified_ids.get(entry_id, false))
		entry["value_modified"] = bool(value_modified_ids.get(entry_id, false))
		item_entries[index] = entry
		entry_by_id[entry_id] = entry
	_search_context = {
		"entry_by_id": entry_by_id,
		"item_entries": item_entries,
		"groups": groups,
		"tags": tags,
		"types": types,
		"input_devices": input_devices,
		"sync_status_by_id": sync_status_by_id,
		"definition_modified_ids": definition_modified_ids,
		"value_modified_ids": value_modified_ids,
	}


func _build_search_context_entry(item: Resource) -> Dictionary:
	var item_id := str(item.get("ItemId"))
	var display_name := str(item.display_name())
	var group_path := str(item.get("GroupPath"))
	var kind := str(item.get("Kind"))
	var value_type := str(item.get("ValueType"))
	var primary_input_device := _item_primary_input_device(item)
	var supported_input_devices := _item_supported_input_devices(item)
	var supported_input_devices_lc: Array = []
	for device_variant in supported_input_devices:
		supported_input_devices_lc.append(str(device_variant).to_lower())
	var tags := PackedStringArray()
	var tags_lc: Array = []
	for tag_variant in item.get("Tags"):
		var tag := str(tag_variant)
		tags.append(tag)
		tags_lc.append(tag.to_lower())
	var aliases := PackedStringArray()
	var aliases_lc: Array = []
	for alias_variant in item.get("Aliases"):
		var alias := str(alias_variant)
		aliases.append(alias)
		aliases_lc.append(alias.to_lower())
	return {
		"item": item,
		"id": item_id,
		"id_lc": item_id.to_lower(),
		"display_name": display_name,
		"display_name_lc": display_name.to_lower(),
		"description_lc": str(item.get("Description")).to_lower(),
		"group_path": group_path,
		"group_path_lc": group_path.to_lower(),
		"kind": kind,
		"kind_lc": kind.to_lower(),
		"value_type": value_type,
		"value_type_lc": value_type.to_lower(),
		"primary_input_device": primary_input_device,
		"primary_input_device_lc": primary_input_device.to_lower(),
		"supported_input_devices": supported_input_devices,
		"supported_input_devices_lc": supported_input_devices_lc,
		"input_device_note_lc": str(item.get("InputDeviceNote")).to_lower(),
		"tags": tags,
		"tags_lc": tags_lc,
		"aliases": aliases,
		"aliases_lc": aliases_lc,
		"sync_status": "",
		"definition_modified": false,
		"value_modified": false,
	}


func _search_entry_matches_suggestion(entry: Dictionary, fragment: String) -> bool:
	if fragment.is_empty():
		return true
	var normalized_fragment := fragment.to_lower()
	if not _normalize_input_device(fragment).is_empty() and _search_device_matches(entry, fragment):
		return true
	if str(entry.get("id_lc", "")).contains(normalized_fragment):
		return true
	if str(entry.get("display_name_lc", "")).contains(normalized_fragment):
		return true
	if str(entry.get("description_lc", "")).contains(normalized_fragment):
		return true
	if str(entry.get("primary_input_device_lc", "")).contains(normalized_fragment):
		return true
	if str(entry.get("input_device_note_lc", "")).contains(normalized_fragment):
		return true
	for device_variant in entry.get("supported_input_devices_lc", []):
		if str(device_variant).contains(normalized_fragment):
			return true
	for alias_variant in entry.get("aliases_lc", []):
		if str(alias_variant).contains(normalized_fragment):
			return true
	for tag_variant in entry.get("tags_lc", []):
		if str(tag_variant).contains(normalized_fragment):
			return true
	return false


func _apply_search_query_filters(items: Array, parsed: Dictionary) -> Array:
	var filtered: Array = []
	for item in items:
		if not _item_matches_search_query(item, parsed):
			continue
		filtered.append(item)
	return filtered


func _refresh_search_filter_caches(parsed: Dictionary) -> void:
	_refresh_search_context()


func _item_matches_search_query(item: Resource, parsed: Dictionary) -> bool:
	var item_id := str(item.get("ItemId"))
	var entry: Dictionary = _search_context.get("entry_by_id", {}).get(item_id, {})
	if entry.is_empty():
		entry = _build_search_context_entry(item)
	if not _matches_free_text_terms(entry, parsed.get("free_text", PackedStringArray()), parsed.get("excluded_free_text", PackedStringArray())):
		return false
	if not _matches_any_search_value(str(entry.get("group_path_lc", "")), parsed.get("groups", PackedStringArray()), parsed.get("excluded_groups", PackedStringArray()), true):
		return false
	if not _matches_any_search_tag(entry.get("tags_lc", []), parsed.get("tags", PackedStringArray()), parsed.get("excluded_tags", PackedStringArray())):
		return false
	if not _matches_any_search_value(str(entry.get("id_lc", "")), parsed.get("ids", PackedStringArray()), parsed.get("excluded_ids", PackedStringArray())):
		return false
	if not _matches_any_search_value(str(entry.get("kind_lc", "")), parsed.get("kinds", PackedStringArray()), parsed.get("excluded_kinds", PackedStringArray())):
		return false
	if not _matches_any_search_value(str(entry.get("value_type_lc", "")), parsed.get("types", PackedStringArray()), parsed.get("excluded_types", PackedStringArray())):
		return false
	if not _matches_device_terms(entry, parsed.get("devices", PackedStringArray()), parsed.get("excluded_devices", PackedStringArray())):
		return false
	if not _matches_sync_terms(entry, parsed.get("sync", PackedStringArray()), parsed.get("excluded_sync", PackedStringArray())):
		return false
	if not _matches_modified_terms(entry, parsed.get("modified", PackedStringArray()), parsed.get("excluded_modified", PackedStringArray())):
		return false
	return true


func _matches_free_text_terms(entry: Dictionary, include_terms: PackedStringArray, exclude_terms: PackedStringArray) -> bool:
	for term in exclude_terms:
		if _entry_matches_free_text(entry, str(term)):
			return false
	for term in include_terms:
		if not _entry_matches_free_text(entry, str(term)):
			return false
	return true


func _entry_matches_free_text(entry: Dictionary, term: String) -> bool:
	var normalized_term := term.strip_edges().to_lower()
	if normalized_term.is_empty():
		return true
	if not _normalize_input_device(term).is_empty() and _search_device_matches(entry, term):
		return true
	if str(entry.get("id_lc", "")).contains(normalized_term):
		return true
	if str(entry.get("display_name_lc", "")).contains(normalized_term):
		return true
	if str(entry.get("description_lc", "")).contains(normalized_term):
		return true
	if str(entry.get("primary_input_device_lc", "")).contains(normalized_term):
		return true
	if str(entry.get("input_device_note_lc", "")).contains(normalized_term):
		return true
	for device_variant in entry.get("supported_input_devices_lc", []):
		if str(device_variant).contains(normalized_term):
			return true
	for tag_variant in entry.get("tags_lc", []):
		if str(tag_variant).contains(normalized_term):
			return true
	for alias_variant in entry.get("aliases_lc", []):
		if str(alias_variant).contains(normalized_term):
			return true
	return false


func _matches_any_search_value(candidate: String, include_terms: PackedStringArray, exclude_terms: PackedStringArray, path_match := false) -> bool:
	var normalized_candidate := candidate.to_lower()
	for term in exclude_terms:
		if _search_value_matches(normalized_candidate, str(term), path_match):
			return false
	if include_terms.is_empty():
		return true
	for term in include_terms:
		if _search_value_matches(normalized_candidate, str(term), path_match):
			return true
	return false


func _search_value_matches(candidate: String, term: String, path_match := false) -> bool:
	var normalized_term := term.strip_edges().to_lower()
	if normalized_term.is_empty():
		return false
	if path_match:
		return candidate == normalized_term or candidate.begins_with(normalized_term) or candidate.contains(normalized_term)
	return candidate == normalized_term or candidate.contains(normalized_term)


func _matches_device_terms(entry: Dictionary, include_terms: PackedStringArray, exclude_terms: PackedStringArray) -> bool:
	for term in exclude_terms:
		if _search_device_matches(entry, str(term)):
			return false
	if include_terms.is_empty():
		return true
	for term in include_terms:
		if _search_device_matches(entry, str(term)):
			return true
	return false


func _search_device_matches(entry: Dictionary, term: String) -> bool:
	var normalized_term := _normalize_input_device(term).to_lower()
	if normalized_term.is_empty():
		normalized_term = term.strip_edges().to_lower()
	if normalized_term.is_empty():
		return false
	if str(entry.get("primary_input_device_lc", "")).contains(normalized_term):
		return true
	for device_variant in entry.get("supported_input_devices_lc", []):
		if str(device_variant).contains(normalized_term):
			return true
	return false


func _matches_any_search_tag(candidate_tags: Array, include_terms: PackedStringArray, exclude_terms: PackedStringArray) -> bool:
	for term in exclude_terms:
		if _search_tags_match(candidate_tags, str(term)):
			return false
	if include_terms.is_empty():
		return true
	for term in include_terms:
		if _search_tags_match(candidate_tags, str(term)):
			return true
	return false


func _search_tags_match(candidate_tags: Array, term: String) -> bool:
	var normalized_term := term.strip_edges().to_lower()
	if normalized_term.is_empty():
		return false
	for tag_variant in candidate_tags:
		var tag := str(tag_variant)
		if tag == normalized_term or tag.contains(normalized_term):
			return true
	return false


func _matches_sync_terms(entry: Dictionary, include_terms: PackedStringArray, exclude_terms: PackedStringArray) -> bool:
	for term in exclude_terms:
		if _search_sync_matches(str(entry.get("sync_status", "")), str(term)):
			return false
	if include_terms.is_empty():
		return true
	for term in include_terms:
		if _search_sync_matches(str(entry.get("sync_status", "")), str(term)):
			return true
	return false


func _search_sync_matches(status: String, term: String) -> bool:
	var normalized_status := status.to_lower()
	var normalized_term := term.strip_edges().to_lower()
	match normalized_term:
		"dirty":
			return normalized_status in ["conflict", "resource_dirty", "markdown_dirty"]
		"conflict":
			return normalized_status == "conflict"
		"resource_dirty", "markdown_dirty", "clean":
			return normalized_status == normalized_term
		_:
			return normalized_status.contains(normalized_term)


func _matches_modified_terms(entry: Dictionary, include_terms: PackedStringArray, exclude_terms: PackedStringArray) -> bool:
	for term in exclude_terms:
		if _search_modified_matches(entry, str(term)):
			return false
	if include_terms.is_empty():
		return true
	for term in include_terms:
		if _search_modified_matches(entry, str(term)):
			return true
	return false


func _search_modified_matches(entry: Dictionary, term: String) -> bool:
	var normalized_term := term.strip_edges().to_lower()
	if normalized_term.is_empty():
		return false
	if "definition".contains(normalized_term) and bool(entry.get("definition_modified", false)):
		return true
	if "value".contains(normalized_term) and bool(entry.get("value_modified", false)):
		return true
	return false


func _add_input_device_batch_header(batch: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = _color_for_search_category("Device").darkened(0.72)
	style.border_width_left = 3
	style.border_color = _color_for_search_category("Device")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	var batch_label := str(batch.get("label", batch.get("key", "Input device"))).strip_edges()
	var count := int(batch.get("count", Array(batch.get("items", [])).size()))
	label.text = "%s (%d)" % [batch_label, count]
	panel.add_child(label)
	_item_container.add_child(panel)


func _add_item_row(setting_item: Resource) -> void:
	var field = BoundSettingFieldScene.instantiate()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.SettingId = str(setting_item.get("ItemId"))
	field.ShowDescription = true
	field.ShowItemId = true
	field.ShowMetadataChips = true
	field.ShowToolbarActions = true
	if field.has_method("set_settings_service"):
		field.call("set_settings_service", settings_service)
	if field.has_signal("operation_completed"):
		field.connect("operation_completed", Callable(self, "_on_field_operation_completed"))
	if field.has_signal("action_requested"):
		field.connect("action_requested", Callable(self, "_on_action_requested"))
	_item_container.add_child(field)


func _create_setting_control(setting_item: Resource) -> Control:
	var scene: PackedScene
	if settings_service != null and settings_service.has_method("get_registry"):
		var registry = settings_service.call("get_registry")
		if registry != null and registry.has_method("get_control_scene"):
			scene = registry.call("get_control_scene", str(setting_item.get("ValueType")))
	if scene == null:
		scene = FallbackControlScene
	var control := scene.instantiate()
	if control.has_method("bind_item"):
		control.call("bind_item", setting_item, settings_service)
	return control


func _add_chip(parent: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = color.lightened(0.05)
	parent.add_child(label)


func _add_toolbar_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _registry_color(bucket: String, key: String) -> Color:
	if settings_service == null or not settings_service.has_method("get_registry"):
		return Color(0.32, 0.36, 0.42)
	var registry = settings_service.call("get_registry")
	if registry != null and registry.has_method("get_color"):
		return registry.call("get_color", bucket, key)
	return Color(0.32, 0.36, 0.42)


func _on_group_selected() -> void:
	var selected := _group_tree.get_selected()
	if selected == null:
		return
	_selected_group = str(selected.get_metadata(0))
	_refresh_items()


func _on_value_submitted(item_id: String, value: Variant) -> void:
	if settings_service == null or not settings_service.has_method("set_value"):
		return
	var result: Dictionary = settings_service.call("set_value", item_id, value)
	_status_label.text = str(result.get("message", "Updated " + item_id)) if bool(result.get("ok", false)) else str(result.get("error", "Could not update " + item_id))
	_refresh_search_context()
	_refresh_search_suggestions()
	_refresh_items()


func _on_action_requested(item_id: String) -> void:
	action_requested.emit(item_id)
	_status_label.text = "Action requested: %s" % item_id

func _on_field_operation_completed(item_id: String, result: Dictionary) -> void:
	_status_label.text = str(result.get("message", "Updated " + item_id)) if bool(result.get("ok", false)) else str(result.get("error", "Could not update " + item_id))
	_refresh_search_context()
	_refresh_search_suggestions()
	_refresh_items()


func _export_markdown() -> void:
	var result: Dictionary = settings_service.call("export_markdown_for_all") if settings_service != null else {"message": "Settings service unavailable"}
	_status_label.text = str(result.get("message", "Markdown export finished"))


func _detect_conflicts() -> void:
	var result: Dictionary = settings_service.call("detect_markdown_sync") if settings_service != null else {"message": "Settings service unavailable"}
	_status_label.text = str(result.get("message", "Conflict check finished"))


func _apply_staged() -> void:
	var result: Dictionary = settings_service.call("apply_staged_values") if settings_service != null else {"message": "Settings service unavailable"}
	_status_label.text = str(result.get("message", "Apply finished"))
	refresh()


func _discard_staged() -> void:
	var result: Dictionary = settings_service.call("discard_staged_values") if settings_service != null else {"message": "Settings service unavailable"}
	_status_label.text = str(result.get("message", "Discard finished"))
	refresh()


func _open_export_dialog() -> void:
	if settings_service == null or not settings_service.has_method("export_profile_text"):
		_status_label.text = "Settings service cannot export profiles."
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Export Settings"
	dialog.min_size = Vector2i(860, 720)
	dialog.get_ok_button().text = "Save To File"

	var box := VBoxContainer.new()
	dialog.add_child(box)

	var summary := Label.new()
	summary.text = "Choose which settings to export. Group, tag, and item selections are additive."
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	var path_edit := LineEdit.new()
	path_edit.placeholder_text = DEFAULT_EXPORT_PATH
	path_edit.text = DEFAULT_EXPORT_PATH
	box.add_child(path_edit)

	var scope_tree := _build_scope_tree(_scope_entries_from_settings())
	box.add_child(scope_tree)

	var action_row := HBoxContainer.new()
	box.add_child(action_row)
	_add_toolbar_button(action_row, "Select All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), true))
	_add_toolbar_button(action_row, "Clear All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), false))
	_add_toolbar_button(action_row, "Copy JSON", func() -> void:
		var selection := _collect_scope_selection(scope_tree.get_root())
		var export_full := _scope_tree_all_checked(scope_tree.get_root())
		var result: Dictionary = settings_service.call("export_profile_text", export_full, selection["ids"], false, selection["groups"], selection["tags"])
		if not bool(result.get("ok", false)):
			_status_label.text = str(result.get("error", "Profile export failed"))
			return
		DisplayServer.clipboard_set(str(result.get("text", "")))
		_status_label.text = "Copied settings profile JSON to the clipboard."
	)

	dialog.confirmed.connect(func() -> void:
		var selection := _collect_scope_selection(scope_tree.get_root())
		var export_full := _scope_tree_all_checked(scope_tree.get_root())
		var export_path := path_edit.text.strip_edges()
		if export_path.is_empty():
			export_path = DEFAULT_EXPORT_PATH
		var result: Dictionary = settings_service.call("export_profile_json", export_path, export_full, selection["ids"], false, selection["groups"], selection["tags"])
		_status_label.text = str(result.get("message", result.get("error", "Profile export finished")))
		if bool(result.get("ok", false)):
			dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered_ratio(0.82)


func _open_import_dialog() -> void:
	if settings_service == null or not settings_service.has_method("parse_profile_text"):
		_status_label.text = "Settings service cannot import profiles."
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Import Settings"
	dialog.min_size = Vector2i(860, 720)
	dialog.get_ok_button().text = "Next"

	var box := VBoxContainer.new()
	dialog.add_child(box)

	var summary := Label.new()
	summary.text = "Import from pasted JSON, a file path, or a saved local preset."
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)

	var paste_page := VBoxContainer.new()
	paste_page.name = "Paste Text"
	tabs.add_child(paste_page)
	var paste_help := Label.new()
	paste_help.text = "Paste a readable Sea Shell settings profile JSON payload."
	paste_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paste_page.add_child(paste_help)
	var paste_edit := TextEdit.new()
	paste_edit.custom_minimum_size.y = 420
	paste_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paste_page.add_child(paste_edit)

	var file_page := VBoxContainer.new()
	file_page.name = "Open File"
	tabs.add_child(file_page)
	var file_help := Label.new()
	file_help.text = "Enter the profile path to open."
	file_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	file_page.add_child(file_help)
	var file_edit := LineEdit.new()
	file_edit.placeholder_text = DEFAULT_IMPORT_PATH
	file_edit.text = DEFAULT_IMPORT_PATH
	file_page.add_child(file_edit)

	var preset_page := VBoxContainer.new()
	preset_page.name = "Load Local Preset"
	tabs.add_child(preset_page)
	var preset_help := Label.new()
	preset_help.text = "Choose one of the locally saved committed presets."
	preset_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_page.add_child(preset_help)
	var preset_list := ItemList.new()
	preset_list.select_mode = ItemList.SELECT_SINGLE
	preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_list.custom_minimum_size.y = 420
	preset_page.add_child(preset_list)
	_fill_preset_list(preset_list, settings_service.call("list_presets"))

	dialog.confirmed.connect(func() -> void:
		var source_result := _resolve_import_source(tabs, paste_edit, file_edit, preset_list)
		if not bool(source_result.get("ok", false)):
			_status_label.text = str(source_result.get("error", "Import source failed"))
			return
		dialog.queue_free()
		_open_import_scope_dialog(source_result.get("profile", {}), str(source_result.get("label", "imported profile")))
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered_ratio(0.82)


func _resolve_import_source(tabs: TabContainer, paste_edit: TextEdit, file_edit: LineEdit, preset_list: ItemList) -> Dictionary:
	match tabs.current_tab:
		0:
			var text := paste_edit.text.strip_edges()
			if text.is_empty():
				return {"ok": false, "error": "Paste some profile JSON first."}
			var parsed: Dictionary = settings_service.call("parse_profile_text", text)
			if not bool(parsed.get("ok", false)):
				return parsed
			return {"ok": true, "profile": parsed.get("profile", {}), "label": "pasted JSON"}
		1:
			var path := file_edit.text.strip_edges()
			if path.is_empty():
				path = DEFAULT_IMPORT_PATH
			var loaded: Dictionary = settings_service.call("load_profile_data", path)
			if not bool(loaded.get("ok", false)):
				return loaded
			return {"ok": true, "profile": loaded.get("profile", {}), "label": str(loaded.get("path", path))}
		2:
			var selected := preset_list.get_selected_items()
			if selected.is_empty():
				return {"ok": false, "error": "Select a preset first."}
			var entries: Array = Array(preset_list.get_meta("entries", []))
			var entry: Dictionary = entries[int(selected[0])]
			var loaded: Dictionary = settings_service.call("load_preset", str(entry.get("path", "")))
			if not bool(loaded.get("ok", false)):
				return loaded
			return {"ok": true, "profile": loaded.get("profile", {}), "label": "preset %s" % str(entry.get("name", ""))}
		_:
			return {"ok": false, "error": "Unsupported import source."}


func _open_import_scope_dialog(profile: Dictionary, source_label: String) -> void:
	if settings_service == null or not settings_service.has_method("preview_profile_data"):
		_status_label.text = "Settings service cannot preview incoming profiles."
		return
	var preview: Dictionary = settings_service.call("preview_profile_data", profile)
	if not bool(preview.get("ok", false)):
		_status_label.text = str(preview.get("error", "Profile preview failed"))
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Select Import Scope"
	dialog.min_size = Vector2i(860, 720)
	dialog.get_ok_button().text = "Review Differences"

	var box := VBoxContainer.new()
	dialog.add_child(box)

	var summary := Label.new()
	summary.text = "Choose which incoming groups, tags, or items from %s are eligible for import." % source_label
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	var detail := Label.new()
	detail.text = "%d incoming setting record%s detected." % [int(preview.get("count", 0)), "" if int(preview.get("count", 0)) == 1 else "s"]
	box.add_child(detail)

	var action_row := HBoxContainer.new()
	box.add_child(action_row)
	var scope_tree := _build_scope_tree(Array(preview.get("items", [])))
	_add_toolbar_button(action_row, "Select All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), true))
	_add_toolbar_button(action_row, "Clear All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), false))
	box.add_child(scope_tree)

	dialog.confirmed.connect(func() -> void:
		var selection := _collect_scope_selection(scope_tree.get_root())
		var diff: Dictionary = settings_service.call("build_profile_import_diff", profile, selection["ids"], selection["groups"], selection["tags"], IMPORT_KEEP_INCOMING)
		if not bool(diff.get("ok", false)):
			_status_label.text = str(diff.get("error", "Could not review incoming profile"))
			return
		if Array(diff.get("changed", [])).is_empty() and Array(diff.get("unknown", [])).is_empty() and Array(diff.get("invalid", [])).is_empty():
			_status_label.text = "No conflicts or changes were found in the selected import scope."
			dialog.queue_free()
			return
		dialog.queue_free()
		_open_import_review_dialog(profile, source_label, diff, selection["ids"], selection["groups"], selection["tags"])
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered_ratio(0.82)


func _open_import_review_dialog(
	profile: Dictionary,
	source_label: String,
	diff: Dictionary,
	include_ids: PackedStringArray,
	include_groups: PackedStringArray,
	include_tags: PackedStringArray
) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Review Differences"
	dialog.min_size = Vector2i(960, 760)
	dialog.get_ok_button().text = "Apply Import"

	var box := VBoxContainer.new()
	dialog.add_child(box)

	var summary := Label.new()
	summary.text = "%s\nExact matches are hidden. Unknown and invalid rows are listed for review only." % str(diff.get("message", source_label))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	var bias_row := HBoxContainer.new()
	box.add_child(bias_row)
	var bias_label := Label.new()
	bias_label.text = "Default conflict choice"
	bias_row.add_child(bias_label)
	var bias_toggle := OptionButton.new()
	bias_toggle.add_item("Keep Incoming")
	bias_toggle.add_item("Keep Mine")
	bias_toggle.select(0 if str(diff.get("default_preference", IMPORT_KEEP_INCOMING)) == IMPORT_KEEP_INCOMING else 1)
	bias_row.add_child(bias_toggle)

	var state := {
		"default_preference": str(diff.get("default_preference", IMPORT_KEEP_INCOMING)),
		"row_choices": {},
		"manual_overrides": {},
	}
	var review_tree := _build_import_review_tree(diff, state)
	box.add_child(review_tree)

	bias_toggle.item_selected.connect(func(index: int) -> void:
		state["default_preference"] = IMPORT_KEEP_INCOMING if index == 0 else IMPORT_KEEP_MINE
		_sync_import_review_defaults(review_tree.get_root(), _preference_uses_incoming(str(state.get("default_preference", IMPORT_KEEP_INCOMING))), state)
	)
	review_tree.item_edited.connect(func() -> void:
		var edited := review_tree.get_edited()
		if edited == null:
			return
		var metadata = edited.get_metadata(0)
		if typeof(metadata) != TYPE_DICTIONARY or str(metadata.get("kind", "")) != "changed":
			return
		var item_id := str(metadata.get("id", ""))
		var use_incoming := edited.is_checked(0)
		var default_value := _preference_uses_incoming(str(state.get("default_preference", IMPORT_KEEP_INCOMING)))
		var row_choices: Dictionary = state["row_choices"]
		var manual_overrides: Dictionary = state["manual_overrides"]
		row_choices[item_id] = use_incoming
		manual_overrides[item_id] = use_incoming != default_value
	)

	dialog.confirmed.connect(func() -> void:
		var result: Dictionary = settings_service.call(
			"apply_profile_data",
			profile,
			include_ids,
			include_groups,
			include_tags,
			state.get("row_choices", {}),
			str(state.get("default_preference", IMPORT_KEEP_INCOMING))
		)
		_status_label.text = str(result.get("message", result.get("error", "Profile import finished")))
		refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered_ratio(0.88)


func _build_import_review_tree(diff: Dictionary, state: Dictionary) -> Tree:
	var tree := Tree.new()
	tree.hide_root = true
	tree.columns = 5
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Use Incoming")
	tree.set_column_title(1, "Setting")
	tree.set_column_title(2, "Current")
	tree.set_column_title(3, "Incoming")
	tree.set_column_title(4, "Group / State")
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 480

	var root := tree.create_item()
	var changed_root := _scope_tree_section(tree, root, "Changed")
	var unknown_root := _scope_tree_section(tree, root, "Unknown")
	var invalid_root := _scope_tree_section(tree, root, "Invalid")
	var row_choices: Dictionary = state["row_choices"]

	for row_variant in diff.get("changed", []):
		var row: Dictionary = row_variant
		var item_id := str(row.get("id", ""))
		var use_incoming := bool(row.get("use_incoming", true))
		row_choices[item_id] = use_incoming
		var item := tree.create_item(changed_root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, use_incoming)
		item.set_text(1, "%s  [%s]" % [str(row.get("display_name", item_id)), item_id])
		item.set_text(2, str(row.get("current_value_text", "")))
		item.set_text(3, str(row.get("incoming_value_text", "")))
		item.set_text(4, "%s | %s" % [str(row.get("group_path", "")), str(row.get("apply_policy", ""))])
		item.set_metadata(0, {"kind": "changed", "id": item_id})

	for row_variant in diff.get("unknown", []):
		var row: Dictionary = row_variant
		var item := tree.create_item(unknown_root)
		item.set_text(1, "%s  [%s]" % [str(row.get("display_name", row.get("id", ""))), str(row.get("id", ""))])
		item.set_text(3, str(row.get("incoming_value_text", "")))
		item.set_text(4, str(row.get("error", "Unknown setting.")))

	for row_variant in diff.get("invalid", []):
		var row: Dictionary = row_variant
		var item := tree.create_item(invalid_root)
		item.set_text(1, "%s  [%s]" % [str(row.get("display_name", row.get("id", ""))), str(row.get("id", ""))])
		item.set_text(3, str(row.get("incoming_value_text", "")))
		item.set_text(4, str(row.get("error", "Invalid setting value.")))

	changed_root.collapsed = false
	unknown_root.collapsed = Array(diff.get("unknown", [])).is_empty()
	invalid_root.collapsed = Array(diff.get("invalid", [])).is_empty()
	return tree


func _sync_import_review_defaults(parent: TreeItem, use_incoming: bool, state: Dictionary) -> void:
	if parent == null:
		return
	var child := parent.get_first_child()
	while child != null:
		var metadata = child.get_metadata(0)
		if typeof(metadata) == TYPE_DICTIONARY and str(metadata.get("kind", "")) == "changed":
			var item_id := str(metadata.get("id", ""))
			var manual_overrides: Dictionary = state["manual_overrides"]
			if not bool(manual_overrides.get(item_id, false)):
				child.set_checked(0, use_incoming)
				var row_choices: Dictionary = state["row_choices"]
				row_choices[item_id] = use_incoming
		_sync_import_review_defaults(child, use_incoming, state)
		child = child.get_next()


func _open_preset_manager() -> void:
	if settings_service == null or not settings_service.has_method("list_presets"):
		_status_label.text = "Settings service cannot manage presets."
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Settings Presets"
	dialog.min_size = Vector2i(980, 760)
	dialog.get_ok_button().text = "Close"

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280.0
	split.add_child(left)
	var list_label := Label.new()
	list_label.text = "Saved Presets"
	left.add_child(list_label)
	var preset_list := ItemList.new()
	preset_list.select_mode = ItemList.SELECT_SINGLE
	preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preset_list)
	_fill_preset_list(preset_list, settings_service.call("list_presets"))

	var load_button := Button.new()
	load_button.text = "Load Selected"
	left.add_child(load_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var name_label := Label.new()
	name_label.text = "Preset Name"
	right.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "New preset name"
	right.add_child(name_edit)

	var helper := Label.new()
	helper.text = "Save committed settings as a new local preset, or overwrite an existing one after confirmation."
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(helper)

	var scope_actions := HBoxContainer.new()
	right.add_child(scope_actions)
	var scope_tree := _build_scope_tree(_scope_entries_from_settings())
	_add_toolbar_button(scope_actions, "Select All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), true))
	_add_toolbar_button(scope_actions, "Clear All", func() -> void: _set_scope_tree_checked(scope_tree.get_root(), false))
	right.add_child(scope_tree)

	var save_actions := HBoxContainer.new()
	right.add_child(save_actions)
	var save_new_button := _add_toolbar_button(save_actions, "Save New", func() -> void:
		var save_result := _save_preset_from_ui(name_edit.text, scope_tree, false)
		_status_label.text = str(save_result.get("message", save_result.get("error", "Preset save finished")))
		if bool(save_result.get("ok", false)):
			_fill_preset_list(preset_list, settings_service.call("list_presets"))
	)
	var overwrite_button := _add_toolbar_button(save_actions, "Overwrite Existing", func() -> void:
		_confirm_overwrite_preset(name_edit.text, scope_tree, preset_list)
	)
	save_new_button = save_new_button
	overwrite_button = overwrite_button

	preset_list.item_selected.connect(func(index: int) -> void:
		var entries: Array = Array(preset_list.get_meta("entries", []))
		if index >= 0 and index < entries.size():
			name_edit.text = str(entries[index].get("name", ""))
	)
	load_button.pressed.connect(func() -> void:
		var selected := preset_list.get_selected_items()
		if selected.is_empty():
			_status_label.text = "Select a preset to load."
			return
		var entries: Array = Array(preset_list.get_meta("entries", []))
		var entry: Dictionary = entries[int(selected[0])]
		var loaded: Dictionary = settings_service.call("load_preset", str(entry.get("path", "")))
		if not bool(loaded.get("ok", false)):
			_status_label.text = str(loaded.get("error", "Could not load preset"))
			return
		dialog.queue_free()
		_open_import_scope_dialog(loaded.get("profile", {}), "preset %s" % str(entry.get("name", "")))
	)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered_ratio(0.9)


func _save_preset_from_ui(name: String, scope_tree: Tree, overwrite: bool) -> Dictionary:
	var selection := _collect_scope_selection(scope_tree.get_root())
	var full_snapshot := _scope_tree_all_checked(scope_tree.get_root())
	return settings_service.call("save_preset", name, full_snapshot, selection["ids"], selection["groups"], selection["tags"], overwrite)


func _confirm_overwrite_preset(name: String, scope_tree: Tree, preset_list: ItemList) -> void:
	var trimmed_name := name.strip_edges()
	if trimmed_name.is_empty():
		_status_label.text = "Choose a preset name to overwrite."
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Preset Overwrite"
	dialog.get_ok_button().text = "Overwrite"
	var label := Label.new()
	label.text = "Overwrite preset '%s' with the current committed selection?" % trimmed_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)
	dialog.confirmed.connect(func() -> void:
		var save_result := _save_preset_from_ui(trimmed_name, scope_tree, true)
		_status_label.text = str(save_result.get("message", save_result.get("error", "Preset overwrite finished")))
		if bool(save_result.get("ok", false)):
			_fill_preset_list(preset_list, settings_service.call("list_presets"))
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 160))


func _fill_preset_list(preset_list: ItemList, entries: Array) -> void:
	preset_list.clear()
	preset_list.set_meta("entries", entries)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var saved_text := ""
		var saved_unix := int(entry.get("saved_unix", 0))
		if saved_unix > 0:
			saved_text = " - %s" % Time.get_datetime_string_from_unix_time(saved_unix, true)
		preset_list.add_item("%s (%d)%s" % [str(entry.get("name", "")), int(entry.get("item_count", 0)), saved_text])


func _scope_entries_from_settings() -> Array:
	var entries: Array = []
	if settings_service == null or not settings_service.has_method("get_items"):
		return entries
	for item in settings_service.call("get_items"):
		if str(item.get("Kind")) != "Setting":
			continue
		entries.append({
			"id": str(item.get("ItemId")),
			"display_name": item.display_name(),
			"group_path": str(item.get("GroupPath")),
			"tags": Array(item.get("Tags")),
		})
	return entries


func _build_scope_tree(entries: Array) -> Tree:
	var tree := Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Selection")
	tree.set_column_title(1, "Kind")
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 420

	var root := tree.create_item()
	var groups_root := _scope_tree_section(tree, root, "Groups")
	var tags_root := _scope_tree_section(tree, root, "Tags")
	var items_root := _scope_tree_section(tree, root, "Items")

	var group_nodes := {"": groups_root}
	var item_group_nodes := {"": items_root}
	var groups := PackedStringArray()
	var tags := PackedStringArray()
	var item_entries := entries.duplicate()
	item_entries.sort_custom(_compare_scope_entries)

	for entry_variant in item_entries:
		var entry: Dictionary = entry_variant
		var group_path := str(entry.get("group_path", "")).strip_edges()
		if not group_path.is_empty() and not groups.has(group_path):
			groups.append(group_path)
		for tag in entry.get("tags", []):
			var typed_tag := str(tag).strip_edges()
			if not typed_tag.is_empty() and not tags.has(typed_tag):
				tags.append(typed_tag)

	groups.sort()
	tags.sort()

	for group_path in groups:
		var parts := group_path.split("/", false)
		var cursor := ""
		var parent: TreeItem = groups_root
		for part in parts:
			cursor = part if cursor.is_empty() else cursor + "/" + part
			if not group_nodes.has(cursor):
				var group_item := tree.create_item(parent)
				group_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				group_item.set_editable(0, true)
				group_item.set_checked(0, true)
				group_item.set_text(0, part)
				group_item.set_text(1, "Group")
				group_item.set_metadata(0, {"kind": "group", "value": cursor})
				group_nodes[cursor] = group_item
			parent = group_nodes[cursor]

	for tag in tags:
		var tag_item := tree.create_item(tags_root)
		tag_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		tag_item.set_editable(0, true)
		tag_item.set_checked(0, true)
		tag_item.set_text(0, tag)
		tag_item.set_text(1, "Tag")
		tag_item.set_metadata(0, {"kind": "tag", "value": tag})

	for entry_variant in item_entries:
		var entry: Dictionary = entry_variant
		var group_path := str(entry.get("group_path", "")).strip_edges()
		var parent: TreeItem = items_root
		if not group_path.is_empty():
			var parts := group_path.split("/", false)
			var cursor := ""
			for part in parts:
				cursor = part if cursor.is_empty() else cursor + "/" + part
				if not item_group_nodes.has(cursor):
					var group_item := tree.create_item(parent)
					group_item.set_text(0, part)
					group_item.set_text(1, "Group")
					item_group_nodes[cursor] = group_item
				parent = item_group_nodes[cursor]
		var item_node := tree.create_item(parent)
		item_node.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item_node.set_editable(0, true)
		item_node.set_checked(0, true)
		item_node.set_text(0, "%s  [%s]" % [str(entry.get("display_name", entry.get("id", ""))), str(entry.get("id", ""))])
		item_node.set_text(1, "Item")
		item_node.set_metadata(0, {"kind": "item", "value": str(entry.get("id", ""))})

	groups_root.collapsed = false
	tags_root.collapsed = false
	items_root.collapsed = false
	return tree


func _compare_scope_entries(left, right) -> bool:
	var left_key := "%s/%s" % [str(left.get("group_path", "")), str(left.get("display_name", left.get("id", "")))]
	var right_key := "%s/%s" % [str(right.get("group_path", "")), str(right.get("display_name", right.get("id", "")))]
	return left_key.nocasecmp_to(right_key) < 0


func _scope_tree_section(tree: Tree, parent: TreeItem, label: String) -> TreeItem:
	var item := tree.create_item(parent)
	item.set_text(0, label)
	item.collapsed = false
	return item


func _set_scope_tree_checked(parent: TreeItem, checked: bool) -> void:
	if parent == null:
		return
	var child := parent.get_first_child()
	while child != null:
		if child.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
			child.set_checked(0, checked)
		_set_scope_tree_checked(child, checked)
		child = child.get_next()


func _scope_tree_all_checked(parent: TreeItem) -> bool:
	var state := {"found": false, "all_checked": true}
	_collect_scope_tree_checked_state(parent, state)
	return bool(state.get("found", false)) and bool(state.get("all_checked", false))


func _collect_scope_tree_checked_state(parent: TreeItem, state: Dictionary) -> void:
	if parent == null:
		return
	var child := parent.get_first_child()
	while child != null:
		if child.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
			state["found"] = true
			if not child.is_checked(0):
				state["all_checked"] = false
		_collect_scope_tree_checked_state(child, state)
		child = child.get_next()


func _collect_scope_selection(parent: TreeItem) -> Dictionary:
	var ids := PackedStringArray()
	var groups := PackedStringArray()
	var tags := PackedStringArray()
	_collect_scope_selection_recursive(parent, ids, groups, tags)
	return {"ids": ids, "groups": groups, "tags": tags}


func _collect_scope_selection_recursive(parent: TreeItem, ids: PackedStringArray, groups: PackedStringArray, tags: PackedStringArray) -> void:
	if parent == null:
		return
	var child := parent.get_first_child()
	while child != null:
		var metadata = child.get_metadata(0)
		if typeof(metadata) == TYPE_DICTIONARY and child.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK and child.is_checked(0):
			match str(metadata.get("kind", "")):
				"item":
					ids.append(str(metadata.get("value", "")))
				"group":
					groups.append(str(metadata.get("value", "")))
				"tag":
					tags.append(str(metadata.get("value", "")))
		_collect_scope_selection_recursive(child, ids, groups, tags)
		child = child.get_next()


func _preference_uses_incoming(preference: String) -> bool:
	return preference.strip_edges() != IMPORT_KEEP_MINE


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _apply_sync_filter(items: Array) -> Array:
	if _sync_filter == null or _sync_filter.selected <= 0 or settings_service == null or not settings_service.has_method("detect_markdown_sync"):
		return items
	var sync_result: Dictionary = settings_service.call("detect_markdown_sync")
	var allowed := {}
	for status in sync_result.get("statuses", []):
		var state := str(status.get("status", ""))
		var include := false
		if _sync_filter.selected == 1:
			include = state == "conflict" or state == "resource_dirty" or state == "markdown_dirty"
		elif _sync_filter.selected == 2:
			include = state == "conflict"
		if include:
			allowed[str(status.get("id", ""))] = true
	var filtered := []
	for item in items:
		if allowed.has(str(item.get("ItemId"))):
			filtered.append(item)
	return filtered
