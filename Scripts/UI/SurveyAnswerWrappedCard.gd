class_name SurveyAnswerWrappedCard
extends Control

const PAGE_SIZE := Vector2i(1080, 1920)
const THEME_LIGHT := "light"
const THEME_DARK := "dark"
const PAGE_KIND_ANSWERS := "answers"
const PAGE_KIND_STATS := "stats"
const CONTENT_MARGIN_LEFT := 82
const CONTENT_MARGIN_RIGHT := 82
const CONTENT_MARGIN_TOP := 78
const CONTENT_MARGIN_BOTTOM := 70
const STORY_TARGET_FILL := 0.64
const STORY_MIN_FILL := 0.52
const STORY_MAX_FILL := 0.72
const LAYOUT_ESTIMATE_SAFETY := 1.25
const ANSWER_FONT_MIN := 34
const ANSWER_LABEL_MIN := 20
const PROMPT_FONT_MIN := 18
const PROMPT_FONT_MAX := 52
const RANKED_OPTION_LIMIT := 5

var _page_data: Dictionary = {}
var _wrapped_data: Dictionary = {}
var _content: MarginContainer
var _stack: VBoxContainer
var _theme_id := THEME_LIGHT
var _header_node: Control
var _answer_list_node: Control
var _stats_stack_node: Control
var _layout_profile: Dictionary = {}
var _layout_metrics: Dictionary = {}
var _vital_nodes: Array[Control] = []
var _answer_nodes: Array[Control] = []
var _prompt_nodes: Array[Control] = []
var _tracked_labels: Array[Dictionary] = []
var _matrix_row_count := 0
var _matrix_primary_answer_count := 0
var _matrix_tie_state_count := 0
var _matrix_row_metrics: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(PAGE_SIZE)
	_build_nodes()
	_apply_page()

func configure(summary_data: Dictionary) -> void:
	_wrapped_data = summary_data.duplicate(true)
	var pages: Array = summary_data.get("pages", [])
	if not pages.is_empty() and pages[0] is Dictionary:
		configure_page(pages[0] as Dictionary, summary_data)
		return
	configure_page(_legacy_summary_page(summary_data), summary_data)

func configure_page(page_data: Dictionary, wrapped_data: Dictionary = {}) -> void:
	_page_data = page_data.duplicate(true)
	_wrapped_data = wrapped_data.duplicate(true)
	_theme_id = _normalized_theme(str(_page_data.get("theme_id", _wrapped_data.get("theme_id", THEME_LIGHT))))
	custom_minimum_size = Vector2(PAGE_SIZE)
	if is_node_ready():
		_apply_page()

func refresh_layout(_available_width: float = float(PAGE_SIZE.x)) -> void:
	custom_minimum_size = Vector2(PAGE_SIZE)
	if is_node_ready():
		size = Vector2(PAGE_SIZE)

func refresh_theme() -> void:
	if is_node_ready():
		_apply_page()

func get_layout_metrics() -> Dictionary:
	_layout_metrics = _collect_layout_metrics()
	return _layout_metrics.duplicate(true)

func _draw() -> void:
	var colors := _palette()
	var start: Color = colors.get("background_start", Color.WHITE)
	var middle: Color = colors.get("background_middle", start)
	var end: Color = colors.get("background_end", Color.WHITE)
	var draw_size := size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		draw_size = Vector2(PAGE_SIZE)
	var cell_size := 18
	for y in range(0, int(draw_size.y) + cell_size, cell_size):
		for x in range(0, int(draw_size.x) + cell_size, cell_size):
			var x_ratio := float(x) / maxf(draw_size.x, 1.0)
			var y_ratio := float(y) / maxf(draw_size.y, 1.0)
			var ratio := clampf((x_ratio * 0.52) + (y_ratio * 0.48), 0.0, 1.0)
			var color := start.lerp(middle, ratio * 2.0) if ratio <= 0.5 else middle.lerp(end, (ratio - 0.5) * 2.0)
			draw_rect(Rect2(float(x), float(y), float(cell_size + 1), float(cell_size + 1)), color)

func _build_nodes() -> void:
	if _content != null:
		return
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", CONTENT_MARGIN_LEFT)
	_content.add_theme_constant_override("margin_right", CONTENT_MARGIN_RIGHT)
	_content.add_theme_constant_override("margin_top", CONTENT_MARGIN_TOP)
	_content.add_theme_constant_override("margin_bottom", CONTENT_MARGIN_BOTTOM)
	add_child(_content)

	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_theme_constant_override("separation", 0)
	_content.add_child(_stack)

func _apply_page() -> void:
	if not is_node_ready():
		return
	size = Vector2(PAGE_SIZE)
	queue_redraw()
	_clear_container(_stack)
	_clear_layout_tracking()
	if _page_data.is_empty():
		return
	var colors := _palette()
	_layout_profile = _layout_profile_for_page()
	_header_node = _context_header(colors)
	_stack.add_child(_header_node)
	if str(_page_data.get("page_kind", PAGE_KIND_ANSWERS)) == PAGE_KIND_STATS:
		_add_stats_page(colors)
	else:
		_add_answer_page(colors)

func _context_header(colors: Dictionary) -> VBoxContainer:
	var header := VBoxContainer.new()
	header.name = "ContextHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 9)

	var title := Label.new()
	title.text = str(_page_data.get("title", _page_data.get("survey_title", "Survey"))).strip_edges()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	_style_label(title, 29, colors.get("context", Color.BLACK), true)
	header.add_child(title)
	_register_context_node(title, "context_title")

	var subtitle_text := str(_page_data.get("subtitle", "")).strip_edges()
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.text = subtitle_text
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.max_lines_visible = 2
		_style_label(subtitle, 21, colors.get("context_subtle", Color.BLACK))
		header.add_child(subtitle)
		_register_context_node(subtitle, "context_subtitle")
	return header

func _add_answer_page(colors: Dictionary) -> void:
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(top_spacer)

	var question_list := VBoxContainer.new()
	question_list.name = "AnswerList"
	question_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	question_list.alignment = BoxContainer.ALIGNMENT_CENTER
	question_list.add_theme_constant_override("separation", int(_layout_profile.get("block_separation", 44)))
	_stack.add_child(question_list)
	_answer_list_node = question_list

	var questions: Array = _page_data.get("questions", [])
	for question_value in questions:
		if question_value is Dictionary:
			question_list.add_child(_answer_block(question_value as Dictionary, colors))

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(bottom_spacer)

func _add_stats_page(colors: Dictionary) -> void:
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(top_spacer)

	var stats_stack := VBoxContainer.new()
	stats_stack.name = "Stats"
	stats_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_stack.add_theme_constant_override("separation", int(_layout_profile.get("stat_separation", 92)))
	_stack.add_child(stats_stack)
	_stats_stack_node = stats_stack

	for stat_value in _page_data.get("stats", []) as Array:
		if stat_value is Dictionary:
			var stat: Dictionary = stat_value as Dictionary
			stats_stack.add_child(_stat_line(str(stat.get("value", "")), str(stat.get("label", "")), colors))

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(bottom_spacer)
	_stack.add_child(_footer_block(colors))

