extends Node

const SURVEY_APP_SCENE := preload("res://Scenes/Main.tscn")
const SURVEY_JOURNEY_SCENE := preload("res://Scenes/SurveyJourney.tscn")
const OVERLAY_MENU_SCENE := preload("res://Scenes/UI/OverlayMenu.tscn")
const CHECKBOX_OPTION_ROW_SCENE := preload("res://Scenes/AnswerPrefabs/CheckboxOptionRow.tscn")
const QUESTION_HELP_OVERLAY_SCENE := preload("res://Scenes/UI/QuestionHelpOverlay.tscn")
const SURVEY_EXPORT_OVERLAY_SCENE := preload("res://Scenes/UI/SurveyExportOverlay.tscn")
const SURVEY_ONBOARDING_OVERLAY_SCENE := preload("res://Scenes/UI/SurveyOnboardingOverlay.tscn")
const SURVEY_PROFILE_OVERLAY_SCENE := preload("res://Scenes/UI/SurveyProfileOverlay.tscn")
const SURVEY_SEARCH_OVERLAY_SCENE := preload("res://Scenes/UI/SurveySearchOverlay.tscn")
const SURVEY_SETTINGS_OVERLAY_SCENE := preload("res://Scenes/UI/SurveySettingsOverlay.tscn")
const SURVEY_SUMMARY_OVERLAY_SCENE := preload("res://Scenes/UI/SurveySummaryOverlay.tscn")
const SURVEY_JOURNEY_FOCUS_STAGE_SCRIPT := preload("res://Scripts/UI/SurveyJourneyFocusStage.gd")
const QUESTION_VIEW_REGISTRY := preload("res://Scripts/UI/QuestionViewRegistry.gd")
const SURVEY_EXPORTER := preload("res://Scripts/Survey/SurveyExporter.gd")
const SURVEY_GAMIFICATION_STORE := preload("res://Scripts/Survey/SurveyGamificationStore.gd")
const SURVEY_QUESTION := preload("res://Scripts/Survey/SurveyQuestion.gd")
const DEFAULT_QUESTION_XP_CONFIG: SurveyQuestionXpConfig = preload("res://Resources/Survey/DefaultQuestionXpConfig.tres")
const SURVEY_SESSION_CACHE := preload("res://Scripts/Survey/SurveySessionCache.gd")
const SURVEY_SAVE_BUNDLE := preload("res://Scripts/Survey/SurveySaveBundle.gd")
const SURVEY_SUBMISSION_BUNDLE := preload("res://Scripts/Survey/SurveySubmissionBundle.gd")
const SURVEY_SUMMARY_ANALYZER := preload("res://Scripts/Survey/SurveySummaryAnalyzer.gd")
const SURVEY_TEMPLATE_LOADER := preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_UPLOAD_AUDIT_STORE := preload("res://Scripts/Survey/SurveyUploadAuditStore.gd")
const DEFAULT_THEME_CATALOG = preload("res://Themes/SurveyThemeCatalog.tres")
const SURVEY_THEME_PALETTE_SCRIPT := preload("res://Scripts/UI/SurveyThemePalette.gd")

const TEMPLATE_PATH := "res://Dev/SurveyTemplates/studio_feedback.json"
const DEBUG_TEMPLATE_PATH := "res://Dev/SurveyTemplates/personal_checkin_debug.json"

var _passed_tests := 0
var _failed_assertions: Array[String] = []
var _current_test_name := ""

func _ready() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	await get_tree().process_frame
	await _run_test("Template Loader And Completion States", _test_template_loader_and_completion_states)
	await _run_test("Save Bundle Round Trip", _test_save_bundle_round_trip)
	await _run_test("Legacy Export Normalization", _test_legacy_export_normalization)
	await _run_test("Exporter Output", _test_exporter_output)
	await _run_test("Identifying Question Scrub Export And Upload", _test_identifying_question_scrub_export_and_upload)
	await _run_test("Upload Audit Anti-Abuse Heuristics", _test_upload_audit_anti_abuse_heuristics)
	await _run_test("Question XP Config Mapping", _test_question_xp_config_mapping)
	await _run_test("Question Chrome Metadata And Reward Overrides", _test_question_chrome_metadata_and_reward_overrides)
	await _run_test("Question Modifiers And Loot Box Matrix", _test_question_modifiers_and_loot_box_matrix)
	await _run_test("Gamification Question Lock XP", _test_gamification_question_lock_xp)
	await _run_test("Gamification Question XP Cap", _test_gamification_question_xp_cap)
	await _run_test("Template Priority And Featured Landing", _test_template_priority_and_featured_landing)
	await _run_test("Journey Lore Empty State And Link Prompt", _test_journey_lore_empty_state_and_link_prompt)
	await _run_test("Survey Questions XP Flow Consistency", _test_survey_questions_xp_flow_consistency)
	await _run_test("Survey App Navigation Awards Locked Question XP", _test_survey_app_navigation_awards_locked_question_xp)
	await _run_test("Journey Navigation Awards Locked Question XP", _test_journey_navigation_awards_locked_question_xp)
	await _run_test("XP Toggle Disabled Suppresses Rewards And HUD", _test_xp_toggle_disabled_suppresses_rewards_and_hud)
	await _run_test("Journey Review Clear Actions And Survey Selection Confirmation", _test_journey_review_clear_actions_and_survey_selection_confirmation)
	await _run_test("Journey Section Outline Overlay", _test_journey_section_outline_overlay)
	await _run_test("Overlay Menu Clear All Button", _test_overlay_menu_clear_all_button)
	await _run_test("Overlay Menu Preview Resolution Picker", _test_overlay_menu_preview_resolution_picker)
	await _run_test("Checkbox Option Row Pre-Ready Configure", _test_checkbox_option_row_pre_ready_configure)
	await _run_test("Journey Focus Stage Detached Sync", _test_journey_focus_stage_detached_sync)
	await _run_test("Theme Catalog And Landing Drawer", _test_theme_catalog_and_landing_drawer)
	await _run_test("UI Layout Safety And Readability", _test_ui_layout_safety_and_readability)

	var total_tests: int = _passed_tests + (_unique_failed_test_count() if _failed_assertions.size() > 0 else 0)
	print("")
	print("CI test summary: %d passed, %d failed, %d total" % [_passed_tests, _unique_failed_test_count(), total_tests])
	if not _failed_assertions.is_empty():
		for failure in _failed_assertions:
			push_error(failure)
	get_tree().quit(0 if _failed_assertions.is_empty() else 1)

func _run_test(test_name: String, test_callable: Callable) -> void:
	_current_test_name = test_name
	var failure_count_before: int = _failed_assertions.size()
	print("[TEST] %s" % test_name)
	await test_callable.call()
	if _failed_assertions.size() == failure_count_before:
		_passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)

func _test_template_loader_and_completion_states() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	_check_equal(survey.id, "studio_feedback", "The built-in studio survey should load with the expected id.")
	_check_equal(survey.template_version, 2, "The built-in studio survey should preserve its template version.")
	_check_equal(survey.schema_hash.length(), 64, "The built-in studio survey should expose a stable SHA-256 schema hash.")
	_check_equal(survey.sections.size(), 3, "The studio survey should keep all three sections.")
	_check_equal(survey.total_questions(), 15, "The studio survey should keep all expected questions.")
	var same_survey_again: SurveyDefinition = _load_studio_feedback()
	if same_survey_again != null:
		_check_equal(same_survey_again.schema_hash, survey.schema_hash, "Reloading the same template should keep the same schema hash.")
	var debug_survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(DEBUG_TEMPLATE_PATH)
	_check_true(debug_survey != null, "The debug survey should also load cleanly for schema-hash comparisons.")
	if debug_survey != null:
		_check_true(debug_survey.schema_hash != survey.schema_hash, "Different templates should not reuse the same schema hash.")

	var participant_section: SurveySection = survey.sections[0]
	var participant_answers := {
		"display_name": "Participant 014",
		"role": "Customer"
	}
	_check_equal(participant_section.required_count(), 2, "The participant profile section should keep two required questions.")
	_check_equal(participant_section.answered_count(participant_answers), 2, "Required participant answers should count as completed.")
	_check_true(participant_section.is_complete(participant_answers), "Optional blanks should not prevent section completion.")

	var matrix_question: SurveyQuestion = _find_question(survey, "topic_ratings")
	if matrix_question != null:
		_check_equal(
			matrix_question.answer_completion_state({"Instructions were clear": "Agree"}),
			SURVEY_QUESTION.ANSWER_STATE_PARTIAL,
			"Matrix questions should report partial completion when only some rows are filled."
		)
		_check_equal(
			matrix_question.answer_completion_state({
				"Instructions were clear": "Agree",
				"Navigation felt predictable": "Neutral",
				"The visual hierarchy made sense": "Strongly agree"
			}),
			SURVEY_QUESTION.ANSWER_STATE_COMPLETE,
			"Matrix questions should report completion when every row is filled."
		)

	var ranked_question: SurveyQuestion = _find_question(survey, "improvement_rank")
	if ranked_question != null:
		_check_equal(
			ranked_question.answer_completion_state(["Navigation"]),
			SURVEY_QUESTION.ANSWER_STATE_PARTIAL,
			"Ranked choice questions should stay partial until every option is ranked."
		)
		_check_equal(
			ranked_question.answer_completion_state(["Navigation", "Question wording", "Visual hierarchy", "Export clarity"]),
			SURVEY_QUESTION.ANSWER_STATE_COMPLETE,
			"Ranked choice questions should become complete once all options are ranked."
		)

func _test_save_bundle_round_trip() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var answers := {
		"display_name": "Participant 014",
		"role": "Customer",
		"topic_ratings": {
			"Instructions were clear": "Agree",
			"Navigation felt predictable": "Neutral",
			"The visual hierarchy made sense": "Strongly agree"
		}
	}
	var preferences := {
		"dark_mode": false,
		"dismissed_onboarding": true,
		"preferred_topic": "visual hierarchy",
		"ui_sfx_volume": 0.5
	}
	var session_state := {
		"current_section_index": 1,
		"selected_question_id": "topic_ratings",
		"session_started_at_unix": 1700000000,
		"first_answer_at_unix": 1700000008,
		"last_answer_at_unix": 1700000042,
		"answer_change_count": 6,
		"restored_progress": true,
		"answer_change_awards": {
			"display_name": 2,
			"topic_ratings": 1
		}
	}

	var json_text: String = SURVEY_SAVE_BUNDLE.build_json_text(survey, TEMPLATE_PATH, answers, preferences, session_state)
	var parsed: Dictionary = SURVEY_SAVE_BUNDLE.parse_json_text(json_text)

	_check_equal(parsed.get("format", ""), SURVEY_SAVE_BUNDLE.FORMAT_ID, "Save bundle payloads should round-trip to the canonical format.")
	_check_equal(parsed.get("survey_id", ""), survey.id, "Save bundle parsing should preserve the survey id.")
	_check_equal(parsed.get("template_path", ""), TEMPLATE_PATH, "Save bundle parsing should preserve the template path.")
	_check_equal(parsed.get("template_version", -1), survey.template_version, "Save bundle parsing should preserve the template version.")
	_check_equal(parsed.get("schema_hash", ""), survey.schema_hash, "Save bundle parsing should preserve the schema hash.")
	_check_equal((parsed.get("answers", {}) as Dictionary).get("display_name", ""), "Participant 014", "Save bundle parsing should preserve answers.")

	var normalized_preferences: Dictionary = parsed.get("preferences", {})
	_check_equal(normalized_preferences.get("use_dark_mode", true), false, "Legacy dark mode preferences should normalize to use_dark_mode.")
	_check_equal(normalized_preferences.get("onboarding_completed", false), true, "Legacy onboarding dismissals should normalize to onboarding_completed.")
	_check_equal(normalized_preferences.get("preferred_topic_tag", ""), "visual_hierarchy", "Topic preferences should normalize to identifier form.")
	_check_equal(snappedf(float(normalized_preferences.get("sfx_volume", 0.0)), 0.01), 0.5, "SFX volume should be preserved through normalization.")

	var normalized_state: Dictionary = parsed.get("session_state", {})
	var normalized_awards: Dictionary = normalized_state.get("answer_change_xp_awards", {})
	_check_equal(normalized_state.get("current_section_index", -1), 1, "Session state should preserve the current section.")
	_check_equal(normalized_state.get("selected_question_id", ""), "topic_ratings", "Session state should preserve the selected question.")
	_check_equal(normalized_state.get("session_started_at_unix", -1), 1700000000, "Session state should preserve the session start timestamp.")
	_check_equal(normalized_state.get("first_answer_at_unix", -1), 1700000008, "Session state should preserve the first-answer timestamp.")
	_check_equal(normalized_state.get("last_answer_at_unix", -1), 1700000042, "Session state should preserve the last-answer timestamp.")
	_check_equal(normalized_state.get("answer_change_count", -1), 6, "Session state should preserve the answer-change count.")
	_check_equal(normalized_state.get("restored_progress", false), true, "Session state should preserve the restored-progress marker.")
	_check_equal(normalized_awards.get("display_name", -1), 2, "Answer-change XP award counts should persist in save bundles.")
	_check_equal(normalized_awards.get("topic_ratings", -1), 1, "Answer-change XP award counts should persist for every question.")

