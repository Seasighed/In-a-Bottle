@tool
extends EditorDock

const BuildProfileScript = preload("res://addons/seashell_devtools/BuildProfile.gd")
const BuildProfileStoreScript = preload("res://addons/seashell_devtools/BuildProfileStore.gd")
const BuildRunnerScript = preload("res://addons/seashell_devtools/BuildRunner.gd")
const BuildVersioning = preload("res://addons/seashell_devtools/BuildVersioning.gd")
const ExportPresetCatalogScript = preload("res://addons/seashell_devtools/ExportPresetCatalog.gd")
const GodotProjectInfo = preload("res://addons/seashell_devtools/GodotProjectInfo.gd")
const PathHelpers = preload("res://addons/seashell_devtools/PathHelpers.gd")
const SupportedBuildPlatforms = preload("res://addons/seashell_devtools/SupportedBuildPlatforms.gd")

const ACTIVE_PROFILE_SETTING_KEY := "seashell_devtools/active_profile_path"
const BUILD_EDITOR_EXECUTABLE_PATH_SETTING_KEY := "seashell_devtools/build_editor_executable_path"
const OBSOLETE_TARGET_PROJECT_PATH_SETTING_KEY := "seashell_devtools/target_project_path"
const OBSOLETE_LEGACY_LINK_TARGET_PROJECT_SETTING_KEY := "seashell_devtools/link_target_project_path"
const WEB_PREVIEW_SERVER_SCRIPT_RES_PATH := "res://addons/seashell_devtools/web_preview_server.ps1"

var _plugin: EditorPlugin
var _profile_store
var _runner = null

var _profiles: Array = []
var _preset_catalog
var _current_project_info: Dictionary = {}
var _suppress_ui_events := false
var _visible_run_id := -1
var _last_auto_opened_run_id := -1
var _last_completed_run_id_seen := -1
var _obsolete_target_settings_logged := false

var _profile_selector: OptionButton
var _duplicate_profile_button: Button
var _delete_profile_button: Button
var _open_output_folder_button: Button
var _platform_selector: OptionButton
var _preset_selector: OptionButton
var _build_mode_selector: OptionButton
var _display_name_edit: LineEdit
var _output_directory_edit: LineEdit
var _file_name_edit: LineEdit
var _prebuild_check_box: CheckBox
var _verbose_check_box: CheckBox
var _open_folder_on_success_check_box: CheckBox
var _current_project_status_label: Label
var _preset_hint_label: Label
var _profile_status_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _step_label: Label
var _detail_label: Label
var _elapsed_label: Label
var _log_view: RichTextLabel
var _build_button: Button
var _abort_button: Button
var _delete_dialog: ConfirmationDialog
var _build_editor_path_edit: LineEdit
var _build_editor_status_label: Label
var _browse_build_editor_button: Button
var _build_editor_dialog: FileDialog
var _runtime_init_error := ""
var _web_preview_servers: Dictionary = {}

func initialize(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_ensure_runtime_objects()
	name = "Sea Shell DevTools"
	title = "Sea Shell DevTools"
	layout_key = "SeaShellDevToolsDock"
	icon_name = "Tools"
	default_slot = EditorDock.DOCK_SLOT_BOTTOM
	available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL | EditorDock.DOCK_LAYOUT_FLOATING

func _ready() -> void:
	_ensure_runtime_objects()
	_build_ui()
	refresh_data()
	set_process(true)

func _process(_delta: float) -> void:
	_ensure_runtime_objects()
	if _runner == null:
		return
	_runner.poll()
	_drain_runner_logs()
	_refresh_run_status()

func _exit_tree() -> void:
	shutdown_runtime()

func shutdown_runtime() -> void:
	_stop_all_web_preview_servers()

func _ensure_runtime_objects() -> void:
	if _runner == null:
		_runner = _try_instantiate_script(BuildRunnerScript, "BuildRunner.gd")
	if _profile_store == null:
		var created_profile_store = _try_instantiate_script(BuildProfileStoreScript, "BuildProfileStore.gd", [ProjectSettings.globalize_path("res://")])
		if created_profile_store != null:
			_profile_store = created_profile_store

func _try_instantiate_script(script_resource, script_name: String, constructor_args: Array = []) -> Variant:
	if script_resource == null:
		_set_runtime_init_error("Could not load '%s'." % script_name)
		return null
	if not (script_resource is Script):
		_set_runtime_init_error("'%s' was loaded, but it is not a Script resource." % script_name)
		return null
	if not script_resource.can_instantiate():
		_set_runtime_init_error("'%s' could not be instantiated. This usually means the synced addon files are out of date or that script failed to compile in this project." % script_name)
		return null
	return script_resource.callv("new", constructor_args)

func _set_runtime_init_error(message: String) -> void:
	if _runtime_init_error == message:
		return
	_runtime_init_error = message
	push_error(message)

func open_dock() -> void:
	make_visible()

func build_active_profile_from_menu() -> void:
	make_visible()
	_start_build()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var profile_toolbar := HBoxContainer.new()
	profile_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(profile_toolbar)

	var active_profile_label := Label.new()
	active_profile_label.text = "Active Profile"
	profile_toolbar.add_child(active_profile_label)

	_profile_selector = OptionButton.new()
	_profile_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_selector.item_selected.connect(_on_profile_selected)
	profile_toolbar.add_child(_profile_selector)

	profile_toolbar.add_child(_create_button("New", _create_profile))
	_duplicate_profile_button = _create_button("Duplicate", _duplicate_profile)
	profile_toolbar.add_child(_duplicate_profile_button)
	_delete_profile_button = _create_button("Delete", _confirm_delete_profile)
	profile_toolbar.add_child(_delete_profile_button)
	profile_toolbar.add_child(_create_button("Refresh", refresh_data))
	profile_toolbar.add_child(_create_button("Profiles Folder", _open_profiles_folder))

	var action_toolbar := HBoxContainer.new()
	action_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(action_toolbar)

	_build_button = _create_button("Build", _start_build)
	action_toolbar.add_child(_build_button)
	_abort_button = _create_button("Abort", _abort_build)
	_abort_button.visible = false
	action_toolbar.add_child(_abort_button)
	_open_output_folder_button = _create_button("Open Output", _open_configured_output_folder)
	action_toolbar.add_child(_open_output_folder_button)

	_profile_status_label = Label.new()
	_profile_status_label.text = "Profiles are stored in res://devtools/build_profiles and committed with the repo."
	_profile_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_profile_status_label)

	var progress_panel := VBoxContainer.new()
	progress_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(progress_panel)

	var progress_row := HBoxContainer.new()
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_panel.add_child(progress_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.text = "0% estimate"
	progress_row.add_child(_progress_label)

	_step_label = Label.new()
	_step_label.text = "Step: Idle"
	progress_panel.add_child(_step_label)

	_detail_label = Label.new()
	_detail_label.text = "The build log is authoritative. Percent complete is a phase-weighted estimate."
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_panel.add_child(_detail_label)

	_elapsed_label = Label.new()
	_elapsed_label.text = "Elapsed: 00:00:00"
	progress_panel.add_child(_elapsed_label)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var settings_scroll := ScrollContainer.new()
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(settings_scroll)
	settings_scroll.add_child(_build_settings_panel())

	split.add_child(_build_log_panel())

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.dialog_text = "Delete the selected build profile? This removes the .tres file from res://devtools/build_profiles."
	_delete_dialog.confirmed.connect(_delete_selected_profile)
	add_child(_delete_dialog)

func _build_settings_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(460, 0)

	var header := Label.new()
	header.text = "Profile Settings"
	header.theme_type_variation = "HeaderSmall"
	panel.add_child(header)

	_current_project_status_label = Label.new()
	_current_project_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_current_project_status_label)

	_preset_hint_label = Label.new()
	_preset_hint_label.text = "Build presets come from the current project's export_presets.cfg. Manage their platform-specific settings in Project > Export."
	_preset_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_preset_hint_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(grid)

	grid.add_child(_make_field_label("Display Name"))
	_display_name_edit = LineEdit.new()
	_display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_name_edit.text_submitted.connect(func(_text: String): _save_edited_text_fields())
	_display_name_edit.focus_exited.connect(_save_edited_text_fields)
	grid.add_child(_display_name_edit)

	grid.add_child(_make_field_label("Platform"))
	_platform_selector = OptionButton.new()
	_platform_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_platform_selector()
	_platform_selector.item_selected.connect(_on_platform_selected)
	grid.add_child(_platform_selector)

	grid.add_child(_make_field_label("Export Preset"))
	_preset_selector = OptionButton.new()
	_preset_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_selector.item_selected.connect(_on_preset_selected)
	grid.add_child(_preset_selector)

	grid.add_child(_make_field_label("Build Mode"))
	_build_mode_selector = OptionButton.new()
	_build_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_mode_selector.add_item("Release", BuildProfileScript.BUILD_MODE_RELEASE)
	_build_mode_selector.add_item("Debug", BuildProfileScript.BUILD_MODE_DEBUG)
	_build_mode_selector.item_selected.connect(func(_index: int): _save_choice_fields())
	grid.add_child(_build_mode_selector)

	grid.add_child(_make_field_label("Build Collection Root"))
	_output_directory_edit = LineEdit.new()
	_output_directory_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_directory_edit.text_submitted.connect(func(_text: String): _save_edited_text_fields())
	_output_directory_edit.focus_exited.connect(_save_edited_text_fields)
	grid.add_child(_output_directory_edit)

	grid.add_child(_make_field_label("Output File"))
	_file_name_edit = LineEdit.new()
	_file_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_name_edit.text_submitted.connect(func(_text: String): _save_edited_text_fields())
	_file_name_edit.focus_exited.connect(_save_edited_text_fields)
	grid.add_child(_file_name_edit)

	var output_collection_note := Label.new()
	output_collection_note.text = "Sea Shell treats the build collection root as a parent folder. Each successful build creates a new versioned subfolder there, such as 'In a Bottle_v0.0.1-release'."
	output_collection_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(output_collection_note)

	_prebuild_check_box = _create_check_box("Pre-build C# solution", _save_choice_fields)
	panel.add_child(_prebuild_check_box)
	_verbose_check_box = _create_check_box("Verbose Godot child-process logs", _save_choice_fields)
	panel.add_child(_verbose_check_box)
	_open_folder_on_success_check_box = _create_check_box("Open output folder on success", _save_choice_fields)
	panel.add_child(_open_folder_on_success_check_box)
	panel.add_child(_build_advanced_panel())

	return panel