func _answer_block(question_data: Dictionary, colors: Dictionary) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "Question_%s" % str(question_data.get("question_id", ""))
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", int(_layout_profile.get("inner_separation", 18)))

	var prompt := Label.new()
	prompt.text = _prompt_text(question_data)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.max_lines_visible = 3
	_style_label(prompt, int(_layout_profile.get("prompt_font_size", 24)), colors.get("prompt", Color.BLACK))
	block.add_child(prompt)
	_register_prompt_node(prompt, "prompt")

	match _answer_visual_kind(question_data):
		"matrix_summary":
			block.add_child(_matrix_summary_control(question_data, colors))
		"ranked_summary":
			block.add_child(_ranked_summary_control(question_data, colors))
		"numeric_summary":
			block.add_child(_large_text_answer_control(_numeric_answer_text(question_data), question_data, colors))
		"option_tallies":
			block.add_child(_choice_summary_control(question_data, colors))
		"text_word_tallies":
			block.add_child(_word_tally_summary_control(question_data, colors))
		"text_individual_answers", "text_answer_tallies":
			block.add_child(_text_answer_tally_control(question_data, colors))
		_:
			block.add_child(_large_text_answer_control(_display_summary(question_data), question_data, colors))
	return block

func _large_text_answer_control(text: String, question_data: Dictionary, colors: Dictionary) -> Label:
	var answer := Label.new()
	answer.name = "AnswerText"
	answer.text = text
	answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	answer.max_lines_visible = _answer_line_limit_for_profile(question_data)
	answer.add_theme_constant_override("line_spacing", int(_layout_profile.get("line_spacing", 10)))
	_style_label(answer, int(_layout_profile.get("answer_font_size", 58)), colors.get("answer", Color.BLACK), true)
	_register_answer_node(answer, "answer_text")
	return answer

func _choice_summary_control(question_data: Dictionary, colors: Dictionary) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.name = "OptionTallySummary"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", int(_layout_profile.get("choice_row_separation", 10)))
	var entries := _sorted_count_entries(question_data.get("option_counts", {}) as Dictionary)
	var added := 0
	for entry in entries:
		var count := int(entry.get("count", 0))
		if count <= 0:
			continue
		var row := Label.new()
		row.name = "OptionTallyRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = "#%d  %s  %d" % [added + 1, str(entry.get("label", "")), count]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.max_lines_visible = 2
		_style_label(row, _fitted_font_size(row.text, int(_layout_profile.get("choice_answer_font_size", _layout_profile.get("answer_font_size", 58))), _content_width(), 2, ANSWER_LABEL_MIN), colors.get("answer", Color.BLACK), true)
		list.add_child(row)
		_register_answer_node(row, "choice_tally")
		added += 1
		if added >= 5:
			break
	if added == 0:
		list.add_child(_large_text_answer_control("No tallied options yet", question_data, colors))
	return list

func _text_answer_tally_control(question_data: Dictionary, colors: Dictionary) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.name = "TextAnswerTallySummary"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", int(_layout_profile.get("text_answer_row_separation", 18)))
	var entries: Array = question_data.get("distinct_answer_tallies", [])
	if entries.is_empty():
		list.add_child(_large_text_answer_control(_text_answer_summary(question_data), question_data, colors))
		return list
	var display_count := mini(entries.size(), 3)
	for index in range(display_count):
		if entries[index] is Dictionary:
			list.add_child(_text_answer_tally_row(entries[index] as Dictionary, index + 1, colors))
	return list

func _text_answer_tally_row(entry: Dictionary, _rank_number: int, colors: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TextAnswerRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_layout_profile.get("respondent_inline_gap", 18)))
	var user_label := Label.new()
	user_label.name = "RespondentInlineLabel"
	user_label.text = _respondent_inline_label(entry)
	user_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	user_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	user_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	user_label.max_lines_visible = 1
	user_label.custom_minimum_size = Vector2(float(_layout_profile.get("respondent_inline_width", 236)), 48)
	var inline_font_size := int(_layout_profile.get("respondent_inline_font_size", _layout_profile.get("respondent_badge_font_size", 24)))
	var label_font := _fitted_font_size(user_label.text, inline_font_size, float(_layout_profile.get("respondent_inline_width", 236)) - 32.0, 1, 14)
	var label_color := _respondent_inline_color(entry, colors)
	user_label.add_theme_stylebox_override("normal", _soft_panel_style(label_color, true, 16, 6))
	_style_label(user_label, label_font, label_color, true)
	row.add_child(user_label)
	_register_answer_node(user_label, "respondent_inline_label")

	var answer := Label.new()
	answer.name = "DistinctAnswerText"
	answer.text = _limited_line(str(entry.get("text", "")).strip_edges(), 130)
	answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	answer.max_lines_visible = 3
	answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer.add_theme_constant_override("line_spacing", int(_layout_profile.get("line_spacing", 10)))
	var answer_width := _content_width() - float(_layout_profile.get("respondent_inline_width", 236)) - float(_layout_profile.get("respondent_inline_gap", 18))
	var font_size := _fitted_font_size(answer.text, int(_layout_profile.get("answer_font_size", 58)), answer_width, 3, ANSWER_FONT_MIN)
	_style_label(answer, font_size, colors.get("answer", Color.BLACK), true)
	row.add_child(answer)
	_register_answer_node(answer, "distinct_text_answer")
	return row

func _respondent_inline_label(entry: Dictionary) -> String:
	var respondents: Array = entry.get("respondents", [])
	if respondents.is_empty():
		return "User ?"
	var numbers: Array[String] = []
	for respondent_value in respondents:
		if not (respondent_value is Dictionary):
			continue
		var number := int((respondent_value as Dictionary).get("respondent_number", 0))
		numbers.append(str(number) if number > 0 else "?")
		if numbers.size() >= 3:
			break
	if numbers.is_empty():
		return "User ?"
	if respondents.size() == 1:
		return "User %s" % numbers[0]
	var label := "Users %s" % ", ".join(numbers)
	if respondents.size() > numbers.size():
		label += " +%d" % (respondents.size() - numbers.size())
	return label

func _respondent_inline_color(entry: Dictionary, colors: Dictionary) -> Color:
	for respondent_value in entry.get("respondents", []) as Array:
		if respondent_value is Dictionary:
			var color_text := str((respondent_value as Dictionary).get("respondent_color", "")).strip_edges()
			if not color_text.is_empty():
				return _color_from_value(color_text, colors.get("answer", Color.BLACK))
	return colors.get("prompt", Color.BLACK)

func _respondent_badge(text: String, color: Color, colors: Dictionary) -> Label:
	var badge := Label.new()
	badge.name = "RespondentBadge"
	badge.text = text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(74, 42)
	badge.add_theme_stylebox_override("normal", _soft_panel_style(color, true, 12, 6))
	_style_label(badge, int(_layout_profile.get("respondent_inline_font_size", _layout_profile.get("respondent_badge_font_size", 24))), color, true)
	_register_answer_node(badge, "respondent_badge")
	return badge

func _word_tally_summary_control(question_data: Dictionary, colors: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "WordTallySummary"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(_layout_profile.get("word_tally_column_gap", 30)))
	grid.add_theme_constant_override("v_separation", int(_layout_profile.get("word_tally_row_separation", 10)))
	var words: Array = question_data.get("word_tallies", [])
	var display_count := mini(words.size(), 12)
	for index in range(display_count):
		if not (words[index] is Dictionary):
			continue
		var entry: Dictionary = words[index] as Dictionary
		var label := Label.new()
		label.name = "WordTallyRow"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "#%d  %s  %d" % [index + 1, str(entry.get("word", "")), int(entry.get("count", 0))]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.max_lines_visible = 1
		var column_width := (_content_width() - float(_layout_profile.get("word_tally_column_gap", 30))) * 0.5
		var font_size := _fitted_font_size(label.text, int(_layout_profile.get("word_tally_font_size", _layout_profile.get("choice_answer_font_size", 58))), column_width, 1, ANSWER_LABEL_MIN)
		_style_label(label, font_size, colors.get("answer", Color.BLACK), true)
		grid.add_child(label)
		_register_answer_node(label, "word_tally")
	if display_count == 0:
		grid.add_child(_large_text_answer_control(str(question_data.get("summary_text", "No word tallies yet.")), question_data, colors))
	return grid

