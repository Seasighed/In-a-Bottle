class_name SurveyUiFlowCatalog
extends RefCounted

const OUTPUT_DIRECTORY := "user://ui_flow_map"
const CANVAS_SIZE := Vector2i(7800, 4700)
const PHONE_VIEWPORT := Vector2i(430, 932)
const GALLERY_VIEWPORT := Vector2i(1900, 2500)
const SCREEN_PREVIEW := Vector2(280.0, 608.0)
const LARGE_PREVIEW := Vector2(760.0, 980.0)

static func build_graph() -> Dictionary:
	return {
		"title": "In a Bottle UI Flow Map",
		"output_directory": OUTPUT_DIRECTORY,
		"canvas_size": CANVAS_SIZE,
		"nodes": build_nodes(),
		"edges": build_edges()
	}

static func build_nodes() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	nodes.append_array(_survey_app_nodes())
	nodes.append_array(_survey_journey_nodes())
	nodes.append_array(_shared_nodes())
	return nodes

static func build_edges() -> Array[Dictionary]:
	return [
		_edge("survey_app_scroll", "survey_app_focus", "Toggle focus mode"),
		_edge("survey_app_scroll", "survey_app_menu", "Open menu"),
		_edge("survey_app_focus", "survey_app_help", "Question help"),
		_edge("survey_app_focus", "question_gallery", "Question prefab family"),
		_edge("survey_app_menu", "survey_app_search", "Search"),
		_edge("survey_app_menu", "survey_app_onboarding", "Onboarding"),
		_edge("survey_app_menu", "survey_app_settings", "Settings"),
		_edge("survey_app_menu", "survey_app_summary", "Summary"),
		_edge("survey_app_menu", "survey_app_export", "Export"),
		_edge("survey_app_menu", "survey_app_profile", "Profile"),
		_edge("journey_landing", "journey_theme_drawer", "Theme palette"),
		_edge("journey_landing", "journey_survey_selection", "Browse surveys"),
		_edge("journey_landing", "journey_focus", "Start featured survey"),
		_edge("journey_landing", "journey_lore", "Open featured lore"),
		_edge("journey_survey_selection", "journey_focus", "Dive in"),
		_edge("journey_survey_selection", "journey_lore", "Open lore"),
		_edge("journey_lore", "journey_lore_link", "Associated URL"),
		_edge("journey_focus", "journey_outline", "Outline"),
		_edge("journey_focus", "journey_menu", "Menu"),
		_edge("journey_focus", "journey_help", "Question help"),
		_edge("journey_focus", "journey_profile", "Profile"),
		_edge("journey_focus", "journey_review", "Review"),
		_edge("journey_focus", "journey_thanks", "Finish"),
		_edge("journey_focus", "question_gallery", "Question prefab family"),
		_edge("journey_review", "journey_focus", "Jump back"),
		_edge("journey_thanks", "journey_review", "Review answers"),
		_edge("journey_thanks", "journey_upload", "Upload answers"),
		_edge("journey_thanks", "journey_export", "Save answers"),
		_edge("journey_export", "journey_upload", "Upload when configured")
	]

static func build_node_lookup(graph: Dictionary = {}) -> Dictionary:
	var resolved_graph: Dictionary = graph if not graph.is_empty() else build_graph()
	var lookup := {}
	var node_values: Variant = resolved_graph.get("nodes", [])
	if node_values is Array:
		for node_value in node_values:
			if not (node_value is Dictionary):
				continue
			var node_spec: Dictionary = node_value as Dictionary
			var node_id := str(node_spec.get("id", "")).strip_edges()
			if node_id.is_empty():
				continue
			lookup[node_id] = node_spec.duplicate(true)
	return lookup

static func has_edge(from_id: String, to_id: String, graph: Dictionary = {}) -> bool:
	var resolved_graph: Dictionary = graph if not graph.is_empty() else build_graph()
	var edge_values: Variant = resolved_graph.get("edges", [])
	if edge_values is Array:
		for edge_value in edge_values:
			if not (edge_value is Dictionary):
				continue
			var edge_spec: Dictionary = edge_value as Dictionary
			if str(edge_spec.get("from", "")).strip_edges() == from_id and str(edge_spec.get("to", "")).strip_edges() == to_id:
				return true
	return false

