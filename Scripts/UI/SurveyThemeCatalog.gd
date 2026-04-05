class_name SurveyThemeCatalog
extends Resource

@export var themes: Array[Resource] = []

func available_themes() -> Array:
	var resolved: Array = []
	var seen_ids := {}
	for theme in themes:
		if theme == null:
			continue
		var normalized_id: String = str(theme.call("normalized_theme_id"))
		if normalized_id.is_empty() or seen_ids.has(normalized_id):
			continue
		seen_ids[normalized_id] = true
		resolved.append(theme)
	return resolved

func resolve_theme(theme_id: String):
	var available: Array = available_themes()
	var normalized_id: String = theme_id.strip_edges().to_lower()
	if not normalized_id.is_empty():
		for theme in available:
			if str(theme.call("normalized_theme_id")) == normalized_id:
				return theme
	return available[0] if not available.is_empty() else null

func resolve_theme_id(theme_id: String) -> String:
	var theme = resolve_theme(theme_id)
	return str(theme.call("normalized_theme_id")) if theme != null else ""
