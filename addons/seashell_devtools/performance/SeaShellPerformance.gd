@tool
extends Node

const OverlayScript = preload("res://addons/seashell_devtools/performance/SeaShellPerformanceOverlay.gd")
const RecorderScript = preload("res://addons/seashell_devtools/performance/SeaShellPerformanceRecorder.gd")
const SessionStoreScript = preload("res://addons/seashell_devtools/performance/SeaShellPerformanceSessionStore.gd")

const SETTINGS_PACK_PATH := "res://addons/seashell_devtools/settings/packs/SeaShellPerformanceSettings.tres"
const PROVIDER_GROUP := "sea_shell_performance_metric_provider"
const FEEDBACK_EVIDENCE_GROUP := "sea_shell_feedback_evidence_provider"
const PERFORMANCE_OVERLAY_SETTING := "seashell_devtools/performance/debug_overlay_enabled"
const DEFAULT_SESSION_ROOT := "user://sea_shell_performance"
const MAX_RECENT_FEEDBACK_EVENTS := 5

signal frame_sampled(snapshot: Dictionary)
signal capture_saved(record: Dictionary)
signal session_updated(session: Dictionary)
signal custom_metrics_changed

var _settings: Node
var _overlay: CanvasLayer
var _recorder: SeaShellPerformanceRecorder
var _session_store: SeaShellPerformanceSessionStore
var _custom_metrics: Dictionary = {}
var _custom_metric_schema: Dictionary = {}
var _registered_custom_monitor_ids := PackedStringArray()
var _active_spans: Dictionary = {}
var _completed_spans_buffer: Array = []
var _span_token := 0
var _frame_index := 0
var _last_frame_snapshot := {}
var _latest_session_snapshot := {}
var _run_started_usec := 0
var _last_sample_timestamp_usec := 0
var _render_warmup_frames := 0
var _settings_refresh_elapsed := 0.0

func _ready() -> void:
	_resolve_settings()
	_register_settings_pack()
	_recorder = RecorderScript.new()
	_session_store = SessionStoreScript.new()
	_run_started_usec = Time.get_ticks_usec()
	add_to_group(FEEDBACK_EVIDENCE_GROUP)
	_refresh_configuration()
	_apply_overlay_setting()
	set_process(true)

func _exit_tree() -> void:
	finalize_session()
	_remove_overlay()
	_remove_custom_monitors()

func _process(delta: float) -> void:
	_settings_refresh_elapsed += delta
	if _settings_refresh_elapsed >= 0.25:
		_settings_refresh_elapsed = 0.0
		_refresh_configuration()
		_apply_overlay_setting()
	if not _should_sample_runtime():
		return
	var snapshot := _sample_frame()
	var capture_events := _recorder.record_frame(snapshot)
	if capture_events.is_empty():
		return
	for event in capture_events:
		var record: Dictionary = Dictionary(event).get("capture", {})
		capture_saved.emit(record.duplicate(true))
	persist_session_snapshot()

func get_setting_value(item_id: String, fallback: Variant = null) -> Variant:
	return _settings_value(item_id, fallback)

func set_setting_value(item_id: String, value: Variant) -> Dictionary:
	var settings := _resolve_settings()
	if settings == null or not settings.has_method("set_value"):
		return {"ok": false, "error": "SeaShellSettings is unavailable."}
	var result: Dictionary = settings.call("set_value", item_id, value)
	_refresh_configuration()
	_apply_overlay_setting()
	return result

func get_overlay() -> CanvasLayer:
	return _overlay

func get_last_frame_snapshot() -> Dictionary:
	return _last_frame_snapshot.duplicate(true)

func get_capture_records() -> Array:
	return _recorder.get_capture_records() if _recorder != null else []

func get_latest_session_snapshot() -> Dictionary:
	if _latest_session_snapshot.is_empty() and _session_store != null:
		_latest_session_snapshot = _session_store.get_session_snapshot()
	return _latest_session_snapshot.duplicate(true)

