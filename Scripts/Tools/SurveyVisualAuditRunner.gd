class_name SurveyVisualAuditRunner
extends Node

const SURVEY_VISUAL_AUDIT_CATALOG = preload("res://Scripts/Tools/SurveyVisualAuditCatalog.gd")
const SURVEY_UI_FLOW_CATALOG = preload("res://Scripts/Tools/SurveyUiFlowCatalog.gd")
const SURVEY_UI_FLOW_FIXTURES = preload("res://Scripts/Tools/SurveyUiFlowFixtures.gd")
const SURVEY_UI_FLOW_CANVAS_SCRIPT = preload("res://Scripts/Tools/SurveyUiFlowCanvas.gd")
const SURVEY_APP_SCENE = preload("res://Scenes/Main.tscn")
const SURVEY_JOURNEY_SCENE = preload("res://Scenes/SurveyJourney.tscn")
const QUESTION_TYPE_GALLERY_SCENE = preload("res://Scenes/UI/QuestionTypeGallery.tscn")
const SURVEY_SUMMARY_OVERLAY_SCENE = preload("res://Scenes/UI/SurveySummaryOverlay.tscn")
const SURVEY_PROFILE_OVERLAY_SCENE = preload("res://Scenes/UI/SurveyProfileOverlay.tscn")
const SURVEY_ANSWER_REVIEW_OVERLAY_SCRIPT = preload("res://Scripts/UI/SurveyAnswerReviewOverlay.gd")
const SURVEY_ANSWER_WRAPPED_CARD_SCRIPT = preload("res://Scripts/UI/SurveyAnswerWrappedCard.gd")
const SURVEY_ANSWER_REVIEW = preload("res://Scripts/Survey/SurveyAnswerReview.gd")
const SURVEY_QA_OVERLAY_SCRIPT = preload("res://Scripts/UI/SurveyQaOverlay.gd")
const SURVEY_QA_CHECKLIST_CATALOG = preload("res://Scripts/QA/SurveyQaChecklistCatalog.gd")
const SURVEY_PLAYTEST_FEEDBACK_OVERLAY_SCRIPT = preload("res://Scripts/UI/SurveyPlaytestFeedbackOverlay.gd")
const QUESTION_VIEW_REGISTRY = preload("res://Scripts/UI/QuestionViewRegistry.gd")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")
const PUBLIC_LAUNCH_TEMPLATE_PATH := "res://Dev/SurveyTemplates/maplestory_pulse.json"

signal status_changed(message: String, is_error: bool)

var _dark_palette: Resource = DEFAULT_DARK_PALETTE
var _light_palette: Resource = DEFAULT_LIGHT_PALETTE
var _use_dark_mode := true
var _capture_placeholder_warning_emitted := false

func configure_theme(dark_palette: Resource = DEFAULT_DARK_PALETTE, light_palette: Resource = DEFAULT_LIGHT_PALETTE, use_dark_mode: bool = true) -> void:
	_dark_palette = dark_palette if dark_palette != null else DEFAULT_DARK_PALETTE
	_light_palette = light_palette if light_palette != null else DEFAULT_LIGHT_PALETTE
	_use_dark_mode = use_dark_mode

func build_flow_graph() -> Dictionary:
	return SURVEY_VISUAL_AUDIT_CATALOG.build_flow_graph()

func flow_output_directory_path() -> String:
	return ProjectSettings.globalize_path(SURVEY_UI_FLOW_CATALOG.OUTPUT_DIRECTORY)

func visual_audit_output_root() -> String:
	return ProjectSettings.globalize_path(SURVEY_VISUAL_AUDIT_CATALOG.OUTPUT_DIRECTORY)

func visual_audit_export_root() -> String:
	return ProjectSettings.globalize_path(SURVEY_VISUAL_AUDIT_CATALOG.ZIP_EXPORT_DIR)

func generate_flow_map_assets(export_dir: String = "", options: Dictionary = {}) -> Dictionary:
	_apply_theme()
	var resolved_export_dir := export_dir.strip_edges()
	if resolved_export_dir.is_empty():
		resolved_export_dir = flow_output_directory_path()
	var contract_only := bool(options.get("contract_only", false))
	var graph: Dictionary = build_flow_graph()
	var capture_specs := SURVEY_VISUAL_AUDIT_CATALOG.build_flow_capture_specs()
	var textures_by_id := {}
	var export_paths_by_id := {}
	var relative_paths_by_id := {}
	var placeholder_ids: Array[String] = []
	_prepare_output_directory(resolved_export_dir)

	for index in range(capture_specs.size()):
		var spec: Dictionary = capture_specs[index]
		_emit_status("Capturing flow map screen %d of %d: %s" % [index + 1, capture_specs.size(), str(spec.get("surface", spec.get("id", "")))], false)
		var capture_result := await _capture_spec_image(spec, contract_only)
		var image: Image = capture_result.get("image") as Image
		if image == null:
			image = _placeholder_image()
		if bool(capture_result.get("placeholder", false)):
			placeholder_ids.append(str(spec.get("id", "")))
		var surface_id := str(spec.get("surface", "")).strip_edges()
		var target_path := resolved_export_dir.path_join("%s.png" % surface_id)
		var save_error := image.save_png(target_path)
		if save_error != OK:
			return {
				"ok": false,
				"message": "Failed to save %s." % target_path
			}
		textures_by_id[surface_id] = ImageTexture.create_from_image(image)
		export_paths_by_id[surface_id] = target_path
		relative_paths_by_id[surface_id] = "%s.png" % surface_id

	var flow_chart_image: Image = await _capture_flow_chart_image(graph, textures_by_id, export_paths_by_id, contract_only)
	if flow_chart_image == null:
		flow_chart_image = _placeholder_image()
	var flow_chart_path := resolved_export_dir.path_join("ui_flow.png")
	var flow_chart_error := flow_chart_image.save_png(flow_chart_path)
	if flow_chart_error != OK:
		return {
			"ok": false,
			"message": "Failed to save the UI flow chart image."
		}

	_write_flow_manifest(resolved_export_dir, graph, export_paths_by_id, relative_paths_by_id, placeholder_ids, "ui_flow.png")
	return {
		"ok": true,
		"graph": graph,
		"textures_by_id": textures_by_id,
		"export_paths_by_id": export_paths_by_id,
		"flow_chart_path": flow_chart_path,
		"placeholder_ids": placeholder_ids
	}

