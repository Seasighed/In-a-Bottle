class_name SurveyUploadEligibility
extends RefCounted

const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")

const DEFAULT_ALLOWLIST_PATH := "res://Resources/Survey/UploadAllowlist.json"
const FORMAT_ID := "survey_upload_allowlist"

static func eligibility_for_survey(survey: SurveyDefinition, template_path: String, allowlist_path: String = DEFAULT_ALLOWLIST_PATH) -> Dictionary:
	var normalized_path := template_path.strip_edges()
	var source_kind := source_kind_for_template_path(normalized_path)
	if survey == null:
		return _blocked("missing_survey", "Load a survey before preparing an upload.", normalized_path, source_kind)
	if normalized_path.is_empty():
		return _blocked("missing_template_path", "This survey is missing template path metadata needed for upload validation.", normalized_path, source_kind)
	if source_kind != "builtin":
		return _blocked("custom_survey", "Custom Survey uploads are disabled in this release. You can still save JSON and CSV exports locally.", normalized_path, source_kind)
	if survey.id.strip_edges().is_empty() or survey.template_version <= 0 or survey.schema_hash.strip_edges().is_empty():
		return _blocked("missing_identity", "This survey is missing the id, template version, or schema hash needed for server validation.", normalized_path, source_kind)
	var allowlist := load_allowlist(allowlist_path)
	if not bool(allowlist.get("ok", false)):
		return _blocked("allowlist_unavailable", str(allowlist.get("message", "Upload allowlist could not be loaded.")).strip_edges(), normalized_path, source_kind)
	var expected_key := identity_key(survey.id, survey.template_version, survey.schema_hash)
	var entries: Array = allowlist.get("entries", []) as Array
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("identity_key", "")).strip_edges() != expected_key:
			continue
		return {
			"ok": true,
			"reason": "allowlisted",
			"message": "This bundled survey is approved for upload.",
			"survey_id": survey.id,
			"template_version": survey.template_version,
			"schema_hash": survey.schema_hash,
			"identity_key": expected_key,
			"template_path": normalized_path,
			"source_kind": source_kind,
			"allowlist_path": allowlist_path,
			"label": str(entry.get("label", survey.title)).strip_edges()
		}
	return _blocked("not_allowlisted", "This built-in survey is not on this release's upload allowlist. Save local exports instead.", normalized_path, source_kind, expected_key)

static func load_allowlist(path: String = DEFAULT_ALLOWLIST_PATH) -> Dictionary:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		normalized_path = DEFAULT_ALLOWLIST_PATH
	if not FileAccess.file_exists(normalized_path):
		return {
			"ok": false,
			"message": "Upload allowlist not found: %s" % normalized_path,
			"entries": []
		}
	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"message": "Upload allowlist could not be opened: %s" % normalized_path,
			"entries": []
		}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {
			"ok": false,
			"message": "Upload allowlist root must be a JSON object.",
			"entries": []
		}
	var payload := parsed as Dictionary
	var entries: Array[Dictionary] = []
	var raw_entries: Array = _array_from_variant(payload.get("surveys", payload.get("entries", [])))
	for entry_value in raw_entries:
		if not (entry_value is Dictionary):
			continue
		var entry := _resolve_allowlist_entry(entry_value as Dictionary)
		if entry.is_empty():
			continue
		entries.append(entry)
	return {
		"ok": true,
		"message": "Loaded %d upload allowlist entrie(s)." % entries.size(),
		"format": str(payload.get("format", FORMAT_ID)).strip_edges(),
		"version": int(payload.get("version", 1)),
		"path": normalized_path,
		"entries": entries
	}

static func identity_key(survey_id: String, template_version: int, schema_hash: String) -> String:
	return "%s::v%d::%s" % [survey_id.strip_edges(), max(template_version, 0), schema_hash.strip_edges()]

static func source_kind_for_template_path(template_path: String) -> String:
	var normalized_path := template_path.strip_edges()
	if normalized_path.begins_with("res://"):
		return "builtin"
	if normalized_path.begins_with("user://"):
		return "custom"
	return "custom"

static func _resolve_allowlist_entry(entry: Dictionary) -> Dictionary:
	var template_path := str(entry.get("template_path", "")).strip_edges()
	var survey_id := str(entry.get("survey_id", entry.get("id", ""))).strip_edges()
	var template_version := int(entry.get("template_version", entry.get("version", 0)))
	var schema_hash := str(entry.get("schema_hash", "")).strip_edges()
	if (survey_id.is_empty() or template_version <= 0 or schema_hash.is_empty()) and template_path.begins_with("res://"):
		var summary := SURVEY_TEMPLATE_LOADER.describe_template_file(template_path)
		if bool(summary.get("ok", false)):
			if survey_id.is_empty():
				survey_id = str(summary.get("id", "")).strip_edges()
			if template_version <= 0:
				template_version = int(summary.get("version", 0))
			if schema_hash.is_empty():
				schema_hash = str(summary.get("schema_hash", "")).strip_edges()
	if survey_id.is_empty() or template_version <= 0 or schema_hash.is_empty():
		return {}
	var resolved := {
		"survey_id": survey_id,
		"template_version": template_version,
		"schema_hash": schema_hash,
		"identity_key": identity_key(survey_id, template_version, schema_hash),
		"template_path": template_path,
		"label": str(entry.get("label", survey_id)).strip_edges()
	}
	return resolved

static func _blocked(reason: String, message: String, template_path: String, source_kind: String, identity: String = "") -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"message": message.strip_edges(),
		"identity_key": identity.strip_edges(),
		"template_path": template_path.strip_edges(),
		"source_kind": source_kind.strip_edges()
	}

static func _array_from_variant(value: Variant) -> Array:
	return value as Array if value is Array else []
