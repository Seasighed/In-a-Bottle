class_name SurveyQuestion
extends RefCounted

const SCALE_CHIPS_VIEW_SCENE := preload("res://Scenes/QuestionViews/ScaleChipQuestionView.tscn")
const RANKED_CHOICE_VIEW_SCENE := preload("res://Scenes/QuestionViews/RankedChoiceQuestionView.tscn")
const MATRIX_VIEW_SCENE := preload("res://Scenes/QuestionViews/MatrixQuestionView.tscn")

const TYPE_SHORT_TEXT := &"short_text"
const TYPE_LONG_TEXT := &"long_text"
const TYPE_SINGLE_CHOICE := &"single_choice"
const TYPE_MULTI_CHOICE := &"multi_choice"
const TYPE_BOOLEAN := &"boolean"
const TYPE_SCALE := &"scale"
const TYPE_RANKED_CHOICE := &"ranked_choice"
const TYPE_DROPDOWN := &"dropdown"
const TYPE_EMAIL := &"email"
const TYPE_NUMBER := &"number"
const TYPE_DATE := &"date"
const TYPE_NPS := &"nps"
const TYPE_MATRIX := &"matrix"
const ANSWER_STATE_UNANSWERED := &"unanswered"
const ANSWER_STATE_PARTIAL := &"partial"
const ANSWER_STATE_COMPLETE := &"complete"

var id: String
var prompt: String
var description: String
var type: StringName
var required: bool
var placeholder: String
var options: PackedStringArray
var rows: PackedStringArray
var topic_tags: PackedStringArray
var keywords: PackedStringArray
var audience_tags: PackedStringArray
var min_value: int
var max_value: int
var step: float
var left_label: String
var right_label: String
var default_value: Variant
var custom_view_scene: PackedScene
var emoji: String
var rating_enabled: bool
var rating_reverse: bool
var rating_weight: float
var rating_label: String
var rating_option_scores: Dictionary
var help_markdown: String

func _init(config: Dictionary = {}) -> void:
	id = str(config.get("id", ""))
	prompt = str(config.get("prompt", config.get("title", "Untitled question")))
	description = str(config.get("description", config.get("help_text", "")))
	help_markdown = str(config.get("help_markdown", config.get("details_markdown", config.get("markdown", config.get("question_help_markdown", "")))))
	type = _normalize_type(str(config.get("type", TYPE_SHORT_TEXT)))
	required = bool(config.get("required", false))
	placeholder = str(config.get("placeholder", ""))
	options = PackedStringArray(config.get("options", config.get("choices", PackedStringArray())))
	rows = PackedStringArray(config.get("rows", config.get("statements", PackedStringArray())))
	topic_tags = _string_array_from_variant(config.get("topic_tags", config.get("tags", PackedStringArray())))
	keywords = _string_array_from_variant(config.get("keywords", PackedStringArray()))
	audience_tags = _string_array_from_variant(config.get("audience_tags", config.get("audiences", PackedStringArray())))
	min_value = int(config.get("min_value", _default_min_value(type)))
	max_value = int(config.get("max_value", _default_max_value(type)))
	step = float(config.get("step", 1.0))
	left_label = str(config.get("left_label", ""))
	right_label = str(config.get("right_label", ""))
	default_value = config.get("default_value", null)
	emoji = str(config.get("emoji", config.get("prompt_emoji", ""))).strip_edges()
	custom_view_scene = config.get("custom_view_scene", null)
	if custom_view_scene == null:
		custom_view_scene = _resolve_view_template(str(config.get("view_template", config.get("template", ""))))

	var rating_config: Dictionary = _dictionary_from_variant(config.get("rating", {}))
	rating_enabled = bool(rating_config.get("enabled", config.get("rating_enabled", _default_rating_enabled(type))))
	rating_reverse = bool(rating_config.get("reverse", config.get("rating_reverse", false)))
	rating_weight = maxf(float(rating_config.get("weight", config.get("rating_weight", 1.0))), 0.0)
	rating_label = str(rating_config.get("label", config.get("rating_label", ""))).strip_edges()
	rating_option_scores = _normalize_option_scores(rating_config.get("option_scores", config.get("rating_option_scores", {})))

