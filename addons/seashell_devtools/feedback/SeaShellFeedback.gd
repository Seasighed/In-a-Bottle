@tool
extends Node

const CueScript = preload("res://addons/seashell_devtools/feedback/SeaShellFeedbackCue.gd")
const OverlayScript = preload("res://addons/seashell_devtools/feedback/SeaShellFeedbackOverlay.gd")
const SessionStoreScript = preload("res://addons/seashell_devtools/feedback/SeaShellFeedbackSessionStore.gd")

const SETTINGS_PACK_PATH := "res://addons/seashell_devtools/settings/packs/SeaShellFeedbackSettings.tres"
const TARGET_GROUP := "sea_shell_feedback_target"
const PROVIDER_GROUP := "sea_shell_feedback_context_provider"
const EVIDENCE_PROVIDER_GROUP := "sea_shell_feedback_evidence_provider"
const UI_LAYER_ROOT_GROUP := "sea_shell_selectable_ui_layer_root"
const AUDIO_MIX_RATE := 22050
const SILENT_DB := -80.0
const MIN_AUDIBLE_VOLUME := 0.0001
const DEFAULT_DEV_VAULT_ROOT := "user://sea_shell_feedback_devlog"
const PULSE_TWEEN_META := "sea_shell_feedback_pulse_tween"
const PULSE_TOKEN_META := "sea_shell_feedback_pulse_token"
const PULSE_BASE_SCALE_META := "sea_shell_feedback_pulse_base_scale"
const SHAKE_TWEEN_META := "sea_shell_feedback_shake_tween"
const SHAKE_TOKEN_META := "sea_shell_feedback_shake_token"
const SHAKE_BASE_POSITION_META := "sea_shell_feedback_shake_base_position"
const FLASH_TWEEN_META := "sea_shell_feedback_flash_tween"
const FLASH_TOKEN_META := "sea_shell_feedback_flash_token"
const FLASH_BASE_VISIBLE_META := "sea_shell_feedback_flash_base_visible"
const FLASH_BASE_COLOR_META := "sea_shell_feedback_flash_base_color"

signal feedback_event(event_id: String, context: Dictionary)
signal cue_played(cue_id: String, result: Dictionary)
signal context_captured(context: Dictionary)
signal dev_feedback_saved(result: Dictionary)

var _settings: Node
var _overlay: SeaShellFeedbackOverlay
var _session_store: SeaShellFeedbackSessionStore
var _cues_by_id: Dictionary = {}
var _cue_ids_by_event: Dictionary = {}
var _audio_players: Dictionary = {}
var _audio_stream_cache: Dictionary = {}
var _visual_effect_owners: Array = []
var _recent_events: Array = []
var _last_context := {}
var _last_cue_result := {}
var _last_capture_request := {}
var _dev_capture_armed := false
var _effect_token := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_resolve_settings()
	_register_settings_pack()
	_register_default_cues()
	_session_store = SessionStoreScript.new()
	_configure_session_store()
	set_process_input(true)

func _exit_tree() -> void:
	stop_all_cues()

func stop_all_cues() -> void:
	_stop_all_visual_effects()
	for cue_id in _audio_players.keys():
		var player: AudioStreamPlayer = _audio_players.get(cue_id)
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
		if player.get_parent() == self:
			remove_child(player)
			player.free()
	_audio_players.clear()
	_audio_stream_cache.clear()

