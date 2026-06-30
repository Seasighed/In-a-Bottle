class_name SurveyPlayfulCopy
extends RefCounted

static func upload_success(playful_copy: bool, server_message: String = "") -> String:
	if playful_copy:
		return "Upload accepted. The bottle made it to the intake shelf."
	return server_message.strip_edges() if not server_message.strip_edges().is_empty() else "Upload accepted."

static func upload_failure(reason: String, server_message: String = "") -> String:
	var normalized_reason := reason.strip_edges()
	match normalized_reason:
		"network", "request_failed":
			return "Network trouble: the upload endpoint could not be reached. Save a local copy before trying again."
		"duplicate_payload":
			return "This response was already uploaded. Save a local copy if you want your own backup."
		"not_allowlisted":
			return "The server rejected this survey as not allowlisted. Local JSON and CSV exports still work."
		"rate_limited":
			return "Upload limit reached for this device. Save a local copy and try again later."
		"malformed_json", "malformed_payload", "unsupported_format", "missing_identity", "invalid_identity", "missing_payload_hash", "unsupported_media_type":
			return "The server could not read this upload payload. Save a local copy before retrying."
		"storage_not_configured", "storage_error", "duplicate_check_failed", "server_error":
			return "The private intake server is not ready. Save a local copy and try again later."
		"cors_not_allowed":
			return "This hosted page is not allowed to upload to the intake endpoint. Save a local copy instead."
	if not server_message.strip_edges().is_empty():
		return "%s Save a local copy before trying again." % server_message.strip_edges()
	return "Upload failed or was rejected by the server. Save a local copy before trying again."
