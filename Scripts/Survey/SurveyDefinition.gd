class_name SurveyDefinition
extends RefCounted

var id: String
var title: String
var subtitle: String
var description: String
var onboarding_subject: String
var audience_profiles: Array[Dictionary]
var guided_presets: Array[Dictionary]
var faq_items: Array[Dictionary]
var sections: Array[SurveySection]

func _init(config: Dictionary = {}) -> void:
	id = str(config.get("id", "survey"))
	title = str(config.get("title", "Survey"))
	subtitle = str(config.get("subtitle", config.get("description", "")))
	description = str(config.get("description", subtitle))
	onboarding_subject = str(config.get("onboarding_subject", title))
	audience_profiles = _normalize_audience_profiles(config.get("audience_profiles", config.get("player_types", [])))
	guided_presets = _normalize_guided_presets(config.get("guided_presets", config.get("onboarding_presets", [])))
	faq_items = _normalize_faq_items(config.get("faq_items", config.get("faqs", [])))
	sections = []
	for section in config.get("sections", []):
		if section is SurveySection:
			sections.append(section)
		elif section is Dictionary:
			sections.append(SurveySection.new(section))
	if audience_profiles.is_empty():
		audience_profiles = _derive_audience_profiles_from_questions()
	if guided_presets.is_empty():
		guided_presets = _derive_guided_presets_from_profiles()

func total_questions() -> int:
	var count := 0
	for section in sections:
		count += section.questions.size()
	return count

func resolved_onboarding_subject() -> String:
	if not onboarding_subject.strip_edges().is_empty():
		return onboarding_subject.strip_edges()
	if not title.strip_edges().is_empty():
		return title.strip_edges()
	return "this survey"

func available_topic_tags() -> Array[Dictionary]:
	var counts: Dictionary = {}
	var labels: Dictionary = {}
	for section in sections:
		for question in section.questions:
			var source_tags: PackedStringArray = question.topic_tags if not question.topic_tags.is_empty() else question.keywords
			for raw_tag in source_tags:
				var tag_id: String = _normalize_identifier(raw_tag)
				if tag_id.is_empty():
					continue
				counts[tag_id] = int(counts.get(tag_id, 0)) + 1
				if not labels.has(tag_id):
					labels[tag_id] = _friendly_label(raw_tag)
	var tags: Array[Dictionary] = []
	for key in counts.keys():
		tags.append({
			"id": str(key),
			"label": str(labels.get(key, _friendly_label(str(key)))),
			"count": int(counts.get(key, 0))
		})
	tags.sort_custom(Callable(self, "_sort_topic_tags"))
	return tags

func find_audience_profile(profile_id: String) -> Dictionary:
	var normalized_id: String = _normalize_identifier(profile_id)
	if normalized_id.is_empty():
		return {}
	for profile in audience_profiles:
		if _normalize_identifier(str(profile.get("id", ""))) == normalized_id:
			return profile.duplicate(true)
	return {}

func find_guided_preset(preset_id: String) -> Dictionary:
	var normalized_id: String = _normalize_identifier(preset_id)
	if normalized_id.is_empty():
		return {}
	for preset in guided_presets:
		if _normalize_identifier(str(preset.get("id", ""))) == normalized_id:
			return preset.duplicate(true)
	return {}

func find_faq_item(faq_id: String) -> Dictionary:
	var normalized_id: String = _normalize_identifier(faq_id)
	if normalized_id.is_empty():
		return {}
	for faq_item in faq_items:
		if _normalize_identifier(str(faq_item.get("id", ""))) == normalized_id:
			return faq_item.duplicate(true)
	return {}

func _normalize_audience_profiles(value: Variant) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if value is Array:
		var raw_profiles: Array = value as Array
		for raw_profile in raw_profiles:
			var normalized_profile: Dictionary = _normalize_audience_profile(raw_profile)
			if not normalized_profile.is_empty():
				profiles.append(normalized_profile)
	return profiles

func _normalize_guided_presets(value: Variant) -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	if value is Array:
		var raw_presets: Array = value as Array
		for raw_preset in raw_presets:
			var normalized_preset: Dictionary = _normalize_guided_preset(raw_preset)
			if not normalized_preset.is_empty():
				presets.append(normalized_preset)
	return presets