func emit_event(event_id: String, target: Variant = null, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	if not _is_feedback_enabled():
		return {"ok": false, "skipped": true, "reason": "Feedback is disabled."}
	var source := String(options.get("source", "user"))
	if source == "programmatic" and not bool(options.get("allow_programmatic", false)):
		return {"ok": false, "skipped": true, "reason": "Programmatic event ignored."}
	var context := capture_context(target, options.get("event", null), payload)
	context["event_id"] = event_id
	_last_context = context.duplicate(true)
	_record_recent_event(event_id, context)
	var cue_results := []
	var max_duration := 0.0
	var max_protected_time := 0.0
	for cue_id in _cue_ids_by_event.get(event_id, []):
		var cue_result := play_cue(String(cue_id), target, payload, options)
		cue_results.append(cue_result)
		max_duration = maxf(max_duration, float(cue_result.get("duration", 0.0)))
		max_protected_time = maxf(max_protected_time, float(cue_result.get("protected_time", 0.0)))
	feedback_event.emit(event_id, context)
	return {
		"ok": true,
		"event_id": event_id,
		"context": context,
		"cue_results": cue_results,
		"duration": max_duration,
		"protected_time": max_protected_time,
	}

func play_cue(cue_id: String, target: Variant = null, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	if not _is_feedback_enabled():
		return {"ok": false, "skipped": true, "reason": "Feedback is disabled.", "duration": 0.0, "protected_time": 0.0}
	var cue: Resource = _cues_by_id.get(cue_id)
	if cue == null:
		return {"ok": false, "error": "Unknown cue '%s'." % cue_id, "duration": 0.0, "protected_time": 0.0}
	var audio_result := _play_audio_cue(cue, payload, options)
	var visual_result := _play_visual_cue(cue, _resolve_target_node(target), payload, options)
	var duration := maxf(float(options.get("duration", cue.get("Duration"))), float(cue.call("estimated_duration")))
	var protected_time := maxf(float(options.get("protected_time", cue.get("ProtectedTime"))), 0.0)
	var result := {
		"ok": true,
		"cue_id": cue_id,
		"audio": audio_result,
		"visual": visual_result,
		"duration": duration,
		"protected_time": protected_time,
	}
	_last_cue_result = result.duplicate(true)
	cue_played.emit(cue_id, result)
	return result

func register_cue(cue: Resource) -> void:
	if cue == null:
		return
	var cue_id := str(cue.get("CueId")).strip_edges()
	if cue_id.is_empty():
		return
	_cues_by_id[cue_id] = cue
	for event_id in cue.get("EventIds"):
		var typed_event := String(event_id)
		if not _cue_ids_by_event.has(typed_event):
			_cue_ids_by_event[typed_event] = []
		if not _cue_ids_by_event[typed_event].has(cue_id):
			_cue_ids_by_event[typed_event].append(cue_id)

func get_cue(cue_id: String) -> Resource:
	return _cues_by_id.get(cue_id)

func get_recent_events() -> Array:
	return _recent_events.duplicate(true)

func get_last_context() -> Dictionary:
	return _last_context.duplicate(true)

func get_last_cue_result() -> Dictionary:
	return _last_cue_result.duplicate(true)

func get_setting_value(item_id: String, fallback: Variant = null) -> Variant:
	return _settings_value(item_id, fallback)

func set_setting_value(item_id: String, value: Variant) -> Dictionary:
	var settings := _resolve_settings()
	if settings == null or not settings.has_method("set_value"):
		return {"ok": false, "error": "SeaShellSettings is unavailable."}
	return settings.call("set_value", item_id, value)

func capture_context(target: Variant = null, event: Variant = null, payload: Dictionary = {}) -> Dictionary:
	var target_node := _resolve_target_node(target)
	if target_node == null:
		target_node = _resolve_hovered_control()
	var event_position := _event_position(event)
	var tag := _find_target_tag(target_node)
	var target_context := tag.call("capture_feedback_context") if tag != null and tag.has_method("capture_feedback_context") else {}
	var layer_record := _resolve_layer_record(target_node)
	var providers := _capture_provider_context(target_node, event, payload)
	var context := {
		"captured_unix": Time.get_unix_time_from_system(),
		"local_timestamp": Time.get_datetime_string_from_system(false, true),
		"window_x": int(event_position.x),
		"window_y": int(event_position.y),
		"screen_x": int(event_position.x),
		"screen_y": int(event_position.y),
		"target_path": String(target_node.get_path()) if target_node != null and target_node.is_inside_tree() else "",
		"control_type": target_node.get_class() if target_node != null else "",
		"display_text": _extract_display_text(target_node),
		"tooltip_text": _extract_tooltip_text(target_node),
		"menu_path": _resolve_menu_path(target_node),
		"scene_file_path": _resolve_scene_file_path(target_node),
		"surface_id": _resolve_surface_id(target_context, layer_record, target_node),
		"target": target_context,
		"layer": layer_record,
		"payload": payload.duplicate(true),
		"providers": providers,
	}
	_apply_provider_context(context, providers)
	context_captured.emit(context)
	return context

func show_callout(target: Variant, payload: Dictionary = {}, mode := "player") -> Dictionary:
	if not _allows_player_callouts() and mode == "player":
		return {"ok": false, "error": "Player callouts are disabled."}
	var context := capture_context(target, null, payload)
	_ensure_overlay()
	return _overlay.show_callout(context, payload, mode)

func begin_dev_capture(event_or_position: Variant = null, initial_text := "") -> Dictionary:
	return begin_dev_capture_request({"event": event_or_position, "initial_text": initial_text})

func begin_dev_capture_request(request: Dictionary = {}) -> Dictionary:
	if not _allows_developer_capture():
		return {"ok": false, "error": "Developer capture is disabled."}
	_ensure_overlay()
	if _overlay.is_capture_popup_visible():
		return {"ok": false, "error": "Capture popup is already visible."}
	_configure_session_store()
	if _requires_explicit_dev_vault() and not _has_explicit_dev_vault():
		_dev_capture_armed = false
		return {"ok": false, "error": "Choose a feedback dev vault before capturing feedback."}
	var event: Variant = request.get("event", request.get("position", null))
	var target: Variant = request.get("target", null)
	var payload := Dictionary(request.get("payload", {})).duplicate(true)
	var context := capture_context(target, event, payload)
	context["event_id"] = "DevCapture.Opened"
	var screenshot := stage_viewport_screenshot()
	if bool(screenshot.get("ok", false)):
		context["screenshot_source_path"] = String(screenshot.get("path", ""))
	elif not bool(screenshot.get("skipped", false)):
		context["screenshot_failure_message"] = String(screenshot.get("failure_message", screenshot.get("error", "")))
	var evidence := collect_evidence(context)
	context["evidence"] = evidence.duplicate(true)
	_last_context = context.duplicate(true)
	_last_capture_request = _build_capture_request(context, screenshot, evidence)
	var anchor := _event_position(event)
	var popup_result := _overlay.show_capture_popup(context, anchor, String(request.get("initial_text", "")))
	emit_event("DevCapture.Opened", target, payload, {"event": event, "allow_programmatic": true})
	return {"ok": bool(popup_result.get("ok", false)), "context": context, "request": _last_capture_request.duplicate(true)}

func save_dev_feedback(feedback_text: String, attachment_paths: PackedStringArray = PackedStringArray()) -> Dictionary:
	return save_dev_feedback_request({"feedback_text": feedback_text, "attachment_paths": attachment_paths})

func save_dev_feedback_request(request: Dictionary = {}) -> Dictionary:
	_configure_session_store()
	var merged := _last_capture_request.duplicate(true)
	for key in request.keys():
		merged[key] = request[key]
	if not merged.has("context"):
		merged["context"] = _last_context.duplicate(true)
	elif typeof(merged.get("context")) == TYPE_DICTIONARY:
		merged["context"] = Dictionary(merged.get("context", {})).duplicate(true)
	var combined_paths := PackedStringArray()
	for source in [_last_capture_request.get("attachment_paths", PackedStringArray()), request.get("attachment_paths", PackedStringArray())]:
		for raw_path in source:
			var path := String(raw_path).strip_edges()
			if not path.is_empty() and not combined_paths.has(path):
				combined_paths.append(path)
	merged["attachment_paths"] = combined_paths
	var result := _session_store.save_feedback(merged)
	dev_feedback_saved.emit(result)
	return result

func ensure_dev_session() -> Dictionary:
	_configure_session_store()
	return _session_store.ensure_session()

func export_session_prompt() -> Dictionary:
	_configure_session_store()
	return _session_store.export_session_prompt()

func get_session_snapshot() -> Dictionary:
	_configure_session_store()
	return _session_store.get_session_snapshot()

func get_session_entries() -> Array:
	_configure_session_store()
	return _session_store.get_entries()

func set_dev_capture_armed(armed: bool) -> void:
	_dev_capture_armed = armed

func is_dev_capture_armed() -> bool:
	return _dev_capture_armed

func pulse(control: Control, scale_amount: float = 0.08, duration: float = 0.18) -> Dictionary:
	if control == null or not is_instance_valid(control):
		return {"ok": false, "error": "Control is null."}
	_play_pulse(control, scale_amount, duration)
	return {"ok": true, "effect": "Pulse", "duration": duration, "protected_time": 0.0}

func shake_control(control: Control, amplitude: float = 5.0, duration: float = 0.22) -> Dictionary:
	if control == null or not is_instance_valid(control):
		return {"ok": false, "error": "Control is null."}
	_play_shake(control, amplitude, duration)
	return {"ok": true, "effect": "Shake", "duration": duration, "protected_time": 0.0}

func flash_control(control: Control, duration: float = 0.22, color: Color = Color(1.0, 1.0, 1.0, 0.92)) -> Dictionary:
	if control == null or not is_instance_valid(control):
		return {"ok": false, "error": "Control is null."}
	_play_flash(control, color, duration)
	return {"ok": true, "effect": "Flash", "duration": duration, "protected_time": duration}

func wire_button(control: Control, hover_event_id := "Ui.Hover", press_event_id := "Ui.Select", options: Dictionary = {}) -> Dictionary:
	if control == null:
		return {"ok": false, "error": "Control is null."}
	var key := "sea_shell_feedback_wired"
	if control.has_meta(key):
		return {"ok": true, "already_wired": true}
	control.set_meta(key, true)
	if not hover_event_id.is_empty():
		control.mouse_entered.connect(func() -> void:
			emit_event(hover_event_id, control, {}, options)
		)
		control.focus_entered.connect(func() -> void:
			emit_event(hover_event_id, control, {}, options)
		)
	if not press_event_id.is_empty():
		if control is BaseButton:
			(control as BaseButton).pressed.connect(func() -> void:
				emit_event(press_event_id, control, {}, options)
			)
		else:
			control.gui_input.connect(func(input_event: InputEvent) -> void:
				if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
					emit_event(press_event_id, control, {}, options)
			)
	return {"ok": true}

func apply_input_passthrough(root_control: Control, include_root := false) -> int:
	if root_control == null:
		return 0
	var changed := 0
	if include_root:
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		changed += 1
	for child in root_control.get_children():
		if child is Control:
			changed += apply_input_passthrough(child as Control, true)
	return changed

func stage_viewport_screenshot() -> Dictionary:
	if not bool(_settings_value("SeaShell.Feedback.AutoScreenshotEnabled", true)):
		return {"ok": false, "skipped": true, "reason": "Auto screenshot disabled."}
	if DisplayServer.get_name().to_lower() == "headless":
		return {"ok": false, "failure_message": "Viewport screenshot capture is unavailable in headless mode."}
	var viewport := get_viewport()
	if viewport == null:
		return {"ok": false, "failure_message": "No viewport is available for screenshot capture."}
	var texture := viewport.get_texture()
	if texture == null:
		return {"ok": false, "failure_message": "The viewport texture is unavailable."}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"ok": false, "failure_message": "The viewport image is empty."}
	var capture_root := ProjectSettings.globalize_path("user://sea_shell_feedback_capture_tmp")
	DirAccess.make_dir_recursive_absolute(capture_root)
	var path := capture_root.path_join("feedback-capture-%s.png" % Time.get_ticks_msec())
	var error := image.save_png(path)
	if error != OK:
		return {"ok": false, "failure_message": "Could not save screenshot: %s." % error_string(error), "path": path}
	return {"ok": true, "path": path}

func collect_evidence(context: Dictionary = {}) -> Dictionary:
	var result := {
		"attachment_paths": PackedStringArray(),
		"recording_source_path": "",
		"file_attachment_source_path": "",
	}
	var tree := get_tree()
	if tree == null:
		return result
	for provider in tree.get_nodes_in_group(EVIDENCE_PROVIDER_GROUP):
		if provider == null:
			continue
		var provider_result: Variant = null
		for method_name in ["sea_shell_capture_feedback_evidence", "sea_shell_get_feedback_evidence", "sea_shell_get_latest_feedback_evidence"]:
			if provider.has_method(method_name):
				provider_result = provider.call(method_name, context)
				break
		if typeof(provider_result) != TYPE_DICTIONARY:
			continue
		var evidence := provider_result as Dictionary
		if String(result.get("recording_source_path", "")).is_empty() and not String(evidence.get("recording_source_path", "")).strip_edges().is_empty():
			result["recording_source_path"] = String(evidence.get("recording_source_path", ""))
		if String(result.get("file_attachment_source_path", "")).is_empty() and not String(evidence.get("file_attachment_source_path", "")).strip_edges().is_empty():
			result["file_attachment_source_path"] = String(evidence.get("file_attachment_source_path", ""))
		if evidence.has("attachment_paths"):
			var paths: PackedStringArray = result.get("attachment_paths", PackedStringArray())
			for raw_path in evidence.get("attachment_paths", []):
				var path := String(raw_path).strip_edges()
				if not path.is_empty() and not paths.has(path):
					paths.append(path)
			result["attachment_paths"] = paths
	return result

func _input(event: InputEvent) -> void:
	if not _allows_developer_capture():
		return
	if _overlay != null and _overlay.is_capture_popup_visible():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		var quick_capture := mouse_event.ctrl_pressed and mouse_event.shift_pressed
		if not quick_capture and not _dev_capture_armed:
			return
		get_viewport().set_input_as_handled()
		begin_dev_capture(mouse_event)

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

func _configure_session_store() -> void:
	if _session_store == null:
		_session_store = SessionStoreScript.new()
	_session_store.configure(
		String(_settings_value("SeaShell.Feedback.DevVaultRoot", DEFAULT_DEV_VAULT_ROOT)),
		String(_settings_value("SeaShell.Feedback.SessionFolder", "Devlog/Sessions")),
		String(_settings_value("SeaShell.Feedback.AttachmentFolder", "Devlog/Attachments")),
		{
			"require_explicit_dev_vault": _requires_explicit_dev_vault(),
			"default_dev_vault_root": DEFAULT_DEV_VAULT_ROOT,
			"frontmatter_prefix": String(_settings_value("SeaShell.Feedback.FrontmatterPrefix", "SS")),
			"note_kind": String(_settings_value("SeaShell.Feedback.NoteKind", "feedback-session")),
		}
	)

func _settings_value(item_id: String, fallback: Variant) -> Variant:
	var settings := _resolve_settings()
	if settings != null and settings.has_method("get_item") and settings.call("get_item", item_id) != null and settings.has_method("get_value"):
		var value: Variant = settings.call("get_value", item_id)
		return fallback if value == null else value
	return fallback

func _is_feedback_enabled() -> bool:
	return bool(_settings_value("SeaShell.Feedback.Enabled", true)) and String(_settings_value("SeaShell.Feedback.Mode", "Both")) != "Off"

func _allows_player_callouts() -> bool:
	var mode := String(_settings_value("SeaShell.Feedback.Mode", "Both"))
	return _is_feedback_enabled() and ["PlayerCallouts", "Both"].has(mode)

func _allows_developer_capture() -> bool:
	var mode := String(_settings_value("SeaShell.Feedback.Mode", "Both"))
	return _is_feedback_enabled() and ["DeveloperCapture", "Both"].has(mode)

func _requires_explicit_dev_vault() -> bool:
	return bool(_settings_value("SeaShell.Feedback.RequireExplicitDevVault", false))

func _has_explicit_dev_vault() -> bool:
	var root := String(_settings_value("SeaShell.Feedback.DevVaultRoot", DEFAULT_DEV_VAULT_ROOT)).strip_edges()
	return not root.is_empty() and root != DEFAULT_DEV_VAULT_ROOT

func _register_default_cues() -> void:
	_register_default_cue("SeaShell.Ui.Hover", PackedStringArray(["Ui.Hover"]), [920.0], [0.028], 0.10, 0.94, 1.01, "None", 0.08)
	_register_default_cue("SeaShell.Ui.OptionHover", PackedStringArray(["Ui.OptionHover"]), [920.0], [0.028], 0.10, 1.12, 1.22, "None", 0.08)
	_register_default_cue("SeaShell.Ui.Select", PackedStringArray(["Ui.Select"]), [620.0, 860.0], [0.038, 0.045], 0.14, 0.96, 1.03, "Pulse", 0.18)
	_register_default_cue("SeaShell.Ui.NavigationNext", PackedStringArray(["Ui.Navigation.Next"]), [620.0, 860.0], [0.038, 0.045], 0.14, 0.82, 0.89, "Pulse", 0.16)
	_register_default_cue("SeaShell.Ui.NavigationPrevious", PackedStringArray(["Ui.Navigation.Previous"]), [620.0, 860.0], [0.038, 0.045], 0.14, 0.68, 0.76, "Pulse", 0.16)
	_register_default_cue("SeaShell.Ui.Export", PackedStringArray(["Ui.Export", "Ui.Save.Success", "Ui.Copy.Success"]), [560.0, 760.0, 1040.0], [0.04, 0.05, 0.07], 0.18, 0.985, 1.025, "Pulse", 0.18)
	_register_default_cue("SeaShell.Ui.MenuOpen", PackedStringArray(["Ui.Menu.Open"]), [180.0, 240.0], [0.06, 0.08], 0.18, 0.99, 1.04, "None", 0.14)
	_register_default_cue("SeaShell.Ui.MenuClose", PackedStringArray(["Ui.Menu.Close"]), [240.0, 170.0], [0.05, 0.09], 0.18, 0.92, 0.98, "None", 0.14)
	_register_default_cue("SeaShell.Survey.AnswerSelect", PackedStringArray(["Survey.Answer.Select"]), [760.0, 1040.0], [0.03, 0.05], 0.15, 0.97, 1.05, "Pulse", 0.18)
	_register_default_cue("SeaShell.Survey.AnswerCharge", PackedStringArray(["Survey.Answer.Charge"]), [300.0, 520.0, 760.0], [0.02, 0.03, 0.05], 0.16, 0.88, 1.18, "Pulse", 0.14)
	_register_default_cue("SeaShell.Survey.AnswerUnselect", PackedStringArray(["Survey.Answer.Unselect"]), [340.0, 240.0], [0.035, 0.055], 0.14, 0.92, 0.98, "Shake", 0.18)
	_register_default_cue("SeaShell.Survey.XpGain", PackedStringArray(["Survey.XpGain"]), [420.0, 560.0, 760.0], [0.03, 0.035, 0.045], 0.15, 0.96, 1.33, "Pulse", 0.16)
	_register_default_cue("SeaShell.Survey.Unlock", PackedStringArray(["Survey.Unlock"]), [520.0, 760.0, 1040.0], [0.045, 0.055, 0.085], 0.18, 0.98, 1.04, "Pulse", 0.22)
	_register_default_cue("SeaShell.Survey.AttackLaunch", PackedStringArray(["Survey.Attack.Launch"]), [220.0, 320.0, 520.0], [0.025, 0.03, 0.06], 0.18, 0.92, 1.08, "Shake", 0.18)
	_register_default_cue("SeaShell.Survey.BossHit", PackedStringArray(["Survey.Boss.Hit"]), [160.0, 120.0, 90.0], [0.03, 0.04, 0.06], 0.22, 0.92, 1.06, "Shake", 0.20)
	_register_default_cue("SeaShell.Survey.BossGlancing", PackedStringArray(["Survey.Boss.Glancing"]), [540.0, 680.0], [0.018, 0.022], 0.10, 0.98, 1.08, "None", 0.10)
	_register_default_cue("SeaShell.Survey.BossSectionBreak", PackedStringArray(["Survey.Boss.SectionBreak"]), [260.0, 180.0, 120.0], [0.04, 0.05, 0.08], 0.20, 0.96, 1.02, "Shake", 0.24)
	_register_default_cue("SeaShell.Survey.BossVictory", PackedStringArray(["Survey.Boss.Victory"]), [360.0, 520.0, 720.0, 980.0], [0.04, 0.045, 0.055, 0.08], 0.20, 0.98, 1.02, "Pulse", 0.28)
	_register_default_cue("SeaShell.Survey.BossPartialResult", PackedStringArray(["Survey.Boss.PartialResult"]), [240.0, 320.0, 420.0], [0.03, 0.04, 0.06], 0.13, 0.94, 1.08, "Pulse", 0.16)
	_register_default_cue("SeaShell.Survey.GambleSpinTick", PackedStringArray(["Survey.Gamble.SpinTick"]), [1120.0], [0.024], 0.11, 0.92, 1.28, "None", 0.08)
	_register_default_cue("SeaShell.Inventory.ItemUseSuccess", PackedStringArray(["Inventory.ItemUse.Success"]), [740.0, 988.0], [0.05, 0.08], 0.14, 0.98, 1.04, "Flash", 0.22)
	_register_default_cue("SeaShell.DevCapture.Opened", PackedStringArray(["DevCapture.Opened"]), [440.0, 660.0], [0.035, 0.05], 0.1, 0.98, 1.02, "None", 0.12)

func _register_default_cue(cue_id: String, event_ids: PackedStringArray, frequencies: Array, durations: Array, amplitude: float, pitch_min: float, pitch_max: float, visual: String, duration: float) -> void:
	var cue = CueScript.new()
	cue.CueId = cue_id
	cue.EventIds = event_ids
	cue.AudioFrequencies = PackedFloat32Array(frequencies)
	cue.AudioDurations = PackedFloat32Array(durations)
	cue.AudioAmplitude = amplitude
	cue.PitchMin = pitch_min
	cue.PitchMax = pitch_max
	cue.VisualEffect = visual
	cue.Duration = duration
	cue.ProtectedTime = duration if visual == "Flash" else 0.0
	register_cue(cue)

func _play_audio_cue(cue: Resource, payload: Dictionary, options: Dictionary) -> Dictionary:
	var event_ids: PackedStringArray = cue.get("EventIds")
	if _event_ids_are_hover(event_ids) and not bool(_settings_value("SeaShell.Feedback.HoverSfxEnabled", false)):
		return {"ok": false, "skipped": true, "reason": "Hover SFX disabled."}
	var spec := _resolve_audio_spec(cue, payload)
	var frequencies: PackedFloat32Array = spec.get("frequencies", PackedFloat32Array())
	var durations: PackedFloat32Array = spec.get("durations", PackedFloat32Array())
	if frequencies.is_empty() or durations.is_empty():
		return {"ok": false, "skipped": true, "reason": "Cue has no audio."}
	var cue_id := str(cue.get("CueId"))
	var player: AudioStreamPlayer = _audio_players.get(cue_id)
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = _safe_node_name("%sAudio" % cue_id)
		add_child(player)
		_audio_players[cue_id] = player
	player.bus = StringName(String(_settings_value("SeaShell.Feedback.AudioBus", "Master")))
	player.stop()
	player.stream = _get_or_build_tone_stream(frequencies, durations, float(spec.get("amplitude", cue.get("AudioAmplitude"))), spec.get("waveforms", PackedStringArray()), spec.get("amplitudes", PackedFloat32Array()))
	var volume_multiplier := float(cue.get("VolumeMultiplier")) * float(payload.get("volume_multiplier", options.get("volume_multiplier", 1.0)))
	var sfx_volume := clampf(float(_settings_value("SeaShell.Feedback.SfxVolume", 0.35)) * volume_multiplier, 0.0, 1.0)
	player.volume_db = SILENT_DB if sfx_volume <= MIN_AUDIBLE_VOLUME else linear_to_db(sfx_volume)
	var min_pitch := float(options.get("pitch_min", payload.get("pitch_min", cue.get("PitchMin"))))
	var max_pitch := float(options.get("pitch_max", payload.get("pitch_max", cue.get("PitchMax"))))
	player.pitch_scale = _rng.randf_range(min_pitch, max_pitch) if not is_equal_approx(min_pitch, max_pitch) else min_pitch
	player.play()
	return {"ok": true, "playing": player.playing, "player": String(player.get_path()), "pitch_scale": player.pitch_scale, "volume_db": player.volume_db, "profile": spec.get("profile", "")}

func _play_visual_cue(cue: Resource, target: Node, _payload: Dictionary, options: Dictionary) -> Dictionary:
	if not bool(_settings_value("SeaShell.Feedback.VisualEffectsEnabled", true)):
		return {"ok": false, "skipped": true, "reason": "Visual effects disabled."}
	if target == null or not (target is Control):
		return {"ok": false, "skipped": true, "reason": "Target is not a Control."}
	var control := target as Control
	var duration := float(options.get("duration", cue.get("Duration")))
	match str(cue.get("VisualEffect")):
		"Pulse":
			_play_pulse(control, float(cue.get("ScaleAmount")), duration)
			return {"ok": true, "effect": "Pulse"}
		"Shake":
			_play_shake(control, float(cue.get("ShakeAmplitude")), duration)
			return {"ok": true, "effect": "Shake"}
		"Flash":
			_play_flash(control, cue.get("FlashColor"), duration)
			return {"ok": true, "effect": "Flash"}
		_:
			return {"ok": false, "skipped": true, "reason": "No visual effect."}

func _play_pulse(control: Control, scale_amount: float, duration: float) -> void:
	_restore_pulse_effect(control)
	var base_scale := control.scale
	var token := _next_effect_token()
	control.set_meta(PULSE_BASE_SCALE_META, base_scale)
	control.set_meta(PULSE_TOKEN_META, token)
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	control.set_meta(PULSE_TWEEN_META, tween)
	_track_visual_effect_owner(control)
	tween.tween_property(control, "scale", base_scale * (1.0 + scale_amount), duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base_scale, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control) and control.has_meta(PULSE_TOKEN_META) and int(control.get_meta(PULSE_TOKEN_META)) == token:
			control.scale = base_scale
			control.remove_meta(PULSE_TWEEN_META)
			control.remove_meta(PULSE_TOKEN_META)
			control.remove_meta(PULSE_BASE_SCALE_META)
	)