func _build_advanced_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	panel.add_child(HSeparator.new())

	var header := Label.new()
	header.text = "Advanced"
	header.theme_type_variation = "HeaderSmall"
	panel.add_child(header)

	var description := Label.new()
	description.text = "Builds always export the currently open Godot project. Sea Shell creates a new versioned build folder inside the configured collection root on every successful build. Use Build Editor Override when this editor install does not have the templates you need, especially for local Web HTML builds."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)

	var editor_label := Label.new()
	editor_label.text = "Build Editor Override"
	panel.add_child(editor_label)

	var editor_row := HBoxContainer.new()
	editor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(editor_row)

	_build_editor_path_edit = LineEdit.new()
	_build_editor_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_editor_path_edit.placeholder_text = "Blank = use the current Godot editor executable"
	_build_editor_path_edit.text_changed.connect(func(_text: String): _on_build_editor_path_changed())
	editor_row.add_child(_build_editor_path_edit)

	_browse_build_editor_button = _create_button("Browse...", _browse_for_build_editor)
	editor_row.add_child(_browse_build_editor_button)

	_build_editor_status_label = Label.new()
	_build_editor_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_build_editor_status_label)

	_build_editor_dialog = FileDialog.new()
	_build_editor_dialog.title = "Choose Godot Editor Executable"
	_build_editor_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_build_editor_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_build_editor_dialog.size = Vector2i(920, 620)
	_build_editor_dialog.file_selected.connect(_on_build_editor_file_selected)
	add_child(_build_editor_dialog)

	return panel

func _build_log_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header := Label.new()
	header.text = "Run Log"
	header.theme_type_variation = "HeaderSmall"
	panel.add_child(header)

	_log_view = RichTextLabel.new()
	_log_view.bbcode_enabled = true
	_log_view.scroll_following = true
	_log_view.selection_enabled = true
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_log_view)
	return panel

func refresh_data() -> void:
	_ensure_runtime_objects()
	_update_current_project_status_label()
	if _profile_store == null:
		return

	_load_stored_build_editor_path()
	_current_project_info = GodotProjectInfo.load(ProjectSettings.globalize_path("res://"))
	_preset_catalog = _load_current_project_preset_catalog()
	_profiles = _profile_store.load_profiles()
	_update_current_project_status_label()
	_log_obsolete_target_setting_notice()

	for message in _profile_store.take_migration_messages():
		_append_standalone_log("Info", "Profiles", String(message))

	var stored_path := _get_stored_active_profile_path()
	if _profiles.is_empty():
		var first_preset: Dictionary = _get_preferred_default_preset()
		var first_platform := _resolve_platform_token_for_preset(first_preset)
		if first_platform.is_empty():
			first_platform = SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP
		var default_profile_name := _build_profile_name_for_platform(first_platform, true)
		_profile_store.create_profile(default_profile_name, first_platform, first_preset)
		_profiles = _profile_store.load_profiles()

	_rebuild_profile_selector(stored_path)
	_load_selected_profile_into_form()
	_update_build_editor_status()
	_refresh_run_status()
	_update_action_availability()

func _rebuild_profile_selector(preferred_path: String) -> void:
	_suppress_ui_events = true
	_profile_selector.clear()

	var selected_index := -1
	for index in range(_profiles.size()):
		var record: Dictionary = _profiles[index]
		var profile: Resource = record.get("Profile")
		_profile_selector.add_item(String(profile.DisplayName), index)
		_profile_selector.set_item_metadata(index, String(record.get("ResourcePath", "")))
		if (not preferred_path.is_empty() and String(record.get("ResourcePath", "")) == preferred_path) or (preferred_path.is_empty() and index == 0):
			selected_index = index

	if _profiles.size() > 0:
		_profile_selector.select(selected_index if selected_index >= 0 else 0)
	_suppress_ui_events = false

func _populate_platform_selector() -> void:
	_suppress_ui_events = true
	_platform_selector.clear()
	for platform_info in SupportedBuildPlatforms.get_all():
		var info: Dictionary = platform_info
		var token := String(info.get("Platform", ""))
		_platform_selector.add_item(String(info.get("ArtifactLabel", "Build")))
		_platform_selector.set_item_metadata(_platform_selector.item_count - 1, token)
	_suppress_ui_events = false

