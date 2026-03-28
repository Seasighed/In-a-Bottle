class_name QuestionViewRegistry
extends RefCounted

const SHORT_TEXT_VIEW_PATH := "res://Scenes/QuestionViews/ShortTextQuestionView.tscn"
const LONG_TEXT_VIEW_PATH := "res://Scenes/QuestionViews/LongTextQuestionView.tscn"
const SINGLE_CHOICE_VIEW_PATH := "res://Scenes/QuestionViews/SingleChoiceQuestionView.tscn"
const MULTI_CHOICE_VIEW_PATH := "res://Scenes/QuestionViews/MultiChoiceQuestionView.tscn"
const BOOLEAN_VIEW_PATH := "res://Scenes/QuestionViews/BooleanQuestionView.tscn"
const SCALE_VIEW_PATH := "res://Scenes/QuestionViews/ScaleQuestionView.tscn"
const RANKED_CHOICE_VIEW_PATH := "res://Scenes/QuestionViews/RankedChoiceQuestionView.tscn"
const DROPDOWN_VIEW_PATH := "res://Scenes/QuestionViews/DropdownQuestionView.tscn"
const EMAIL_VIEW_PATH := "res://Scenes/QuestionViews/EmailQuestionView.tscn"
const NUMBER_VIEW_PATH := "res://Scenes/QuestionViews/NumberQuestionView.tscn"
const DATE_VIEW_PATH := "res://Scenes/QuestionViews/DateQuestionView.tscn"
const NPS_VIEW_PATH := "res://Scenes/QuestionViews/NpsQuestionView.tscn"
const MATRIX_VIEW_PATH := "res://Scenes/QuestionViews/MatrixQuestionView.tscn"
const DEFAULT_VIEW_PATH := "res://Scenes/QuestionViews/DefaultQuestionView.tscn"

const SHORT_TEXT_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/ShortTextQuestionView.tscn")
const LONG_TEXT_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/LongTextQuestionView.tscn")
const SINGLE_CHOICE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/SingleChoiceQuestionView.tscn")
const MULTI_CHOICE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/MultiChoiceQuestionView.tscn")
const BOOLEAN_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/BooleanQuestionView.tscn")
const SCALE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/ScaleQuestionView.tscn")
const RANKED_CHOICE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/RankedChoiceQuestionView.tscn")
const DROPDOWN_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/DropdownQuestionView.tscn")
const EMAIL_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/EmailQuestionView.tscn")
const NUMBER_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/NumberQuestionView.tscn")
const DATE_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/DateQuestionView.tscn")
const NPS_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/NpsQuestionView.tscn")
const MATRIX_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/MatrixQuestionView.tscn")
const DEFAULT_VIEW_SCENE: PackedScene = preload("res://Scenes/QuestionViews/DefaultQuestionView.tscn")

static func packed_scene_for_type(kind: StringName) -> PackedScene:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return SHORT_TEXT_VIEW_SCENE
		SurveyQuestion.TYPE_LONG_TEXT:
			return LONG_TEXT_VIEW_SCENE
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return SINGLE_CHOICE_VIEW_SCENE
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return MULTI_CHOICE_VIEW_SCENE
		SurveyQuestion.TYPE_BOOLEAN:
			return BOOLEAN_VIEW_SCENE
		SurveyQuestion.TYPE_SCALE:
			return SCALE_VIEW_SCENE
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return RANKED_CHOICE_VIEW_SCENE
		SurveyQuestion.TYPE_DROPDOWN:
			return DROPDOWN_VIEW_SCENE
		SurveyQuestion.TYPE_EMAIL:
			return EMAIL_VIEW_SCENE
		SurveyQuestion.TYPE_NUMBER:
			return NUMBER_VIEW_SCENE
		SurveyQuestion.TYPE_DATE:
			return DATE_VIEW_SCENE
		SurveyQuestion.TYPE_NPS:
			return NPS_VIEW_SCENE
		SurveyQuestion.TYPE_MATRIX:
			return MATRIX_VIEW_SCENE
	return DEFAULT_VIEW_SCENE