func _test_legacy_export_normalization() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var answers := {
		"display_name": "Participant 014",
		"role": "Customer",
		"focus_areas": ["Clarity", "Accessibility"]
	}
	var export_text: String = SURVEY_EXPORTER.build_json_text(survey, answers)
	var parsed: Dictionary = SURVEY_SAVE_BUNDLE.parse_json_text(export_text)
	var parsed_answers: Dictionary = parsed.get("answers", {})

	_check_equal(parsed.get("survey_id", ""), survey.id, "Legacy export payloads should still normalize to the survey id.")
	_check_equal(parsed.get("template_version", -1), survey.template_version, "Legacy export normalization should preserve the template version.")
	_check_equal(parsed.get("schema_hash", ""), survey.schema_hash, "Legacy export normalization should preserve the schema hash.")
	_check_equal(parsed_answers.get("display_name", ""), "Participant 014", "Legacy export payloads should flatten answers by question id.")
	_check_equal(parsed_answers.get("role", ""), "Customer", "Legacy export payloads should preserve choice answers.")
	_check_equal((parsed_answers.get("focus_areas", []) as Array).size(), 2, "Legacy export payloads should preserve multi-select answers.")

func _test_exporter_output() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var answers := {
		"display_name": "Participant 014",
		"focus_areas": ["Clarity", "Accessibility"],
		"recommendation": true
	}
	var json_text: String = SURVEY_EXPORTER.build_json_text(survey, answers)
	var parsed: Variant = JSON.parse_string(json_text)
	_check_true(parsed is Dictionary, "Exporter JSON output should be valid JSON.")
	if parsed is Dictionary:
		var payload: Dictionary = parsed as Dictionary
		_check_equal(payload.get("survey_id", ""), survey.id, "Exporter JSON output should preserve the survey id.")
		_check_equal(payload.get("template_version", -1), survey.template_version, "Exporter JSON output should preserve the template version.")
		_check_equal(payload.get("schema_hash", ""), survey.schema_hash, "Exporter JSON output should preserve the schema hash.")
		_check_equal((payload.get("answers", []) as Array).size(), survey.sections.size(), "Exporter JSON output should keep one section payload per section.")

	var csv_text: String = SURVEY_EXPORTER.build_csv_text(survey, answers)
	var csv_lines: PackedStringArray = csv_text.strip_edges().split("\n", false)
	_check_equal(csv_lines.size(), survey.total_questions() + 1, "Exporter CSV output should keep one row per question plus a header.")
	_check_true(csv_text.contains("\"display_name\""), "Exporter CSV output should include the display_name question row.")
	_check_true(csv_text.contains("\"Participant 014\""), "Exporter CSV output should include typed answers.")
	_check_true(csv_text.contains("\"Clarity | Accessibility\""), "Exporter CSV output should include multi-select answers as pipe-delimited text.")
	_check_true(csv_text.contains("\"true\""), "Exporter CSV output should serialize boolean answers.")

func _test_identifying_question_scrub_export_and_upload() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return
	_check_true(survey.asks_identifying_info, "The studio survey should advertise that it asks for identifying information.")
	var display_name_question: SurveyQuestion = _find_question(survey, "display_name")
	var email_question: SurveyQuestion = _find_question(survey, "email")
	_check_true(display_name_question != null and display_name_question.asks_identifying_info, "The display name question should be marked as identifying.")
	_check_true(email_question != null and email_question.asks_identifying_info, "The email question should be marked as identifying.")

	var answers := {
		"display_name": "Participant 014",
		"email": "participant@example.com",
		"role": "Customer",
		"recommendation": true
	}

	var scrubbed_save_bundle: String = SURVEY_SAVE_BUNDLE.build_json_text(survey, TEMPLATE_PATH, answers, {}, {}, true)
	var parsed_save_bundle: Dictionary = SURVEY_SAVE_BUNDLE.parse_json_text(scrubbed_save_bundle)
	var scrubbed_answers: Dictionary = parsed_save_bundle.get("answers", {})
	_check_true(not scrubbed_answers.has("display_name"), "Scrubbed save bundles should remove identifying answers.")
	_check_true(not scrubbed_answers.has("email"), "Scrubbed save bundles should remove identifying email answers.")
	_check_equal(scrubbed_answers.get("role", ""), "Customer", "Scrubbed save bundles should preserve non-identifying answers.")

	var scrubbed_export_json: String = SURVEY_EXPORTER.build_json_text(survey, answers, true)
	var parsed_export: Variant = JSON.parse_string(scrubbed_export_json)
	_check_true(parsed_export is Dictionary, "Scrubbed exporter JSON should still be valid JSON.")
	if parsed_export is Dictionary:
		var payload: Dictionary = parsed_export as Dictionary
		_check_equal(payload.get("scrub_identifying_info", false), true, "Scrubbed exporter JSON should declare the scrub option.")
		_check_equal(payload.get("template_version", -1), survey.template_version, "Scrubbed exporter JSON should preserve the template version.")
		_check_equal(payload.get("schema_hash", ""), survey.schema_hash, "Scrubbed exporter JSON should preserve the schema hash.")
		var sections: Array = payload.get("answers", [])
		var found_identifying_response := false
		for section_payload in sections:
			if not (section_payload is Dictionary):
				continue
			for response_payload in ((section_payload as Dictionary).get("responses", []) as Array):
				if not (response_payload is Dictionary):
					continue
				var question_id := str((response_payload as Dictionary).get("question_id", ""))
				if question_id == "display_name" or question_id == "email":
					found_identifying_response = true
		_check_true(not found_identifying_response, "Scrubbed exporter JSON should omit identifying responses.")

	var scrubbed_csv: String = SURVEY_EXPORTER.build_csv_text(survey, answers, true)
	_check_true(not scrubbed_csv.contains("\"display_name\""), "Scrubbed CSV exports should omit identifying question rows.")
	_check_true(not scrubbed_csv.contains("\"participant@example.com\""), "Scrubbed CSV exports should omit identifying email values.")
	_check_true(scrubbed_csv.contains("\"role\""), "Scrubbed CSV exports should keep non-identifying question rows.")

	var session_metadata := {
		"session_duration_seconds": 96,
		"seconds_to_first_answer": 4,
		"seconds_since_last_answer": 2,
		"answer_change_count": 5,
		"distinct_answered_question_count": 4,
		"completed_answered_question_count": 4,
		"answers_per_minute": 2.5,
		"restored_progress": false
	}
	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(survey, TEMPLATE_PATH, answers, {}, "ci-install", true, session_metadata)
	var upload_stats: Dictionary = upload_package.get("stats", {})
	_check_equal(upload_stats.get("scrubbed_identifying_response_count", -1), 2, "Scrubbed upload bundles should count removed identifying responses.")
	var upload_payload: Dictionary = upload_package.get("payload", {})
	var upload_survey: Dictionary = upload_payload.get("survey", {})
	_check_equal(upload_survey.get("template_version", -1), survey.template_version, "Upload bundles should preserve the template version.")
	_check_equal(upload_survey.get("schema_hash", ""), survey.schema_hash, "Upload bundles should preserve the schema hash.")
	var quality: Dictionary = upload_payload.get("quality", {})
	_check_equal(quality.get("session_duration_seconds", -1), 96, "Upload bundles should include session-duration moderation metadata.")
	_check_equal(quality.get("seconds_to_first_answer", -1), 4, "Upload bundles should include time-to-first-answer metadata.")
	_check_equal(quality.get("answer_change_count", -1), 5, "Upload bundles should include answer-change counts for moderation.")
	var privacy: Dictionary = upload_payload.get("privacy", {})
	_check_equal(privacy.get("scrub_identifying_info", false), true, "Upload bundles should record when identifying info was scrubbed.")
	var uploaded_identifying_response := false
	for section_payload in (upload_payload.get("responses", []) as Array):
		if not (section_payload is Dictionary):
			continue
		for response_payload in ((section_payload as Dictionary).get("responses", []) as Array):
			if not (response_payload is Dictionary):
				continue
			var question_id := str((response_payload as Dictionary).get("question_id", ""))
			if question_id == "display_name" or question_id == "email":
				uploaded_identifying_response = true
	_check_true(not uploaded_identifying_response, "Scrubbed upload bundles should omit identifying responses.")