func get_active_spans_snapshot() -> Array:
	var result := []
	var now_usec := Time.get_ticks_usec()
	for token in _active_spans.keys():
		var span: Dictionary = _active_spans[token]
		result.append({
			"token": int(token),
			"span_id": String(span.get("span_id", "")),
			"duration_ms": (now_usec - int(span.get("start_usec", now_usec))) / 1000.0,
			"context": Dictionary(span.get("context", {})).duplicate(true),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("duration_ms", 0.0)) > float(b.get("duration_ms", 0.0))
	)
	return result

func get_custom_metric_schema() -> Dictionary:
	return _custom_metric_schema.duplicate(true)

func begin_span(span_id: String, context: Dictionary = {}) -> int:
	_span_token += 1
	_active_spans[_span_token] = {
		"span_id": span_id.strip_edges(),
		"start_usec": Time.get_ticks_usec(),
		"context": context.duplicate(true),
	}
	return _span_token

func end_span(token: int, context: Dictionary = {}) -> Dictionary:
	if not _active_spans.has(token):
		return {"ok": false, "error": "Unknown performance span token '%s'." % token}
	var span: Dictionary = _active_spans[token]
	_active_spans.erase(token)
	var ended_usec := Time.get_ticks_usec()
	var merged_context := Dictionary(span.get("context", {})).duplicate(true)
	for key in context.keys():
		merged_context[key] = context[key]
	var result := {
		"ok": true,
		"token": token,
		"span_id": String(span.get("span_id", "")),
		"start_usec": int(span.get("start_usec", 0)),
		"end_usec": ended_usec,
		"duration_ms": (ended_usec - int(span.get("start_usec", ended_usec))) / 1000.0,
		"context": merged_context,
	}
	_completed_spans_buffer.append(result.duplicate(true))
	return result

func set_custom_metric(metric_id: String, value: Variant, metadata: Dictionary = {}) -> Dictionary:
	return _set_custom_metric_internal(metric_id, value, metadata, "push")

func mark_capture(label := "", context: Dictionary = {}) -> Dictionary:
	var typed_context := context.duplicate(true)
	if bool(typed_context.get("include_screenshot", false)):
		var screenshot := stage_viewport_screenshot()
		if bool(screenshot.get("ok", false)):
			typed_context["screenshot_source_path"] = String(screenshot.get("path", ""))
		else:
			var failure_message := String(screenshot.get("failure_message", screenshot.get("error", ""))).strip_edges()
			if not failure_message.is_empty():
				typed_context["screenshot_failure_message"] = failure_message
			if bool(screenshot.get("skipped", false)):
				typed_context["screenshot_skipped"] = true
	var result := _recorder.request_capture(String(label), typed_context)
	return {"ok": bool(result.get("ok", false)), "message": "Queued performance capture.", "pending_capture": result.get("pending_capture", {})}

func persist_session_snapshot() -> Dictionary:
	if _session_store == null or _recorder == null:
		return {"ok": false, "error": "Sea Shell Performance is unavailable."}
	if not _has_recorded_state():
		return {"ok": false, "skipped": true, "reason": "No performance samples were recorded yet."}
	var state := _build_session_state()
	var result := _session_store.save_session(state)
	_latest_session_snapshot = Dictionary(result.get("session", {})).duplicate(true)
	session_updated.emit(_latest_session_snapshot.duplicate(true))
	return {
		"ok": bool(result.get("ok", false)),
		"session": _latest_session_snapshot.duplicate(true),
		"attachment_paths": result.get("attachment_paths", PackedStringArray()),
		"message": "Saved Sea Shell performance session.",
	}

func finalize_session() -> Dictionary:
	if _session_store == null or _recorder == null:
		return {"ok": false, "error": "Sea Shell Performance is unavailable."}
	if not _has_recorded_state():
		return {"ok": false, "skipped": true, "reason": "No performance samples were recorded."}
	var capture_events := _recorder.finish_recording()
	for event in capture_events:
		var record: Dictionary = Dictionary(event).get("capture", {})
		capture_saved.emit(record.duplicate(true))
	var result := persist_session_snapshot()
	result["message"] = "Finalized Sea Shell performance session."
	return result

func export_session_prompt() -> Dictionary:
	if _latest_session_snapshot.is_empty():
		persist_session_snapshot()
	if _session_store == null:
		return {"ok": false, "error": "Sea Shell Performance is unavailable."}
	return _session_store.export_session_prompt()