func resolved_emoji() -> String:
	if not emoji.is_empty():
		return emoji
	match type:
		TYPE_SHORT_TEXT, TYPE_LONG_TEXT:
			return "✍️"
		TYPE_EMAIL:
			return "✉️"
		TYPE_DATE:
			return "📅"
		TYPE_NUMBER:
			return "🔢"
		TYPE_SINGLE_CHOICE, TYPE_DROPDOWN, TYPE_BOOLEAN:
			return "🔘"
		TYPE_MULTI_CHOICE:
			return "☑️"
		TYPE_SCALE, TYPE_NPS:
			return "📊"
		TYPE_RANKED_CHOICE:
			return "🏁"
		TYPE_MATRIX:
			return "🧭"
	return "❓"

func display_prompt() -> String:
	var visible_prompt: String = prompt.strip_edges()
	var resolved_emoji_value: String = resolved_emoji()
	if not resolved_emoji_value.is_empty():
		visible_prompt = "%s %s" % [resolved_emoji_value, visible_prompt]
	return visible_prompt

func display_title(index: int) -> String:
	return "%d. %s" % [index + 1, display_prompt()]

func rating_display_label(index: int = -1) -> String:
	if not rating_label.is_empty():
		return rating_label
	if index >= 0:
		return "Question %d" % [index + 1]
	return prompt.strip_edges()

func display_type_label() -> String:
	match type:
		TYPE_SHORT_TEXT:
			return "Typed Answer"
		TYPE_LONG_TEXT:
			return "Long Answer"
		TYPE_SINGLE_CHOICE:
			return "Single Choice"
		TYPE_MULTI_CHOICE:
			return "Multi Choice"
		TYPE_BOOLEAN:
			return "Yes / No"
		TYPE_SCALE:
			return "Scale"
		TYPE_RANKED_CHOICE:
			return "Ranked Choice"
		TYPE_DROPDOWN:
			return "Dropdown"
		TYPE_EMAIL:
			return "Email"
		TYPE_NUMBER:
			return "Number"
		TYPE_DATE:
			return "Date"
		TYPE_NPS:
			return "0-10 Score"
		TYPE_MATRIX:
			return "Matrix"
	return "Question"

func accent_label(show_debug_id: bool = false) -> String:
	if show_debug_id and not id.strip_edges().is_empty():
		return id.strip_edges()
	return display_type_label()

func help_markdown_text() -> String:
	if not help_markdown.strip_edges().is_empty():
		return help_markdown
	if not description.strip_edges().is_empty():
		return description
	return "No additional notes were provided for this question."

func is_answer_complete(value: Variant) -> bool:
	return not is_answer_empty(value)

func answer_completion_state(value: Variant) -> StringName:
	if is_answer_complete(value):
		return ANSWER_STATE_COMPLETE
	if _has_partial_answer(value):
		return ANSWER_STATE_PARTIAL
	return ANSWER_STATE_UNANSWERED

func is_answer_empty(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value).strip_edges().is_empty()
		TYPE_ARRAY:
			var items := value as Array
			if type == TYPE_RANKED_CHOICE and not options.is_empty():
				return items.size() < options.size()
			return items.is_empty()
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			if dict.is_empty():
				return true
			if type == TYPE_MATRIX and not rows.is_empty():
				for row_name in rows:
					if str(dict.get(row_name, "")).strip_edges().is_empty():
						return true
				return false
			for nested_value in dict.values():
				if not _variant_is_blank(nested_value):
					return false
			return true
	return false

