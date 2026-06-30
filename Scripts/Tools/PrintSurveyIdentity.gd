extends SceneTree

const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")

const DEFAULT_TEMPLATE_PATH := "res://Dev/SurveyTemplates/maplestory_pulse.json"

func _initialize() -> void:
	var template_path := DEFAULT_TEMPLATE_PATH
	for argument in OS.get_cmdline_user_args():
		var text := str(argument).strip_edges()
		if text.begins_with("--template="):
			template_path = text.get_slice("=", 1).strip_edges()
	var summary := SURVEY_TEMPLATE_LOADER.describe_template_file(template_path)
	if not bool(summary.get("ok", false)):
		push_error("Unable to describe survey template: %s" % template_path)
		for error_text in summary.get("errors", PackedStringArray()) as PackedStringArray:
			push_error(error_text)
		quit(1)
		return
	var identity := {
		"template_path": template_path,
		"survey_id": str(summary.get("id", "")).strip_edges(),
		"template_version": int(summary.get("version", 0)),
		"schema_hash": str(summary.get("schema_hash", "")).strip_edges(),
		"title": str(summary.get("title", "")).strip_edges()
	}
	print("SURVEY_IDENTITY_JSON:%s" % JSON.stringify(identity))
	quit(0)