func _rebuild_preset_selector(platform_token: String = "") -> void:
	_suppress_ui_events = true
	_preset_selector.clear()

	var effective_platform := SupportedBuildPlatforms.normalize_platform_token(platform_token if not platform_token.is_empty() else _get_selected_platform_token())
	var presets: Array = _get_presets_for_platform(effective_platform)
	if presets.is_empty():
		_preset_selector.add_item("<No matching export preset>")
		_preset_selector.set_item_metadata(0, "")
		_preset_selector.set_item_disabled(0, true)
		_preset_selector.select(0)
		_suppress_ui_events = false
		return

	for preset in presets:
		var typed_preset: Dictionary = preset
		var display := _build_preset_display_label(typed_preset)
		if not bool(typed_preset.get("Runnable", false)):
			display += " (not runnable)"
		_preset_selector.add_item(display)
		_preset_selector.set_item_metadata(_preset_selector.item_count - 1, String(typed_preset.get("Name", "")))

	_suppress_ui_events = false

func _on_profile_selected(_index: int) -> void:
	if _suppress_ui_events:
		return
	var record := _get_selected_profile_record()
	if not record.is_empty():
		_set_stored_active_profile_path(String(record.get("ResourcePath", "")))
	_load_selected_profile_into_form()
	_update_action_availability()

func _load_selected_profile_into_form() -> void:
	var record := _get_selected_profile_record()
	if record.is_empty():
		_clear_profile_form()
		return

	var profile: Resource = record.get("Profile")
	var target_platform := SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))

	_suppress_ui_events = true
	_display_name_edit.text = String(profile.DisplayName)
	_output_directory_edit.text = String(profile.OutputDirectory)
	_file_name_edit.text = String(profile.ExecutableFileName)
	_prebuild_check_box.button_pressed = bool(profile.PrebuildDotnetSolution)
	_verbose_check_box.button_pressed = bool(profile.VerboseGodotLog)
	_open_folder_on_success_check_box.button_pressed = bool(profile.OpenOutputFolderOnSuccess)
	_select_platform(target_platform)
	_rebuild_preset_selector(target_platform)
	_select_preset(String(profile.ExportPresetName))
	_select_build_mode(int(profile.BuildMode))
	_profile_status_label.text = "Editing %s" % record.get("ResourcePath", "")
	_suppress_ui_events = false

	_update_preset_hint_label()
	_update_csharp_control_visibility()
	_update_output_action_labels()

func _clear_profile_form() -> void:
	_suppress_ui_events = true
	_display_name_edit.text = ""
	_output_directory_edit.text = ""
	_file_name_edit.text = ""
	_prebuild_check_box.button_pressed = false
	_verbose_check_box.button_pressed = false
	_open_folder_on_success_check_box.button_pressed = false
	_select_platform(SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP)
	_rebuild_preset_selector(SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP)
	_select_build_mode(BuildProfileScript.BUILD_MODE_RELEASE)
	_profile_status_label.text = "No build profile selected."
	_suppress_ui_events = false

	_update_preset_hint_label()
	_update_csharp_control_visibility()
	_update_output_action_labels()

func _select_platform(platform_token: String) -> void:
	var normalized := SupportedBuildPlatforms.normalize_platform_token(platform_token)
	for index in range(_platform_selector.item_count):
		if String(_platform_selector.get_item_metadata(index)) == normalized:
			_platform_selector.select(index)
			return
	if _platform_selector.item_count > 0:
		_platform_selector.select(0)

func _select_preset(preset_name: String) -> bool:
	for index in range(_preset_selector.item_count):
		if String(_preset_selector.get_item_metadata(index)) == preset_name:
			_preset_selector.select(index)
			return true

	if not preset_name.is_empty():
		_preset_selector.add_item("%s [missing from current project or selected platform]" % preset_name)
		_preset_selector.set_item_metadata(_preset_selector.item_count - 1, preset_name)
		_preset_selector.select(_preset_selector.item_count - 1)
		return false

	if _preset_selector.item_count > 0:
		_preset_selector.select(0)
		return not _preset_selector.is_item_disabled(0)

	return false

func _select_build_mode(mode: int) -> void:
	for index in range(_build_mode_selector.item_count):
		if _build_mode_selector.get_item_id(index) == mode:
			_build_mode_selector.select(index)
			return
	_build_mode_selector.select(0)

func _save_edited_text_fields() -> void:
	_save_active_profile_from_form(true)

func _save_choice_fields() -> void:
	_save_active_profile_from_form(false)

func _save_active_profile_from_form(refresh_after_save: bool) -> void:
	if _suppress_ui_events or _profile_store == null:
		return

	var record := _get_selected_profile_record()
	if record.is_empty():
		return

	var profile: Resource = record.get("Profile")
	profile.DisplayName = _display_name_edit.text.strip_edges() if not _display_name_edit.text.strip_edges().is_empty() else "Unnamed Build Profile"
	profile.TargetPlatform = _get_selected_platform_token()
	profile.ExportPresetName = _get_selected_preset_name()
	profile.BuildMode = _get_selected_build_mode()
	profile.OutputDirectory = _output_directory_edit.text.strip_edges()
	profile.ExecutableFileName = _file_name_edit.text.strip_edges()
	profile.PrebuildDotnetSolution = _prebuild_check_box.button_pressed
	profile.VerboseGodotLog = _verbose_check_box.button_pressed
	profile.OpenOutputFolderOnSuccess = _open_folder_on_success_check_box.button_pressed

	var resource_path := String(record.get("ResourcePath", ""))
	_profile_store.save_profile(profile, resource_path)
	_set_stored_active_profile_path(resource_path)
	_profile_status_label.text = "Saved %s" % resource_path

	if refresh_after_save:
		refresh_data()
		_select_profile_by_path(resource_path)
		return

	_update_preset_hint_label()
	_update_action_availability()
	_update_csharp_control_visibility()

func _create_profile() -> void:
	if _profile_store == null:
		return

	var target_platform := _get_selected_platform_token()
	var preset: Dictionary = _get_preferred_new_profile_preset(target_platform)
	var default_profile_name := _build_profile_name_for_platform(target_platform, false)
	var created: Dictionary = _profile_store.create_profile(default_profile_name, target_platform, preset)
	refresh_data()
	_select_profile_by_path(String(created.get("ResourcePath", "")))

func _duplicate_profile() -> void:
	if _profile_store == null:
		return

	var record := _get_selected_profile_record()
	if record.is_empty():
		return

	var duplicate: Dictionary = _profile_store.duplicate_profile(record)
	refresh_data()
	_select_profile_by_path(String(duplicate.get("ResourcePath", "")))

func _confirm_delete_profile() -> void:
	if _get_selected_profile_record().is_empty():
		return
	_delete_dialog.popup_centered(Vector2i(520, 120))

func _delete_selected_profile() -> void:
	if _profile_store == null:
		return
	var record := _get_selected_profile_record()
	if record.is_empty():
		return
	_profile_store.delete_profile(String(record.get("ResourcePath", "")))
	refresh_data()

func _open_profiles_folder() -> void:
	if _profile_store == null:
		return
	OS.shell_open(_profile_store.get_profiles_absolute_path())

