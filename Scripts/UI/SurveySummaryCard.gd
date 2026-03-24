class_name SurveySummaryCard
extends PanelContainer

signal adjective_text_changed(text: String)

@onready var _stack: VBoxContainer = $Stack
@onready var _eyebrow_label: Label = $Stack/EyebrowLabel
@onready var _heading_label: Label = $Stack/HeadingLabel
@onready var _subtitle_label: Label = $Stack/SubtitleLabel
@onready var _stats_grid: GridContainer = $Stack/StatsGrid
@onready var _sentiment_panel: PanelContainer = $Stack/SentimentPanel
@onready var _sentiment_heading_label: Label = $Stack/SentimentPanel/SentimentStack/SentimentHeadingLabel
@onready var _sentiment_value_label: Label = $Stack/SentimentPanel/SentimentStack/SentimentValueLabel
@onready var _sentiment_summary_label: Label = $Stack/SentimentPanel/SentimentStack/SentimentSummaryLabel
@onready var _adjectives_heading_label: Label = $Stack/AdjectivesHeadingLabel
@onready var _adjectives_summary_label: Label = $Stack/AdjectivesSummaryLabel
@onready var _adjective_field: LineEdit = $Stack/AdjectiveField
@onready var _suggestions_heading_label: Label = $Stack/SuggestionsHeadingLabel
@onready var _suggestion_flow: HFlowContainer = $Stack/SuggestionFlow
@onready var _sections_heading_label: Label = $Stack/SectionsHeadingLabel
@onready var _sections_list: VBoxContainer = $Stack/SectionsList

var _summary_data: Dictionary = {}
var _adjective_text := ""

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_theme()
	_adjective_field.text_changed.connect(_on_adjective_text_changed)
	_apply_summary()

func configure(summary_data: Dictionary, adjective_text: String = "") -> void:
	_summary_data = summary_data.duplicate(true)
	_adjective_text = adjective_text.strip_edges()
	if is_node_ready():
		_apply_summary()

func current_adjective_text() -> String:
	return _adjective_field.text.strip_edges() if is_node_ready() else _adjective_text

