class_name SurveySearchOverlay
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const MAX_RESULTS := 12

signal navigate_requested(section_index: int, question_id: String)
signal close_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _panel: PanelContainer = $Center/Panel
@onready var _heading_label: Label = $Center/Panel/Stack/HeadingRow/HeadingLabel
@onready var _close_button: Button = $Center/Panel/Stack/HeadingRow/CloseButton
@onready var _subtitle_label: Label = $Center/Panel/Stack/SubtitleLabel
@onready var _search_field: LineEdit = $Center/Panel/Stack/SearchField
@onready var _empty_state_label: Label = $Center/Panel/Stack/EmptyStateLabel
@onready var _results_scroll: ScrollContainer = $Center/Panel/Stack/ResultsScroll
@onready var _results_list: VBoxContainer = $Center/Panel/Stack/ResultsScroll/ResultsList

var _survey: SurveyDefinition
var _search_entries: Array[Dictionary] = []
var _result_cache: Array[Dictionary] = []

func _ready() -> void:
	layer = 60
	visible = false
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_search_field.text_changed.connect(_on_search_text_changed)
	_search_field.text_submitted.connect(_on_search_text_submitted)

func refresh_theme() -> void:
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 26, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.style_body(_empty_state_label)
	SurveyStyle.apply_secondary_button(_close_button)
	SurveyStyle.style_line_edit(_search_field)
	_close_button.custom_minimum_size = Vector2(44, 44)
	_refresh_results_for_query(_search_field.text if is_node_ready() else "")

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.04, 12.0, 28.0)
	var panel_width: float = clampf(viewport_size.x - (horizontal_margin * 2.0), 280.0, 760.0)
	_panel.custom_minimum_size.x = panel_width
	_results_scroll.custom_minimum_size.y = clampf(viewport_size.y * 0.32, 180.0, 360.0)

func open_search(survey_definition: SurveyDefinition) -> void:
	_survey = survey_definition
	_search_entries = _build_search_entries()
	_result_cache.clear()
	_heading_label.text = "What's on your mind about %s?" % _search_subject()
	_subtitle_label.text = "Type a keyword, phrase, section title, or answer option to search the questionnaire."
	_search_field.text = ""
	_refresh_results_for_query("")
	show()
	call_deferred("_focus_search_field")

func close_search() -> void:
	hide()

func _focus_search_field() -> void:
	if not visible:
		return
	_search_field.grab_focus()
	_search_field.select_all()

func _build_search_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _survey == null:
		return entries
	for section_index in range(_survey.sections.size()):
		var section: SurveySection = _survey.sections[section_index]
		for question_index in range(section.questions.size()):
			var question: SurveyQuestion = section.questions[question_index]
			var preview_text: String = question.description.strip_edges()
			if preview_text.is_empty():
				preview_text = _build_question_preview(question)
			entries.append({
				"section_index": section_index,
				"question_id": question.id,
				"title": question.display_title(question_index),
				"section_label": section.display_title(section_index),
				"type_label": str(question.type).replace("_", " "),
				"preview": preview_text,
				"normalized_prompt": _normalize_text(question.prompt),
				"normalized_section": _normalize_text("%s %s" % [section.title, section.description]),
				"normalized_haystack": _normalize_text(_build_question_haystack(section, question))
			})
	return entries

func _build_question_haystack(section: SurveySection, question: SurveyQuestion) -> String:
	return "%s %s %s" % [section.title, section.description, question.searchable_text()]

func _build_question_preview(question: SurveyQuestion) -> String:
	if not question.options.is_empty():
		var preview_options: Array[String] = []
		for option_index in range(mini(question.options.size(), 3)):
			preview_options.append(question.options[option_index])
		return "Options: %s" % ", ".join(preview_options)
	if not question.rows.is_empty():
		var preview_rows: Array[String] = []
		for row_index in range(mini(question.rows.size(), 2)):
			preview_rows.append(question.rows[row_index])
		return "Rows: %s" % " | ".join(preview_rows)
	return "Question"

func _search_subject() -> String:
	if _survey == null:
		return "this survey"
	return _survey.resolved_onboarding_subject()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _on_search_text_changed(new_text: String) -> void:
	_refresh_results_for_query(new_text)

func _on_search_text_submitted(_submitted_text: String) -> void:
	if _result_cache.is_empty():
		return
	var first_result: Dictionary = _result_cache[0]
	_on_result_selected(int(first_result.get("section_index", 0)), str(first_result.get("question_id", "")), null)

