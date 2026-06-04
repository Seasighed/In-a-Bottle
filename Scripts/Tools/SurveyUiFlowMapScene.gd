class_name SurveyUiFlowMapScene
extends Control

const SURVEY_BUILD_EXPORT_SUPPORT = preload("res://Scripts/Tools/SurveyBuildExportSupport.gd")
const SURVEY_UI_FLOW_CATALOG = preload("res://Scripts/Tools/SurveyUiFlowCatalog.gd")
const SURVEY_UI_FLOW_FIXTURES = preload("res://Scripts/Tools/SurveyUiFlowFixtures.gd")
const SURVEY_VISUAL_AUDIT_RUNNER = preload("res://Scripts/Tools/SurveyVisualAuditRunner.gd")
const SURVEY_APP_SCENE = preload("res://Scenes/Main.tscn")
const SURVEY_JOURNEY_SCENE = preload("res://Scenes/SurveyJourney.tscn")
const QUESTION_TYPE_GALLERY_SCENE = preload("res://Scenes/UI/QuestionTypeGallery.tscn")
const DEFAULT_DARK_PALETTE = preload("res://Themes/SurveyDarkPalette.tres")
const DEFAULT_LIGHT_PALETTE = preload("res://Themes/SurveyLightPalette.tres")

@export var dark_palette: Resource = DEFAULT_DARK_PALETTE
@export var light_palette: Resource = DEFAULT_LIGHT_PALETTE
@export var use_dark_mode := true
@export var autogenerate_on_ready := true
@export var output_directory := SURVEY_UI_FLOW_CATALOG.OUTPUT_DIRECTORY
@export var default_builds_directory := SURVEY_BUILD_EXPORT_SUPPORT.DEFAULT_BUILDS_DIRECTORY

var _generation_in_progress := false
var _build_export_in_progress := false
var _visual_audit_in_progress := false
var _latest_graph: Dictionary = {}
var _export_paths_by_id: Dictionary = {}
var _build_presets: Array[Dictionary] = []
var _export_buttons: Array[Button] = []
var _capture_placeholder_warning_emitted := false
var _suppress_build_directory_updates := false
var _build_folder_dialog: FileDialog
var _visual_audit_runner: SurveyVisualAuditRunner

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Margin/Stack/Toolbar/TitleLabel
@onready var _generate_button: Button = $Margin/Stack/Toolbar/GenerateButton
@onready var _open_folder_button: Button = $Margin/Stack/Toolbar/OpenFolderButton
@onready var _visual_audit_button: Button = $Margin/Stack/Toolbar/VisualAuditButton
@onready var _build_panel: PanelContainer = $Margin/Stack/BuildPanel
@onready var _build_heading_label: Label = $Margin/Stack/BuildPanel/BuildStack/BuildHeadingLabel
@onready var _build_description_label: Label = $Margin/Stack/BuildPanel/BuildStack/BuildDescriptionLabel
@onready var _build_folder_field: LineEdit = $Margin/Stack/BuildPanel/BuildStack/BuildFolderRow/BuildFolderField
@onready var _build_browse_button: Button = $Margin/Stack/BuildPanel/BuildStack/BuildFolderRow/BuildBrowseButton
@onready var _build_open_button: Button = $Margin/Stack/BuildPanel/BuildStack/BuildFolderRow/BuildOpenButton
@onready var _next_build_label: Label = $Margin/Stack/BuildPanel/BuildStack/NextBuildLabel
@onready var _build_buttons_flow: HFlowContainer = $Margin/Stack/BuildPanel/BuildStack/BuildButtonsFlow
@onready var _build_status_label: Label = $Margin/Stack/BuildPanel/BuildStack/BuildStatusLabel
@onready var _status_label: Label = $Margin/Stack/StatusLabel
@onready var _flow_canvas = $Margin/Stack/FlowScroll/FlowCanvas
@onready var _capture_root: Node = $CaptureRoot

