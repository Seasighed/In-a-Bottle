class_name SampleSurvey
extends RefCounted

const SPOTLIGHT_HEADER := preload("res://Scenes/Headers/SpotlightHeader.tscn")
const SCALE_CHIPS_VIEW := preload("res://Scenes/QuestionViews/ScaleChipQuestionView.tscn")

static func build() -> SurveyDefinition:
	return SurveyDefinition.new({
		"id": "studio_feedback",
		"title": "Survey Studio",
		"subtitle": "A modular questionnaire shell with section navigation, reusable views, and export-ready data.",
		"asks_identifying_info": true,
		"sections": [
			SurveySection.new({
				"id": "participant_profile",
				"title": "Participant Profile",
				"description": "Start with the basics. This section shows a custom header scene that can be swapped for your own art direction.",
				"icon": "profile",
				"custom_header_scene": SPOTLIGHT_HEADER,
				"questions": [
					SurveyQuestion.new({
						"id": "display_name",
						"prompt": "What name should appear in the response export?",
						"description": "Use a participant code if you want anonymous exports.",
						"type": SurveyQuestion.TYPE_SHORT_TEXT,
						"asks_identifying_info": true,
						"required": true,
						"placeholder": "Participant 014"
					}),
					SurveyQuestion.new({
						"id": "role",
						"prompt": "Which best describes this respondent?",
						"type": SurveyQuestion.TYPE_SINGLE_CHOICE,
						"required": true,
						"options": PackedStringArray(["Customer", "Playtester", "Team member", "Research volunteer"])
					}),
					SurveyQuestion.new({
						"id": "focus_areas",
						"prompt": "Which themes should this response emphasize?",
						"description": "Choose as many as apply.",
						"type": SurveyQuestion.TYPE_MULTI_CHOICE,
						"options": PackedStringArray(["Clarity", "Usability", "Visual design", "Performance", "Accessibility"])
					})
				]
			}),
			SurveySection.new({
				"id": "experience_review",
				"title": "Experience Review",
				"description": "Mix and match question types per section. This section now includes custom scale and ranked-choice prefabs alongside standard controls.",
				"icon": "review",
				"custom_header_scene": SPOTLIGHT_HEADER,
				"questions": [
					SurveyQuestion.new({
						"id": "ease_of_use",
						"prompt": "How easy was the survey flow to follow?",
						"description": "This is rendered with a custom scene to demonstrate swappable visuals.",
						"type": SurveyQuestion.TYPE_SCALE,
						"required": true,
						"min_value": 1,
						"max_value": 5,
						"custom_view_scene": SCALE_CHIPS_VIEW
					}),
					SurveyQuestion.new({
						"id": "workflow_frequency",
						"prompt": "How often would this questionnaire run in your workflow?",
						"type": SurveyQuestion.TYPE_SINGLE_CHOICE,
						"options": PackedStringArray(["One-time intake", "Weekly check-in", "Monthly review", "Event-based follow-up"])
					}),
					SurveyQuestion.new({
						"id": "improvement_rank",
						"prompt": "Rank the areas you would improve first.",
						"description": "Move the most urgent follow-up to the top.",
						"type": SurveyQuestion.TYPE_RANKED_CHOICE,
						"options": PackedStringArray(["Navigation", "Question wording", "Visual hierarchy", "Export clarity"])
					}),
					SurveyQuestion.new({
						"id": "pain_points",
						"prompt": "What would you change first?",
						"type": SurveyQuestion.TYPE_LONG_TEXT,
						"placeholder": "Call out friction points, missing states, or extra data you would want to collect."
					})
				]
			}),
			SurveySection.new({
				"id": "closeout",
				"title": "Closeout",
				"description": "Finish with consent and follow-up questions, then export the data as JSON or CSV.",
				"icon": "closeout",
				"custom_header_scene": SPOTLIGHT_HEADER,
				"questions": [
					SurveyQuestion.new({
						"id": "recommendation",
						"prompt": "Would you use this survey shell for a real questionnaire?",
						"type": SurveyQuestion.TYPE_BOOLEAN,
						"required": true
					}),
					SurveyQuestion.new({
						"id": "follow_up_notes",
						"prompt": "Any final notes for the designer?",
						"type": SurveyQuestion.TYPE_LONG_TEXT,
						"placeholder": "Write a final summary or leave this blank."
					}),
					SurveyQuestion.new({
						"id": "contact_permission",
						"prompt": "Can the team contact this participant for follow-up?",
						"type": SurveyQuestion.TYPE_BOOLEAN
					})
				]
			})
		]
	})
