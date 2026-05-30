@tool
extends RefCounted
class_name SeaShellPerformanceRecorder

const MODE_HYBRID := "HybridSpikeBuffer"
const MODE_FULL := "FullSession"

var capture_mode := MODE_HYBRID
var auto_capture_enabled := true
var rolling_buffer_seconds := 20.0
var pre_roll_seconds := 4.0
var post_roll_seconds := 2.0
var spike_threshold_ms := 25.0
var spike_cooldown_ms := 3000
var max_auto_captures_per_run := 10

var _rolling_frames: Array = []
var _saved_frames: Array = []
var _saved_frame_keys: Dictionary = {}
var _capture_records: Array = []
var _pending_captures: Array = []
var _last_auto_capture_timestamp_usec := 0
var _auto_capture_count := 0
var _capture_sequence := 0

func configure(options: Dictionary = {}) -> void:
	capture_mode = String(options.get("capture_mode", MODE_HYBRID))
	auto_capture_enabled = bool(options.get("auto_capture_enabled", true))
	rolling_buffer_seconds = maxf(float(options.get("rolling_buffer_seconds", 20.0)), 1.0)
	pre_roll_seconds = maxf(float(options.get("pre_roll_seconds", 4.0)), 0.0)
	post_roll_seconds = maxf(float(options.get("post_roll_seconds", 2.0)), 0.0)
	spike_threshold_ms = maxf(float(options.get("spike_threshold_ms", 25.0)), 0.0)
	spike_cooldown_ms = maxi(int(options.get("spike_cooldown_ms", 3000)), 0)
	max_auto_captures_per_run = maxi(int(options.get("max_auto_captures_per_run", 10)), 0)

func record_frame(snapshot: Dictionary) -> Array:
	if snapshot.is_empty():
		return []
	var frame := snapshot.duplicate(true)
	_rolling_frames.append(frame)
	_trim_rolling_frames(int(frame.get("timestamp_usec", 0)))
	if capture_mode == MODE_FULL:
		_save_frame(frame)
	if capture_mode == MODE_HYBRID and _should_auto_capture(frame):
		_queue_capture("auto_spike", "Spike %.2f ms" % float(frame.get("frame_time_ms", 0.0)), {"auto_capture": true}, frame)
		_last_auto_capture_timestamp_usec = int(frame.get("timestamp_usec", 0))
		_auto_capture_count += 1
	return _finalize_completed_captures(int(frame.get("timestamp_usec", 0)))

func request_capture(label := "", context: Dictionary = {}, reason := "manual_mark") -> Dictionary:
	if _rolling_frames.is_empty():
		return {"ok": false, "error": "No frame samples are available yet."}
	var snapshot: Dictionary = _rolling_frames.back()
	var pending := _queue_capture(reason, String(label), context, snapshot)
	return {"ok": true, "pending_capture": pending.duplicate(true)}

func finish_recording() -> Array:
	var events := []
	var latest_timestamp_usec := int((_rolling_frames.back() as Dictionary).get("timestamp_usec", 0)) if not _rolling_frames.is_empty() else 0
	for pending in _pending_captures.duplicate(true):
		events.append(_build_capture_event(pending, latest_timestamp_usec, true))
	_pending_captures.clear()
	if capture_mode != MODE_FULL and _capture_records.is_empty() and not _rolling_frames.is_empty():
		var latest_frame: Dictionary = _rolling_frames.back()
		var latest_timestamp := int(latest_frame.get("timestamp_usec", 0))
		var summary_window_usec := int(minf(rolling_buffer_seconds, 5.0) * 1000000.0)
		var pending := {
			"capture_id": _next_capture_id(),
			"reason": "run_exit_summary",
			"label": "Run Exit Summary",
			"trigger_frame_index": int(latest_frame.get("frame_index", 0)),
			"trigger_timestamp_usec": latest_timestamp,
			"start_timestamp_usec": maxi(latest_timestamp - summary_window_usec, 0),
			"end_timestamp_usec": latest_timestamp,
			"scene_file_path": String(latest_frame.get("scene_file_path", "")),
			"context": {},
			"screenshot_source_path": "",
		}
		events.append(_build_capture_event(pending, latest_timestamp, true))
	return events

func get_saved_frames() -> Array:
	return _saved_frames.duplicate(true)

func get_capture_records() -> Array:
	return _capture_records.duplicate(true)

func get_latest_capture_record() -> Dictionary:
	return (_capture_records.back() as Dictionary).duplicate(true) if not _capture_records.is_empty() else {}

func get_pending_capture_count() -> int:
	return _pending_captures.size()

func _should_auto_capture(frame: Dictionary) -> bool:
	if not auto_capture_enabled or max_auto_captures_per_run <= 0:
		return false
	if _auto_capture_count >= max_auto_captures_per_run:
		return false
	var frame_time_ms := float(frame.get("frame_time_ms", 0.0))
	if frame_time_ms < spike_threshold_ms:
		return false
	var timestamp_usec := int(frame.get("timestamp_usec", 0))
	if spike_cooldown_ms > 0 and timestamp_usec - _last_auto_capture_timestamp_usec < spike_cooldown_ms * 1000:
		return false
	return true