func _ready() -> void:
	SurveyStyle.configure_palettes(dark_palette if dark_palette != null else DEFAULT_DARK_PALETTE, light_palette if light_palette != null else DEFAULT_LIGHT_PALETTE, use_dark_mode)
	_apply_theme()
	_ensure_visual_audit_runner()
	_generate_button.pressed.connect(_on_generate_pressed)
	_open_folder_button.pressed.connect(_on_open_folder_pressed)
	_visual_audit_button.pressed.connect(_on_visual_audit_pressed)
	_build_folder_field.text_changed.connect(_on_build_folder_text_changed)
	_build_folder_field.text_submitted.connect(_on_build_folder_text_submitted)
	_build_folder_field.focus_exited.connect(_on_build_folder_focus_exited)
	_build_browse_button.pressed.connect(_on_build_browse_pressed)
	_build_open_button.pressed.connect(_on_build_open_folder_pressed)
	_title_label.text = "UI Flow Map"
	_build_heading_label.text = "Versioned Build Exports"
	_build_description_label.text = "Pick a Builds folder, then export the next incremented release using the presets from export_presets.cfg."
	_status_label.text = "Ready to generate the UI flow atlas."
	_build_presets = SURVEY_BUILD_EXPORT_SUPPORT.available_presets()
	_load_build_export_preferences()
	_create_build_folder_dialog()
	_rebuild_build_buttons()
	_refresh_build_preview()
	_refresh_build_ready_status()
	if autogenerate_on_ready:
		call_deferred("regenerate_map")

func build_flow_graph() -> Dictionary:
	return _visual_audit_runner.build_flow_graph() if _visual_audit_runner != null else SURVEY_UI_FLOW_CATALOG.build_graph()

func export_directory_path() -> String:
	var preferred_output := output_directory.strip_edges()
	if preferred_output.is_empty():
		preferred_output = str(SURVEY_UI_FLOW_CATALOG.build_graph().get("output_directory", SURVEY_UI_FLOW_CATALOG.OUTPUT_DIRECTORY))
	return ProjectSettings.globalize_path(preferred_output)

func available_build_presets() -> Array[Dictionary]:
	return _build_presets.duplicate(true)

func build_export_directory_path() -> String:
	return SURVEY_BUILD_EXPORT_SUPPORT.normalize_directory_path(_build_folder_field.text, default_builds_directory)

func preview_next_build_version() -> Dictionary:
	return SURVEY_BUILD_EXPORT_SUPPORT.next_version_info(build_export_directory_path())

func regenerate_map() -> void:
	if _generation_in_progress or _visual_audit_in_progress:
		return
	_generation_in_progress = true
	_update_visual_interaction_state()
	var result := await _visual_audit_runner.generate_flow_map_assets(export_directory_path())
	if not bool(result.get("ok", false)):
		_status_label.text = str(result.get("message", "Unable to generate the UI flow atlas.")).strip_edges()
		_generation_in_progress = false
		_update_visual_interaction_state()
		return
	_latest_graph = result.get("graph", {}) as Dictionary
	_export_paths_by_id = result.get("export_paths_by_id", {}) as Dictionary
	_flow_canvas.set_graph(_latest_graph, result.get("textures_by_id", {}) as Dictionary, _export_paths_by_id)
	_status_label.text = "Captured %d UI states to %s" % [_export_paths_by_id.size(), export_directory_path()]
	_generation_in_progress = false
	_update_visual_interaction_state()

func _on_generate_pressed() -> void:
	regenerate_map()

func _on_visual_audit_pressed() -> void:
	_export_visual_audit_bundle()

func _on_open_folder_pressed() -> void:
	var folder_path := export_directory_path()
	var ensure_error := DirAccess.make_dir_recursive_absolute(folder_path)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(folder_path):
		_status_label.text = "Unable to prepare %s" % folder_path
		return
	var open_error := OS.shell_open(folder_path)
	_status_label.text = "Opened %s" % folder_path if open_error == OK else "Failed to open %s" % folder_path

func _ensure_visual_audit_runner() -> void:
	if _visual_audit_runner != null:
		_visual_audit_runner.configure_theme(dark_palette, light_palette, use_dark_mode)
		return
	_visual_audit_runner = SURVEY_VISUAL_AUDIT_RUNNER.new()
	_visual_audit_runner.name = "SurveyVisualAuditRunner"
	add_child(_visual_audit_runner)
	_visual_audit_runner.configure_theme(dark_palette, light_palette, use_dark_mode)
	_visual_audit_runner.status_changed.connect(_on_visual_audit_status_changed)

