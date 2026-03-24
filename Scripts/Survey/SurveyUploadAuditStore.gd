class_name SurveyUploadAuditStore
extends RefCounted

const STORE_PATH := "user://survey_upload_audit.json"
const CURRENT_VERSION := 1
const MAX_STORED_ATTEMPTS := 40

static func get_install_id() -> String:
	var state: Dictionary = _load_state()
	var install_id: String = str(state.get("install_id", "")).strip_edges()
	if not install_id.is_empty():
		return install_id
	install_id = _generate_install_id()
	state["install_id"] = install_id
	_save_state(state)
	return install_id

static func evaluate_attempt(payload_hash: String, answered_count: int, min_answered_questions: int, cooldown_seconds: int, max_attempts_in_window: int, window_seconds: int) -> Dictionary:
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
	if cooldown_seconds > 0 and not attempts.is_empty():
		var last_attempt_at: int = int(attempts[attempts.size() - 1].get("at", 0))
		var elapsed: int = now - last_attempt_at
		if elapsed < cooldown_seconds:
			return {
				"ok": false,
				"message": "Please wait %d more second(s) before trying another upload." % max(cooldown_seconds - elapsed, 1),
				"install_id": install_id
			}

	if max_attempts_in_window > 0 and attempts.size() >= max_attempts_in_window:
		return {
			"ok": false,
			"message": "This device has already tried %d upload(s) in the current window. Please pause before sending more." % attempts.size(),
			"install_id": install_id
		}

	if not payload_hash.is_empty():
		for attempt in attempts:
			if str(attempt.get("payload_hash", "")) == payload_hash and bool(attempt.get("accepted", false)):
				return {
					"ok": false,
					"message": "This exact response payload was already uploaded from this device.",
					"install_id": install_id
				}

	return {
		"ok": true,
		"message": "Client-side checks passed for this upload.",
		"install_id": install_id
	}

static func record_attempt(payload_hash: String, accepted: bool, response_code: int, note: String = "") -> void:
	var state: Dictionary = _load_state()
	var attempts: Array = state.get("attempts", [])
	if not (attempts is Array):
		attempts = []
	(attempts as Array).append({
		"at": int(Time.get_unix_time_from_system()),
		"payload_hash": payload_hash,
		"accepted": accepted,
		"response_code": response_code,
		"note": note.substr(0, min(note.length(), 240))
	})
	while (attempts as Array).size() > MAX_STORED_ATTEMPTS:
		(attempts as Array).remove_at(0)
	state["attempts"] = attempts
	_save_state(state)

static func _recent_attempts(state: Dictionary, now: int, window_seconds: int) -> Array[Dictionary]:
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
			recent.append(attempt)
	return recent

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
	if int(state.get("version", 0)) != CURRENT_VERSION:
		return _default_state()
	var normalized: Dictionary = _default_state()
	normalized["install_id"] = str(state.get("install_id", "")).strip_edges()
	normalized["attempts"] = state.get("attempts", [])
	return normalized

static func _save_state(state: Dictionary) -> bool:
	var payload: Dictionary = _default_state()
	payload["install_id"] = str(state.get("install_id", "")).strip_edges()
	payload["attempts"] = state.get("attempts", [])
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
		"attempts": []
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