func _test_upload_audit_anti_abuse_heuristics() -> void:
	var audit_path: String = ProjectSettings.globalize_path(SURVEY_UPLOAD_AUDIT_STORE.STORE_PATH)
	var backup_exists: bool = FileAccess.file_exists(audit_path)
	var backup_text := ""
	if backup_exists:
		var backup_file: FileAccess = FileAccess.open(audit_path, FileAccess.READ)
		if backup_file != null:
			backup_text = backup_file.get_as_text()
	_reset_upload_audit_state_file(audit_path)
	var template_key: String = SURVEY_UPLOAD_AUDIT_STORE.template_key_for_values("studio_feedback", 2, "schema-hash-ci")
	SURVEY_UPLOAD_AUDIT_STORE.record_template_load(template_key)
	var fast_session_result: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		"payload-fast",
		5,
		3,
		0,
		10,
		3600,
		{
			"template_key": template_key,
			"session_duration_seconds": 4,
			"min_session_duration_seconds": 20,
			"min_seconds_per_answer": 3.0
		}
	)
	_check_true(not bool(fast_session_result.get("ok", true)), "Fast upload attempts should be blocked by the session-duration guard.")
	_check_true(str(fast_session_result.get("message", "")).contains("Spend at least"), "Fast upload guard messages should explain the minimum session duration.")

	_reset_upload_audit_state_file(audit_path)
	for _load_index in range(4):
		SURVEY_UPLOAD_AUDIT_STORE.record_template_load(template_key)
	var reload_result: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		"payload-reload",
		5,
		3,
		0,
		10,
		3600,
		{
			"template_key": template_key,
			"session_duration_seconds": 120,
			"max_template_loads_per_window": 3,
			"template_load_window_seconds": 3600
		}
	)
	_check_true(not bool(reload_result.get("ok", true)), "Repeated rapid reloads of the same template should be blocked.")
	_check_true(str(reload_result.get("message", "")).contains("reloaded the same survey template"), "Reload guard messages should explain why the upload was blocked.")

	_reset_upload_audit_state_file(audit_path)
	SURVEY_UPLOAD_AUDIT_STORE.record_attempt("accepted-template-1", true, 201, "Accepted", {"template_key": template_key})
	var accepted_limit_result: Dictionary = SURVEY_UPLOAD_AUDIT_STORE.evaluate_attempt(
		"payload-template-limit",
		5,
		3,
		0,
		10,
		3600,
		{
			"template_key": template_key,
			"session_duration_seconds": 120,
			"max_successful_uploads_per_template": 1,
			"successful_uploads_per_template_window_seconds": 86400
		}
	)
	_check_true(not bool(accepted_limit_result.get("ok", true)), "Accepted-upload limits per template should block extra submissions from the same install.")
	_check_true(str(accepted_limit_result.get("message", "")).contains("maximum number of accepted uploads for this survey template"), "Per-template accepted-upload limit messages should be explicit.")

	if backup_exists:
		DirAccess.make_dir_recursive_absolute(audit_path.get_base_dir())
		var restore_file: FileAccess = FileAccess.open(audit_path, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(backup_text)
			restore_file.close()
	else:
		_reset_upload_audit_state_file(audit_path)

func _test_question_xp_config_mapping() -> void:
	var config := _load_default_question_xp_config()
	_check_true(config != null, "The default question XP config should load as a resource.")
	if config == null:
		return

	var matrix_question := SURVEY_QUESTION.new({"id": "matrix_xp", "prompt": "Matrix", "type": "matrix"})
	var short_text_question := SURVEY_QUESTION.new({"id": "short_text_xp", "prompt": "Short text", "type": "short_text"})
	var ranked_question := SURVEY_QUESTION.new({"id": "ranked_xp", "prompt": "Ranked", "type": "ranked_choice"})
	var single_choice_question := SURVEY_QUESTION.new({"id": "single_choice_xp", "prompt": "Single", "type": "single_choice"})

	_check_equal(config.xp_for_question(matrix_question), config.matrix_xp, "Matrix questions should read their XP from the matrix config slot.")
	_check_equal(config.xp_for_question(short_text_question), config.short_text_xp, "Short text questions should read their XP from the short-text config slot.")
	_check_equal(config.xp_for_type(SURVEY_QUESTION.TYPE_RANKED_CHOICE), config.ranked_choice_xp, "Ranked-choice questions should read their XP from the ranked-choice config slot.")
	_check_true(config.matrix_xp > config.single_choice_xp, "Matrix questions should be worth more XP than single-choice questions by default.")
	_check_true(config.ranked_choice_xp > config.short_text_xp or config.long_text_xp > config.single_choice_xp, "More complex question types should be configured above simpler ones.")
	_check_true(config.max_configured_xp() >= config.xp_for_question(ranked_question), "The config should report a max XP at least as high as its ranked-choice value.")

func _test_question_chrome_metadata_and_reward_overrides() -> void:
	var config := _load_default_question_xp_config()
	_check_true(config != null, "The default question XP config should be available for reward override checks.")
	if config == null:
		return

	var reward_sprite_path := "res://Assets/UI/Icons/state-complete.svg"
	var reward_survey := SurveyDefinition.new({
		"id": "reward_metadata_test",
		"title": "Reward Metadata Test",
		"sections": [
			{
				"id": "reward_section",
				"title": "Reward Section",
				"questions": [
					{
						"id": "rewarded_question",
						"prompt": "Which answer should get a custom reward?",
						"type": "single_choice",
						"required": true,
						"options": ["This one", "Not this one"],
						"reward_count": 12,
						"reward_sprite": reward_sprite_path
					},
					{
						"id": "optional_question",
						"prompt": "Should this one explicitly pay out nothing?",
						"type": "boolean",
						"reward_count": 0
					}
				]
			}
		]
	})
	var rewarded_question: SurveyQuestion = _find_question(reward_survey, "rewarded_question")
	var optional_question: SurveyQuestion = _find_question(reward_survey, "optional_question")
	_check_true(rewarded_question.reward_count_configured, "Rewarded questions should remember that their reward count was explicitly configured.")
	_check_equal(rewarded_question.resolved_reward_count(4), 12, "Explicit question reward counts should override fallback XP values.")
	_check_equal(config.xp_for_question(rewarded_question), 12, "Question XP config should prefer the per-question reward count when present.")
	_check_true(optional_question.reward_count_configured, "A zero reward should still count as an explicit override.")
	_check_equal(config.xp_for_question(optional_question), 0, "Explicit zero reward counts should suppress the default type-based XP.")

	var save_payload: Variant = JSON.parse_string(SURVEY_SAVE_BUNDLE.build_json_text(reward_survey, "res://Dev/SurveyTemplates/starter_template.json", {}))
	_check_true(save_payload is Dictionary, "Save bundle exports should stay valid JSON when question metadata is embedded.")
	if save_payload is Dictionary:
		var reward_catalog_entry: Dictionary = _find_question_catalog_entry((save_payload as Dictionary).get("question_catalog", []) as Array, "rewarded_question")
		var optional_catalog_entry: Dictionary = _find_question_catalog_entry((save_payload as Dictionary).get("question_catalog", []) as Array, "optional_question")
		_check_equal(reward_catalog_entry.get("required", false), true, "Save bundle question catalogs should preserve required flags.")
		_check_equal(reward_catalog_entry.get("reward_count", -1), 12, "Save bundle question catalogs should preserve per-question reward counts.")
		_check_equal(reward_catalog_entry.get("reward_sprite", ""), reward_sprite_path, "Save bundle question catalogs should preserve per-question reward sprites.")
		_check_equal(optional_catalog_entry.get("reward_count", -1), 0, "Save bundle question catalogs should preserve explicit zero reward overrides.")

	var exporter_payload: Variant = JSON.parse_string(SURVEY_EXPORTER.build_json_text(reward_survey, {}))
	_check_true(exporter_payload is Dictionary, "Answer exports should stay valid JSON when question metadata is embedded.")
	if exporter_payload is Dictionary:
		var rewarded_response: Dictionary = _find_response_payload((exporter_payload as Dictionary).get("answers", []) as Array, "rewarded_question")
		var optional_response: Dictionary = _find_response_payload((exporter_payload as Dictionary).get("answers", []) as Array, "optional_question")
		_check_equal(rewarded_response.get("required", false), true, "Answer exports should preserve required flags for each response row.")
		_check_equal(rewarded_response.get("reward_count", -1), 12, "Answer exports should preserve per-question reward counts.")
		_check_equal(rewarded_response.get("reward_sprite", ""), reward_sprite_path, "Answer exports should preserve per-question reward sprites.")
		_check_equal(optional_response.get("reward_count", -1), 0, "Answer exports should preserve explicit zero reward overrides.")

	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(
		reward_survey,
		"res://Dev/SurveyTemplates/starter_template.json",
		{"rewarded_question": "This one"},
		{},
		"ci-install"
	)
	var upload_rewarded_response: Dictionary = _find_response_payload(upload_package.get("payload", {}).get("responses", []) as Array, "rewarded_question")
	_check_equal(upload_rewarded_response.get("required", false), true, "Upload bundles should preserve required flags for each submitted response.")
	_check_equal(upload_rewarded_response.get("reward_count", -1), 12, "Upload bundles should preserve per-question reward counts.")
	_check_equal(upload_rewarded_response.get("reward_sprite", ""), reward_sprite_path, "Upload bundles should preserve per-question reward sprites.")

	var view := QUESTION_VIEW_REGISTRY.instantiate_for_question(rewarded_question)
	_check_true(view != null, "Reward metadata checks should be able to instantiate a question view.")
	if view == null:
		return
	add_child(view)
	view.set_presentation_mode(SurveyQuestionView.PRESENTATION_DOCUMENT)
	view.configure(rewarded_question)
	await _await_layout_frames()
	var requirement_label: Label = view.find_child("QuestionRequirementLabel", true, false) as Label
	_check_true(requirement_label != null, "Question views should expose a dedicated required/optional label in the shared chrome.")
	if requirement_label != null:
		_check_equal(requirement_label.text, "Required", "Question chrome should label required questions explicitly.")
	view.configure(optional_question)
	await _await_layout_frames()
	requirement_label = view.find_child("QuestionRequirementLabel", true, false) as Label
	if requirement_label != null:
		_check_equal(requirement_label.text, "Optional", "Question chrome should label optional questions explicitly.")
	view.queue_free()
	await _await_layout_frames()

func _test_question_modifiers_and_loot_box_matrix() -> void:
	var modifier_survey := SurveyDefinition.new({
		"id": "modifier_metadata_test",
		"title": "Modifier Metadata Test",
		"sections": [
			{
				"id": "modifier_section",
				"title": "Modifier Section",
				"questions": [
					{
						"id": "loot_box_question",
						"prompt": "Spin for your mood rating.",
						"type": "matrix",
						"rows": ["Energy level"],
						"options": ["Low", "Medium", "High"],
						"modifier": {
							"key": "loot_box_matrix",
							"accept_hint_text": "Tap to lock it in",
							"fatigue_reroll_threshold": 4
						}
					}
				]
			}
		]
	})
	var matrix_question: SurveyQuestion = _find_question(modifier_survey, "loot_box_question")
	_check_equal(matrix_question.modifier_key, "loot_box_matrix", "Matrix questions should preserve their modifier key.")
	_check_equal(str(matrix_question.modifier_settings.get("accept_hint_text", "")), "Tap to lock it in", "Matrix modifier settings should preserve custom prompt text.")

	var save_payload: Variant = JSON.parse_string(SURVEY_SAVE_BUNDLE.build_json_text(modifier_survey, DEBUG_TEMPLATE_PATH, {}))
	_check_true(save_payload is Dictionary, "Save bundles should stay valid JSON when modifier metadata is embedded.")
	if save_payload is Dictionary:
		var modifier_catalog_entry: Dictionary = _find_question_catalog_entry((save_payload as Dictionary).get("question_catalog", []) as Array, "loot_box_question")
		_check_equal(modifier_catalog_entry.get("modifier", ""), "loot_box_matrix", "Save bundle question catalogs should preserve modifier keys.")
		_check_equal(((modifier_catalog_entry.get("modifier_settings", {}) as Dictionary).get("accept_hint_text", "")), "Tap to lock it in", "Save bundle question catalogs should preserve modifier settings.")

	var exporter_payload: Variant = JSON.parse_string(SURVEY_EXPORTER.build_json_text(modifier_survey, {}))
	_check_true(exporter_payload is Dictionary, "Answer exports should stay valid JSON when modifier metadata is embedded.")
	if exporter_payload is Dictionary:
		var modifier_response: Dictionary = _find_response_payload((exporter_payload as Dictionary).get("answers", []) as Array, "loot_box_question")
		_check_equal(modifier_response.get("modifier", ""), "loot_box_matrix", "Answer exports should preserve modifier keys for each response row.")
		_check_equal(((modifier_response.get("modifier_settings", {}) as Dictionary).get("accept_hint_text", "")), "Tap to lock it in", "Answer exports should preserve modifier settings for each response row.")

	var upload_package: Dictionary = SURVEY_SUBMISSION_BUNDLE.build_package(
		modifier_survey,
		DEBUG_TEMPLATE_PATH,
		{
			"loot_box_question": {
				"Energy level": "High"
			}
		},
		{},
		"ci-install"
	)
	var upload_modifier_response: Dictionary = _find_response_payload(upload_package.get("payload", {}).get("responses", []) as Array, "loot_box_question")
	_check_equal(upload_modifier_response.get("modifier", ""), "loot_box_matrix", "Upload bundles should preserve modifier keys for each submitted response.")
	_check_equal(((upload_modifier_response.get("modifier_settings", {}) as Dictionary).get("accept_hint_text", "")), "Tap to lock it in", "Upload bundles should preserve modifier settings for each submitted response.")

	var view := QUESTION_VIEW_REGISTRY.instantiate_for_question(matrix_question)
	_check_true(view != null, "Modifier checks should be able to instantiate a matrix question view.")
	if view == null:
		return
	add_child(view)
	view.set_presentation_mode(SurveyQuestionView.PRESENTATION_JOURNEY_FOCUS)
	view.configure(matrix_question, {})
	await _await_layout_frames()

	var mobile_list := view.get_node_or_null("Panel/Stack/MobileList") as VBoxContainer
	var grid_scroll := view.get_node_or_null("Panel/Stack/GridScroll") as ScrollContainer
	_check_true(mobile_list != null and mobile_list.visible, "Loot-box matrix modifiers should force the cycle selector layout.")
	_check_true(grid_scroll != null and not grid_scroll.visible, "Loot-box matrix modifiers should hide the grid layout while active.")
	if mobile_list == null:
		view.queue_free()
		await _await_layout_frames()
		return

	var fatigue_messages: Array[String] = []
	view.modifier_fatigue_detected.connect(func(_question_id: String, _modifier_key: String, message: String) -> void:
		fatigue_messages.append(message)
	)
	var row_name: String = matrix_question.rows[0]
	view.call("_on_mobile_matrix_cycle", row_name, 1)
	await _await_layout_frames()
	var pending_value: Variant = view.current_value
	_check_true(pending_value is Dictionary and (pending_value as Dictionary).is_empty(), "Loot-box matrix modifiers should not commit an answer until the center panel is tapped.")

	var row_panel := mobile_list.get_child(0) as PanelContainer
	var row_stack := row_panel.get_child(0) as VBoxContainer if row_panel != null and row_panel.get_child_count() > 0 else null
	var selector_row := row_stack.get_child(1) as HBoxContainer if row_stack != null and row_stack.get_child_count() > 1 else null
	var value_panel := selector_row.get_child(1) as PanelContainer if selector_row != null and selector_row.get_child_count() > 1 else null
	_check_true(value_panel != null, "Loot-box matrix modifiers should expose a tappable center panel.")
	if value_panel != null:
		var saw_accept_hint := false
		var saw_pending_option := false
		for label_node in value_panel.find_children("*", "Label", true, false):
			var label := label_node as Label
			if label == null:
				continue
			if label.text == "Tap to lock it in":
				saw_accept_hint = true
			if matrix_question.options.has(label.text):
				saw_pending_option = true
		_check_true(saw_accept_hint, "Loot-box matrix modifiers should show their custom accept hint.")
		_check_true(saw_pending_option, "Loot-box matrix modifiers should show a pending randomized answer before commit.")
		var tap_event := InputEventMouseButton.new()
		tap_event.pressed = true
		tap_event.button_index = MOUSE_BUTTON_LEFT
		view.call("_on_mobile_matrix_value_panel_gui_input", tap_event, row_name)
		await _await_layout_frames()
		var committed_value := view.current_value as Dictionary
		_check_true(committed_value.has(row_name), "Tapping the center panel should commit the pending loot-box answer.")
		_check_true(matrix_question.options.has(str(committed_value.get(row_name, ""))), "Committed loot-box answers should still be valid matrix options.")

	for _attempt in range(6):
		view.call("_on_mobile_matrix_cycle", row_name, 1)
	await _await_layout_frames()
	_check_true(not fatigue_messages.is_empty(), "Repeatedly fighting the loot-box modifier should emit a fatigue signal.")

	view.set_question_modifiers_enabled(false)
	view.set_presentation_mode(SurveyQuestionView.PRESENTATION_DOCUMENT)
	view.size = Vector2(1280.0, 720.0)
	view.refresh_responsive_layout(Vector2(1280.0, 720.0))
	await _await_layout_frames()
	_check_true(grid_scroll != null and grid_scroll.visible, "Disabling question modifiers should return matrix questions to their standard layout when space allows.")
	_check_true(mobile_list != null and not mobile_list.visible, "Disabling question modifiers should hide the modifier-driven cycle selector.")
	view.queue_free()
	await _await_layout_frames()

func _test_gamification_question_lock_xp() -> void:
	var question := SURVEY_QUESTION.new({
		"id": "question_lock_test",
		"prompt": "How much XP should this lock-in award?",
		"type": "short_text"
	})
	var base_xp := 6
	var profile: Dictionary = SURVEY_GAMIFICATION_STORE.default_profile()
	var reward_key := "ci_test::question_lock_test"

	var first: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, base_xp, Vector2.ZERO, reward_key, base_xp)
	profile = first.get("profile", profile)
	var first_stats: Dictionary = profile.get("stats", {})
	var first_totals: Dictionary = profile.get("question_xp_totals", {})
	_check_equal(first.get("xp_awarded", -1), base_xp, "The first lock-in should award the configured question XP.")
	_check_equal(first_stats.get("questions_locked", -1), 1, "The first lock-in should increment the questions_locked stat.")
	_check_equal(first_totals.get(reward_key, -1), base_xp, "The first lock-in should persist the question total under its reward key.")

	var second: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, base_xp, Vector2.ZERO, reward_key, base_xp)
	profile = second.get("profile", profile)
	var second_stats: Dictionary = profile.get("stats", {})
	_check_equal(second.get("xp_awarded", -1), 0, "A locked question should not award XP twice once its question cap is filled.")
	_check_equal(second_stats.get("questions_locked", -1), 1, "Repeated lock-ins should not increment questions_locked again.")

