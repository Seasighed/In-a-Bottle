class_name SurveyQuestionView
extends Control

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal answer_changed(question_id: String, value: Variant)
signal question_selected(question_id: String)

var question: SurveyQuestion
var current_value: Variant
var is_selected := false

func _ready() -> void:
	if question != null:
		_apply_question()
	_refresh_layout_metrics()
	_apply_selection_state()

func configure(new_question: SurveyQuestion, initial_value: Variant = null) -> void:
	question = new_question
	current_value = initial_value if initial_value != null else question.default_value
	if is_node_ready():
		_apply_question()
		_refresh_layout_metrics()
		_apply_selection_state()

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_node_ready():
		_apply_selection_state()

func focus_primary_control() -> void:
	pass

func emit_answer(value: Variant) -> void:
	current_value = value
	answer_changed.emit(question.id, value)

func emit_selected() -> void:
	if question != null:
		question_selected.emit(question.id)

func register_selectable(control: Control) -> void:
	if control == null:
		return
	control.focus_entered.connect(_on_selectable_focus_entered)
	control.gui_input.connect(_on_selectable_gui_input)
	control.mouse_entered.connect(_on_selectable_mouse_entered)

func _refresh_layout_metrics() -> void:
	update_minimum_size()
	var parent_container := get_parent() as Container
	if parent_container != null:
		parent_container.queue_sort()

func _get_minimum_size() -> Vector2:
	var min_size := custom_minimum_size
	for child in get_children():
		var child_control := child as Control
		if child_control != null and child_control.visible:
			min_size = min_size.max(child_control.get_combined_minimum_size())
	return min_size

func _on_selectable_focus_entered() -> void:
	emit_selected()

func _on_selectable_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_selectable_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_option_hover()

func _apply_question() -> void:
	pass

func _apply_selection_state() -> void:
	pass

