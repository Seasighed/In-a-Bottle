class_name SurveyDebugLogger
extends RefCounted

static func append_text(path: String, text: String) -> void:
	if path.strip_edges().is_empty() or text.is_empty():
		return
	var file: FileAccess = null
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
