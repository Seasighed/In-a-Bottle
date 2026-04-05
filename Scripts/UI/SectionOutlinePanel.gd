class_name SectionOutlinePanel
extends PanelContainer

const SPRITE_ICON_HOST = preload("res://Scripts/UI/SpriteIconHost.gd")
const SURVEY_ICON_LIBRARY = preload("res://Scripts/UI/SurveyIconLibrary.gd")
const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const COMPLETE_STATUS_COLOR := Color("3cab68")

signal navigate_requested(section_index: int, question_id: String)

@onready var _title_label: Label = $Stack/TitleLabel
@onready var _subtitle_label: Label = $Stack/SubtitleLabel
@onready var _current_section_label: Label = $Stack/CurrentSectionLabel
@onready var _current_question_label: Label = $Stack/CurrentQuestionLabel
@onready var _section_scroll: ScrollContainer = $Stack/SectionScroll
@onready var _section_list: VBoxContainer = $Stack/SectionScroll/SectionList

var _survey: SurveyDefinition
var _answers: Dictionary = {}
var _show_question_rows := true
var _title_text := "Survey Map"
var _subtitle_text := "Click any section or question to scroll the questionnaire."
var _current_section_index := 0
var _current_focus_question_id := ""

func _ready() -> void:
	visible = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(290, 0)
	refresh_theme()
	_apply_display_copy()
	_current_section_label.text = "Section"
	_current_question_label.text = "Question"

func configure_display(title: String, subtitle: String, show_question_rows: bool = true) -> void:
	_title_text = title.strip_edges() if not title.strip_edges().is_empty() else "Survey Map"
	_subtitle_text = subtitle.strip_edges() if not subtitle.strip_edges().is_empty() else "Click any section or question to scroll the questionnaire."
	_show_question_rows = show_question_rows
	if not is_node_ready():
		return
	_apply_display_copy()
	if _survey != null:
		refresh(_answers, _current_section_index, _current_focus_question_id)