func _queue_capture(reason: String, label: String, context: Dictionary, snapshot: Dictionary) -> Dictionary:
	var typed_context := context.duplicate(true)
	var trigger_timestamp_usec := int(snapshot.get("timestamp_usec", 0))
	var pending := {
		"capture_id": _next_capture_id(),
		"reason": reason,
		"label": label.strip_edges() if not label.strip_edges().is_empty() else reason.capitalize().replace("_", " "),
		"trigger_frame_index": int(snapshot.get("frame_index", 0)),
		"trigger_timestamp_usec": trigger_timestamp_usec,
		"start_timestamp_usec": maxi(trigger_timestamp_usec - int(pre_roll_seconds * 1000000.0), 0),
		"end_timestamp_usec": trigger_timestamp_usec + int(post_roll_seconds * 1000000.0),
		"scene_file_path": String(snapshot.get("scene_file_path", "")),
		"context": typed_context,
		"screenshot_source_path": String(typed_context.get("screenshot_source_path", "")),
	}
	_pending_captures.append(pending)
	return pending

func _finalize_completed_captures(latest_timestamp_usec: int) -> Array:
	var events := []
	var pending_index := 0
	while pending_index < _pending_captures.size():
		var pending: Dictionary = _pending_captures[pending_index]
		if latest_timestamp_usec < int(pending.get("end_timestamp_usec", 0)):
			pending_index += 1
			continue
		events.append(_build_capture_event(pending, latest_timestamp_usec, false))
		_pending_captures.remove_at(pending_index)
	return events

func _build_capture_event(pending: Dictionary, latest_timestamp_usec: int, truncated_post_roll: bool) -> Dictionary:
	var selected_frames := []
	var max_frame_time_ms := 0.0
	for source in _rolling_frames:
		var frame: Dictionary = source
		var timestamp_usec := int(frame.get("timestamp_usec", 0))
		if timestamp_usec < int(pending.get("start_timestamp_usec", 0)) or timestamp_usec > int(pending.get("end_timestamp_usec", latest_timestamp_usec)):
			continue
		var copy := frame.duplicate(true)
		if int(copy.get("frame_index", -1)) == int(pending.get("trigger_frame_index", -2)):
			if pending.get("reason", "") == "auto_spike":
				var spike_flags: PackedStringArray = copy.get("spike_flags", PackedStringArray())
				if not spike_flags.has("threshold_crossed"):
					spike_flags.append("threshold_crossed")
				copy["spike_flags"] = spike_flags
			else:
				var manual_marks: Array = copy.get("manual_marks", [])
				manual_marks.append({
					"label": String(pending.get("label", "")),
					"reason": String(pending.get("reason", "")),
					"context": Dictionary(pending.get("context", {})).duplicate(true),
				})
				copy["manual_marks"] = manual_marks
		selected_frames.append(copy)
		_save_frame(copy)
		max_frame_time_ms = maxf(max_frame_time_ms, float(copy.get("frame_time_ms", 0.0)))
	if selected_frames.is_empty() and not _rolling_frames.is_empty():
		var fallback := (_rolling_frames.back() as Dictionary).duplicate(true)
		selected_frames.append(fallback)
		_save_frame(fallback)
		max_frame_time_ms = float(fallback.get("frame_time_ms", 0.0))
	var capture_record := pending.duplicate(true)
	capture_record["frame_count"] = selected_frames.size()
	capture_record["max_frame_time_ms"] = max_frame_time_ms
	capture_record["completed_timestamp_usec"] = latest_timestamp_usec
	capture_record["truncated_post_roll"] = truncated_post_roll
	_capture_records.append(capture_record)
	return {"capture": capture_record, "frames": selected_frames}

func _save_frame(frame: Dictionary) -> void:
	var key := _frame_key(frame)
	if _saved_frame_keys.has(key):
		return
	_saved_frame_keys[key] = true
	_saved_frames.append(frame.duplicate(true))

func _trim_rolling_frames(latest_timestamp_usec: int) -> void:
	var earliest_timestamp_usec := latest_timestamp_usec - int(rolling_buffer_seconds * 1000000.0)
	while not _rolling_frames.is_empty():
		var oldest: Dictionary = _rolling_frames[0]
		if int(oldest.get("timestamp_usec", 0)) >= earliest_timestamp_usec:
			break
		_rolling_frames.remove_at(0)

func _frame_key(frame: Dictionary) -> String:
	return "%s:%s" % [int(frame.get("frame_index", 0)), int(frame.get("timestamp_usec", 0))]

func _next_capture_id() -> String:
	_capture_sequence += 1
	return "capture-%02d" % _capture_sequence