static func _survey_app_nodes() -> Array[Dictionary]:
	return [
		_node("survey_app_scroll", "Survey App / Scroll", "Document mode in the shipped main scene.", "survey_app", "scroll", Vector2(120.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_focus", "Survey App / Focus", "The focused question presentation for narrow/mobile layouts.", "survey_app", "focus", Vector2(920.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_menu", "Survey App / Menu", "The in-app overlay menu for navigation and utilities.", "survey_app", "overlay_menu", Vector2(520.0, 1120.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_search", "Survey App / Search", "Question search and jump overlay.", "survey_app", "search", Vector2(120.0, 2060.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_onboarding", "Survey App / Onboarding", "The startup guidance and routing overlay.", "survey_app", "onboarding", Vector2(920.0, 2060.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_settings", "Survey App / Settings", "Theme, SFX, and persistence controls.", "survey_app", "settings", Vector2(1720.0, 2060.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_summary", "Survey App / Summary", "Opinion summary overlay with export actions.", "survey_app", "summary", Vector2(120.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_export", "Survey App / Export", "Save, copy, and upload responses from the main shell.", "survey_app", "export", Vector2(920.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_profile", "Survey App / Profile", "Character/social profile overlay.", "survey_app", "profile", Vector2(1720.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app"),
		_node("survey_app_help", "Survey App / Help", "Inline question help for the selected prompt.", "survey_app", "help", Vector2(920.0, 3940.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_app")
	]

static func _survey_journey_nodes() -> Array[Dictionary]:
	return [
		_node("journey_landing", "Journey / Landing", "The Journey shell landing screen.", "survey_journey", "landing", Vector2(2800.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_theme_drawer", "Journey / Theme Drawer", "Landing-only palette drawer.", "survey_journey", "theme_drawer", Vector2(3600.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_survey_selection", "Journey / Survey Selection", "Template picking and management.", "survey_journey", "survey_selection", Vector2(4400.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_lore", "Journey / Lore", "Lore framing and context screen.", "survey_journey", "lore", Vector2(3600.0, 1120.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_lore_link", "Journey / Lore Link", "The lore-link prompt overlay.", "survey_journey", "lore_link_prompt", Vector2(4400.0, 1120.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_focus", "Journey / Focus", "Single-question focus flow.", "survey_journey", "focus", Vector2(5200.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_outline", "Journey / Outline", "The focus-mode section outline overlay.", "survey_journey", "focus_outline", Vector2(6000.0, 180.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_menu", "Journey / Menu", "Focus-mode overlay menu.", "survey_journey", "overlay_menu", Vector2(5200.0, 1120.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_help", "Journey / Help", "Focus-mode question help.", "survey_journey", "help", Vector2(6000.0, 1120.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_review", "Journey / Review", "Answer review screen.", "survey_journey", "review", Vector2(5200.0, 2060.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_profile", "Journey / Profile", "Character/social profile from Journey mode.", "survey_journey", "profile", Vector2(6000.0, 2060.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_thanks", "Journey / Thanks", "Post-completion thank-you screen.", "survey_journey", "thanks", Vector2(5200.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_export", "Journey / Submit / Save", "Submit-or-save handoff screen with local copy fallback.", "survey_journey", "export", Vector2(6000.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey"),
		_node("journey_upload", "Journey / Upload", "Upload review/consent screen.", "survey_journey", "upload", Vector2(6800.0, 3000.0), PHONE_VIEWPORT, SCREEN_PREVIEW, "survey_journey")
	]

static func _shared_nodes() -> Array[Dictionary]:
	return [
		_node("question_gallery", "Question UI Atlas", "Every mapped question prefab rendered together in one sheet.", "question_gallery", "gallery", Vector2(6400.0, 180.0), GALLERY_VIEWPORT, LARGE_PREVIEW, "shared_ui")
	]

static func _node(id: String, title: String, description: String, source_kind: String, state: String, position: Vector2, viewport_size: Vector2i, preview_size: Vector2, group: String) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"source_kind": source_kind,
		"state": state,
		"position": position,
		"viewport_size": viewport_size,
		"preview_size": preview_size,
		"group": group
	}

static func _edge(from_id: String, to_id: String, label: String = "") -> Dictionary:
	return {
		"from": from_id,
		"to": to_id,
		"label": label
	}
