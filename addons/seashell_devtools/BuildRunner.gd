@tool
extends RefCounted

const BuildProfileScript = preload("res://addons/seashell_devtools/BuildProfile.gd")
const BuildVersioning = preload("res://addons/seashell_devtools/BuildVersioning.gd")
const GodotProjectInfo = preload("res://addons/seashell_devtools/GodotProjectInfo.gd")
const PathHelpers = preload("res://addons/seashell_devtools/PathHelpers.gd")
const SupportedBuildPlatforms = preload("res://addons/seashell_devtools/SupportedBuildPlatforms.gd")

const VALIDATION_PROGRESS := 0.15
const BUILD_PROGRESS := 0.40
const EXPORT_PROGRESS := 0.90
const PROCESS_CHUNK_SIZE := 4096

var _pending_logs: Array = []
var _run_id := 0
var _is_busy := false
var _abort_requested := false
var _state := "Idle"
var _progress01 := 0.0
var _phase_floor := 0.0
var _phase_cap := VALIDATION_PROGRESS
var _phase_started_msec := 0
var _started_msec := 0
var _finished_msec := 0
var _current_step := "Idle"
var _detail := "Ready to build."
var _output_directory_absolute := ""
var _output_file_absolute := ""
var _open_output_folder_on_success := false
var _pending_steps: Array = []
var _active_process: Dictionary = {}
var _current_request: Dictionary = {}
var _created_output_directory_absolute := ""

func start_build(profile_snapshot: Dictionary, preset: Dictionary, editor_executable_path: String, project_root_absolute: String) -> bool:
	if _is_busy:
		return false

	_run_id += 1
	_is_busy = true
	_abort_requested = false
	_pending_steps.clear()
	_active_process.clear()
	_current_request.clear()
	_progress01 = 0.0
	_phase_floor = 0.0
	_phase_cap = VALIDATION_PROGRESS
	_phase_started_msec = Time.get_ticks_msec()
	_started_msec = _phase_started_msec
	_finished_msec = 0
	_state = "Validating"
	_current_step = "Validating"
	_detail = "Preparing build profile '%s'." % profile_snapshot.get("DisplayName", "Build")
	_output_directory_absolute = ""
	_output_file_absolute = ""
	_open_output_folder_on_success = bool(profile_snapshot.get("OpenOutputFolderOnSuccess", false))
	_created_output_directory_absolute = ""

	_log("Info", "Validating", "Starting build for profile '%s'." % profile_snapshot.get("DisplayName", "Build"))
	var request: Dictionary = _validate(profile_snapshot, preset, editor_executable_path, project_root_absolute)
	if not request.get("ok", false):
		_log("Error", "Failed", request.get("error", "Build validation failed."))
		_complete("Failed", "Build failed", request.get("error", "Build validation failed."))
		return true

	_current_request = request
	if bool(request.get("ShouldBuildSolution", false)):
		_pending_steps.append({
			"State": "BuildingSolution",
			"StepId": "BuildingSolution",
			"StepTitle": "Building C# solution",
			"Detail": "Compiling the Godot C# solution before export.",
			"ExecutablePath": editor_executable_path,
			"Arguments": request.get("BuildSolutionArguments", PackedStringArray()),
			"CompletedProgress": BUILD_PROGRESS,
		})
	else:
		_log("Info", "BuildingSolution", request.get("BuildSolutionSkipMessage", "Skipping solution build."))
		_set_progress(BUILD_PROGRESS)

	_pending_steps.append({
		"State": "Exporting",
		"StepId": "Exporting",
		"StepTitle": "Exporting %s" % request.get("ArtifactLabel", "artifact"),
		"Detail": "Running Godot export preset '%s' to '%s'." % [request.get("ExportPresetName", ""), request.get("OutputFileAbsolute", "")],
		"ExecutablePath": editor_executable_path,
		"Arguments": request.get("ExportArguments", PackedStringArray()),
		"CompletedProgress": EXPORT_PROGRESS,
	})
	_start_next_step()
	return true

func abort() -> void:
	if not _is_busy:
		return

	_abort_requested = true
	_detail = "Abort requested. Waiting for the current child process to stop."
	_log("Warning", "Cancel", "Abort requested. Partial outputs may remain in the output folder.")

	if _active_process.is_empty():
		return

	var pid := int(_active_process.get("Pid", -1))
	if pid > 0:
		OS.kill(pid)

func poll() -> void:
	if not _is_busy or _active_process.is_empty():
		return

	_drain_active_process_output(false)
	var pid := int(_active_process.get("Pid", -1))
	if pid <= 0 or OS.is_process_running(pid):
		return

	_drain_active_process_output(true)
	var step_id := String(_active_process.get("StepId", "Run"))
	var step_title := String(_active_process.get("StepTitle", step_id))
	var completed_progress := float(_active_process.get("CompletedProgress", EXPORT_PROGRESS))
	var exit_code := OS.get_process_exit_code(pid)
	_active_process.clear()

	if _abort_requested:
		_complete("Canceled", "Build canceled", "Build canceled. Partial outputs may remain in the output folder.")
		return

	if exit_code != 0:
		_fail("%s failed with exit code %d. Check the step log for details." % [step_title, exit_code])
		return

	_set_progress(completed_progress)
	_log("Success", step_id, "%s finished successfully." % step_title)
	_start_next_step()

func drain_logs() -> Array:
	var entries: Array = _pending_logs.duplicate(true)
	_pending_logs.clear()
	return entries

func get_snapshot() -> Dictionary:
	var elapsed_msec := (_finished_msec if _finished_msec > 0 else Time.get_ticks_msec()) - _started_msec
	if elapsed_msec < 0:
		elapsed_msec = 0

	var progress: float = _progress01
	if _is_estimating(_state):
		var phase_elapsed := float(Time.get_ticks_msec() - _phase_started_msec) / 1000.0
		var target: float = _phase_floor + min((_phase_cap - _phase_floor) * 0.82, phase_elapsed * 0.015)
		progress = max(progress, target)

	return {
		"RunId": _run_id,
		"State": _state,
		"IsBusy": _is_busy,
		"Platform": String(_current_request.get("Platform", "")),
		"Progress01": clamp(progress, 0.0, 1.0),
		"CurrentStep": _current_step,
		"Detail": _detail,
		"ElapsedText": _format_elapsed_msec(elapsed_msec),
		"OutputDirectoryAbsolute": _output_directory_absolute,
		"OutputFileAbsolute": _output_file_absolute,
		"OpenOutputFolderOnSuccess": _open_output_folder_on_success,
	}