func sea_shell_capture_feedback_evidence(_context: Dictionary = {}) -> Dictionary:
	if _latest_session_snapshot.is_empty():
		persist_session_snapshot()
	var attachments := PackedStringArray()
	for path_key in [
		"manifest_absolute_path",
		"frames_absolute_path",
		"metrics_schema_absolute_path",
		"summary_absolute_path",
		"capture_context_absolute_path",
	]:
		var path := String(_latest_session_snapshot.get(path_key, "")).strip_edges()
		if not path.is_empty() and FileAccess.file_exists(path):
			attachments.append(path)
	for attachment in _latest_session_snapshot.get("attachment_paths", PackedStringArray()):
		var absolute_path := String(attachment).strip_edges()
		if not absolute_path.is_empty() and FileAccess.file_exists(absolute_path) and not attachments.has(absolute_path):
			attachments.append(absolute_path)
	var summary_path := String(_latest_session_snapshot.get("summary_absolute_path", "")).strip_edges()
	return {
		"recording_source_path": "",
		"file_attachment_source_path": summary_path,
		"attachment_paths": attachments,
	}

func stage_viewport_screenshot() -> Dictionary:
	if DisplayServer.get_name().to_lower() == "headless":
		return {"ok": false, "skipped": true, "failure_message": "Viewport screenshot capture is unavailable in headless mode."}
	var viewport := get_viewport()
	if viewport == null:
		return {"ok": false, "failure_message": "No viewport is available for screenshot capture."}
	var texture := viewport.get_texture()
	if texture == null:
		return {"ok": false, "failure_message": "The viewport texture is unavailable."}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"ok": false, "failure_message": "The viewport image is empty."}
	var capture_root := ProjectSettings.globalize_path("user://sea_shell_performance_capture_tmp")
	DirAccess.make_dir_recursive_absolute(capture_root)
	var path := capture_root.path_join("performance-capture-%s.png" % Time.get_ticks_msec())
	var error := image.save_png(path)
	if error != OK:
		return {"ok": false, "failure_message": "Could not save screenshot: %s." % error_string(error)}
	return {"ok": true, "path": path}

func _sample_frame() -> Dictionary:
	_refresh_provider_metrics()
	_frame_index += 1
	var timestamp_usec := Time.get_ticks_usec()
	var delta_usec := timestamp_usec - _last_sample_timestamp_usec if _last_sample_timestamp_usec > 0 else 0
	_last_sample_timestamp_usec = timestamp_usec
	var monitor_values := _collect_monitor_values()
	var render_values := _collect_render_values()
	var hovered := _resolve_hovered_control()
	var layer_record := _resolve_layer_record(hovered)
	var snapshot := {
		"frame_index": _frame_index,
		"timestamp_usec": timestamp_usec,
		"frame_time_ms": float(monitor_values.get("process_time_ms", 0.0)),
		"physics_time_ms": float(monitor_values.get("physics_time_ms", 0.0)),
		"navigation_time_ms": float(monitor_values.get("navigation_time_ms", 0.0)),
		"fps_estimate": 1000000.0 / float(delta_usec) if delta_usec > 0 else float(monitor_values.get("reported_fps", 0.0)),
		"reported_fps": float(monitor_values.get("reported_fps", 0.0)),
		"monitors": monitor_values,
		"render": render_values,
		"custom_metrics": _current_custom_metric_values(),
		"completed_spans": _consume_completed_spans(),
		"active_spans": get_active_spans_snapshot(),
		"spike_flags": PackedStringArray(),
		"manual_marks": [],
		"scene_file_path": _current_scene_file_path(),
		"hovered_control_path": String(hovered.get_path()) if hovered != null and hovered.is_inside_tree() else "",
		"hovered_text": _extract_display_text(hovered),
		"hovered_tooltip_text": _extract_tooltip_text(hovered),
		"layer": layer_record,
		"recent_feedback_event_ids": _recent_feedback_event_ids(),
	}
	_last_frame_snapshot = snapshot.duplicate(true)
	frame_sampled.emit(snapshot.duplicate(true))
	return snapshot