func _test_gamification_question_xp_cap() -> void:
	var question := SURVEY_QUESTION.new({
		"id": "xp_cap_test",
		"prompt": "Can this question be farmed forever?",
		"type": "short_text",
		"required": true
	})
	var profile: Dictionary = SURVEY_GAMIFICATION_STORE.default_profile()
	var question_reward_key := "ci_test::xp_cap_test"
	var question_xp_cap := 6
	var requested_xp := 10

	var locked_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, requested_xp, Vector2.ZERO, question_reward_key, question_xp_cap)
	profile = locked_result.get("profile", profile)
	var question_totals: Dictionary = profile.get("question_xp_totals", {})
	_check_equal(locked_result.get("xp_awarded", -1), question_xp_cap, "Question XP caps should clamp lock-in awards to the configured maximum.")
	_check_equal(profile.get("xp_total", -1), question_xp_cap, "Question XP caps should clamp total earned XP for that question.")
	_check_equal(question_totals.get(question_reward_key, -1), question_xp_cap, "Question XP totals should persist at the configured cap.")

func _test_template_priority_and_featured_landing() -> void:
	var debug_survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(DEBUG_TEMPLATE_PATH)
	_check_true(debug_survey != null, "The personal check-in debug survey should load cleanly.")
	if debug_survey == null:
		return
	_check_equal(debug_survey.priority, 100, "The debug survey should declare a high template priority.")
	_check_true(debug_survey.single_survey_mode, "The debug survey should enable single-survey landing mode.")
	_check_equal(debug_survey.total_questions(), 13, "The debug survey should include one question for every supported question type.")
	var covered_types: Dictionary = {}
	for section in debug_survey.sections:
		for question in section.questions:
			covered_types[String(question.type)] = true
	var expected_types := [
		String(SURVEY_QUESTION.TYPE_SHORT_TEXT),
		String(SURVEY_QUESTION.TYPE_LONG_TEXT),
		String(SURVEY_QUESTION.TYPE_SINGLE_CHOICE),
		String(SURVEY_QUESTION.TYPE_MULTI_CHOICE),
		String(SURVEY_QUESTION.TYPE_BOOLEAN),
		String(SURVEY_QUESTION.TYPE_SCALE),
		String(SURVEY_QUESTION.TYPE_RANKED_CHOICE),
		String(SURVEY_QUESTION.TYPE_DROPDOWN),
		String(SURVEY_QUESTION.TYPE_EMAIL),
		String(SURVEY_QUESTION.TYPE_NUMBER),
		String(SURVEY_QUESTION.TYPE_DATE),
		String(SURVEY_QUESTION.TYPE_NPS),
		String(SURVEY_QUESTION.TYPE_MATRIX)
	]
	for expected_type in expected_types:
		_check_true(covered_types.has(expected_type), "The debug survey should cover the '%s' question type." % expected_type)
	var gratitude_question: SurveyQuestion = _find_question(debug_survey, "gratitude_notes")
	if gratitude_question != null:
		_check_true(gratitude_question.help_markdown_text().contains("long-form"), "Question help markdown should survive template normalization.")

	var template_summaries: Array[Dictionary] = SURVEY_TEMPLATE_LOADER.list_available_templates()
	_check_true(not template_summaries.is_empty(), "Template discovery should find at least one available survey template.")
	var previous_priority := INF
	for summary in template_summaries:
		var summary_priority := int(summary.get("priority", 0))
		_check_true(summary_priority <= previous_priority, "Template summaries should be sorted by descending priority.")
		previous_priority = summary_priority
	if template_summaries.is_empty():
		return

	var featured_summary: Dictionary = template_summaries[0]
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)

	var take_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/LandingView/LandingActions/TakeSurveyButton")
	var character_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/LandingView/LandingActions/CharacterButton")
	var browse_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/LandingView/LandingBrowseSurveysButton")
	var featured_label: Label = journey.get_node_or_null("Margin/MainPanel/Stack/LandingView/LandingFeaturedSurveyLabel")
	_check_true(take_button != null, "Journey landing should expose the primary survey button.")
	_check_true(character_button != null, "Journey landing should expose the Character button.")
	_check_true(browse_button != null, "Journey landing should expose the browse-other-surveys button.")
	_check_true(featured_label != null, "Journey landing should expose the featured survey caption.")
	if take_button != null and character_button != null and browse_button != null and featured_label != null:
		_check_equal(character_button.text, "Character", "Journey landing should label the social-profile entry point as Character.")
		character_button.emit_signal("pressed")
		await _await_layout_frames(2)
		var profile_overlay: CanvasLayer = journey.get_node_or_null("ProfileOverlay") as CanvasLayer
		_check_true(profile_overlay != null and profile_overlay.visible, "Pressing Character on the landing screen should open the social profile overlay.")
		if profile_overlay != null and profile_overlay.has_method("close_profile"):
			profile_overlay.call("close_profile")
			await _await_layout_frames(1)
		if bool(featured_summary.get("single_survey_mode", false)):
			_check_equal(take_button.text, "Start Survey", "Single-survey mode should relabel the landing action to Start Survey.")
			_check_true(browse_button.visible, "Single-survey mode should expose a browse-other-surveys escape hatch.")
			_check_true(featured_label.visible, "Single-survey mode should show the featured survey label.")
			_check_true(featured_label.text.contains(str(featured_summary.get("title", ""))), "The featured survey label should name the active featured survey.")
			journey.call("_on_take_survey_pressed")
			await _await_layout_frames(2)
			_check_equal(str(journey.get("_current_view")), "focus", "Start Survey should jump straight into focus mode in single-survey mode.")
			_check_equal(str(journey.get("_current_template_path")), str(featured_summary.get("path", "")), "Start Survey should load the featured survey template.")
			_check_equal(int(journey.get("_focus_index")), 0, "Start Survey should begin at the first question.")
		else:
			_check_equal(take_button.text, "Take Survey", "Normal landing mode should keep the Take Survey label.")
			_check_true(not browse_button.visible, "Normal landing mode should hide the browse-other-surveys button.")
			_check_true(not featured_label.visible, "Normal landing mode should hide the featured survey caption.")

	journey.queue_free()
	await _await_layout_frames()