func _start_next_step() -> void:
	if _pending_steps.is_empty():
		_transition_to("PostChecking", EXPORT_PROGRESS, 1.0, "PostChecking", "Verifying build artifacts")
		_log("Info", "PostChecking", "Checking that the exported %s exists at the configured output path." % _current_request.get("ArtifactLabel", "artifact"))
		if _abort_requested:
			_complete("Canceled", "Build canceled", "Build canceled. Partial outputs may remain in the output folder.")
			return

		var post_check: Dictionary = _post_check_build_outputs(_current_request)
		if not post_check.get("ok", false):
			_fail(post_check.get("error", "Build output validation failed."))
			return

		_output_directory_absolute = String(_current_request.get("OutputDirectoryAbsolute", ""))
		_output_file_absolute = String(_current_request.get("OutputFileAbsolute", ""))
		var version_save_result: Dictionary = _persist_project_version(_current_request)
		if not version_save_result.get("ok", false):
			_log("Warning", "PostChecking", version_save_result.get("error", "Sea Shell DevTools could not save the updated project version."))
		_log("Success", "PostChecking", "Build finished successfully: %s" % _output_file_absolute)
		_complete("Succeeded", "Build complete", "%s export finished successfully." % _current_request.get("ArtifactLabel", "Build"))
		return

	var next_step: Dictionary = _pending_steps.pop_front()
	_start_process_step(next_step)

func _start_process_step(step: Dictionary) -> void:
	var state := String(step.get("State", "Running"))
	var step_id := String(step.get("StepId", "Run"))
	var step_title := String(step.get("StepTitle", step_id))
	var detail := String(step.get("Detail", "Running child process."))
	var executable_path := String(step.get("ExecutablePath", ""))
	var arguments: PackedStringArray = step.get("Arguments", PackedStringArray())
	var phase_floor := VALIDATION_PROGRESS if state == "BuildingSolution" else BUILD_PROGRESS
	var phase_cap := BUILD_PROGRESS if state == "BuildingSolution" else EXPORT_PROGRESS

	_transition_to(state, phase_floor, phase_cap, step_id, detail)
	_log("Info", step_id, "%s started." % step_title)
	_log("Info", step_id, "Command: %s" % _format_command(executable_path, arguments))

	if _abort_requested:
		_complete("Canceled", "Build canceled", "Build canceled. Partial outputs may remain in the output folder.")
		return

	var pipe_result := OS.execute_with_pipe(executable_path, arguments, false)
	if pipe_result.is_empty():
		_fail("%s could not be started." % step_title)
		return

	_active_process = {
		"Pid": int(pipe_result.get("pid", -1)),
		"Stdio": pipe_result.get("stdio"),
		"Stderr": pipe_result.get("stderr"),
		"State": state,
		"StepId": step_id,
		"StepTitle": step_title,
		"CompletedProgress": float(step.get("CompletedProgress", EXPORT_PROGRESS)),
		"StdoutRemainder": "",
		"StderrRemainder": "",
	}