func _open_configured_output_folder() -> void:
	var record := _get_selected_profile_record()
	if record.is_empty():
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var profile: Resource = record.get("Profile")
	var collection_root := PathHelpers.resolve_directory(String(profile.OutputDirectory), project_root)
	if collection_root.is_empty():
		OS.alert("Output directory could not be resolved.", "Sea Shell DevTools")
		return

	DirAccess.make_dir_recursive_absolute(collection_root)
	if SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform)) == SupportedBuildPlatforms.PLATFORM_WEB:
		var latest_web_build: Dictionary = BuildVersioning.find_latest_build_directory(_current_project_info, collection_root)
		if not latest_web_build.get("ok", false):
			OS.alert(String(latest_web_build.get("error", "Build the Web profile once before previewing it.")), "Sea Shell DevTools")
			return
		_open_web_build_preview(String(latest_web_build.get("directory_absolute", "")), String(profile.ExecutableFileName), true)
		return

	OS.shell_open(collection_root)

func _start_build() -> void:
	_ensure_runtime_objects()
	if _runner == null:
		OS.alert("The build runner could not be initialized.", "Sea Shell DevTools")
		return
	var build_request := _try_resolve_build_request()
	if not build_request.get("ok", false):
		OS.alert(build_request.get("error", "Build request could not be resolved."), "Sea Shell DevTools")
		return

	var record: Dictionary = build_request.get("record", {})
	if not _runner.start_build(
		record.get("Profile").to_snapshot(String(record.get("ResourcePath", ""))),
		build_request.get("preset", {}),
		String(build_request.get("build_editor_path", "")),
		ProjectSettings.globalize_path("res://")
	):
		OS.alert("A build is already running. Abort it before starting another one.", "Sea Shell DevTools")
		return

	_visible_run_id = -1
	make_visible()
	_update_action_availability()

func _abort_build() -> void:
	_ensure_runtime_objects()
	if _runner == null:
		return
	_runner.abort()
	_update_action_availability()

func _drain_runner_logs() -> void:
	if _runner == null:
		return
	for entry in _runner.drain_logs():
		var snapshot: Dictionary = _runner.get_snapshot()
		if _visible_run_id != int(snapshot.get("RunId", -1)):
			_log_view.clear()
			_visible_run_id = int(snapshot.get("RunId", -1))
		_append_log_entry(entry)

func _append_log_entry(entry: Dictionary) -> void:
	var color := "#b6c8dc"
	match String(entry.get("Severity", "Info")):
		"Success":
			color = "#7ad7a8"
		"Warning":
			color = "#ffcf70"
		"Error":
			color = "#ff8a8a"
	var severity := String(entry.get("Severity", "Info")).to_upper()
	var message := _escape_bbcode(String(entry.get("Message", "")))
	var step := _escape_bbcode(String(entry.get("Step", "")))
	_log_view.append_text("[color=#7f94ac]%s[/color] [color=%s][b]%s[/b][/color] [b]%s[/b] %s\n" % [
		entry.get("Timestamp", "00:00:00"),
		color,
		severity,
		step,
		message,
	])

func _append_standalone_log(severity: String, step: String, message: String) -> void:
	_append_log_entry({
		"Timestamp": Time.get_time_string_from_system(),
		"Severity": severity,
		"Step": step,
		"Message": message,
	})

func _refresh_run_status() -> void:
	if _runner == null:
		return
	var snapshot: Dictionary = _runner.get_snapshot()
	var percent := float(snapshot.get("Progress01", 0.0)) * 100.0
	_progress_bar.value = snapped(percent, 0.1)
	_progress_label.text = "%d%% estimate" % int(round(percent))
	_step_label.text = "Step: %s" % snapshot.get("CurrentStep", "Idle")
	_detail_label.text = String(snapshot.get("Detail", "Ready to build."))
	_elapsed_label.text = "Elapsed: %s" % snapshot.get("ElapsedText", "00:00:00")

	if _visible_run_id != int(snapshot.get("RunId", -1)) and int(snapshot.get("RunId", -1)) > 0 and bool(snapshot.get("IsBusy", false)):
		_log_view.clear()
		_visible_run_id = int(snapshot.get("RunId", -1))

	if not bool(snapshot.get("IsBusy", false)) and String(snapshot.get("State", "")) == "Succeeded" and int(snapshot.get("RunId", -1)) > 0 and int(snapshot.get("RunId", -1)) != _last_completed_run_id_seen:
		_last_completed_run_id_seen = int(snapshot.get("RunId", -1))
		_current_project_info = GodotProjectInfo.load(ProjectSettings.globalize_path("res://"))
		_update_current_project_status_label()

	if String(snapshot.get("State", "")) == "Succeeded" and int(snapshot.get("RunId", -1)) != _last_auto_opened_run_id and bool(snapshot.get("OpenOutputFolderOnSuccess", false)):
		var output_directory := String(snapshot.get("OutputDirectoryAbsolute", ""))
		var output_file_absolute := String(snapshot.get("OutputFileAbsolute", ""))
		var platform := SupportedBuildPlatforms.normalize_platform_token(String(snapshot.get("Platform", "")))
		if not output_directory.is_empty():
			_last_auto_opened_run_id = int(snapshot.get("RunId", -1))
			if platform == SupportedBuildPlatforms.PLATFORM_WEB:
				if not _open_web_build_preview(output_directory, output_file_absolute.get_file(), false):
					_append_standalone_log("Warning", "Preview", "Sea Shell DevTools built the Web export successfully, but could not launch a localhost preview automatically.")
			else:
				OS.shell_open(output_directory)

	_update_action_availability()

func _update_action_availability() -> void:
	if _build_button == null or \
		_abort_button == null or \
		_duplicate_profile_button == null or \
		_delete_profile_button == null or \
		_open_output_folder_button == null or \
		_display_name_edit == null or \
		_platform_selector == null or \
		_preset_selector == null or \
		_build_mode_selector == null or \
		_output_directory_edit == null or \
		_file_name_edit == null or \
		_prebuild_check_box == null or \
		_verbose_check_box == null or \
		_open_folder_on_success_check_box == null or \
		_build_editor_path_edit == null or \
		_browse_build_editor_button == null:
		return
	if _runner == null:
		return

	var snapshot: Dictionary = _runner.get_snapshot()
	var has_profile := not _get_selected_profile_record().is_empty()
	var interactions_blocked := bool(snapshot.get("IsBusy", false))
	var build_editor_resolved := _try_resolve_build_editor_executable_path().get("ok", false)
	var selected_preset_available := _try_resolve_selected_preset_for_build().get("ok", false)
	var current_project_is_csharp := _current_project_looks_like_csharp()
	var selected_platform_presets: Array = _get_presets_for_platform(_get_selected_platform_token())

	_duplicate_profile_button.disabled = not has_profile or interactions_blocked
	_delete_profile_button.disabled = not has_profile or interactions_blocked
	_build_button.disabled = not has_profile or interactions_blocked or not build_editor_resolved or not selected_preset_available
	_abort_button.visible = bool(snapshot.get("IsBusy", false))
	_abort_button.disabled = not bool(snapshot.get("IsBusy", false))
	_open_output_folder_button.disabled = not has_profile

	var form_enabled := has_profile and not interactions_blocked
	_display_name_edit.editable = form_enabled
	_platform_selector.disabled = not form_enabled
	_preset_selector.disabled = not form_enabled or selected_platform_presets.is_empty()
	_build_mode_selector.disabled = not form_enabled
	_output_directory_edit.editable = form_enabled
	_file_name_edit.editable = form_enabled
	_prebuild_check_box.disabled = not form_enabled or not current_project_is_csharp
	_verbose_check_box.disabled = not form_enabled
	_open_folder_on_success_check_box.disabled = not form_enabled
	_build_editor_path_edit.editable = not interactions_blocked
	_browse_build_editor_button.disabled = interactions_blocked

	_update_csharp_control_visibility()
	_update_output_action_labels()