func _test_journey_lore_empty_state_and_link_prompt() -> void:
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)

	var lore_survey: SurveyDefinition = SurveyDefinition.new({
		"id": "lore_prompt_test",
		"title": "Lore Prompt Survey",
		"description": "A focused lore prompt test.",
		"lore_url": "https://example.com/lore",
		"lore_url_label": "Lore Notes",
		"sections": [{
			"id": "check_in",
			"title": "Check In",
			"questions": [{
				"id": "today_status",
				"prompt": "How are you doing today?",
				"type": "short_text"
			}]
		}]
	})
	journey.set("survey", lore_survey)
	journey.call("_show_view", "lore")
	await _await_layout_frames(2)

	var empty_label: Label = journey.get_node_or_null("Margin/MainPanel/Stack/LoreView/LoreBody/LoreEmptyPanel/LoreEmptyStack/LoreEmptyLabel")
	var link_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/LoreView/LoreBody/LoreEmptyPanel/LoreEmptyStack/LoreLinkButton")
	_check_true(empty_label != null, "Journey lore view should expose the empty-state message.")
	_check_true(link_button != null, "Journey lore view should expose the lore link icon button.")
	if empty_label != null:
		_check_equal(empty_label.text, "There is no lore at this time.", "Journey lore view should show the empty lore message.")
	if link_button != null:
		_check_true(link_button.visible, "Journey lore view should show the lore link button when a lore URL exists.")
		_check_true(not link_button.disabled, "Journey lore view should enable the lore link button when a lore URL exists.")
		link_button.emit_signal("pressed")
		await _await_layout_frames(2)

	var prompt_overlay: Control = journey.get_node_or_null("LoreLinkPromptOverlay") as Control
	var prompt_heading: Label = journey.get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/TopRow/HeadingLabel") as Label
	var prompt_body: Label = journey.get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/BodyLabel") as Label
	var prompt_close_button: Button = journey.get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/TopRow/CloseButton") as Button
	var prompt_open_button: Button = journey.get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/ActionRow/OpenButton") as Button
	var prompt_copy_button: Button = journey.get_node_or_null("LoreLinkPromptOverlay/Center/Panel/Stack/ActionRow/CopyButton") as Button
	_check_true(prompt_overlay != null and prompt_overlay.visible, "Pressing the lore link button should open the lore link prompt.")
	_check_true(prompt_heading != null, "The lore link prompt should expose a heading label.")
	_check_true(prompt_body != null, "The lore link prompt should expose a body label.")
	_check_true(prompt_close_button != null, "The lore link prompt should expose a close button in the top row.")
	_check_true(prompt_open_button != null and prompt_copy_button != null, "The lore link prompt should expose both Open URL and Copy URL actions.")
	if prompt_heading != null:
		_check_true(prompt_heading.text.contains("Lore Notes"), "The lore link prompt heading should reflect the configured lore URL label.")
	if prompt_body != null:
		_check_true(prompt_body.text.contains("https://example.com/lore"), "The lore link prompt should include the configured lore URL.")
	if prompt_close_button != null:
		prompt_close_button.emit_signal("pressed")
		await _await_layout_frames(2)
		_check_true(prompt_overlay != null and not prompt_overlay.visible, "Closing the lore link prompt should hide it.")

	var no_link_survey: SurveyDefinition = SurveyDefinition.new({
		"id": "lore_prompt_no_link",
		"title": "Loreless Survey",
		"sections": [{
			"id": "section_one",
			"title": "Section One",
			"questions": [{
				"id": "q1",
				"prompt": "What is one thing on your mind?",
				"type": "short_text"
			}]
		}]
	})
	journey.set("survey", no_link_survey)
	journey.call("_refresh_lore_view")
	await _await_layout_frames(2)
	if link_button != null:
		_check_true(not link_button.visible, "Journey lore view should hide the lore link button when no lore URL is configured.")

	journey.queue_free()
	await _await_layout_frames()

func _test_survey_questions_xp_flow_consistency() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var config := _load_default_question_xp_config()
	_check_true(config != null, "The default question XP config should load for survey-wide XP consistency checks.")
	if config == null:
		return
	var covered_question_ids: PackedStringArray = PackedStringArray()
	for section in survey.sections:
		for question in section.questions:
			covered_question_ids.append(question.id)
			var profile: Dictionary = SURVEY_GAMIFICATION_STORE.default_profile()
			var question_reward_key := "ci_consistency::%s" % question.id
			var partial_answer: Variant = _sample_partial_answer(question)
			var complete_answer: Variant = _sample_complete_answer(question)
			var expected_question_xp: int = config.xp_for_question(question)
			_check_equal(
				question.answer_completion_state(complete_answer),
				SURVEY_QUESTION.ANSWER_STATE_COMPLETE,
				"Question '%s' should treat the generated complete answer as complete." % question.id
			)
			if partial_answer != null:
				_check_equal(
					question.answer_completion_state(partial_answer),
					SURVEY_QUESTION.ANSWER_STATE_PARTIAL,
					"Question '%s' should treat the generated partial answer as partial." % question.id
				)
				var partial_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, expected_question_xp, Vector2.ZERO, "%s::partial" % question_reward_key, expected_question_xp)
				_check_equal(partial_result.get("xp_awarded", -1), expected_question_xp, "Question '%s' should pay its configured XP when a partial answer is locked in." % question.id)
			var lock_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, expected_question_xp, Vector2.ZERO, question_reward_key, expected_question_xp)
			profile = lock_result.get("profile", profile)
			_check_equal(
				lock_result.get("xp_awarded", -1),
				expected_question_xp,
				"Question '%s' should award its configured lock-in XP on the first committed answer." % question.id
			)
			var repeated_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, question, expected_question_xp, Vector2.ZERO, question_reward_key, expected_question_xp)
			profile = repeated_result.get("profile", profile)
			_check_equal(
				repeated_result.get("xp_awarded", -1),
				0,
				"Question '%s' should not award lock-in XP more than once for the same question reward key." % question.id
			)
			var final_stats: Dictionary = profile.get("stats", {})
			var final_question_totals: Dictionary = profile.get("question_xp_totals", {})
			_check_equal(
				profile.get("xp_total", -1),
				expected_question_xp,
				"Question '%s' should end with exactly its configured question XP after one lock-in." % question.id
			)
			_check_equal(
				final_question_totals.get(question_reward_key, -1),
				expected_question_xp,
				"Question '%s' should track its total earned XP under the reward key." % question.id
			)
			_check_equal(
				final_stats.get("questions_locked", -1),
				1,
				"Question '%s' should only increment questions_locked once." % question.id
			)

	_check_equal(covered_question_ids.size(), survey.total_questions(), "The XP consistency test should cover every question in the built-in survey.")

func _test_survey_app_navigation_awards_locked_question_xp() -> void:
	var app: Control = SURVEY_APP_SCENE.instantiate()
	app.set("use_saved_dev_data", false)
	app.set("xp_system_enabled", true)
	SURVEY_GAMIFICATION_STORE.save_profile(SURVEY_GAMIFICATION_STORE.default_profile())
	add_child(app)
	await _await_layout_frames(2)

	var survey: SurveyDefinition = app.get("survey")
	_check_true(survey != null, "The survey app scene should load a survey for navigation XP checks.")
	if survey == null or survey.sections.is_empty() or survey.sections[0].questions.is_empty():
		app.queue_free()
		await _await_layout_frames()
		return
	var config: SurveyQuestionXpConfig = app.get("question_xp_config") as SurveyQuestionXpConfig
	var hub: Node = app.get_node_or_null("SurveyGamificationHub")
	_check_true(hub != null, "The survey app scene should expose a gamification hub for navigation XP checks.")
	if hub == null:
		app.queue_free()
		await _await_layout_frames()
		return
	var first_question: SurveyQuestion = survey.sections[0].questions[0]
	var answer: Variant = _sample_complete_answer(first_question)
	app.call("_on_answer_changed", first_question.id, answer)
	await _await_layout_frames(2)

	var profile_before: Dictionary = hub.call("current_profile")
	_check_equal(int(profile_before.get("xp_total", -1)), 0, "Editing an answer in SurveyApp should not award XP before navigation.")

	app.call("_go_to_next_section")
	await _await_layout_frames(3)

	var profile_after: Dictionary = hub.call("current_profile")
	var expected_xp: int = config.xp_for_question(first_question) if config != null else 0
	_check_equal(int(profile_after.get("xp_total", -1)), expected_xp, "SurveyApp should award the configured question XP when navigating away with Next/Previous.")

	app.queue_free()
	await _await_layout_frames()

func _test_journey_navigation_awards_locked_question_xp() -> void:
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	journey.set("xp_system_enabled", true)
	SURVEY_GAMIFICATION_STORE.save_profile(SURVEY_GAMIFICATION_STORE.default_profile())
	add_child(journey)
	await _await_layout_frames(2)

	var loaded: bool = bool(journey.call("_load_survey_from_path", TEMPLATE_PATH))
	_check_true(loaded, "SurveyJourney should load the built-in survey for navigation XP checks.")
	if not loaded:
		journey.queue_free()
		await _await_layout_frames()
		return
	journey.call("_clear_all_answers")
	await _await_layout_frames(2)
	journey.call("_start_focus_from_section", 0, "")
	await _await_layout_frames(3)

	var question: SurveyQuestion = journey.call("_current_focus_question")
	var config: SurveyQuestionXpConfig = journey.get("question_xp_config") as SurveyQuestionXpConfig
	var hub: Node = journey.get_node_or_null("SurveyGamificationHub")
	_check_true(question != null, "SurveyJourney should expose an active focus question for navigation XP checks.")
	if question == null or hub == null:
		journey.queue_free()
		await _await_layout_frames()
		return

	journey.call("_on_focus_answer_changed", question.id, _sample_complete_answer(question))
	await _await_layout_frames(2)
	var profile_before: Dictionary = hub.call("current_profile")
	_check_equal(int(profile_before.get("xp_total", -1)), 0, "Editing a Journey answer should not award XP before navigation.")

	journey.call("_on_focus_next_pressed")
	await _await_layout_frames(4)

	var profile_after: Dictionary = hub.call("current_profile")
	var expected_xp: int = config.xp_for_question(question) if config != null else 0
	_check_equal(int(profile_after.get("xp_total", -1)), expected_xp, "SurveyJourney should award the configured question XP when navigating away with Next/Previous.")

	journey.queue_free()
	await _await_layout_frames()