func _validate(profile_snapshot: Dictionary, preset: Dictionary, editor_executable_path: String, project_root_absolute: String) -> Dictionary:
	_transition_to("Validating", 0.0, VALIDATION_PROGRESS, "Validating", "Checking profile, export preset, templates, and output paths")

	if OS.get_name() != "Windows":
		return _error("This v1 build flow currently supports Windows editor hosts only.")

	var resolved_editor_executable_path := editor_executable_path.simplify_path()
	if not FileAccess.file_exists(resolved_editor_executable_path):
		return _error("The current Godot editor executable could not be found at '%s'." % resolved_editor_executable_path)

	var current_project := GodotProjectInfo.load(project_root_absolute)
	if not FileAccess.file_exists(String(current_project.get("ProjectFileAbsolute", ""))):
		return _error("This folder does not look like a Godot project because project.godot is missing.")

	if String(profile_snapshot.get("DisplayName", "")).is_empty():
		return _error("Build profile display name cannot be blank.")

	if String(profile_snapshot.get("ExportPresetName", "")).is_empty():
		return _error("Build profile export preset name cannot be blank.")

	_set_progress(0.04)
	if preset.is_empty():
		return _error("Export preset '%s' was not found in export_presets.cfg." % profile_snapshot.get("ExportPresetName", ""))

	var resolved_platform := SupportedBuildPlatforms.try_resolve_from_preset(preset)
	if not resolved_platform.get("ok", false):
		return _error(resolved_platform.get("error", "The selected export preset is not supported."))
	var platform_info: Dictionary = resolved_platform.get("platform_info", {})

	_set_progress(0.08)
	var output_collection_root_absolute := PathHelpers.resolve_directory(String(profile_snapshot.get("OutputDirectory", "")), String(current_project.get("ProjectRootAbsolute", "")))
	if output_collection_root_absolute.is_empty():
		return _error("Output directory could not be resolved.")
	DirAccess.make_dir_recursive_absolute(output_collection_root_absolute)

	var output_file_name_result := PathHelpers.ensure_output_file_name(
		String(profile_snapshot.get("ExecutableFileName", "")),
		String(platform_info.get("OutputFileExtension", "")),
		String(platform_info.get("ArtifactLabel", "artifact"))
	)
	if not output_file_name_result.get("ok", false):
		return _error(output_file_name_result.get("error", "Output file name is invalid."))
	var output_file_name := String(output_file_name_result.get("value", ""))

	_set_progress(0.11)
	if String(platform_info.get("Platform", "")) == SupportedBuildPlatforms.PLATFORM_WEB and bool(current_project.get("LooksLikeCSharpProject", false)):
		var csharp_markers: Array = []
		if bool(current_project.get("HasTopLevelCsproj", false)):
			csharp_markers.append("a top-level .csproj file")
		if bool(current_project.get("HasCSharpFeature", false)):
			csharp_markers.append("the C# project feature in project.godot")
		return _error("Current project '%s' looks like a C# project because it contains %s. Godot 4 cannot export C# projects to the Web, so Sea Shell DevTools only supports GDScript-only Web projects here." % [current_project.get("ProjectRootAbsolute", ""), " and ".join(csharp_markers)])

	var editor_version_info: Dictionary = _resolve_editor_version_info(resolved_editor_executable_path)
	if not editor_version_info.get("ok", false):
		return editor_version_info

	var template_directory_result: Dictionary = _resolve_template_directory(editor_version_info)
	if not template_directory_result.get("ok", false):
		return template_directory_result
	var template_directory := String(template_directory_result.get("value", ""))
	if bool(template_directory_result.get("autofixed", false)):
		_log("Warning", "Validating", String(template_directory_result.get("message", "")))

	var matching_templates: Array = _find_matching_templates(
		template_directory,
		platform_info,
		int(profile_snapshot.get("BuildMode", BuildProfileScript.BUILD_MODE_RELEASE))
	)
	if matching_templates.is_empty():
		var expected_templates: PackedStringArray = _get_expected_template_names(
			platform_info,
			int(profile_snapshot.get("BuildMode", BuildProfileScript.BUILD_MODE_RELEASE))
		)
		if String(platform_info.get("Platform", "")) == SupportedBuildPlatforms.PLATFORM_WEB:
			return _error("No compatible Web export templates were found for build editor '%s' in '%s'. Sea Shell DevTools accepts %s. Point Build Editor Override at a standard Godot editor with matching Web templates installed." % [resolved_editor_executable_path, template_directory, ", ".join(expected_templates)])
		return _error("Export templates for '%s' are installed, but the expected %s %s template is missing. Expected one of: %s." % [
			editor_version_info.get("NormalizedTemplateToken", ""),
			platform_info.get("ArtifactLabel", "artifact"),
			"release" if int(profile_snapshot.get("BuildMode", BuildProfileScript.BUILD_MODE_RELEASE)) == BuildProfileScript.BUILD_MODE_RELEASE else "debug",
			", ".join(expected_templates),
		])

	var matching_names: Array = []
	for path in matching_templates:
		matching_names.append(String(path).get_file())
	_log("Success", "Validating", "Found compatible export templates in '%s': %s" % [template_directory, ", ".join(matching_names)])

	if String(platform_info.get("Platform", "")) == SupportedBuildPlatforms.PLATFORM_ANDROID_APK:
		var android_toolchain: Dictionary = _validate_android_toolchain(String(editor_version_info.get("NormalizedTemplateToken", "")))
		if not android_toolchain.get("ok", false):
			return android_toolchain

		var android_template: Dictionary = _ensure_android_gradle_build_template(template_directory, String(current_project.get("ProjectRootAbsolute", "")))
		if not android_template.get("ok", false):
			return android_template

	var versioned_output_result: Dictionary = BuildVersioning.resolve_next_build_directory(
		current_project,
		output_collection_root_absolute,
		int(profile_snapshot.get("BuildMode", BuildProfileScript.BUILD_MODE_RELEASE))
	)
	if not versioned_output_result.get("ok", false):
		return _error(versioned_output_result.get("error", "Could not determine the next versioned build folder."))

	var output_directory_absolute := String(versioned_output_result.get("FolderAbsolute", "")).simplify_path()
	DirAccess.make_dir_recursive_absolute(output_directory_absolute)
	var output_file_absolute := output_directory_absolute.path_join(output_file_name)

	_output_directory_absolute = output_directory_absolute
	_output_file_absolute = output_file_absolute
	_created_output_directory_absolute = output_directory_absolute

	_log("Info", "Validating", "Using build editor: %s" % resolved_editor_executable_path)
	_log("Info", "Validating", "Using current Godot project: %s" % current_project.get("ProjectRootAbsolute", ""))
	_log("Info", "Validating", "Using export preset '%s' on platform '%s'." % [preset.get("Name", ""), preset.get("Platform", "")])
	_log("Info", "Validating", "Using build collection root: %s" % output_collection_root_absolute)
	_log("Info", "Validating", "Resolved next build version: %s (%s)." % [
		String(versioned_output_result.get("ResolvedVersionString", "")),
		String(versioned_output_result.get("BuildModeLabel", "release")),
	])
	var history_record: Dictionary = versioned_output_result.get("LatestHistoryRecord", {})
	if not history_record.is_empty():
		_log("Info", "Validating", "Latest existing Sea Shell build folder in this collection: %s." % history_record.get("DirectoryName", ""))
	elif String(current_project.get("ProjectVersion", "")).strip_edges().is_empty():
		_log("Info", "Validating", "No existing Sea Shell build folders were found in this collection, and the project version is blank.")
	_log("Info", "Validating", "Resolved versioned output path: %s" % output_file_absolute)

	_set_progress(VALIDATION_PROGRESS)

	var should_build_solution := bool(profile_snapshot.get("PrebuildDotnetSolution", false)) and bool(current_project.get("HasTopLevelCsproj", false))
	var build_solution_skip_message := "Skipping solution build because the current project does not contain a top-level .csproj file." if bool(profile_snapshot.get("PrebuildDotnetSolution", false)) else "Skipping solution build because the active profile disabled it."

	return {
		"ok": true,
		"Platform": String(platform_info.get("Platform", "")),
		"ProjectRootAbsolute": String(current_project.get("ProjectRootAbsolute", "")),
		"ProjectName": String(versioned_output_result.get("ProjectName", "")),
		"ExportPresetName": profile_snapshot.get("ExportPresetName", ""),
		"ArtifactLabel": platform_info.get("ArtifactLabel", "artifact"),
		"BuildCollectionRootAbsolute": output_collection_root_absolute,
		"OutputDirectoryAbsolute": output_directory_absolute,
		"OutputFileAbsolute": output_file_absolute,
		"CreatedOutputDirectoryAbsolute": output_directory_absolute,
		"ResolvedBuildVersion": String(versioned_output_result.get("ResolvedVersionString", "")),
		"BuildFolderName": String(versioned_output_result.get("FolderName", "")),
		"BuildModeLabel": String(versioned_output_result.get("BuildModeLabel", "release")),
		"ShouldBuildSolution": should_build_solution,
		"BuildSolutionSkipMessage": build_solution_skip_message,
		"BuildSolutionArguments": _create_build_solution_arguments(String(current_project.get("ProjectRootAbsolute", "")), bool(profile_snapshot.get("VerboseGodotLog", false))),
		"ExportArguments": _create_export_arguments(String(current_project.get("ProjectRootAbsolute", "")), profile_snapshot, output_file_absolute),
	}

