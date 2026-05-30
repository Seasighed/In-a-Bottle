extends CanvasLayer
class_name SeaShellUiLayersDebugPanel

const ManagerScript = preload("res://addons/seashell_devtools/SeaShellUiLayerManager.gd")
const MANAGER_GROUP := "sea_shell_ui_layer_manager"

@export var manager_path: NodePath = NodePath("")
@export var start_collapsed := true
@export var create_manager_if_missing := true
@export var include_hidden_layers := false
@export var focus_on_select := true
@export var canvas_layer_index := 4096
@export var panel_size: Vector2 = Vector2(420, 520)
@export_range(0.1, 5.0, 0.1) var refresh_interval := 0.25

var _manager: Node
var _root_control: Control
var _layers_button: Button
var _panel: PanelContainer
var _tree: Tree
var _focus_button: Button
var _close_button: Button
var _reload_button: Button
var _selected_layer: Dictionary = {}
var _refresh_elapsed := 0.0
var _collapsed_paths: Dictionary = {}

func _ready() -> void:
	layer = canvas_layer_index
	_build_ui()
	_connect_manager()
	_set_expanded(not start_collapsed)
	set_process(true)

func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return

	_refresh_elapsed += delta
	if _refresh_elapsed < refresh_interval:
		return

	_refresh_elapsed = 0.0
	if _manager == null or not is_instance_valid(_manager):
		_connect_manager()
	elif _manager.has_method("refresh_layers"):
		_manager.call("refresh_layers")
	_rebuild_tree()

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "LayersDebugUi"
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)

	_layers_button = Button.new()
	_layers_button.name = "LayersButton"
	_layers_button.text = "Layers"
	_layers_button.tooltip_text = "Show selectable UI layers"
	_layers_button.custom_minimum_size = Vector2(104, 34)
	_layers_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_layers_button.anchor_left = 1.0
	_layers_button.anchor_right = 1.0
	_layers_button.offset_left = -116.0
	_layers_button.offset_top = 12.0
	_layers_button.offset_right = -12.0
	_layers_button.offset_bottom = 46.0
	_layers_button.pressed.connect(func(): _set_expanded(true))
	_root_control.add_child(_layers_button)

	_panel = PanelContainer.new()
	_panel.name = "LayersPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -panel_size.x - 12.0
	_panel.offset_top = 52.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 52.0 + panel_size.y
	_root_control.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(toolbar)

	var title := Label.new()
	title.text = "Layers"
	title.theme_type_variation = "HeaderSmall"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_request_refresh)
	toolbar.add_child(refresh_button)

	var collapse_button := Button.new()
	collapse_button.text = "Collapse"
	collapse_button.pressed.connect(func(): _set_expanded(false))
	toolbar.add_child(collapse_button)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.set_column_title(0, "Layer")
	_tree.set_column_title(1, "Path")
	_tree.set_column_title(2, "State")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(2, 74)
	_tree.item_selected.connect(_on_tree_item_selected)
	content.add_child(_tree)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(actions)

	_focus_button = Button.new()
	_focus_button.text = "Focus"
	_focus_button.pressed.connect(_focus_selected_layer)
	actions.add_child(_focus_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(_close_selected_layer)
	actions.add_child(_close_button)

	_reload_button = Button.new()
	_reload_button.text = "Reload"
	_reload_button.pressed.connect(_reload_selected_layer)
	actions.add_child(_reload_button)

	_update_action_buttons()

func _connect_manager() -> void:
	var resolved_manager := _resolve_manager()
	if resolved_manager == _manager:
		_request_refresh()
		return

	var change_callback := Callable(self, "_request_refresh")
	if _manager != null and is_instance_valid(_manager) and _manager.has_signal("layers_changed"):
		if _manager.is_connected("layers_changed", change_callback):
			_manager.disconnect("layers_changed", change_callback)

	_manager = resolved_manager
	if _manager != null and _manager.has_signal("layers_changed"):
		if not _manager.is_connected("layers_changed", change_callback):
			_manager.connect("layers_changed", change_callback)
	if _manager != null and _manager.has_method("refresh_layers"):
		_manager.call("refresh_layers")
	_request_refresh()

func _resolve_manager() -> Node:
	if not String(manager_path).strip_edges().is_empty():
		var explicit_manager := get_node_or_null(manager_path)
		if explicit_manager != null:
			return explicit_manager

	var scene_tree := get_tree()
	if scene_tree != null:
		var managers := scene_tree.get_nodes_in_group(MANAGER_GROUP)
		if not managers.is_empty():
			return managers[0]

	if not create_manager_if_missing:
		return null

	var manager := ManagerScript.new()
	manager.name = "SeaShellUiLayerManager"
	var manager_parent := get_parent()
	if manager_parent == null and get_tree() != null:
		manager_parent = get_tree().root
	if manager_parent != null:
		manager_parent.add_child(manager)
		return manager
	return null

func _set_expanded(expanded: bool) -> void:
	if _panel == null or _layers_button == null:
		return

	_panel.visible = expanded
	_layers_button.visible = not expanded
	if expanded:
		_connect_manager()
		_rebuild_tree()

func _request_refresh() -> void:
	_refresh_elapsed = 0.0
	if _tree != null and _panel != null and _panel.visible:
		_rebuild_tree()

func _rebuild_tree() -> void:
	if _tree == null:
		return

	_capture_collapsed_state()
	_tree.clear()
	var root_item := _tree.create_item()

	if _manager == null or not is_instance_valid(_manager) or not _manager.has_method("get_layers"):
		var missing_item := _tree.create_item(root_item)
		missing_item.set_text(0, "No layer manager")
		_selected_layer = {}
		_update_action_buttons()
		return

	var layers: Array = _manager.call("get_layers", include_hidden_layers)
	if layers.is_empty():
		var empty_item := _tree.create_item(root_item)
		empty_item.set_text(0, "No selectable layers open")
		_selected_layer = {}
		_update_action_buttons()
		return

	var item_by_root_id: Dictionary = {}
	for layer_record in layers:
		if not _is_live_layer(layer_record):
			continue

		var layer_root := _get_layer_root(layer_record)
		if layer_root == null:
			continue

		var parent_item := _find_parent_item(layer_root, item_by_root_id, root_item)
		var item := _tree.create_item(parent_item)
		var layer_key := _get_layer_key(layer_record)
		item.collapsed = bool(_collapsed_paths.get(layer_key, false))
		item.set_text(0, String(layer_record.get("name", layer_root.name)))
		item.set_text(1, _get_display_path(layer_root))
		item.set_text(2, String(layer_record.get("state", "Open")))
		item.set_tooltip_text(0, String(layer_root.get_path()))
		item.set_tooltip_text(1, String(layer_root.get_path()))
		item.set_metadata(0, layer_record)
		item.set_metadata(1, layer_key)

		var root_key := str(layer_root.get_instance_id())
		item_by_root_id[root_key] = item
		if _is_same_layer(layer_record, _selected_layer):
			item.select(0)

	if not _is_live_layer(_selected_layer):
		_selected_layer = {}
	_update_action_buttons()

func _find_parent_item(layer_root: Node, item_by_root_id: Dictionary, fallback_item: TreeItem) -> TreeItem:
	var ancestor := layer_root.get_parent()
	while ancestor != null:
		var ancestor_key := str(ancestor.get_instance_id())
		if item_by_root_id.has(ancestor_key):
			return item_by_root_id[ancestor_key]
		ancestor = ancestor.get_parent()
	return fallback_item

func _capture_collapsed_state() -> void:
	if _tree == null:
		return

	_collapsed_paths.clear()
	var root_item := _tree.get_root()
	if root_item == null:
		return
	_capture_collapsed_state_for(root_item)

func _capture_collapsed_state_for(item: TreeItem) -> void:
	var child := item.get_first_child()
	while child != null:
		var metadata := child.get_metadata(1)
		if typeof(metadata) == TYPE_STRING:
			var layer_key := String(metadata)
			if not layer_key.is_empty():
				_collapsed_paths[layer_key] = child.collapsed
		_capture_collapsed_state_for(child)
		child = child.get_next()

func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	_selected_layer = _get_item_layer(item)
	_update_action_buttons()
	if focus_on_select:
		_focus_selected_layer()

func _focus_selected_layer() -> void:
	if not _is_live_layer(_selected_layer):
		return
	if _manager != null and is_instance_valid(_manager) and _manager.has_method("focus_layer"):
		_manager.call("focus_layer", _selected_layer)
	_request_refresh()

func _close_selected_layer() -> void:
	if not _is_live_layer(_selected_layer):
		return
	if _manager != null and is_instance_valid(_manager) and _manager.has_method("close_layer"):
		_manager.call("close_layer", _selected_layer)
	_selected_layer = {}
	_request_refresh()

func _reload_selected_layer() -> void:
	if not _is_live_layer(_selected_layer):
		return
	if _manager != null and is_instance_valid(_manager) and _manager.has_method("reload_layer"):
		_manager.call("reload_layer", _selected_layer)
	_selected_layer = {}
	_request_refresh()

func _update_action_buttons() -> void:
	var has_selection := _is_live_layer(_selected_layer)
	if _focus_button != null:
		_focus_button.disabled = not has_selection
	if _close_button != null:
		_close_button.disabled = not has_selection
	if _reload_button != null:
		_reload_button.disabled = not has_selection

func _get_item_layer(item: TreeItem) -> Dictionary:
	if item == null:
		return {}

	var metadata := item.get_metadata(0)
	if typeof(metadata) == TYPE_DICTIONARY and _is_live_layer(metadata):
		return metadata
	return {}

func _is_live_layer(layer_record: Variant) -> bool:
	if typeof(layer_record) != TYPE_DICTIONARY:
		return false
	var root: Variant = (layer_record as Dictionary).get("root")
	return root is Node and is_instance_valid(root) and (root as Node).is_inside_tree()

func _is_same_layer(left: Variant, right: Variant) -> bool:
	if not _is_live_layer(left) or not _is_live_layer(right):
		return false
	return _get_layer_key(left) == _get_layer_key(right)

func _get_layer_root(layer_record: Dictionary) -> Node:
	var root: Variant = layer_record.get("root")
	if root is Node and is_instance_valid(root):
		return root
	return null

func _get_layer_key(layer_record: Dictionary) -> String:
	return String(layer_record.get("key", ""))

func _get_display_path(layer_root: Node) -> String:
	var path := String(layer_root.get_path())
	if path.begins_with("/root/"):
		return path.trim_prefix("/root/")
	return path