func _play_shake(control: Control, amplitude: float, duration: float) -> void:
	_restore_shake_effect(control)
	var origin := control.position
	var token := _next_effect_token()
	control.set_meta(SHAKE_BASE_POSITION_META, origin)
	control.set_meta(SHAKE_TOKEN_META, token)
	var tween := control.create_tween()
	control.set_meta(SHAKE_TWEEN_META, tween)
	_track_visual_effect_owner(control)
	tween.tween_property(control, "position", origin + Vector2(amplitude, 0.0), duration * 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", origin + Vector2(-amplitude * 0.8, 0.0), duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position", origin + Vector2(amplitude * 0.45, 0.0), duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position", origin, duration * 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control) and control.has_meta(SHAKE_TOKEN_META) and int(control.get_meta(SHAKE_TOKEN_META)) == token:
			control.position = origin
			control.remove_meta(SHAKE_TWEEN_META)
			control.remove_meta(SHAKE_TOKEN_META)
			control.remove_meta(SHAKE_BASE_POSITION_META)
	)

func _play_flash(control: Control, color: Color, duration: float) -> void:
	var overlay := control.get_node_or_null("FlashOverlay") as ColorRect
	if overlay == null:
		overlay = control.get_node_or_null("SeaShellFeedbackFlash") as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "SeaShellFeedbackFlash"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		overlay.color = Color(color.r, color.g, color.b, 0.0)
		control.add_child(overlay)
		control.move_child(overlay, control.get_child_count() - 1)
	_restore_flash_effect(overlay)
	var base_visible := overlay.visible
	var base_color := overlay.color
	var token := _next_effect_token()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = true
	overlay.color = Color(color.r, color.g, color.b, 0.0)
	var tween := overlay.create_tween()
	overlay.set_meta(FLASH_TWEEN_META, tween)
	overlay.set_meta(FLASH_TOKEN_META, token)
	overlay.set_meta(FLASH_BASE_VISIBLE_META, base_visible)
	overlay.set_meta(FLASH_BASE_COLOR_META, base_color)
	_track_visual_effect_owner(overlay)
	tween.tween_property(overlay, "color", color, duration * 0.35)
	tween.tween_property(overlay, "color", Color(color.r, color.g, color.b, 0.0), duration * 0.65)
	tween.finished.connect(func() -> void:
		if is_instance_valid(overlay) and overlay.has_meta(FLASH_TOKEN_META) and int(overlay.get_meta(FLASH_TOKEN_META)) == token:
			overlay.visible = base_visible
			overlay.color = base_color
			overlay.remove_meta(FLASH_TWEEN_META)
			overlay.remove_meta(FLASH_TOKEN_META)
			overlay.remove_meta(FLASH_BASE_VISIBLE_META)
			overlay.remove_meta(FLASH_BASE_COLOR_META)
	)

