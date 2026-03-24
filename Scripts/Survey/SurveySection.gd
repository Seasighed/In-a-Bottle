class_name SurveySection
extends RefCounted

const SPOTLIGHT_HEADER_SCENE := preload("res://Scenes/Headers/SpotlightHeader.tscn")

var id: String
var title: String
var description: String
var questions: Array[SurveyQuestion]
var custom_header_scene: PackedScene
var icon_name: String
var emoji: String

func _init(config: Dictionary = {}) -> void:
	id = str(config.get("id", ""))
	title = str(config.get("title", "Untitled section"))
	description = str(config.get("description", ""))
	icon_name = _resolve_icon_name(str(config.get("icon", config.get("icon_name", ""))))
	emoji = str(config.get("emoji", config.get("icon_emoji", ""))).strip_edges()
	custom_header_scene = config.get("custom_header_scene", null)
	if custom_header_scene == null:
		custom_header_scene = _resolve_header_template(str(config.get("header_template", "")))
	questions = []
	for question in config.get("questions", []):
		if question is SurveyQuestion:
			questions.append(question)
		elif question is Dictionary:
			questions.append(SurveyQuestion.new(question))

func answered_count(answers: Dictionary) -> int:
	var total := 0
	for question in questions:
		if question.is_answer_complete(answers.get(question.id, null)):
			total += 1
	return total

func required_count() -> int:
	var total := 0
	for question in questions:
		if question.required:
			total += 1
	return total

func is_complete(answers: Dictionary) -> bool:
	for question in questions:
		if question.required and not question.is_answer_complete(answers.get(question.id, null)):
			return false
	return true

func resolved_emoji() -> String:
	if not emoji.is_empty():
		return emoji
	match icon_name:
		"profile":
			return "\uD83E\uDDD1"
		"review":
			return "\uD83E\uDDED"
		"closeout":
			return "\uD83C\uDFC1"
	return "\uD83D\uDCC1"

func display_title(index: int = -1) -> String:
	var visible_title: String = title.strip_edges()
	var resolved_emoji_value: String = resolved_emoji()
	if not resolved_emoji_value.is_empty():
		visible_title = "%s %s" % [resolved_emoji_value, visible_title]
	if index >= 0:
		return "%d. %s" % [index + 1, visible_title]
	return visible_title

func _resolve_header_template(template_name: String) -> PackedScene:
	match template_name.to_lower().strip_edges():
		"spotlight":
			return SPOTLIGHT_HEADER_SCENE
	return null

func _resolve_icon_name(raw_icon_name: String) -> String:
	var normalized := raw_icon_name.to_lower().strip_edges()
	if not normalized.is_empty():
		return normalized
	var haystack := ("%s %s" % [id, title]).to_lower()
	if haystack.contains("profile") or haystack.contains("participant") or haystack.contains("user"):
		return "profile"
	if haystack.contains("review") or haystack.contains("feedback") or haystack.contains("experience"):
		return "review"
	if haystack.contains("close") or haystack.contains("finish") or haystack.contains("done") or haystack.contains("wrap"):
		return "closeout"
	return "generic"