func _get_preferred_default_preset() -> Dictionary:
	for platform_token in [
		SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP,
		SupportedBuildPlatforms.PLATFORM_WEB,
		SupportedBuildPlatforms.PLATFORM_ANDROID_APK,
	]:
		var matching_presets: Array = _get_presets_for_platform(String(platform_token))
		if not matching_presets.is_empty():
			return matching_presets[0]
	return {}

func _get_preferred_new_profile_preset(platform_token: String) -> Dictionary:
	var normalized := SupportedBuildPlatforms.normalize_platform_token(platform_token)
	var record := _get_selected_profile_record()
	if not record.is_empty():
		var profile: Resource = record.get("Profile")
		var current_preset: Dictionary = _preset_catalog.find_by_name(String(profile.ExportPresetName))
		if not current_preset.is_empty() and _resolve_platform_token_for_preset(current_preset) == normalized:
			return current_preset

	var matching_presets: Array = _get_presets_for_platform(normalized)
	return matching_presets[0] if not matching_presets.is_empty() else {}

func _get_eligible_presets() -> Array:
	var presets: Array = _preset_catalog.Presets if _preset_catalog != null else []
	return presets.filter(func(preset: Dictionary): return SupportedBuildPlatforms.is_eligible_preset(preset))

func _get_presets_for_platform(platform_token: String) -> Array:
	var normalized := SupportedBuildPlatforms.normalize_platform_token(platform_token)
	return _get_eligible_presets().filter(func(preset: Dictionary): return _resolve_platform_token_for_preset(preset) == normalized)

func _build_preset_display_label(preset: Dictionary) -> String:
	var platform := String(preset.get("Platform", "")).to_lower()
	if platform == "android":
		var extension := String(preset.get("ExportPath", "")).get_extension().to_lower()
		if extension == "aab":
			return "%s [Android AAB unsupported here]" % preset.get("Name", "Android")
		return "%s [Android APK]" % preset.get("Name", "Android")
	if platform == "web":
		return "%s [Web HTML]" % preset.get("Name", "Web")
	return "%s [Windows EXE]" % preset.get("Name", "Windows")

func _build_preset_summary_label(preset: Dictionary) -> String:
	var platform := String(preset.get("Platform", "")).to_lower()
	if platform == "web":
		return "%s (Web)" % preset.get("Name", "Web")
	if platform == "android":
		return "%s (Android)" % preset.get("Name", "Android")
	return "%s (Windows)" % preset.get("Name", "Windows")

func _on_platform_selected(_index: int) -> void:
	if _suppress_ui_events:
		return

	var record := _get_selected_profile_record()
	if record.is_empty():
		return

	var profile: Resource = record.get("Profile")
	var previous_platform := SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))
	var next_platform := _get_selected_platform_token()

	_adjust_output_fields_for_platform_change(previous_platform, next_platform)
	_rebuild_preset_selector(next_platform)

	var preferred_preset_name := ""
	var current_preset: Dictionary = _preset_catalog.find_by_name(String(profile.ExportPresetName))
	if not current_preset.is_empty() and _resolve_platform_token_for_preset(current_preset) == next_platform:
		preferred_preset_name = String(profile.ExportPresetName)

	var preset_selected := _select_preset(preferred_preset_name)
	if not preset_selected and _preset_selector.item_count > 0 and not _preset_selector.is_item_disabled(0):
		_preset_selector.select(0)

	_save_choice_fields()

func _on_preset_selected(_index: int) -> void:
	if _suppress_ui_events:
		return
	_adjust_output_file_name_for_selected_preset()
	_save_choice_fields()

func _adjust_output_fields_for_platform_change(previous_platform: String, next_platform: String) -> void:
	var previous_info: Dictionary = _get_platform_info(previous_platform)
	var next_info: Dictionary = _get_platform_info(next_platform)

	var current_output_directory := _output_directory_edit.text.strip_edges()
	if current_output_directory.is_empty() or _normalize_path_text(current_output_directory) == _normalize_path_text(String(previous_info.get("DefaultOutputDirectory", ""))):
		_output_directory_edit.text = String(next_info.get("DefaultOutputDirectory", ""))

	var current_file_name := _file_name_edit.text.strip_edges()
	if current_file_name.is_empty():
		_file_name_edit.text = _build_default_output_file_name_for_platform(next_info)
	else:
		var current_extension := ".%s" % current_file_name.get_extension() if current_file_name.get_extension() != "" else ""
		var next_extension := String(next_info.get("OutputFileExtension", ""))
		if current_extension.is_empty():
			_file_name_edit.text = SupportedBuildPlatforms.build_default_output_file_name(current_file_name, next_info)
		elif _is_known_supported_extension(current_extension) and current_extension.to_lower() != next_extension.to_lower():
			_file_name_edit.text = _build_retargeted_output_file_name(current_file_name, previous_info, next_info)

	var current_mode := _get_selected_build_mode()
	if current_mode == _default_build_mode_for_platform(previous_platform):
		_select_build_mode(_default_build_mode_for_platform(next_platform))

func _adjust_output_file_name_for_selected_preset() -> void:
	var preset_name := _get_selected_preset_name()
	if preset_name.is_empty():
		return

	var preset: Dictionary = _preset_catalog.find_by_name(preset_name)
	var resolved := SupportedBuildPlatforms.try_resolve_from_preset(preset)
	if not resolved.get("ok", false):
		return

	var platform_info: Dictionary = resolved.get("platform_info", {})
	var current_file_name := _file_name_edit.text.strip_edges()
	if current_file_name.is_empty():
		_file_name_edit.text = _build_default_output_file_name_for_platform(platform_info)
		return

	var current_extension := ".%s" % current_file_name.get_extension() if current_file_name.get_extension() != "" else ""
	if current_extension.is_empty():
		_file_name_edit.text = SupportedBuildPlatforms.build_default_output_file_name(current_file_name, platform_info)
		return

	if _is_known_supported_extension(current_extension) and current_extension.to_lower() != String(platform_info.get("OutputFileExtension", "")).to_lower():
		_file_name_edit.text = SupportedBuildPlatforms.build_default_output_file_name(current_file_name.get_basename(), platform_info)

func _resolve_platform_token_for_preset(preset: Dictionary) -> String:
	var resolved := SupportedBuildPlatforms.try_resolve_from_preset(preset)
	if not resolved.get("ok", false):
		return ""
	return String(resolved.get("platform_info", {}).get("Platform", ""))

func _get_selected_profile_record() -> Dictionary:
	if _profile_selector.item_count == 0 or _profile_selector.selected < 0:
		return {}
	var resource_path := String(_profile_selector.get_item_metadata(_profile_selector.selected))
	for record in _profiles:
		var typed_record: Dictionary = record
		if String(typed_record.get("ResourcePath", "")) == resource_path:
			return typed_record
	return {}

