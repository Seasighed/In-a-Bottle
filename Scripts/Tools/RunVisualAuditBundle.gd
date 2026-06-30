extends SceneTree

const SURVEY_VISUAL_AUDIT_RUNNER = preload("res://Scripts/Tools/SurveyVisualAuditRunner.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var contract_only := false
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value).strip_edges()
		if argument == "--contract-only":
			contract_only = true
	var runner := SURVEY_VISUAL_AUDIT_RUNNER.new()
	root.add_child(runner)
	runner.status_changed.connect(_on_status_changed)
	var result := await runner.export_visual_audit_bundle({
		"contract_only": contract_only
	})
	var printable := result.duplicate(true)
	printable.erase("buffer")
	print("PLAYTEST_AUDIT_RESULT=%s" % JSON.stringify(printable))
	var ok := bool(result.get("ok", false))
	if not ok:
		push_error(str(result.get("message", "Visual audit bundle export failed.")))
	quit(0 if ok else 1)

func _on_status_changed(message: String, is_error: bool) -> void:
	if is_error:
		push_error(message)
	else:
		print(message)