func export_visual_audit_bundle(options: Dictionary = {}) -> Dictionary:
	_apply_theme()
	var contract_only := bool(options.get("contract_only", false))
	var bundle_stamp := _safe_stamp(Time.get_datetime_string_from_system(true))
	var run_dir_name := "survey_visual_audit_%s" % bundle_stamp
	var run_dir_relative := SURVEY_VISUAL_AUDIT_CATALOG.OUTPUT_DIRECTORY.path_join(run_dir_name)
	var run_dir_absolute := ProjectSettings.globalize_path(run_dir_relative)
	_prepare_output_directory(run_dir_absolute)
	_prepare_output_directory(run_dir_absolute.path_join("flow_chart"))
	_prepare_output_directory(run_dir_absolute.path_join("metadata"))

	var graph: Dictionary = build_flow_graph()
	var capture_specs := SURVEY_VISUAL_AUDIT_CATALOG.build_bundle_capture_specs()
	var capture_entries: Array[Dictionary] = []
	var placeholder_ids: Array[String] = []
	var wrapped_layout_metrics: Array[Dictionary] = []
	var textures_for_flow_chart := {}
	var flow_chart_paths_by_id := {}

	for index in range(capture_specs.size()):
		var spec: Dictionary = capture_specs[index]
		_emit_status("Capturing visual audit screen %d of %d: %s" % [index + 1, capture_specs.size(), str(spec.get("id", ""))], false)
		var capture_result := await _capture_spec_image(spec, contract_only)
		var image: Image = capture_result.get("image") as Image
		if image == null:
			image = _placeholder_image()
		if capture_result.has("layout_metrics") and capture_result.get("layout_metrics", {}) is Dictionary:
			var metrics: Dictionary = (capture_result.get("layout_metrics", {}) as Dictionary).duplicate(true)
			if not metrics.is_empty():
				metrics["capture_id"] = str(spec.get("id", "")).strip_edges()
				metrics["variant"] = str(spec.get("variant", "")).strip_edges()
				metrics["surface"] = str(spec.get("surface", "")).strip_edges()
				wrapped_layout_metrics.append(metrics)
		var relative_path := _bundle_relative_path_for_spec(spec)
		var absolute_path := run_dir_absolute.path_join(relative_path)
		_prepare_output_directory(absolute_path.get_base_dir())
		var save_error := image.save_png(absolute_path)
		if save_error != OK:
			return {
				"ok": false,
				"message": "Failed to save %s." % relative_path
			}
		var placeholder := bool(capture_result.get("placeholder", false))
		if placeholder:
			placeholder_ids.append(str(spec.get("id", "")))
		var manifest_entry := _manifest_capture_entry(spec, relative_path, placeholder)
		capture_entries.append(manifest_entry)
		if _spec_should_feed_flow_chart(spec):
			var source_node_id := str(spec.get("source_node_id", "")).strip_edges()
			if not source_node_id.is_empty():
				textures_for_flow_chart[source_node_id] = ImageTexture.create_from_image(image)
				flow_chart_paths_by_id[source_node_id] = absolute_path
	if textures_for_flow_chart.is_empty():
		for flow_spec in SURVEY_VISUAL_AUDIT_CATALOG.build_flow_capture_specs():
			var surface_id := str(flow_spec.get("surface", "")).strip_edges()
			if surface_id.is_empty():
				continue
			var placeholder_image := _placeholder_image()
			textures_for_flow_chart[surface_id] = ImageTexture.create_from_image(placeholder_image)
			flow_chart_paths_by_id[surface_id] = run_dir_absolute.path_join("screens/%s/%s.png" % [surface_id, "placeholder"])

	var flow_chart_image: Image = await _capture_flow_chart_image(graph, textures_for_flow_chart, flow_chart_paths_by_id, contract_only)
	if flow_chart_image == null:
		flow_chart_image = _placeholder_image()
	var flow_chart_relative := "flow_chart/ui_flow.png"
	var flow_chart_absolute := run_dir_absolute.path_join(flow_chart_relative)
	var flow_chart_save_error := flow_chart_image.save_png(flow_chart_absolute)
	if flow_chart_save_error != OK:
		return {
			"ok": false,
			"message": "Failed to save the visual audit flow chart."
		}
	var flow_relative_paths_by_id := {}
	for node_id in flow_chart_paths_by_id.keys():
		var absolute_path := str(flow_chart_paths_by_id.get(node_id, "")).strip_edges()
		if absolute_path.is_empty():
			continue
		flow_relative_paths_by_id[str(node_id)] = _relative_path_from_root(run_dir_absolute, absolute_path)
	_write_flow_manifest(run_dir_absolute.path_join("flow_chart"), graph, flow_chart_paths_by_id, flow_relative_paths_by_id, placeholder_ids, "ui_flow.png")

	var coverage_report := _build_coverage_report(capture_specs, capture_entries, placeholder_ids)
	var bundle_manifest := _build_bundle_manifest(run_dir_name, capture_entries, placeholder_ids, flow_chart_relative, coverage_report, contract_only)
	if not wrapped_layout_metrics.is_empty():
		bundle_manifest["wrapped_layout_metrics_path"] = "metadata/wrapped_layout_metrics.json"
		bundle_manifest["wrapped_layout_metric_count"] = wrapped_layout_metrics.size()
	_write_json_file(run_dir_absolute.path_join("metadata/coverage_report.json"), coverage_report)
	if not wrapped_layout_metrics.is_empty():
		_write_json_file(run_dir_absolute.path_join("metadata/wrapped_layout_metrics.json"), {
			"format": "survey_wrapped_layout_metrics_v1",
			"generated_at": Time.get_datetime_string_from_system(true),
			"display_server": DisplayServer.get_name(),
			"metrics": wrapped_layout_metrics
		})
	_write_json_file(run_dir_absolute.path_join("metadata/bundle_manifest.json"), bundle_manifest)

	var export_root := visual_audit_export_root()
	_prepare_output_directory(export_root)
	var zip_file_name := "%s.zip" % run_dir_name
	var zip_relative_path := SURVEY_VISUAL_AUDIT_CATALOG.ZIP_EXPORT_DIR.path_join(zip_file_name)
	var zip_absolute_path := ProjectSettings.globalize_path(zip_relative_path)
	var zip_result := _write_directory_zip(run_dir_absolute, zip_relative_path)
	if not bool(zip_result.get("ok", false)):
		return zip_result
	var zip_buffer := FileAccess.get_file_as_bytes(zip_absolute_path)
	if zip_buffer.is_empty():
		return {
			"ok": false,
			"message": "The visual audit ZIP archive was empty."
		}
	_emit_status("Visual audit bundle exported to %s" % zip_absolute_path, false)
	return {
		"ok": true,
		"buffer": zip_buffer,
		"file_name": zip_file_name,
		"zip_path": zip_relative_path,
		"zip_absolute_path": zip_absolute_path,
		"run_directory": run_dir_absolute,
		"capture_count": capture_entries.size(),
		"placeholder_capture_count": placeholder_ids.size(),
		"flow_chart_path": flow_chart_absolute
	}