func _update_visual_interaction_state() -> void:
	var busy := _generation_in_progress or _visual_audit_in_progress or _build_export_in_progress
	_generate_button.disabled = busy
	_open_folder_button.disabled = busy
	_visual_audit_button.disabled = busy

func _on_visual_audit_status_changed(message: String, is_error: bool) -> void:
	_status_label.text = message
	SurveyStyle.style_body(_status_label, SurveyStyle.DANGER if is_error else SurveyStyle.TEXT_MUTED)

func _export_visual_audit_bundle() -> void:
	if _visual_audit_in_progress or _generation_in_progress:
		return
	_visual_audit_in_progress = true
	_update_visual_interaction_state()
	_status_label.text = "Exporting the visual audit bundle..."
	var result := await _visual_audit_runner.export_visual_audit_bundle()
	_visual_audit_in_progress = false
	_update_visual_interaction_state()
	if not bool(result.get("ok", false)):
		_status_label.text = str(result.get("message", "Unable to export the visual audit bundle.")).strip_edges()
		SurveyStyle.style_body(_status_label, SurveyStyle.DANGER)
		return
	var zip_absolute_path := str(result.get("zip_absolute_path", "")).strip_edges()
	if not zip_absolute_path.is_empty():
		_status_label.text = "Visual audit bundle exported to %s" % zip_absolute_path
		SurveyStyle.style_body(_status_label, SurveyStyle.TEXT_MUTED)
		OS.shell_open(zip_absolute_path.get_base_dir())
		return
	_status_label.text = "Visual audit bundle export finished."
	SurveyStyle.style_body(_status_label, SurveyStyle.TEXT_MUTED)

func _on_build_folder_text_changed(_new_text: String) -> void:
	if _suppress_build_directory_updates:
		return
	_refresh_build_preview()

func _on_build_folder_text_submitted(new_text: String) -> void:
	_commit_build_output_directory(new_text)

func _on_build_folder_focus_exited() -> void:
	_commit_build_output_directory(_build_folder_field.text)

func _on_build_browse_pressed() -> void:
	if _build_folder_dialog == null:
		return
	_build_folder_dialog.current_dir = build_export_directory_path()
	_build_folder_dialog.current_path = build_export_directory_path()
	_build_folder_dialog.popup_centered_ratio(0.7)

func _on_build_open_folder_pressed() -> void:
	var folder_path := build_export_directory_path()
	var ensure_error := DirAccess.make_dir_recursive_absolute(folder_path)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(folder_path):
		_set_build_status("Unable to prepare %s." % folder_path, true)
		return
	var open_error := OS.shell_open(folder_path)
	_set_build_status("Opened %s." % folder_path if open_error == OK else "Failed to open %s." % folder_path, open_error != OK)

func _on_build_folder_selected(dir_path: String) -> void:
	_commit_build_output_directory(dir_path)

func _on_export_all_pressed() -> void:
	await _export_builds(_build_presets)

func _on_export_preset_pressed(preset_index: int) -> void:
	for preset in _build_presets:
		if int(preset.get("index", -1)) == preset_index:
			await _export_builds([preset])
			return
	_set_build_status("Unable to find export preset %d." % preset_index, true)

func _capture_node(node_spec: Dictionary) -> Image:
	match str(node_spec.get("source_kind", "")).strip_edges():
		"survey_app":
			return await _capture_survey_app(node_spec)
		"survey_journey":
			return await _capture_survey_journey(node_spec)
		"question_gallery":
			return await _capture_question_gallery(node_spec)
	return _placeholder_image()

func _capture_survey_app(node_spec: Dictionary) -> Image:
	var viewport_size := node_spec.get("viewport_size", SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT) as Vector2i
	var viewport := _create_capture_viewport(viewport_size)
	var app: Control = SURVEY_APP_SCENE.instantiate()
	app.set("launch_fullscreen", false)
	app.set("use_saved_dev_data", false)
	viewport.add_child(app)
	_fit_control_to_viewport(app, viewport_size)
	await _await_capture_frames(4)
	app.call("_close_onboarding_overlay")
	await _await_capture_frames(3)

	match str(node_spec.get("state", "")).strip_edges():
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

