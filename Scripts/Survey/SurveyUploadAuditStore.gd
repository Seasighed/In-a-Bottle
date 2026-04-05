class_name SurveyUploadAuditStore
extends RefCounted

const STORE_PATH := "user://survey_upload_audit.json"
const CURRENT_VERSION := 2
const MAX_STORED_ATTEMPTS := 40
const MAX_STORED_TEMPLATE_LOADS := 80

static func get_install_id() -> String:
	var state: Dictionary = _load_state()
	var install_id: String = str(state.get("install_id", "")).strip_edges()
	if not install_id.is_empty():
		return install_id
	install_id = _generate_install_id()
	state["install_id"] = install_id
	_save_state(state)
	return install_id

static func template_key_for_values(survey_id: String, template_version: int, schema_hash: String) -> String:
	var resolved_survey_id: String = survey_id.strip_edges()
	var resolved_version: int = max(template_version, 0)
	var resolved_schema_hash: String = schema_hash.strip_edges().to_lower()
	if resolved_survey_id.is_empty() and resolved_schema_hash.is_empty():
		return ""
	return "%s::v%d::%s" % [
		resolved_survey_id if not resolved_survey_id.is_empty() else "survey",
		resolved_version,
		resolved_schema_hash if not resolved_schema_hash.is_empty() else "no_schema_hash"
	]

static func record_template_load(template_key: String) -> void:
	var normalized_template_key: String = template_key.strip_edges()
	if normalized_template_key.is_empty():
		return
	var state: Dictionary = _load_state()
	var template_loads_value: Variant = state.get("template_loads", [])
	var template_loads: Array = template_loads_value as Array if template_loads_value is Array else []
	template_loads.append({
		"at": int(Time.get_unix_time_from_system()),
		"template_key": normalized_template_key
	})
	while template_loads.size() > MAX_STORED_TEMPLATE_LOADS:
		template_loads.remove_at(0)
	state["template_loads"] = template_loads
	_save_state(state)