func _capture_spec_image(spec: Dictionary, contract_only: bool) -> Dictionary:
	if contract_only:
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	match str(spec.get("entry_route", "")).strip_edges():
		"flow_node":
			return await _capture_flow_node_image(spec)
		"qa_overlay":
			return await _capture_qa_overlay_image(spec)
		"feedback_overlay":
			return await _capture_feedback_overlay_image(spec)
		"answer_review_overlay":
			return await _capture_answer_review_overlay_image(spec)
		"question_type":
			return await _capture_question_type_image(spec)
		"custom_view":
			return await _capture_custom_view_image(spec)
		"feature_export":
			return await _capture_feature_export_image(spec)
	return {
		"image": _placeholder_image(),
		"placeholder": true
	}

func _capture_flow_node_image(spec: Dictionary) -> Dictionary:
	match str(spec.get("source_kind", "")).strip_edges():
		"survey_app":
			return await _capture_survey_app_image(spec)
		"survey_journey":
			return await _capture_survey_journey_image(spec)
		"question_gallery":
			return await _capture_question_gallery_image(spec)
	return {
		"image": _placeholder_image(),
		"placeholder": true
	}

func _capture_survey_app_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var app: Control = SURVEY_APP_SCENE.instantiate()
	app.set("launch_fullscreen", false)
	app.set("use_saved_dev_data", false)
	viewport.add_child(app)
	_fit_control_to_viewport(app, viewport_size)
	await _await_capture_frames(4)
	app.call("_close_onboarding_overlay")
	await _await_capture_frames(3)

	match str(spec.get("state", "")).strip_edges():
		"scroll":
			app.call("_set_survey_view_mode_preference", "scroll", false)
		"focus":
			app.call("_set_survey_view_mode_preference", "focus", false)
		"overlay_menu":
			app.call("_set_survey_view_mode_preference", "scroll", false)
			app.call("_open_overlay_menu")
		"search":
			app.call("_open_search_overlay")
		"onboarding":
			app.call("_open_onboarding_overlay")
		"settings":
			app.call("_open_settings_overlay")
		"summary":
			_apply_sample_answers_to_survey_app(app)
			app.call("_open_summary_overlay")
		"export":
			_apply_sample_answers_to_survey_app(app)
			app.call("_open_export_overlay")
		"profile":
			_apply_sample_answers_to_survey_app(app)
			app.call("_open_profile_overlay")
		"help":
			app.call("_set_survey_view_mode_preference", "focus", false)
			await _await_capture_frames(2)
			app.call("_open_question_help")
	await _await_capture_frames(6)
	return await _finalize_capture(viewport)

func _capture_survey_journey_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	journey.set("persist_selected_template", false)
	var upload_state := str(spec.get("upload_state", "")).strip_edges()
	if upload_state == "configured":
		journey.set("upload_endpoint_url", "https://example.com/upload")
		journey.set("upload_destination_name", "Visual Audit Intake")
		journey.set("upload_public_repo_name", "Visual Audit Repo")
		journey.set("upload_public_repo_url", "https://example.com/research/visual-audit")
		journey.set("max_template_loads_per_window", 0)
	else:
		journey.set("upload_endpoint_url", "")
	viewport.add_child(journey)
	_fit_control_to_viewport(journey, viewport_size)
	await _await_capture_frames(4)
	var template_path := PUBLIC_LAUNCH_TEMPLATE_PATH if upload_state == "configured" else SURVEY_UI_FLOW_FIXTURES.default_template_path()
	journey.call("_load_survey_from_path", template_path, false)
	await _await_capture_frames(4)

	match str(spec.get("state", "")).strip_edges():
		"landing":
			journey.call("_show_view", "landing")
		"theme_drawer":
			journey.call("_show_view", "landing")
			await _await_capture_frames(2)
			var theme_drawer := journey.get_node_or_null("ThemeDrawer")
			if theme_drawer != null:
				theme_drawer.call("set_expanded", true)
		"survey_selection":
			journey.call("_show_view", "survey_selection")
		"lore":
			journey.call("_show_view", "lore")
		"lore_link_prompt":
			var survey: SurveyDefinition = journey.get("survey") as SurveyDefinition
			if survey != null and survey.lore_url.is_empty():
				survey.lore_url = "https://example.com/lore"
				survey.lore_url_label = "Lore Link"
			journey.call("_refresh_all_views")
			journey.call("_show_view", "lore")
			await _await_capture_frames(2)
			journey.call("_open_lore_link_prompt")
		"focus":
			journey.call("_start_focus_from_section", 0, "")
		"focus_outline":
			journey.call("_start_focus_from_section", 0, "")
			await _await_capture_frames(2)
			journey.call("_set_focus_outline_visible", true)
		"overlay_menu":
			journey.call("_start_focus_from_section", 0, "")
			await _await_capture_frames(2)
			journey.call("_open_overlay_menu")
		"help":
			journey.call("_start_focus_from_section", 0, "")
			await _await_capture_frames(2)
			journey.call("_open_question_help")
		"review":
			_apply_sample_answers_to_survey_journey(journey)
			journey.call("_open_review_view")
		"profile":
			_apply_sample_answers_to_survey_journey(journey)
			journey.call("_start_focus_from_section", 0, "")
			await _await_capture_frames(2)
			journey.call("_open_profile_overlay")
		"thanks":
			_apply_sample_answers_to_survey_journey(journey)
			journey.call("_show_view", "thanks")
		"export":
			_apply_sample_answers_to_survey_journey(journey)
			journey.call("_open_export_overlay")
		"upload":
			_apply_sample_answers_to_survey_journey(journey)
			journey.call("_open_export_overlay")
			await _await_capture_frames(2)
			journey.call("_open_upload_view")
	await _await_capture_frames(6)
	return await _finalize_capture(viewport)