func _capture_survey_journey(node_spec: Dictionary) -> Image:
	var viewport_size := node_spec.get("viewport_size", SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT) as Vector2i
	var viewport := _create_capture_viewport(viewport_size)
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	journey.set("persist_selected_template", false)
	viewport.add_child(journey)
	_fit_control_to_viewport(journey, viewport_size)
	await _await_capture_frames(4)
	journey.call("_load_survey_from_path", SURVEY_UI_FLOW_FIXTURES.default_template_path(), false)
	await _await_capture_frames(4)

	match str(node_spec.get("state", "")).strip_edges():
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

func _capture_question_gallery(node_spec: Dictionary) -> Image:
	var viewport_size := node_spec.get("viewport_size", SURVEY_UI_FLOW_CATALOG.GALLERY_VIEWPORT) as Vector2i
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

func _create_capture_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = viewport_size
	_capture_root.add_child(viewport)
	return viewport

func _fit_control_to_viewport(control: Control, viewport_size: Vector2i) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.custom_minimum_size = Vector2(viewport_size)

func _finalize_capture(viewport: SubViewport) -> Image:
	await _await_capture_frames(2)
	if DisplayServer.get_name() == "headless":
		if not _capture_placeholder_warning_emitted:
			push_warning("SubViewport captures are unavailable in headless mode. Using placeholder images for the UI flow export.")
			_capture_placeholder_warning_emitted = true
		viewport.queue_free()
		await get_tree().process_frame
		return _placeholder_image()
	var texture := viewport.get_texture()
	var image: Image = null
	if texture != null:
		image = texture.get_image()
	if image == null:
		if not _capture_placeholder_warning_emitted:
			push_warning("SubViewport textures are unavailable in the active renderer. Using placeholder images for the UI flow export.")
			_capture_placeholder_warning_emitted = true
		image = _placeholder_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image

func _await_capture_frames(count: int) -> void:
	for _index in range(maxi(count, 1)):
		await get_tree().process_frame

func _prepare_output_directory(export_dir: String) -> void:
	var ensure_error := DirAccess.make_dir_recursive_absolute(export_dir)
	if ensure_error != OK and not DirAccess.dir_exists_absolute(export_dir):
		push_error("Failed to prepare %s" % export_dir)

func _write_manifest(export_dir: String) -> void:
	var manifest_nodes: Array[Dictionary] = []
	var manifest_edges: Array[Dictionary] = []
	var manifest := {
		"title": str(_latest_graph.get("title", "UI Flow Map")),
		"generated_at": Time.get_datetime_string_from_system(true),
		"canvas_size": _vector2i_to_array(_latest_graph.get("canvas_size", Vector2i.ZERO) as Vector2i),
		"nodes": manifest_nodes,
		"edges": manifest_edges
	}
	var node_values: Variant = _latest_graph.get("nodes", [])
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
				"image_path": str(_export_paths_by_id.get(node_id, ""))
			})
	var edge_values: Variant = _latest_graph.get("edges", [])
	if edge_values is Array:
		for edge_value in edge_values:
			if edge_value is Dictionary:
				manifest_edges.append((edge_value as Dictionary).duplicate(true))
	var file := FileAccess.open("%s/flow_manifest.json" % export_dir.trim_suffix("/"), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

func _placeholder_image() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.86, 0.18, 0.18, 1.0))
	return image

func _vector2_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]

func _vector2i_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]

