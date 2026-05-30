extends Node
class_name SeaShellUiLayerManager

signal layers_changed

const TAG_GROUP := "sea_shell_selectable_ui_layer"
const ROOT_GROUP := "sea_shell_selectable_ui_layer_root"
const MANAGER_GROUP := "sea_shell_ui_layer_manager"

const META_LAYER_NAME := "sea_shell_layer_name"
const META_FOCUS_METHOD := "sea_shell_layer_focus_method"
const META_CLOSE_METHOD := "sea_shell_layer_close_method"
const META_RELOAD_METHOD := "sea_shell_layer_reload_method"

@export var include_hidden_layers := false

var _sources: Array = []

func _enter_tree() -> void:
	add_to_group(MANAGER_GROUP)

func _ready() -> void:
	refresh_layers()

func _exit_tree() -> void:
	remove_from_group(MANAGER_GROUP)
	_sources.clear()

func register_layer(tag: Node) -> void:
	if not _is_valid_tag(tag):
		return
	if not _sources.has(tag):
		_sources.append(tag)
		layers_changed.emit()

func unregister_layer(tag: Node) -> void:
	if tag == null:
		return
	if _sources.has(tag):
		_sources.erase(tag)
		layers_changed.emit()

func notify_layer_changed(_tag: Node) -> void:
	layers_changed.emit()

func refresh_layers() -> void:
	_refresh_sources(true)

func get_layers(include_hidden := false) -> Array:
	_refresh_sources(false)

	var records := _build_layer_records()
	var result: Array = []
	var should_include_hidden := include_hidden or include_hidden_layers
	for record in records:
		if not _is_valid_record(record):
			continue
		if not should_include_hidden and not bool(record.get("visible", false)):
			continue
		result.append(record)
	return result

func focus_layer(layer: Variant) -> bool:
	var record := _coerce_layer_record(layer)
	if record.is_empty():
		return false

	var tag := _get_record_tag(record)
	if tag != null and tag.has_method("focus_layer"):
		return bool(tag.call("focus_layer"))

	return _focus_root(
		_get_record_root(record),
		String(record.get("focus_method", ""))
	)

func close_layer(layer: Variant) -> bool:
	var record := _coerce_layer_record(layer)
	if record.is_empty():
		return false

	var tag := _get_record_tag(record)
	if tag != null and tag.has_method("close_layer"):
		return bool(tag.call("close_layer"))

	var closed := _close_root(
		_get_record_root(record),
		String(record.get("close_method", ""))
	)
	if closed:
		layers_changed.emit()
	return closed

func reload_layer(layer: Variant) -> bool:
	var record := _coerce_layer_record(layer)
	if record.is_empty():
		return false

	var tag := _get_record_tag(record)
	if tag != null and tag.has_method("reload_layer"):
		return bool(tag.call("reload_layer"))

	var reloaded := _reload_root(
		_get_record_root(record),
		String(record.get("reload_method", ""))
	)
	if reloaded:
		layers_changed.emit()
	return reloaded

func _refresh_sources(emit_change: bool) -> void:
	var previous_key := _build_sources_key(_sources)
	var next_sources: Array = []

	var scene_tree := get_tree()
	if scene_tree != null:
		for node in scene_tree.get_nodes_in_group(TAG_GROUP):
			if _is_valid_tag(node):
				next_sources.append(node)

		for node in scene_tree.get_nodes_in_group(ROOT_GROUP):
			if _is_valid_group_root(node):
				next_sources.append(node)

	next_sources.sort_custom(_compare_sources)
	_sources = next_sources

	if emit_change and previous_key != _build_sources_key(_sources):
		layers_changed.emit()

func _build_layer_records() -> Array:
	var records: Array = []
	var tagged_root_ids := {}

	for source in _sources:
		if not _is_valid_tag(source):
			continue

		var record := _build_tag_record(source)
		if record.is_empty():
			continue

		records.append(record)
		tagged_root_ids[str((_get_record_root(record) as Node).get_instance_id())] = true

	for source in _sources:
		if not _is_valid_group_root(source):
			continue
		var root := source as Node
		if tagged_root_ids.has(str(root.get_instance_id())):
			continue

		var record := _build_group_record(root)
		if not record.is_empty():
			records.append(record)

	records.sort_custom(_compare_records)
	return records

func _build_tag_record(tag: Node) -> Dictionary:
	var root: Variant = tag.call("get_layer_root")
	if not _is_live_node(root):
		return {}

	var display_name := String(root.name)
	if tag.has_method("get_display_name"):
		display_name = String(tag.call("get_display_name"))

	return {
		"kind": "tag",
		"key": "tag:%s" % (root as Node).get_instance_id(),
		"tag": tag,
		"root": root,
		"name": display_name,
		"path": String((root as Node).get_path()),
		"sort_path": String((root as Node).get_path()),
		"visible": _is_root_visible(root),
		"state": _get_visible_state(root),
	}

