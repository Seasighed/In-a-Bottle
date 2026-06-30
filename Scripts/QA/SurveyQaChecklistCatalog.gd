class_name SurveyQaChecklistCatalog
extends RefCounted

const SURVEY_UI_FLOW_CATALOG = preload("res://Scripts/Tools/SurveyUiFlowCatalog.gd")
const DEFAULT_TEMPLATE_PATH := "res://Dev/SurveyTemplates/personal_checkin_debug.json"

const JOURNEY_PAGE_IDS := [
	"journey_landing",
	"journey_theme_drawer",
	"journey_survey_selection",
	"journey_lore",
	"journey_lore_link",
	"journey_focus",
	"journey_outline",
	"journey_menu",
	"journey_help",
	"journey_review",
	"journey_profile",
	"journey_thanks",
	"journey_export",
	"journey_upload"
]

const SURVEY_APP_PAGE_IDS := [
	"survey_app_scroll",
	"survey_app_focus",
	"survey_app_menu",
	"survey_app_search",
	"survey_app_onboarding",
	"survey_app_settings",
	"survey_app_summary",
	"survey_app_export",
	"survey_app_profile",
	"survey_app_help"
]

const SHARED_PAGE_IDS := [
	"question_gallery"
]

static func default_template_path() -> String:
	return DEFAULT_TEMPLATE_PATH

static func page_ids_for_surface(surface_id: String, include_shared: bool = true) -> Array[String]:
	var page_ids: Array[String] = []
	match surface_id.strip_edges():
		"survey_journey":
			page_ids.append_array(JOURNEY_PAGE_IDS)
		"survey_app":
			page_ids.append_array(SURVEY_APP_PAGE_IDS)
	if include_shared:
		page_ids.append_array(SHARED_PAGE_IDS)
	return page_ids

static func sections_for_surface(surface_id: String, include_shared: bool = true) -> Array[Dictionary]:
	var lookup: Dictionary = SURVEY_UI_FLOW_CATALOG.build_node_lookup()
	var sections: Array[Dictionary] = []
	for page_node_id in page_ids_for_surface(surface_id, include_shared):
		var node_spec: Dictionary = lookup.get(page_node_id, {}) as Dictionary
		if node_spec.is_empty():
			continue
		sections.append({
			"page_node_id": page_node_id,
			"title": str(node_spec.get("title", page_node_id)).strip_edges(),
			"description": str(node_spec.get("description", "")).strip_edges(),
			"group": str(node_spec.get("group", "")).strip_edges(),
			"items": items_for_page(page_node_id)
		})
	return sections

static func items_for_surface(surface_id: String, include_shared: bool = true) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for page_node_id in page_ids_for_surface(surface_id, include_shared):
		items.append_array(items_for_page(page_node_id))
	return items

static func item_lookup(surface_id: String, include_shared: bool = true) -> Dictionary:
	var lookup := {}
	for item in items_for_surface(surface_id, include_shared):
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		lookup[item_id] = item.duplicate(true)
	return lookup

static func find_item(surface_id: String, item_id: String) -> Dictionary:
	return item_lookup(surface_id).get(item_id, {}) as Dictionary