func _test_xp_toggle_disabled_suppresses_rewards_and_hud() -> void:
	SURVEY_GAMIFICATION_STORE.save_profile(SURVEY_GAMIFICATION_STORE.default_profile())

	var app: Control = SURVEY_APP_SCENE.instantiate()
	app.set("use_saved_dev_data", false)
	add_child(app)
	await _await_layout_frames(2)

	_check_true(not bool(app.get("xp_system_enabled")), "SurveyApp should keep the XP system disabled by default during playtesting.")
	_check_true(app.get_node_or_null("SurveyGamificationHub") == null, "SurveyApp should not spawn the gamification hub when XP is disabled.")
	_check_true(app.get_node_or_null("SurveyGamificationHud") == null, "SurveyApp should not show the bottom XP HUD when XP is disabled.")
	var app_survey: SurveyDefinition = app.get("survey")
	if app_survey != null and not app_survey.sections.is_empty() and not app_survey.sections[0].questions.is_empty():
		var first_question: SurveyQuestion = app_survey.sections[0].questions[0]
		app.call("_on_answer_changed", first_question.id, _sample_complete_answer(first_question))
		await _await_layout_frames(2)
		app.call("_go_to_next_section")
		await _await_layout_frames(3)
		var app_snapshot: Dictionary = app.call("_build_profile_snapshot")
		_check_equal(int(app_snapshot.get("xp_total", -1)), 0, "SurveyApp should not grant XP when the XP system is disabled.")
	app.queue_free()
	await _await_layout_frames()

	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)

	_check_true(not bool(journey.get("xp_system_enabled")), "SurveyJourney should keep the XP system disabled by default during playtesting.")
	_check_true(journey.get_node_or_null("SurveyGamificationHub") == null, "SurveyJourney should not spawn the gamification hub when XP is disabled.")
	_check_true(journey.get_node_or_null("SurveyGamificationHud") == null, "SurveyJourney should not show the bottom XP HUD when XP is disabled.")
	var loaded: bool = bool(journey.call("_load_survey_from_path", TEMPLATE_PATH))
	_check_true(loaded, "SurveyJourney should still load surveys while XP is disabled.")
	if loaded:
		journey.call("_clear_all_answers")
		await _await_layout_frames(2)
		journey.call("_start_focus_from_section", 0, "")
		await _await_layout_frames(3)
		var focus_xp_stack: Control = journey.get_node_or_null("Margin/MainPanel/Stack/FocusView/FocusNavRow/FocusNavSpacer/FocusXpAnchor/FocusXpStack") as Control
		_check_true(focus_xp_stack != null, "SurveyJourney should keep the focus XP anchor available for visibility checks.")
		if focus_xp_stack != null:
			_check_true(not focus_xp_stack.visible, "SurveyJourney should hide the inline focus XP bar when XP is disabled.")
		var question: SurveyQuestion = journey.call("_current_focus_question")
		if question != null:
			journey.call("_on_focus_answer_changed", question.id, _sample_complete_answer(question))
			await _await_layout_frames(2)
			journey.call("_on_focus_next_pressed")
			await _await_layout_frames(4)
		var journey_snapshot: Dictionary = journey.call("_build_profile_snapshot")
		_check_equal(int(journey_snapshot.get("xp_total", -1)), 0, "SurveyJourney should not grant XP when the XP system is disabled.")
	journey.queue_free()
	await _await_layout_frames()

func _test_journey_review_clear_actions_and_survey_selection_confirmation() -> void:
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)

	var loaded: bool = bool(journey.call("_load_survey_from_path", TEMPLATE_PATH))
	_check_true(loaded, "SurveyJourney should load the built-in survey for review clear-action checks.")
	if not loaded:
		journey.queue_free()
		await _await_layout_frames()
		return

	journey.call("_clear_all_answers")
	await _await_layout_frames(2)
	journey.call("_start_focus_from_section", 0, "")
	await _await_layout_frames(2)

	var question: SurveyQuestion = journey.call("_current_focus_question")
	_check_true(question != null, "SurveyJourney should expose a focus question for review clear-action checks.")
	if question == null:
		journey.queue_free()
		await _await_layout_frames()
		return

	journey.call("_on_focus_answer_changed", question.id, _sample_complete_answer(question))
	await _await_layout_frames(2)
	journey.call("_open_review_view")
	await _await_layout_frames(3)

	var review_clear_button: Button = journey.find_child("ClearAnswerButton", true, false) as Button
	var review_type_label: Label = journey.find_child("QuestionTypeLabel", true, false) as Label
	_check_true(review_clear_button != null, "The review screen should expose a clear-answer button on question cards.")
	_check_true(review_type_label != null, "The review screen should expose a question-type label on question cards.")
	if review_clear_button != null:
		_check_true(not review_clear_button.disabled, "The review clear-answer button should enable when the question has a saved answer.")
		review_clear_button.emit_signal("pressed")
		await _await_layout_frames(2)
		var review_confirm: ConfirmationDialog = journey.get_node_or_null("ActionConfirmationDialog") as ConfirmationDialog
		_check_true(review_confirm != null and review_confirm.visible, "Pressing a review clear-answer button should open the confirmation dialog.")
		if review_confirm != null:
			_check_true(review_confirm.dialog_text.contains(question.prompt.strip_edges()), "The review clear confirmation should mention the current question.")
	if review_type_label != null:
		var expected_color := SurveyStyle.question_type_color(question.type).lightened(0.1)
		_check_equal(review_type_label.get_theme_color("font_color"), expected_color, "Review question type labels should keep the same accent color used while answering.")

	var template_survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(TEMPLATE_PATH)
	if template_survey != null and not template_survey.sections.is_empty() and not template_survey.sections[0].questions.is_empty():
		var first_question: SurveyQuestion = template_survey.sections[0].questions[0]
		SURVEY_SESSION_CACHE.clear_session(template_survey, TEMPLATE_PATH)
		SURVEY_SESSION_CACHE.save_session(template_survey, TEMPLATE_PATH, {first_question.id: _sample_complete_answer(first_question)}, {}, {})
		journey.set("_selected_template_path", TEMPLATE_PATH)
		journey.call("_show_view", "survey_selection")
		await _await_layout_frames(2)
		var import_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionImportButton")
		var export_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionExportButton")
		var clear_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionManageGrid/SurveySelectionClearButton")
		var choose_button: Button = journey.get_node_or_null("Margin/MainPanel/Stack/SurveySelectionView/SurveySelectionActionRow/SurveySelectionNextButton")
		_check_true(import_button != null and export_button != null and clear_button != null and choose_button != null, "The survey selection view should expose its manage buttons and primary choose button.")
		if import_button != null and export_button != null and clear_button != null and choose_button != null:
			_check_true(import_button.custom_minimum_size.y < choose_button.custom_minimum_size.y, "Survey selection manage buttons should stay visually smaller than the primary Choose button.")
			_check_true(export_button.custom_minimum_size.y < choose_button.custom_minimum_size.y, "Survey selection export should stay visually smaller than the primary Choose button.")
			_check_true(clear_button.custom_minimum_size.y < choose_button.custom_minimum_size.y, "Survey selection clear should stay visually smaller than the primary Choose button.")
			journey.call("_confirm_clear_selected_template_answers")
			await _await_layout_frames(2)
			var selection_confirm: ConfirmationDialog = journey.get_node_or_null("ActionConfirmationDialog") as ConfirmationDialog
			_check_true(selection_confirm != null and selection_confirm.visible, "Clearing saved answers from survey selection should require confirmation first.")
			if selection_confirm != null:
				_check_true(selection_confirm.dialog_text.contains(template_survey.title), "The survey selection clear confirmation should name the selected survey.")
		SURVEY_SESSION_CACHE.clear_session(template_survey, TEMPLATE_PATH)

	journey.queue_free()
	await _await_layout_frames()

func _test_journey_section_outline_overlay() -> void:
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)

	journey.set("_selected_template_path", TEMPLATE_PATH)
	journey.set("_selection_purpose", StringName("survey"))
	journey.call("_advance_from_survey_selection")
	await _await_layout_frames(4)

	var current_view: StringName = journey.get("_current_view")
	_check_equal(String(current_view), "focus", "DIVE IN should open Journey focus mode directly.")

	var outline_toggle: Button = journey.find_child("FocusOutlineToggleButton", true, false) as Button
	var outline_overlay: Control = journey.find_child("FocusOutlineOverlay", true, false) as Control
	var outline_panel: SectionOutlinePanel = journey.find_child("FocusOutlinePanel", true, false) as SectionOutlinePanel
	_check_true(outline_toggle != null and outline_overlay != null and outline_panel != null, "Journey focus mode should expose the section outline toggle and overlay.")
	if outline_toggle != null:
		_check_true(not outline_toggle.button_pressed, "Journey should keep the section outline toggle off when you first dive in.")
	if outline_overlay != null:
		_check_true(not outline_overlay.visible, "The section outline overlay should stay hidden on initial Journey focus entry.")
	if outline_toggle != null:
		outline_toggle.emit_signal("toggled", true)
		await _await_layout_frames(2)
	if outline_overlay != null:
		_check_true(outline_overlay.visible, "Toggling the section outline on should show the overlay.")
	if outline_toggle != null:
		_check_true(outline_toggle.button_pressed, "Toggling the section outline on should press the toggle button.")

	var loaded_survey: SurveyDefinition = journey.get("survey")
	if loaded_survey != null and loaded_survey.sections.size() > 1:
		journey.call("_on_focus_outline_navigate_requested", 1, "")
		await _await_layout_frames(3)
		_check_equal(int(journey.get("_focus_start_section_index")), 1, "Selecting a section in the outline should jump Journey focus to that section.")
		var focus_section_label: Label = journey.get_node_or_null("Margin/MainPanel/Stack/FocusView/FocusSectionLabel") as Label
		if focus_section_label != null:
			_check_equal(focus_section_label.text, loaded_survey.sections[1].display_title(1), "The focus header should update after jumping from the section outline.")

	journey.call("_set_focus_outline_visible", false)
	await _await_layout_frames(2)
	if outline_toggle != null:
		_check_true(not outline_toggle.button_pressed, "Closing the section outline should also release the toggle button state.")
	if outline_overlay != null:
		_check_true(not outline_overlay.visible, "Closing the section outline should hide the overlay.")

	journey.queue_free()
	await _await_layout_frames()

func _test_overlay_menu_clear_all_button() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var overlay: OverlayMenu = OVERLAY_MENU_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame

	overlay.open_menu(
		survey,
		0,
		{"display_name": "Participant 014"},
		0.35,
		false,
		{
			"show_section_tools": true,
			"show_restart": true
		}
	)
	await get_tree().process_frame

	var clear_all_button: Button = overlay.get_node_or_null("Bounds/Center/Panel/PanelScroll/Stack/SectionClearAllButton")
	_check_true(clear_all_button != null, "The overlay menu scene should expose the bottom section clear-all button.")
	if clear_all_button != null:
		_check_true(clear_all_button.visible, "The bottom clear-all button should be visible when section tools are enabled.")
		_check_true(not clear_all_button.disabled, "The bottom clear-all button should enable when stored answers exist.")
		_check_equal(clear_all_button.text, "Clear All Answers", "The bottom clear-all button should use the clear-all label.")

	overlay.queue_free()
	await get_tree().process_frame

func _test_overlay_menu_preview_resolution_picker() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var overlay: OverlayMenu = OVERLAY_MENU_SCENE.instantiate()
	add_child(overlay)
	await get_tree().process_frame

	overlay.open_menu(
		survey,
		0,
		{},
		0.35,
		false,
		{
			"show_preview_controls": true,
			"preview_mode_options": [
				{"value": "auto", "label": "Auto"},
				{"value": "desktop", "label": "Desktop"}
			],
			"preview_mode": "auto",
			"preview_resolution_options": [
				{"value": "", "label": "Current Window"},
				{"value": "phone_390x844", "label": "Phone 390x844"},
				{"value": "desktop_1600x900", "label": "Desktop 1600x900"}
			],
			"preview_resolution": "desktop_1600x900"
		}
	)
	await get_tree().process_frame

	var resolution_picker: OptionButton = overlay.get_node_or_null("Bounds/Center/Panel/PanelScroll/Stack/PreviewResolutionRow/PreviewResolutionPicker")
	_check_true(resolution_picker != null, "The overlay menu should expose the preview resolution picker when preview controls are enabled.")
	if resolution_picker != null:
		_check_equal(resolution_picker.get_item_count(), 3, "The preview resolution picker should populate from the latest menu options when the menu opens.")
		_check_true(not resolution_picker.disabled, "The preview resolution picker should stay enabled when presets are provided.")
		_check_equal(str(resolution_picker.get_item_metadata(resolution_picker.get_selected_id())), "desktop_1600x900", "The preview resolution picker should select the requested preset.")

	overlay.queue_free()
	await get_tree().process_frame

