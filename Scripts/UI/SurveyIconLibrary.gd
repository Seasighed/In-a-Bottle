class_name SurveyIconLibrary
extends RefCounted

const STATE_COMPLETE := preload("res://Assets/UI/Icons/state-complete.svg")
const STATE_INCOMPLETE := preload("res://Assets/UI/Icons/state-incomplete.svg")
const SECTION_GENERIC := preload("res://Assets/UI/Icons/section-generic.svg")
const SECTION_PROFILE := preload("res://Assets/UI/Icons/section-profile.svg")
const SECTION_REVIEW := preload("res://Assets/UI/Icons/section-review.svg")
const SECTION_CLOSEOUT := preload("res://Assets/UI/Icons/section-closeout.svg")

static func completion_texture(is_complete: bool) -> Texture2D:
	return STATE_COMPLETE if is_complete else STATE_INCOMPLETE

static func section_texture(icon_name: String) -> Texture2D:
	match icon_name.to_lower().strip_edges():
		"profile", "participant", "user", "people":
			return SECTION_PROFILE
		"review", "feedback", "rating", "analytics", "experience":
			return SECTION_REVIEW
		"closeout", "wrap", "finish", "done", "end":
			return SECTION_CLOSEOUT
	return SECTION_GENERIC
