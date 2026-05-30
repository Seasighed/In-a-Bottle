@tool
extends RefCounted

const PROFILES_RES_PATH := "res://devtools/build_profiles"

const BuildProfileScript = preload("res://addons/seashell_devtools/BuildProfile.gd")
const ExportPresetCatalogScript = preload("res://addons/seashell_devtools/ExportPresetCatalog.gd")
const PathHelpers = preload("res://addons/seashell_devtools/PathHelpers.gd")
const SupportedBuildPlatforms = preload("res://addons/seashell_devtools/SupportedBuildPlatforms.gd")

var _project_root_absolute := ""
var _profiles_absolute_path := ""
var _migration_messages: Array = []
var _current_preset_catalog

func _init(project_root_absolute: String) -> void:
	_project_root_absolute = project_root_absolute.simplify_path()
	_profiles_absolute_path = ProjectSettings.globalize_path(PROFILES_RES_PATH)
	_current_preset_catalog = ExportPresetCatalogScript.load(_project_root_absolute)

func get_profiles_absolute_path() -> String:
	return _profiles_absolute_path

func take_migration_messages() -> Array:
	var messages := _migration_messages.duplicate()
	_migration_messages.clear()
	return messages

func load_profiles() -> Array:
	ensure_profiles_directory()
	_migrate_legacy_profiles()

	var files: Array = []
	if DirAccess.dir_exists_absolute(_profiles_absolute_path):
		for file_name in DirAccess.get_files_at(_profiles_absolute_path):
			if String(file_name).to_lower().ends_with(".tres"):
				files.append(String(file_name))
	files.sort()

	var records: Array = []
	for file_name in files:
		var absolute_path := _profiles_absolute_path.path_join(file_name)
		var resource_path := PathHelpers.to_res_path(absolute_path, _project_root_absolute)
		if resource_path.is_empty():
			continue

		var profile := ResourceLoader.load(resource_path)
		if profile == null:
			continue
		_ensure_target_platform(profile, resource_path)

		records.append({
			"ResourcePath": resource_path,
			"Profile": profile,
		})

	return records

func create_profile(display_name: String, target_platform: String = SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP, export_preset: Dictionary = {}) -> Dictionary:
	ensure_profiles_directory()

	var profile: Resource = BuildProfileScript.new()
	profile.DisplayName = display_name.strip_edges() if not display_name.strip_edges().is_empty() else "New Build Profile"
	profile.TargetPlatform = SupportedBuildPlatforms.normalize_platform_token(target_platform)
	if not export_preset.is_empty():
		var resolved := SupportedBuildPlatforms.try_resolve_from_preset(export_preset)
		if resolved.get("ok", false):
			profile.TargetPlatform = String(resolved.get("platform_info", {}).get("Platform", profile.TargetPlatform))
	profile.ExportPresetName = String(export_preset.get("Name", ""))
	_apply_platform_defaults(profile, profile.TargetPlatform)

	var resource_path := _build_unique_resource_path(profile.DisplayName)
	save_profile(profile, resource_path)
	return {
		"ResourcePath": resource_path,
		"Profile": profile,
	}

func duplicate_profile(source: Dictionary) -> Dictionary:
	var profile: Resource = source.get("Profile").clone_profile()
	profile.DisplayName = "%s Copy" % source.get("Profile").DisplayName

	var resource_path := _build_unique_resource_path(profile.DisplayName)
	save_profile(profile, resource_path)
	return {
		"ResourcePath": resource_path,
		"Profile": profile,
	}

func save_profile(profile: Resource, resource_path: String) -> void:
	var error := ResourceSaver.save(profile, resource_path)
	if error != OK:
		push_error("Could not save build profile '%s'. Godot returned '%s'." % [resource_path, error_string(error)])

