class_name SurveyRuntimeBuildProfile
extends RefCounted

const PROFILE_PARTICIPANT := "participant"
const PROFILE_QA := "qa"

const PARTICIPANT_TEMPLATE_PATH := "res://Dev/SurveyTemplates/maplestory_pulse.json"
const QA_TEMPLATE_PATH := "res://Dev/SurveyTemplates/personal_checkin_debug.json"

const FEATURE_FLAG_PROPERTIES := [
	"enable_lore",
	"enable_character_profile",
	"enable_question_modifiers",
	"enable_gamification",
	"enable_boss_battle",
	"enable_playful_copy",
	"enable_preview_controls",
	"enable_theme_toggle",
	"enable_qa_mode",
	"enable_debug_trace_logging"
]

static var _override_profile_id := ""

static func resolve_runtime_profile(base_feature_flags: Resource, fallback_template_path: String = PARTICIPANT_TEMPLATE_PATH) -> Dictionary:
	var resolved: Dictionary = resolve_profile_id_from_inputs(OS.get_cmdline_user_args(), _web_query_profile_value(), PROFILE_PARTICIPANT)
	var profile_id := str(resolved.get("id", PROFILE_PARTICIPANT)).strip_edges()
	var profile_definition: Dictionary = definition_for_id(profile_id, fallback_template_path)
	return {
		"id": profile_id,
		"display_name": str(profile_definition.get("display_name", profile_id.capitalize())).strip_edges(),
		"template_path": str(profile_definition.get("template_path", fallback_template_path)).strip_edges(),
		"feature_flags": build_feature_flags(base_feature_flags, profile_id),
		"source": str(resolved.get("source", "default")).strip_edges(),
		"is_explicit": bool(resolved.get("is_explicit", false))
	}

static func resolve_profile_id_from_inputs(cmdline_args: Array, web_query_profile: String = "", fallback_profile_id: String = PROFILE_PARTICIPANT) -> Dictionary:
	var override_profile := str(_override_profile_id).strip_edges()
	if not override_profile.is_empty():
		return _profile_resolution(override_profile, "override", fallback_profile_id)
	for index in range(cmdline_args.size()):
		var argument := str(cmdline_args[index]).strip_edges()
		if argument == "--build-profile" and index + 1 < cmdline_args.size():
			return _profile_resolution(str(cmdline_args[index + 1]).strip_edges(), "cmdline", fallback_profile_id)
		if argument.begins_with("--build-profile="):
			return _profile_resolution(argument.get_slice("=", 1), "cmdline", fallback_profile_id)
	var query_profile := str(web_query_profile).strip_edges()
	if not query_profile.is_empty():
		return _profile_resolution(query_profile, "web_query", fallback_profile_id)
	return _profile_resolution(fallback_profile_id, "default", fallback_profile_id, false)

static func definition_for_id(profile_id: String, fallback_template_path: String = PARTICIPANT_TEMPLATE_PATH) -> Dictionary:
	match _normalized_profile_id(profile_id, PROFILE_PARTICIPANT):
		PROFILE_QA:
			return {
				"id": PROFILE_QA,
				"display_name": "QA",
				"template_path": QA_TEMPLATE_PATH
			}
		_:
			return {
				"id": PROFILE_PARTICIPANT,
				"display_name": "Participant",
				"template_path": fallback_template_path if not fallback_template_path.strip_edges().is_empty() else PARTICIPANT_TEMPLATE_PATH
			}

static func build_feature_flags(base_feature_flags: Resource, profile_id: String) -> SurveyFeatureFlags:
	var resolved_base := base_feature_flags if base_feature_flags != null else SurveyFeatureFlags.new()
	var profile_flags := SurveyFeatureFlags.new()
	for property_name in FEATURE_FLAG_PROPERTIES:
		profile_flags.set(property_name, bool(resolved_base.get(property_name)))
	profile_flags.enable_qa_mode = _normalized_profile_id(profile_id, PROFILE_PARTICIPANT) == PROFILE_QA
	if profile_flags.enable_qa_mode:
		profile_flags.enable_playful_copy = false
	return profile_flags

static func reorder_template_summaries(template_summaries: Array[Dictionary], preferred_template_path: String) -> Array[Dictionary]:
	var preferred_path := preferred_template_path.strip_edges()
	if preferred_path.is_empty() or template_summaries.is_empty():
		return template_summaries.duplicate(true)
	var reordered: Array[Dictionary] = []
	for summary in template_summaries:
		if str(summary.get("path", "")).strip_edges() == preferred_path:
			reordered.append(summary.duplicate(true))
	for summary in template_summaries:
		if str(summary.get("path", "")).strip_edges() == preferred_path:
			continue
		reordered.append(summary.duplicate(true))
	return reordered

static func set_override_profile_id(profile_id: String) -> void:
	_override_profile_id = _normalized_profile_id(profile_id, "").strip_edges()

static func clear_override_profile_id() -> void:
	_override_profile_id = ""

static func _normalized_profile_id(raw_profile_id: String, fallback_profile_id: String = PROFILE_PARTICIPANT) -> String:
	var normalized := raw_profile_id.strip_edges().to_lower()
	if normalized in [PROFILE_PARTICIPANT, PROFILE_QA]:
		return normalized
	return fallback_profile_id

static func _profile_resolution(raw_profile_id: String, source: String, fallback_profile_id: String, is_explicit: bool = true) -> Dictionary:
	return {
		"id": _normalized_profile_id(raw_profile_id, fallback_profile_id),
		"source": source,
		"is_explicit": is_explicit
	}

static func _web_query_profile_value() -> String:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var result: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				return String(window.__IN_A_BOTTLE_BUILD_PROFILE || '');
			} catch (error) {
				return '';
			}
		})()
	""", true)
	return str(result).strip_edges()
