@tool
extends EditorPlugin

const OPEN_DOCK_ID := 1
const BUILD_ACTIVE_PROFILE_ID := 2
const RESYNC_ID := 3
const TOGGLE_UI_LAYERS_OVERLAY_ID := 4
const REBUILD_EMERALD_EDITOR_ASSETS_ID := 5
const COMPILE_CURRENT_EDITOR_MAP_ID := 6
const OPEN_SETTINGS_BROWSER_ID := 7
const OPEN_SETTINGS_CONFIG_ID := 8
const TOGGLE_SETTINGS_RUNTIME_ID := 9
const TOGGLE_UI_LAYERS_RUNTIME_ID := 10
const TOGGLE_FEEDBACK_RUNTIME_ID := 11
const TOGGLE_PERFORMANCE_RUNTIME_ID := 12
const TOGGLE_PERFORMANCE_OVERLAY_ID := 13

const MENU_NAME := "Sea Shell Tools"
const DOCK_SCRIPT_PATH := "res://addons/seashell_devtools/SeaShellDevToolsDock.gd"
const SETTINGS_DOCK_SCRIPT_PATH := "res://addons/seashell_devtools/settings/ui/SeaShellSettingsDock.gd"
const LINK_SCRIPT_RES_PATH := "res://tools/link-addon.ps1"
const LINK_METADATA_RES_PATH := "res://addons/seashell_devtools.link.json"

const UI_LAYERS_AUTOLOAD_NAME := "SeaShellUiLayers"
const UI_LAYERS_AUTOLOAD_PATH := "res://addons/seashell_devtools/SeaShellUiLayers.gd"
const UI_LAYERS_AUTOLOAD_SETTING := "autoload/SeaShellUiLayers"
const UI_LAYERS_DEBUG_OVERLAY_SETTING := "seashell_devtools/ui_layers/debug_overlay_enabled"
const SETTINGS_AUTOLOAD_NAME := "SeaShellSettings"
const SETTINGS_AUTOLOAD_PATH := "res://addons/seashell_devtools/settings/SeaShellSettings.gd"
const SETTINGS_AUTOLOAD_SETTING := "autoload/SeaShellSettings"
const SETTINGS_PACK_PATHS_SETTING := "seashell_devtools/settings/pack_paths"
const SETTINGS_REGISTRY_PATH_SETTING := "seashell_devtools/settings/registry_path"
const SETTINGS_STORE_SCRIPT_PATH_SETTING := "seashell_devtools/settings/store_script_path"
const SETTINGS_VALUE_STORE_PATH_SETTING := "seashell_devtools/settings/value_store_path"
const SETTINGS_DEFAULT_PACK_PATHS := [
	"res://addons/seashell_devtools/settings/packs/SeaShellDevToolsSettings.tres",
	"res://addons/seashell_devtools/settings/packs/SeaShellCommonGameSettings.tres",
]
const SETTINGS_DEFAULT_REGISTRY_PATH := "res://addons/seashell_devtools/settings/packs/SeaShellDefaultSettingsRegistry.tres"
const SETTINGS_DEFAULT_VALUE_STORE_PATH := "user://sea_shell_settings_values.json"
const FEEDBACK_AUTOLOAD_NAME := "SeaShellFeedback"
const FEEDBACK_AUTOLOAD_PATH := "res://addons/seashell_devtools/feedback/SeaShellFeedback.gd"
const FEEDBACK_AUTOLOAD_SETTING := "autoload/SeaShellFeedback"
const PERFORMANCE_AUTOLOAD_NAME := "SeaShellPerformance"
const PERFORMANCE_AUTOLOAD_PATH := "res://addons/seashell_devtools/performance/SeaShellPerformance.gd"
const PERFORMANCE_AUTOLOAD_SETTING := "autoload/SeaShellPerformance"
const PERFORMANCE_DEBUG_OVERLAY_SETTING := "seashell_devtools/performance/debug_overlay_enabled"
const SETTINGS_RUNTIME_ENABLED_SETTING := "seashell_devtools/subscriptions/settings_runtime_enabled"
const UI_LAYERS_RUNTIME_ENABLED_SETTING := "seashell_devtools/subscriptions/ui_layers_runtime_enabled"
const FEEDBACK_RUNTIME_ENABLED_SETTING := "seashell_devtools/subscriptions/feedback_runtime_enabled"
const PERFORMANCE_RUNTIME_ENABLED_SETTING := "seashell_devtools/subscriptions/performance_runtime_enabled"