func refresh_theme() -> void:
	SurveyStyle.apply_panel(self, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.style_heading(_title_label, 20)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.style_caption(_current_section_label, SurveyStyle.ACCENT_ALT)
	SurveyStyle.style_caption(_current_question_label, SurveyStyle.TEXT_PRIMARY)

func _apply_display_copy() -> void:
	if _title_label != null:
		_title_label.text = _title_text
	if _subtitle_label != null:
		_subtitle_label.text = _subtitle_text

func bind_survey(survey_definition: SurveyDefinition) -> void:
	_survey = survey_definition
	refresh({}, 0, "")
	sync_scroll_progress(0.0)

func refresh(answers: Dictionary, current_section_index: int, focus_question_id: String = "") -> void:
	if _survey == null or _section_list == null:
		return
	_answers = answers
	_current_section_index = current_section_index
	_current_focus_question_id = focus_question_id
	_update_current_view_labels(current_section_index, focus_question_id)
	_clear_container(_section_list)
	for section_index in range(_survey.sections.size()):
		var section := _survey.sections[section_index]
		var section_stack := VBoxContainer.new()
		section_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_stack.add_theme_constant_override("separation", 4)
		_section_list.add_child(section_stack)

		var active_question_index := -1
		if section_index == current_section_index:
			active_question_index = _question_index_for_section(section, focus_question_id)
		var section_row := _create_section_row(section, section_index, section_index == current_section_index, active_question_index)
		section_stack.add_child(section_row)
		if not _show_question_rows:
			continue

		var question_margin := MarginContainer.new()
		question_margin.add_theme_constant_override("margin_left", 18)
		question_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_stack.add_child(question_margin)

		var question_stack := VBoxContainer.new()
		question_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_stack.add_theme_constant_override("separation", 4)
		question_margin.add_child(question_stack)

		for question_index in range(section.questions.size()):
			var question := section.questions[question_index]
			var is_active_question := section_index == current_section_index and question.id == focus_question_id
			var question_row := _create_question_row(section_index, question_index, question, is_active_question)
			question_stack.add_child(question_row)

func _update_current_view_labels(current_section_index: int, focus_question_id: String) -> void:
	if _survey == null or _survey.sections.is_empty():
		_current_section_label.text = "Section"
		_current_question_label.text = "Question"
		return
	var resolved_section_index: int = clampi(current_section_index, 0, _survey.sections.size() - 1)
	var section: SurveySection = _survey.sections[resolved_section_index]
	_current_section_label.text = section.display_title(resolved_section_index)
	SurveyStyle.style_caption(_current_section_label, _status_color(_section_completion_state(section)))
	if not _show_question_rows:
		_current_question_label.text = "%d question(s) | %d answered" % [section.questions.size(), _answered_question_count(section)]
		SurveyStyle.style_caption(_current_question_label, _status_color(_section_completion_state(section)))
		return
	var question_index: int = _question_index_for_section(section, focus_question_id)
	if question_index < 0 or question_index >= section.questions.size():
		_current_question_label.text = "Question"
		SurveyStyle.style_caption(_current_question_label, SurveyStyle.TEXT_PRIMARY)
		return
	var question: SurveyQuestion = section.questions[question_index]
	_current_question_label.text = "Question %d | %s | %s" % [question_index + 1, _type_label(question.type), question.requirement_label()]
	SurveyStyle.style_caption(_current_question_label, _status_color(_question_completion_state(question)))

func sync_scroll_progress(progress: float) -> void:
	if _section_scroll == null:
		return
	var resolved_progress: float = clampf(progress, 0.0, 1.0)
	var scroll_bar := _section_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		_section_scroll.scroll_vertical = 0
		return
	var max_scroll: float = maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	_section_scroll.scroll_vertical = int(round(max_scroll * resolved_progress))

func _create_section_row(section: SurveySection, section_index: int, is_active: bool, active_question_index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var completion_state: StringName = _section_completion_state(section)
	var fill := SurveyStyle.SURFACE_MUTED if is_active else SurveyStyle.SURFACE_ALT
	var border := _status_color(completion_state) if completion_state != SurveyQuestion.ANSWER_STATE_UNANSWERED else (SurveyStyle.ACCENT_ALT if is_active else SurveyStyle.BORDER)
	SurveyStyle.apply_panel(row, fill, border, 16, 1)
	row.gui_input.connect(_on_row_gui_input.bind(section_index, "", row))
	row.mouse_entered.connect(_on_row_mouse_entered)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var status_icon = SPRITE_ICON_HOST.new()
	status_icon.custom_minimum_size = Vector2(18, 18)
	status_icon.set_icon(
		SURVEY_ICON_LIBRARY.completion_texture(completion_state == SurveyQuestion.ANSWER_STATE_COMPLETE),
		_status_color(completion_state),
		16.0
	)
	hbox.add_child(status_icon)

	var section_icon = SPRITE_ICON_HOST.new()
	section_icon.custom_minimum_size = Vector2(18, 18)
	section_icon.set_icon(
		SURVEY_ICON_LIBRARY.section_texture(section.icon_name),
		SurveyStyle.ACCENT_ALT if is_active else SurveyStyle.TEXT_MUTED,
		16.0
	)
	hbox.add_child(section_icon)

	var title_label := Label.new()
	title_label.text = section.display_title(section_index)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_body(title_label, SurveyStyle.TEXT_PRIMARY)
	hbox.add_child(title_label)

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_active and active_question_index >= 0 and not section.questions.is_empty():
		count_label.text = "%d/%d" % [active_question_index + 1, section.questions.size()]
	else:
		count_label.text = str(section.questions.size())
	SurveyStyle.style_caption(count_label, SurveyStyle.TEXT_PRIMARY)
	hbox.add_child(count_label)

	return row

func _create_question_row(section_index: int, question_index: int, question: SurveyQuestion, is_active: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var completion_state: StringName = _question_completion_state(question)
	var answered := completion_state == SurveyQuestion.ANSWER_STATE_COMPLETE
	var fill := SurveyStyle.SURFACE_MUTED if is_active else SurveyStyle.SURFACE
	var border := _status_color(completion_state) if completion_state != SurveyQuestion.ANSWER_STATE_UNANSWERED else SurveyStyle.BORDER
	if is_active:
		border = _status_color(completion_state) if completion_state != SurveyQuestion.ANSWER_STATE_UNANSWERED else SurveyStyle.ACCENT_ALT
	SurveyStyle.apply_panel(row, fill, border, 14, 1)
	row.gui_input.connect(_on_row_gui_input.bind(section_index, question.id, row))
	row.mouse_entered.connect(_on_row_mouse_entered)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var status_icon = SPRITE_ICON_HOST.new()
	status_icon.custom_minimum_size = Vector2(16, 16)
	status_icon.set_icon(
		SURVEY_ICON_LIBRARY.completion_texture(answered),
		_status_color(completion_state),
		14.0
	)
	hbox.add_child(status_icon)

	var prompt_label := Label.new()
	prompt_label.text = question.display_title(question_index)
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_body(prompt_label, SurveyStyle.TEXT_PRIMARY if is_active or completion_state != SurveyQuestion.ANSWER_STATE_UNANSWERED else SurveyStyle.TEXT_MUTED)
	hbox.add_child(prompt_label)

	return row

func _type_label(kind: StringName) -> String:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_LONG_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_EMAIL:
			return "Email"
		SurveyQuestion.TYPE_DATE:
			return "Date"
		SurveyQuestion.TYPE_NUMBER:
			return "Number"
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return "Multiple choice"
		SurveyQuestion.TYPE_DROPDOWN:
			return "Dropdown"
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return "Checkbox"
		SurveyQuestion.TYPE_BOOLEAN:
			return "Yes/No"
		SurveyQuestion.TYPE_SCALE:
			return "Scale"
		SurveyQuestion.TYPE_NPS:
			return "NPS"
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return "Ranked choice"
		SurveyQuestion.TYPE_MATRIX:
			return "Matrix"
	return "Question"

func _question_index_for_section(section: SurveySection, question_id: String) -> int:
	if question_id.is_empty():
		return 0 if not section.questions.is_empty() else -1
	for question_index in range(section.questions.size()):
		if section.questions[question_index].id == question_id:
			return question_index
	return 0 if not section.questions.is_empty() else -1

func _on_row_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_row_gui_input(event: InputEvent, section_index: int, question_id: String, row: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			SURVEY_UI_FEEDBACK.play_select()
			SURVEY_UI_FEEDBACK.pulse(row, 0.035, 0.16)
			call_deferred("_emit_navigate_requested", section_index, question_id)

func _emit_navigate_requested(section_index: int, question_id: String) -> void:
	navigate_requested.emit(section_index, question_id)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()

func _question_completion_state(question: SurveyQuestion) -> StringName:
	if question == null:
		return SurveyQuestion.ANSWER_STATE_UNANSWERED
	return question.answer_completion_state(_answers.get(question.id, null))

func _section_completion_state(section: SurveySection) -> StringName:
	if section == null or section.questions.is_empty():
		return SurveyQuestion.ANSWER_STATE_UNANSWERED
	var saw_partial := false
	var saw_complete := false
	for question in section.questions:
		var state: StringName = _question_completion_state(question)
		if state == SurveyQuestion.ANSWER_STATE_COMPLETE:
			saw_complete = true
		elif state == SurveyQuestion.ANSWER_STATE_PARTIAL:
			saw_partial = true
	if section.is_complete(_answers):
		return SurveyQuestion.ANSWER_STATE_COMPLETE
	if saw_complete or saw_partial:
		return SurveyQuestion.ANSWER_STATE_PARTIAL
	return SurveyQuestion.ANSWER_STATE_UNANSWERED

func _answered_question_count(section: SurveySection) -> int:
	if section == null:
		return 0
	var answered_count := 0
	for question in section.questions:
		if not question.is_answer_empty(_answers.get(question.id, null)):
			answered_count += 1
	return answered_count

func _status_color(state: StringName) -> Color:
	match state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			return COMPLETE_STATUS_COLOR
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			return SurveyStyle.HIGHLIGHT_GOLD
	return SurveyStyle.TEXT_MUTED