func _normalize_faq_items(value: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if value is Array:
		var raw_items: Array = value as Array
		for raw_item in raw_items:
			var normalized_item: Dictionary = _normalize_faq_item(raw_item)
			if not normalized_item.is_empty():
				items.append(normalized_item)
	return items

func _normalize_audience_profile(raw_profile: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if raw_profile is Dictionary:
		var profile: Dictionary = raw_profile as Dictionary
		var raw_id: String = str(profile.get("id", profile.get("key", profile.get("name", profile.get("label", "")))))
		var profile_id: String = _normalize_identifier(raw_id)
		if profile_id.is_empty():
			return {}
		normalized["id"] = profile_id
		normalized["label"] = str(profile.get("label", profile.get("name", _friendly_label(raw_id))))
		normalized["description"] = str(profile.get("description", ""))
		return normalized
	var text_value: String = str(raw_profile).strip_edges()
	if text_value.is_empty():
		return {}
	return {
		"id": _normalize_identifier(text_value),
		"label": _friendly_label(text_value),
		"description": ""
	}

func _normalize_guided_preset(raw_preset: Variant) -> Dictionary:
	if raw_preset is Dictionary:
		var preset: Dictionary = raw_preset as Dictionary
		var raw_id: String = str(preset.get("id", preset.get("key", preset.get("name", preset.get("label", "")))))
		var preset_id: String = _normalize_identifier(raw_id)
		if preset_id.is_empty():
			return {}
		return {
			"id": preset_id,
			"label": str(preset.get("label", preset.get("name", _friendly_label(raw_id)))),
			"description": str(preset.get("description", "")),
			"audience_id": _normalize_identifier(str(preset.get("audience_id", preset.get("audience", preset.get("profile_id", ""))))),
			"topic_tags": _string_array_from_variant(preset.get("topic_tags", preset.get("topics", PackedStringArray())))
		}
	var text_value: String = str(raw_preset).strip_edges()
	if text_value.is_empty():
		return {}
	return {
		"id": _normalize_identifier(text_value),
		"label": _friendly_label(text_value),
		"description": "",
		"audience_id": "",
		"topic_tags": PackedStringArray()
	}

func _normalize_faq_item(raw_item: Variant) -> Dictionary:
	if raw_item is Dictionary:
		var faq_item: Dictionary = raw_item as Dictionary
		var raw_id: String = str(faq_item.get("id", faq_item.get("key", faq_item.get("question", faq_item.get("label", "")))))
		var faq_id: String = _normalize_identifier(raw_id)
		var question: String = str(faq_item.get("question", faq_item.get("label", _friendly_label(raw_id)))).strip_edges()
		var answer: String = str(faq_item.get("answer", faq_item.get("response", ""))).strip_edges()
		if faq_id.is_empty() or question.is_empty() or answer.is_empty():
			return {}
		return {
			"id": faq_id,
			"question": question,
			"answer": answer
		}
	return {}

func _derive_audience_profiles_from_questions() -> Array[Dictionary]:
	var counts: Dictionary = {}
	for section in sections:
		for question in section.questions:
			for raw_tag in question.audience_tags:
				var tag_id: String = _normalize_identifier(raw_tag)
				if tag_id.is_empty():
					continue
				counts[tag_id] = int(counts.get(tag_id, 0)) + 1
	var derived_profiles: Array[Dictionary] = []
	for key in counts.keys():
		derived_profiles.append({
			"id": str(key),
			"label": _friendly_label(str(key)),
			"description": ""
		})
	derived_profiles.sort_custom(Callable(self, "_sort_audience_profiles"))
	return derived_profiles

func _derive_guided_presets_from_profiles() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	for profile in audience_profiles:
		presets.append({
			"id": str(profile.get("id", "")),
			"label": str(profile.get("label", "")),
			"description": str(profile.get("description", "")),
			"audience_id": str(profile.get("id", "")),
			"topic_tags": PackedStringArray()
		})
	return presets

func _sort_topic_tags(left: Dictionary, right: Dictionary) -> bool:
	var left_count: int = int(left.get("count", 0))
	var right_count: int = int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("label", "")) < str(right.get("label", ""))

func _sort_audience_profiles(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("label", "")) < str(right.get("label", ""))

func _friendly_label(raw_value: String) -> String:
	var text: String = raw_value.strip_edges().replace("_", " ").replace("-", " ")
	while text.contains("  "):
		text = text.replace("  ", " ")
	var parts: PackedStringArray = text.split(" ", false)
	for index in range(parts.size()):
		parts[index] = parts[index].capitalize()
	return " ".join(parts).strip_edges()

func _normalize_identifier(raw_value: String) -> String:
	return raw_value.to_lower().strip_edges().replace("-", "_").replace(" ", "_")

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