const EMERALD_MAP_IMPORTER_PATH := "res://scripts/importing/emerald_map_importer.gd"
const EDITOR_MAP_RUNTIME_COMPILER_PATH := "res://scripts/importing/editor_map_runtime_compiler.gd"

var _dock
var _settings_dock
var _tools_menu: PopupMenu

func _enable_plugin() -> void:
	_ensure_project_subscriptions()

func _disable_plugin() -> void:
	var changed := false
	if _remove_ui_layers_autoload_if_owned():
		changed = true
	if _remove_settings_autoload_if_owned():
		changed = true
	if _remove_feedback_autoload_if_owned():
		changed = true
	if _remove_performance_autoload_if_owned():
		changed = true
	if changed:
		ProjectSettings.save()

func _enter_tree() -> void:
	_ensure_project_subscriptions()

	var dock_script = load(DOCK_SCRIPT_PATH)
	if dock_script == null or not (dock_script is Script) or not dock_script.can_instantiate():
		push_error("Sea Shell DevTools could not instantiate SeaShellDevToolsDock.gd. The addon files in this project may be out of date or one of the dock dependencies failed to compile.")
		return

	_dock = dock_script.new()
	_dock.initialize(self)
	add_dock(_dock)

	var settings_dock_script = load(SETTINGS_DOCK_SCRIPT_PATH)
	if settings_dock_script == null or not (settings_dock_script is Script) or not settings_dock_script.can_instantiate():
		push_warning("Sea Shell DevTools could not instantiate the Settings browser dock at '%s'." % SETTINGS_DOCK_SCRIPT_PATH)
	else:
		_settings_dock = settings_dock_script.new()
		add_dock(_settings_dock)

	_tools_menu = PopupMenu.new()
	_tools_menu.id_pressed.connect(_on_tools_menu_pressed)
	_build_tools_menu()
	add_tool_submenu_item(MENU_NAME, _tools_menu)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)

	if is_instance_valid(_tools_menu):
		_tools_menu.queue_free()
		_tools_menu = null

	if is_instance_valid(_dock):
		if _dock.has_method("shutdown_runtime"):
			_dock.shutdown_runtime()
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null

	if is_instance_valid(_settings_dock):
		remove_dock(_settings_dock)
		_settings_dock.queue_free()
		_settings_dock = null

func _build_tools_menu() -> void:
	if _tools_menu == null:
		return

	_tools_menu.clear()
	_tools_menu.add_item("Open Dock", OPEN_DOCK_ID)
	_tools_menu.add_item("Open Settings Browser", OPEN_SETTINGS_BROWSER_ID)
	_tools_menu.add_item("Open Settings Configuration", OPEN_SETTINGS_CONFIG_ID)
	_tools_menu.add_item("Build Active Profile", BUILD_ACTIVE_PROFILE_ID)
	_tools_menu.add_item("Resync", RESYNC_ID)
	_tools_menu.add_separator()
	_tools_menu.add_check_item("Enable Settings Runtime", TOGGLE_SETTINGS_RUNTIME_ID)
	_tools_menu.add_check_item("Enable UI Layers Runtime", TOGGLE_UI_LAYERS_RUNTIME_ID)
	_tools_menu.add_check_item("Enable Feedback Runtime", TOGGLE_FEEDBACK_RUNTIME_ID)
	_tools_menu.add_check_item("Enable Performance Runtime", TOGGLE_PERFORMANCE_RUNTIME_ID)
	if _is_ui_layers_runtime_enabled():
		_tools_menu.add_check_item("Show Layers Overlay In Debug Runs", TOGGLE_UI_LAYERS_OVERLAY_ID)
	if _is_performance_runtime_enabled():
		_tools_menu.add_check_item("Show Performance Overlay In Debug Runs", TOGGLE_PERFORMANCE_OVERLAY_ID)

	if _optional_script_exists(EMERALD_MAP_IMPORTER_PATH) or _optional_script_exists(EDITOR_MAP_RUNTIME_COMPILER_PATH):
		_tools_menu.add_separator()
		if _optional_script_exists(EMERALD_MAP_IMPORTER_PATH):
			_tools_menu.add_item("Rebuild Emerald Editor Assets", REBUILD_EMERALD_EDITOR_ASSETS_ID)
		if _optional_script_exists(EDITOR_MAP_RUNTIME_COMPILER_PATH):
			_tools_menu.add_item("Compile Current Editor Map", COMPILE_CURRENT_EDITOR_MAP_ID)

	_update_runtime_subscription_menu_items()
	_update_ui_layers_menu_item()