func _test_checkbox_option_row_pre_ready_configure() -> void:
	var row: CheckboxOptionRow = CHECKBOX_OPTION_ROW_SCENE.instantiate()
	_check_true(row != null, "The checkbox option row scene should instantiate for lifecycle coverage.")
	if row == null:
		return

	row.configure("I feel rested today", true)
	add_child(row)
	await _await_layout_frames(2)

	var control := row.get_primary_control() as CheckBox
	_check_true(control != null, "Checkbox option rows should resolve their primary control even when configured before entering the tree.")
	if control != null:
		_check_equal(control.text, "I feel rested today", "Pre-ready checkbox configuration should preserve the option label.")
		_check_true(control.button_pressed, "Pre-ready checkbox configuration should preserve the pressed state.")
	_check_true(row.is_checked(), "Checkbox option rows should report checked state after pre-ready configuration.")

	row.queue_free()
	await get_tree().process_frame

	var fallback_row := CheckboxOptionRow.new()
	fallback_row.configure("I can still answer this", true)
	add_child(fallback_row)
	await _await_layout_frames(2)

	var fallback_control := fallback_row.get_primary_control() as CheckBox
	_check_true(fallback_control != null, "Checkbox option rows should create a fallback checkbox when configured before any child exists.")
	if fallback_control != null:
		_check_equal(fallback_control.text, "I can still answer this", "Fallback checkbox rows should preserve their configured label.")
		_check_true(fallback_control.button_pressed, "Fallback checkbox rows should preserve their configured pressed state.")
	_check_true(fallback_row.is_checked(), "Fallback checkbox rows should still report checked state.")

	fallback_row.queue_free()
	await get_tree().process_frame

func _test_journey_focus_stage_detached_sync() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return
	var first_section: SurveySection = survey.sections[0]
	_check_true(first_section.questions.size() >= 2, "The built-in survey should expose at least two questions for focus-stage sync coverage.")
	if first_section.questions.size() < 2:
		return

	var focus_stage: SurveyJourneyFocusStage = SURVEY_JOURNEY_FOCUS_STAGE_SCRIPT.new()
	add_child(focus_stage)
	await get_tree().process_frame

	var first_question: SurveyQuestion = first_section.questions[0]
	var second_question: SurveyQuestion = first_section.questions[1]
	focus_stage.prepare_questions([first_question, second_question], {
		first_question.id: _sample_complete_answer(first_question),
		second_question.id: _sample_complete_answer(second_question)
	}, Vector2(1024.0, 768.0))
	_check_true(focus_stage.show_question(first_question.id), "The focus stage should show the first prepared question.")
	await _await_layout_frames()
	_check_true(focus_stage.show_question(second_question.id), "The focus stage should swap to the second prepared question.")
	await _await_layout_frames()

	focus_stage.sync_answers({})
	await _await_layout_frames()

	var active_view := focus_stage.active_view()
	_check_true(active_view != null, "The focus stage should keep an active view after syncing detached question views.")
	if active_view != null:
		_check_equal(active_view.question.id, second_question.id, "Syncing detached question views should preserve the currently active question.")
		_check_equal(active_view.current_value, second_question.default_value, "Syncing detached question views should still refresh the active view to the cleared answer state.")

	focus_stage.queue_free()
	await get_tree().process_frame

func _test_theme_catalog_and_landing_drawer() -> void:
	var catalog = DEFAULT_THEME_CATALOG
	_check_true(catalog != null, "The default theme catalog resource should load.")
	if catalog == null:
		return
	var themes: Array = catalog.available_themes()
	_check_true(themes.size() >= 4, "The default theme catalog should expose the starter theme collection.")
	var sunset_theme = catalog.resolve_theme("sunset")
	_check_true(sunset_theme != null, "The theme catalog should resolve named themes by id.")
	if sunset_theme != null:
		_check_equal(sunset_theme.display_title(), "Sunset Jam", "The sunset theme should keep its configured display name.")
		_check_equal(sunset_theme.preview_gradient_colors(true).size(), 3, "Theme previews should expose a three-stop gradient.")

	var palette: SurveyThemePalette = SURVEY_THEME_PALETTE_SCRIPT.new()
	var imported: bool = palette.import_from_text("""
mode_name = Candy
background = #101820
surface = #182a3a
accent = #ff7a90
accent_alt = #ffd166
success = #4fd1a1
highlight_gold = #c9a227
soft_white = #ffffff88
""")
	_check_true(imported, "Theme palettes should accept copy-paste palette imports.")
	_check_equal(palette.mode_name, "Candy", "Palette imports should preserve the imported mode label.")
	_check_equal(palette.background.to_html(true), Color("#101820").to_html(true), "Palette imports should apply background colors.")
	_check_equal(palette.accent.to_html(true), Color("#ff7a90").to_html(true), "Palette imports should apply accent colors.")
	_check_equal(palette.highlight_gold.to_html(true), Color("#c9a227").to_html(true), "Palette imports should apply highlight colors.")
	_check_equal(palette.soft_white.to_html(true), Color("#ffffff88").to_html(true), "Palette imports should preserve alpha values.")

	var journey: Node = SURVEY_JOURNEY_SCENE.instantiate()
	add_child(journey)
	await _await_layout_frames(2)
	var theme_drawer := journey.get_node_or_null("ThemeDrawer")
	_check_true(theme_drawer != null, "The journey landing scene should create the theme drawer.")
	if theme_drawer != null:
		_check_true(bool(theme_drawer.visible), "The theme drawer should be visible on the landing screen.")
		_check_true(bool(theme_drawer.call("has_themes")), "The theme drawer should receive the available theme list.")
		journey.call("_show_view", StringName("survey_selection"))
		await _await_layout_frames()
		_check_true(not bool(theme_drawer.visible), "The theme drawer should hide when the user leaves the landing screen.")
		journey.call("_show_view", StringName("landing"))
		await _await_layout_frames()
		_check_true(bool(theme_drawer.visible), "The theme drawer should return when the landing screen is shown again.")
	journey.queue_free()
	await _await_layout_frames()

func _test_ui_layout_safety_and_readability() -> void:
	var survey: SurveyDefinition = _load_studio_feedback()
	if survey == null:
		return

	var answers: Dictionary = _sample_complete_answers(survey)
	var templates: Array[Dictionary] = SURVEY_TEMPLATE_LOADER.list_available_templates()
	var summary: Dictionary = SURVEY_SUMMARY_ANALYZER.build_summary(survey, answers)
	var profile_snapshot: Dictionary = _sample_profile_snapshot(survey, answers)
	var help_question := SURVEY_QUESTION.new({
		"id": "layout_help_question",
		"prompt": "How likely are you to recommend this survey shell to a teammate after working through a complete session?",
		"description": "Use this help card to check whether long headings, subtitles, and body copy still fit cleanly across compact and wide layouts.",
		"type": "long_text",
		"help_markdown": "[b]What this asks[/b]\nThis prompt should stay readable in overlays without collapsing into one character per line.\n\n[b]Why it matters[/b]\nThe UI should preserve comfortable margins, readable wrapping, and reachable buttons even on smaller screens."
	})
	await _run_ui_layout_case("SurveyApp Scroll", SURVEY_APP_SCENE)
	await _run_ui_layout_case("SurveyApp Focus", SURVEY_APP_SCENE, Callable(self, "_configure_survey_app_focus_layout_case"))
	await _run_ui_layout_case("SurveyJourney Landing", SURVEY_JOURNEY_SCENE)
	await _run_ui_layout_case("SurveyJourney Focus", SURVEY_JOURNEY_SCENE, Callable(self, "_configure_survey_journey_focus_layout_case"))
	await _run_ui_layout_case("Overlay Menu", OVERLAY_MENU_SCENE, Callable(self, "_configure_overlay_menu_layout_case").bind(survey, answers))
	await _run_ui_layout_case("Onboarding Overlay", SURVEY_ONBOARDING_OVERLAY_SCENE, Callable(self, "_configure_onboarding_overlay_layout_case").bind(survey, templates))
	await _run_ui_layout_case("Export Overlay", SURVEY_EXPORT_OVERLAY_SCENE, Callable(self, "_configure_export_overlay_layout_case").bind(survey))
	await _run_ui_layout_case("Summary Overlay", SURVEY_SUMMARY_OVERLAY_SCENE, Callable(self, "_configure_summary_overlay_layout_case").bind(summary))

func _load_studio_feedback() -> SurveyDefinition:
	var survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(TEMPLATE_PATH)
	_check_true(survey != null, "The built-in studio survey template should load without validation errors.")
	return survey

func _load_default_question_xp_config() -> SurveyQuestionXpConfig:
	return DEFAULT_QUESTION_XP_CONFIG as SurveyQuestionXpConfig

func _find_question(survey: SurveyDefinition, question_id: String) -> SurveyQuestion:
	if survey == null:
		return null
	for section in survey.sections:
		for question in section.questions:
			if question.id == question_id:
				return question
	_fail("Expected to find question '%s' in the loaded survey." % question_id)
	return null

func _find_question_catalog_entry(question_catalog: Array, question_id: String) -> Dictionary:
	for section_value in question_catalog:
		if not (section_value is Dictionary):
			continue
		var questions: Array = ((section_value as Dictionary).get("questions", []) as Array)
		for question_value in questions:
			if not (question_value is Dictionary):
				continue
			var question_payload: Dictionary = question_value as Dictionary
			if str(question_payload.get("question_id", "")).strip_edges() == question_id:
				return question_payload
	_fail("Expected to find question catalog entry '%s'." % question_id)
	return {}

func _find_response_payload(section_payloads: Array, question_id: String) -> Dictionary:
	for section_value in section_payloads:
		if not (section_value is Dictionary):
			continue
		var responses: Array = ((section_value as Dictionary).get("responses", []) as Array)
		for response_value in responses:
			if not (response_value is Dictionary):
				continue
			var response_payload: Dictionary = response_value as Dictionary
			if str(response_payload.get("question_id", "")).strip_edges() == question_id:
				return response_payload
	_fail("Expected to find response payload '%s'." % question_id)
	return {}

func _sample_complete_answers(survey: SurveyDefinition) -> Dictionary:
	var answers := {}
	if survey == null:
		return answers
	for section in survey.sections:
		for question in section.questions:
			answers[question.id] = _sample_complete_answer(question)
	return answers