func _has_partial_answer(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(value).strip_edges().is_empty()
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return true
		TYPE_ARRAY:
			var items := value as Array
			if items.is_empty():
				return false
			if type == TYPE_RANKED_CHOICE and not options.is_empty():
				return items.size() < options.size()
			return false
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			if dict.is_empty():
				return false
			if type == TYPE_MATRIX and not rows.is_empty():
				var answered_rows := 0
				for row_name in rows:
					if not str(dict.get(row_name, "")).strip_edges().is_empty():
						answered_rows += 1
				return answered_rows > 0 and answered_rows < rows.size()
			for nested_value in dict.values():
				if not _variant_is_blank(nested_value):
					return true
			return false
	return false

func searchable_text() -> String:
	var parts: Array[String] = [prompt, description]
	if not options.is_empty():
		parts.append(" ".join(options))
	if not rows.is_empty():
		parts.append(" ".join(rows))
	if not topic_tags.is_empty():
		parts.append(" ".join(topic_tags))
	if not keywords.is_empty():
		parts.append(" ".join(keywords))
	if not audience_tags.is_empty():
		parts.append(" ".join(audience_tags))
	return " ".join(parts).strip_edges()

func has_topic_tag(tag: String) -> bool:
	return _matches_tag_list(topic_tags, tag)

func has_keyword(keyword: String) -> bool:
	return _matches_tag_list(keywords, keyword)

func has_audience_tag(tag: String) -> bool:
	return _matches_tag_list(audience_tags, tag)

func is_rating_question() -> bool:
	if not rating_enabled:
		return false
	match type:
		TYPE_SCALE, TYPE_NPS, TYPE_BOOLEAN, TYPE_NUMBER, TYPE_SINGLE_CHOICE, TYPE_DROPDOWN, TYPE_MATRIX:
			return true
		TYPE_MULTI_CHOICE, TYPE_RANKED_CHOICE:
			return not rating_option_scores.is_empty()
	return false

func answer_score_percent(value: Variant) -> float:
	var ratio: float = answer_score_ratio(value)
	if ratio < 0.0:
		return -1.0
	return clampf(ratio * 100.0, 0.0, 100.0)

func answer_score_ratio(value: Variant) -> float:
	if not is_rating_question() or is_answer_empty(value):
		return -1.0
	var ratio: float = _score_ratio_for_answer(value)
	if ratio < 0.0:
		return -1.0
	if rating_reverse:
		ratio = 1.0 - ratio
	return clampf(ratio, 0.0, 1.0)

func _score_ratio_for_answer(value: Variant) -> float:
	match type:
		TYPE_SCALE, TYPE_NPS, TYPE_NUMBER:
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return _normalize_numeric_score(float(value), float(min_value), float(max_value))
		TYPE_BOOLEAN:
			if typeof(value) == TYPE_BOOL:
				if not rating_option_scores.is_empty():
					var explicit_key: String = "true" if bool(value) else "false"
					var explicit_score: float = _normalized_score_from_explicit_map(explicit_key)
					if explicit_score < 0.0:
						explicit_score = _normalized_score_from_explicit_map("yes" if bool(value) else "no")
					return explicit_score
				return 1.0 if bool(value) else 0.0
		TYPE_SINGLE_CHOICE, TYPE_DROPDOWN:
			return _score_ratio_for_choice(str(value))
		TYPE_MULTI_CHOICE:
			if value is Array:
				return _score_ratio_for_multi_choice(value as Array)
		TYPE_RANKED_CHOICE:
			if value is Array:
				return _score_ratio_for_ranked_choice(value as Array)
		TYPE_MATRIX:
			if value is Dictionary:
				return _score_ratio_for_matrix(value as Dictionary)
	return -1.0

func _score_ratio_for_choice(selection: String) -> float:
	var normalized_selection: String = selection.strip_edges()
	if normalized_selection.is_empty():
		return -1.0
	if not rating_option_scores.is_empty():
		return _normalized_score_from_explicit_map(normalized_selection)
	if options.is_empty():
		return -1.0
	var option_index: int = options.find(normalized_selection)
	if option_index == -1:
		return -1.0
	if options.size() == 1:
		return 1.0
	return float(option_index) / float(options.size() - 1)

func _score_ratio_for_multi_choice(values: Array) -> float:
	if rating_option_scores.is_empty():
		return -1.0
	var samples: Array[float] = []
	for item in values:
		var item_score: float = _normalized_score_from_explicit_map(str(item))
		if item_score >= 0.0:
			samples.append(item_score)
	return _average_scores(samples)

func _score_ratio_for_ranked_choice(values: Array) -> float:
	if rating_option_scores.is_empty():
		return -1.0
	var weighted_total := 0.0
	var total_weight := 0.0
	for index in range(values.size()):
		var item_score: float = _normalized_score_from_explicit_map(str(values[index]))
		if item_score < 0.0:
			continue
		var weight: float = float(values.size() - index)
		weighted_total += item_score * weight
		total_weight += weight
	if total_weight <= 0.0:
		return -1.0
	return weighted_total / total_weight

func _score_ratio_for_matrix(values: Dictionary) -> float:
	var samples: Array[float] = []
	for row_name in rows:
		var selection: String = str(values.get(row_name, "")).strip_edges()
		if selection.is_empty():
			continue
		var row_score: float = _score_ratio_for_choice(selection)
		if row_score >= 0.0:
			samples.append(row_score)
	return _average_scores(samples)

func _average_scores(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())

func _normalized_score_from_explicit_map(raw_key: String) -> float:
	if rating_option_scores.is_empty():
		return -1.0
	var normalized_key: String = _normalize_rating_key(raw_key)
	if normalized_key.is_empty() or not rating_option_scores.has(normalized_key):
		return -1.0
	var min_score := INF
	var max_score := -INF
	for key in rating_option_scores.keys():
		var score_value: float = float(rating_option_scores[key])
		min_score = minf(min_score, score_value)
		max_score = maxf(max_score, score_value)
	if min_score == INF or max_score == -INF:
		return -1.0
	if is_equal_approx(max_score, min_score):
		return 1.0
	var selected_score: float = float(rating_option_scores.get(normalized_key, min_score))
	return clampf((selected_score - min_score) / (max_score - min_score), 0.0, 1.0)

func _normalize_numeric_score(raw_value: float, min_score: float, max_score: float) -> float:
	if max_score < min_score:
		var swap: float = min_score
		min_score = max_score
		max_score = swap
	if is_equal_approx(max_score, min_score):
		return 1.0
	return clampf((raw_value - min_score) / (max_score - min_score), 0.0, 1.0)

func _variant_is_blank(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return true
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value).strip_edges().is_empty()
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
	return false

func _matches_tag_list(values: PackedStringArray, query: String) -> bool:
	var normalized_query: String = _normalize_tag(query)
	if normalized_query.is_empty():
		return false
	for value in values:
		if _normalize_tag(value) == normalized_query:
			return true
	return false

func _string_array_from_variant(value: Variant) -> PackedStringArray:
	var resolved: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				resolved.append(text)
		return resolved
	if value is Array:
		var values: Array = value as Array
		for item in values:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				resolved.append(text)
	return resolved

func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _normalize_option_scores(value: Variant) -> Dictionary:
	var source: Dictionary = _dictionary_from_variant(value)
	var resolved: Dictionary = {}
	for key in source.keys():
		var normalized_key: String = _normalize_rating_key(str(key))
		if normalized_key.is_empty():
			continue
		var raw_score: Variant = source.get(key)
		match typeof(raw_score):
			TYPE_INT, TYPE_FLOAT:
				resolved[normalized_key] = float(raw_score)
			TYPE_STRING, TYPE_STRING_NAME:
				var score_text: String = str(raw_score).strip_edges()
				if score_text.is_valid_int() or score_text.is_valid_float():
					resolved[normalized_key] = float(score_text)
	return resolved

func _normalize_tag(raw_value: String) -> String:
	return raw_value.to_lower().strip_edges().replace("-", "_").replace(" ", "_")

func _normalize_rating_key(raw_value: String) -> String:
	return raw_value.to_lower().strip_edges().replace("-", "_").replace(" ", "_")

func _default_min_value(kind: StringName) -> int:
	match kind:
		TYPE_NPS:
			return 0
		TYPE_NUMBER:
			return -1000000
	return 1

func _default_max_value(kind: StringName) -> int:
	match kind:
		TYPE_NPS:
			return 10
		TYPE_NUMBER:
			return 1000000
	return 5

func _default_rating_enabled(kind: StringName) -> bool:
	match kind:
		TYPE_SCALE, TYPE_NPS, TYPE_MATRIX:
			return true
	return false

func _normalize_type(raw_type: String) -> StringName:
	match raw_type.to_lower().strip_edges():
		"text", "short", "short answer", "short-answer", "short_answer", "single line", "single_line":
			return TYPE_SHORT_TEXT
		"paragraph", "textarea", "long answer", "long-answer", "long_answer", "comment":
			return TYPE_LONG_TEXT
		"multiple choice", "multiple_choice", "multiple-choice", "radio", "radio button", "radio_button":
			return TYPE_SINGLE_CHOICE
		"checkbox", "checkboxes", "select all", "select_all", "select-all":
			return TYPE_MULTI_CHOICE
		"yes no", "yes_no", "yes-no":
			return TYPE_BOOLEAN
		"rating", "linear scale", "linear_scale", "linear-scale", "slider":
			return TYPE_SCALE
		"ranking", "rank order", "rank_order", "rank-order":
			return TYPE_RANKED_CHOICE
		"net promoter score", "net_promoter_score", "net-promoter-score":
			return TYPE_NPS
		"likert", "grid", "multiple choice grid", "multiple_choice_grid", "checkbox grid", "checkbox_grid":
			return TYPE_MATRIX
	return StringName(raw_type)

func _resolve_view_template(template_name: String) -> PackedScene:
	match template_name.to_lower().strip_edges():
		"scale_chips":
			return SCALE_CHIPS_VIEW_SCENE
		"ranked_choice":
			return RANKED_CHOICE_VIEW_SCENE
		"matrix":
			return MATRIX_VIEW_SCENE
	return null