func _resolve_audio_spec(cue: Resource, payload: Dictionary) -> Dictionary:
	if str(cue.get("CueId")) == "SeaShell.Inventory.ItemUseSuccess":
		return _inventory_item_use_audio_spec(String(payload.get("sfx_profile", "generic")))
	return {
		"frequencies": cue.get("AudioFrequencies"),
		"durations": cue.get("AudioDurations"),
		"amplitude": float(cue.get("AudioAmplitude")),
		"waveforms": cue.get("AudioWaveforms") if cue.get("AudioWaveforms") != null else PackedStringArray(),
		"amplitudes": PackedFloat32Array(),
	}

func _inventory_item_use_audio_spec(profile: String) -> Dictionary:
	var normalized := profile.strip_edges().to_lower()
	var notes := []
	match normalized:
		"recovery":
			notes = [[660.0, 0.05, "triangle", 0.70], [880.0, 0.07, "triangle", 0.78], [1174.0, 0.08, "triangle", 0.82]]
		"status":
			notes = [[784.0, 0.05, "sine", 0.68], [988.0, 0.08, "sine", 0.76]]
		"pp":
			notes = [[622.0, 0.04, "square", 0.58], [740.0, 0.04, "square", 0.62], [932.0, 0.07, "triangle", 0.76]]
		"boost":
			notes = [[698.0, 0.05, "triangle", 0.66], [1047.0, 0.06, "triangle", 0.78], [1397.0, 0.08, "triangle", 0.84]]
		"special":
			notes = [[523.0, 0.04, "sine", 0.58], [784.0, 0.05, "triangle", 0.70], [1174.0, 0.10, "triangle", 0.84]]
		_:
			normalized = "generic"
			notes = [[740.0, 0.05, "triangle", 0.66], [988.0, 0.08, "triangle", 0.74]]
	var frequencies := PackedFloat32Array()
	var durations := PackedFloat32Array()
	var waveforms := PackedStringArray()
	var amplitudes := PackedFloat32Array()
	for note in notes:
		frequencies.append(float(note[0]))
		durations.append(float(note[1]))
		waveforms.append(String(note[2]))
		amplitudes.append(float(note[3]))
	return {"profile": normalized, "frequencies": frequencies, "durations": durations, "waveforms": waveforms, "amplitudes": amplitudes, "amplitude": 0.16}

