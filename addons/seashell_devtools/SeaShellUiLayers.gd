extends Node

const ManagerScript = preload("res://addons/seashell_devtools/SeaShellUiLayerManager.gd")
const DebugPanelScript = preload("res://addons/seashell_devtools/SeaShellUiLayersDebugPanel.gd")

const DEBUG_OVERLAY_SETTING := "seashell_devtools/ui_layers/debug_overlay_enabled"
const UI_LAYERS_RUNTIME_ENABLED_SETTING := "seashell_devtools/subscriptions/ui_layers_runtime_enabled"

var _manager: Node
var _debug_panel: CanvasLayer
var _last_overlay_enabled := false
var _poll_elapsed := 0.0

func _ready() -> void:
	_ensure_manager()
	_apply_debug_overlay_setting()
	set_process(true)

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed < 0.5:
		return

	_poll_elapsed = 0.0
	_apply_debug_overlay_setting()

func get_manager() -> Node:
	_ensure_manager()
	return _manager

func get_debug_panel() -> CanvasLayer:
	return _debug_panel

func refresh_layers() -> void:
	_ensure_manager()
	if _manager.has_method("refresh_layers"):
		_manager.call("refresh_layers")

func get_layers(include_hidden := false) -> Array:
	_ensure_manager()
	if _manager.has_method("get_layers"):
		return _manager.call("get_layers", include_hidden)
	return []

func set_debug_overlay_enabled(enabled: bool) -> void:
	ProjectSettings.set_setting(DEBUG_OVERLAY_SETTING, enabled)
	_apply_debug_overlay_setting()

func _ensure_manager() -> void:
	if _manager != null and is_instance_valid(_manager):
		return

	_manager = ManagerScript.new()
	_manager.name = "SeaShellUiLayerManager"
	add_child(_manager)

func _apply_debug_overlay_setting() -> void:
	var overlay_enabled := _should_show_debug_overlay()
	if overlay_enabled == _last_overlay_enabled and ((overlay_enabled and _debug_panel != null and is_instance_valid(_debug_panel)) or (not overlay_enabled and _debug_panel == null)):
		return

	_last_overlay_enabled = overlay_enabled
	if overlay_enabled:
		_ensure_debug_panel()
	else:
		_remove_debug_panel()

func _should_show_debug_overlay() -> bool:
	if not OS.has_feature("debug"):
		return false
	if not bool(ProjectSettings.get_setting(UI_LAYERS_RUNTIME_ENABLED_SETTING, false)):
		return false
	return bool(ProjectSettings.get_setting(DEBUG_OVERLAY_SETTING, false))

func _ensure_debug_panel() -> void:
	_ensure_manager()
	if _debug_panel != null and is_instance_valid(_debug_panel):
		return

	_debug_panel = DebugPanelScript.new()
	_debug_panel.name = "SeaShellUiLayersDebugPanel"
	_debug_panel.manager_path = NodePath("../SeaShellUiLayerManager")
	_debug_panel.create_manager_if_missing = false
	add_child(_debug_panel)

func _remove_debug_panel() -> void:
	if _debug_panel != null and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	_debug_panel = null