static func items_for_page(page_node_id: String) -> Array[Dictionary]:
	match page_node_id.strip_edges():
		"journey_landing":
			return [
				_item(page_node_id, "readability", "Landing copy is readable and the featured CTA is obvious.", "The landing title, subtitle, and primary call to action should fit cleanly without overlap or clipped text."),
				_item(page_node_id, "entry_points", "The landing buttons route to the correct next surfaces.", "Take Survey, Get Lore, Character, and the QA/report affordances should open the matching surface or tool.", true, true)
			]
		"journey_theme_drawer":
			return [
				_item(page_node_id, "drawer_visibility", "The theme drawer expands without covering critical controls.", "The landing-only palette drawer should open, stay readable, and remain dismissible."),
				_item(page_node_id, "theme_feedback", "Theme selections provide clear visual feedback.", "Changing the theme or light/dark mode should update the shell styling without breaking layout.", true, true)
			]
		"journey_survey_selection":
			return [
				_item(page_node_id, "template_grid", "Survey cards remain readable and selectable.", "The survey selection grid should show the available survey cards with clear labels and no overlapping actions."),
				_item(page_node_id, "selection_flow", "Selecting the QA template prepares the tester for the next step.", "Choosing a survey should enable the next step and keep import/export/clear actions understandable.", true, true)
			]
		"journey_lore":
			return [
				_item(page_node_id, "lore_copy", "Lore text or the empty state explains what this page is for.", "The lore screen should either show context text or a clear empty state with no broken layout."),
				_item(page_node_id, "lore_cta", "Lore actions stay predictable.", "Back, Take This Survey, and optional lore-link actions should behave consistently.", true, true)
			]
		"journey_lore_link":
			return [
				_item(page_node_id, "lore_prompt", "The lore-link prompt explains the destination clearly.", "The lore-link prompt should make it obvious what will open or copy before the tester leaves the app."),
				_item(page_node_id, "lore_prompt_actions", "Copy and open actions are available when lore links exist.", "The prompt should support a safe copy/open flow and close cleanly.", true, true)
			]
		"journey_focus":
			return [
				_item(page_node_id, "focus_question", "The focus question view shows one question cleanly.", "The active question, progress, and answer controls should fit comfortably and remain obvious on the current surface."),
				_item(page_node_id, "focus_navigation", "Previous and Next keep the tester oriented.", "Focus navigation should move through questions without losing progress or confusing the current section context.", true, true)
			]
		"journey_outline":
			return [
				_item(page_node_id, "outline_readability", "The outline overlay lists sections clearly.", "The section outline should show the current section and let the tester understand where they are."),
				_item(page_node_id, "outline_navigation", "Outline jumps land in the expected question flow.", "Choosing an outline row should return the tester to the correct question position.", true, true)
			]
		"journey_menu":
			return [
				_item(page_node_id, "menu_scope", "The Journey menu keeps only safe tester actions visible.", "The menu should stay focused on continue/review/jump/profile/report/submit-save style actions without exposing noisy dev-only controls."),
				_item(page_node_id, "menu_routes", "Menu actions lead to the expected destination.", "Review Answers, Character, Report Issue, and Submit or Save should open the matching surface without dead ends.", true, true)
			]
		"journey_help":
			return [
				_item(page_node_id, "help_explains", "Question help explains the current prompt clearly.", "The help panel should describe the active question and remain readable on the current surface."),
				_item(page_node_id, "help_exit", "Leaving help returns to the same question context.", "Closing help should preserve the tester's place in the focus flow.", true, true)
			]
		"journey_review":
			return [
				_item(page_node_id, "review_cards", "Review cards summarize answers without broken copy or layout.", "The answer review screen should group answers clearly and avoid clipping or overlapping cards."),
				_item(page_node_id, "review_jump_back", "Review actions return the tester to the expected question.", "Jump-back or back actions should preserve context instead of dropping the tester somewhere unexpected.", true, true)
			]
		"journey_profile":
			return [
				_item(page_node_id, "profile_render", "The character/profile overlay renders a coherent snapshot.", "The profile surface should show readable progression or placeholder state without broken controls."),
				_item(page_node_id, "profile_exports", "Profile export and copy controls are present when expected.", "Profile PNG/JSON/CSV actions should be visible and feel distinct from the main survey exports.", true, true)
			]
		"journey_thanks":
			return [
				_item(page_node_id, "thanks_copy", "The thanks view explains the next action clearly.", "The wrap-up message should make Review Answers versus Upload/Save easy for a non-technical tester to understand."),
				_item(page_node_id, "thanks_cta", "The primary thanks CTA matches completion state.", "The main button should reflect the current build state, favoring upload when configured and save otherwise.", true, true)
			]
		"journey_export":
			return [
				_item(page_node_id, "export_actions", "Save and copy actions remain understandable.", "The submit/save surface should clearly separate local JSON/CSV actions from any upload path."),
				_item(page_node_id, "upload_explanation", "The export surface explains upload availability honestly.", "If upload is unavailable for the build, the copy should say so clearly instead of pretending the path exists.", true, true)
			]
		"journey_upload":
			return [
				_item(page_node_id, "upload_disclosure", "Upload copy explains what would be sent.", "The upload review page should summarize what is sent, where it goes, and whether identifying answers are scrubbed.", true, true, false, "high", "", "upload_configured"),
				_item(page_node_id, "upload_guardrails", "Consent and readiness checks gate the submit action.", "The upload action should stay blocked until the build is ready and the tester has acknowledged the required consent state.", true, true, false, "high", "", "upload_configured")
			]
		"survey_app_scroll":
			return [
				_item(page_node_id, "document_layout", "The full document view stays readable and scrollable.", "Section headers, prompts, and answer fields should stack cleanly without hidden or overlapping content."),
				_item(page_node_id, "section_navigation", "Next and Previous section actions move predictably.", "Document-mode navigation should preserve the tester's place and avoid skipping sections unexpectedly.", true, true)
			]
		"survey_app_focus":
			return [
				_item(page_node_id, "focus_layout", "The focused question layout stays clean on the current viewport.", "One question at a time should remain readable with obvious progress and next-step controls."),
				_item(page_node_id, "focus_flow", "Focus navigation preserves answers and context.", "Previous and Next should move cleanly between questions while keeping the current answer state intact.", true, true)
			]
		"survey_app_menu":
			return [
				_item(page_node_id, "menu_actions", "The survey-app menu exposes the expected utilities.", "Menu actions like search, onboarding, settings, summary, export, profile, and QA/report tooling should all be understandable."),
				_item(page_node_id, "menu_navigation", "Menu buttons open the correct overlays.", "Choosing a menu action should open the expected overlay without leaving stale UI open behind it.", true, true)
			]
		"survey_app_search":
			return [
				_item(page_node_id, "search_prompt", "Search tells the tester what can be searched.", "The search overlay should explain what it searches and keep the empty state readable."),
				_item(page_node_id, "search_jump", "Search results jump to the intended question.", "Selecting a result should place the tester at the expected question or section.", true, true)
			]
		"survey_app_onboarding":
			return [
				_item(page_node_id, "onboarding_guidance", "Onboarding explains how to get started without repo knowledge.", "The onboarding surface should explain modes or template choices clearly enough for a first-time tester."),
				_item(page_node_id, "onboarding_exit", "Closing onboarding returns to a usable survey state.", "The tester should be able to leave onboarding without getting stuck or losing the current survey.", true, true)
			]
		"survey_app_settings":
			return [
				_item(page_node_id, "settings_readability", "Settings labels and toggles stay readable.", "Theme, SFX, and privacy/session settings should remain legible and not overlap on the current viewport."),
				_item(page_node_id, "settings_state", "Changing a setting gives immediate feedback.", "Theme and sound-related changes should update the shell in a predictable way.", true, true)
			]
		"survey_app_summary":
			return [
				_item(page_node_id, "summary_cards", "Summary cards render without broken layout.", "The summary overlay should show section/overall results cleanly once the sample answers are loaded."),
				_item(page_node_id, "summary_exports", "Summary copy or PNG actions stay available.", "Summary export actions should be visible and distinct from answer export actions.", true, true)
			]
		"survey_app_export":
			return [
				_item(page_node_id, "export_bundle_actions", "Progress, JSON, and CSV actions are all reachable.", "The export overlay should make it easy to save progress separately from answer-only JSON/CSV outputs."),
				_item(page_node_id, "export_upload_copy", "Upload readiness copy is honest about build configuration.", "If upload is unavailable, the overlay should say so directly instead of showing a misleading ready state.", true, true)
			]
		"survey_app_profile":
			return [
				_item(page_node_id, "profile_snapshot", "The social profile overlay renders a coherent snapshot.", "The profile view should show readable cards and keep the close/export controls visible."),
				_item(page_node_id, "profile_actions", "Profile export actions stay distinct from survey export actions.", "PNG/JSON/CSV profile actions should feel specific to the profile surface.", true, true)
			]
		"survey_app_help":
			return [
				_item(page_node_id, "help_body", "Question help explains the selected question.", "The help overlay should summarize the current question clearly and stay readable."),
				_item(page_node_id, "help_context", "Closing help keeps the tester on the same question.", "The tester should return to the same selected question after leaving help.", true, true)
			]
		"question_gallery":
			return [
				_item(page_node_id, "gallery_coverage", "The question gallery shows every supported question family.", "The gallery should render every mapped question type so the tester can visually confirm coverage.", false, false, true, "normal", "Gallery coverage still needs a human visual scan of the rendered question cards."),
				_item(page_node_id, "gallery_readability", "Gallery cards stay readable and scroll cleanly.", "Question gallery headings, scenes, and examples should remain legible without broken layout.", false, false, true, "normal", "Readability checks still need a human pass across the scrolled gallery.")
			]
	return []

static func _item(page_node_id: String, suffix: String, label: String, expected_result: String, has_auto_action: bool = true, capture_on_pass: bool = true, manual_only: bool = false, severity: String = "normal", manual_reason: String = "", conditional_key: String = "") -> Dictionary:
	return {
		"id": "%s::%s" % [page_node_id, suffix],
		"page_node_id": page_node_id,
		"label": label.strip_edges(),
		"expected_result": expected_result.strip_edges(),
		"focus_action_id": page_node_id,
		"auto_action_id": page_node_id if has_auto_action and not manual_only else "",
		"manual_only": manual_only,
		"manual_reason": manual_reason.strip_edges(),
		"capture_on_pass": capture_on_pass,
		"severity": severity.strip_edges(),
		"conditional_key": conditional_key.strip_edges()
	}
