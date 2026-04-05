class_name SurveyQuestionModifier
extends RefCounted

signal fatigue_requested(message: String)

var host = null
var question: SurveyQuestion

func attach_to_view(host_view, question_definition: SurveyQuestion) -> void:
	host = host_view
	question = question_definition
	_on_attached()

func detach_from_view() -> void:
	_on_detached()
	host = null
	question = null

func prefers_layout_hint(_hint: StringName) -> bool:
	return false

func intercept_action(_action_name: StringName, _context: Dictionary = {}) -> Dictionary:
	return {}

func on_answer_emitted(_value: Variant) -> void:
	pass

func _on_attached() -> void:
	pass

func _on_detached() -> void:
	pass

func _request_fatigue(message: String) -> void:
	var resolved_message: String = message.strip_edges()
	if resolved_message.is_empty():
		resolved_message = "Question modifiers were paused for now."
	fatigue_requested.emit(resolved_message)
