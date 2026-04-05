class_name SurveyQuestionXpConfig
extends Resource

@export_range(0, 250, 1) var short_text_xp := 6
@export_range(0, 250, 1) var long_text_xp := 8
@export_range(0, 250, 1) var single_choice_xp := 4
@export_range(0, 250, 1) var multi_choice_xp := 6
@export_range(0, 250, 1) var boolean_xp := 3
@export_range(0, 250, 1) var scale_xp := 4
@export_range(0, 250, 1) var ranked_choice_xp := 9
@export_range(0, 250, 1) var dropdown_xp := 4
@export_range(0, 250, 1) var email_xp := 5
@export_range(0, 250, 1) var number_xp := 4
@export_range(0, 250, 1) var date_xp := 4
@export_range(0, 250, 1) var nps_xp := 4
@export_range(0, 250, 1) var matrix_xp := 10

func xp_for_question(question: SurveyQuestion) -> int:
	if question == null:
		return 0
	return question.resolved_reward_count(xp_for_type(question.type))

func xp_for_type(question_type: StringName) -> int:
	match question_type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return short_text_xp
		SurveyQuestion.TYPE_LONG_TEXT:
			return long_text_xp
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return single_choice_xp
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return multi_choice_xp
		SurveyQuestion.TYPE_BOOLEAN:
			return boolean_xp
		SurveyQuestion.TYPE_SCALE:
			return scale_xp
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return ranked_choice_xp
		SurveyQuestion.TYPE_DROPDOWN:
			return dropdown_xp
		SurveyQuestion.TYPE_EMAIL:
			return email_xp
		SurveyQuestion.TYPE_NUMBER:
			return number_xp
		SurveyQuestion.TYPE_DATE:
			return date_xp
		SurveyQuestion.TYPE_NPS:
			return nps_xp
		SurveyQuestion.TYPE_MATRIX:
			return matrix_xp
	return short_text_xp

func max_configured_xp() -> int:
	var highest_xp := 0
	for value in [
		short_text_xp,
		long_text_xp,
		single_choice_xp,
		multi_choice_xp,
		boolean_xp,
		scale_xp,
		ranked_choice_xp,
		dropdown_xp,
		email_xp,
		number_xp,
		date_xp,
		nps_xp,
		matrix_xp
	]:
		highest_xp = max(highest_xp, int(value))
	return highest_xp
