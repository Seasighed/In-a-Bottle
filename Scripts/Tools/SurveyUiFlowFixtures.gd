class_name SurveyUiFlowFixtures
extends RefCounted

const SAMPLE_SURVEY = preload("res://Scripts/Survey/SampleSurvey.gd")
const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_SUMMARY_ANALYZER = preload("res://Scripts/Survey/SurveySummaryAnalyzer.gd")
const SURVEY_GAMIFICATION_STORE = preload("res://Scripts/Survey/SurveyGamificationStore.gd")
const DEFAULT_QUESTION_XP_CONFIG: SurveyQuestionXpConfig = preload("res://Resources/Survey/DefaultQuestionXpConfig.tres")
const TEMPLATE_PATH := "res://Dev/SurveyTemplates/studio_feedback.json"

static func default_template_path() -> String:
	return TEMPLATE_PATH

static func load_default_survey() -> SurveyDefinition:
	var survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(TEMPLATE_PATH)
	if survey != null:
		return survey
	return SAMPLE_SURVEY.build()

static func available_templates() -> Array[Dictionary]:
	return SURVEY_TEMPLATE_LOADER.list_available_templates()

static func sample_complete_answers(survey: SurveyDefinition) -> Dictionary:
	var answers := {}
	if survey == null:
		return answers
	for section in survey.sections:
		for question in section.questions:
			answers[question.id] = sample_complete_answer(question)
	return answers

static func sample_complete_answer(question: SurveyQuestion) -> Variant:
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return "Sample short answer"
		SurveyQuestion.TYPE_LONG_TEXT:
			return "Sample long answer with enough detail to count as filled."
		SurveyQuestion.TYPE_EMAIL:
			return "tester@example.com"
		SurveyQuestion.TYPE_DATE:
			return "2026-04-01"
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			return question.options[0] if not question.options.is_empty() else "Option A"
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return [question.options[0]] if not question.options.is_empty() else ["Option A"]
		SurveyQuestion.TYPE_BOOLEAN:
			return true
		SurveyQuestion.TYPE_SCALE:
			return clampi(question.max_value, question.min_value, question.max_value)
		SurveyQuestion.TYPE_NPS:
			return clampi(9, question.min_value, question.max_value)
		SurveyQuestion.TYPE_NUMBER:
			return clampi(25, question.min_value, question.max_value)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			var ranked_answer: Array = []
			for option in question.options:
				ranked_answer.append(option)
			return ranked_answer
		SurveyQuestion.TYPE_MATRIX:
			var matrix_answer: Dictionary = {}
			var selection: String = question.options[0] if not question.options.is_empty() else "Yes"
			for row_name in question.rows:
				matrix_answer[row_name] = selection
			return matrix_answer
	return "Fallback answer"

static func summary_data(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	if survey == null:
		return {}
	return SURVEY_SUMMARY_ANALYZER.build_summary(survey, answers)

static func profile_snapshot(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	var profile: Dictionary = SURVEY_GAMIFICATION_STORE.default_profile()
	if survey != null and not survey.sections.is_empty() and not survey.sections[0].questions.is_empty():
		var first_question: SurveyQuestion = survey.sections[0].questions[0]
		var reward_key := "ui_flow::%s" % first_question.id
		var config := DEFAULT_QUESTION_XP_CONFIG
		var question_xp: int = config.xp_for_question(first_question) if config != null else 6
		var question_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, first_question, question_xp, Vector2.ZERO, reward_key, question_xp)
		profile = question_result.get("profile", profile)
		var section_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_section_complete(profile, survey.sections[0].id, survey.sections[0].title)
		profile = section_result.get("profile", profile)
	return SURVEY_GAMIFICATION_STORE.build_profile_snapshot(profile, survey, answers)