func _matrix_summary_control(question_data: Dictionary, colors: Dictionary) -> VBoxContainer:
	var matrix := VBoxContainer.new()
	matrix.name = "MatrixSummary"
	matrix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matrix.alignment = BoxContainer.ALIGNMENT_CENTER
	matrix.add_theme_constant_override("separation", int(_layout_profile.get("matrix_row_separation", 16)))
	var rows: Array = question_data.get("matrix_rows", [])
	if rows.is_empty():
		matrix.add_child(_large_text_answer_control(str(question_data.get("summary_text", "No matrix answers.")), question_data, colors))
		return matrix
	for index in range(rows.size()):
		var row_value: Variant = rows[index]
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value as Dictionary
		matrix.add_child(_matrix_row_control(row, colors, index + 1))
	return matrix

func _matrix_row_control(row: Dictionary, colors: Dictionary, row_number: int = 0) -> VBoxContainer:
	var row_stack := VBoxContainer.new()
	row_stack.name = "MatrixRow"
	row_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	row_stack.add_theme_constant_override("separation", int(_layout_profile.get("matrix_inner_separation", 8)))
	var row_label := Label.new()
	row_label.text = "%d. %s" % [row_number, str(row.get("row", ""))] if row_number > 0 else str(row.get("row", ""))
	row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row_label.max_lines_visible = 2
	_style_label(row_label, int(_layout_profile.get("matrix_row_label_font_size", 24)), colors.get("prompt", Color.BLACK), true)
	row_stack.add_child(row_label)
	_register_answer_node(row_label, "matrix_row_label")

	var summary := _matrix_row_summary(row)
	_matrix_row_count += 1
	_matrix_primary_answer_count += 1
	if bool(summary.get("is_tie", false)):
		_matrix_tie_state_count += 1
	_matrix_row_metrics.append(summary.duplicate(true))

	var chip := PanelContainer.new()
	chip.name = "MatrixPrimaryAnswer"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _soft_panel_style(colors.get("answer", Color.BLACK), true, 20, 13))
	row_stack.add_child(chip)

	var chip_stack := VBoxContainer.new()
	chip_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_stack.add_theme_constant_override("separation", 3)
	chip.add_child(chip_stack)

	var primary_label := Label.new()
	primary_label.name = "MatrixPrimaryAnswerLabel"
	primary_label.text = str(summary.get("primary_text", "No tally"))
	primary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	primary_label.max_lines_visible = 2
	var primary_font := _fitted_font_size(primary_label.text, int(_layout_profile.get("matrix_primary_font_size", 32)), _content_width() - 64.0, 2, ANSWER_LABEL_MIN)
	_style_label(primary_label, primary_font, colors.get("answer", Color.BLACK), true)
	chip_stack.add_child(primary_label)
	_register_answer_node(primary_label, "matrix_primary")

	var context_text := str(summary.get("context_text", "")).strip_edges()
	if not context_text.is_empty():
		var context_label := Label.new()
		context_label.name = "MatrixContextLabel"
		context_label.text = context_text
		context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		context_label.max_lines_visible = 2
		var context_font := _fitted_font_size(context_text, int(_layout_profile.get("matrix_context_font_size", 20)), _content_width() - 64.0, 2, 16)
		_style_label(context_label, context_font, colors.get("prompt", Color.BLACK), true)
		chip_stack.add_child(context_label)
		_register_answer_node(context_label, "matrix_context")
	return row_stack

func _ranked_summary_control(question_data: Dictionary, colors: Dictionary) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.name = "RankedSummary"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", int(_layout_profile.get("ranked_row_separation", 14)))
	var options: Array = question_data.get("ranked_options", [])
	if options.is_empty():
		list.add_child(_large_text_answer_control(str(question_data.get("summary_text", "No ranked answers.")), question_data, colors))
		return list
	var display_count := mini(options.size(), RANKED_OPTION_LIMIT)
	for index in range(display_count):
		if options[index] is Dictionary:
			list.add_child(_ranked_row_control(options[index] as Dictionary, index + 1, colors))
	return list