func _select_profile_by_path(resource_path: String) -> void:
	for index in range(_profile_selector.item_count):
		if String(_profile_selector.get_item_metadata(index)) != resource_path:
			continue
		_profile_selector.select(index)
		_set_stored_active_profile_path(resource_path)
		_load_selected_profile_into_form()
		_update_action_availability()
		return

func _get_stored_active_profile_path() -> String:
	var settings := _plugin.get_editor_interface().get_editor_settings()
	return String(settings.get_setting(ACTIVE_PROFILE_SETTING_KEY)) if settings.has_setting(ACTIVE_PROFILE_SETTING_KEY) else ""

func _set_stored_active_profile_path(resource_path: String) -> void:
	_plugin.get_editor_interface().get_editor_settings().set_setting(ACTIVE_PROFILE_SETTING_KEY, resource_path)

func _load_stored_build_editor_path() -> void:
	var settings := _plugin.get_editor_interface().get_editor_settings()
	var stored_path := String(settings.get_setting(BUILD_EDITOR_EXECUTABLE_PATH_SETTING_KEY)) if settings.has_setting(BUILD_EDITOR_EXECUTABLE_PATH_SETTING_KEY) else ""
	_suppress_ui_events = true
	_build_editor_path_edit.text = stored_path
	_suppress_ui_events = false

func _store_build_editor_path(path: String) -> void:
	_plugin.get_editor_interface().get_editor_settings().set_setting(BUILD_EDITOR_EXECUTABLE_PATH_SETTING_KEY, path)

func _on_build_editor_path_changed() -> void:
	if _suppress_ui_events:
		return
	_store_build_editor_path(_build_editor_path_edit.text.strip_edges())
	_update_build_editor_status()
	_update_action_availability()

func _browse_for_build_editor() -> void:
	var start_dir := _resolve_initial_build_editor_browse_directory()
	if not start_dir.is_empty() and DirAccess.dir_exists_absolute(start_dir):
		_build_editor_dialog.current_dir = start_dir.replace("\\", "/")
	_build_editor_dialog.popup_centered()

func _resolve_initial_build_editor_browse_directory() -> String:
	var current_text := _build_editor_path_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if FileAccess.file_exists(current_text):
		return current_text.get_base_dir()
	if DirAccess.dir_exists_absolute(current_text):
		return current_text.simplify_path()
	return OS.get_executable_path().get_base_dir()

func _on_build_editor_file_selected(path: String) -> void:
	_suppress_ui_events = true
	_build_editor_path_edit.text = path.replace("/", "\\")
	_suppress_ui_events = false
	_store_build_editor_path(_build_editor_path_edit.text)
	_update_build_editor_status()
	_update_action_availability()

func _update_build_editor_status() -> void:
	var resolved := _try_resolve_build_editor_executable_path()
	if resolved.get("ok", false):
		var build_editor_path := String(resolved.get("build_editor_path", ""))
		if _build_editor_path_edit.text.strip_edges().is_empty():
			_build_editor_status_label.text = "Using the current Godot editor for builds: %s. Set an override when this install is missing templates for a local Web HTML build or another export mode." % build_editor_path
		else:
			_build_editor_status_label.text = "Using build editor override: %s" % build_editor_path
		return

	_build_editor_status_label.text = String(resolved.get("message", "Choose a valid Godot editor executable path."))

func _load_current_project_preset_catalog():
	return ExportPresetCatalogScript.load(ProjectSettings.globalize_path("res://"))

func _update_current_project_status_label() -> void:
	if _current_project_status_label == null:
		return

	if not _runtime_init_error.is_empty():
		_current_project_status_label.text = "Sea Shell DevTools could not initialize fully. %s" % _runtime_init_error
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var runtime_message := "C# markers detected." if _current_project_looks_like_csharp() else "No C# markers detected."
	var current_version := String(_current_project_info.get("ProjectVersion", "")).strip_edges()
	var version_message := "Current project version: %s." % current_version if not current_version.is_empty() else "Current project version is blank."
	_current_project_status_label.text = "Current project only: builds always export '%s'. %s %s" % [project_root, version_message, runtime_message]

func _update_preset_hint_label() -> void:
	if _preset_hint_label == null:
		return

	var all_preset_summaries: Array = []
	for preset in _get_eligible_presets():
		var typed_preset: Dictionary = preset
		all_preset_summaries.append(_build_preset_summary_label(typed_preset))

	var general_summary := "No supported Windows Desktop, Web, or Android presets were detected in the current project's export_presets.cfg." if all_preset_summaries.is_empty() else "Detected current-project presets: %s." % ", ".join(all_preset_summaries)
	var record := _get_selected_profile_record()
	if record.is_empty():
		_preset_hint_label.text = "%s Manage export presets in Project > Export." % general_summary
		return

	var profile: Resource = record.get("Profile")
	var target_platform := SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))
	var platform_info: Dictionary = _get_platform_info(target_platform)
	var platform_label := String(platform_info.get("ArtifactLabel", "Build"))
	var matching_presets: Array = _get_presets_for_platform(target_platform)
	var matching_names: Array = []
	for preset in matching_presets:
		var typed_preset: Dictionary = preset
		matching_names.append(_build_preset_display_label(typed_preset))

	if matching_presets.is_empty():
		_preset_hint_label.text = "Profile '%s' targets %s, but the current project has no matching export preset. Create a %s preset in Project > Export, then press Refresh. %s" % [profile.DisplayName, platform_label, String(platform_info.get("GodotPlatformName", platform_label)), general_summary]
		return

	if String(profile.ExportPresetName).strip_edges().is_empty():
		_preset_hint_label.text = "Profile '%s' targets %s. Choose one of the current project's matching presets to enable Build: %s." % [profile.DisplayName, platform_label, ", ".join(matching_names)]
		return

	var selected_preset: Dictionary = _preset_catalog.find_by_name(String(profile.ExportPresetName))
	if selected_preset.is_empty():
		_preset_hint_label.text = "Profile '%s' expects preset '%s', but it was not found in the current project's export_presets.cfg. %s" % [profile.DisplayName, profile.ExportPresetName, general_summary]
		return

	var preset_platform := _resolve_platform_token_for_preset(selected_preset)
	if preset_platform != target_platform:
		var preset_platform_label := String(_get_platform_info(preset_platform).get("ArtifactLabel", "another platform"))
		_preset_hint_label.text = "Profile '%s' targets %s, but preset '%s' is a %s preset. Choose a matching preset or create one in Project > Export. Matching options: %s." % [profile.DisplayName, platform_label, profile.ExportPresetName, preset_platform_label, ", ".join(matching_names)]
		return

	var web_note := " Web builds may need Build Editor Override when the current editor install is missing compatible Web templates." if target_platform == SupportedBuildPlatforms.PLATFORM_WEB else ""
	_preset_hint_label.text = "Profile '%s' uses current-project preset '%s'. Available %s presets: %s.%s" % [profile.DisplayName, profile.ExportPresetName, platform_label, ", ".join(matching_names), web_note]