func _post_check_build_outputs(request: Dictionary) -> Dictionary:
	var output_file_absolute := String(request.get("OutputFileAbsolute", ""))
	if not FileAccess.file_exists(output_file_absolute):
		return _error("Godot reported a successful export, but the expected %s file was not found afterwards." % request.get("ArtifactLabel", "artifact"))

	if String(request.get("Platform", "")) != SupportedBuildPlatforms.PLATFORM_WEB:
		return {"ok": true}

	var output_directory_absolute := String(request.get("OutputDirectoryAbsolute", ""))
	var output_stem := output_file_absolute.get_file().get_basename()
	var sidecar_files: Array = []
	if DirAccess.dir_exists_absolute(output_directory_absolute):
		for file_name in DirAccess.get_files_at(output_directory_absolute):
			var name := String(file_name)
			if name == output_file_absolute.get_file():
				continue
			if name.begins_with(output_stem):
				sidecar_files.append(name)
	sidecar_files.sort()

	if sidecar_files.is_empty():
		_log("Warning", "PostChecking", "The Web HTML output exists, but no matching sidecar files were found beside '%s'." % output_file_absolute.get_file())
		return {"ok": true}

	_log("Info", "PostChecking", "Web sidecar files emitted beside '%s': %s" % [output_file_absolute.get_file(), ", ".join(sidecar_files)])
	_log("Info", "PostChecking", "Web builds must be served over http://localhost. Use Sea Shell DevTools preview instead of opening '%s' directly with file://." % output_file_absolute.get_file())
	return {"ok": true}

func _drain_active_process_output(flush: bool) -> void:
	if _active_process.is_empty():
		return

	_drain_pipe(_active_process.get("Stdio"), _active_process, "StdoutRemainder", String(_active_process.get("State", "")) == "BuildingSolution", false, flush)
	_drain_pipe(_active_process.get("Stderr"), _active_process, "StderrRemainder", String(_active_process.get("State", "")) == "BuildingSolution", true, flush)

func _drain_pipe(file: Variant, process: Dictionary, remainder_key: String, estimate_progress: bool, is_error_stream: bool, flush: bool) -> void:
	if file == null:
		return

	var remainder := String(process.get(remainder_key, ""))
	var loops := 0
	while loops < 32:
		loops += 1
		var chunk: PackedByteArray = file.get_buffer(PROCESS_CHUNK_SIZE)
		var error: int = file.get_error()
		if chunk.is_empty():
			if flush:
				break
			if error != OK:
				break
			break

		remainder += chunk.get_string_from_utf8()
		var normalized := remainder.replace("\r\n", "\n").replace("\r", "\n")
		var parts: Array = Array(normalized.split("\n", false))
		var has_trailing_newline := normalized.ends_with("\n")
		if not has_trailing_newline and not parts.is_empty():
			remainder = String(parts[parts.size() - 1])
			parts.remove_at(parts.size() - 1)
		else:
			remainder = ""

		for raw_line in parts:
			var line: String = _strip_ansi(String(raw_line)).strip_edges()
			if line.is_empty():
				continue
			_on_process_output(String(process.get("StepId", "Run")), line, is_error_stream, estimate_progress)

		if error != OK or chunk.size() < PROCESS_CHUNK_SIZE:
			break

	if flush and not remainder.strip_edges().is_empty():
		_on_process_output(String(process.get("StepId", "Run")), _strip_ansi(remainder).strip_edges(), is_error_stream, estimate_progress)
		remainder = ""

	process[remainder_key] = remainder

func _on_process_output(step_id: String, line: String, is_error_stream: bool, estimate_progress: bool) -> void:
	var severity: String = _classify_severity(line, is_error_stream)
	_log(severity, step_id, line)
	if estimate_progress:
		_nudge_progress()
	_detail = line

func _transition_to(state: String, phase_floor: float, phase_cap: float, step: String, detail: String) -> void:
	_state = state
	_phase_floor = phase_floor
	_phase_cap = phase_cap
	_phase_started_msec = Time.get_ticks_msec()
	_current_step = step
	_detail = detail
	_progress01 = max(_progress01, phase_floor)

func _set_progress(progress01: float) -> void:
	_progress01 = clamp(progress01, 0.0, 1.0)

func _nudge_progress() -> void:
	if not _is_estimating(_state):
		return
	_progress01 = min(_phase_cap, _progress01 + 0.01)

func _complete(state: String, step: String, detail: String) -> void:
	if state != "Succeeded":
		_cleanup_failed_output_directory()

	_state = state
	_current_step = step
	_detail = detail
	if state == "Succeeded":
		_progress01 = 1.0
	_is_busy = false
	_finished_msec = Time.get_ticks_msec()

	match state:
		"Succeeded":
			_log("Success", step, detail)
		"Canceled":
			_log("Warning", step, detail)
		_:
			_log("Error", step, detail)

	if state == "Succeeded":
		_created_output_directory_absolute = ""

func _fail(message: String) -> void:
	_log("Error", "Failed", message)
	_complete("Failed", "Build failed", message)

func _persist_project_version(request: Dictionary) -> Dictionary:
	var resolved_version := String(request.get("ResolvedBuildVersion", "")).strip_edges()
	if resolved_version.is_empty():
		return {
			"ok": false,
			"error": "Sea Shell DevTools did not resolve a semantic version for this build.",
		}

	var previous_version := String(ProjectSettings.get_setting(BuildVersioning.PROJECT_VERSION_SETTING_KEY, "")).strip_edges()
	if previous_version == resolved_version:
		_log("Info", "PostChecking", "Project version is already '%s'." % resolved_version)
		return {"ok": true}

	ProjectSettings.set_setting(BuildVersioning.PROJECT_VERSION_SETTING_KEY, resolved_version)
	var save_error := ProjectSettings.save()
	if save_error != OK:
		ProjectSettings.set_setting(BuildVersioning.PROJECT_VERSION_SETTING_KEY, previous_version)
		return {
			"ok": false,
			"error": "Sea Shell DevTools built version '%s', but could not save application/config/version back to project.godot. Godot returned '%s'." % [resolved_version, error_string(save_error)],
		}

	_log("Success", "PostChecking", "Updated application/config/version from '%s' to '%s'." % [previous_version if not previous_version.is_empty() else "<blank>", resolved_version])
	return {"ok": true}

func _cleanup_failed_output_directory() -> void:
	var directory_to_remove := _created_output_directory_absolute.simplify_path()
	if directory_to_remove.is_empty():
		return
	if not DirAccess.dir_exists_absolute(directory_to_remove):
		_created_output_directory_absolute = ""
		return

	_remove_directory_recursive(directory_to_remove)
	if DirAccess.dir_exists_absolute(directory_to_remove):
		_log("Warning", "Cleanup", "Sea Shell DevTools could not fully remove failed build folder '%s'. Partial artifacts remain." % directory_to_remove)
	else:
		_log("Info", "Cleanup", "Removed failed build folder '%s'." % directory_to_remove)
	_created_output_directory_absolute = ""

