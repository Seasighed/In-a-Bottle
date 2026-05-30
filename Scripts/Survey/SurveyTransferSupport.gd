class_name SurveyTransferSupport
extends RefCounted

const SURVEY_SUBMISSION_BUNDLE = preload("res://Scripts/Survey/SurveySubmissionBundle.gd")
const SURVEY_UPLOAD_AUDIT_STORE = preload("res://Scripts/Survey/SurveyUploadAuditStore.gd")

static func build_upload_package(survey: SurveyDefinition, template_path: String, answers: Dictionary, summary_data: Dictionary, install_id: String, scrub_identifying_info: bool, session_metrics: Dictionary, minimum_answered_questions_for_upload: int, upload_cooldown_seconds: int, upload_max_attempts_per_window: int, upload_attempt_window_seconds: int, audit_context: Dictionary = {}) -> Dictionary:
	if survey == null:
		return {}
	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(
		survey,
		template_path,
		answers,
		summary_data,
		install_id,
		scrub_identifying_info,
		session_metrics
	)
	if upload_package.is_empty():
		return {}
	var stats: Dictionary = upload_package.get("stats", {}) as Dictionary
	var total_question_count: int = max(int(stats.get("total_question_count", 0)), 0)
	var min_required_answers: int = min(max(minimum_answered_questions_for_upload, 0), total_question_count)
	var audit: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		str(upload_package.get("payload_hash", "")).strip_edges(),
		int(stats.get("valid_response_count", 0)),
		min_required_answers,
		upload_cooldown_seconds,
		upload_max_attempts_per_window,
		upload_attempt_window_seconds,
		audit_context
	)
	upload_package["min_required_answers"] = min_required_answers
	upload_package["session_metrics"] = session_metrics.duplicate(true)
	upload_package["audit_context"] = audit_context.duplicate(true)
	upload_package["audit"] = audit
	return upload_package

static func configured_upload_headers(upload_request_headers: PackedStringArray) -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	for raw_header in upload_request_headers:
		var header_text: String = str(raw_header).strip_edges()
		if header_text.is_empty():
			continue
		if header_text.to_lower().begins_with("content-type:"):
			continue
		headers.append(header_text)
	return headers

static func copy_text_to_clipboard(contents: String, empty_message: String, success_message: String) -> Dictionary:
	if contents.strip_edges().is_empty():
		return {
			"ok": false,
			"message": empty_message
		}
	DisplayServer.clipboard_set(contents)
	return {
		"ok": true,
		"message": success_message
	}

static func supports_browser_file_share() -> bool:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return false
	var supported: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				return !!(
					window &&
					window.navigator &&
					typeof window.navigator.share === 'function' &&
					typeof window.File === 'function' &&
					typeof window.Blob === 'function'
				);
			} catch (error) {
				return false;
			}
		})()
	""", true)
	return bool(supported)

static func share_buffer_to_browser(buffer: PackedByteArray, file_name: String, mime_type: String, title: String, text: String) -> Dictionary:
	if buffer.is_empty():
		return {
			"ok": false,
			"message": "Nothing is available to share yet."
		}
	if not supports_browser_file_share():
		return {
			"ok": false,
			"message": "Browser file sharing is unavailable in this build."
		}
	var resolved_file_name: String = file_name.strip_edges()
	if resolved_file_name.is_empty():
		resolved_file_name = "download.bin"
	var resolved_mime_type: String = mime_type.strip_edges()
	if resolved_mime_type.is_empty():
		resolved_mime_type = "application/octet-stream"
	var script := """
		(async function () {
			const base64 = %s;
			const fileName = %s;
			const mimeType = %s;
			const title = %s;
			const text = %s;
			const binary = window.atob(base64);
			const bytes = new Uint8Array(binary.length);
			for (let index = 0; index < binary.length; index += 1) {
				bytes[index] = binary.charCodeAt(index);
			}
			const blob = new Blob([bytes], { type: mimeType || 'application/octet-stream' });
			const file = new File([blob], fileName, { type: mimeType || 'application/octet-stream' });
			const downloadFallback = () => {
				const url = URL.createObjectURL(blob);
				const anchor = document.createElement('a');
				anchor.href = url;
				anchor.download = fileName;
				anchor.style.display = 'none';
				document.body.appendChild(anchor);
				anchor.click();
				anchor.remove();
				window.setTimeout(() => URL.revokeObjectURL(url), 2000);
			};
			let shouldAttemptShare = !!(window.navigator && typeof window.navigator.share === 'function');
			if (shouldAttemptShare && typeof window.navigator.canShare === 'function') {
				try {
					shouldAttemptShare = window.navigator.canShare({ files: [file] });
				} catch (error) {
					shouldAttemptShare = false;
				}
			}
			if (shouldAttemptShare) {
				try {
					await window.navigator.share({
						files: [file],
						title,
						text
					});
					return;
				} catch (error) {
				}
			}
			downloadFallback();
		})()
	""" % [
		_js_string_literal(Marshalls.raw_to_base64(buffer)),
		_js_string_literal(resolved_file_name),
		_js_string_literal(resolved_mime_type),
		_js_string_literal(title.strip_edges()),
		_js_string_literal(text.strip_edges())
	]
	JavaScriptBridge.eval(script, true)
	return {
		"ok": true,
		"message": "The browser will try to share the file first and download it if sharing is unavailable."
	}

static func is_upload_endpoint_configured(upload_endpoint_url: String) -> bool:
	return not upload_endpoint_url.strip_edges().is_empty()

static func format_upload_response_body(body_text: String) -> String:
	var trimmed_body := body_text.strip_edges()
	if trimmed_body.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(trimmed_body)
	if parsed is Dictionary or parsed is Array:
		return JSON.stringify(parsed, "\t")
	return trimmed_body

static func format_upload_response(result: int, response_code: int, headers: PackedStringArray, body_text: String) -> String:
	var lines: Array[String] = []
	lines.append("Result: %s" % _http_request_result_label(result))
	lines.append("HTTP Status: %d" % response_code)
	if not headers.is_empty():
		lines.append("")
		lines.append("Headers:")
		for header in headers:
			lines.append(str(header))
	var formatted_body: String = format_upload_response_body(body_text)
	if not formatted_body.is_empty():
		lines.append("")
		lines.append("Body:")
		lines.append(formatted_body)
	return "\n".join(lines).strip_edges()

static func build_upload_completion_state(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	var body_text: String = body.get_string_from_utf8()
	var accepted := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	return {
		"accepted": accepted,
		"response_text": format_upload_response(result, response_code, headers, body_text),
		"status_text": "Upload accepted by the server." if accepted else "Upload failed or was rejected by the server.",
		"is_error": not accepted
	}

static func build_upload_status_reset_state(clear_response: bool, current_response_text: String) -> Dictionary:
	return {
		"upload_in_progress": false,
		"pending_upload_payload_hash": "",
		"last_upload_status_text": "",
		"last_upload_status_is_error": false,
		"last_upload_response_text": "" if clear_response else current_response_text
	}

static func _http_request_result_label(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Body size limit exceeded"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "Body decompress failed"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Cannot write download file"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Redirect limit reached"
		HTTPRequest.RESULT_TIMEOUT:
			return "Timeout"
	return "Unknown result"

static func _js_string_literal(value: String) -> String:
	return JSON.stringify(value)