func _sample_profile_snapshot(survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	var profile: Dictionary = SURVEY_GAMIFICATION_STORE.default_profile()
	if survey != null and not survey.sections.is_empty() and not survey.sections[0].questions.is_empty():
		var first_question: SurveyQuestion = survey.sections[0].questions[0]
		var reward_key := "layout_profile::%s" % first_question.id
		var config := _load_default_question_xp_config()
		var question_xp: int = config.xp_for_question(first_question) if config != null else 6
		var question_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_question_lock(profile, first_question, question_xp, Vector2.ZERO, reward_key, question_xp)
		profile = question_result.get("profile", profile)
		var section_result: Dictionary = SURVEY_GAMIFICATION_STORE.award_section_complete(profile, survey.sections[0].id, survey.sections[0].title)
		profile = section_result.get("profile", profile)
	return SURVEY_GAMIFICATION_STORE.build_profile_snapshot(profile, survey, answers)

func _sample_complete_answer(question: SurveyQuestion) -> Variant:
	match question.type:
		SURVEY_QUESTION.TYPE_SHORT_TEXT:
			return "Sample short answer"
		SURVEY_QUESTION.TYPE_LONG_TEXT:
			return "Sample long answer with enough detail to count as filled."
		SURVEY_QUESTION.TYPE_EMAIL:
			return "tester@example.com"
		SURVEY_QUESTION.TYPE_DATE:
			return "2026-04-01"
		SURVEY_QUESTION.TYPE_SINGLE_CHOICE, SURVEY_QUESTION.TYPE_DROPDOWN:
			return question.options[0] if not question.options.is_empty() else "Option A"
		SURVEY_QUESTION.TYPE_MULTI_CHOICE:
			return [question.options[0]] if not question.options.is_empty() else ["Option A"]
		SURVEY_QUESTION.TYPE_BOOLEAN:
			return true
		SURVEY_QUESTION.TYPE_SCALE:
			return clampi(question.max_value, question.min_value, question.max_value)
		SURVEY_QUESTION.TYPE_NPS:
			return clampi(9, question.min_value, question.max_value)
		SURVEY_QUESTION.TYPE_NUMBER:
			return clampi(25, question.min_value, question.max_value)
		SURVEY_QUESTION.TYPE_RANKED_CHOICE:
			var ranked_answer: Array = []
			for option in question.options:
				ranked_answer.append(option)
			return ranked_answer
		SURVEY_QUESTION.TYPE_MATRIX:
			var matrix_answer: Dictionary = {}
			var selection: String = question.options[0] if not question.options.is_empty() else "Yes"
			for row_name in question.rows:
				matrix_answer[row_name] = selection
			return matrix_answer
	return "Fallback answer"

func _sample_partial_answer(question: SurveyQuestion) -> Variant:
	match question.type:
		SURVEY_QUESTION.TYPE_RANKED_CHOICE:
			return [question.options[0]] if not question.options.is_empty() else ["Option A"]
		SURVEY_QUESTION.TYPE_MATRIX:
			if question.rows.is_empty():
				return null
			var matrix_answer := {}
			matrix_answer[question.rows[0]] = question.options[0] if not question.options.is_empty() else "Yes"
			return matrix_answer
	return null

func _reset_upload_audit_state_file(audit_path: String) -> void:
	if FileAccess.file_exists(audit_path):
		DirAccess.remove_absolute(audit_path)

func _check_true(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s Expected %s, got %s." % [message, var_to_str(expected), var_to_str(actual)])

func _run_ui_layout_case(case_name: String, scene: PackedScene, configure: Callable = Callable()) -> void:
	var node: Node = scene.instantiate()
	add_child(node)
	await _await_layout_frames()
	if configure.is_valid():
		configure.call(node)
		await _await_layout_frames(2)
	_assert_ui_layout_sane(case_name, node, get_viewport().get_visible_rect())
	node.queue_free()
	await _await_layout_frames()

func _await_layout_frames(frame_count: int = 2) -> void:
	for _frame in range(max(1, frame_count)):
		await get_tree().process_frame

func _configure_survey_app_focus_layout_case(node: Node) -> void:
	node.call("_set_focus_mode_active", true)
	node.call("_refresh_focus_mode", true)

func _configure_survey_journey_focus_layout_case(node: Node) -> void:
	node.call("_start_focus_from_section", 0, "")

func _configure_overlay_menu_layout_case(node: Node, survey: SurveyDefinition, answers: Dictionary) -> void:
	node.call("open_menu", survey, 0, answers, 0.35, false, {"show_section_tools": true, "show_restart": true})

func _configure_search_overlay_layout_case(node: Node, survey: SurveyDefinition) -> void:
	node.call("open_search", survey)
	node.call("_refresh_results_for_query", "navigation")

func _configure_settings_overlay_layout_case(node: Node) -> void:
	node.call("open_settings", true, 0.55, true, true, true)

func _configure_onboarding_overlay_layout_case(node: Node, survey: SurveyDefinition, templates: Array[Dictionary]) -> void:
	node.call("open_onboarding", survey, "navigation", "participant", TEMPLATE_PATH, templates, "focus")

func _configure_export_overlay_layout_case(node: Node, survey: SurveyDefinition) -> void:
	node.call("open_export_menu", {
		"survey_title": survey.title,
		"progress_summary": "Save or load the full progress bundle, including preferences and where the respondent left off in the current run.",
		"answer_summary": "Copy or save answer-only exports for review, debugging, analytics, or manual follow-up without reopening the full editing session.",
		"save_progress_enabled": true,
		"load_progress_enabled": true,
		"save_progress_label": "Save Progress JSON",
		"load_progress_label": "Load Progress JSON",
		"save_json_label": "Save JSON",
		"save_csv_label": "Save CSV",
		"upload_ready": true,
		"upload_busy": false,
		"consent_required": true,
		"upload_usage_summary": "Internal playtest review and moderated research synthesis.",
		"upload_destination_name": "In a Bottle Research Intake",
		"upload_destination_url": "https://example.com/surveys/intake/research-upload",
		"upload_reason_summary": "Route sanitized exports to the review queue without exposing a raw local project file.",
		"upload_metadata_summary": "Anonymous install identifier, upload timestamps, answer counts, current template id, and a payload hash are included for moderation and duplicate detection.",
		"upload_ready_message": "Review the disclosure, confirm consent, then submit the sanitized response bundle.",
		"upload_status_text": "Ready when you are.",
		"upload_response_text": JSON.stringify({"status": "queued", "message": "Upload accepted for review.", "ticket": "layout-smoke-001"}, "\t")
	})

func _configure_profile_overlay_layout_case(node: Node, snapshot: Dictionary) -> void:
	node.call("open_profile", snapshot)

func _configure_summary_overlay_layout_case(node: Node, summary: Dictionary) -> void:
	node.call("open_summary", summary, "optimistic, clear-eyed, thoughtful")

func _configure_help_overlay_layout_case(node: Node, question: SurveyQuestion) -> void:
	node.call("open_help", question, true)

func _assert_ui_layout_sane(case_name: String, root_node: Node, viewport_rect: Rect2) -> void:
	for control in _collect_layout_controls(root_node):
		_assert_control_bounds(case_name, root_node, control, viewport_rect)
		if control is BaseButton:
			_assert_button_click_target(case_name, root_node, control as BaseButton, viewport_rect)
		if control is Label:
			_assert_label_readability(case_name, root_node, control as Label)
		elif control is RichTextLabel:
			_assert_rich_text_readability(case_name, root_node, control as RichTextLabel)

func _collect_layout_controls(root_node: Node) -> Array[Control]:
	var collected: Array[Control] = []
	_collect_layout_controls_recursive(root_node, collected)
	return collected

func _collect_layout_controls_recursive(node: Node, collected: Array[Control]) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.is_visible_in_tree() and _should_inspect_layout_control(control):
			collected.append(control)
	for child in node.get_children():
		_collect_layout_controls_recursive(child, collected)

func _should_inspect_layout_control(control: Control) -> bool:
	return control is PanelContainer or control is ScrollContainer or control is Label or control is RichTextLabel or control is LineEdit or control is TextEdit or control is BaseButton or control is HSlider

func _assert_control_bounds(case_name: String, root_node: Node, control: Control, viewport_rect: Rect2) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	if control_rect.size.x <= 1.0 or control_rect.size.y <= 1.0:
		_fail("%s: %s has a collapsed size of %s." % [case_name, _layout_node_label(root_node, control), var_to_str(control_rect.size)])
		return
	var visible_region: Rect2 = _effective_visible_region(control, viewport_rect)
	var visible_rect: Rect2 = control_rect.intersection(visible_region)
	var visible_area: float = _rect_area(visible_rect)
	var control_area: float = _rect_area(control_rect)
	if _has_scroll_ancestor(control) and visible_area <= 0.0:
		return
	if visible_area <= 0.0:
		_fail("%s: %s is outside the visible viewport bounds." % [case_name, _layout_node_label(root_node, control)])
		return
	var visible_ratio: float = visible_area / maxf(control_area, 1.0)
	var minimum_ratio: float = 0.6 if control is BaseButton or control is LineEdit or control is TextEdit or control is HSlider else 0.35
	if not _has_scroll_ancestor(control) and visible_ratio < minimum_ratio:
		_fail("%s: %s is too clipped for its role (%.0f%% visible)." % [case_name, _layout_node_label(root_node, control), visible_ratio * 100.0])

func _assert_button_click_target(case_name: String, root_node: Node, button: BaseButton, viewport_rect: Rect2) -> void:
	if button.disabled:
		return
	var button_rect: Rect2 = button.get_global_rect()
	var visible_region: Rect2 = _effective_visible_region(button, viewport_rect)
	var visible_rect: Rect2 = button_rect.intersection(visible_region)
	var has_scroll_ancestor: bool = _has_scroll_ancestor(button)
	if has_scroll_ancestor and _rect_area(visible_rect) <= 0.0:
		return
	if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_fail("%s: %s is visible but ignores mouse input." % [case_name, _layout_node_label(root_node, button)])
	if button_rect.size.x < 24.0 or button_rect.size.y < 24.0:
		_fail("%s: %s is too small to be a reliable click target at %s." % [case_name, _layout_node_label(root_node, button), var_to_str(button_rect.size)])
	var center_point: Vector2 = button_rect.get_center()
	if not has_scroll_ancestor and not visible_region.has_point(center_point):
		_fail("%s: %s does not have its center inside the visible interaction region." % [case_name, _layout_node_label(root_node, button)])

func _assert_label_readability(case_name: String, root_node: Node, label: Label) -> void:
	var text: String = _normalized_layout_text(label.text)
	if text.length() < 8:
		return
	var line_count: int = max(label.get_line_count(), label.get_visible_line_count())
	if line_count < 4:
		return
	var average_chars_per_line: float = float(text.length()) / float(max(line_count, 1))
	if average_chars_per_line < 2.0:
		_fail("%s: %s wraps too aggressively (%d characters over %d lines)." % [case_name, _layout_node_label(root_node, label), text.length(), line_count])

func _assert_rich_text_readability(case_name: String, root_node: Node, label: RichTextLabel) -> void:
	var parsed_text: String = _normalized_layout_text(label.get_parsed_text() if label.has_method("get_parsed_text") else "")
	if parsed_text.length() < 8:
		return
	var line_count: int = max(label.get_line_count(), label.get_visible_line_count())
	if line_count < 4:
		return
	var average_chars_per_line: float = float(parsed_text.length()) / float(max(line_count, 1))
	if average_chars_per_line < 2.0:
		_fail("%s: %s wraps rich text too aggressively (%d characters over %d lines)." % [case_name, _layout_node_label(root_node, label), parsed_text.length(), line_count])

func _effective_visible_region(control: Control, viewport_rect: Rect2) -> Rect2:
	var region: Rect2 = viewport_rect
	var current: Node = control.get_parent()
	while current != null:
		if current is Control:
			var current_control: Control = current as Control
			if current_control.clip_contents or current_control is ScrollContainer:
				region = region.intersection(current_control.get_global_rect())
		current = current.get_parent()
	return region

func _has_scroll_ancestor(control: Control) -> bool:
	var current: Node = control.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false

func _rect_area(rect: Rect2) -> float:
	return maxf(rect.size.x, 0.0) * maxf(rect.size.y, 0.0)

func _normalized_layout_text(raw_text: String) -> String:
	return raw_text.strip_edges().replace(" ", "").replace("\n", "").replace("\t", "")

func _layout_node_label(root_node: Node, node: Node) -> String:
	if root_node == null or node == null:
		return "<unknown>"
	if root_node == node:
		return root_node.name
	return "%s/%s" % [root_node.name, String(root_node.get_path_to(node))]

func _fail(message: String) -> void:
	_failed_assertions.append("[%s] %s" % [_current_test_name, message])

func _unique_failed_test_count() -> int:
	var unique_test_names: Dictionary = {}
	for failure in _failed_assertions:
		var prefix_end: int = failure.find("]")
		if prefix_end == -1:
			continue
		var test_name: String = failure.substr(1, prefix_end - 1)
		unique_test_names[test_name] = true
	return unique_test_names.size()