static func scene_path_for_type(kind: StringName) -> String:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return SHORT_TEXT_VIEW_PATH
		SurveyQuestion.TYPE_LONG_TEXT:
			return LONG_TEXT_VIEW_PATH
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return SINGLE_CHOICE_VIEW_PATH
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return MULTI_CHOICE_VIEW_PATH
		SurveyQuestion.TYPE_BOOLEAN:
			return BOOLEAN_VIEW_PATH
		SurveyQuestion.TYPE_SCALE:
			return SCALE_VIEW_PATH
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return RANKED_CHOICE_VIEW_PATH
		SurveyQuestion.TYPE_DROPDOWN:
			return DROPDOWN_VIEW_PATH
		SurveyQuestion.TYPE_EMAIL:
			return EMAIL_VIEW_PATH
		SurveyQuestion.TYPE_NUMBER:
			return NUMBER_VIEW_PATH
		SurveyQuestion.TYPE_DATE:
			return DATE_VIEW_PATH
		SurveyQuestion.TYPE_NPS:
			return NPS_VIEW_PATH
		SurveyQuestion.TYPE_MATRIX:
			return MATRIX_VIEW_PATH
	return DEFAULT_VIEW_PATH

static func instantiate_for_question(question: SurveyQuestion) -> SurveyQuestionView:
	if question == null:
		return null
	if question.custom_view_scene != null:
		var custom_node := question.custom_view_scene.instantiate()
		var custom_view := custom_node as SurveyQuestionView
		if custom_view != null:
			return custom_view
	var packed_scene := packed_scene_for_type(question.type)
	if packed_scene != null:
		var scene_node := packed_scene.instantiate()
		var scene_view := scene_node as SurveyQuestionView
		if scene_view != null:
			return scene_view
	var fallback_node := DEFAULT_VIEW_SCENE.instantiate()
	var fallback_view := fallback_node as SurveyQuestionView
	if fallback_view != null:
		return fallback_view
	return DefaultQuestionView.new()

