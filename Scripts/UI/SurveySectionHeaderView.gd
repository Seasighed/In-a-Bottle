class_name SurveySectionHeaderView
extends Control

var section: SurveySection
var survey: SurveyDefinition
var answers: Dictionary = {}

func _ready() -> void:
	if section != null:
		_apply_section()
	_refresh_layout_metrics()

func configure_section(new_section: SurveySection, survey_definition: SurveyDefinition, current_answers: Dictionary) -> void:
	section = new_section
	survey = survey_definition
	answers = current_answers
	if is_node_ready():
		_apply_section()
		_refresh_layout_metrics()

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

func _apply_section() -> void:
	pass