func _on_tools_menu_pressed(id: int) -> void:
	match id:
		OPEN_DOCK_ID:
			_dock.open_dock()
		OPEN_SETTINGS_BROWSER_ID:
			_open_settings_browser()
		OPEN_SETTINGS_CONFIG_ID:
			_open_settings_configuration()
		BUILD_ACTIVE_PROFILE_ID:
			_dock.build_active_profile_from_menu()
		RESYNC_ID:
			_run_resync()
		TOGGLE_SETTINGS_RUNTIME_ID:
			_toggle_settings_runtime_subscription()
		TOGGLE_UI_LAYERS_RUNTIME_ID:
			_toggle_ui_layers_runtime_subscription()
		TOGGLE_FEEDBACK_RUNTIME_ID:
			_toggle_feedback_runtime_subscription()
		TOGGLE_PERFORMANCE_RUNTIME_ID:
			_toggle_performance_runtime_subscription()
		TOGGLE_UI_LAYERS_OVERLAY_ID:
			_toggle_ui_layers_debug_overlay()
		TOGGLE_PERFORMANCE_OVERLAY_ID:
			_toggle_performance_debug_overlay()
		REBUILD_EMERALD_EDITOR_ASSETS_ID:
			_rebuild_emerald_editor_assets()
		COMPILE_CURRENT_EDITOR_MAP_ID:
			_compile_current_editor_map()

func _ensure_project_subscriptions() -> void:
	var changed := _ensure_subscription_project_settings()
	var settings_enabled := _is_settings_runtime_enabled()
	var ui_layers_enabled := _is_ui_layers_runtime_enabled()
	var feedback_enabled := _is_feedback_runtime_enabled()
	var performance_enabled := _is_performance_runtime_enabled()

	if (feedback_enabled or performance_enabled) and not settings_enabled:
		ProjectSettings.set_setting(SETTINGS_RUNTIME_ENABLED_SETTING, true)
		settings_enabled = true
		changed = true

	if ui_layers_enabled:
		if _ensure_ui_layers_subscription():
			changed = true
	else:
		if _remove_ui_layers_autoload_if_owned():
			changed = true

	if settings_enabled:
		if _ensure_settings_subscription():
			changed = true
	else:
		if _remove_settings_autoload_if_owned():
			changed = true

	if feedback_enabled:
		if _ensure_feedback_subscription():
			changed = true
	else:
		if _remove_feedback_autoload_if_owned():
			changed = true

	if performance_enabled:
		if _ensure_performance_subscription():
			changed = true
	else:
		if _remove_performance_autoload_if_owned():
			changed = true

	if changed:
		ProjectSettings.save()
	_update_runtime_subscription_menu_items()
	_update_ui_layers_menu_item()
	_update_performance_menu_item()

