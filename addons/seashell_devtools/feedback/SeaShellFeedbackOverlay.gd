@tool
extends CanvasLayer
class_name SeaShellFeedbackOverlay

signal dev_feedback_saved(request: Dictionary)
signal dev_feedback_cancelled
signal callout_closed

@export var canvas_layer_index := 4097

var _root: Control
var _callout_panel: PanelContainer
var _callout_title: Label
var _callout_body: Label
var _capture_panel: PanelContainer
var _feedback_edit: TextEdit
var _context_label: Label
var _current_capture_context := {}

func _ready() -> void:
	layer = canvas_layer_index
	_build_ui()

func show_callout(context: Dictionary, payload: Dictionary = {}, mode := "player") -> Dictionary:
	_ensure_ui()
	var target_context: Dictionary = context.get("target", {})
	if mode == "player" and not bool(target_context.get("expose_to_players", false)):
		return {"ok": false, "error": "Target is not exposed to players."}
	_callout_title.text = _resolve_callout_title(context, payload)
	_callout_body.text = _resolve_callout_body(context, payload)
	_position_panel(_callout_panel, Vector2(context.get("window_x", 24), context.get("window_y", 24)))
	_callout_panel.visible = true
	return {"ok": true}

func hide_callout() -> void:
	if _callout_panel != null:
		_callout_panel.visible = false
	callout_closed.emit()

func is_callout_visible() -> bool:
	return _callout_panel != null and _callout_panel.visible

func show_capture_popup(context: Dictionary, anchor_position: Vector2, initial_text := "") -> Dictionary:
	_ensure_ui()
	_current_capture_context = context.duplicate(true)
	_feedback_edit.text = initial_text
	_context_label.text = _build_context_summary(context)
	_position_panel(_capture_panel, anchor_position)
	_capture_panel.visible = true
	_feedback_edit.grab_focus()
	return {"ok": true}

func is_capture_popup_visible() -> bool:
	return _capture_panel != null and _capture_panel.visible

func commit_capture(feedback_text := "", attachment_paths: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not is_capture_popup_visible():
		return {"ok": false, "error": "Capture popup is not visible."}
	var text := feedback_text if not feedback_text.strip_edges().is_empty() else _feedback_edit.text
	_capture_panel.visible = false
	var request := {
		"feedback_text": text,
		"context": _current_capture_context.duplicate(true),
		"attachment_paths": attachment_paths,
	}
	dev_feedback_saved.emit(request)
	return {"ok": true, "request": request}

func cancel_capture() -> void:
	if _capture_panel != null:
		_capture_panel.visible = false
	dev_feedback_cancelled.emit()

func _ensure_ui() -> void:
	if _root == null or not is_instance_valid(_root):
		_build_ui()

func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_root = Control.new()
	_root.name = "SeaShellFeedbackRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_callout_panel()
	_build_capture_panel()

func _build_callout_panel() -> void:
	_callout_panel = PanelContainer.new()
	_callout_panel.name = "CalloutPanel"
	_callout_panel.visible = false
	_callout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout_panel.custom_minimum_size = Vector2(320, 140)
	_root.add_child(_callout_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_callout_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	_callout_title = Label.new()
	_callout_title.theme_type_variation = "HeaderSmall"
	_callout_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_callout_title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(hide_callout)
	row.add_child(close_button)
	_callout_body = Label.new()
	_callout_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_callout_body)

func _build_capture_panel() -> void:
	_capture_panel = PanelContainer.new()
	_capture_panel.name = "CapturePanel"
	_capture_panel.visible = false
	_capture_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_capture_panel.custom_minimum_size = Vector2(460, 360)
	_root.add_child(_capture_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_capture_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Feedback"
	title.theme_type_variation = "HeaderSmall"
	box.add_child(title)
	_feedback_edit = TextEdit.new()
	_feedback_edit.custom_minimum_size = Vector2(420, 130)
	_feedback_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_feedback_edit)
	_context_label = Label.new()
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.custom_minimum_size.y = 90
	box.add_child(_context_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(func() -> void: commit_capture())
	row.add_child(save_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(cancel_capture)
	row.add_child(cancel_button)

func _position_panel(panel: Control, anchor_position: Vector2) -> void:
	var viewport_size := Vector2.ZERO
	if get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	var resolved := anchor_position + Vector2(16, 16)
	var panel_size := panel.custom_minimum_size
	if viewport_size.x > 0.0:
		resolved.x = clampf(resolved.x, 12.0, maxf(12.0, viewport_size.x - panel_size.x - 12.0))
		resolved.y = clampf(resolved.y, 12.0, maxf(12.0, viewport_size.y - panel_size.y - 12.0))
	panel.position = resolved

func _resolve_callout_title(context: Dictionary, payload: Dictionary) -> String:
	if payload.has("title") and not String(payload.get("title", "")).strip_edges().is_empty():
		return String(payload.get("title", ""))
	var target_context: Dictionary = context.get("target", {})
	if not String(target_context.get("callout_title", "")).strip_edges().is_empty():
		return String(target_context.get("callout_title", ""))
	if not String(target_context.get("display_name", "")).strip_edges().is_empty():
		return String(target_context.get("display_name", ""))
	return "Context"

func _resolve_callout_body(context: Dictionary, payload: Dictionary) -> String:
	if payload.has("body") and not String(payload.get("body", "")).strip_edges().is_empty():
		return String(payload.get("body", ""))
	var target_context: Dictionary = context.get("target", {})
	if not String(target_context.get("callout_body", "")).strip_edges().is_empty():
		return String(target_context.get("callout_body", ""))
	return _build_context_summary(context)

func _build_context_summary(context: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Event: %s" % context.get("event_id", ""))
	lines.append("Target: %s" % context.get("target_path", ""))
	lines.append("Control: %s" % context.get("control_type", ""))
	lines.append("Surface: %s" % context.get("surface_id", ""))
	var text := String(context.get("display_text", "")).strip_edges()
	if not text.is_empty():
		lines.append("Text: %s" % text)
	var tooltip := String(context.get("tooltip_text", "")).strip_edges()
	if not tooltip.is_empty():
		lines.append("Tooltip: %s" % tooltip)
	return "\n".join(lines)