func delete_profile(resource_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return

	var directory := DirAccess.open(_profiles_absolute_path)
	if directory == null:
		push_error("Could not open the build profile folder for deletion.")
		return

	var error := directory.remove(absolute_path.get_file())
	if error != OK:
		push_error("Could not delete build profile '%s'. Godot returned '%s'." % [resource_path, error_string(error)])

func ensure_profiles_directory() -> void:
	DirAccess.make_dir_recursive_absolute(_profiles_absolute_path)

func _apply_platform_defaults(profile: Resource, target_platform: String) -> void:
	var resolved := SupportedBuildPlatforms.try_resolve_by_token(target_platform)
	if not resolved.get("ok", false):
		return

	var platform_info: Dictionary = resolved.get("platform_info", {})
	profile.OutputDirectory = String(platform_info.get("DefaultOutputDirectory", "artifacts/windows"))
	profile.ExecutableFileName = SupportedBuildPlatforms.build_default_output_file_name(_build_project_output_stem(), platform_info)
	profile.BuildMode = BuildProfileScript.BUILD_MODE_DEBUG if String(platform_info.get("Platform", "")) == SupportedBuildPlatforms.PLATFORM_ANDROID_APK else BuildProfileScript.BUILD_MODE_RELEASE

func _build_project_output_stem() -> String:
	var folder_name := _project_root_absolute.get_file()
	if folder_name.is_empty():
		return "BuildOutput"

	var compact := folder_name.replace(" ", "")
	return folder_name if compact.is_empty() else compact

func _build_unique_resource_path(display_name: String) -> String:
	var slug := PathHelpers.slugify(display_name, "build-profile")
	var candidate := "%s/%s.tres" % [PROFILES_RES_PATH, slug]
	var suffix := 2
	while FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
		candidate = "%s/%s-%d.tres" % [PROFILES_RES_PATH, slug, suffix]
		suffix += 1
	return candidate

func _ensure_target_platform(profile: Resource, resource_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var raw := FileAccess.get_file_as_string(absolute_path)
	if raw.contains("TargetPlatform ="):
		profile.TargetPlatform = SupportedBuildPlatforms.normalize_platform_token(String(profile.TargetPlatform))
		return

	var inferred_platform := _infer_legacy_target_platform(profile)
	profile.TargetPlatform = inferred_platform
	save_profile(profile, resource_path)
	_migration_messages.append("Inferred target platform '%s' for legacy build profile '%s'." % [inferred_platform, absolute_path.get_file()])

func _infer_legacy_target_platform(profile: Resource) -> String:
	var preset_name := String(profile.ExportPresetName).strip_edges()
	if not preset_name.is_empty() and _current_preset_catalog != null:
		var preset: Dictionary = _current_preset_catalog.find_by_name(preset_name)
		var resolved := SupportedBuildPlatforms.try_resolve_from_preset(preset)
		if resolved.get("ok", false):
			return String(resolved.get("platform_info", {}).get("Platform", SupportedBuildPlatforms.PLATFORM_WINDOWS_DESKTOP))

	return SupportedBuildPlatforms.infer_platform_token_from_output_file_name(String(profile.ExecutableFileName))

func _migrate_legacy_profiles() -> void:
	if not DirAccess.dir_exists_absolute(_profiles_absolute_path):
		return

	for file_name in DirAccess.get_files_at(_profiles_absolute_path):
		if not String(file_name).to_lower().ends_with(".tres"):
			continue

		var absolute_path := _profiles_absolute_path.path_join(file_name)
		var raw := FileAccess.get_file_as_string(absolute_path)
		if raw.is_empty():
			continue

		var updated_lines: Array = []
		var changed := false
		var index := 0
		for raw_line in raw.split("\n"):
			var line := raw_line
			if index == 0 and line.contains("script_class=\"BuildProfile\""):
				line = "[gd_resource type=\"Resource\" load_steps=2 format=3]"
				changed = true
			elif line.contains("path=\"res://addons/seashell_devtools/BuildProfile.cs\""):
				line = line.replace("path=\"res://addons/seashell_devtools/BuildProfile.cs\"", "path=\"res://addons/seashell_devtools/BuildProfile.gd\"")
				changed = true
			updated_lines.append(line)
			index += 1

		if not changed:
			continue

		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file == null:
			push_error("Could not migrate legacy build profile '%s'." % absolute_path)
			continue
		file.store_string("\n".join(updated_lines))
		file.close()
		_migration_messages.append("Migrated legacy build profile '%s' from the C# resource script to the universal GDScript profile." % file_name)