static func gallery_definitions() -> Array[Dictionary]:
	return [
		{
			"type": SurveyQuestion.TYPE_SHORT_TEXT,
			"title": "Short Text",
			"scene_path": SHORT_TEXT_VIEW_PATH,
			"question_config": {
				"id": "short_text_example",
				"type": SurveyQuestion.TYPE_SHORT_TEXT,
				"prompt": "What name should appear in the response export?",
				"description": "Use a participant code if you want anonymous exports.",
				"placeholder": "Participant 014",
				"required": true,
				"help_markdown": "## Example\nUse this for short freeform answers."
			},
			"answer": "Participant 014"
		},
		{
			"type": SurveyQuestion.TYPE_LONG_TEXT,
			"title": "Long Text",
			"scene_path": LONG_TEXT_VIEW_PATH,
			"question_config": {
				"id": "long_text_example",
				"type": SurveyQuestion.TYPE_LONG_TEXT,
				"prompt": "Tell us more about your workflow.",
				"description": "Long-form answers support multiple lines.",
				"placeholder": "I usually start by...",
				"help_markdown": "## Example\nGreat for reflection, context, or detailed opinions."
			},
			"answer": "I usually start by sketching ideas, then build the rough version first."
		},
		{
			"type": SurveyQuestion.TYPE_EMAIL,
			"title": "Email",
			"scene_path": EMAIL_VIEW_PATH,
			"question_config": {
				"id": "email_example",
				"type": SurveyQuestion.TYPE_EMAIL,
				"prompt": "Where can we contact you?",
				"description": "Optional if you want follow-up.",
				"placeholder": "name@example.com"
			},
			"answer": "alex@example.com"
		},
		{
			"type": SurveyQuestion.TYPE_DATE,
			"title": "Date",
			"scene_path": DATE_VIEW_PATH,
			"question_config": {
				"id": "date_example",
				"type": SurveyQuestion.TYPE_DATE,
				"prompt": "When did you start using this tool?",
				"description": "Use YYYY-MM-DD formatting.",
				"placeholder": "2026-03-27"
			},
			"answer": "2026-03-27"
		},
		{
			"type": SurveyQuestion.TYPE_SINGLE_CHOICE,
			"title": "Single Choice",
			"scene_path": SINGLE_CHOICE_VIEW_PATH,
			"question_config": {
				"id": "single_choice_example",
				"type": SurveyQuestion.TYPE_SINGLE_CHOICE,
				"prompt": "Which primary loader do you use?",
				"description": "Pick the one you rely on most often.",
				"options": PackedStringArray(["Fabric", "Forge", "Quilt", "Multiple loaders"])
			},
			"answer": "Fabric"
		},
		{
			"type": SurveyQuestion.TYPE_DROPDOWN,
			"title": "Dropdown",
			"scene_path": DROPDOWN_VIEW_PATH,
			"question_config": {
				"id": "dropdown_example",
				"type": SurveyQuestion.TYPE_DROPDOWN,
				"prompt": "Which region best matches you?",
				"description": "This uses the dropdown/list style.",
				"options": PackedStringArray(["North America", "South America", "Europe", "Asia", "Oceania"])
			},
			"answer": "North America"
		},
		{
			"type": SurveyQuestion.TYPE_MULTI_CHOICE,
			"title": "Multi Choice",
			"scene_path": MULTI_CHOICE_VIEW_PATH,
			"question_config": {
				"id": "multi_choice_example",
				"type": SurveyQuestion.TYPE_MULTI_CHOICE,
				"prompt": "Which tools do you use regularly?",
				"description": "Select every option that fits.",
				"options": PackedStringArray(["Git", "VS Code", "Godot", "Supabase"])
			},
			"answer": ["VS Code", "Godot", "Git"]
		},
		{
			"type": SurveyQuestion.TYPE_BOOLEAN,
			"title": "Yes / No",
			"scene_path": BOOLEAN_VIEW_PATH,
			"question_config": {
				"id": "boolean_example",
				"type": SurveyQuestion.TYPE_BOOLEAN,
				"prompt": "Would you recommend this to a friend?",
				"description": "A simple yes/no decision point."
			},
			"answer": true
		},
		{
			"type": SurveyQuestion.TYPE_NUMBER,
			"title": "Number",
			"scene_path": NUMBER_VIEW_PATH,
			"question_config": {
				"id": "number_example",
				"type": SurveyQuestion.TYPE_NUMBER,
				"prompt": "How many hours did you spend this week?",
				"description": "Use a numeric input with the mobile keypad.",
				"placeholder": "12"
			},
			"answer": 12
		},
		{
			"type": SurveyQuestion.TYPE_SCALE,
			"title": "Scale",
			"scene_path": SCALE_VIEW_PATH,
			"question_config": {
				"id": "scale_example",
				"type": SurveyQuestion.TYPE_SCALE,
				"prompt": "How confident do you feel with the current flow?",
				"description": "This is the slider-style scale question.",
				"min_value": 1,
				"max_value": 5,
				"step": 1.0,
				"left_label": "Low",
				"right_label": "High"
			},
			"answer": 4
		},
		{
			"type": SurveyQuestion.TYPE_NPS,
			"title": "NPS / 0-10",
			"scene_path": NPS_VIEW_PATH,
			"question_config": {
				"id": "nps_example",
				"type": SurveyQuestion.TYPE_NPS,
				"prompt": "How likely are you to recommend this workflow?",
				"description": "This uses the chip/slider NPS-style control.",
				"min_value": 0,
				"max_value": 10,
				"step": 1.0
			},
			"answer": 8
		},
		{
			"type": SurveyQuestion.TYPE_RANKED_CHOICE,
			"title": "Ranked Choice",
			"scene_path": RANKED_CHOICE_VIEW_PATH,
			"question_config": {
				"id": "ranked_choice_example",
				"type": SurveyQuestion.TYPE_RANKED_CHOICE,
				"prompt": "Rank these priorities.",
				"description": "Use drag or buttons to reorder the list.",
				"options": PackedStringArray(["Speed", "Clarity", "Flexibility", "Polish"])
			},
			"answer": ["Clarity", "Speed", "Polish", "Flexibility"]
		},
		{
			"type": SurveyQuestion.TYPE_MATRIX,
			"title": "Matrix",
			"scene_path": MATRIX_VIEW_PATH,
			"question_config": {
				"id": "matrix_example",
				"type": SurveyQuestion.TYPE_MATRIX,
				"prompt": "How well is the current workflow serving you?",
				"description": "A multi-row agreement matrix.",
				"rows": PackedStringArray(["Setting up the workspace", "Debugging runtime issues", "Working with mappings"]),
				"options": PackedStringArray(["Very poor", "Poor", "Mixed", "Good", "Excellent"])
			},
			"answer": {
				"Setting up the workspace": "Good",
				"Debugging runtime issues": "Mixed",
				"Working with mappings": "Excellent"
			}
		}
	]