func _apply_theme() -> void:
	_background.color = SurveyStyle.BACKGROUND
	SurveyStyle.style_heading(_title_label, 28)
	SurveyStyle.apply_primary_button(_generate_button)
	SurveyStyle.apply_secondary_button(_open_folder_button)
	SurveyStyle.apply_primary_button(_visual_audit_button)
	SurveyStyle.apply_panel(_build_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	SurveyStyle.style_heading(_build_heading_label, 18)
	SurveyStyle.style_body(_build_description_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_line_edit(_build_folder_field)
	SurveyStyle.apply_secondary_button(_build_browse_button)
	SurveyStyle.apply_secondary_button(_build_open_button)
	SurveyStyle.style_body(_next_build_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_body(_build_status_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_body(_status_label, SurveyStyle.TEXT_MUTED)

func _load_build_export_preferences() -> void:
	_set_build_directory_field(SURVEY_BUILD_EXPORT_SUPPORT.load_builds_directory(default_builds_directory))

func _set_build_directory_field(path: String) -> void:
	_suppress_build_directory_updates = true
	_build_folder_field.text = SURVEY_BUILD_EXPORT_SUPPORT.normalize_directory_path(path, default_builds_directory)
	_suppress_build_directory_updates = false

func _commit_build_output_directory(raw_path: String) -> void:
	var normalized_path := SURVEY_BUILD_EXPORT_SUPPORT.normalize_directory_path(raw_path, default_builds_directory)
	_set_build_directory_field(normalized_path)
	var save_error := SURVEY_BUILD_EXPORT_SUPPORT.save_builds_directory(normalized_path, default_builds_directory)
	_refresh_build_preview()
	if save_error != OK:
		_set_build_status("Saved the build path for this session, but failed to persist it to user://.", true)
		return
	if not _build_export_in_progress:
		_refresh_build_ready_status()

func _create_build_folder_dialog() -> void:
	_build_folder_dialog = FileDialog.new()
	_build_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_build_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_build_folder_dialog.title = "Choose Builds Folder"
	_build_folder_dialog.dir_selected.connect(_on_build_folder_selected)
	add_child(_build_folder_dialog)

func _rebuild_build_buttons() -> void:
	_export_buttons.clear()
	for child in _build_buttons_flow.get_children():
		child.queue_free()
	if _build_presets.is_empty():
		return
	if _build_presets.size() > 1:
		var export_all_button := Button.new()
		export_all_button.text = "Export All To Next Version"
		export_all_button.tooltip_text = "Export every configured preset into the same next version folder."
		SurveyStyle.apply_primary_button(export_all_button)
		export_all_button.pressed.connect(_on_export_all_pressed)
		_build_buttons_flow.add_child(export_all_button)
		_export_buttons.append(export_all_button)
	for preset in _build_presets:
		var button := Button.new()
		var preset_name := str(preset.get("name", "Build")).strip_edges()
		button.text = "Export Next %s Build" % preset_name
		button.tooltip_text = _build_preset_tooltip(preset)
		if _build_presets.size() == 1:
			SurveyStyle.apply_primary_button(button)
		else:
			SurveyStyle.apply_secondary_button(button)
		button.pressed.connect(_on_export_preset_pressed.bind(int(preset.get("index", -1))))
		_build_buttons_flow.add_child(button)
		_export_buttons.append(button)
	_update_build_interaction_state()

func _build_preset_tooltip(preset: Dictionary) -> String:
	var preset_name := str(preset.get("name", "Build")).strip_edges()
	var platform := str(preset.get("platform", "")).strip_edges()
	var relative_path := str(preset.get("relative_export_path", "")).strip_edges()
	var details: Array[String] = ["Export %s to the next version folder." % preset_name]
	if not platform.is_empty():
		details.append("Platform: %s" % platform)
	if not relative_path.is_empty():
		details.append("Output: %s" % relative_path)
	return "\n".join(details)

func _refresh_build_preview() -> void:
	var next_version := preview_next_build_version()
	_next_build_label.text = "Next build slot: %s  ->  %s" % [str(next_version.get("label", "v001")), str(next_version.get("path", build_export_directory_path()))]
	_update_build_interaction_state()

func _refresh_build_ready_status() -> void:
	_set_build_status(_default_build_status_text(), false)

func _default_build_status_text() -> String:
	if _build_presets.is_empty():
		return "No export presets were found in export_presets.cfg."
	var next_version := preview_next_build_version()
	return "Ready to export %d preset(s) into %s." % [_build_presets.size(), str(next_version.get("path", build_export_directory_path()))]

func _set_build_status(message: String, is_error: bool = false) -> void:
	_build_status_label.text = message
	SurveyStyle.style_body(_build_status_label, SurveyStyle.DANGER if is_error else SurveyStyle.TEXT_MUTED)

func _update_build_interaction_state() -> void:
	var export_enabled := not _build_export_in_progress and not _build_presets.is_empty()
	_build_folder_field.editable = not _build_export_in_progress
	_build_browse_button.disabled = _build_export_in_progress
	_build_open_button.disabled = _build_export_in_progress
	for button in _export_buttons:
		button.disabled = not export_enabled
	_update_visual_interaction_state()

func _export_builds(presets: Array[Dictionary]) -> void:
	if _build_export_in_progress:
		return
	if presets.is_empty():
		_set_build_status("There are no export presets available to build.", true)
		return
	var executable_path := OS.get_executable_path().strip_edges()
	if executable_path.is_empty():
		_set_build_status("Unable to locate the current Godot executable for export.", true)
		return
	_commit_build_output_directory(_build_folder_field.text)
	var next_version := preview_next_build_version()
	var version_label := str(next_version.get("label", "")).strip_edges()
	var version_root := str(next_version.get("path", "")).strip_edges()
	var ensure_root_error := DirAccess.make_dir_recursive_absolute(version_root)
	if ensure_root_error != OK and not DirAccess.dir_exists_absolute(version_root):
		_set_build_status("Unable to prepare %s." % version_root, true)
		return
	_build_export_in_progress = true
	_update_build_interaction_state()
	_set_build_status("Exporting %d preset(s) to %s..." % [presets.size(), version_root])
	await get_tree().process_frame

	var exported_paths: Array[String] = []
	var failures: Array[String] = []
	for preset in presets:
		var preset_name := str(preset.get("name", "Build")).strip_edges()
		var blocker_message := SURVEY_BUILD_EXPORT_SUPPORT.export_blocker_message(preset, executable_path)
		if not blocker_message.is_empty():
			failures.append("%s blocked before export. %s" % [preset_name, blocker_message])
			continue
		var target_path := SURVEY_BUILD_EXPORT_SUPPORT.build_target_path(build_export_directory_path(), version_label, preset)
		var ensure_target_error := SURVEY_BUILD_EXPORT_SUPPORT.ensure_parent_directory(target_path)
		if ensure_target_error != OK:
			failures.append("Failed to prepare %s for %s (error %d)." % [target_path.get_base_dir(), preset_name, ensure_target_error])
			continue
		var command := SURVEY_BUILD_EXPORT_SUPPORT.build_export_command(preset_name, target_path, executable_path)
		var output: Array = []
		var exit_code := OS.execute(
			str(command.get("executable", "")),
			command.get("arguments", PackedStringArray()),
			output,
			true
		)
		if exit_code == 0:
			var verification := SURVEY_BUILD_EXPORT_SUPPORT.verify_export_artifacts(target_path, preset)
			if bool(verification.get("ok", false)):
				exported_paths.append(target_path)
				continue
			var missing_artifacts := verification.get("missing", PackedStringArray()) as PackedStringArray
			failures.append(
				"%s finished without reporting an export error, but the expected artifact(s) were missing: %s" % [
					preset_name,
					", ".join(missing_artifacts)
				]
			)
			continue
		failures.append(_format_build_export_failure(preset_name, exit_code, output))

	_build_export_in_progress = false
	_refresh_build_preview()
	if failures.is_empty():
		SurveyUiFeedback.play_export()
		_set_build_status("Exported %d preset(s) to %s." % [exported_paths.size(), version_root])
		return
	if exported_paths.is_empty():
		_set_build_status("Build export failed. %s" % failures[0], true)
		return
	_set_build_status(
		"Exported %d preset(s) to %s, but %d export(s) failed. %s" % [exported_paths.size(), version_root, failures.size(), failures[0]],
		true
	)

func _format_build_export_failure(preset_name: String, exit_code: int, output: Array) -> String:
	var last_line := ""
	for entry in output:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			last_line = text
	return "%s failed with exit code %d.%s" % [
		preset_name,
		exit_code,
		" %s" % last_line if not last_line.is_empty() else ""
	]
