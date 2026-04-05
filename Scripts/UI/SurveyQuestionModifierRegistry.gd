class_name SurveyQuestionModifierRegistry
extends RefCounted

const LOOT_BOX_MATRIX_MODIFIER = preload("res://Scripts/UI/Modifiers/LootBoxMatrixModifier.gd")

static func create_modifier(question: SurveyQuestion):
	if question == null:
		return null
	match question.modifier_key.to_lower().strip_edges():
		"loot_box_matrix":
			return LOOT_BOX_MATRIX_MODIFIER.new()
	return null
