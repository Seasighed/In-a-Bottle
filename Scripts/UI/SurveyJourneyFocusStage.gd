class_name SurveyJourneyFocusStage
extends Control

const DEFAULT_QUESTION_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/DefaultQuestionView.tscn")
const SCALE_CHIPS_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/ScaleChipQuestionView.tscn")
const RANKED_CHOICE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/RankedChoiceQuestionView.tscn")
const MATRIX_QUESTION_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/MatrixQuestionView.tscn")
const QUESTION_VIEW_REGISTRY = preload("res://Scripts/UI/QuestionViewRegistry.gd")
const TRACE_LOG_PATH := "user://survey_journey_trace.log"

signal answer_changed(question_id: String, value: Variant)
signal question_selected(question_id: String)
signal help_requested(question_id: String)
signal modifier_fatigue_detected(question_id: String, modifier_key: String, message: String)
signal layout_stabilized

var _views_by_question_id: Dictionary = {}
var _questions_by_id: Dictionary = {}
var _answers_by_question_id: Dictionary = {}
var _active_question_id := ""
var _active_view: SurveyQuestionView
var _viewport_size := Vector2.ZERO
var _layout_refresh_in_progress := false
var _answer_layout_refresh_queued := false
var _question_debug_ids_enabled := false
var _question_modifiers_enabled := true

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	custom_minimum_size = Vector2.ZERO

func reset() -> void:
	_trace("FocusStage reset active=%s cached=%d" % [_active_question_id, _views_by_question_id.size()])
	for value in _views_by_question_id.values():
		var view := value as SurveyQuestionView
		if view == null or not is_instance_valid(view):
			continue
		if view.get_parent() == self:
			remove_child(view)
		view.queue_free()
	_views_by_question_id.clear()
	_questions_by_id.clear()
	_answers_by_question_id.clear()
	_active_question_id = ""
	_active_view = null
	custom_minimum_size = Vector2.ZERO

func prepare_questions(questions: Array, answers: Dictionary, viewport_size: Vector2) -> void:
	reset()
	_viewport_size = viewport_size
	_trace("FocusStage prepare questions=%d" % questions.size())
	for question_variant in questions:
		var question := question_variant as SurveyQuestion
		if question == null:
			continue
		_questions_by_id[question.id] = question
		if answers.has(question.id):
			_answers_by_question_id[question.id] = _duplicate_answer_value(answers.get(question.id))
	refresh_stage_layout(viewport_size)

func show_question(question_id: String, should_focus_primary: bool = false) -> bool:
	_trace("FocusStage show_question start id=%s active=%s" % [question_id, _active_question_id])
	var view := _ensure_view(question_id)
	if view == null:
		_trace("FocusStage show_question failed missing view id=%s" % question_id)
		return false
	if _active_view != null and is_instance_valid(_active_view) and _active_view != view:
		_active_view.visible = false
		_active_view.set_selected(false)
		if _active_view.get_parent() == self:
			remove_child(_active_view)
	if view.get_parent() != self:
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		add_child(view)
	view.visible = true
	view.set_selected(true)
	_active_question_id = question_id
	_active_view = view
	refresh_stage_layout(_viewport_size if _viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)
	call_deferred("_refresh_after_show")
	if should_focus_primary:
		call_deferred("_focus_primary_control")
	_trace("FocusStage show_question ready id=%s" % question_id)
	return true

func sync_answers(answers: Dictionary) -> void:
	_answers_by_question_id.clear()
	for question_id_variant in _questions_by_id.keys():
		var question_id := str(question_id_variant)
		var question := _questions_by_id.get(question_id) as SurveyQuestion
		if question == null:
			continue
		if answers.has(question_id):
			_answers_by_question_id[question_id] = _duplicate_answer_value(answers.get(question_id))
		var view := _views_by_question_id.get(question_id) as SurveyQuestionView
		if view != null:
			view.set_question_debug_ids_enabled(_question_debug_ids_enabled)
			view.set_question_modifiers_enabled(_question_modifiers_enabled)
			view.configure(question, _answers_by_question_id.get(question_id, question.default_value))
			view.set_selected(question_id == _active_question_id)

func set_question_debug_ids_enabled(enabled: bool) -> void:
	if _question_debug_ids_enabled == enabled:
		return
	_question_debug_ids_enabled = enabled
	for value in _views_by_question_id.values():
		var view := value as SurveyQuestionView
		if view != null and is_instance_valid(view):
			view.set_question_debug_ids_enabled(enabled)

func set_question_modifiers_enabled(enabled: bool) -> void:
	if _question_modifiers_enabled == enabled:
		return
	_question_modifiers_enabled = enabled
	for value in _views_by_question_id.values():
		var view := value as SurveyQuestionView
		if view != null and is_instance_valid(view):
			view.set_question_modifiers_enabled(enabled)
	if _active_view != null and is_instance_valid(_active_view):
		refresh_stage_layout(_viewport_size if _viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)

func refresh_stage_layout(viewport_size: Vector2) -> void:
	if _layout_refresh_in_progress:
		return
	_layout_refresh_in_progress = true
	_viewport_size = viewport_size
	if _active_view == null or not is_instance_valid(_active_view):
		custom_minimum_size = Vector2.ZERO
		_layout_refresh_in_progress = false
		return
	_active_view.refresh_responsive_layout(viewport_size)
	var scroll := get_parent() as ScrollContainer
	var stage_width := _resolved_stage_width(scroll, viewport_size.x)
	_position_active_view(stage_width)
	var stage_height := maxf(_active_view.size.y, _active_view.get_combined_minimum_size().y)
	stage_height = maxf(stage_height, 1.0)
	size = Vector2(stage_width, stage_height)
	custom_minimum_size = Vector2(0.0, stage_height)
	_layout_refresh_in_progress = false