func _try_resolve_build_editor_executable_path() -> Dictionary:
	var raw_value := _build_editor_path_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if raw_value.is_empty():
		var current_editor := OS.get_executable_path()
		if FileAccess.file_exists(current_editor):
			return {
				"ok": true,
				"build_editor_path": current_editor,
				"message": "Using current Godot editor executable '%s'." % current_editor,
			}
		return {
			"ok": false,
			"message": "The current Godot editor executable could not be found at '%s'." % current_editor,
		}

	var build_editor_path := raw_value.simplify_path()
	if not FileAccess.file_exists(build_editor_path):
		return {
			"ok": false,
			"message": "Build editor override was set to '%s', but that file does not exist." % build_editor_path,
		}
	return {
		"ok": true,
		"build_editor_path": build_editor_path,
		"message": "Using build editor override '%s'." % build_editor_path,
	}

func _try_resolve_selected_preset_for_build() -> Dictionary:
	var record := _get_selected_profile_record()
	if record.is_empty():
		return {
			"ok": false,
			"message": "Select or create a build profile first.",
		}

	var profile: Resource = record.get("Profile")
	var target_platform := SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))
	var platform_info: Dictionary = _get_platform_info(target_platform)
	var platform_label := String(platform_info.get("ArtifactLabel", "Build"))

	if String(profile.ExportPresetName).strip_edges().is_empty():
		return {
			"ok": false,
			"message": "Build profile '%s' targets %s, but no export preset is selected. Create or choose a matching preset in Project > Export." % [profile.DisplayName, platform_label],
		}

	var preset: Dictionary = _preset_catalog.find_by_name(String(profile.ExportPresetName))
	if preset.is_empty():
		return {
			"ok": false,
			"message": "Build profile '%s' expects export preset '%s', but that preset was not found in the current project's export_presets.cfg." % [profile.DisplayName, profile.ExportPresetName],
		}

	var preset_platform := _resolve_platform_token_for_preset(preset)
	if preset_platform != target_platform:
		return {
			"ok": false,
			"message": "Build profile '%s' targets %s, but export preset '%s' is a %s preset." % [profile.DisplayName, platform_label, profile.ExportPresetName, String(_get_platform_info(preset_platform).get("ArtifactLabel", "different platform"))],
		}

	var resolved_preset := SupportedBuildPlatforms.try_resolve_from_preset(preset)
	if not resolved_preset.get("ok", false):
		return {
			"ok": false,
			"message": String(resolved_preset.get("error", "The selected export preset is not supported.")),
		}

	return {
		"ok": true,
		"preset": preset,
		"message": "Using export preset '%s'." % preset.get("Name", ""),
	}

func _try_resolve_build_request() -> Dictionary:
	var record := _get_selected_profile_record()
	if record.is_empty():
		return {
			"ok": false,
			"error": "Select or create a build profile first.",
		}

	var resolved_editor := _try_resolve_build_editor_executable_path()
	if not resolved_editor.get("ok", false):
		return {
			"ok": false,
			"error": resolved_editor.get("message", "Build editor path is invalid."),
		}

	var resolved_preset := _try_resolve_selected_preset_for_build()
	if not resolved_preset.get("ok", false):
		return {
			"ok": false,
			"error": resolved_preset.get("message", "The selected export preset could not be resolved."),
		}

	return {
		"ok": true,
		"record": record,
		"preset": resolved_preset.get("preset", {}),
		"build_editor_path": resolved_editor.get("build_editor_path", ""),
	}

func _build_profile_name_for_platform(platform_token: String, is_first_profile: bool) -> String:
	var normalized := SupportedBuildPlatforms.normalize_platform_token(platform_token)
	if normalized == SupportedBuildPlatforms.PLATFORM_WEB:
		return "Default Web Build" if is_first_profile else "New Web Build"
	if normalized == SupportedBuildPlatforms.PLATFORM_ANDROID_APK:
		return "Default Android APK Build" if is_first_profile else "New Android APK Build"
	return "Default Windows Build" if is_first_profile else "New Windows Build"

func _current_project_looks_like_csharp() -> bool:
	return bool(_current_project_info.get("LooksLikeCSharpProject", false))

func _update_csharp_control_visibility() -> void:
	if _prebuild_check_box == null:
		return
	_prebuild_check_box.visible = _current_project_looks_like_csharp()

func _update_output_action_labels() -> void:
	if _open_output_folder_button == null or _open_folder_on_success_check_box == null:
		return

	var target_platform := _get_selected_profile_platform_token()
	if target_platform == SupportedBuildPlatforms.PLATFORM_WEB:
		_open_output_folder_button.text = "Preview Latest Build"
		_open_folder_on_success_check_box.text = "Open web preview on success"
		return

	_open_output_folder_button.text = "Open Build Collection"
	_open_folder_on_success_check_box.text = "Open built folder on success"

func _get_platform_info(platform_token: String) -> Dictionary:
	var resolved := SupportedBuildPlatforms.try_resolve_by_token(platform_token)
	if resolved.get("ok", false):
		return resolved.get("platform_info", {})
	return SupportedBuildPlatforms.WINDOWS_DESKTOP

func _get_selected_platform_token() -> String:
	if _platform_selector == null or _platform_selector.item_count == 0 or _platform_selector.selected < 0:
		return SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP
	return SupportedBuildPlatforms.normalize_platform_token(String(_platform_selector.get_item_metadata(_platform_selector.selected)))

func _get_selected_profile_platform_token() -> String:
	var record := _get_selected_profile_record()
	if record.is_empty():
		return _get_selected_platform_token()
	var profile: Resource = record.get("Profile")
	return SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))

func _get_selected_preset_name() -> String:
	if _preset_selector == null or _preset_selector.item_count == 0 or _preset_selector.selected < 0:
		return ""
	return String(_preset_selector.get_item_metadata(_preset_selector.selected)).strip_edges()

func _get_selected_build_mode() -> int:
	if _build_mode_selector == null or _build_mode_selector.item_count == 0 or _build_mode_selector.selected < 0:
		return BuildProfileScript.BUILD_MODE_RELEASE
	return _build_mode_selector.get_item_id(_build_mode_selector.selected)

func _build_default_output_file_name_for_platform(platform_info: Dictionary) -> String:
	return SupportedBuildPlatforms.build_default_output_file_name(_build_project_output_stem(), platform_info)

func _build_retargeted_output_file_name(current_file_name: String, previous_info: Dictionary, next_info: Dictionary) -> String:
	var current_lower := current_file_name.to_lower()
	var previous_default_name := _build_default_output_file_name_for_platform(previous_info).to_lower()
	var explicit_default_name := String(next_info.get("DefaultOutputFileName", ""))
	if not explicit_default_name.is_empty() and current_lower == previous_default_name:
		return explicit_default_name
	return SupportedBuildPlatforms.build_default_output_file_name(current_file_name.get_basename(), next_info)

func _build_project_output_stem() -> String:
	var folder_name := ProjectSettings.globalize_path("res://").get_file()
	if folder_name.is_empty():
		return "BuildOutput"

	var compact := folder_name.replace(" ", "")
	return folder_name if compact.is_empty() else compact

func _default_build_mode_for_platform(platform_token: String) -> int:
	return BuildProfileScript.BUILD_MODE_DEBUG if SupportedBuildPlatforms.normalize_platform_token(platform_token) == SupportedBuildPlatforms.PLATFORM_ANDROID_APK else BuildProfileScript.BUILD_MODE_RELEASE

func _is_known_supported_extension(extension: String) -> bool:
	for platform_info in SupportedBuildPlatforms.get_all():
		var info: Dictionary = platform_info
		if String(info.get("OutputFileExtension", "")).to_lower() == extension.to_lower():
			return true
	return false