func _get_or_build_tone_stream(frequencies: PackedFloat32Array, durations: PackedFloat32Array, amplitude: float, waveforms: PackedStringArray = PackedStringArray(), amplitudes: PackedFloat32Array = PackedFloat32Array()) -> AudioStreamWAV:
	var cache_key := _tone_stream_cache_key(frequencies, durations, amplitude, waveforms, amplitudes)
	var cached: Variant = _audio_stream_cache.get(cache_key)
	if cached is AudioStreamWAV:
		return cached
	var stream := _build_tone_stream(frequencies, durations, amplitude, waveforms, amplitudes)
	_audio_stream_cache[cache_key] = stream
	return stream

func _build_tone_stream(frequencies: PackedFloat32Array, durations: PackedFloat32Array, amplitude: float, waveforms: PackedStringArray = PackedStringArray(), amplitudes: PackedFloat32Array = PackedFloat32Array()) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	for index in range(mini(frequencies.size(), durations.size())):
		var waveform := String(waveforms[index]) if index < waveforms.size() else "sine"
		var segment_amplitude := amplitude * float(amplitudes[index]) if index < amplitudes.size() else amplitude
		_append_tone(pcm, frequencies[index], durations[index], segment_amplitude, waveform)
		_append_silence(pcm, 0.01)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = AUDIO_MIX_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.data = pcm
	return stream