func _capture_question_gallery_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.GALLERY_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var gallery: Control = QUESTION_TYPE_GALLERY_SCENE.instantiate()
	viewport.add_child(gallery)
	_fit_control_to_viewport(gallery, viewport_size)
	await _await_capture_frames(6)
	gallery.call("_refresh_gallery_layout")
	await _await_capture_frames(4)
	var margin := gallery.get_node_or_null("Margin") as MarginContainer
	var shell := gallery.get_node_or_null("Margin/Shell") as VBoxContainer
	var heading := gallery.get_node_or_null("Margin/Shell/HeadingLabel") as Control
	var description := gallery.get_node_or_null("Margin/Shell/DescriptionLabel") as Control
	var grid := gallery.get_node_or_null("Margin/Shell/GalleryScroll/Grid") as Control
	if margin != null and shell != null and heading != null and description != null and grid != null:
		var margin_vertical := float(margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom"))
		var separation := float(shell.get_theme_constant("separation"))
		var required_height := margin_vertical + heading.get_combined_minimum_size().y + description.get_combined_minimum_size().y + grid.get_combined_minimum_size().y + (separation * 2.0) + 24.0
		var expanded_height := maxi(viewport.size.y, int(ceil(required_height)))
		if expanded_height > viewport.size.y:
			viewport.size = Vector2i(viewport.size.x, expanded_height)
			_fit_control_to_viewport(gallery, viewport.size)
			gallery.call("_refresh_gallery_layout")
			await _await_capture_frames(6)
	return await _finalize_capture(viewport)

func _capture_qa_overlay_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var overlay: SurveyQaOverlay = SURVEY_QA_OVERLAY_SCRIPT.new()
	viewport.add_child(overlay)
	await _await_capture_frames(3)
	overlay.refresh_layout(Vector2(viewport_size))
	match str(spec.get("surface", "")).strip_edges():
		"qa_tutorial":
			overlay.open_tutorial(_sample_qa_tutorial_state())
		"qa_checklist":
			overlay.open_checklist(_sample_qa_checklist_state())
		_:
			overlay.open_home(_sample_qa_home_state())
	await _await_capture_frames(4)
	return await _finalize_capture(viewport)

func _capture_feedback_overlay_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var overlay: SurveyPlaytestFeedbackOverlay = SURVEY_PLAYTEST_FEEDBACK_OVERLAY_SCRIPT.new()
	viewport.add_child(overlay)
	await _await_capture_frames(3)
	overlay.refresh_layout(Vector2(viewport_size))
	match str(spec.get("surface", "")).strip_edges():
		"feedback_armed_capture":
			overlay.open_armed_capture()
		"feedback_report_popup":
			overlay.open_capture(_sample_feedback_capture_context(viewport_size))
		"feedback_review_panel":
			overlay.open_review([_sample_feedback_issue("visual_audit_feedback")])
	await _await_capture_frames(4)
	return await _finalize_capture(viewport)

func _capture_answer_review_overlay_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var overlay = SURVEY_ANSWER_REVIEW_OVERLAY_SCRIPT.new()
	viewport.add_child(overlay)
	await _await_capture_frames(3)
	overlay.refresh_layout(Vector2(viewport_size))
	var review_survey: SurveyDefinition = SURVEY_UI_FLOW_FIXTURES.load_default_survey()
	if review_survey == null:
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	var scan_report := _sample_answer_review_scan_report(review_survey)
	overlay.open_review(review_survey, {
		"folder_path": "X:/Playtests/Imported Answers",
		"recursive": true,
		"scrub_identifying_info": true
	}, scan_report)
	await _await_capture_frames(4)
	return await _finalize_capture(viewport)

func _capture_question_type_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_VISUAL_AUDIT_CATALOG.QUESTION_CARD_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var wrapper := Control.new()
	viewport.add_child(wrapper)
	_fit_control_to_viewport(wrapper, viewport_size)
	var card := _build_question_capture_card(spec)
	if card == null:
		viewport.queue_free()
		await get_tree().process_frame
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	wrapper.add_child(card)
	card.position = Vector2(18.0, 18.0)
	card.size = Vector2(viewport_size.x - 36, viewport_size.y - 36)
	var question_view := card.get_meta("question_view", null) as SurveyQuestionView
	await awaitable_refresh_question_view(question_view, card)
	await _await_capture_frames(4)
	if str(spec.get("surface", "")).strip_edges() == "dropdown" and str(spec.get("variant", "")).strip_edges() == "expanded":
		var option_button := _find_first_option_button(card)
		if option_button != null:
			var popup := option_button.get_popup()
			if popup != null:
				popup.position = option_button.global_position + Vector2(0.0, option_button.size.y)
				popup.size = Vector2(option_button.size.x, 220.0)
				popup.popup()
		await _await_capture_frames(2)
	return await _finalize_capture(viewport)

func _capture_custom_view_image(spec: Dictionary) -> Dictionary:
	var question: SurveyQuestion = spec.get("question") as SurveyQuestion
	if question == null:
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	var custom_spec := {
		"surface": str(spec.get("surface", "")).strip_edges(),
		"variant": str(spec.get("variant", "filled")).strip_edges(),
		"viewport_size": spec.get("viewport_size", SURVEY_VISUAL_AUDIT_CATALOG.QUESTION_CARD_VIEWPORT),
		"question": question,
		"answer": _duplicate_variant(spec.get("answer", null)),
		"title": str(spec.get("title", question.display_prompt())).strip_edges(),
		"scene_path": str(spec.get("scene_path", "")).strip_edges()
	}
	return await _capture_question_like_image(custom_spec)

func _capture_feature_export_image(spec: Dictionary) -> Dictionary:
	var survey := SURVEY_UI_FLOW_FIXTURES.load_default_survey()
	if survey == null:
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	var answers := SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey)
	match str(spec.get("surface", "")).strip_edges():
		"answer_wrapped_image":
			return await _capture_answer_wrapped_card_image(spec, survey)
		"profile_image":
			var profile_overlay: SurveyProfileOverlay = SURVEY_PROFILE_OVERLAY_SCENE.instantiate() as SurveyProfileOverlay
			add_child(profile_overlay)
			await _await_capture_frames(2)
			profile_overlay.open_profile(SURVEY_UI_FLOW_FIXTURES.profile_snapshot(survey, answers))
			await _await_capture_frames(2)
			var profile_image: Image = await profile_overlay.capture_profile_image()
			profile_overlay.queue_free()
			await get_tree().process_frame
			return {
				"image": profile_image if profile_image != null else _placeholder_image(),
				"placeholder": profile_image == null
			}
		_:
			var summary_overlay: SurveySummaryOverlay = SURVEY_SUMMARY_OVERLAY_SCENE.instantiate() as SurveySummaryOverlay
			add_child(summary_overlay)
			await _await_capture_frames(2)
			summary_overlay.open_summary(SURVEY_UI_FLOW_FIXTURES.summary_data(survey, answers), "optimistic, clear-eyed, thoughtful")
			await _await_capture_frames(2)
			var summary_image: Image = await summary_overlay.capture_summary_image()
			summary_overlay.queue_free()
			await get_tree().process_frame
			return {
				"image": summary_image if summary_image != null else _placeholder_image(),
				"placeholder": summary_image == null
			}