func active_question_id() -> String:
	return _active_question_id

func active_view() -> SurveyQuestionView:
	return _active_view

func _position_active_view(width: float) -> void:
	if _active_view == null:
		return
	_active_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_active_view.position = Vector2.ZERO
	_active_view.custom_minimum_size = Vector2(width, 0.0)
	_active_view.size = Vector2(width, 0.0)
	_active_view.reset_size()
	var view_height := maxf(_active_view.size.y, _active_view.get_combined_minimum_size().y)
	_active_view.size = Vector2(width, view_height)

func _refresh_after_show() -> void:
	if _active_view == null or not is_instance_valid(_active_view):
		return
	refresh_stage_layout(_viewport_size if _viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)
	layout_stabilized.emit()

func _resolved_stage_width(scroll: ScrollContainer, viewport_width: float) -> float:
	var stage_width := 0.0
	var phone_layout := viewport_width <= 480.0
	var max_stage_width := maxf(viewport_width - (4.0 if phone_layout else 96.0), 320.0)
	if scroll != null:
		if scroll.size.x > 0.0:
			stage_width = scroll.size.x
		var parent_control := scroll.get_parent() as Control
		if stage_width <= 0.0 and parent_control != null and parent_control.size.x > 0.0:
			stage_width = parent_control.size.x
	if stage_width <= 0.0:
		stage_width = max_stage_width
	return clampf(stage_width, 320.0, max_stage_width)

func _focus_primary_control() -> void:
	if _active_view != null and is_instance_valid(_active_view):
		_active_view.focus_primary_control()

func _on_view_answer_changed(question_id: String, value: Variant) -> void:
	_answers_by_question_id[question_id] = _duplicate_answer_value(value)
	_trace("FocusStage answer_changed id=%s type=%s" % [question_id, typeof(value)])
	_queue_answer_layout_refresh()
	answer_changed.emit(question_id, value)

func _queue_answer_layout_refresh() -> void:
	if _answer_layout_refresh_queued:
		return
	_answer_layout_refresh_queued = true
	call_deferred("_refresh_after_answer_change")

func _refresh_after_answer_change() -> void:
	_answer_layout_refresh_queued = false
	if _active_view == null or not is_instance_valid(_active_view):
		return
	refresh_stage_layout(_viewport_size if _viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)
	layout_stabilized.emit()

func _on_view_question_selected(question_id: String) -> void:
	question_selected.emit(question_id)

func _on_view_help_requested(question_id: String) -> void:
	help_requested.emit(question_id)

func _on_view_modifier_fatigue_detected(question_id: String, modifier_key: String, message: String) -> void:
	modifier_fatigue_detected.emit(question_id, modifier_key, message)

func _instantiate_question_view(question: SurveyQuestion) -> SurveyQuestionView:
	var resolved_view := QUESTION_VIEW_REGISTRY.instantiate_for_question(question)
	if resolved_view != null:
		return resolved_view
	var fallback_node := DEFAULT_QUESTION_VIEW_SCENE.instantiate()
	var fallback_view := fallback_node as SurveyQuestionView
	if fallback_view != null:
		return fallback_view
	return DefaultQuestionView.new()

func _ensure_view(question_id: String) -> SurveyQuestionView:
	var existing_view := _views_by_question_id.get(question_id) as SurveyQuestionView
	if existing_view != null and is_instance_valid(existing_view):
		_trace("FocusStage reuse view id=%s" % question_id)
		return existing_view
	var question := _questions_by_id.get(question_id) as SurveyQuestion
	if question == null:
		_trace("FocusStage missing question id=%s" % question_id)
		return null
	var view := _instantiate_question_view(question)
	if view == null:
		_trace("FocusStage instantiate failed id=%s" % question_id)
		return null
	view.visible = false
	view.set_presentation_mode(SurveyQuestionView.PRESENTATION_JOURNEY_FOCUS)
	view.set_question_debug_ids_enabled(_question_debug_ids_enabled)
	view.set_question_modifiers_enabled(_question_modifiers_enabled)
	view.answer_changed.connect(_on_view_answer_changed)
	view.question_selected.connect(_on_view_question_selected)
	view.help_requested.connect(_on_view_help_requested)
	view.modifier_fatigue_detected.connect(_on_view_modifier_fatigue_detected)
	view.configure(question, _answers_by_question_id.get(question_id, question.default_value))
	view.set_selected(false)
	_views_by_question_id[question_id] = view
	_trace("FocusStage instantiate view id=%s type=%s" % [question_id, str(question.type)])
	return view

func _duplicate_answer_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return value

func _trace(message: String) -> void:
	var existing := ""
	if FileAccess.file_exists(TRACE_LOG_PATH):
		var read_file := FileAccess.open(TRACE_LOG_PATH, FileAccess.READ)
		if read_file != null:
			existing = read_file.get_as_text()
			read_file.close()
	var write_file := FileAccess.open(TRACE_LOG_PATH, FileAccess.WRITE)
	if write_file == null:
		return
	write_file.store_string(existing + "[%s] %s\n" % [Time.get_time_string_from_system(), message])
	write_file.close()