func _consume_completed_spans() -> Array:
	var result := _completed_spans_buffer.duplicate(true)
	_completed_spans_buffer.clear()
	return result

func _collect_monitor_values() -> Dictionary:
	var values := {}
	for spec in _monitor_specs():
		var raw_value := float(Performance.get_monitor(int(spec.get("monitor", 0))))
		values[spec.get("id")] = raw_value * float(spec.get("scale", 1.0))
	return values

func _collect_render_values() -> Dictionary:
	var values := {"warmup_ready": _render_warmup_frames >= 2}
	var viewport := get_viewport()
	if viewport == null:
		return values
	_render_warmup_frames += 1
	values["total_objects_in_frame"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	values["total_primitives_in_frame"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	values["total_draw_calls_in_frame"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	values["texture_mem_used_bytes"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	values["buffer_mem_used_bytes"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	var viewport_rid := viewport.get_viewport_rid()
	values["measured_render_time_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) if RenderingServer.has_method("viewport_get_measured_render_time_cpu") else 0.0
	values["measured_render_time_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid) if RenderingServer.has_method("viewport_get_measured_render_time_gpu") else 0.0
	for spec in _viewport_render_specs():
		values[spec.get("id")] = RenderingServer.viewport_get_render_info(
			viewport_rid,
			int(spec.get("type", 0)),
			int(spec.get("info", 0))
		)
	return values

func _refresh_provider_metrics() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for provider in tree.get_nodes_in_group(PROVIDER_GROUP):
		if provider == null or not provider.has_method("sea_shell_collect_performance_metrics"):
			continue
		var provider_result: Variant = provider.call("sea_shell_collect_performance_metrics")
		if typeof(provider_result) != TYPE_DICTIONARY:
			continue
		var metrics: Dictionary = provider_result
		for metric_id in metrics.keys():
			var record := metrics.get(metric_id)
			var value: Variant = record
			var metadata := {"source": "provider", "provider": String(provider.name)}
			if typeof(record) == TYPE_DICTIONARY:
				value = Dictionary(record).get("value")
				for key in Dictionary(record).keys():
					if key == "value":
						continue
					metadata[key] = Dictionary(record).get(key)
			_set_custom_metric_internal(String(metric_id), value, metadata, "provider")

func _set_custom_metric_internal(metric_id: String, value: Variant, metadata: Dictionary, source: String) -> Dictionary:
	var typed_id := metric_id.strip_edges()
	if typed_id.is_empty():
		return {"ok": false, "error": "Performance metric ID cannot be empty."}
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return {"ok": false, "error": "Performance metric '%s' must be numeric." % typed_id}
	var normalized_value := maxf(float(value), 0.0)
	var typed_metadata := metadata.duplicate(true)
	typed_metadata["source"] = source
	_custom_metrics[typed_id] = {
		"value": normalized_value,
		"metadata": typed_metadata,
		"updated_usec": Time.get_ticks_usec(),
	}
	var schema_changed := _ensure_custom_metric_schema(typed_id, typed_metadata)
	_ensure_custom_monitor(typed_id)
	if schema_changed:
		custom_metrics_changed.emit()
	return {"ok": true, "metric_id": typed_id, "value": normalized_value}

func _ensure_custom_metric_schema(metric_id: String, metadata: Dictionary) -> bool:
	var existing: Dictionary = Dictionary(_custom_metric_schema.get(metric_id, {}))
	var next := {
		"id": metric_id,
		"display_name": String(metadata.get("label", metric_id)),
		"units": String(metadata.get("units", "")),
		"provider": String(metadata.get("provider", "")),
		"source": String(metadata.get("source", "")),
		"category": String(metric_id.get_slice("/", 0)),
		"metadata": metadata.duplicate(true),
	}
	if existing == next:
		return false
	_custom_metric_schema[metric_id] = next
	return true

func _ensure_custom_monitor(metric_id: String) -> void:
	var monitor_id := StringName(metric_id)
	if Performance.has_custom_monitor(monitor_id):
		if not _registered_custom_monitor_ids.has(metric_id):
			_registered_custom_monitor_ids.append(metric_id)
		return
	Performance.add_custom_monitor(monitor_id, Callable(self, "_read_custom_monitor").bind(metric_id))
	if not _registered_custom_monitor_ids.has(metric_id):
		_registered_custom_monitor_ids.append(metric_id)

func _read_custom_monitor(metric_id: String) -> float:
	var metric: Dictionary = Dictionary(_custom_metrics.get(metric_id, {}))
	return float(metric.get("value", 0.0))

func _remove_custom_monitors() -> void:
	for metric_id in _registered_custom_monitor_ids:
		var monitor_id := StringName(String(metric_id))
		if Performance.has_custom_monitor(monitor_id):
			Performance.remove_custom_monitor(monitor_id)
	_registered_custom_monitor_ids.clear()

func _current_custom_metric_values() -> Dictionary:
	var values := {}
	for metric_id in _custom_metrics.keys():
		values[metric_id] = float(Dictionary(_custom_metrics.get(metric_id, {})).get("value", 0.0))
	return values

func _build_session_state() -> Dictionary:
	return {
		"capture_mode": String(_settings_value("SeaShell.Performance.CaptureMode", "HybridSpikeBuffer")),
		"run_started_usec": _run_started_usec,
		"frames": _recorder.get_saved_frames(),
		"capture_records": _recorder.get_capture_records(),
		"metrics_schema": _build_metrics_schema(),
		"last_frame": _last_frame_snapshot.duplicate(true),
	}

func _build_metrics_schema() -> Dictionary:
	return {
		"format": "SeaShellPerformanceMetricsSchema",
		"version": 1,
		"built_in_monitors": _monitor_specs(),
		"render_metrics": _render_schema_records(),
		"custom_metrics": _custom_metric_schema.duplicate(true),
	}

func _render_schema_records() -> Array:
	var records := [
		{"id": "total_objects_in_frame", "source": "RenderingServer.get_rendering_info", "units": "count"},
		{"id": "total_primitives_in_frame", "source": "RenderingServer.get_rendering_info", "units": "count"},
		{"id": "total_draw_calls_in_frame", "source": "RenderingServer.get_rendering_info", "units": "count"},
		{"id": "texture_mem_used_bytes", "source": "RenderingServer.get_rendering_info", "units": "bytes", "trend_only": true},
		{"id": "buffer_mem_used_bytes", "source": "RenderingServer.get_rendering_info", "units": "bytes", "trend_only": true},
		{"id": "measured_render_time_cpu_ms", "source": "RenderingServer.viewport_get_measured_render_time_cpu", "units": "ms"},
		{"id": "measured_render_time_gpu_ms", "source": "RenderingServer.viewport_get_measured_render_time_gpu", "units": "ms", "trend_only": true},
	]
	for spec in _viewport_render_specs():
		records.append({
			"id": spec.get("id"),
			"source": "RenderingServer.viewport_get_render_info",
			"units": "count",
			"render_pass": spec.get("type_name"),
		})
	return records

func _refresh_configuration() -> void:
	if _recorder == null:
		_recorder = RecorderScript.new()
	_recorder.configure({
		"capture_mode": _settings_value("SeaShell.Performance.CaptureMode", "HybridSpikeBuffer"),
		"auto_capture_enabled": _settings_value("SeaShell.Performance.AutoCaptureEnabled", true),
		"rolling_buffer_seconds": _settings_value("SeaShell.Performance.RollingBufferSeconds", 20),
		"pre_roll_seconds": _settings_value("SeaShell.Performance.PreRollSeconds", 4.0),
		"post_roll_seconds": _settings_value("SeaShell.Performance.PostRollSeconds", 2.0),
		"spike_threshold_ms": _settings_value("SeaShell.Performance.SpikeThresholdMs", 25.0),
		"spike_cooldown_ms": _settings_value("SeaShell.Performance.SpikeCooldownMs", 3000),
		"max_auto_captures_per_run": _settings_value("SeaShell.Performance.MaxAutoCapturesPerRun", 10),
	})
	if _session_store == null:
		_session_store = SessionStoreScript.new()
	_session_store.configure(String(_settings_value("SeaShell.Performance.SessionRoot", DEFAULT_SESSION_ROOT)))

func _is_performance_enabled() -> bool:
	return bool(_settings_value("SeaShell.Performance.Enabled", true))

func _apply_overlay_setting() -> void:
	var overlay_enabled := _should_show_overlay()
	if overlay_enabled and _overlay == null:
		_overlay = OverlayScript.new()
		_overlay.name = "SeaShellPerformanceOverlay"
		add_child(_overlay)
	elif not overlay_enabled and _overlay != null and is_instance_valid(_overlay):
		_remove_overlay()

func _should_sample_runtime() -> bool:
	if Engine.is_editor_hint():
		return false
	if not OS.has_feature("debug"):
		return false
	return _is_performance_enabled()

func _should_show_overlay() -> bool:
	if Engine.is_editor_hint():
		return false
	if not OS.has_feature("debug"):
		return false
	return bool(_settings_value("SeaShell.Performance.OverlayEnabled", false))

func _has_recorded_state() -> bool:
	return _frame_index > 0 or _recorder.get_saved_frames().size() > 0 or _recorder.get_capture_records().size() > 0

func _remove_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _resolve_settings() -> Node:
	if _settings != null and is_instance_valid(_settings):
		return _settings
	_settings = get_node_or_null("/root/SeaShellSettings")
	return _settings

func _register_settings_pack() -> void:
	var settings := _resolve_settings()
	if settings == null or not settings.has_method("register_pack"):
		return
	var pack := ResourceLoader.load(SETTINGS_PACK_PATH)
	if pack is Resource:
		settings.call("register_pack", pack)

func _settings_value(item_id: String, fallback: Variant) -> Variant:
	var settings := _resolve_settings()
	if settings != null and settings.has_method("get_item") and settings.call("get_item", item_id) != null and settings.has_method("get_value"):
		var value: Variant = settings.call("get_value", item_id)
		return fallback if value == null else value
	if item_id == "SeaShell.Performance.OverlayEnabled":
		return ProjectSettings.get_setting(PERFORMANCE_OVERLAY_SETTING, fallback)
	return fallback

func _resolve_hovered_control() -> Control:
	var viewport := get_viewport()
	if viewport != null and viewport.has_method("gui_get_hovered_control"):
		return viewport.gui_get_hovered_control()
	return null

func _resolve_layer_record(target: Node) -> Dictionary:
	var layers_service := get_node_or_null("/root/SeaShellUiLayers")
	if layers_service == null or not layers_service.has_method("get_layers"):
		return {}
	var layers: Array = layers_service.call("get_layers", true)
	for record in layers:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var root: Variant = Dictionary(record).get("root")
		if root is Node and _is_ancestor_or_same(root, target):
			var copy := Dictionary(record).duplicate(true)
			copy.erase("root")
			copy.erase("tag")
			return copy
	return {}

func _is_ancestor_or_same(ancestor: Node, node: Node) -> bool:
	if ancestor == null or node == null:
		return false
	var cursor := node
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false

func _extract_display_text(node: Node) -> String:
	if node == null:
		return ""
	for property_name in ["text", "placeholder_text", "title"]:
		var value: Variant = node.get(property_name)
		if value != null and not String(value).strip_edges().is_empty():
			return String(value).strip_edges()
	return String(node.name) if node != null else ""

func _extract_tooltip_text(node: Node) -> String:
	if node is Control:
		return String((node as Control).tooltip_text)
	return ""

func _current_scene_file_path() -> String:
	var scene_tree := get_tree()
	if scene_tree == null:
		return ""
	var current_scene := scene_tree.current_scene
	if current_scene == null:
		return ""
	return String(current_scene.scene_file_path).strip_edges()

func _recent_feedback_event_ids() -> Array:
	var feedback := get_node_or_null("/root/SeaShellFeedback")
	if feedback == null or not feedback.has_method("get_recent_events"):
		return []
	var result := []
	for event in feedback.call("get_recent_events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		result.append(String(Dictionary(event).get("event_id", "")))
		if result.size() >= MAX_RECENT_FEEDBACK_EVENTS:
			break
	return result

func _monitor_specs() -> Array:
	return [
		{"id": "reported_fps", "monitor": Performance.TIME_FPS, "units": "fps", "trend_only": true},
		{"id": "process_time_ms", "monitor": Performance.TIME_PROCESS, "scale": 1000.0, "units": "ms"},
		{"id": "physics_time_ms", "monitor": Performance.TIME_PHYSICS_PROCESS, "scale": 1000.0, "units": "ms"},
		{"id": "navigation_time_ms", "monitor": Performance.TIME_NAVIGATION_PROCESS, "scale": 1000.0, "units": "ms"},
		{"id": "memory_static_bytes", "monitor": Performance.MEMORY_STATIC, "units": "bytes", "trend_only": true},
		{"id": "memory_static_max_bytes", "monitor": Performance.MEMORY_STATIC_MAX, "units": "bytes", "trend_only": true},
		{"id": "memory_message_buffer_max_bytes", "monitor": Performance.MEMORY_MESSAGE_BUFFER_MAX, "units": "bytes", "trend_only": true},
		{"id": "object_count", "monitor": Performance.OBJECT_COUNT, "units": "count", "trend_only": true},
		{"id": "resource_count", "monitor": Performance.OBJECT_RESOURCE_COUNT, "units": "count", "trend_only": true},
		{"id": "node_count", "monitor": Performance.OBJECT_NODE_COUNT, "units": "count", "trend_only": true},
		{"id": "orphan_node_count", "monitor": Performance.OBJECT_ORPHAN_NODE_COUNT, "units": "count", "trend_only": true},
		{"id": "physics_2d_active_objects", "monitor": Performance.PHYSICS_2D_ACTIVE_OBJECTS, "units": "count"},
		{"id": "physics_2d_collision_pairs", "monitor": Performance.PHYSICS_2D_COLLISION_PAIRS, "units": "count"},
		{"id": "physics_2d_island_count", "monitor": Performance.PHYSICS_2D_ISLAND_COUNT, "units": "count"},
		{"id": "physics_3d_active_objects", "monitor": Performance.PHYSICS_3D_ACTIVE_OBJECTS, "units": "count"},
		{"id": "physics_3d_collision_pairs", "monitor": Performance.PHYSICS_3D_COLLISION_PAIRS, "units": "count"},
		{"id": "physics_3d_island_count", "monitor": Performance.PHYSICS_3D_ISLAND_COUNT, "units": "count"},
		{"id": "navigation_active_maps", "monitor": Performance.NAVIGATION_ACTIVE_MAPS, "units": "count"},
		{"id": "navigation_region_count", "monitor": Performance.NAVIGATION_REGION_COUNT, "units": "count"},
		{"id": "navigation_agent_count", "monitor": Performance.NAVIGATION_AGENT_COUNT, "units": "count"},
		{"id": "navigation_link_count", "monitor": Performance.NAVIGATION_LINK_COUNT, "units": "count"},
		{"id": "navigation_polygon_count", "monitor": Performance.NAVIGATION_POLYGON_COUNT, "units": "count"},
		{"id": "navigation_edge_count", "monitor": Performance.NAVIGATION_EDGE_COUNT, "units": "count"},
	]

func _viewport_render_specs() -> Array:
	return [
		{"id": "viewport_visible_objects", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "type_name": "visible", "info": RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME},
		{"id": "viewport_visible_primitives", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "type_name": "visible", "info": RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME},
		{"id": "viewport_visible_draw_calls", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "type_name": "visible", "info": RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME},
		{"id": "viewport_shadow_objects", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, "type_name": "shadow", "info": RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME},
		{"id": "viewport_shadow_primitives", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, "type_name": "shadow", "info": RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME},
		{"id": "viewport_shadow_draw_calls", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, "type_name": "shadow", "info": RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME},
		{"id": "viewport_canvas_objects", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, "type_name": "canvas", "info": RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME},
		{"id": "viewport_canvas_primitives", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, "type_name": "canvas", "info": RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME},
		{"id": "viewport_canvas_draw_calls", "type": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, "type_name": "canvas", "info": RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME},
	]