func _tone_stream_cache_key(frequencies: PackedFloat32Array, durations: PackedFloat32Array, amplitude: float, waveforms: PackedStringArray, amplitudes: PackedFloat32Array) -> String:
	var parts := PackedStringArray(["%.6f" % amplitude])
	for index in range(mini(frequencies.size(), durations.size())):
		var waveform := String(waveforms[index]) if index < waveforms.size() else "sine"
		var segment_amplitude := float(amplitudes[index]) if index < amplitudes.size() else 1.0
		parts.append("%.3f:%.6f:%s:%.6f" % [frequencies[index], durations[index], waveform, segment_amplitude])
	return "|".join(parts)

func _kill_meta_tween(owner: Object, tween_meta: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if not owner.has_meta(tween_meta):
		return
	var existing: Variant = owner.get_meta(tween_meta)
	if existing is Tween and is_instance_valid(existing):
		(existing as Tween).kill()
	owner.remove_meta(tween_meta)

func _restore_pulse_effect(control: Control) -> void:
	_kill_meta_tween(control, PULSE_TWEEN_META)
	if control.has_meta(PULSE_BASE_SCALE_META):
		control.scale = control.get_meta(PULSE_BASE_SCALE_META)
		control.remove_meta(PULSE_BASE_SCALE_META)
	if control.has_meta(PULSE_TOKEN_META):
		control.remove_meta(PULSE_TOKEN_META)

func _restore_shake_effect(control: Control) -> void:
	_kill_meta_tween(control, SHAKE_TWEEN_META)
	if control.has_meta(SHAKE_BASE_POSITION_META):
		control.position = control.get_meta(SHAKE_BASE_POSITION_META)
		control.remove_meta(SHAKE_BASE_POSITION_META)
	if control.has_meta(SHAKE_TOKEN_META):
		control.remove_meta(SHAKE_TOKEN_META)

func _restore_flash_effect(overlay: ColorRect) -> void:
	_kill_meta_tween(overlay, FLASH_TWEEN_META)
	if overlay.has_meta(FLASH_BASE_VISIBLE_META):
		overlay.visible = bool(overlay.get_meta(FLASH_BASE_VISIBLE_META))
		overlay.remove_meta(FLASH_BASE_VISIBLE_META)
	if overlay.has_meta(FLASH_BASE_COLOR_META):
		overlay.color = overlay.get_meta(FLASH_BASE_COLOR_META)
		overlay.remove_meta(FLASH_BASE_COLOR_META)
	if overlay.has_meta(FLASH_TOKEN_META):
		overlay.remove_meta(FLASH_TOKEN_META)

func _stop_all_visual_effects() -> void:
	for owner in _visual_effect_owners:
		if owner == null or not is_instance_valid(owner):
			continue
		if owner is Control:
			_restore_pulse_effect(owner as Control)
			_restore_shake_effect(owner as Control)
		if owner is ColorRect:
			_restore_flash_effect(owner as ColorRect)
	_visual_effect_owners.clear()

func _track_visual_effect_owner(owner: Object) -> void:
	if owner != null and is_instance_valid(owner) and not _visual_effect_owners.has(owner):
		_visual_effect_owners.append(owner)

func _next_effect_token() -> int:
	_effect_token += 1
	return _effect_token

func _append_tone(pcm: PackedByteArray, frequency: float, duration: float, amplitude: float, waveform := "sine") -> void:
	var sample_count := int(AUDIO_MIX_RATE * duration)
	for sample_index in range(sample_count):
		var t := float(sample_index) / float(AUDIO_MIX_RATE)
		var envelope := 1.0
		if sample_count > 1:
			var edge := minf(t / duration, (duration - t) / duration) * 4.0
			envelope = clampf(edge, 0.0, 1.0)
		var phase := frequency * t
		var wave_value := sin(TAU * phase)
		match waveform.to_lower():
			"square":
				wave_value = 1.0 if sin(TAU * phase) >= 0.0 else -1.0
			"triangle":
				wave_value = 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
		var sample_value := wave_value * amplitude * envelope
		_append_sample(pcm, sample_value)

func _append_silence(pcm: PackedByteArray, duration: float) -> void:
	for _i in range(int(AUDIO_MIX_RATE * duration)):
		_append_sample(pcm, 0.0)

func _append_sample(pcm: PackedByteArray, sample_value: float) -> void:
	var clamped := clampf(sample_value, -1.0, 1.0)
	var sample_int := int(round(clamped * 32767.0))
	if sample_int < 0:
		sample_int += 65536
	pcm.append(sample_int & 255)
	pcm.append((sample_int >> 8) & 255)

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = OverlayScript.new()
	_overlay.name = "SeaShellFeedbackOverlay"
	add_child(_overlay)
	_overlay.dev_feedback_saved.connect(func(request: Dictionary) -> void:
		save_dev_feedback_request(request)
	)

func _resolve_target_node(target: Variant) -> Node:
	if target is Node and is_instance_valid(target):
		return target
	if target is NodePath:
		return get_node_or_null(target)
	if typeof(target) == TYPE_STRING and not String(target).strip_edges().is_empty():
		return get_node_or_null(String(target))
	return null

func _resolve_hovered_control() -> Control:
	var viewport := get_viewport()
	if viewport != null and viewport.has_method("gui_get_hovered_control"):
		return viewport.gui_get_hovered_control()
	return null

func _event_position(event: Variant) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if typeof(event) == TYPE_VECTOR2:
		return event
	if typeof(event) == TYPE_DICTIONARY:
		var dictionary := event as Dictionary
		if dictionary.has("position") and typeof(dictionary.get("position")) == TYPE_VECTOR2:
			return dictionary.get("position")
		if dictionary.has("window_position") and typeof(dictionary.get("window_position")) == TYPE_VECTOR2:
			return dictionary.get("window_position")
		return Vector2(float(dictionary.get("window_x", 0.0)), float(dictionary.get("window_y", 0.0)))
	return Vector2.ZERO

func _find_target_tag(node: Node) -> Node:
	var cursor := node
	while cursor != null:
		for child in cursor.get_children():
			if child is Node and (child as Node).is_in_group(TARGET_GROUP):
				return child
		if cursor.is_in_group(TARGET_GROUP):
			return cursor
		cursor = cursor.get_parent()
	return null

func _resolve_layer_record(target: Node) -> Dictionary:
	var layers_service := get_node_or_null("/root/SeaShellUiLayers")
	if layers_service == null or not layers_service.has_method("get_layers"):
		return {}
	var layers: Array = layers_service.call("get_layers", true)
	for record in layers:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var root: Variant = (record as Dictionary).get("root")
		if root is Node and _is_ancestor_or_same(root, target):
			var copy := (record as Dictionary).duplicate(true)
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

func _resolve_surface_id(target_context: Dictionary, layer_record: Dictionary, target: Node) -> String:
	var tagged_surface := String(target_context.get("surface_id", "")).strip_edges()
	if not tagged_surface.is_empty():
		return tagged_surface
	var layer_name := String(layer_record.get("name", "")).strip_edges()
	if not layer_name.is_empty():
		return layer_name
	if target != null:
		return String(target.name)
	return ""

func _resolve_scene_file_path(node: Node) -> String:
	var cursor := node
	while cursor != null:
		var scene_path := String(cursor.scene_file_path).strip_edges()
		if not scene_path.is_empty():
			return scene_path
		cursor = cursor.get_parent()
	return ""

func _extract_display_text(node: Node) -> String:
	if node == null:
		return ""
	for property_name in ["text", "placeholder_text", "title"]:
		var value: Variant = node.get(property_name)
		if value != null and not String(value).strip_edges().is_empty():
			return String(value).strip_edges()
	return String(node.name)

func _extract_tooltip_text(node: Node) -> String:
	if node is Control:
		return String((node as Control).tooltip_text)
	return ""

func _resolve_menu_path(node: Node) -> String:
	var parts := []
	var cursor := node
	while cursor != null:
		if cursor is Popup or cursor is PopupPanel or cursor is MenuButton or cursor is BaseButton or String(cursor.name).contains("Menu"):
			parts.push_front(String(cursor.name))
		cursor = cursor.get_parent()
	return " > ".join(PackedStringArray(parts))

func _capture_provider_context(target: Node, event: Variant, payload: Dictionary) -> Array:
	var result := []
	var tree := get_tree()
	if tree == null:
		return result
	for provider in tree.get_nodes_in_group(PROVIDER_GROUP):
		if provider != null and provider.has_method("sea_shell_capture_feedback_context"):
			var provider_context: Variant = provider.call("sea_shell_capture_feedback_context", target, event, payload)
			if typeof(provider_context) == TYPE_DICTIONARY:
				result.append({"provider": String(provider.name), "context": provider_context})
	return result

func _apply_provider_context(context: Dictionary, providers: Array) -> void:
	for record in providers:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var provider_context: Dictionary = Dictionary(record).get("context", {})
		for key in ["top_level_tab", "current_note_path", "dashboard_vault_id", "dashboard_vault_name", "dashboard_vault_root", "latest_session_status", "is_obs_recording", "navigation_target", "history_state", "recent_actions"]:
			if provider_context.has(key) and not context.has(key):
				context[key] = provider_context.get(key)

func _record_recent_event(event_id: String, context: Dictionary) -> void:
	_recent_events.push_front({"event_id": event_id, "context": context.duplicate(true), "unix": Time.get_unix_time_from_system()})
	while _recent_events.size() > 20:
		_recent_events.pop_back()

func _event_ids_are_hover(event_ids: PackedStringArray) -> bool:
	for event_id in event_ids:
		if String(event_id).to_lower().contains("hover"):
			return true
	return false

func _build_capture_request(context: Dictionary, screenshot: Dictionary, evidence: Dictionary) -> Dictionary:
	return {
		"context": context.duplicate(true),
		"screenshot_source_path": String(screenshot.get("path", "")) if bool(screenshot.get("ok", false)) else "",
		"screenshot_failure_message": String(context.get("screenshot_failure_message", "")),
		"recording_source_path": String(evidence.get("recording_source_path", "")),
		"file_attachment_source_path": String(evidence.get("file_attachment_source_path", "")),
		"attachment_paths": evidence.get("attachment_paths", PackedStringArray()),
	}

func _safe_node_name(raw: String) -> String:
	return raw.replace(".", "_").replace("/", "_").replace(" ", "_")