func _build_group_record(root: Node) -> Dictionary:
	return {
		"kind": "group",
		"key": "group:%s" % root.get_instance_id(),
		"tag": null,
		"root": root,
		"name": _get_meta_string(root, META_LAYER_NAME, String(root.name)),
		"path": String(root.get_path()),
		"sort_path": String(root.get_path()),
		"visible": _is_root_visible(root),
		"state": _get_visible_state(root),
		"focus_method": _get_meta_string(root, META_FOCUS_METHOD, ""),
		"close_method": _get_meta_string(root, META_CLOSE_METHOD, ""),
		"reload_method": _get_meta_string(root, META_RELOAD_METHOD, ""),
	}

func _coerce_layer_record(layer: Variant) -> Dictionary:
	if typeof(layer) == TYPE_DICTIONARY:
		var record: Dictionary = layer
		return record if _is_valid_record(record) else {}

	if layer is Node:
		if _is_valid_tag(layer):
			return _build_tag_record(layer)
		if _is_valid_group_root(layer):
			return _build_group_record(layer)

	return {}

func _is_valid_record(record: Dictionary) -> bool:
	return _is_live_node(record.get("root"))

func _is_valid_tag(tag: Variant) -> bool:
	if not _is_live_node(tag):
		return false
	var node := tag as Node
	if not node.has_method("get_layer_root"):
		return false
	if node.has_method("is_selectable_layer") and not bool(node.call("is_selectable_layer")):
		return false
	return _is_live_node(node.call("get_layer_root"))

func _is_valid_group_root(root: Variant) -> bool:
	if not _is_live_node(root):
		return false
	return (root as Node).is_in_group(ROOT_GROUP)

func _is_live_node(value: Variant) -> bool:
	return value is Node and is_instance_valid(value) and (value as Node).is_inside_tree()

func _get_record_root(record: Dictionary) -> Node:
	var root: Variant = record.get("root")
	return root if _is_live_node(root) else null

func _get_record_tag(record: Dictionary) -> Node:
	var tag: Variant = record.get("tag")
	return tag if _is_live_node(tag) else null

func _focus_root(root: Node, method_name: String) -> bool:
	if not _is_live_node(root):
		return false
	if _call_root_method(root, method_name):
		return true

	_show_root(root)
	_bring_root_to_front(root)

	var focus_target := _find_focus_target(root)
	if focus_target != null:
		focus_target.grab_focus()
	return true

func _close_root(root: Node, method_name: String) -> bool:
	if not _is_live_node(root):
		return false
	if _call_root_method(root, method_name):
		return true

	if root is CanvasItem:
		(root as CanvasItem).hide()
		return true
	if root is CanvasLayer:
		(root as CanvasLayer).visible = false
		return true
	return false

func _reload_root(root: Node, method_name: String) -> bool:
	if not _is_live_node(root):
		return false
	if _call_root_method(root, method_name):
		return true

	var scene_path := String(root.scene_file_path).strip_edges()
	if scene_path.is_empty():
		return false

	var parent := root.get_parent()
	if parent == null:
		return false

	var resource := load(scene_path)
	if not (resource is PackedScene):
		return false

	var original_name := String(root.name)
	var original_index := root.get_index()
	root.name = "%s_Reloading" % original_name

	var replacement := (resource as PackedScene).instantiate()
	replacement.name = original_name
	parent.add_child(replacement)
	parent.move_child(replacement, original_index)
	root.queue_free()
	return true

func _call_root_method(root: Node, method_name: String) -> bool:
	var resolved_method := method_name.strip_edges()
	if resolved_method.is_empty() or not root.has_method(resolved_method):
		return false
	root.call(resolved_method)
	return true

func _show_root(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).show()
	elif root is CanvasLayer:
		(root as CanvasLayer).visible = true

func _bring_root_to_front(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).move_to_front()
		return

	var parent := root.get_parent()
	if parent != null:
		parent.move_child(root, parent.get_child_count() - 1)

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

func _is_root_visible(root: Node) -> bool:
	if root is CanvasItem:
		return (root as CanvasItem).is_visible_in_tree()
	if root is CanvasLayer:
		return (root as CanvasLayer).visible
	return true

func _get_visible_state(root: Node) -> String:
	if root is CanvasItem:
		return "Visible" if (root as CanvasItem).is_visible_in_tree() else "Hidden"
	if root is CanvasLayer:
		return "Visible" if (root as CanvasLayer).visible else "Hidden"
	return "Open"

func _get_meta_string(node: Node, meta_name: String, fallback: String) -> String:
	if not node.has_meta(meta_name):
		return fallback
	var value := String(node.get_meta(meta_name)).strip_edges()
	return value if not value.is_empty() else fallback

func _compare_sources(left: Node, right: Node) -> bool:
	return _get_source_sort_path(left).nocasecmp_to(_get_source_sort_path(right)) < 0

func _compare_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("sort_path", "")).nocasecmp_to(String(right.get("sort_path", ""))) < 0

func _get_source_sort_path(source: Node) -> String:
	if _is_valid_tag(source):
		var root: Variant = source.call("get_layer_root")
		if _is_live_node(root):
			return String((root as Node).get_path())
	if source.is_inside_tree():
		return String(source.get_path())
	return str(source.get_instance_id())

func _build_sources_key(sources: Array) -> String:
	var key := ""
	for source in sources:
		if source is Node and is_instance_valid(source):
			if not key.is_empty():
				key += "|"
			key += "%s:%s" % [
				"tag" if _is_valid_tag(source) else "group",
				(source as Node).get_instance_id(),
			]
	return key