func _log(severity: String, step: String, message: String) -> void:
	_pending_logs.append({
		"Timestamp": Time.get_time_string_from_system(),
		"Step": step,
		"Severity": severity,
		"Message": message,
	})

func _is_estimating(state: String) -> bool:
	return state in ["Validating", "BuildingSolution", "Exporting"]

func _classify_severity(line: String, is_error_stream: bool) -> String:
	var lowered := line.to_lower()
	if "error" in lowered:
		return "Error"
	if "warning" in lowered:
		return "Warning"
	if is_error_stream:
		return "Warning"
	return "Info"

func _create_build_solution_arguments(project_root_absolute: String, verbose: bool) -> PackedStringArray:
	var args := PackedStringArray(["--headless", "--path", project_root_absolute, "--build-solutions", "--quit"])
	if verbose:
		args.insert(0, "--verbose")
	return args

func _create_export_arguments(project_root_absolute: String, profile_snapshot: Dictionary, output_file_absolute: String) -> PackedStringArray:
	var args := PackedStringArray()
	if bool(profile_snapshot.get("VerboseGodotLog", false)):
		args.append("--verbose")
	args.append("--headless")
	args.append("--path")
	args.append(project_root_absolute)
	args.append("--export-release" if int(profile_snapshot.get("BuildMode", BuildProfileScript.BUILD_MODE_RELEASE)) == BuildProfileScript.BUILD_MODE_RELEASE else "--export-debug")
	args.append(String(profile_snapshot.get("ExportPresetName", "")))
	args.append(output_file_absolute)
	return args