func _ranked_row_control(option: Dictionary, rank_number: int, colors: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "RankedRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_layout_profile.get("ranked_gap", 16)))
	var badge := Label.new()
	badge.text = "#%d" % rank_number
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(float(_layout_profile.get("rank_badge_width", 96)), 0.0)
	_style_label(badge, int(_layout_profile.get("rank_badge_font_size", 42)), colors.get("prompt", Color.BLACK), true)
	row.add_child(badge)
	_register_answer_node(badge, "rank_badge")
	var option_label := Label.new()
	option_label.text = str(option.get("option", ""))
	option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	option_label.max_lines_visible = 2
	option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(option_label, int(_layout_profile.get("answer_font_size", 58)), colors.get("answer", Color.BLACK), true)
	row.add_child(option_label)
	_register_answer_node(option_label, "rank_option")
	var meta := Label.new()
	meta.text = "avg %s | %d" % [str(option.get("average_rank", "")), int(option.get("sample_count", 0))]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.custom_minimum_size = Vector2(float(_layout_profile.get("rank_meta_width", 180)), 0.0)
	_style_label(meta, int(_layout_profile.get("rank_meta_font_size", 25)), colors.get("prompt", Color.BLACK), true)
	row.add_child(meta)
	_register_answer_node(meta, "rank_meta")
	return row

func _stat_line(value_text: String, label_text: String, colors: Dictionary) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.name = "Stat_%s" % label_text
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", int(_layout_profile.get("stat_inner_separation", 10)))
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.max_lines_visible = 1
	_style_label(value, _stat_value_font_size(value_text), colors.get("answer", Color.BLACK), true)
	stack.add_child(value)
	_register_answer_node(value, "stat_value")
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 1
	_style_label(label, _stat_label_font_size(label_text), colors.get("prompt", Color.BLACK), true)
	stack.add_child(label)
	_register_answer_node(label, "stat_label")
	return stack

func _footer_block(colors: Dictionary) -> Label:
	var footer := Label.new()
	var footer_parts: Array[String] = []
	if bool(_page_data.get("scrub_identifying_info", true)):
		footer_parts.append("Identifying-marked text hidden")
	var generated := str(_page_data.get("generated_at", "")).strip_edges()
	if not generated.is_empty():
		footer_parts.append("Generated %s" % generated)
	if footer_parts.is_empty():
		footer_parts.append("Wrapped export")
	footer.text = " | ".join(footer_parts)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.max_lines_visible = 2
	_style_label(footer, 18, colors.get("context_subtle", Color.BLACK))
	_register_context_node(footer, "footer")
	return footer

func _layout_profile_for_page() -> Dictionary:
	if str(_page_data.get("page_kind", PAGE_KIND_ANSWERS)) == PAGE_KIND_STATS:
		return _stats_layout_profile()
	return _answer_layout_profile()

func _answer_layout_profile() -> Dictionary:
	var questions: Array = _page_data.get("questions", [])
	var question_count := maxi(questions.size(), 1)
	var width := _content_width()
	var story_height := _story_height_budget(width)
	var min_font := ANSWER_FONT_MIN
	var max_font := _answer_font_max_for_questions(questions, question_count)
	var chosen := _profile_for_answer_font(min_font, question_count)
	var chose_fit := false
	var largest_story_fit: Dictionary = {}
	for font_size in range(max_font, min_font - 1, -2):
		var candidate := _profile_for_answer_font(font_size, question_count)
		var estimated_height := _estimate_answer_content_height(questions, width, candidate)
		var guarded_height := estimated_height * LAYOUT_ESTIMATE_SAFETY
		candidate["estimated_vital_height"] = guarded_height
		candidate["raw_estimated_vital_height"] = estimated_height
		candidate["estimated_fill_height_ratio"] = snappedf(guarded_height / maxf(story_height, 1.0), 0.001)
		candidate["estimated_overflow"] = guarded_height > story_height
		if guarded_height <= story_height and largest_story_fit.is_empty():
			largest_story_fit = candidate.duplicate(true)
		if guarded_height <= story_height and float(candidate.get("estimated_fill_height_ratio", 1.0)) <= STORY_MAX_FILL:
			chosen = candidate
			chose_fit = true
			break
	if not chose_fit and not largest_story_fit.is_empty():
		chosen = largest_story_fit
		chose_fit = true
	if not chose_fit:
		var overflow_height := _estimate_answer_content_height(questions, width, chosen)
		var guarded_overflow_height := overflow_height * LAYOUT_ESTIMATE_SAFETY
		chosen["estimated_vital_height"] = guarded_overflow_height
		chosen["raw_estimated_vital_height"] = overflow_height
		chosen["estimated_fill_height_ratio"] = snappedf(guarded_overflow_height / maxf(story_height, 1.0), 0.001)
		chosen["estimated_overflow"] = guarded_overflow_height > story_height
	chosen["story_target_fill"] = STORY_TARGET_FILL
	chosen["story_min_fill"] = STORY_MIN_FILL
	chosen["story_max_fill"] = STORY_MAX_FILL
	chosen["story_height_budget"] = story_height
	return chosen

func _stats_layout_profile() -> Dictionary:
	return {
		"question_count": 0,
		"answer_font_size": 210,
		"secondary_answer_font_size": 92,
		"prompt_font_size": 58,
		"line_spacing": 10,
		"block_separation": 0,
		"inner_separation": 18,
		"stat_value_font_size": 236,
		"stat_label_font_size": 64,
		"stat_separation": 108,
		"stat_inner_separation": 14,
		"story_target_fill": STORY_TARGET_FILL,
		"story_min_fill": STORY_MIN_FILL,
		"story_max_fill": STORY_MAX_FILL,
		"estimated_vital_height": 960.0,
		"estimated_fill_height_ratio": 0.68,
		"estimated_overflow": false
	}

func _profile_for_answer_font(answer_font_size: int, question_count: int) -> Dictionary:
	var prompt_cap := mini(PROMPT_FONT_MAX, int(floor(float(answer_font_size) * 0.45)))
	var prompt_font := clampi(int(round(float(answer_font_size) * 0.34)), PROMPT_FONT_MIN, maxi(prompt_cap, PROMPT_FONT_MIN))
	var secondary_font := clampi(int(round(float(answer_font_size) * 0.72)), 26, maxi(answer_font_size, 26))
	return {
		"question_count": question_count,
		"answer_font_size": answer_font_size,
		"secondary_answer_font_size": secondary_font,
		"prompt_font_size": prompt_font,
		"line_spacing": clampi(int(round(float(answer_font_size) * 0.12)), 6, 18),
		"block_separation": clampi(int(round(float(answer_font_size) * 0.62)), 26, 64),
		"inner_separation": clampi(int(round(float(answer_font_size) * 0.22)), 10, 28),
		"choice_answer_font_size": clampi(int(round(float(answer_font_size) * 0.88)), 28, maxi(answer_font_size, 28)),
		"choice_row_separation": clampi(int(round(float(answer_font_size) * 0.18)), 8, 20),
		"choice_gap": clampi(int(round(float(answer_font_size) * 0.32)), 16, 34),
		"text_answer_row_separation": clampi(int(round(float(answer_font_size) * 0.22)), 12, 28),
		"respondent_inline_font_size": clampi(int(round(float(answer_font_size) * 0.34)), 18, 32),
		"respondent_inline_width": clampf(float(answer_font_size) * 4.2, 220.0, 310.0),
		"respondent_inline_gap": clampi(int(round(float(answer_font_size) * 0.24)), 12, 28),
		"word_tally_font_size": clampi(int(round(float(answer_font_size) * 0.76)), 26, maxi(answer_font_size, 26)),
		"word_tally_row_separation": clampi(int(round(float(answer_font_size) * 0.16)), 8, 18),
		"word_tally_column_gap": clampi(int(round(float(answer_font_size) * 0.42)), 20, 42),
		"matrix_row_label_font_size": clampi(int(round(float(answer_font_size) * 0.42)), 18, 36),
		"matrix_primary_font_size": clampi(int(round(float(answer_font_size) * 0.56)), 24, 42),
		"matrix_context_font_size": clampi(int(round(float(answer_font_size) * 0.32)), 16, 24),
		"matrix_row_separation": clampi(int(round(float(answer_font_size) * 0.24)), 10, 24),
		"matrix_inner_separation": clampi(int(round(float(answer_font_size) * 0.12)), 6, 14),
		"rank_badge_font_size": clampi(int(round(float(answer_font_size) * 0.70)), 28, 68),
		"rank_meta_font_size": clampi(int(round(float(answer_font_size) * 0.34)), 18, 34),
		"rank_badge_width": clampf(float(answer_font_size) * 1.4, 74.0, 132.0),
		"rank_meta_width": clampf(float(answer_font_size) * 2.7, 130.0, 240.0),
		"ranked_row_separation": clampi(int(round(float(answer_font_size) * 0.22)), 10, 22),
		"ranked_gap": clampi(int(round(float(answer_font_size) * 0.24)), 12, 26)
	}

func _answer_font_max_for_questions(questions: Array, question_count: int) -> int:
	var cap := _answer_font_max_for_count(question_count)
	for question_value in questions:
		if not (question_value is Dictionary):
			continue
		match _answer_visual_kind(question_value as Dictionary):
			"matrix_summary":
				cap = mini(cap, 68)
			"ranked_summary":
				cap = mini(cap, 76)
			"option_tallies":
				cap = mini(cap, 92)
			"numeric_summary":
				cap = mini(cap, 112)
			"text_word_tallies":
				cap = mini(cap, 94)
			"text_individual_answers":
				cap = mini(cap, 112)
			"text_answer_tallies":
				cap = mini(cap, 96)
	return cap

func _answer_font_max_for_count(question_count: int) -> int:
	if question_count <= 1:
		return 132
	if question_count == 2:
		return 110
	if question_count == 3:
		return 94
	if question_count <= 5:
		return 78
	if question_count <= 7:
		return 66
	return 56

func _estimate_answer_content_height(questions: Array, width: float, profile: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for question_value in questions:
		if not (question_value is Dictionary):
			continue
		if count > 0:
			total += float(profile.get("block_separation", 44))
		total += _estimate_question_height(question_value as Dictionary, width, profile)
		count += 1
	return total

func _estimate_question_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var prompt_height := _estimate_text_height(_prompt_text(question_data), int(profile.get("prompt_font_size", 24)), width, 3)
	var answer_height := _estimate_answer_height(question_data, width, profile)
	return prompt_height + float(profile.get("inner_separation", 18)) + answer_height

func _estimate_answer_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	match _answer_visual_kind(question_data):
		"matrix_summary":
			return _estimate_matrix_height(question_data, width, profile)
		"ranked_summary":
			return _estimate_ranked_height(question_data, width, profile)
		"option_tallies":
			return _estimate_choice_height(question_data, width, profile)
		"numeric_summary":
			return _estimate_text_height(_numeric_answer_text(question_data), int(profile.get("answer_font_size", 58)), width, _answer_line_limit_for_profile(question_data, profile))
		"text_word_tallies":
			return _estimate_word_tally_height(question_data, width, profile)
		"text_individual_answers", "text_answer_tallies":
			return _estimate_text_tally_height(question_data, width, profile)
	return _estimate_text_height(_display_summary(question_data), int(profile.get("answer_font_size", 58)), width, _answer_line_limit_for_profile(question_data, profile))

func _estimate_choice_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var entries := _sorted_count_entries(question_data.get("option_counts", {}) as Dictionary)
	var row_count := 0
	for entry in entries:
		if int(entry.get("count", 0)) > 0:
			row_count += 1
		if row_count >= 5:
			break
	if row_count <= 0:
		row_count = 1
	var row_height := _estimate_text_height("Choice answer 99", int(profile.get("choice_answer_font_size", 58)), width, 2)
	return (row_height * float(row_count)) + (float(profile.get("choice_row_separation", 10)) * float(maxi(row_count - 1, 0)))

func _estimate_text_tally_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var entries: Array = question_data.get("distinct_answer_tallies", [])
	var row_count := clampi(entries.size(), 1, 3)
	var label_width := float(profile.get("respondent_inline_width", 236))
	var gap := float(profile.get("respondent_inline_gap", 18))
	var answer_width := maxf(width - label_width - gap, width * 0.55)
	var inline_font_size := int(profile.get("respondent_inline_font_size", profile.get("respondent_badge_font_size", 24)))
	var user_label_height := _estimate_text_height("Users 100, 99, 98 +97", inline_font_size, label_width, 1)
	var answer_height := _estimate_text_height("A distinct answer sample with readable wording", int(profile.get("answer_font_size", 58)), answer_width, 3)
	var row_height := maxf(user_label_height, answer_height)
	return (row_height * float(row_count)) + (float(profile.get("text_answer_row_separation", 18)) * float(maxi(row_count - 1, 0)))

func _estimate_word_tally_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var words: Array = question_data.get("word_tallies", [])
	var display_count := clampi(words.size(), 1, 12)
	var row_count := int(ceil(float(display_count) / 2.0))
	var column_width := (width - float(profile.get("word_tally_column_gap", 30))) * 0.5
	var row_height := _estimate_text_height("#12 answer 99", int(profile.get("word_tally_font_size", 48)), column_width, 1)
	return (row_height * float(row_count)) + (float(profile.get("word_tally_row_separation", 10)) * float(maxi(row_count - 1, 0)))

func _estimate_matrix_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var rows: Array = question_data.get("matrix_rows", [])
	var row_count := maxi(rows.size(), 1)
	var row_label_height := _estimate_text_height("Matrix row", int(profile.get("matrix_row_label_font_size", 24)), width, 2)
	var chip_width := maxf(width - 64.0, 1.0)
	var primary_height := _estimate_text_height("Selected answer 99", int(profile.get("matrix_primary_font_size", 32)), chip_width, 2)
	var context_height := _estimate_text_height("also: another answer 1", int(profile.get("matrix_context_font_size", 20)), chip_width, 2)
	var row_height := row_label_height + float(profile.get("matrix_inner_separation", 8)) + primary_height + context_height + 30.0
	return (row_height * float(row_count)) + (float(profile.get("matrix_row_separation", 16)) * float(maxi(row_count - 1, 0)))

func _estimate_ranked_height(question_data: Dictionary, width: float, profile: Dictionary) -> float:
	var options: Array = question_data.get("ranked_options", [])
	var row_count := clampi(options.size(), 1, RANKED_OPTION_LIMIT)
	var row_height := maxf(
		_estimate_text_height("Option", int(profile.get("answer_font_size", 58)), width, 2),
		_estimate_text_height("#1", int(profile.get("rank_badge_font_size", 42)), width, 1)
	) + 10.0
	return (row_height * float(row_count)) + (float(profile.get("ranked_row_separation", 14)) * float(maxi(row_count - 1, 0)))

func _estimate_text_height(text: String, font_size: int, width: float, max_lines: int) -> float:
	var measured := _measure_text_size(text, font_size, width, max_lines)
	return maxf(measured.y, float(font_size) * 1.18)

func _measure_text_size(text: String, font_size: int, width: float, max_lines: int = -1) -> Vector2:
	var clean := text.strip_edges()
	if clean.is_empty():
		clean = " "
	var font := get_theme_font("font")
	if font != null:
		return font.get_multiline_string_size(clean, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, max_lines)
	var character_width := maxf(float(font_size) * 0.56, 1.0)
	var lines := int(ceil((float(clean.length()) * character_width) / maxf(width, 1.0)))
	if max_lines > 0:
		lines = mini(lines, max_lines)
	return Vector2(minf(width, float(clean.length()) * character_width), float(maxi(lines, 1)) * float(font_size) * 1.2)

func _fitted_font_size(text: String, preferred_size: int, width: float, max_lines: int, min_size: int) -> int:
	var resolved_width := maxf(width, 1.0)
	var resolved_min := maxi(min_size, 8)
	var resolved_preferred := maxi(preferred_size, resolved_min)
	for font_size in range(resolved_preferred, resolved_min - 1, -1):
		var measured := _measure_text_size(text, font_size, resolved_width, max_lines)
		var max_height := float(font_size) * 1.28 * float(maxi(max_lines, 1))
		if measured.x <= resolved_width + 1.0 and measured.y <= max_height + 1.0 and _longest_word_width(text, font_size) <= resolved_width + 1.0:
			return font_size
	return resolved_min

func _longest_word_width(text: String, font_size: int) -> float:
	var longest := ""
	for part in text.replace("\n", " ").replace("\t", " ").split(" ", false):
		var word := str(part).strip_edges()
		if word.length() > longest.length():
			longest = word
	if longest.is_empty():
		return 0.0
	var font := get_theme_font("font")
	if font != null:
		return font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return float(longest.length()) * maxf(float(font_size) * 0.56, 1.0)

func _content_width() -> float:
	return float(PAGE_SIZE.x - CONTENT_MARGIN_LEFT - CONTENT_MARGIN_RIGHT)

func _story_height_budget(width: float) -> float:
	var header_height := _estimated_header_height(width)
	return maxf(1.0, float(PAGE_SIZE.y - CONTENT_MARGIN_TOP - CONTENT_MARGIN_BOTTOM) - header_height - 42.0)

func _estimated_header_height(width: float) -> float:
	var title_text := str(_page_data.get("title", _page_data.get("survey_title", "Survey"))).strip_edges()
	var height := _estimate_text_height(title_text, 29, width, 2)
	var subtitle_text := str(_page_data.get("subtitle", "")).strip_edges()
	if not subtitle_text.is_empty():
		height += 9.0 + _estimate_text_height(subtitle_text, 21, width, 2)
	return height

func _answer_line_limit_for_profile(question_data: Dictionary, profile: Dictionary = {}) -> int:
	var resolved_profile := profile if not profile.is_empty() else _layout_profile
	var question_count := int(resolved_profile.get("question_count", 1))
	match StringName(str(question_data.get("question_type", ""))):
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			return 9 if question_count <= 1 else (7 if question_count <= 3 else 4)
		SurveyQuestion.TYPE_MATRIX, SurveyQuestion.TYPE_RANKED_CHOICE:
			return 6 if question_count <= 2 else (5 if question_count <= 4 else 4)
	return 4 if question_count >= 5 else (5 if question_count >= 3 else 6)

func _answer_visual_kind(question_data: Dictionary) -> String:
	if bool(question_data.get("scrubbed", false)):
		return "text_samples"
	var explicit := str(question_data.get("wrapped_renderer", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	match StringName(str(question_data.get("question_type", ""))):
		SurveyQuestion.TYPE_MATRIX:
			return "matrix_summary"
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return "ranked_summary"
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			return "numeric_summary"
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_MULTI_CHOICE, SurveyQuestion.TYPE_DROPDOWN, SurveyQuestion.TYPE_BOOLEAN:
			return "option_tallies"
	return "text_samples"

func _numeric_answer_text(question_data: Dictionary) -> String:
	var stats: Dictionary = question_data.get("numeric_stats", {})
	if stats.is_empty():
		return str(question_data.get("summary_text", "No numeric answers."))
	var parts: Array[String] = [
		"Average %s" % str(stats.get("average", "")),
		"Range %s to %s" % [str(stats.get("min", "")), str(stats.get("max", ""))]
	]
	var entries := _sorted_count_entries(question_data.get("option_counts", {}) as Dictionary)
	var added := 0
	for entry in entries:
		var count := int(entry.get("count", 0))
		if count <= 0:
			continue
		parts.append("#%d  %s  %d" % [added + 1, str(entry.get("label", "")), count])
		added += 1
		if added >= 3:
			break
	return "\n".join(parts)

func _soft_panel_style(color: Color, highlighted: bool, horizontal_padding: int, vertical_padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.14 if highlighted else 0.055)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	return style

func _clear_layout_tracking() -> void:
	_header_node = null
	_answer_list_node = null
	_stats_stack_node = null
	_layout_profile.clear()
	_layout_metrics.clear()
	_vital_nodes.clear()
	_answer_nodes.clear()
	_prompt_nodes.clear()
	_tracked_labels.clear()
	_matrix_row_count = 0
	_matrix_primary_answer_count = 0
	_matrix_tie_state_count = 0
	_matrix_row_metrics.clear()

func _register_context_node(node: Control, role: String) -> void:
	if node == null:
		return
	_track_label(node, role, false)

func _register_prompt_node(node: Control, role: String = "prompt") -> void:
	if node == null:
		return
	_prompt_nodes.append(node)
	_vital_nodes.append(node)
	_track_label(node, role, true)

func _register_answer_node(node: Control, role: String = "answer") -> void:
	if node == null:
		return
	_answer_nodes.append(node)
	_vital_nodes.append(node)
	_track_label(node, role, true)

func _track_label(node: Control, role: String, vital: bool) -> void:
	if node == null or not (node is Label):
		return
	_tracked_labels.append({
		"node": node,
		"role": role,
		"vital": vital
	})

func _collect_layout_metrics() -> Dictionary:
	var safe_rect := _safe_story_rect()
	var vital_rect := _merged_local_rect(_vital_nodes)
	var answer_rect := _merged_local_rect(_answer_nodes)
	if vital_rect.size.y <= 0.0 and float(_layout_profile.get("estimated_vital_height", 0.0)) > 0.0:
		var fallback_height := float(_layout_profile.get("estimated_vital_height", 0.0))
		vital_rect = Rect2(safe_rect.position + Vector2(safe_rect.size.x * 0.12, maxf((safe_rect.size.y - fallback_height) * 0.5, 0.0)), Vector2(safe_rect.size.x * 0.76, fallback_height))
	if answer_rect.size.y <= 0.0:
		answer_rect = vital_rect
	var fill_height := snappedf(vital_rect.size.y / maxf(safe_rect.size.y, 1.0), 0.001)
	var fill_width := snappedf(vital_rect.size.x / maxf(safe_rect.size.x, 1.0), 0.001)
	var label_report := _collect_label_metrics(safe_rect)
	return {
		"page_number": int(_page_data.get("page_number", 1)),
		"page_kind": str(_page_data.get("page_kind", PAGE_KIND_ANSWERS)),
		"question_count": (_page_data.get("questions", []) as Array).size(),
		"safe_rect": _rect_to_dictionary(safe_rect),
		"vital_content_rect": _rect_to_dictionary(vital_rect),
		"answer_text_rect": _rect_to_dictionary(answer_rect),
		"fill_height_ratio": fill_height,
		"fill_width_ratio": fill_width,
		"target_fill_ratio": STORY_TARGET_FILL,
		"minimum_fill_ratio": STORY_MIN_FILL,
		"maximum_fill_ratio": STORY_MAX_FILL,
		"overflow": _rect_overflows(vital_rect, safe_rect),
		"text_overflow": bool(label_report.get("text_overflow", false)),
		"label_overflow_count": int(label_report.get("label_overflow_count", 0)),
		"longest_word_overflow": bool(label_report.get("longest_word_overflow", false)),
		"screenshot_text_overflow": bool(label_report.get("screenshot_text_overflow", false)),
		"label_metrics": label_report.get("labels", []),
		"answer_font_size": int(_layout_profile.get("answer_font_size", 0)),
		"secondary_answer_font_size": int(_layout_profile.get("secondary_answer_font_size", 0)),
		"prompt_font_size": int(_layout_profile.get("prompt_font_size", 0)),
		"renderer_kinds": _renderer_kinds_for_page(),
		"matrix_row_count": _matrix_row_count,
		"matrix_primary_answer_count": _matrix_primary_answer_count,
		"matrix_tie_state_count": _matrix_tie_state_count,
		"matrix_rows": _matrix_row_metrics.duplicate(true),
		"estimated_fill_height_ratio": float(_layout_profile.get("estimated_fill_height_ratio", 0.0)),
		"estimated_overflow": bool(_layout_profile.get("estimated_overflow", false))
	}

func _collect_label_metrics(safe_rect: Rect2) -> Dictionary:
	var page_rect := Rect2(Vector2.ZERO, Vector2(PAGE_SIZE))
	var labels: Array[Dictionary] = []
	var label_overflow_count := 0
	var text_overflow := false
	var longest_word_overflow := false
	var screenshot_text_overflow := false
	for entry in _tracked_labels:
		var label := entry.get("node", null) as Label
		if label == null or not label.is_inside_tree() or not label.visible:
			continue
		var role := str(entry.get("role", "label"))
		var vital := bool(entry.get("vital", false))
		var rect := _local_rect_for(label)
		var font_size := _label_font_size(label)
		var max_lines := int(label.max_lines_visible)
		var measured := _measure_text_size(label.text, font_size, maxf(rect.size.x, 1.0), max_lines)
		var longest_word := _longest_word_width(label.text, font_size)
		var measured_overflow := measured.x > rect.size.x + 1.0 or measured.y > rect.size.y + 1.0
		var longest_overflow := longest_word > rect.size.x + 1.0
		var screenshot_overflow := _rect_overflows(rect, page_rect)
		var safe_overflow := vital and _rect_overflows(rect, safe_rect)
		var overflows := measured_overflow or longest_overflow or screenshot_overflow or safe_overflow
		if overflows:
			label_overflow_count += 1
		text_overflow = text_overflow or measured_overflow or safe_overflow
		longest_word_overflow = longest_word_overflow or longest_overflow
		screenshot_text_overflow = screenshot_text_overflow or screenshot_overflow
		labels.append({
			"role": role,
			"node_name": label.name,
			"vital": vital,
			"text_preview": _limited_line(label.text, 96),
			"text_length": label.text.length(),
			"allocated_rect": _rect_to_dictionary(rect),
			"measured_text_size": _size_to_dictionary(measured),
			"font_size": font_size,
			"max_lines": max_lines,
			"longest_word_width": snappedf(longest_word, 0.01),
			"text_overflow": measured_overflow,
			"safe_overflow": safe_overflow,
			"screenshot_overflow": screenshot_overflow,
			"longest_word_overflow": longest_overflow
		})
	return {
		"labels": labels,
		"label_overflow_count": label_overflow_count,
		"text_overflow": text_overflow,
		"longest_word_overflow": longest_word_overflow,
		"screenshot_text_overflow": screenshot_text_overflow
	}

func _label_font_size(label: Label) -> int:
	var font_size := label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 16
	return font_size

func _renderer_kinds_for_page() -> Array[String]:
	var kinds: Array[String] = []
	for question_value in _page_data.get("questions", []) as Array:
		if question_value is Dictionary:
			var kind := _answer_visual_kind(question_value as Dictionary)
			if not kinds.has(kind):
				kinds.append(kind)
	return kinds

func _safe_story_rect() -> Rect2:
	var top := float(CONTENT_MARGIN_TOP)
	if _header_node != null and _header_node.is_inside_tree():
		var header_rect := _local_rect_for(_header_node)
		if header_rect.size.y > 0.0:
			top = maxf(top, header_rect.position.y + header_rect.size.y + 42.0)
	else:
		top += _estimated_header_height(_content_width()) + 42.0
	var bottom := float(PAGE_SIZE.y - CONTENT_MARGIN_BOTTOM)
	var height := maxf(1.0, bottom - top)
	return Rect2(float(CONTENT_MARGIN_LEFT), top, _content_width(), height)

func _merged_local_rect(nodes: Array[Control]) -> Rect2:
	var merged := Rect2()
	var has_rect := false
	for node in nodes:
		if node == null or not node.is_inside_tree() or not node.visible:
			continue
		var rect := _local_rect_for(node)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if has_rect:
			merged = merged.merge(rect)
		else:
			merged = rect
			has_rect = true
	return merged if has_rect else Rect2()

func _local_rect_for(node: Control) -> Rect2:
	var root_rect := get_global_rect()
	var rect := node.get_global_rect()
	return Rect2(rect.position - root_rect.position, rect.size)

func _rect_overflows(rect: Rect2, safe_rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var epsilon := 1.0
	return rect.position.x < safe_rect.position.x - epsilon \
		or rect.position.y < safe_rect.position.y - epsilon \
		or rect.position.x + rect.size.x > safe_rect.position.x + safe_rect.size.x + epsilon \
		or rect.position.y + rect.size.y > safe_rect.position.y + safe_rect.size.y + epsilon

func _rect_to_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": snappedf(rect.position.x, 0.01),
		"y": snappedf(rect.position.y, 0.01),
		"width": snappedf(rect.size.x, 0.01),
		"height": snappedf(rect.size.y, 0.01)
	}

func _size_to_dictionary(value: Vector2) -> Dictionary:
	return {
		"width": snappedf(value.x, 0.01),
		"height": snappedf(value.y, 0.01)
	}

func _prompt_text(question_data: Dictionary) -> String:
	var text := str(question_data.get("prompt", "Question")).strip_edges()
	var part_count := int(question_data.get("wrap_part_count", 1))
	if part_count > 1:
		text += " | answers %d of %d" % [int(question_data.get("wrap_part_number", 1)), part_count]
	return text

func _display_summary(question_data: Dictionary) -> String:
	if bool(question_data.get("scrubbed", false)):
		return "Hidden for sharing"
	var question_type := StringName(str(question_data.get("question_type", "")))
	match question_type:
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			return _text_answer_summary(question_data)
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			var stats: Dictionary = question_data.get("numeric_stats", {})
			if stats.is_empty():
				return str(question_data.get("summary_text", "No numeric answers."))
			return "Average %s\nRange %s to %s" % [str(stats.get("average", "")), str(stats.get("min", "")), str(stats.get("max", ""))]
		SurveyQuestion.TYPE_MATRIX:
			var row_parts: Array[String] = []
			for row_value in question_data.get("matrix_rows", []) as Array:
				if row_value is Dictionary:
					var row: Dictionary = row_value as Dictionary
					row_parts.append("%s: %s" % [str(row.get("row", "")), _top_count(row.get("option_counts", {}) as Dictionary)])
			return "\n".join(row_parts) if not row_parts.is_empty() else str(question_data.get("summary_text", "No matrix answers."))
		SurveyQuestion.TYPE_RANKED_CHOICE:
			var ranked_parts: Array[String] = []
			for option_value in question_data.get("ranked_options", []) as Array:
				if option_value is Dictionary:
					ranked_parts.append("%s avg %s" % [str((option_value as Dictionary).get("option", "")), str((option_value as Dictionary).get("average_rank", ""))])
			return "\n".join(ranked_parts) if not ranked_parts.is_empty() else str(question_data.get("summary_text", "No ranked answers."))
	return _top_counts(question_data.get("option_counts", {}) as Dictionary)

func _text_answer_summary(question_data: Dictionary) -> String:
	var renderer := _answer_visual_kind(question_data)
	if renderer == "text_word_tallies":
		var word_parts: Array[String] = []
		for entry_value in question_data.get("word_tallies", []) as Array:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value as Dictionary
				word_parts.append("#%d %s %d" % [int(entry.get("rank", word_parts.size() + 1)), str(entry.get("word", "")), int(entry.get("count", 0))])
			if word_parts.size() >= 12:
				break
		return "\n".join(word_parts) if not word_parts.is_empty() else str(question_data.get("summary_text", "No word tallies."))
	if renderer in ["text_individual_answers", "text_answer_tallies"]:
		var answer_parts: Array[String] = []
		for entry_value in question_data.get("distinct_answer_tallies", []) as Array:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value as Dictionary
				answer_parts.append("#%d %s" % [int(entry.get("rank", answer_parts.size() + 1)), _limited_line(str(entry.get("text", "")), 96)])
			if answer_parts.size() >= 3:
				break
		if not answer_parts.is_empty():
			return "\n".join(answer_parts)
	var samples: Array = question_data.get("text_samples", [])
	if samples.is_empty():
		samples = question_data.get("text_answers", [])
	if samples.is_empty():
		return str(question_data.get("summary_text", "No text answers."))
	var parts: Array[String] = []
	for sample_value in samples:
		if sample_value is Dictionary:
			parts.append(_limited_line(str((sample_value as Dictionary).get("text", "")).strip_edges(), 96))
		elif typeof(sample_value) != TYPE_NIL:
			parts.append(_limited_line(str(sample_value).strip_edges(), 96))
		if parts.size() >= 5:
			break
	return "\n".join(parts)

func _top_counts(counts: Dictionary) -> String:
	var entries := _sorted_count_entries(counts)
	var parts: Array[String] = []
	for entry in entries:
		if int(entry.get("count", 0)) <= 0:
			continue
		parts.append("%s  %d" % [str(entry.get("label", "")), int(entry.get("count", 0))])
		if parts.size() >= 5:
			break
	return "\n".join(parts) if not parts.is_empty() else "No tallied options yet"

func _top_count(counts: Dictionary) -> String:
	var entries := _sorted_count_entries(counts)
	for entry in entries:
		if int(entry.get("count", 0)) > 0:
			return "%s (%d)" % [str(entry.get("label", "")), int(entry.get("count", 0))]
	return "No tally"

func _matrix_row_summary(row: Dictionary) -> Dictionary:
	var entries := _positive_count_entries(row.get("option_counts", {}) as Dictionary)
	var row_name := str(row.get("row", "")).strip_edges()
	if entries.is_empty():
		return {
			"row": row_name,
			"primary_text": "No tally",
			"context_text": "",
			"is_tie": false,
			"top_count": 0,
			"also_count": 0
		}
	var top_count := int((entries[0] as Dictionary).get("count", 0))
	var top_labels: Array[String] = []
	var also_parts: Array[String] = []
	for entry in entries:
		var label := str(entry.get("label", ""))
		var count := int(entry.get("count", 0))
		if count == top_count:
			top_labels.append(label)
		else:
			also_parts.append("%s %d" % [label, count])
	var is_tie := top_labels.size() > 1
	var primary_text := ""
	var context_text := ""
	if is_tie:
		primary_text = "Tie: %s" % " / ".join(top_labels)
		context_text = "%d each" % top_count
	else:
		primary_text = "%s  %d" % [top_labels[0], top_count]
	if not also_parts.is_empty():
		context_text = "%s%salso: %s" % [context_text, " | " if not context_text.is_empty() else "", ", ".join(also_parts)]
	return {
		"row": row_name,
		"primary_text": primary_text,
		"context_text": context_text,
		"is_tie": is_tie,
		"top_count": top_count,
		"also_count": also_parts.size()
	}

func _positive_count_entries(counts: Dictionary) -> Array[Dictionary]:
	var entries := _sorted_count_entries(counts)
	var positives: Array[Dictionary] = []
	for entry in entries:
		if int(entry.get("count", 0)) > 0:
			positives.append(entry)
	return positives

func _sorted_count_entries(counts: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key in counts.keys():
		entries.append({"label": str(key), "count": int(counts.get(key, 0))})
	entries.sort_custom(Callable(self, "_sort_count_entries"))
	return entries

func _sort_count_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("label", "")) < str(right.get("label", ""))

func _answer_line_limit(question_data: Dictionary, question_count: int) -> int:
	match StringName(str(question_data.get("question_type", ""))):
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			return 7 if question_count <= 1 else (5 if question_count <= 3 else 3)
		SurveyQuestion.TYPE_MATRIX, SurveyQuestion.TYPE_RANKED_CHOICE:
			return 5 if question_count <= 2 else (4 if question_count <= 4 else 3)
	return 3 if question_count >= 5 else (4 if question_count >= 3 else 5)

func _prompt_font_size(question_count: int) -> int:
	if question_count >= 6:
		return 18
	if question_count >= 4:
		return 20
	return 23

func _answer_font_size(question_data: Dictionary, answer_text: String, question_count: int) -> int:
	var line_count := answer_text.count("\n") + 1
	var size := 58
	if question_count == 2:
		size = 50
	elif question_count == 3:
		size = 43
	elif question_count == 4:
		size = 38
	elif question_count >= 5:
		size = 34
	if line_count >= 5:
		size -= 7
	elif line_count >= 3:
		size -= 3
	match StringName(str(question_data.get("question_type", ""))):
		SurveyQuestion.TYPE_MATRIX, SurveyQuestion.TYPE_RANKED_CHOICE:
			size = mini(size, 42)
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			size = mini(size, 46)
	return maxi(size, 30)

func _stat_value_font_size(value_text: String) -> int:
	var configured := int(_layout_profile.get("stat_value_font_size", 0))
	if configured > 0:
		var length_for_configured := value_text.strip_edges().length()
		if length_for_configured >= 8:
			return int(round(float(configured) * 0.72))
		if length_for_configured >= 5:
			return int(round(float(configured) * 0.84))
		return configured
	var length := value_text.strip_edges().length()
	if length >= 8:
		return 126
	if length >= 5:
		return 144
	return 168

func _stat_label_font_size(label_text: String) -> int:
	var configured := int(_layout_profile.get("stat_label_font_size", 0))
	if configured > 0:
		return configured if label_text.strip_edges().length() <= 12 else int(round(float(configured) * 0.86))
	return 44 if label_text.strip_edges().length() <= 12 else 38

func _legacy_summary_page(summary_data: Dictionary) -> Dictionary:
	var first_section: Dictionary = {}
	for section_value in summary_data.get("sections", []) as Array:
		if section_value is Dictionary:
			first_section = section_value as Dictionary
			break
	return {
		"page_kind": PAGE_KIND_ANSWERS,
		"title": str(summary_data.get("survey_title", "Survey")),
		"subtitle": str(first_section.get("title", summary_data.get("survey_subtitle", ""))),
		"survey_title": str(summary_data.get("survey_title", "Survey")),
		"survey_subtitle": str(summary_data.get("survey_subtitle", "")),
		"generated_at": str(summary_data.get("generated_at", "")),
		"scrub_identifying_info": bool(summary_data.get("scrub_identifying_info", true)),
		"respondent_count": int(summary_data.get("respondent_count", 0)),
		"answered_response_total": int(summary_data.get("answered_response_total", 0)),
		"total_question_count": int(summary_data.get("total_question_count", 0)),
		"theme_id": str(summary_data.get("theme_id", THEME_LIGHT)),
		"share_profile": summary_data.get("share_profile", {}),
		"section_number": int(first_section.get("section_number", 0)),
		"section_title": str(first_section.get("title", "Results")),
		"section_part_number": 1,
		"section_part_count": 1,
		"page_number": 1,
		"page_count": 1,
		"questions": first_section.get("questions", []),
		"page_width": PAGE_SIZE.x,
		"page_height": PAGE_SIZE.y
	}

func _palette() -> Dictionary:
	var default_start := Color("061018") if _theme_id == THEME_DARK else Color("ffffff")
	var default_middle := Color("0d1b2d") if _theme_id == THEME_DARK else Color("f8fbff")
	var default_end := Color("172235") if _theme_id == THEME_DARK else Color("e7f2ff")
	var gradient: Dictionary = _page_data.get("background_gradient", {}) as Dictionary if _page_data.get("background_gradient", {}) is Dictionary else {}
	var start := _color_from_value(gradient.get("start", ""), default_start)
	var middle := _color_from_value(gradient.get("middle", ""), default_middle)
	var end := _color_from_value(gradient.get("end", ""), default_end)
	if _theme_id == THEME_DARK:
		return {
			"background_start": start,
			"background_middle": middle,
			"background_end": end,
			"answer": Color("f7fbff"),
			"prompt": Color(0.78, 0.86, 0.94, 0.58),
			"context": Color(0.78, 0.88, 0.96, 0.58),
			"context_subtle": Color(0.72, 0.82, 0.91, 0.46)
		}
	return {
		"background_start": start,
		"background_middle": middle,
		"background_end": end,
		"answer": Color("081521"),
		"prompt": Color(0.08, 0.15, 0.22, 0.52),
		"context": Color(0.10, 0.18, 0.26, 0.56),
		"context_subtle": Color(0.12, 0.22, 0.32, 0.44)
	}

func _color_from_value(value: Variant, fallback: Color) -> Color:
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	return Color(text)

func _style_label(label: Label, font_size: int, color: Color, bold: bool = false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if bold:
		label.add_theme_constant_override("outline_size", 0)

func _limited_line(text: String, limit: int) -> String:
	var clean := text.replace("\t", " ")
	clean = " ".join(clean.split("\n", false))
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	if clean.length() <= limit:
		return clean
	return "%s..." % clean.substr(0, maxi(limit - 3, 0))

func _normalized_theme(theme_id: String) -> String:
	return THEME_DARK if theme_id.strip_edges().to_lower() == THEME_DARK else THEME_LIGHT

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
