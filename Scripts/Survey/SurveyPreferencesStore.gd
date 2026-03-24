class_name SurveyPreferencesStore
extends RefCounted

const STORE_PATH := "user://survey_preferences.json"

static func load_preferences() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return (parsed as Dictionary).duplicate(true)

static func save_preferences(preferences: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(preferences, "\t"))
	file.close()
	return true