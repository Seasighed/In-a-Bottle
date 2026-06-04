extends SceneTree

const SURVEY_BUILD_EXPORT_SUPPORT = preload("res://Scripts/Tools/SurveyBuildExportSupport.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: godot --headless --path . --script res://Scripts/Tools/VerifyExportArtifacts.gd -- <preset name> <target path>")
		quit(2)
		return
	var preset_name := str(args[0]).strip_edges()
	var target_path := str(args[1]).strip_edges()
	var preset := _find_preset(preset_name)
	if preset.is_empty():
		push_error("Unknown export preset: %s" % preset_name)
		quit(3)
		return
	var verification := SURVEY_BUILD_EXPORT_SUPPORT.verify_export_artifacts(target_path, preset)
	if not bool(verification.get("ok", false)):
		var missing := verification.get("missing", PackedStringArray()) as PackedStringArray
		push_error("Missing export artifacts for %s: %s" % [preset_name, ", ".join(missing)])
		quit(1)
		return
	print("Verified export artifacts for %s:" % preset_name)
	for artifact_path in verification.get("artifacts", PackedStringArray()) as PackedStringArray:
		print(" - %s" % artifact_path)
	quit(0)

func _find_preset(preset_name: String) -> Dictionary:
	for preset in SURVEY_BUILD_EXPORT_SUPPORT.available_presets():
		if str(preset.get("name", "")).strip_edges() == preset_name:
			return preset.duplicate(true)
	return {}
