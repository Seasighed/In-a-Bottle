class_name SurveyPlatformExports
extends RefCounted

static func supports_image_clipboard_copy() -> bool:
	return OS.has_feature("windows") and not OS.has_feature("web")

static func copy_image_to_clipboard(image: Image, temp_file_name: String) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	if not supports_image_clipboard_copy():
		return false
	var temp_path := _temporary_export_path(temp_file_name)
	if temp_path.is_empty():
		return false
	if image.save_png(temp_path) != OK:
		return false
	var escaped_path := temp_path.replace("'", "''")
	var command := "$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $image = $null; $stream = [System.IO.File]::OpenRead('%s'); try { $image = [System.Drawing.Image]::FromStream($stream); [System.Windows.Forms.Clipboard]::SetImage($image) } finally { if ($image -ne $null) { $image.Dispose() }; $stream.Dispose() }" % escaped_path
	var output: Array = []
	var exit_code := OS.execute("powershell.exe", PackedStringArray(["-NoProfile", "-STA", "-Command", command]), output, true)
	return exit_code == 0

static func _temporary_export_path(file_name: String) -> String:
	var export_dir := ProjectSettings.globalize_path("user://exports")
	var ensure_error := DirAccess.make_dir_recursive_absolute(export_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(export_dir):
		return ""
	return "%s/%s" % [export_dir.trim_suffix("/"), file_name]