func _resolve_editor_version_info(editor_executable_path: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(editor_executable_path, PackedStringArray(["--version"]), output, true)
	if exit_code != 0 and output.is_empty():
		return _error("Could not determine the current Godot editor version during preflight validation.")

	var combined := "\n".join(output)
	var first_line := ""
	for raw_line in combined.split("\n"):
		var line := String(raw_line).strip_edges()
		if not line.is_empty():
			first_line = line
			break

	if first_line.is_empty():
		return _error("Could not determine the current Godot editor version during preflight validation.")

	var parsed_version: Dictionary = _parse_template_version_descriptor(first_line)
	if not parsed_version.get("ok", false):
		return _error("Could not parse a Godot export template version from '%s'." % first_line)

	return {
		"ok": true,
		"RawVersionLine": first_line,
		"NormalizedTemplateToken": parsed_version.get("ExpectedTemplateToken", ""),
		"ExpectedTemplateToken": parsed_version.get("ExpectedTemplateToken", ""),
		"VersionNumberToken": parsed_version.get("VersionNumberToken", ""),
		"CompatibilityFamilyToken": parsed_version.get("CompatibilityFamilyToken", ""),
		"MajorMinorToken": parsed_version.get("MajorMinorToken", ""),
		"StatusToken": parsed_version.get("StatusToken", ""),
		"PatchNumber": parsed_version.get("PatchNumber", -1),
		"IsMono": parsed_version.get("IsMono", false),
		"LookupTokens": parsed_version.get("LookupTokens", []),
	}

func _resolve_template_directory(version_info: Dictionary) -> Dictionary:
	var search_roots: Array = []
	var appdata := OS.get_environment("APPDATA").strip_edges()
	if not appdata.is_empty():
		search_roots.append(appdata.path_join("Godot").path_join("export_templates"))
	var local_appdata := OS.get_environment("LOCALAPPDATA").strip_edges()
	if not local_appdata.is_empty():
		search_roots.append(local_appdata.path_join("Godot").path_join("export_templates"))

	var expected_template_token := String(version_info.get("ExpectedTemplateToken", "")).strip_edges()
	if expected_template_token.is_empty():
		return _error("Could not determine the expected export template folder name for build editor '%s'." % version_info.get("RawVersionLine", ""))

	var alias_error_message := ""
	for search_root in search_roots:
		if not DirAccess.dir_exists_absolute(search_root):
			continue

		var exact_candidate: String = search_root.path_join(expected_template_token)
		if DirAccess.dir_exists_absolute(exact_candidate):
			return {
				"ok": true,
				"value": exact_candidate,
			}

		var records: Array = _collect_template_directory_records(search_root)
		var exact_record: Dictionary = _find_template_directory_record_by_token(records, expected_template_token)
		if not exact_record.is_empty():
			var exact_alias_result: Dictionary = _ensure_template_directory_alias(search_root, expected_template_token, exact_record)
			if exact_alias_result.get("ok", false):
				return exact_alias_result
			alias_error_message = String(exact_alias_result.get("error", alias_error_message))
			continue

		var compatible_record: Dictionary = _find_compatible_template_directory_record(records, version_info)
		if compatible_record.is_empty():
			continue

		var compatible_alias_result: Dictionary = _ensure_template_directory_alias(search_root, expected_template_token, compatible_record)
		if compatible_alias_result.get("ok", false):
			return compatible_alias_result
		alias_error_message = String(compatible_alias_result.get("error", alias_error_message))

	if not alias_error_message.is_empty():
		var install_after_alias_failure: Dictionary = _attempt_auto_install_export_templates(version_info, search_roots)
		if install_after_alias_failure.get("ok", false):
			return install_after_alias_failure
		return _error("%s %s" % [alias_error_message, String(install_after_alias_failure.get("error", "")).strip_edges()])

	var auto_install_result: Dictionary = _attempt_auto_install_export_templates(version_info, search_roots)
	if auto_install_result.get("ok", false):
		return auto_install_result

	var auto_install_error := String(auto_install_result.get("error", "")).strip_edges()
	var message := "Godot export templates for '%s' were not found. Install matching templates for build editor '%s' before exporting." % [version_info.get("NormalizedTemplateToken", ""), version_info.get("RawVersionLine", "")]
	if not auto_install_error.is_empty():
		message += " %s" % auto_install_error
	return _error(message)

func _parse_template_version_descriptor(raw_value: String) -> Dictionary:
	var trimmed := raw_value.strip_edges()
	if trimmed.is_empty():
		return _error("Godot version string was blank.")

	var parts: Array = Array(trimmed.split(".", false))
	if parts.size() < 3:
		return _error("Godot version string '%s' did not have enough segments." % trimmed)

	var major_token := String(parts[0]).strip_edges()
	var minor_token := String(parts[1]).strip_edges()
	if not major_token.is_valid_int() or not minor_token.is_valid_int():
		return _error("Godot version string '%s' did not start with major.minor numbers." % trimmed)

	var cursor := 2
	var patch_number := -1
	var expected_parts: Array = [major_token, minor_token]
	var version_number_parts: Array = [major_token, minor_token]
	if cursor < parts.size() and String(parts[cursor]).is_valid_int():
		patch_number = int(String(parts[cursor]))
		var patch_token := String(parts[cursor])
		expected_parts.append(patch_token)
		version_number_parts.append(patch_token)
		cursor += 1

	if cursor >= parts.size():
		return _error("Godot version string '%s' did not include a status segment." % trimmed)

	var status_token := String(parts[cursor]).strip_edges().to_lower()
	if status_token.is_empty():
		return _error("Godot version string '%s' did not include a valid status segment." % trimmed)
	expected_parts.append(status_token)
	cursor += 1

	var is_mono := false
	if cursor < parts.size() and String(parts[cursor]).strip_edges().to_lower() == "mono":
		expected_parts.append("mono")
		is_mono = true

	var expected_template_token := ".".join(expected_parts)
	var compatibility_parts: Array = [major_token, minor_token, status_token]
	if is_mono:
		compatibility_parts.append("mono")
	var compatibility_family_token := ".".join(compatibility_parts)

	var lookup_tokens: Array = [expected_template_token]
	if compatibility_family_token != expected_template_token:
		lookup_tokens.append(compatibility_family_token)

	return {
		"ok": true,
		"ExpectedTemplateToken": expected_template_token,
		"VersionNumberToken": ".".join(version_number_parts),
		"CompatibilityFamilyToken": compatibility_family_token,
		"MajorMinorToken": "%s.%s" % [major_token, minor_token],
		"StatusToken": status_token,
		"PatchNumber": patch_number,
		"IsMono": is_mono,
		"LookupTokens": lookup_tokens,
	}

func _attempt_auto_install_export_templates(version_info: Dictionary, search_roots: Array) -> Dictionary:
	var status_token := String(version_info.get("StatusToken", "")).strip_edges().to_lower()
	if status_token != "stable":
		return _error("Sea Shell DevTools can only auto-install missing export templates for stable Godot releases right now.")

	var version_number_token := String(version_info.get("VersionNumberToken", "")).strip_edges()
	var expected_template_token := String(version_info.get("ExpectedTemplateToken", "")).strip_edges()
	if version_number_token.is_empty() or expected_template_token.is_empty():
		return _error("Sea Shell DevTools could not determine which export template package should be downloaded automatically.")

	var install_root: String = _choose_template_install_root(search_roots)
	if install_root.is_empty():
		return _error("Sea Shell DevTools could not determine where Godot export templates should be installed on this machine.")

	var destination_directory: String = install_root.path_join(expected_template_token)
	if DirAccess.dir_exists_absolute(destination_directory) and FileAccess.file_exists(destination_directory.path_join("version.txt")):
		return {
			"ok": true,
			"value": destination_directory,
		}

	var slug: String = "mono_export_templates.tpz" if bool(version_info.get("IsMono", false)) else "export_templates.tpz"
	var url: String = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=%s&version=%s" % [slug, version_number_token]
	var file_stem: String = "Godot_v%s-stable_%s" % [version_number_token, "mono_export_templates.tpz" if bool(version_info.get("IsMono", false)) else "export_templates.tpz"]
	var temp_root: String = _choose_download_temp_root()
	if temp_root.is_empty():
		return _error("Sea Shell DevTools could not determine a temporary download folder for auto-installing export templates.")

	DirAccess.make_dir_recursive_absolute(temp_root)
	var temp_tpz_path: String = temp_root.path_join(file_stem)
	var download_result: Dictionary = _download_and_extract_export_templates(url, temp_tpz_path, destination_directory, expected_template_token)
	if not download_result.get("ok", false):
		return download_result

	return {
		"ok": true,
		"value": destination_directory,
		"autofixed": true,
		"message": "Auto-installed Godot export templates for '%s' into '%s' from the official stable download archive." % [expected_template_token, destination_directory],
	}

func _choose_template_install_root(search_roots: Array) -> String:
	for search_root in search_roots:
		var candidate: String = String(search_root).strip_edges()
		if candidate.is_empty():
			continue
		DirAccess.make_dir_recursive_absolute(candidate)
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""

func _choose_download_temp_root() -> String:
	var temp_root: String = OS.get_environment("TEMP").strip_edges()
	if temp_root.is_empty():
		temp_root = OS.get_environment("TMP").strip_edges()
	if temp_root.is_empty():
		return ""
	return temp_root.path_join("SeaShellDevTools").path_join("template_downloads")

func _download_and_extract_export_templates(url: String, temp_tpz_path: String, destination_directory: String, expected_template_token: String) -> Dictionary:
	var powershell_script := "\n".join([
		"$ErrorActionPreference = 'Stop'",
		"$url = '%s'" % _escape_powershell_single_quoted_string(url),
		"$tempPath = '%s'" % _escape_powershell_single_quoted_string(temp_tpz_path),
		"$destinationPath = '%s'" % _escape_powershell_single_quoted_string(destination_directory),
		"$expectedVersion = '%s'" % _escape_powershell_single_quoted_string(expected_template_token),
		"$parentPath = Split-Path -Parent $destinationPath",
		"if (-not [string]::IsNullOrWhiteSpace($parentPath)) { New-Item -ItemType Directory -Force -Path $parentPath | Out-Null }",
		"$tempParent = Split-Path -Parent $tempPath",
		"if (-not [string]::IsNullOrWhiteSpace($tempParent)) { New-Item -ItemType Directory -Force -Path $tempParent | Out-Null }",
		"Invoke-WebRequest -Uri $url -OutFile $tempPath",
		"if (Test-Path -LiteralPath $destinationPath) { Remove-Item -LiteralPath $destinationPath -Force -Recurse }",
		"New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null",
		"Add-Type -AssemblyName System.IO.Compression.FileSystem",
		"[System.IO.Compression.ZipFile]::ExtractToDirectory($tempPath, $destinationPath)",
		"$nestedTemplatesPath = Join-Path $destinationPath 'templates'",
		"if (Test-Path -LiteralPath $nestedTemplatesPath) {",
		"  Get-ChildItem -LiteralPath $nestedTemplatesPath -Force | ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $destinationPath -Force }",
		"  Remove-Item -LiteralPath $nestedTemplatesPath -Force -Recurse",
		"}",
		"[System.IO.File]::WriteAllText((Join-Path $destinationPath 'version.txt'), $expectedVersion + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))",
		"Remove-Item -LiteralPath $tempPath -Force",
	])

	var output: Array = []
	var exit_code := OS.execute("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-Command",
		powershell_script,
	]), output, true)
	if exit_code != 0:
		var details := "\n".join(output).strip_edges()
		var message := "Sea Shell DevTools tried to auto-install missing export templates from the official Godot stable download archive, but that download/extract step failed."
		if not details.is_empty():
			message += " %s" % details
		return _error(message)

	return {"ok": true}