func _capture_answer_wrapped_card_image(spec: Dictionary, survey: SurveyDefinition) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_VISUAL_AUDIT_CATALOG.WRAPPED_PHONE_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var card = SURVEY_ANSWER_WRAPPED_CARD_SCRIPT.new()
	viewport.add_child(card)
	card.custom_minimum_size = Vector2(viewport_size)
	card.size = Vector2(viewport_size)
	var pages_data := _sample_answer_review_pages_data(survey, str(spec.get("wrapped_theme_id", "light")))
	var pages: Array = pages_data.get("pages", [])
	var page_index := clampi(int(spec.get("page_index", 0)), 0, maxi(pages.size() - 1, 0))
	var requested_page_kind := str(spec.get("page_kind", "")).strip_edges()
	if not requested_page_kind.is_empty():
		for index in range(pages.size()):
			if pages[index] is Dictionary and str((pages[index] as Dictionary).get("page_kind", "")) == requested_page_kind:
				page_index = index
				break
	var requested_renderer := str(spec.get("wrapped_renderer", "")).strip_edges()
	if not requested_renderer.is_empty():
		var found_renderer_page := false
		for index in range(pages.size()):
			if not (pages[index] is Dictionary):
				continue
			var page: Dictionary = pages[index] as Dictionary
			for question_value in page.get("questions", []) as Array:
				if question_value is Dictionary and str((question_value as Dictionary).get("wrapped_renderer", "")).strip_edges() == requested_renderer:
					page_index = index
					found_renderer_page = true
					break
			if found_renderer_page:
				break
	if not pages.is_empty() and pages[page_index] is Dictionary:
		card.configure_page(pages[page_index] as Dictionary, pages_data)
	else:
		card.configure(pages_data)
	card.refresh_layout(float(viewport_size.x))
	await _await_capture_frames(4)
	var layout_metrics: Dictionary = card.get_layout_metrics() if card.has_method("get_layout_metrics") else {}
	var capture_result := await _finalize_capture(viewport)
	capture_result["layout_metrics"] = layout_metrics
	return capture_result

func _capture_question_like_image(spec: Dictionary) -> Dictionary:
	var viewport_size := _resolved_viewport_size(spec, SURVEY_VISUAL_AUDIT_CATALOG.QUESTION_CARD_VIEWPORT)
	var viewport := _create_capture_viewport(viewport_size)
	var wrapper := Control.new()
	viewport.add_child(wrapper)
	_fit_control_to_viewport(wrapper, viewport_size)
	var card := _build_question_capture_card(spec)
	if card == null:
		viewport.queue_free()
		await get_tree().process_frame
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	wrapper.add_child(card)
	card.position = Vector2(18.0, 18.0)
	card.size = Vector2(viewport_size.x - 36, viewport_size.y - 36)
	var question_view := card.get_meta("question_view", null) as SurveyQuestionView
	await awaitable_refresh_question_view(question_view, card)
	await _await_capture_frames(4)
	return await _finalize_capture(viewport)