func refresh_theme() -> void:
	SurveyStyle.apply_panel(self, SurveyStyle.SURFACE, SurveyStyle.BORDER, 28, 1)
	SurveyStyle.style_caption(_eyebrow_label, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.style_heading(_heading_label, 28)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.apply_panel(_sentiment_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 20, 1)
	SurveyStyle.style_caption(_sentiment_heading_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_heading(_sentiment_value_label, 30)
	SurveyStyle.style_body(_sentiment_summary_label)
	SurveyStyle.style_heading(_adjectives_heading_label, 18)
	SurveyStyle.style_body(_adjectives_summary_label)
	SurveyStyle.style_line_edit(_adjective_field)
	SurveyStyle.style_caption(_suggestions_heading_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_heading(_sections_heading_label, 18)
	if is_node_ready():
		_rebuild_stats()
		_rebuild_suggestion_buttons()
		_rebuild_sections()

func _apply_summary() -> void:
	if not is_node_ready():
		return
	_eyebrow_label.text = "Opinion Summary"
	_heading_label.text = str(_summary_data.get("survey_title", "Survey"))
	var subtitle_parts: Array[String] = ["Single-page snapshot of rating-enabled answers, section scores, and overall sentiment."]
	var survey_subtitle: String = str(_summary_data.get("survey_subtitle", "")).strip_edges()
	if not survey_subtitle.is_empty():
		subtitle_parts.append(survey_subtitle)
	_subtitle_label.text = " ".join(subtitle_parts)
	_sentiment_heading_label.text = "General sentiment"
	var overall_score: float = float(_summary_data.get("overall_score_percent", -1.0))
	var sentiment_label: String = str(_summary_data.get("overall_sentiment_label", "No sentiment signal yet"))
	if overall_score >= 0.0:
		_sentiment_value_label.text = "%d%%  %s" % [int(round(overall_score)), sentiment_label]
	else:
		_sentiment_value_label.text = sentiment_label
	_sentiment_summary_label.text = str(_summary_data.get("overall_sentiment_summary", ""))
	_adjectives_heading_label.text = "How does this feel overall?"
	_adjectives_summary_label.text = "Pick from the suggested adjectives, edit the text yourself, or do both. This field is included in the PNG summary export."
	if _adjective_field.text != _adjective_text:
		_adjective_field.text = _adjective_text
	_suggestions_heading_label.text = "Suggested adjectives"
	_sections_heading_label.text = "Section scorecards"
	_refresh_sentiment_panel()
	_rebuild_stats()
	_rebuild_suggestion_buttons()
	_rebuild_sections()

func _refresh_sentiment_panel() -> void:
	var overall_score: float = float(_summary_data.get("overall_score_percent", -1.0))
	var border_color: Color = SurveyStyle.BORDER if overall_score < 0.0 else _score_color(overall_score)
	SurveyStyle.apply_panel(_sentiment_panel, SurveyStyle.SURFACE_ALT, border_color, 20, 1)
	SurveyStyle.style_heading(_sentiment_value_label, 30, SurveyStyle.TEXT_PRIMARY if overall_score < 0.0 else border_color)

func _rebuild_stats() -> void:
	_clear_container(_stats_grid)
	_stats_grid.columns = 2
	var stat_tiles: Array[Dictionary] = [
		{
			"label": "Questions answered",
			"value": "%d / %d" % [int(_summary_data.get("answered_question_count", 0)), int(_summary_data.get("total_question_count", 0))]
		},
		{
			"label": "Sections touched",
			"value": "%d / %d" % [int(_summary_data.get("sections_answered_count", 0)), int(_summary_data.get("total_section_count", 0))]
		},
		{
			"label": "Scored questions",
			"value": str(int(_summary_data.get("scored_question_count", 0)))
		},
		{
			"label": "Overall score",
			"value": _overall_score_tile_text()
		}
	]
	for tile in stat_tiles:
		_stats_grid.add_child(_build_stat_tile(str(tile.get("label", "")), str(tile.get("value", ""))))

func _overall_score_tile_text() -> String:
	var overall_score: float = float(_summary_data.get("overall_score_percent", -1.0))
	if overall_score < 0.0:
		return "Not scored"
	return "%d%%" % int(round(overall_score))

func _build_stat_tile(label_text: String, value_text: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(tile, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	tile.add_child(stack)
	var label := Label.new()
	label.text = label_text
	SurveyStyle.style_caption(label, SurveyStyle.SOFT_WHITE)
	stack.add_child(label)
	var value := Label.new()
	value.text = value_text
	SurveyStyle.style_heading(value, 22)
	stack.add_child(value)
	return tile

func _rebuild_suggestion_buttons() -> void:
	_clear_container(_suggestion_flow)
	var suggestions: Array = _summary_data.get("adjective_suggestions", [])
	for raw_suggestion in suggestions:
		var suggestion: String = str(raw_suggestion).strip_edges()
		if suggestion.is_empty():
			continue
		var button := Button.new()
		button.text = suggestion.capitalize()
		button.pressed.connect(_on_suggestion_pressed.bind(suggestion))
		button.custom_minimum_size = Vector2(0.0, 34.0)
		_suggestion_flow.add_child(button)
	_refresh_suggestion_button_states()

func _refresh_suggestion_button_states() -> void:
	var active_tokens: Array[String] = _parse_adjective_tokens(current_adjective_text())
	for child in _suggestion_flow.get_children():
		var button := child as Button
		if button == null:
			continue
		var normalized_text: String = button.text.to_lower().strip_edges()
		if active_tokens.has(normalized_text):
			SurveyStyle.apply_primary_button(button)
		else:
			SurveyStyle.apply_secondary_button(button)
		button.add_theme_font_size_override("font_size", 14)

func _rebuild_sections() -> void:
	_clear_container(_sections_list)
	var sections: Array = _summary_data.get("sections", [])
	if sections.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No sections available."
		SurveyStyle.style_body(empty_label)
		_sections_list.add_child(empty_label)
		return
	for section_data in sections:
		if not (section_data is Dictionary):
			continue
		_sections_list.add_child(_build_section_card(section_data as Dictionary))

func _build_section_card(section_data: Dictionary) -> PanelContainer:
	var score_percent: float = float(section_data.get("score_percent", -1.0))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_color: Color = SurveyStyle.BORDER if score_percent < 0.0 else _score_color(score_percent)
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, border_color, 18, 1)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 10)
	stack.add_child(header_row)

	var title_label := Label.new()
	title_label.text = "Section %d  %s" % [int(section_data.get("section_number", 0)), str(section_data.get("title", "Section"))]
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_heading(title_label, 18)
	header_row.add_child(title_label)

	var score_label := Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if score_percent >= 0.0:
		score_label.text = "%d%%" % int(round(score_percent))
		SurveyStyle.style_heading(score_label, 20, border_color)
	else:
		score_label.text = "N/A"
		SurveyStyle.style_heading(score_label, 18, SurveyStyle.TEXT_MUTED)
	header_row.add_child(score_label)

	var meta_label := Label.new()
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.text = "%d/%d answered  |  %d scored question(s)  |  %s" % [
		int(section_data.get("answered_question_count", 0)),
		int(section_data.get("total_question_count", 0)),
		int(section_data.get("scored_question_count", 0)),
		str(section_data.get("score_label", "Not scored"))
	]
	SurveyStyle.style_caption(meta_label, SurveyStyle.SOFT_WHITE)
	stack.add_child(meta_label)

	var questions: Array = section_data.get("questions", [])
	if questions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No rating-enabled answers in this section yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_body(empty_label)
		stack.add_child(empty_label)
		return panel

	var question_list := VBoxContainer.new()
	question_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_list.add_theme_constant_override("separation", 8)
	stack.add_child(question_list)
	for question_data in questions:
		if question_data is Dictionary:
			question_list.add_child(_build_question_row(question_data as Dictionary))
	return panel

func _build_question_row(question_data: Dictionary) -> PanelContainer:
	var score_percent: float = float(question_data.get("score_percent", -1.0))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE, _score_color(score_percent), 14, 1)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)

	var title_label := Label.new()
	title_label.text = "Q%s  %s" % [str(question_data.get("display_number", str(question_data.get("question_number", "")))), str(question_data.get("prompt", "Question"))]
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_body(title_label, SurveyStyle.TEXT_PRIMARY)
	copy.add_child(title_label)

	var answer_label := Label.new()
	answer_label.text = str(question_data.get("answer_text", ""))
	answer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(answer_label, SurveyStyle.SOFT_WHITE)
	copy.add_child(answer_label)

	var score_stack := VBoxContainer.new()
	score_stack.custom_minimum_size.x = 118.0
	score_stack.add_theme_constant_override("separation", 4)
	row.add_child(score_stack)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % int(round(score_percent)) if score_percent >= 0.0 else "N/A"
	SurveyStyle.style_heading(value_label, 18, _score_color(score_percent))
	score_stack.add_child(value_label)

	var band_label := Label.new()
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	band_label.text = str(question_data.get("score_label", "Not scored"))
	SurveyStyle.style_caption(band_label, SurveyStyle.SOFT_WHITE)
	score_stack.add_child(band_label)
	return panel

func _score_color(score_percent: float) -> Color:
	if score_percent < 0.0:
		return SurveyStyle.BORDER
	return SurveyStyle.DANGER.lerp(SurveyStyle.ACCENT_ALT, clampf(score_percent / 100.0, 0.0, 1.0))

func _parse_adjective_tokens(raw_value: String) -> Array[String]:
	var tokens: Array[String] = []
	for part in raw_value.replace(";", ",").split(",", false):
		var token: String = part.strip_edges().to_lower()
		if token.is_empty() or tokens.has(token):
			continue
		tokens.append(token)
	return tokens

func _on_adjective_text_changed(new_text: String) -> void:
	_adjective_text = new_text.strip_edges()
	_refresh_suggestion_button_states()
	adjective_text_changed.emit(_adjective_text)

func _on_suggestion_pressed(suggestion: String) -> void:
	var tokens: Array[String] = _parse_adjective_tokens(current_adjective_text())
	var normalized: String = suggestion.strip_edges().to_lower()
	if tokens.has(normalized):
		tokens.erase(normalized)
	else:
		tokens.append(normalized)
	_adjective_field.text = ", ".join(tokens)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