func _escape_powershell_single_quoted_string(value: String) -> String:
	return value.replace("'", "''")

func _collect_template_directory_records(search_root: String) -> Array:
	var records: Array = []
	for directory_name in DirAccess.get_directories_at(search_root):
		var name := String(directory_name)
		var directory_path: String = search_root.path_join(name)
		var version_text := ""
		var version_file_path := directory_path.path_join("version.txt")
		if FileAccess.file_exists(version_file_path):
			version_text = FileAccess.get_file_as_string(version_file_path).strip_edges()

		var parsed_info: Dictionary = {}
		var parsed_from_version: Dictionary = _parse_template_version_descriptor(version_text) if not version_text.is_empty() else {}
		if parsed_from_version.get("ok", false):
			parsed_info = parsed_from_version
		else:
			var parsed_from_name: Dictionary = _parse_template_version_descriptor(name)
			if parsed_from_name.get("ok", false):
				parsed_info = parsed_from_name

		records.append({
			"DirectoryPath": directory_path,
			"Name": name,
			"VersionText": version_text,
			"ParsedInfo": parsed_info,
		})
	return records

func _find_template_directory_record_by_token(records: Array, token: String) -> Dictionary:
	if token.is_empty():
		return {}

	for record in records:
		var typed_record: Dictionary = record
		if _equals_ignore_case(String(typed_record.get("Name", "")), token):
			return typed_record
		if _equals_ignore_case(String(typed_record.get("VersionText", "")), token):
			return typed_record
	return {}

func _find_compatible_template_directory_record(records: Array, version_info: Dictionary) -> Dictionary:
	var expected_family_token := String(version_info.get("CompatibilityFamilyToken", ""))
	var expected_major_minor := String(version_info.get("MajorMinorToken", ""))
	var expected_status := String(version_info.get("StatusToken", ""))
	var expected_patch := int(version_info.get("PatchNumber", -1))
	var expected_is_mono := bool(version_info.get("IsMono", false))

	var best_record: Dictionary = {}
	var best_score := -1
	for record in records:
		var typed_record: Dictionary = record
		var parsed_info: Dictionary = typed_record.get("ParsedInfo", {})
		if parsed_info.is_empty():
			continue
		if String(parsed_info.get("MajorMinorToken", "")) != expected_major_minor:
			continue
		if String(parsed_info.get("StatusToken", "")) != expected_status:
			continue
		if bool(parsed_info.get("IsMono", false)) != expected_is_mono:
			continue

		var score := 200
		if String(parsed_info.get("CompatibilityFamilyToken", "")) == expected_family_token:
			score += 400

		var candidate_patch := int(parsed_info.get("PatchNumber", -1))
		if expected_patch >= 0 and candidate_patch >= 0:
			score += max(0, 100 - abs(candidate_patch - expected_patch))
		elif expected_patch >= 0 and candidate_patch < 0:
			score += 80
		elif expected_patch < 0 and candidate_patch < 0:
			score += 100
		else:
			score += 60

		if score > best_score:
			best_score = score
			best_record = typed_record

	return best_record

func _ensure_template_directory_alias(search_root: String, expected_template_token: String, source_record: Dictionary) -> Dictionary:
	var source_directory: String = String(source_record.get("DirectoryPath", "")).simplify_path()
	if source_directory.is_empty():
		return _error("Could not auto-fix export templates because the source template directory was blank.")

	var destination_directory: String = search_root.path_join(expected_template_token)
	if _equals_ignore_case(source_directory, destination_directory):
		return {
			"ok": true,
			"value": source_directory,
		}

	if DirAccess.dir_exists_absolute(destination_directory):
		return {
			"ok": true,
			"value": destination_directory,
		}

	DirAccess.make_dir_recursive_absolute(destination_directory)
	var copy_result: Dictionary = _copy_directory_recursive(source_directory, destination_directory)
	if not copy_result.get("ok", false):
		return copy_result

	var version_file_path: String = destination_directory.path_join("version.txt")
	var version_file := FileAccess.open(version_file_path, FileAccess.WRITE)
	if version_file == null:
		return _error("Auto-fixed export templates were copied to '%s', but version.txt could not be written there." % destination_directory)
	version_file.store_string("%s\n" % expected_template_token)
	version_file.close()

	return {
		"ok": true,
		"value": destination_directory,
		"autofixed": true,
		"message": "Auto-fixed export template lookup by copying compatible templates from '%s' to '%s' and writing version.txt for '%s'." % [source_directory, destination_directory, expected_template_token],
	}