func _build_question_capture_card(spec: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(maxf(_resolved_viewport_size(spec, SURVEY_VISUAL_AUDIT_CATALOG.QUESTION_CARD_VIEWPORT).x - 36.0, 320.0), 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 20, 1)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = str(spec.get("title", str(spec.get("surface", "")).capitalize())).strip_edges()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_heading(title_label, 20)
	stack.add_child(title_label)

	var scene_path := str(spec.get("scene_path", "")).strip_edges()
	if not scene_path.is_empty():
		var scene_label := Label.new()
		scene_label.text = scene_path
		scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_caption(scene_label, SurveyStyle.TEXT_MUTED)
		stack.add_child(scene_label)

	var question: SurveyQuestion = spec.get("question") as SurveyQuestion
	if question == null:
		var question_config: Variant = spec.get("question_config", {})
		if question_config is Dictionary:
			question = SurveyQuestion.new(question_config as Dictionary)
	if question == null:
		return null
	var answer_value: Variant = _duplicate_variant(spec.get("answer", question.default_value))
	var question_view := QUESTION_VIEW_REGISTRY.instantiate_for_question(question)
	if question_view == null:
		return null
	question_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_view.set_presentation_mode(SurveyQuestionView.PRESENTATION_DOCUMENT)
	question_view.configure(question, answer_value)
	stack.add_child(question_view)
	panel.set_meta("question_view", question_view)
	return panel

func awaitable_refresh_question_view(question_view: SurveyQuestionView, panel: PanelContainer) -> void:
	if question_view == null or panel == null:
		return
	if not question_view.is_node_ready():
		await get_tree().process_frame
	if not question_view.is_node_ready():
		await get_tree().process_frame
	var width := maxf(panel.custom_minimum_size.x - 32.0, 320.0)
	question_view.refresh_responsive_layout(Vector2(width, _resolved_root_viewport_height()))

func _find_first_option_button(node: Node) -> OptionButton:
	if node is OptionButton:
		return node as OptionButton
	for child in node.get_children():
		var found := _find_first_option_button(child)
		if found != null:
			return found
	return null

func _capture_flow_chart_image(graph: Dictionary, textures_by_id: Dictionary, export_paths_by_id: Dictionary, contract_only: bool) -> Image:
	if contract_only:
		return _placeholder_image()
	var viewport_size := graph.get("canvas_size", SURVEY_UI_FLOW_CATALOG.CANVAS_SIZE) as Vector2i
	var viewport := _create_capture_viewport(viewport_size)
	var canvas := SURVEY_UI_FLOW_CANVAS_SCRIPT.new() as SurveyUiFlowCanvas
	viewport.add_child(canvas)
	_fit_control_to_viewport(canvas, viewport_size)
	canvas.set_graph(graph, textures_by_id, export_paths_by_id)
	await _await_capture_frames(4)
	var capture_result := await _finalize_capture(viewport)
	return capture_result.get("image") as Image

func _create_capture_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	viewport.size = viewport_size
	add_child(viewport)
	return viewport

func _fit_control_to_viewport(control: Control, viewport_size: Vector2i) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.custom_minimum_size = Vector2(viewport_size)

func _finalize_capture(viewport: SubViewport) -> Dictionary:
	await _await_capture_frames(2)
	if DisplayServer.get_name() == "headless":
		if not _capture_placeholder_warning_emitted:
			push_warning("Renderer-backed captures are unavailable in headless mode. Using placeholder images for the visual audit export.")
			_capture_placeholder_warning_emitted = true
		viewport.queue_free()
		await get_tree().process_frame
		return {
			"image": _placeholder_image(),
			"placeholder": true
		}
	var texture := viewport.get_texture()
	var image: Image = null
	if texture != null:
		image = texture.get_image()
	if image == null:
		if not _capture_placeholder_warning_emitted:
			push_warning("SubViewport textures were unavailable in the active renderer. Using placeholder images for the visual audit export.")
			_capture_placeholder_warning_emitted = true
		image = _placeholder_image()
	viewport.queue_free()
	await get_tree().process_frame
	return {
		"image": image,
		"placeholder": image == null
	}

func _await_capture_frames(count: int) -> void:
	for _index in range(maxi(count, 1)):
		await get_tree().process_frame

func _prepare_output_directory(export_dir: String) -> void:
	var ensure_error := DirAccess.make_dir_recursive_absolute(export_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(export_dir):
		push_error("Failed to prepare %s" % export_dir)

func _write_flow_manifest(export_dir: String, graph: Dictionary, export_paths_by_id: Dictionary, relative_paths_by_id: Dictionary, placeholder_ids: Array[String], flow_chart_relative_path: String) -> void:
	var manifest_nodes: Array[Dictionary] = []
	var manifest_edges: Array[Dictionary] = []
	var manifest := {
		"title": str(graph.get("title", "UI Flow Map")),
		"generated_at": Time.get_datetime_string_from_system(true),
		"canvas_size": _vector2i_to_array(graph.get("canvas_size", Vector2i.ZERO) as Vector2i),
		"flow_chart_image_path": flow_chart_relative_path,
		"placeholder_capture_ids": placeholder_ids.duplicate(),
		"nodes": manifest_nodes,
		"edges": manifest_edges
	}
	var node_values: Variant = graph.get("nodes", [])
	if node_values is Array:
		for node_value in node_values:
			if not (node_value is Dictionary):
				continue
			var node_spec: Dictionary = node_value as Dictionary
			var node_id := str(node_spec.get("id", "")).strip_edges()
			manifest_nodes.append({
				"id": node_id,
				"title": str(node_spec.get("title", "")),
				"description": str(node_spec.get("description", "")),
				"group": str(node_spec.get("group", "")),
				"source_kind": str(node_spec.get("source_kind", "")),
				"state": str(node_spec.get("state", "")),
				"position": _vector2_to_array(node_spec.get("position", Vector2.ZERO) as Vector2),
				"viewport_size": _vector2i_to_array(node_spec.get("viewport_size", Vector2i.ZERO) as Vector2i),
				"preview_size": _vector2_to_array(node_spec.get("preview_size", Vector2.ZERO) as Vector2),
				"image_path": str(relative_paths_by_id.get(node_id, _relative_path_from_root(export_dir, str(export_paths_by_id.get(node_id, "")))))
			})
	var edge_values: Variant = graph.get("edges", [])
	if edge_values is Array:
		for edge_value in edge_values:
			if edge_value is Dictionary:
				manifest_edges.append((edge_value as Dictionary).duplicate(true))
	_write_json_file(export_dir.path_join("flow_manifest.json"), manifest)

func _write_json_file(path: String, payload: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_sanitize_variant(payload), "\t"))
	file.close()

func _build_coverage_report(specs: Array[Dictionary], capture_entries: Array[Dictionary], placeholder_ids: Array[String]) -> Dictionary:
	var captured_ids := {}
	var groups := {}
	for entry in capture_entries:
		var capture_id := str(entry.get("id", "")).strip_edges()
		if capture_id.is_empty():
			continue
		captured_ids[capture_id] = true
		var group := str(entry.get("group", "")).strip_edges()
		groups[group] = int(groups.get(group, 0)) + 1
	var missing_capture_ids: Array[String] = []
	for spec in specs:
		var spec_id := str(spec.get("id", "")).strip_edges()
		if spec_id.is_empty() or captured_ids.has(spec_id):
			continue
		missing_capture_ids.append(spec_id)
	return {
		"expected_capture_count": specs.size(),
		"captured_count": capture_entries.size(),
		"missing_capture_ids": missing_capture_ids,
		"placeholder_capture_ids": placeholder_ids.duplicate(),
		"group_counts": groups,
		"flow_node_count": SURVEY_VISUAL_AUDIT_CATALOG.flow_node_ids().size(),
		"question_family_count": SURVEY_VISUAL_AUDIT_CATALOG.question_family_ids().size(),
		"custom_view_count": SURVEY_VISUAL_AUDIT_CATALOG.discovered_custom_scene_paths().size()
	}

func _build_bundle_manifest(run_dir_name: String, capture_entries: Array[Dictionary], placeholder_ids: Array[String], flow_chart_relative_path: String, coverage_report: Dictionary, contract_only: bool) -> Dictionary:
	return {
		"format": "survey_visual_audit_bundle_v1",
		"generated_at": Time.get_datetime_string_from_system(true),
		"run_id": run_dir_name,
		"theme": {
			"use_dark_mode": _use_dark_mode
		},
		"display_server": DisplayServer.get_name(),
		"contract_only": contract_only,
		"flow_chart_image_path": flow_chart_relative_path,
		"coverage_report_path": "metadata/coverage_report.json",
		"placeholder_capture_count": placeholder_ids.size(),
		"capture_count": capture_entries.size(),
		"captures": capture_entries.duplicate(true),
		"coverage": coverage_report.duplicate(true)
	}

func _write_directory_zip(root_absolute: String, zip_relative_path: String) -> Dictionary:
	var writer := ZIPPacker.new()
	writer.compression_level = ZIPPacker.COMPRESSION_DEFAULT
	var open_error := writer.open(zip_relative_path, ZIPPacker.APPEND_CREATE)
	if open_error != OK:
		return {
			"ok": false,
			"message": "Failed to create the visual audit ZIP archive."
		}
	for absolute_path in _collect_files_recursive(root_absolute):
		var relative_path := _relative_path_from_root(root_absolute, absolute_path)
		if relative_path.is_empty():
			continue
		var file_bytes := FileAccess.get_file_as_bytes(absolute_path)
		if file_bytes.is_empty():
			continue
		var write_error := _write_zip_entry(writer, relative_path, file_bytes)
		if write_error != OK:
			writer.close()
			return {
				"ok": false,
				"message": "Failed while writing %s to the visual audit ZIP archive." % relative_path
			}
	var close_error := writer.close()
	if close_error != OK:
		return {
			"ok": false,
			"message": "Failed to finish the visual audit ZIP archive."
		}
	return {
		"ok": true
	}

func _collect_files_recursive(root_absolute: String) -> PackedStringArray:
	var files := PackedStringArray()
	var directory := DirAccess.open(root_absolute)
	if directory == null:
		return files
	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var absolute_path := root_absolute.path_join(entry_name)
		if directory.current_is_dir():
			files.append_array(_collect_files_recursive(absolute_path))
		else:
			files.append(absolute_path.replace("\\", "/"))
	directory.list_dir_end()
	return files

func _write_zip_entry(writer: ZIPPacker, entry_path: String, buffer: PackedByteArray) -> Error:
	var normalized_entry_path := entry_path.replace("\\", "/")
	var start_error := writer.start_file(normalized_entry_path)
	if start_error != OK:
		return start_error
	var write_error := writer.write_file(buffer)
	var close_error := writer.close_file()
	if write_error != OK:
		return write_error
	return close_error

func _bundle_relative_path_for_spec(spec: Dictionary) -> String:
	var group := str(spec.get("group", "")).strip_edges()
	var surface := _safe_segment(str(spec.get("surface", "")).strip_edges())
	var variant := _safe_segment(str(spec.get("variant", "")).strip_edges())
	match group:
		"question_types":
			return "question_types/%s/%s.png" % [surface, variant]
		"custom_views":
			return "custom_views/%s/%s.png" % [surface, variant]
		"features":
			return "features/%s/%s.png" % [surface, variant]
		_:
			return "screens/%s/%s.png" % [surface, variant]

func _manifest_capture_entry(spec: Dictionary, relative_path: String, placeholder: bool) -> Dictionary:
	return {
		"id": str(spec.get("id", "")).strip_edges(),
		"group": str(spec.get("group", "")).strip_edges(),
		"surface": str(spec.get("surface", "")).strip_edges(),
		"variant": str(spec.get("variant", "")).strip_edges(),
		"viewport_preset": str(spec.get("viewport_preset", "")).strip_edges(),
		"entry_route": str(spec.get("entry_route", "")).strip_edges(),
		"state_tags": _string_array(spec.get("state_tags", [])),
		"source_node_id": str(spec.get("source_node_id", "")).strip_edges(),
		"relative_path": relative_path.replace("\\", "/"),
		"placeholder": placeholder
	}

func _spec_should_feed_flow_chart(spec: Dictionary) -> bool:
	var source_node_id := str(spec.get("source_node_id", "")).strip_edges()
	if source_node_id.is_empty():
		return false
	if spec.has("upload_state"):
		return false
	var surface := str(spec.get("surface", "")).strip_edges()
	if surface == "question_gallery":
		return str(spec.get("variant", "")).strip_edges() == "sheet"
	return str(spec.get("viewport_preset", "")).strip_edges() == SURVEY_VISUAL_AUDIT_CATALOG.PHONE_VIEWPORT_ID

func _sample_answer_review_scan_report(survey: SurveyDefinition) -> Dictionary:
	var aggregate := _sample_answer_review_aggregate(survey)
	return {
		"survey_id": survey.id if survey != null else "",
		"schema_hash": survey.schema_hash if survey != null else "",
		"folder_path": "X:/Playtests/Imported Answers",
		"recursive": true,
		"generated_at": Time.get_datetime_string_from_system(true),
		"records": aggregate.get("_sample_records", []),
		"rejected_files": [
			{
				"path": "X:/Playtests/Imported Answers/wrong_survey.json",
				"file_name": "wrong_survey.json",
				"message": "Survey id did not match."
			}
		],
		"warnings": ["legacy_export.json did not include a schema hash."],
		"aggregate": aggregate,
		"accepted_count": int(aggregate.get("respondent_count", 0)),
		"question_count": survey.total_questions() if survey != null else 0
	}

func _sample_answer_review_summary_data(survey: SurveyDefinition) -> Dictionary:
	return SURVEY_ANSWER_REVIEW.build_wrapped_summary_data(survey, _sample_answer_review_aggregate(survey), true)

func _sample_answer_review_pages_data(survey: SurveyDefinition, theme_id: String) -> Dictionary:
	return SURVEY_ANSWER_REVIEW.build_wrapped_pages_data(
		survey,
		_sample_answer_review_aggregate(survey),
		true,
		{
			"profile_name": "Mushroom",
			"fields": [
				{"label": "Username", "value": "QA Review"},
				{"label": "World", "value": "Bottle"},
				{"label": "Region", "value": "NA"}
			],
			"show_on_wrap": true
		},
		theme_id
	)

func _sample_answer_review_aggregate(survey: SurveyDefinition) -> Dictionary:
	if survey == null:
		return {}
	var first_answers := SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey)
	var second_answers := SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey)
	for section in survey.sections:
		for question in section.questions:
			match question.type:
				SurveyQuestion.TYPE_SHORT_TEXT:
					second_answers[question.id] = "Clearer once the second screen introduced the goal."
				SurveyQuestion.TYPE_LONG_TEXT:
					second_answers[question.id] = "The wrapped summary should keep the useful theme without exposing identifying details."
				SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
					if question.options.size() > 1:
						second_answers[question.id] = question.options[question.options.size() - 1]
				SurveyQuestion.TYPE_MULTI_CHOICE:
					var choices: Array = []
					for index in range(mini(question.options.size(), 2)):
						choices.append(question.options[index])
					second_answers[question.id] = choices
				SurveyQuestion.TYPE_BOOLEAN:
					second_answers[question.id] = false
				SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS, SurveyQuestion.TYPE_NUMBER:
					second_answers[question.id] = clampi(question.min_value + 1, question.min_value, question.max_value)
				SurveyQuestion.TYPE_RANKED_CHOICE:
					var reversed_options: Array = []
					for option_index in range(question.options.size() - 1, -1, -1):
						reversed_options.append(question.options[option_index])
					second_answers[question.id] = reversed_options
				SurveyQuestion.TYPE_MATRIX:
					var matrix_answer: Dictionary = {}
					var option := question.options[min(1, max(question.options.size() - 1, 0))] if not question.options.is_empty() else "Yes"
					for row_name in question.rows:
						matrix_answer[row_name] = option
					second_answers[question.id] = matrix_answer
	var records: Array[Dictionary] = [
		{"source_name": "visual_audit_a.json", "answers": first_answers},
		{"source_name": "visual_audit_b.json", "answers": second_answers}
	]
	var aggregate: Dictionary = SURVEY_ANSWER_REVIEW.build_aggregate(survey, records)
	aggregate["_sample_records"] = records
	return aggregate

