@tool
extends Node
class_name SeaShellFeedbackTargetTag

signal target_changed(tag: Node)

const TAG_GROUP := "sea_shell_feedback_target"

@export var TargetId := ""
@export var DisplayName := ""
@export var SurfaceId := ""
@export var Tags := PackedStringArray()
@export var ExposeToPlayers := false
@export_multiline var CalloutTitle := ""
@export_multiline var CalloutBody := ""
@export var TargetPath: NodePath = NodePath("")
@export var Context: Dictionary = {}
@export var FocusMethod := ""

func _enter_tree() -> void:
	add_to_group(TAG_GROUP)

func _exit_tree() -> void:
	remove_from_group(TAG_GROUP)

func get_feedback_target() -> Node:
	if not String(TargetPath).strip_edges().is_empty():
		var explicit := get_node_or_null(TargetPath)
		if explicit != null:
			return explicit
	return get_parent()

func get_display_name() -> String:
	var explicit_name := DisplayName.strip_edges()
	if not explicit_name.is_empty():
		return explicit_name
	var target := get_feedback_target()
	return String(target.name) if target != null else String(name)

func capture_feedback_context() -> Dictionary:
	var target := get_feedback_target()
	return {
		"target_id": TargetId,
		"display_name": get_display_name(),
		"surface_id": SurfaceId,
		"tags": Array(Tags),
		"expose_to_players": ExposeToPlayers,
		"callout_title": CalloutTitle,
		"callout_body": CalloutBody,
		"node_path": String(target.get_path()) if target != null and target.is_inside_tree() else "",
		"scene_file_path": String(target.scene_file_path) if target != null else "",
		"context": Context.duplicate(true),
	}

func focus_target() -> bool:
	var target := get_feedback_target()
	if target == null:
		return false
	if not FocusMethod.strip_edges().is_empty() and target.has_method(FocusMethod):
		target.call(FocusMethod)
		return true
	if target is CanvasItem:
		(target as CanvasItem).show()
		(target as CanvasItem).move_to_front()
	if target is Control:
		var control := target as Control
		if control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
	return true

func notify_target_changed() -> void:
	target_changed.emit(self)