func _copy_directory_recursive(source_directory: String, destination_directory: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(source_directory):
		return _error("Could not auto-fix export templates because source directory '%s' does not exist." % source_directory)

	DirAccess.make_dir_recursive_absolute(destination_directory)

	for subdirectory in DirAccess.get_directories_at(source_directory):
		var nested_result: Dictionary = _copy_directory_recursive(
			source_directory.path_join(String(subdirectory)),
			destination_directory.path_join(String(subdirectory))
		)
		if not nested_result.get("ok", false):
			return nested_result

	for file_name in DirAccess.get_files_at(source_directory):
		var source_file_path: String = source_directory.path_join(String(file_name))
		var destination_file_path: String = destination_directory.path_join(String(file_name))
		var source_file := FileAccess.open(source_file_path, FileAccess.READ)
		if source_file == null:
			return _error("Could not read template file '%s' while auto-fixing export templates." % source_file_path)
		var target_file := FileAccess.open(destination_file_path, FileAccess.WRITE)
		if target_file == null:
			source_file.close()
			return _error("Could not write template file '%s' while auto-fixing export templates." % destination_file_path)
		target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
		target_file.close()
		source_file.close()

	return {"ok": true}

func _find_matching_templates(template_directory: String, platform_info: Dictionary, build_mode: int) -> Array:
	var patterns: PackedStringArray = _get_expected_template_names(platform_info, build_mode)
	var matches: Array = []
	for file_name in DirAccess.get_files_at(template_directory):
		var normalized := String(file_name)
		for pattern in patterns:
			if normalized.matchn(String(pattern)):
				matches.append(template_directory.path_join(normalized))
				break
	matches.sort()
	return matches

func _get_expected_template_names(platform_info: Dictionary, build_mode: int) -> PackedStringArray:
	return platform_info.get("ReleaseTemplateSearchPatterns", PackedStringArray()) if build_mode == BuildProfileScript.BUILD_MODE_RELEASE else platform_info.get("DebugTemplateSearchPatterns", PackedStringArray())

func _validate_android_toolchain(version_token: String) -> Dictionary:
	var settings_path_result: Dictionary = _resolve_editor_settings_path(version_token)
	if not settings_path_result.get("ok", false):
		return settings_path_result
	var settings_path := String(settings_path_result.get("value", ""))
	if not FileAccess.file_exists(settings_path):
		return _error("Could not find Godot editor settings at '%s' to validate Android export setup." % settings_path)

	var settings: Dictionary = _parse_flat_settings_file(settings_path)
	var android_sdk_path: String = _unquote(String(settings.get("export/android/android_sdk_path", "\"\"")))
	var java_sdk_path: String = _unquote(String(settings.get("export/android/java_sdk_path", "\"\"")))
	if android_sdk_path.is_empty():
		return _error("Godot Editor Settings > Export > Android > Android SDK Path is blank. Official Godot Android export setup requires an Android SDK path before exporting APKs.")
	if not DirAccess.dir_exists_absolute(android_sdk_path):
		return _error("Godot's configured Android SDK Path does not exist: '%s'." % android_sdk_path)

	var adb_path := android_sdk_path.path_join("platform-tools").path_join("adb.exe")
	if not FileAccess.file_exists(adb_path):
		return _error("Godot's configured Android SDK Path does not contain platform-tools/adb: '%s'." % android_sdk_path)

	if java_sdk_path.is_empty():
		return _error("Godot Editor Settings > Export > Android > Java SDK Path is blank. Official Godot Android export setup requires a Java SDK path before exporting APKs.")
	if not DirAccess.dir_exists_absolute(java_sdk_path) and not FileAccess.file_exists(java_sdk_path):
		return _error("Godot's configured Java SDK Path does not exist: '%s'." % java_sdk_path)

	_log("Success", "Validating", "Found Android SDK at '%s'." % android_sdk_path)
	_log("Success", "Validating", "Found Java SDK path at '%s'." % java_sdk_path)
	return {"ok": true}

func _resolve_editor_settings_path(version_token: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(\\d+\\.\\d+)")
	var match := regex.search(version_token)
	if match == null:
		return _error("Could not determine the editor settings file for Godot version '%s'." % version_token)

	var appdata := OS.get_environment("APPDATA").strip_edges()
	if appdata.is_empty():
		return _error("The APPDATA environment variable is not available for editor settings lookup.")

	return {
		"ok": true,
		"value": appdata.path_join("Godot").path_join("editor_settings-%s.tres" % match.get_string(1)),
	}

func _parse_flat_settings_file(absolute_path: String) -> Dictionary:
	var values := {}
	var raw := FileAccess.get_file_as_string(absolute_path)
	for raw_line in raw.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("[") or line.begins_with(";") or line.begins_with("#"):
			continue
		var separator_index := line.find("=")
		if separator_index <= 0:
			continue
		values[line.substr(0, separator_index).strip_edges()] = line.substr(separator_index + 1).strip_edges()
	return values

func _ensure_android_gradle_build_template(template_directory: String, project_root_absolute: String) -> Dictionary:
	var android_build_directory := project_root_absolute.path_join("android").path_join("build")
	var gradle_build_file := android_build_directory.path_join("build.gradle")
	if FileAccess.file_exists(gradle_build_file):
		_log("Success", "Validating", "Found Android Gradle build template at '%s'." % android_build_directory)
		return {"ok": true}

	var android_source_zip := template_directory.path_join("android_source.zip")
	if not FileAccess.file_exists(android_source_zip):
		return _error("Android Gradle build support needs '%s', but that template zip was not found." % android_source_zip)

	var android_root_directory := project_root_absolute.path_join("android")
	DirAccess.make_dir_recursive_absolute(android_root_directory)
	if DirAccess.dir_exists_absolute(android_build_directory):
		_remove_directory_recursive(android_build_directory)
	DirAccess.make_dir_recursive_absolute(android_build_directory)

	var extract_result: Dictionary = _extract_zip_to_directory(android_source_zip, android_build_directory)
	if not extract_result.get("ok", false):
		return extract_result

	_log("Success", "Validating", "Installed Android Gradle build template into '%s'." % android_build_directory)
	return {"ok": true}

func _extract_zip_to_directory(zip_path: String, destination_root: String) -> Dictionary:
	var reader := ZIPReader.new()
	var error := reader.open(zip_path)
	if error != OK:
		return _error("Could not open template zip '%s'. Godot returned '%s'." % [zip_path, error_string(error)])

	for archive_path in reader.get_files():
		var entry := String(archive_path)
		var normalized_entry := entry.replace("\\", "/")
		var target_path := destination_root.path_join(normalized_entry)
		if normalized_entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target_path.trim_suffix("/"))
			continue

		DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			reader.close()
			return _error("Could not write extracted template file '%s'." % target_path)
		file.store_buffer(reader.read_file(entry))
		file.close()

	reader.close()
	return {"ok": true}

func _remove_directory_recursive(directory_path: String) -> void:
	for subdirectory in DirAccess.get_directories_at(directory_path):
		_remove_directory_recursive(directory_path.path_join(String(subdirectory)))
	for file_name in DirAccess.get_files_at(directory_path):
		DirAccess.remove_absolute(directory_path.path_join(String(file_name)))
	DirAccess.remove_absolute(directory_path)

func _format_command(executable_path: String, arguments: PackedStringArray) -> String:
	var parts := [ _quote_argument(executable_path) ]
	for argument in arguments:
		parts.append(_quote_argument(String(argument)))
	return " ".join(parts)

func _quote_argument(argument: String) -> String:
	return "\"%s\"" % argument if " " in argument else argument

func _strip_ansi(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\x1B\\[[0-9;]*[A-Za-z]")
	return regex.sub(value, "", true)

func _format_elapsed_msec(elapsed_msec: int) -> String:
	var total_seconds := int(elapsed_msec / 1000)
	var hours := int(total_seconds / 3600)
	var minutes := int(total_seconds / 60) % 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func _equals_ignore_case(left: String, right: String) -> bool:
	return left.to_lower() == right.to_lower()

func _unquote(raw_value: String) -> String:
	var trimmed := raw_value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed

func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