func _sample_qa_home_state() -> Dictionary:
	return {
		"title": "QA Guide",
		"subtitle": "Journey test surface",
		"status_text": "Current page: journey landing",
		"summary_text": "Use the guided QA flow to step through expected behavior, capture screenshots, export the QA bundle, or export the full visual audit bundle.\n\n- Surface: Survey journey\n- Started: %s\n- Checklist: pass 2, fail 1, pending 18\n- Captures: 4\n- Reported issues: 1" % Time.get_datetime_string_from_system(true),
		"can_resume": true,
		"resume_label": "Resume Journey checklist",
		"switch_surface_label": "Switch To Survey App Smoke Test",
		"switch_surface_id": "survey_app"
	}

func _sample_qa_tutorial_state() -> Dictionary:
	return {
		"title": "How To Report An Issue",
		"subtitle": "Teach the feedback system first",
		"status_text": "Current page: journey focus",
		"tutorial_text": "1. Use the QA checklist to navigate to the page you want to inspect.\n2. Press Start Issue Tagging, then click or tap the broken area.\n3. On desktop, Ctrl-click still works as a direct shortcut.\n4. Add a short description before saving the issue.\n5. Use Open Issue Review to delete or confirm captured issues.\n6. Export the final QA bundle or the full visual audit bundle when you are done.",
		"can_export_feedback_zip": true
	}