func _refresh_results_for_query(raw_query: String) -> void:
	if _results_list == null:
		return
	_clear_results()
	_result_cache.clear()
	var normalized_query: String = _normalize_text(raw_query)
	if normalized_query.is_empty():
		_empty_state_label.text = "Try a section name, question phrase, or answer option."
		_empty_state_label.visible = true
		return

	var ranked_results: Array[Dictionary] = []
	for entry in _search_entries:
		var score: float = _score_entry(entry, normalized_query)
		if score < 18.0:
			continue
		var result: Dictionary = entry.duplicate(true)
		result["score"] = score
		ranked_results.append(result)
	ranked_results.sort_custom(Callable(self, "_sort_results"))
	if ranked_results.size() > MAX_RESULTS:
		ranked_results.resize(MAX_RESULTS)
	_result_cache = ranked_results

	if _result_cache.is_empty():
		_empty_state_label.text = "No close matches yet. Try a shorter phrase or a different keyword."
		_empty_state_label.visible = true
		return

	_empty_state_label.visible = false
	for result in _result_cache:
		_results_list.add_child(_build_result_row(result))
	_results_scroll.scroll_vertical = 0

func _sort_results(left: Dictionary, right: Dictionary) -> bool:
	var left_score: float = float(left.get("score", 0.0))
	var right_score: float = float(right.get("score", 0.0))
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score
	return str(left.get("title", "")) < str(right.get("title", ""))

func _score_entry(entry: Dictionary, normalized_query: String) -> float:
	var prompt_text: String = str(entry.get("normalized_prompt", ""))
	var section_text: String = str(entry.get("normalized_section", ""))
	var haystack_text: String = str(entry.get("normalized_haystack", ""))
	var score: float = 0.0

	if prompt_text.contains(normalized_query):
		score += 140.0
	if haystack_text.contains(normalized_query):
		score += 95.0
	if section_text.contains(normalized_query):
		score += 55.0

	var prompt_similarity: float = prompt_text.similarity(normalized_query)
	if prompt_similarity >= 0.26:
		score += prompt_similarity * 85.0
	var haystack_similarity: float = haystack_text.similarity(normalized_query)
	if haystack_similarity >= 0.22:
		score += haystack_similarity * 60.0

	var query_tokens: PackedStringArray = _tokenize_text(normalized_query)
	var haystack_tokens: PackedStringArray = _tokenize_text(haystack_text)
	for token in query_tokens:
		if haystack_tokens.has(token):
			score += 28.0
			continue
		var best_similarity: float = _best_token_similarity(token, haystack_tokens)
		if best_similarity >= 0.82:
			score += best_similarity * 22.0
		elif token.length() >= 5 and best_similarity >= 0.66:
			score += best_similarity * 11.0

	return score

func _best_token_similarity(query_token: String, haystack_tokens: PackedStringArray) -> float:
	var best_similarity := 0.0
	for candidate in haystack_tokens:
		if abs(candidate.length() - query_token.length()) > 4:
			continue
		var similarity: float = query_token.similarity(candidate)
		if similarity > best_similarity:
			best_similarity = similarity
	return best_similarity

func _build_result_row(result: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	SurveyStyle.apply_panel(row, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	row.gui_input.connect(_on_result_gui_input.bind(int(result.get("section_index", 0)), str(result.get("question_id", "")), row))
	row.mouse_entered.connect(_on_result_mouse_entered)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	row.add_child(stack)

	var title_label := Label.new()
	title_label.text = str(result.get("title", ""))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_body(title_label, SurveyStyle.TEXT_PRIMARY)
	stack.add_child(title_label)

	var meta_label := Label.new()
	meta_label.text = "%s - %s" % [str(result.get("section_label", "")), str(result.get("type_label", ""))]
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(meta_label, SurveyStyle.SOFT_WHITE)
	stack.add_child(meta_label)

	var preview_label := Label.new()
	preview_label.text = str(result.get("preview", ""))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(preview_label, SurveyStyle.TEXT_MUTED)
	stack.add_child(preview_label)

	return row

func _on_result_mouse_entered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_result_gui_input(event: InputEvent, section_index: int, question_id: String, row: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_result_selected(section_index, question_id, row)

func _on_result_selected(section_index: int, question_id: String, row: Control) -> void:
	if question_id.is_empty():
		return
	SURVEY_UI_FEEDBACK.play_select()
	if row != null:
		SURVEY_UI_FEEDBACK.pulse(row, 0.04, 0.18)
	navigate_requested.emit(section_index, question_id)
	close_requested.emit()

func _clear_results() -> void:
	for child in _results_list.get_children():
		child.free()

func _normalize_text(raw_text: String) -> String:
	var normalized: String = raw_text.to_lower().strip_edges()
	for token in ["\n", "\t", ".", ",", ":", ";", "!", "?", "(", ")", "[", "]", "{", "}", "/", "\\", "-", "_", "\"", "'", "|"]:
		normalized = normalized.replace(token, " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()

func _tokenize_text(raw_text: String) -> PackedStringArray:
	var normalized: String = _normalize_text(raw_text)
	if normalized.is_empty():
		return PackedStringArray()
	return PackedStringArray(normalized.split(" ", false))