func _normalize_path_text(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()

func _open_web_build_preview(output_directory_absolute: String, output_file_name: String, show_alerts: bool) -> bool:
	var normalized_directory := output_directory_absolute.simplify_path()
	var html_file_name := output_file_name.get_file().strip_edges()
	if html_file_name.is_empty():
		html_file_name = "index.html"

	var html_path := normalized_directory.path_join(html_file_name)
	if not FileAccess.file_exists(html_path):
		if show_alerts:
			OS.alert("Web preview could not be opened because '%s' does not exist yet. Build the Web profile first." % html_path, "Sea Shell DevTools")
		return false

	var preview_result: Dictionary = _ensure_web_preview_server(normalized_directory, html_file_name)
	if not preview_result.get("ok", false):
		if show_alerts:
			OS.alert(String(preview_result.get("error", "Web preview could not be started.")), "Sea Shell DevTools")
		return false

	var preview_url := String(preview_result.get("url", "")).strip_edges()
	if preview_url.is_empty():
		if show_alerts:
			OS.alert("Sea Shell DevTools started a web preview server, but no preview URL was returned.", "Sea Shell DevTools")
		return false

	OS.shell_open(preview_url)
	return true

func _ensure_web_preview_server(output_directory_absolute: String, output_file_name: String) -> Dictionary:
	var server_key := _build_web_preview_server_key(output_directory_absolute, output_file_name)
	var known_state: Dictionary = _web_preview_servers.get(server_key, {})
	if _is_web_preview_state_running(known_state, output_directory_absolute, output_file_name):
		return {
			"ok": true,
			"url": String(known_state.get("url", "")),
		}

	var state_file_path := _build_web_preview_state_file_path(server_key)
	var existing_state: Dictionary = _read_web_preview_state_file(state_file_path)
	if _is_web_preview_state_running(existing_state, output_directory_absolute, output_file_name):
		_web_preview_servers[server_key] = existing_state
		return {
			"ok": true,
			"url": String(existing_state.get("url", "")),
		}

	return _start_web_preview_server(output_directory_absolute, output_file_name, server_key, state_file_path)

func _build_web_preview_server_key(output_directory_absolute: String, output_file_name: String) -> String:
	return "%s|%s" % [_normalize_path_text(output_directory_absolute), output_file_name.strip_edges().to_lower()]

func _build_web_preview_state_file_path(server_key: String) -> String:
	var temp_root := OS.get_environment("TEMP").strip_edges()
	if temp_root.is_empty():
		temp_root = OS.get_environment("TMP").strip_edges()
	if temp_root.is_empty():
		temp_root = ProjectSettings.globalize_path("res://").path_join(".godot").path_join("sea_shell_temp")
	var state_key := "%d" % abs(server_key.hash())
	return temp_root.path_join("SeaShellDevTools").path_join("web_preview").path_join("preview_%s.json" % state_key)

func _read_web_preview_state_file(state_file_path: String) -> Dictionary:
	if not FileAccess.file_exists(state_file_path):
		return {}

	var raw_state := FileAccess.get_file_as_string(state_file_path).strip_edges()
	if raw_state.is_empty():
		return {}

	var parsed: Variant = JSON.parse_string(raw_state)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _is_web_preview_state_running(state: Dictionary, output_directory_absolute: String, output_file_name: String) -> bool:
	if state.is_empty():
		return false

	var pid := int(state.get("pid", -1))
	if pid <= 0 or not OS.is_process_running(pid):
		return false

	var root_path := String(state.get("rootPath", "")).simplify_path()
	var html_file_name := String(state.get("htmlFileName", "")).get_file()
	if _normalize_path_text(root_path) != _normalize_path_text(output_directory_absolute):
		return false
	if html_file_name.to_lower() != output_file_name.get_file().to_lower():
		return false
	return not String(state.get("url", "")).strip_edges().is_empty()

func _start_web_preview_server(output_directory_absolute: String, output_file_name: String, server_key: String, state_file_path: String) -> Dictionary:
	var script_path := ProjectSettings.globalize_path(WEB_PREVIEW_SERVER_SCRIPT_RES_PATH)
	if not FileAccess.file_exists(script_path):
		return {
			"ok": false,
			"error": "Sea Shell DevTools could not find its bundled web preview server script at '%s'." % script_path,
		}

	var state_directory := state_file_path.get_base_dir()
	if not state_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(state_directory)
	if FileAccess.file_exists(state_file_path):
		DirAccess.remove_absolute(state_file_path)

	var powershell_command := "& '%s' -RootPath '%s' -HtmlFileName '%s' -StateFilePath '%s'" % [
		_escape_powershell_single_quoted_string(script_path),
		_escape_powershell_single_quoted_string(output_directory_absolute),
		_escape_powershell_single_quoted_string(output_file_name.get_file()),
		_escape_powershell_single_quoted_string(state_file_path),
	]
	var args := PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-WindowStyle",
		"Hidden",
		"-Command",
		powershell_command,
	])
	var pid := OS.create_process("powershell.exe", args, false)
	if pid <= 0:
		return {
			"ok": false,
			"error": "Sea Shell DevTools could not start its localhost web preview server.",
		}

	var timeout_msec := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < timeout_msec:
		var state: Dictionary = _read_web_preview_state_file(state_file_path)
		if _is_web_preview_state_running(state, output_directory_absolute, output_file_name):
			_web_preview_servers[server_key] = state
			return {
				"ok": true,
				"url": String(state.get("url", "")),
			}
		if not OS.is_process_running(pid) and not FileAccess.file_exists(state_file_path):
			break
		OS.delay_msec(50)

	var failure_details := ""
	if FileAccess.file_exists(state_file_path):
		var incomplete_state: Dictionary = _read_web_preview_state_file(state_file_path)
		var maybe_url := String(incomplete_state.get("url", "")).strip_edges()
		if not maybe_url.is_empty():
			failure_details = " It reported '%s', but the process did not stay alive." % maybe_url
	return {
		"ok": false,
		"error": "Sea Shell DevTools could not start a localhost web preview in time.%s" % failure_details,
	}

func _stop_all_web_preview_servers() -> void:
	for server_key in _web_preview_servers.keys():
		var typed_key := String(server_key)
		var state: Dictionary = _web_preview_servers.get(typed_key, {})
		_stop_web_preview_server_state(state)
	_web_preview_servers.clear()

func _stop_web_preview_server_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	var pid := int(state.get("pid", -1))
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)

func _log_obsolete_target_setting_notice() -> void:
	if _obsolete_target_settings_logged:
		return

	var settings := _plugin.get_editor_interface().get_editor_settings()
	if not settings.has_setting(OBSOLETE_TARGET_PROJECT_PATH_SETTING_KEY) and not settings.has_setting(OBSOLETE_LEGACY_LINK_TARGET_PROJECT_SETTING_KEY):
		return

	_obsolete_target_settings_logged = true
	_append_standalone_log("Info", "Settings", "Ignoring legacy target-project build settings. Sea Shell DevTools now builds only the currently open project.")

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

func _escape_powershell_single_quoted_string(value: String) -> String:
	return value.replace("'", "''")

func _create_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button

func _create_check_box(text: String, action: Callable) -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = text
	check_box.toggled.connect(func(_pressed: bool): action.call())
	return check_box

func _make_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