func _sample_qa_checklist_state() -> Dictionary:
	var sections: Array[Dictionary] = []
	for section_value in SURVEY_QA_CHECKLIST_CATALOG.sections_for_surface("survey_journey"):
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = (section_value as Dictionary).duplicate(true)
		var resolved_items: Array[Dictionary] = []
		for item_value in section.get("items", []) as Array:
			if not (item_value is Dictionary):
				continue
			var item: Dictionary = (item_value as Dictionary).duplicate(true)
			var item_id := str(item.get("id", "")).strip_edges()
			if item_id.ends_with("readability"):
				item["status"] = "pass"
			elif item_id.ends_with("navigation"):
				item["status"] = "fail"
			resolved_items.append(item)
		section["items"] = resolved_items
		sections.append(section)
	return {
		"title": "Guided QA Checklist",
		"subtitle": "Expected behavior by page",
		"status_text": "Current page: journey landing",
		"sections": sections,
		"selected_page_node_id": "journey_landing",
		"page_status_text": "This page: pass 1, fail 1, pending 3"
	}

func _sample_feedback_capture_context(viewport_size: Vector2i) -> Dictionary:
	var image := Image.create(320, 240, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.18, 0.2, 0.24, 1.0))
	return {
		"page_summary": "Journey | Focus Question 1",
		"target_summary": "Question 1: What is this template for?",
		"click": {
			"pixel_position": {
				"x": int(round(float(viewport_size.x) * 0.45)),
				"y": int(round(float(viewport_size.y) * 0.38))
			},
			"normalized_position": {
				"x": 0.45,
				"y": 0.38
			},
			"viewport_size": {
				"x": viewport_size.x,
				"y": viewport_size.y
			}
		},
		"_screenshot_image": image
	}

func _sample_feedback_issue(issue_id: String) -> Dictionary:
	var image := Image.create(128, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.22, 0.34, 0.62, 1.0))
	return {
		"id": issue_id,
		"timestamp": "2026-06-04T02:30:00Z",
		"surface": "survey_journey",
		"capture_method": "desktop_ctrl_click",
		"input_kind": "mouse",
		"trigger_source": "ctrl_click",
		"page_summary": "Journey | Focus Question 1",
		"target_summary": "Question 1: What is this template for?",
		"description": "The question card feels too cramped at this size.",
		"screenshot": {
			"file_path": "screenshots/%s.png" % issue_id,
			"size": {"x": 128, "y": 96}
		},
		"_screenshot_image": image,
		"_screenshot_png": image.save_png_to_buffer()
	}

func _apply_sample_answers_to_survey_app(app: Object) -> void:
	var survey: SurveyDefinition = app.get("survey") as SurveyDefinition
	if survey == null:
		return
	app.set("answers", SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey))
	app.call("_rebuild_document_preserving_state", "", false)

func _apply_sample_answers_to_survey_journey(journey: Object) -> void:
	var survey: SurveyDefinition = journey.get("survey") as SurveyDefinition
	if survey == null:
		return
	journey.set("answers", SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey))
	journey.call("_refresh_all_views")
	journey.call("_refresh_gamification_surfaces")

func _apply_theme() -> void:
	SurveyStyle.configure_palettes(_dark_palette, _light_palette, _use_dark_mode)

func _resolved_viewport_size(spec: Dictionary, fallback: Vector2i) -> Vector2i:
	var explicit_size: Variant = spec.get("viewport_size", Vector2i.ZERO)
	if explicit_size is Vector2i and explicit_size != Vector2i.ZERO:
		return explicit_size as Vector2i
	var viewport_id := str(spec.get("viewport_preset", "")).strip_edges()
	var preset_size: Vector2i = SurveyPreviewConfig.resolution_size(viewport_id)
	return preset_size if preset_size != Vector2i.ZERO else fallback

func _resolved_root_viewport_height() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 900.0
	return viewport.get_visible_rect().size.y

func _placeholder_image() -> Image:
	var image := Image.create(96, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.86, 0.18, 0.18, 1.0))
	return image

func _vector2_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]

func _vector2i_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]

func _relative_path_from_root(root_path: String, target_path: String) -> String:
	var normalized_root := root_path.replace("\\", "/").trim_suffix("/")
	var normalized_target := target_path.replace("\\", "/")
	if normalized_root.is_empty() or normalized_target.is_empty():
		return ""
	if normalized_target.begins_with(normalized_root):
		return normalized_target.substr(normalized_root.length() + 1)
	return normalized_target.get_file()

func _safe_stamp(raw_value: String) -> String:
	return _safe_segment(raw_value.replace(":", "-").replace(" ", "_"))

func _safe_segment(raw_value: String) -> String:
	var value := raw_value.strip_edges().to_lower()
	if value.is_empty():
		return "audit"
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	return value.trim_prefix("_").trim_suffix("_")

func _string_array(value: Variant) -> Array[String]:
	var resolved: Array[String] = []
	if value is Array:
		for item in value as Array:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			resolved.append(text)
	return resolved

func _sanitize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var resolved: Dictionary = {}
			var source := value as Dictionary
			for key_variant in source.keys():
				var key := str(key_variant).strip_edges()
				if key.is_empty():
					continue
				var nested_value: Variant = source.get(key_variant)
				if nested_value is SurveyQuestion:
					continue
				resolved[key] = _sanitize_variant(nested_value)
			return resolved
		TYPE_ARRAY:
			var resolved_array: Array = []
			for item in value as Array:
				if item is SurveyQuestion:
					continue
				resolved_array.append(_sanitize_variant(item))
			return resolved_array
		TYPE_PACKED_STRING_ARRAY:
			var strings: Array = []
			for item in value as PackedStringArray:
				strings.append(str(item))
			return strings
		TYPE_STRING_NAME:
			return str(value)
	return value

func _duplicate_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_STRING_ARRAY:
			return (value as PackedStringArray).duplicate()
	return value

func _emit_status(message: String, is_error: bool) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return
	status_changed.emit(trimmed, is_error)