func _ensure_subscription_project_settings() -> bool:
	var changed := false
	for setting_name in [SETTINGS_RUNTIME_ENABLED_SETTING, UI_LAYERS_RUNTIME_ENABLED_SETTING, FEEDBACK_RUNTIME_ENABLED_SETTING, PERFORMANCE_RUNTIME_ENABLED_SETTING]:
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, false)
			changed = true
		ProjectSettings.add_property_info({"name": setting_name, "type": TYPE_BOOL})
	return changed

func _ensure_ui_layers_subscription() -> bool:
	var changed := _ensure_ui_layers_debug_overlay_setting()
	if _ensure_autoload(UI_LAYERS_AUTOLOAD_NAME, UI_LAYERS_AUTOLOAD_PATH, UI_LAYERS_AUTOLOAD_SETTING):
		changed = true
	_update_ui_layers_menu_item()
	return changed

func _ensure_ui_layers_debug_overlay_setting() -> bool:
	var changed := false
	if not ProjectSettings.has_setting(UI_LAYERS_DEBUG_OVERLAY_SETTING):
		ProjectSettings.set_setting(UI_LAYERS_DEBUG_OVERLAY_SETTING, false)
		changed = true

	ProjectSettings.add_property_info({
		"name": UI_LAYERS_DEBUG_OVERLAY_SETTING,
		"type": TYPE_BOOL,
	})
	return changed

func _ensure_settings_subscription() -> bool:
	var changed := _ensure_settings_project_settings()
	if _ensure_autoload(SETTINGS_AUTOLOAD_NAME, SETTINGS_AUTOLOAD_PATH, SETTINGS_AUTOLOAD_SETTING):
		changed = true
	return changed

