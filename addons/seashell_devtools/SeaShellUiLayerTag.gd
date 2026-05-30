extends Node
class_name SeaShellUiLayerTag

signal layer_changed(tag: Node)

const TAG_GROUP := "sea_shell_selectable_ui_layer"
const MANAGER_GROUP := "sea_shell_ui_layer_manager"

@export var selectable := true:
	set(value):
		selectable = value
		_notify_layer_changed()

@export var layer_name := "":
	set(value):
		layer_name = value
		_notify_layer_changed()

@export var target_path: NodePath = NodePath(""):
	set(value):
		target_path = value
		_notify_layer_changed()

@export var manager_path: NodePath = NodePath(""):
	set(value):
		manager_path = value
		if is_inside_tree():
			call_deferred("_register_when_ready")

@export var focus_method := ""
@export var close_method := "close"
@export var reload_method := "reload"

var _manager: Node
var _registered := false

func _enter_tree() -> void:
	add_to_group(TAG_GROUP)
	call_deferred("_register_when_ready")

func _ready() -> void:
	_register_when_ready()

func _exit_tree() -> void:
	_unregister_from_manager()
	remove_from_group(TAG_GROUP)

func is_selectable_layer() -> bool:
	return selectable

func get_layer_root() -> Node:
	if not String(target_path).strip_edges().is_empty():
		var explicit_target := get_node_or_null(target_path)
		if explicit_target != null:
			return explicit_target
	return get_parent()

func get_display_name() -> String:
	var explicit_name := layer_name.strip_edges()
	if not explicit_name.is_empty():
		return explicit_name

	var layer_root := get_layer_root()
	if layer_root != null:
		return String(layer_root.name)
	return String(name)

func get_layer_path() -> String:
	var layer_root := get_layer_root()
	if layer_root != null and layer_root.is_inside_tree():
		return String(layer_root.get_path())
	if is_inside_tree():
		return String(get_path())
	return ""

func focus_layer() -> bool:
	if _call_layer_method(focus_method):
		return true

	var layer_root := get_layer_root()
	if layer_root == null or not layer_root.is_inside_tree():
		return false

	_show_layer(layer_root)
	_bring_layer_to_front(layer_root)

	var focus_target := _find_focus_target(layer_root)
	if focus_target != null:
		focus_target.grab_focus()
	return true

func close_layer() -> bool:
	if _call_layer_method(close_method):
		return true

	var layer_root := get_layer_root()
	if layer_root == null or not layer_root.is_inside_tree():
		return false

	if layer_root is CanvasItem:
		(layer_root as CanvasItem).hide()
		_notify_layer_changed()
		return true
	if layer_root is CanvasLayer:
		(layer_root as CanvasLayer).visible = false
		_notify_layer_changed()
		return true
	return false

func reload_layer() -> bool:
	if _call_layer_method(reload_method):
		return true

	var layer_root := get_layer_root()
	if layer_root == null or not layer_root.is_inside_tree():
		return false

	var scene_path := String(layer_root.scene_file_path).strip_edges()
	if scene_path.is_empty():
		return false

	var parent := layer_root.get_parent()
	if parent == null:
		return false

	var resource := load(scene_path)
	if not (resource is PackedScene):
		return false

	var original_name := String(layer_root.name)
	var original_index := layer_root.get_index()
	layer_root.name = "%s_Reloading" % original_name

	var replacement := (resource as PackedScene).instantiate()
	replacement.name = original_name
	parent.add_child(replacement)
	parent.move_child(replacement, original_index)
	layer_root.queue_free()
	_notify_layer_changed()
	return true

func _register_when_ready() -> void:
	if not is_inside_tree():
		return

	var resolved_manager := _resolve_manager()
	if resolved_manager == null:
		return

	if resolved_manager == _manager and _registered:
		return

	_unregister_from_manager()
	_manager = resolved_manager
	if _manager.has_method("register_layer"):
		_manager.call("register_layer", self)
		_registered = true

func _unregister_from_manager() -> void:
	if _registered and is_instance_valid(_manager) and _manager.has_method("unregister_layer"):
		_manager.call("unregister_layer", self)
	_manager = null
	_registered = false

func _resolve_manager() -> Node:
	if not String(manager_path).strip_edges().is_empty():
		var explicit_manager := get_node_or_null(manager_path)
		if explicit_manager != null:
			return explicit_manager

	var scene_tree := get_tree()
	if scene_tree == null:
		return null

	var managers := scene_tree.get_nodes_in_group(MANAGER_GROUP)
	return managers[0] if not managers.is_empty() else null

func _notify_layer_changed() -> void:
	layer_changed.emit(self)
	if _registered and is_instance_valid(_manager) and _manager.has_method("notify_layer_changed"):
		_manager.call("notify_layer_changed", self)

func _call_layer_method(method_name: String) -> bool:
	var resolved_method := method_name.strip_edges()
	if resolved_method.is_empty():
		return false

	var layer_root := get_layer_root()
	if layer_root == null or not layer_root.has_method(resolved_method):
		return false

	layer_root.call(resolved_method)
	_notify_layer_changed()
	return true

func _show_layer(layer_root: Node) -> void:
	if layer_root is CanvasItem:
		(layer_root as CanvasItem).show()
	elif layer_root is CanvasLayer:
		(layer_root as CanvasLayer).visible = true

func _bring_layer_to_front(layer_root: Node) -> void:
	if layer_root is CanvasItem:
		(layer_root as CanvasItem).move_to_front()
		return

	var parent := layer_root.get_parent()
	if parent != null:
		parent.move_child(layer_root, parent.get_child_count() - 1)

func _find_focus_target(node: Node) -> Control:
	if node is Control:
		var control := node as Control
		if control.visible and control.focus_mode != Control.FOCUS_NONE:
			return control

	for child in node.get_children():
		var focus_target := _find_focus_target(child)
		if focus_target != null:
			return focus_target
	return null
