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
	var locked_width := custom_minimum_size.x > 0.0
	for child in get_children():
		var child_control := child as Control
		if child_control != null and child_control.visible:
			var child_min_size := child_control.get_combined_minimum_size()
			if locked_width:
				min_size.y = maxf(min_size.y, child_min_size.y)
			else:
				min_size = min_size.max(child_min_size)
	var width_cap := _minimum_width_cap()
	if width_cap > 0.0:
		min_size.x = minf(min_size.x, width_cap)
	return min_size

func _minimum_width_cap() -> float:
	if custom_minimum_size.x > 0.0:
		return custom_minimum_size.x
	var current: Node = get_parent()
	while current != null:
		var parent_control := current as Control
		if parent_control != null:
			var parent_width := maxf(parent_control.size.x, parent_control.custom_minimum_size.x)
			if parent_width > 0.0:
				return parent_width
		current = current.get_parent()
	var viewport := get_viewport()
	return viewport.get_visible_rect().size.x if viewport != null else 0.0

func _apply_section() -> void:
	pass