func _ensure_settings_project_settings() -> bool:
	var changed := false
	if not ProjectSettings.has_setting(SETTINGS_PACK_PATHS_SETTING):
		ProjectSettings.set_setting(SETTINGS_PACK_PATHS_SETTING, PackedStringArray(SETTINGS_DEFAULT_PACK_PATHS))
		changed = true
	if not ProjectSettings.has_setting(SETTINGS_REGISTRY_PATH_SETTING):
		ProjectSettings.set_setting(SETTINGS_REGISTRY_PATH_SETTING, SETTINGS_DEFAULT_REGISTRY_PATH)
		changed = true
	if not ProjectSettings.has_setting(SETTINGS_STORE_SCRIPT_PATH_SETTING):
		ProjectSettings.set_setting(SETTINGS_STORE_SCRIPT_PATH_SETTING, "")
		changed = true
	if not ProjectSettings.has_setting(SETTINGS_VALUE_STORE_PATH_SETTING):
		ProjectSettings.set_setting(SETTINGS_VALUE_STORE_PATH_SETTING, SETTINGS_DEFAULT_VALUE_STORE_PATH)
		changed = true
	ProjectSettings.add_property_info({"name": SETTINGS_PACK_PATHS_SETTING, "type": TYPE_PACKED_STRING_ARRAY})
	ProjectSettings.add_property_info({"name": SETTINGS_REGISTRY_PATH_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tres,*.res"})
	ProjectSettings.add_property_info({"name": SETTINGS_STORE_SCRIPT_PATH_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.gd"})
	ProjectSettings.add_property_info({"name": SETTINGS_VALUE_STORE_PATH_SETTING, "type": TYPE_STRING})
	return changed

func _ensure_feedback_subscription() -> bool:
	var changed := _ensure_autoload(FEEDBACK_AUTOLOAD_NAME, FEEDBACK_AUTOLOAD_PATH, FEEDBACK_AUTOLOAD_SETTING)
	return changed

func _ensure_performance_subscription() -> bool:
	var changed := _ensure_performance_debug_overlay_setting()
	if _ensure_autoload(PERFORMANCE_AUTOLOAD_NAME, PERFORMANCE_AUTOLOAD_PATH, PERFORMANCE_AUTOLOAD_SETTING):
		changed = true
	_update_performance_menu_item()
	return changed

func _ensure_performance_debug_overlay_setting() -> bool:
	var changed := false
	if not ProjectSettings.has_setting(PERFORMANCE_DEBUG_OVERLAY_SETTING):
		ProjectSettings.set_setting(PERFORMANCE_DEBUG_OVERLAY_SETTING, false)
		changed = true
	ProjectSettings.add_property_info({
		"name": PERFORMANCE_DEBUG_OVERLAY_SETTING,
		"type": TYPE_BOOL,
	})
	return changed

func _ensure_autoload(autoload_name: String, autoload_path: String, autoload_setting: String) -> bool:
	if not ResourceLoader.exists(autoload_path):
		push_error("Sea Shell DevTools could not find autoload script '%s' at '%s'." % [autoload_name, autoload_path])
		return false

	var current_value := String(ProjectSettings.get_setting(autoload_setting, "")).strip_edges()
	if current_value == "*%s" % autoload_path:
		return false

	var normalized_current := _normalize_autoload_value(current_value)
	if normalized_current.is_empty():
		add_autoload_singleton(autoload_name, autoload_path)
		return true

	if normalized_current == autoload_path:
		if current_value.begins_with("*"):
			return false
		remove_autoload_singleton(autoload_name)
		add_autoload_singleton(autoload_name, autoload_path)
		return true

	push_warning("Sea Shell DevTools did not replace autoload '%s' because it points at '%s' instead of '%s'." % [autoload_name, normalized_current, autoload_path])
	return false

func _remove_ui_layers_autoload_if_owned() -> bool:
	return _remove_autoload_if_owned(UI_LAYERS_AUTOLOAD_NAME, UI_LAYERS_AUTOLOAD_PATH, UI_LAYERS_AUTOLOAD_SETTING)

func _remove_settings_autoload_if_owned() -> bool:
	return _remove_autoload_if_owned(SETTINGS_AUTOLOAD_NAME, SETTINGS_AUTOLOAD_PATH, SETTINGS_AUTOLOAD_SETTING)

func _remove_feedback_autoload_if_owned() -> bool:
	return _remove_autoload_if_owned(FEEDBACK_AUTOLOAD_NAME, FEEDBACK_AUTOLOAD_PATH, FEEDBACK_AUTOLOAD_SETTING)

func _remove_performance_autoload_if_owned() -> bool:
	return _remove_autoload_if_owned(PERFORMANCE_AUTOLOAD_NAME, PERFORMANCE_AUTOLOAD_PATH, PERFORMANCE_AUTOLOAD_SETTING)

func _remove_autoload_if_owned(autoload_name: String, autoload_path: String, autoload_setting: String) -> bool:
	var current_value := String(ProjectSettings.get_setting(autoload_setting, "")).strip_edges()
	if _normalize_autoload_value(current_value) != autoload_path:
		return false

	remove_autoload_singleton(autoload_name)
	return true

func _normalize_autoload_value(value: String) -> String:
	var normalized := value.strip_edges().trim_prefix("*").strip_edges()
	if normalized.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(normalized)
		if uid != -1:
			var uid_path := ResourceUID.get_id_path(uid)
			if not uid_path.is_empty():
				return uid_path
	return normalized

func _toggle_settings_runtime_subscription() -> void:
	_set_runtime_subscription(SETTINGS_RUNTIME_ENABLED_SETTING, not _is_settings_runtime_enabled())

func _toggle_ui_layers_runtime_subscription() -> void:
	_set_runtime_subscription(UI_LAYERS_RUNTIME_ENABLED_SETTING, not _is_ui_layers_runtime_enabled())

func _toggle_feedback_runtime_subscription() -> void:
	var next_enabled := not _is_feedback_runtime_enabled()
	if next_enabled:
		ProjectSettings.set_setting(SETTINGS_RUNTIME_ENABLED_SETTING, true)
	ProjectSettings.set_setting(FEEDBACK_RUNTIME_ENABLED_SETTING, next_enabled)
	_ensure_project_subscriptions()
	_build_tools_menu()

func _toggle_performance_runtime_subscription() -> void:
	var next_enabled := not _is_performance_runtime_enabled()
	if next_enabled:
		ProjectSettings.set_setting(SETTINGS_RUNTIME_ENABLED_SETTING, true)
	ProjectSettings.set_setting(PERFORMANCE_RUNTIME_ENABLED_SETTING, next_enabled)
	_ensure_project_subscriptions()
	_build_tools_menu()

func _set_runtime_subscription(setting_name: String, enabled: bool) -> void:
	ProjectSettings.set_setting(setting_name, enabled)
	if setting_name == SETTINGS_RUNTIME_ENABLED_SETTING and not enabled and _is_feedback_runtime_enabled():
		ProjectSettings.set_setting(FEEDBACK_RUNTIME_ENABLED_SETTING, false)
	if setting_name == SETTINGS_RUNTIME_ENABLED_SETTING and not enabled and _is_performance_runtime_enabled():
		ProjectSettings.set_setting(PERFORMANCE_RUNTIME_ENABLED_SETTING, false)
	_ensure_project_subscriptions()
	_build_tools_menu()

func _is_settings_runtime_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTINGS_RUNTIME_ENABLED_SETTING, false))

func _is_ui_layers_runtime_enabled() -> bool:
	return bool(ProjectSettings.get_setting(UI_LAYERS_RUNTIME_ENABLED_SETTING, false))

func _is_feedback_runtime_enabled() -> bool:
	return bool(ProjectSettings.get_setting(FEEDBACK_RUNTIME_ENABLED_SETTING, false))

func _is_performance_runtime_enabled() -> bool:
	return bool(ProjectSettings.get_setting(PERFORMANCE_RUNTIME_ENABLED_SETTING, false))

func _update_runtime_subscription_menu_items() -> void:
	if _tools_menu == null:
		return
	var settings_index := _tools_menu.get_item_index(TOGGLE_SETTINGS_RUNTIME_ID)
	if settings_index >= 0:
		_tools_menu.set_item_checked(settings_index, _is_settings_runtime_enabled())
	var layers_index := _tools_menu.get_item_index(TOGGLE_UI_LAYERS_RUNTIME_ID)
	if layers_index >= 0:
		_tools_menu.set_item_checked(layers_index, _is_ui_layers_runtime_enabled())
	var feedback_index := _tools_menu.get_item_index(TOGGLE_FEEDBACK_RUNTIME_ID)
	if feedback_index >= 0:
		_tools_menu.set_item_checked(feedback_index, _is_feedback_runtime_enabled())
	var performance_index := _tools_menu.get_item_index(TOGGLE_PERFORMANCE_RUNTIME_ID)
	if performance_index >= 0:
		_tools_menu.set_item_checked(performance_index, _is_performance_runtime_enabled())

func _toggle_ui_layers_debug_overlay() -> void:
	if not _is_ui_layers_runtime_enabled():
		OS.alert("Enable the UI Layers runtime before showing the Layers overlay.", MENU_NAME)
		return
	var next_enabled := not _is_ui_layers_debug_overlay_enabled()
	ProjectSettings.set_setting(UI_LAYERS_DEBUG_OVERLAY_SETTING, next_enabled)
	ProjectSettings.save()
	_update_ui_layers_menu_item()

	var state := "enabled" if next_enabled else "disabled"
	OS.alert("The Layers overlay is now %s for editor play and debug exports. Restart the current play session if one is already running." % state, MENU_NAME)

func _is_ui_layers_debug_overlay_enabled() -> bool:
	return _is_ui_layers_runtime_enabled() and bool(ProjectSettings.get_setting(UI_LAYERS_DEBUG_OVERLAY_SETTING, false))

func _update_ui_layers_menu_item() -> void:
	if _tools_menu == null:
		return

	var index := _tools_menu.get_item_index(TOGGLE_UI_LAYERS_OVERLAY_ID)
	if index >= 0:
		_tools_menu.set_item_checked(index, _is_ui_layers_debug_overlay_enabled())

func _toggle_performance_debug_overlay() -> void:
	if not _is_performance_runtime_enabled():
		OS.alert("Enable the Performance runtime before showing the Performance overlay.", MENU_NAME)
		return
	var next_enabled := not _is_performance_debug_overlay_enabled()
	ProjectSettings.set_setting(PERFORMANCE_DEBUG_OVERLAY_SETTING, next_enabled)
	ProjectSettings.save()
	_update_performance_menu_item()

	var state := "enabled" if next_enabled else "disabled"
	OS.alert("The Performance overlay is now %s for editor play and debug exports. Restart the current play session if one is already running." % state, MENU_NAME)

func _is_performance_debug_overlay_enabled() -> bool:
	return _is_performance_runtime_enabled() and bool(ProjectSettings.get_setting(PERFORMANCE_DEBUG_OVERLAY_SETTING, false))

func _update_performance_menu_item() -> void:
	if _tools_menu == null:
		return
	var index := _tools_menu.get_item_index(TOGGLE_PERFORMANCE_OVERLAY_ID)
	if index >= 0:
		_tools_menu.set_item_checked(index, _is_performance_debug_overlay_enabled())

func _open_settings_browser() -> void:
	if is_instance_valid(_settings_dock):
		if _settings_dock.has_method("open_dock"):
			_settings_dock.open_dock()
		return
	OS.alert("The Sea Shell Settings browser dock is not available in this project.", MENU_NAME)

func _open_settings_configuration() -> void:
	var editor_interface := get_editor_interface()
	if editor_interface != null and editor_interface.has_method("popup_project_settings"):
		editor_interface.call("popup_project_settings")
	OS.alert(
		"Sea Shell Settings project settings:\n\n%s\n%s\n%s\n%s" % [
			SETTINGS_PACK_PATHS_SETTING,
			SETTINGS_REGISTRY_PATH_SETTING,
			SETTINGS_STORE_SCRIPT_PATH_SETTING,
			SETTINGS_VALUE_STORE_PATH_SETTING,
		],
		MENU_NAME
	)

func _optional_script_exists(script_path: String) -> bool:
	return ResourceLoader.exists(script_path) or FileAccess.file_exists(ProjectSettings.globalize_path(script_path))

func _load_optional_script(script_path: String, label: String) -> Script:
	var script_resource = load(script_path)
	if script_resource == null or not (script_resource is Script) or not script_resource.can_instantiate():
		OS.alert("%s is not available in this project.\n\nExpected: %s" % [label, script_path], MENU_NAME)
		return null
	return script_resource

func _run_resync() -> void:
	if OS.get_name() != "Windows":
		OS.alert("Resync is currently supported on Windows hosts only.", MENU_NAME)
		return

	var current_project_root := ProjectSettings.globalize_path("res://")
	var current_project_link_script := ProjectSettings.globalize_path(LINK_SCRIPT_RES_PATH)
	if FileAccess.file_exists(current_project_link_script):
		_run_link_script(
			current_project_link_script,
			PackedStringArray(["-UseRegisteredProjects", "-EnablePlugin", "-Force"]),
			"registered linked projects",
			true
		)
		return

	var metadata := _load_link_metadata()
	if metadata.is_empty():
		OS.alert("Resync metadata was not found for this project. Run the source repo's tools/link-addon.ps1 once so this project is registered for menu resync.", MENU_NAME)
		return

	var link_script_path := String(metadata.get("linkScriptPath", "")).simplify_path()
	if link_script_path.is_empty() or not FileAccess.file_exists(link_script_path):
		OS.alert("This project has resync metadata, but the source repo link script could not be found at:\n%s" % link_script_path, MENU_NAME)
		return

	_run_link_script(
		link_script_path,
		PackedStringArray(["-ProjectPaths", current_project_root, "-EnablePlugin", "-Force"]),
		"this project",
		false
	)

func _run_link_script(link_script_path: String, script_args: PackedStringArray, target_description: String, expect_restart_for_others: bool) -> void:
	var args := PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", link_script_path])
	for argument in script_args:
		args.append(String(argument))

	var output: Array = []
	var exit_code := OS.execute("powershell.exe", args, output, true)
	var details := "\n".join(output).strip_edges()
	if exit_code != 0:
		var error_message := "Resync failed for %s." % target_description
		if not details.is_empty():
			error_message += "\n\n%s" % details
		OS.alert(error_message, MENU_NAME)
		return

	var success_message := "Resync finished for %s." % target_description
	if not details.is_empty():
		success_message += "\n\n%s" % details
	if expect_restart_for_others:
		success_message += "\n\nReopen any consumer projects that were using stale addon files."
	else:
		success_message += "\n\nReopen this project if the editor is still holding old addon scripts."
	OS.alert(success_message, MENU_NAME)

	if is_instance_valid(_dock) and _dock.has_method("refresh_data"):
		_dock.call_deferred("refresh_data")

func _load_link_metadata() -> Dictionary:
	var metadata_path := ProjectSettings.globalize_path(LINK_METADATA_RES_PATH)
	if not FileAccess.file_exists(metadata_path):
		return {}

	var raw := FileAccess.get_file_as_string(metadata_path)
	if raw.strip_edges().is_empty():
		return {}

	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _rebuild_emerald_editor_assets() -> void:
	var importer_script := _load_optional_script(EMERALD_MAP_IMPORTER_PATH, "Emerald map importer")
	if importer_script == null:
		return

	var source_root := ProjectSettings.globalize_path("res://../pret-pokeemerald")
	if not DirAccess.dir_exists_absolute(source_root):
		OS.alert("pret-pokeemerald source root was not found at:\n%s" % source_root, MENU_NAME)
		return

	var importer = importer_script.new()
	var result: Dictionary = importer.import_source({
		"alias": "pret_emerald",
		"kind": "emerald",
		"source_root": source_root,
	}, {
		"profile": "overworld_plus_interiors",
		"resume": true,
		"prune_maps": false,
		"build_editor_authoring": true,
	})
	if not bool(result.get("ok", false)):
		OS.alert("Emerald editor asset rebuild failed.\n\n%s" % str(result.get("message", "unknown error")), MENU_NAME)
		return
	var authoring_result := Dictionary(result.get("editor_authoring_result", {})).duplicate(true)
	OS.alert(
		"Emerald editor asset rebuild finished.\n\nPairs: %s\nEditor scenes: %s\n\n%s" % [
			int(authoring_result.get("pair_count", 0)),
			int(authoring_result.get("map_count", 0)),
			str(result.get("message", "")),
		],
		MENU_NAME
	)

func _compile_current_editor_map() -> void:
	var compiler_script := _load_optional_script(EDITOR_MAP_RUNTIME_COMPILER_PATH, "Editor map runtime compiler")
	if compiler_script == null:
		return

	var editor_interface := get_editor_interface()
	if editor_interface == null:
		OS.alert("Editor interface was unavailable.", MENU_NAME)
		return
	var edited_scene_root := editor_interface.get_edited_scene_root()
	if edited_scene_root == null:
		OS.alert("Open a map scene first so there is an edited scene to compile.", MENU_NAME)
		return
	var scene_path := str(edited_scene_root.scene_file_path).strip_edges()
	if scene_path.is_empty():
		OS.alert("The current edited scene is unsaved. Save it first.", MENU_NAME)
		return
	var compiler = compiler_script.new()
	var result: Dictionary = compiler.compile_scene(scene_path)
	if not bool(result.get("ok", false)):
		OS.alert("Editor map compile failed.\n\n%s" % str(result.get("message", "unknown error")), MENU_NAME)
		return
	OS.alert(
		"Compiled runtime bundle for %s.\n\nOutput: %s" % [
			str(result.get("map_id", "")),
			str(result.get("output_dir", "")),
		],
		MENU_NAME
	)