static func evaluate_attempt(payload_hash: String, answered_count: int, min_answered_questions: int, cooldown_seconds: int, max_attempts_in_window: int, window_seconds: int, context: Dictionary = {}) -> Dictionary:
	var install_id: String = get_install_id()
	var required_answers: int = max(min_answered_questions, 0)
	if answered_count < required_answers:
		return {
			"ok": false,
			"message": "Answer at least %d question(s) before submitting to the server." % required_answers,
			"install_id": install_id
		}

	var state: Dictionary = _load_state()
	var now: int = int(Time.get_unix_time_from_system())
	var attempts: Array[Dictionary] = _recent_attempts(state, now, window_seconds)
	var template_key: String = str(context.get("template_key", "")).strip_edges()
	var session_duration_seconds: int = max(0, int(context.get("session_duration_seconds", 0)))
	var seconds_to_first_answer: int = int(context.get("seconds_to_first_answer", -1))
	var min_session_duration_seconds: int = max(0, int(context.get("min_session_duration_seconds", 0)))
	var min_seconds_to_first_answer: int = max(0, int(context.get("min_seconds_to_first_answer", 0)))
	var min_seconds_per_answer: float = maxf(0.0, float(context.get("min_seconds_per_answer", 0.0)))
	var max_template_loads_per_window: int = max(0, int(context.get("max_template_loads_per_window", 0)))
	var template_load_window_seconds: int = max(0, int(context.get("template_load_window_seconds", 0)))
	var max_successful_uploads_per_template: int = max(0, int(context.get("max_successful_uploads_per_template", 0)))
	var successful_uploads_per_template_window_seconds: int = max(0, int(context.get("successful_uploads_per_template_window_seconds", 0)))
	var max_successful_uploads_per_install: int = max(0, int(context.get("max_successful_uploads_per_install", 0)))
	var successful_uploads_per_install_window_seconds: int = max(0, int(context.get("successful_uploads_per_install_window_seconds", 0)))
	var required_session_duration_seconds: int = max(min_session_duration_seconds, int(ceili(float(answered_count) * min_seconds_per_answer)))
	var template_load_count_recent := 0
	var successful_upload_count_for_template_recent := 0
	var successful_upload_count_recent := _recent_attempts(state, now, successful_uploads_per_install_window_seconds, true).size()
	if not template_key.is_empty():
		template_load_count_recent = _recent_template_load_count(state, now, template_load_window_seconds, template_key)
		successful_upload_count_for_template_recent = _recent_attempts(state, now, successful_uploads_per_template_window_seconds, true, template_key).size()

	if required_session_duration_seconds > 0 and session_duration_seconds < required_session_duration_seconds:
		return {
			"ok": false,
			"message": "Spend at least %d second(s) in this survey before uploading. This session is only %d second(s) old." % [required_session_duration_seconds, session_duration_seconds],
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if min_seconds_to_first_answer > 0 and seconds_to_first_answer >= 0 and seconds_to_first_answer < min_seconds_to_first_answer:
		return {
			"ok": false,
			"message": "This response started answering too quickly after opening the survey to be accepted automatically.",
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if cooldown_seconds > 0 and not attempts.is_empty():
		var last_attempt_at: int = int(attempts[attempts.size() - 1].get("at", 0))
		var elapsed: int = now - last_attempt_at
		if elapsed < cooldown_seconds:
			return {
				"ok": false,
				"message": "Please wait %d more second(s) before trying another upload." % max(cooldown_seconds - elapsed, 1),
				"install_id": install_id,
				"required_session_duration_seconds": required_session_duration_seconds,
				"template_load_count_recent": template_load_count_recent,
				"successful_upload_count_recent": successful_upload_count_recent,
				"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
			}

	if max_attempts_in_window > 0 and attempts.size() >= max_attempts_in_window:
		return {
			"ok": false,
			"message": "This device has already tried %d upload(s) in the current window. Please pause before sending more." % attempts.size(),
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if max_template_loads_per_window > 0 and not template_key.is_empty() and template_load_count_recent > max_template_loads_per_window:
		return {
			"ok": false,
			"message": "This device has reloaded the same survey template too many times in a short window. Please slow down before uploading again.",
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if max_successful_uploads_per_template > 0 and not template_key.is_empty() and successful_upload_count_for_template_recent >= max_successful_uploads_per_template:
		return {
			"ok": false,
			"message": "This device already sent the maximum number of accepted uploads for this survey template in the current window.",
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if max_successful_uploads_per_install > 0 and successful_upload_count_recent >= max_successful_uploads_per_install:
		return {
			"ok": false,
			"message": "This device already sent the maximum number of accepted uploads in the current moderation window.",
			"install_id": install_id,
			"required_session_duration_seconds": required_session_duration_seconds,
			"template_load_count_recent": template_load_count_recent,
			"successful_upload_count_recent": successful_upload_count_recent,
			"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
		}

	if not payload_hash.is_empty():
		for attempt in attempts:
			if str(attempt.get("payload_hash", "")) == payload_hash and bool(attempt.get("accepted", false)):
				return {
					"ok": false,
					"message": "This exact response payload was already uploaded from this device.",
					"install_id": install_id,
					"required_session_duration_seconds": required_session_duration_seconds,
					"template_load_count_recent": template_load_count_recent,
					"successful_upload_count_recent": successful_upload_count_recent,
					"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
				}

	return {
		"ok": true,
		"message": "Client-side checks passed for this upload.",
		"install_id": install_id,
		"required_session_duration_seconds": required_session_duration_seconds,
		"template_load_count_recent": template_load_count_recent,
		"successful_upload_count_recent": successful_upload_count_recent,
		"successful_upload_count_for_template_recent": successful_upload_count_for_template_recent
	}

static func record_attempt(payload_hash: String, accepted: bool, response_code: int, note: String = "", context: Dictionary = {}) -> void:
	var state: Dictionary = _load_state()
	var attempts_value: Variant = state.get("attempts", [])
	var attempts: Array = attempts_value as Array if attempts_value is Array else []
	var template_key: String = str(context.get("template_key", "")).strip_edges()
	attempts.append({
		"at": int(Time.get_unix_time_from_system()),
		"payload_hash": payload_hash,
		"accepted": accepted,
		"response_code": response_code,
		"note": note.substr(0, min(note.length(), 240)),
		"template_key": template_key
	})
	while attempts.size() > MAX_STORED_ATTEMPTS:
		attempts.remove_at(0)
	state["attempts"] = attempts
	_save_state(state)

static func _recent_attempts(state: Dictionary, now: int, window_seconds: int, accepted_only: bool = false, template_key: String = "") -> Array[Dictionary]:
	var recent: Array[Dictionary] = []
	var attempts_value: Variant = state.get("attempts", [])
	if attempts_value is Array:
		for raw_attempt in attempts_value:
			if not (raw_attempt is Dictionary):
				continue
			var attempt: Dictionary = raw_attempt as Dictionary
			var attempt_at: int = int(attempt.get("at", 0))
			if window_seconds > 0 and (now - attempt_at) > window_seconds:
				continue
			if accepted_only and not bool(attempt.get("accepted", false)):
				continue
			if not template_key.is_empty() and str(attempt.get("template_key", "")).strip_edges() != template_key:
				continue
			recent.append(attempt)
	return recent

static func _recent_template_load_count(state: Dictionary, now: int, window_seconds: int, template_key: String) -> int:
	if template_key.is_empty():
		return 0
	var count := 0
	var template_loads_value: Variant = state.get("template_loads", [])
	if template_loads_value is Array:
		for raw_load in template_loads_value:
			if not (raw_load is Dictionary):
				continue
			var template_load: Dictionary = raw_load as Dictionary
			var load_at: int = int(template_load.get("at", 0))
			if window_seconds > 0 and (now - load_at) > window_seconds:
				continue
			if str(template_load.get("template_key", "")).strip_edges() != template_key:
				continue
			count += 1
	return count

static func _load_state() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return _default_state()
	var file: FileAccess = FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return _default_state()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _default_state()
	var state: Dictionary = parsed as Dictionary
	var version: int = int(state.get("version", 0))
	if version != CURRENT_VERSION:
		if version == 1:
			return {
				"version": CURRENT_VERSION,
				"install_id": str(state.get("install_id", "")).strip_edges(),
				"attempts": state.get("attempts", []),
				"template_loads": []
			}
		return _default_state()
	var normalized: Dictionary = _default_state()
	normalized["install_id"] = str(state.get("install_id", "")).strip_edges()
	normalized["attempts"] = state.get("attempts", [])
	normalized["template_loads"] = state.get("template_loads", [])
	return normalized

static func _save_state(state: Dictionary) -> bool:
	var payload: Dictionary = _default_state()
	payload["install_id"] = str(state.get("install_id", "")).strip_edges()
	payload["attempts"] = state.get("attempts", [])
	payload["template_loads"] = state.get("template_loads", [])
	var file: FileAccess = FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func _default_state() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"install_id": "",
		"attempts": [],
		"template_loads": []
	}

static func _generate_install_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_text: String = "%d:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec(), int(rng.randi())]
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return seed_text.replace(":", "_")
	context.update(seed_text.to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 24)
