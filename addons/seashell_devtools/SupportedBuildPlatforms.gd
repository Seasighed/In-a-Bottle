@tool
extends RefCounted

const PLATFORM_WINDOWS_DESKTOP := "windows_desktop"
const PLATFORM_ANDROID_APK := "android_apk"
const PLATFORM_WEB := "web"

const WINDOWS_DESKTOP := {
	"Platform": PLATFORM_WINDOWS_DESKTOP,
	"GodotPlatformName": "Windows Desktop",
	"FriendlyName": "Windows Desktop",
	"ArtifactLabel": "Windows EXE",
	"OutputFileExtension": ".exe",
	"DefaultOutputDirectory": "artifacts/windows",
	"DebugTemplateSearchPatterns": ["windows_debug_*.exe"],
	"ReleaseTemplateSearchPatterns": ["windows_release_*.exe"],
}

const ANDROID_APK := {
	"Platform": PLATFORM_ANDROID_APK,
	"GodotPlatformName": "Android",
	"FriendlyName": "Android APK",
	"ArtifactLabel": "Android APK",
	"OutputFileExtension": ".apk",
	"DefaultOutputDirectory": "artifacts/android",
	"DebugTemplateSearchPatterns": ["android_debug.apk"],
	"ReleaseTemplateSearchPatterns": ["android_release.apk"],
}

const WEB := {
	"Platform": PLATFORM_WEB,
	"GodotPlatformName": "Web",
	"FriendlyName": "Web",
	"ArtifactLabel": "Web HTML",
	"OutputFileExtension": ".html",
	"DefaultOutputDirectory": "artifacts/web",
	"DefaultOutputFileName": "index.html",
	"DebugTemplateSearchPatterns": [
		"web_debug.zip",
		"web_nothreads_debug.zip",
		"web_dlink_debug.zip",
		"web_dlink_nothreads_debug.zip",
	],
	"ReleaseTemplateSearchPatterns": [
		"web_release.zip",
		"web_nothreads_release.zip",
		"web_dlink_release.zip",
		"web_dlink_nothreads_release.zip",
	],
}

static func get_all() -> Array:
	return [WINDOWS_DESKTOP, ANDROID_APK, WEB]

static func normalize_platform_token(raw_value: String) -> String:
	var value := raw_value.strip_edges().to_lower()
	match value:
		PLATFORM_WINDOWS_DESKTOP, "windows desktop":
			return PLATFORM_WINDOWS_DESKTOP
		PLATFORM_ANDROID_APK, "android", "android apk":
			return PLATFORM_ANDROID_APK
		PLATFORM_WEB, "web html":
			return PLATFORM_WEB
		_:
			return PLATFORM_WINDOWS_DESKTOP

static func try_resolve_by_token(raw_value: String) -> Dictionary:
	var token := normalize_platform_token(raw_value)
	match token:
		PLATFORM_WINDOWS_DESKTOP:
			return {
				"ok": true,
				"platform_info": WINDOWS_DESKTOP,
			}
		PLATFORM_ANDROID_APK:
			return {
				"ok": true,
				"platform_info": ANDROID_APK,
			}
		PLATFORM_WEB:
			return {
				"ok": true,
				"platform_info": WEB,
			}
		_:
			return {
				"ok": false,
				"error": "Unsupported platform token '%s'." % raw_value,
			}

static func is_eligible_preset(preset: Dictionary) -> bool:
	var platform := String(preset.get("Platform", ""))
	return platform.to_lower() in ["windows desktop", "android", "web"]

static func try_resolve_from_preset(preset: Dictionary) -> Dictionary:
	if preset.is_empty():
		return {
			"ok": false,
			"error": "No export preset is selected.",
		}

	var platform := String(preset.get("Platform", ""))
	if platform.to_lower() == "windows desktop":
		return {
			"ok": true,
			"platform_info": WINDOWS_DESKTOP,
		}

	if platform.to_lower() == "android":
		var configured_extension := String(preset.get("ExportPath", "")).get_extension().to_lower()
		if configured_extension == "aab":
			return {
				"ok": false,
				"error": "Export preset '%s' is configured for AAB output in Godot's export menu. Sea Shell DevTools currently supports Android APK presets first." % preset.get("Name", "Android"),
			}

		if configured_extension != "" and configured_extension != "apk":
			return {
				"ok": false,
				"error": "Export preset '%s' targets Android, but its configured export path ends with '.%s'. Sea Shell DevTools currently expects Android APK presets." % [preset.get("Name", "Android"), configured_extension],
			}

		if not _preset_get_option_bool(preset, "gradle_build/use_gradle_build"):
			return {
				"ok": false,
				"error": "Export preset '%s' targets Android, but Gradle Build is disabled. Sea Shell DevTools currently expects Android APK presets with Gradle Build enabled." % preset.get("Name", "Android"),
			}

		return {
			"ok": true,
			"platform_info": ANDROID_APK,
		}

	if platform.to_lower() == "web":
		return {
			"ok": true,
			"platform_info": WEB,
		}

	return {
		"ok": false,
		"error": "Export preset '%s' targets '%s', which is not supported yet." % [preset.get("Name", "Preset"), platform],
	}

static func infer_platform_token_from_output_file_name(output_file_name: String) -> String:
	var extension := output_file_name.get_extension().to_lower()
	if extension == "html":
		return PLATFORM_WEB
	if extension == "apk":
		return PLATFORM_ANDROID_APK
	return PLATFORM_WINDOWS_DESKTOP

static func build_default_output_file_name(base_name: String, platform_info: Dictionary) -> String:
	var default_file_name := String(platform_info.get("DefaultOutputFileName", ""))
	if not default_file_name.is_empty():
		return default_file_name

	var stem := base_name.strip_edges()
	if stem.is_empty():
		stem = "BuildOutput"

	var sanitized := ""
	var invalid := "<>:\"/\\|?*"
	for character in stem:
		if invalid.contains(character):
			continue
		sanitized += character

	sanitized = sanitized.strip_edges()
	if sanitized.is_empty():
		sanitized = "BuildOutput"

	return "%s%s" % [sanitized, platform_info.get("OutputFileExtension", "")]

static func _preset_get_option_bool(preset: Dictionary, key: String, default_value := false) -> bool:
	var options: Dictionary = preset.get("Options", {})
	if not options.has(key):
		return default_value

	var raw_value := String(options.get(key, "")).strip_edges().to_lower()
	return raw_value in ["true", "1"]
