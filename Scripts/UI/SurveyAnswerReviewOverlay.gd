class_name SurveyAnswerReviewOverlay
extends CanvasLayer

const WRAPPED_CARD_SCRIPT = preload("res://Scripts/UI/SurveyAnswerWrappedCard.gd")
const SURVEY_ANSWER_REVIEW = preload("res://Scripts/Survey/SurveyAnswerReview.gd")
const SURVEY_SHARE_PROFILE_STORE = preload("res://Scripts/Survey/SurveyShareProfileStore.gd")

signal close_requested
signal choose_folder_requested
signal rescan_requested
signal settings_changed(recursive: bool, scrub_identifying_info: bool, wrapped_theme_id: String, gradient_preset_id: String, respondent_color_overrides: Dictionary, text_summary_mode: String)
signal save_wrapped_png_requested

const TAB_REVIEW := "review"
const TAB_SUMMARY := "summary"
const TAB_EXPORT_SETTINGS := "export_settings"

var _survey: SurveyDefinition
var _scan_report: Dictionary = {}
var _settings: Dictionary = {}
var _scrub_identifying_info := true
var _recursive_scan := true
var _wrapped_theme_id := SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT
var _gradient_preset_id := SURVEY_ANSWER_REVIEW.WRAP_DEFAULT_GRADIENT_PRESET
var _text_summary_mode := SURVEY_ANSWER_REVIEW.WRAP_TEXT_SUMMARY_AUTO
var _respondent_color_overrides: Dictionary = {}
var _share_profile: Dictionary = {}
var _updating_profile_controls := false
var _updating_color_controls := false
var _active_tab := TAB_REVIEW
var _dimmer: ColorRect
var _bounds: MarginContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _stack: VBoxContainer
var _heading_label: Label
var _subtitle_label: Label
var _folder_label: Label
var _status_label: Label
var _choose_folder_button: Button
var _rescan_button: Button
var _save_png_button: Button
var _recursive_checkbox: CheckBox
var _scrub_checkbox: CheckBox
var _theme_option: OptionButton
var _gradient_option: OptionButton
var _tab_buttons: Dictionary = {}
var _tab_containers: Dictionary = {}
var _review_tab: VBoxContainer
var _summary_tab: VBoxContainer
var _settings_tab: VBoxContainer
var _summary_status_label: Label
var _summary_hint_label: Label
var _respondent_colors_list: VBoxContainer
var _respondent_color_rows: Array[Dictionary] = []
var _show_profile_checkbox: CheckBox
var _profile_name_field: LineEdit
var _profile_fields_list: VBoxContainer
var _add_profile_field_button: Button
var _profile_field_rows: Array[Dictionary] = []
var _purge_profile_button: Button
var _stats_grid: GridContainer
var _questions_list: VBoxContainer

func _ready() -> void:
	layer = 58
	visible = false
	_build_nodes()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func open_review(survey: SurveyDefinition, settings: Dictionary, scan_report: Dictionary = {}) -> void:
	_survey = survey
	_settings = settings.duplicate(true)
	_scan_report = scan_report.duplicate(true)
	_recursive_scan = bool(_settings.get("recursive", true))
	_scrub_identifying_info = bool(_settings.get("scrub_identifying_info", true))
	_wrapped_theme_id = str(_settings.get("wrapped_theme_id", SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT))
	_gradient_preset_id = str(_settings.get("wrapped_gradient_preset_id", SURVEY_ANSWER_REVIEW.WRAP_DEFAULT_GRADIENT_PRESET))
	_text_summary_mode = str(_settings.get("text_summary_mode", SURVEY_ANSWER_REVIEW.WRAP_TEXT_SUMMARY_AUTO))
	_respondent_color_overrides = _settings.get("respondent_color_overrides", {}) as Dictionary if _settings.get("respondent_color_overrides", {}) is Dictionary else {}
	_share_profile = SURVEY_SHARE_PROFILE_STORE.load_profile()
	_apply_state()
	show()
	call_deferred("_reset_scroll_position")

func update_scan_report(scan_report: Dictionary, settings: Dictionary = {}) -> void:
	_scan_report = scan_report.duplicate(true)
	if not settings.is_empty():
		_settings = settings.duplicate(true)
		_recursive_scan = bool(_settings.get("recursive", _recursive_scan))
		_scrub_identifying_info = bool(_settings.get("scrub_identifying_info", _scrub_identifying_info))
		_wrapped_theme_id = str(_settings.get("wrapped_theme_id", _wrapped_theme_id))
		_gradient_preset_id = str(_settings.get("wrapped_gradient_preset_id", _gradient_preset_id))
		_text_summary_mode = str(_settings.get("text_summary_mode", _text_summary_mode))
		_respondent_color_overrides = _settings.get("respondent_color_overrides", _respondent_color_overrides) as Dictionary if _settings.get("respondent_color_overrides", _respondent_color_overrides) is Dictionary else {}
	_apply_state()

func close_review() -> void:
	hide()

func current_recursive_scan() -> bool:
	return _recursive_checkbox.button_pressed if _recursive_checkbox != null else _recursive_scan

func current_scrub_identifying_info() -> bool:
	return _scrub_checkbox.button_pressed if _scrub_checkbox != null else _scrub_identifying_info

func current_wrapped_theme_id() -> String:
	if _theme_option != null:
		var selected_id := str(_theme_option.get_item_metadata(_theme_option.selected)).strip_edges()
		if not selected_id.is_empty():
			return selected_id
	return _wrapped_theme_id

func current_gradient_preset_id() -> String:
	if _gradient_option != null:
		var selected_id := str(_gradient_option.get_item_metadata(_gradient_option.selected)).strip_edges()
		if not selected_id.is_empty():
			return selected_id
	return _gradient_preset_id

func current_respondent_color_overrides() -> Dictionary:
	return _respondent_color_overrides.duplicate(true)

func current_text_summary_mode() -> String:
	return _text_summary_mode

func current_wrap_options() -> Dictionary:
	return {
		"gradient_preset_id": current_gradient_preset_id(),
		"respondent_color_overrides": current_respondent_color_overrides(),
		"text_summary_mode": current_text_summary_mode()
	}

func current_share_profile() -> Dictionary:
	return _share_profile.duplicate(true)

func current_folder_path() -> String:
	return str(_settings.get("folder_path", "")).strip_edges()

func set_busy(busy: bool) -> void:
	if _rescan_button != null:
		_rescan_button.disabled = busy or current_folder_path().is_empty()
	if _choose_folder_button != null:
		_choose_folder_button.disabled = busy
	if _save_png_button != null:
		_save_png_button.disabled = busy or int(_scan_report.get("accepted_count", 0)) <= 0

func refresh_theme() -> void:
	if not is_node_ready():
		return
	_dimmer.color = SurveyStyle.OVERLAY_DIMMER
	SurveyStyle.apply_panel(_panel, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.style_caption(_folder_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_caption(_status_label)
	SurveyStyle.apply_secondary_button(_choose_folder_button)
	SurveyStyle.apply_primary_button(_rescan_button)
	SurveyStyle.apply_secondary_button(_save_png_button)
	SurveyStyle.style_check_box(_recursive_checkbox)
	SurveyStyle.style_check_box(_scrub_checkbox)
	SurveyStyle.style_option_button(_theme_option)
	SurveyStyle.style_option_button(_gradient_option)
	_style_tab_buttons()
	SurveyStyle.style_check_box(_show_profile_checkbox)
	SurveyStyle.style_line_edit(_profile_name_field)
	SurveyStyle.apply_secondary_button(_add_profile_field_button)
	_style_profile_field_rows()
	_style_respondent_color_rows()
	SurveyStyle.apply_danger_button(_purge_profile_button)

func refresh_layout(viewport_size: Vector2) -> void:
	if not is_node_ready():
		return
	var horizontal_margin := clampf(viewport_size.x * 0.04, 12.0, 64.0)
	var vertical_margin := clampf(viewport_size.y * 0.04, 12.0, 48.0)
	_bounds.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bounds.add_theme_constant_override("margin_top", int(vertical_margin))
	_bounds.add_theme_constant_override("margin_bottom", int(vertical_margin))
	_panel.custom_minimum_size = Vector2(clampf(viewport_size.x - (horizontal_margin * 2.0), 320.0, 1120.0), 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, clampf(viewport_size.y - (vertical_margin * 2.0), 320.0, 820.0))
	_stats_grid.columns = 1 if viewport_size.x <= 700.0 else 3

func capture_wrapped_pages(pages_data: Dictionary) -> Array[Dictionary]:
	var captures: Array[Dictionary] = []
	if pages_data.is_empty():
		return captures
	var pages: Array = pages_data.get("pages", [])
	if pages.is_empty():
		pages = [pages_data]
	for index in range(pages.size()):
		if not (pages[index] is Dictionary):
			continue
		var page: Dictionary = pages[index] as Dictionary
		var viewport := SubViewport.new()
		viewport.disable_3d = true
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.size = Vector2i(
			int(page.get("page_width", pages_data.get("page_width", SURVEY_ANSWER_REVIEW.WRAP_PAGE_WIDTH))),
			int(page.get("page_height", pages_data.get("page_height", SURVEY_ANSWER_REVIEW.WRAP_PAGE_HEIGHT)))
		)
		add_child(viewport)
		var card = WRAPPED_CARD_SCRIPT.new()
		viewport.add_child(card)
		card.custom_minimum_size = Vector2(viewport.size)
		card.size = Vector2(viewport.size)
		if pages_data.has("pages"):
			card.configure_page(page, pages_data)
		else:
			card.configure(pages_data)
		card.refresh_layout(float(viewport.size.x))
		await get_tree().process_frame
		var layout_metrics: Dictionary = card.get_layout_metrics() if card.has_method("get_layout_metrics") else {}
		if DisplayServer.get_name() == "headless":
			var placeholder := Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
			placeholder.fill(Color("101826") if str(page.get("theme_id", pages_data.get("theme_id", ""))) == SURVEY_ANSWER_REVIEW.WRAP_THEME_DARK else Color("eef6ff"))
			viewport.queue_free()
			await get_tree().process_frame
			captures.append(_wrapped_capture_payload(placeholder, page, index + 1, pages.size(), layout_metrics))
			continue
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		layout_metrics = card.get_layout_metrics() if card.has_method("get_layout_metrics") else layout_metrics
		viewport.queue_free()
		await get_tree().process_frame
		captures.append(_wrapped_capture_payload(image, page, index + 1, pages.size(), layout_metrics))
	return captures

func measure_wrapped_pages(pages_data: Dictionary) -> Array[Dictionary]:
	var captures := await capture_wrapped_pages(pages_data)
	var metrics: Array[Dictionary] = []
	for capture_value in captures:
		if capture_value is Dictionary:
			metrics.append(((capture_value as Dictionary).get("layout_metrics", {}) as Dictionary).duplicate(true))
	return metrics

func capture_wrapped_image(summary_data: Dictionary) -> Image:
	var captures := await capture_wrapped_pages(summary_data)
	if captures.is_empty():
		return null
	return captures[0].get("image", null) as Image

func _wrapped_capture_payload(image: Image, page: Dictionary, fallback_page_number: int, fallback_page_count: int, layout_metrics: Dictionary = {}) -> Dictionary:
	return {
		"image": image,
		"file_name": str(page.get("file_name", "wrapped_%02d.png" % fallback_page_number)),
		"page_number": int(page.get("page_number", fallback_page_number)),
		"page_count": int(page.get("page_count", fallback_page_count)),
		"page_kind": str(page.get("page_kind", "answers")),
		"section_id": str(page.get("section_id", "")),
		"part_number": int(page.get("section_part_number", 1)),
		"part_count": int(page.get("section_part_count", 1)),
		"layout_metrics": layout_metrics.duplicate(true)
	}

func _build_nodes() -> void:
	if _dimmer != null:
		return
	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	add_child(_dimmer)

	_bounds = MarginContainer.new()
	_bounds.name = "Bounds"
	_bounds.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bounds)

	var center := CenterContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bounds.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	center.add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_theme_constant_override("separation", 14)
	_scroll.add_child(_stack)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	_stack.add_child(top_row)
	_heading_label = Label.new()
	_heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(_heading_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close imported answer review"
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	top_row.add_child(close_button)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_subtitle_label)

	_folder_label = Label.new()
	_folder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_folder_label)

	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	_stack.add_child(actions)
	_choose_folder_button = Button.new()
	_choose_folder_button.text = "Choose Folder"
	_choose_folder_button.pressed.connect(func() -> void: choose_folder_requested.emit())
	actions.add_child(_choose_folder_button)
	_rescan_button = Button.new()
	_rescan_button.text = "Rescan"
	_rescan_button.pressed.connect(func() -> void: rescan_requested.emit())
	actions.add_child(_rescan_button)

	_recursive_checkbox = CheckBox.new()
	_recursive_checkbox.text = "Scan subfolders"
	_recursive_checkbox.toggled.connect(_on_option_toggled)
	_stack.add_child(_recursive_checkbox)

	_stack.add_child(_tab_button_row())

	_review_tab = VBoxContainer.new()
	_review_tab.name = "ReviewTab"
	_review_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_tab.add_theme_constant_override("separation", 12)
	_stack.add_child(_review_tab)
	_tab_containers[TAB_REVIEW] = _review_tab
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_tab.add_child(_status_label)

	_stats_grid = GridContainer.new()
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", 10)
	_stats_grid.add_theme_constant_override("v_separation", 10)
	_review_tab.add_child(_stats_grid)

	_questions_list = VBoxContainer.new()
	_questions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_questions_list.add_theme_constant_override("separation", 10)
	_review_tab.add_child(_questions_list)

	_summary_tab = VBoxContainer.new()
	_summary_tab.name = "SummaryTab"
	_summary_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_tab.add_theme_constant_override("separation", 12)
	_stack.add_child(_summary_tab)
	_tab_containers[TAB_SUMMARY] = _summary_tab
	_summary_status_label = Label.new()
	_summary_status_label.name = "SummaryStatus"
	_summary_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_tab.add_child(_summary_status_label)
	_summary_hint_label = Label.new()
	_summary_hint_label.name = "SummaryPreviewStatus"
	_summary_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_tab.add_child(_summary_hint_label)
	_save_png_button = Button.new()
	_save_png_button.name = "SaveWrappedPagesButton"
	_save_png_button.text = "Save Wrapped Pages"
	_save_png_button.pressed.connect(func() -> void: save_wrapped_png_requested.emit())
	_summary_tab.add_child(_save_png_button)

	_settings_tab = VBoxContainer.new()
	_settings_tab.name = "ExportSettingsTab"
	_settings_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_tab.add_theme_constant_override("separation", 12)
	_stack.add_child(_settings_tab)
	_tab_containers[TAB_EXPORT_SETTINGS] = _settings_tab
	_settings_tab.add_child(_wrap_settings_panel())
	_apply_active_tab()

func _tab_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ReviewTabButtons"
	row.add_theme_constant_override("separation", 8)
	_tab_buttons.clear()
	row.add_child(_tab_button("Review", TAB_REVIEW, "ReviewTabButton"))
	row.add_child(_tab_button("Summary", TAB_SUMMARY, "SummaryTabButton"))
	row.add_child(_tab_button("Export Settings", TAB_EXPORT_SETTINGS, "ExportSettingsTabButton"))
	return row

func _tab_button(label: String, tab_id: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_active_tab = tab_id
		_apply_active_tab()
	)
	_tab_buttons[tab_id] = button
	return button

func _apply_active_tab() -> void:
	for key in _tab_containers.keys():
		var container := _tab_containers.get(key, null) as Control
		if container != null:
			container.visible = str(key) == _active_tab
	for key in _tab_buttons.keys():
		var button := _tab_buttons.get(key, null) as Button
		if button != null:
			button.set_pressed_no_signal(str(key) == _active_tab)

func _style_tab_buttons() -> void:
	for value in _tab_buttons.values():
		if value is Button:
			SurveyStyle.apply_secondary_button(value as Button)

func _add_gradient_option(label: String, preset_id: String) -> void:
	if _gradient_option == null:
		return
	var index := _gradient_option.item_count
	_gradient_option.add_item(label)
	_gradient_option.set_item_metadata(index, preset_id)

func _wrap_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "WrapSettingsPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 16, 1)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "Wrapped export profile"
	SurveyStyle.style_heading(title, 16)
	stack.add_child(title)

	_scrub_checkbox = CheckBox.new()
	_scrub_checkbox.text = "Hide identifying-marked text in review image"
	_scrub_checkbox.toggled.connect(_on_option_toggled)
	stack.add_child(_scrub_checkbox)

	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 8)
	stack.add_child(theme_row)
	var theme_label := Label.new()
	theme_label.text = "Theme"
	theme_label.custom_minimum_size = Vector2(92, 0)
	SurveyStyle.style_caption(theme_label, SurveyStyle.TEXT_MUTED)
	theme_row.add_child(theme_label)
	_theme_option = OptionButton.new()
	_theme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_theme_option.add_item("White gradient")
	_theme_option.set_item_metadata(0, SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT)
	_theme_option.add_item("Dark gradient")
	_theme_option.set_item_metadata(1, SURVEY_ANSWER_REVIEW.WRAP_THEME_DARK)
	_theme_option.item_selected.connect(_on_theme_selected)
	theme_row.add_child(_theme_option)

	var gradient_row := HBoxContainer.new()
	gradient_row.add_theme_constant_override("separation", 8)
	stack.add_child(gradient_row)
	var gradient_label := Label.new()
	gradient_label.text = "Gradient"
	gradient_label.custom_minimum_size = Vector2(92, 0)
	SurveyStyle.style_caption(gradient_label, SurveyStyle.TEXT_MUTED)
	gradient_row.add_child(gradient_label)
	_gradient_option = OptionButton.new()
	_gradient_option.name = "GradientPresetOption"
	_gradient_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_gradient_option("Soft white", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_SOFT_WHITE)
	_add_gradient_option("Sunrise", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_SUNRISE)
	_add_gradient_option("Mint", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_MINT)
	_add_gradient_option("Sky", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_SKY)
	_add_gradient_option("Rose", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_ROSE)
	_add_gradient_option("Violet", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_VIOLET)
	_add_gradient_option("Night", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_NIGHT)
	_add_gradient_option("Aurora", SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_AURORA)
	_gradient_option.item_selected.connect(_on_gradient_selected)
	gradient_row.add_child(_gradient_option)

	var respondent_title := Label.new()
	respondent_title.text = "Respondent colors"
	SurveyStyle.style_heading(respondent_title, 15)
	stack.add_child(respondent_title)
	_respondent_colors_list = VBoxContainer.new()
	_respondent_colors_list.name = "RespondentColorsList"
	_respondent_colors_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_respondent_colors_list.add_theme_constant_override("separation", 6)
	stack.add_child(_respondent_colors_list)

	_show_profile_checkbox = CheckBox.new()
	_show_profile_checkbox.text = "Show optional profile fields on wrapped pages"
	_show_profile_checkbox.toggled.connect(_on_share_profile_show_toggled)
	stack.add_child(_show_profile_checkbox)

	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 8)
	stack.add_child(profile_row)
	var profile_label := Label.new()
	profile_label.text = "Profile"
	profile_label.custom_minimum_size = Vector2(92, 0)
	SurveyStyle.style_caption(profile_label, SurveyStyle.TEXT_MUTED)
	profile_row.add_child(profile_label)
	_profile_name_field = LineEdit.new()
	_profile_name_field.placeholder_text = "Mushroom"
	_profile_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_name_field.text_changed.connect(_on_share_profile_text_changed)
	SurveyStyle.style_line_edit(_profile_name_field)
	profile_row.add_child(_profile_name_field)

	_profile_fields_list = VBoxContainer.new()
	_profile_fields_list.name = "ProfileFields"
	_profile_fields_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_fields_list.add_theme_constant_override("separation", 6)
	stack.add_child(_profile_fields_list)

	_add_profile_field_button = Button.new()
	_add_profile_field_button.text = "Add Profile Field"
	_add_profile_field_button.tooltip_text = "Add a custom profile label and value."
	_add_profile_field_button.pressed.connect(_on_add_profile_field_pressed)
	SurveyStyle.apply_secondary_button(_add_profile_field_button)
	stack.add_child(_add_profile_field_button)

	_purge_profile_button = Button.new()
	_purge_profile_button.text = "Purge Share Profile"
	_purge_profile_button.tooltip_text = "Remove the optional share profile stored on this device."
	_purge_profile_button.pressed.connect(_on_purge_profile_pressed)
	stack.add_child(_purge_profile_button)
	return panel

func _add_profile_field_row(field_data: Dictionary = {}) -> void:
	if _profile_fields_list == null:
		return
	var row := HBoxContainer.new()
	row.name = "ProfileFieldRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var label_field := LineEdit.new()
	label_field.placeholder_text = "Field"
	label_field.text = str(field_data.get("label", ""))
	label_field.custom_minimum_size = Vector2(150, 0)
	label_field.text_changed.connect(_on_share_profile_text_changed)
	row.add_child(label_field)
	var value_field := LineEdit.new()
	value_field.placeholder_text = "Value"
	value_field.text = str(field_data.get("value", ""))
	value_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_field.text_changed.connect(_on_share_profile_text_changed)
	row.add_child(value_field)
	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.tooltip_text = "Remove this profile field."
	row.add_child(remove_button)
	var row_data := {
		"container": row,
		"label_field": label_field,
		"value_field": value_field,
		"remove_button": remove_button
	}
	remove_button.pressed.connect(func() -> void: _remove_profile_field_row(row_data))
	_profile_field_rows.append(row_data)
	_profile_fields_list.add_child(row)
	SurveyStyle.style_line_edit(label_field)
	SurveyStyle.style_line_edit(value_field)
	SurveyStyle.apply_secondary_button(remove_button)

func _remove_profile_field_row(row_data: Dictionary) -> void:
	if _updating_profile_controls:
		return
	var container: Node = row_data.get("container", null) as Node
	_profile_field_rows.erase(row_data)
	if container != null and container.get_parent() != null:
		container.get_parent().remove_child(container)
		container.queue_free()
	_save_share_profile_from_controls()

func _style_profile_field_rows() -> void:
	for row_value in _profile_field_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value as Dictionary
		var label_field: LineEdit = row.get("label_field", null) as LineEdit
		var value_field: LineEdit = row.get("value_field", null) as LineEdit
		var remove_button: Button = row.get("remove_button", null) as Button
		if label_field != null:
			SurveyStyle.style_line_edit(label_field)
		if value_field != null:
			SurveyStyle.style_line_edit(value_field)
		if remove_button != null:
			SurveyStyle.apply_secondary_button(remove_button)

func _style_respondent_color_rows() -> void:
	for row_value in _respondent_color_rows:
		if not (row_value is Dictionary):
			continue
		var label: Label = (row_value as Dictionary).get("label", null) as Label
		var reset_button: Button = (row_value as Dictionary).get("reset_button", null) as Button
		if label != null:
			SurveyStyle.style_caption(label, SurveyStyle.SOFT_WHITE)
		if reset_button != null:
			SurveyStyle.apply_secondary_button(reset_button)

func _apply_state() -> void:
	if not is_node_ready():
		return
	var survey_title := _survey.title if _survey != null else "Survey"
	_heading_label.text = "Review Imported Answers"
	_subtitle_label.text = "Aggregate review for %s. Point this survey at a folder of compatible answer JSON files, then scan to tally preset options and read custom text answers together." % survey_title
	var folder_path := current_folder_path()
	_folder_label.text = "Folder: %s" % (folder_path if not folder_path.is_empty() else "No folder selected")
	_recursive_checkbox.set_pressed_no_signal(_recursive_scan)
	_scrub_checkbox.set_pressed_no_signal(_scrub_identifying_info)
	_select_theme_option(_wrapped_theme_id)
	_select_gradient_option(_gradient_preset_id)
	_apply_share_profile_controls()
	_status_label.text = _scan_status_text()
	_update_summary_status()
	_rebuild_stats()
	_rebuild_questions()
	_rebuild_respondent_color_rows()
	_apply_active_tab()
	set_busy(false)

func _select_theme_option(theme_id: String) -> void:
	_wrapped_theme_id = theme_id if theme_id == SURVEY_ANSWER_REVIEW.WRAP_THEME_DARK else SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT
	if _theme_option == null:
		return
	for index in range(_theme_option.item_count):
		if str(_theme_option.get_item_metadata(index)) == _wrapped_theme_id:
			_theme_option.select(index)
			return
	_theme_option.select(0)

func _select_gradient_option(preset_id: String) -> void:
	_gradient_preset_id = preset_id.strip_edges().to_lower()
	if _gradient_option == null:
		return
	for index in range(_gradient_option.item_count):
		if str(_gradient_option.get_item_metadata(index)) == _gradient_preset_id:
			_gradient_option.select(index)
			return
	_gradient_option.select(0)
	_gradient_preset_id = str(_gradient_option.get_item_metadata(0))

func _update_summary_status() -> void:
	if _summary_status_label == null or _summary_hint_label == null:
		return
	var accepted := int(_scan_report.get("accepted_count", 0))
	var aggregate: Dictionary = _scan_report.get("aggregate", {}) as Dictionary
	if accepted <= 0 or aggregate.is_empty():
		_summary_status_label.text = "No compatible answers are ready for wrapped export."
		_summary_hint_label.text = "Scan a folder with matching answer JSON files to enable the summary render."
		return
	var page_estimate := 0
	if _survey != null:
		var pages_data := SURVEY_ANSWER_REVIEW.build_wrapped_pages_data(
			_survey,
			aggregate,
			current_scrub_identifying_info(),
			current_share_profile(),
			current_wrapped_theme_id(),
			current_wrap_options()
		)
		page_estimate = (pages_data.get("pages", []) as Array).size()
	_summary_status_label.text = "%d compatible answer file(s) ready." % accepted
	_summary_hint_label.text = "Wrapped summary will save %d phone-sized PNG page(s)." % page_estimate

func _apply_share_profile_controls() -> void:
	_updating_profile_controls = true
	var normalized := SURVEY_SHARE_PROFILE_STORE.normalize_profile(_share_profile)
	_share_profile = normalized
	if _show_profile_checkbox != null:
		_show_profile_checkbox.set_pressed_no_signal(bool(normalized.get("show_on_wrap", false)))
	if _profile_name_field != null:
		_profile_name_field.text = str(normalized.get("profile_name", SURVEY_SHARE_PROFILE_STORE.DEFAULT_PROFILE_NAME))
	_rebuild_profile_field_rows(normalized.get("fields", []) as Array)
	_updating_profile_controls = false

func _rebuild_profile_field_rows(fields: Array) -> void:
	if _profile_fields_list == null:
		return
	_clear_container(_profile_fields_list)
	_profile_field_rows.clear()
	for field_value in fields:
		if field_value is Dictionary:
			_add_profile_field_row(field_value as Dictionary)
	if _profile_field_rows.is_empty():
		_add_profile_field_row()

func _rebuild_respondent_color_rows() -> void:
	if _respondent_colors_list == null:
		return
	_updating_color_controls = true
	_clear_container(_respondent_colors_list)
	_respondent_color_rows.clear()
	var aggregate: Dictionary = _scan_report.get("aggregate", {}) as Dictionary
	var respondents: Array = aggregate.get("respondents", [])
	if respondents.is_empty():
		var empty := Label.new()
		empty.text = "Scan compatible answers to edit respondent colors."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_caption(empty, SurveyStyle.TEXT_MUTED)
		_respondent_colors_list.add_child(empty)
		_updating_color_controls = false
		return
	for index in range(respondents.size()):
		if respondents[index] is Dictionary:
			_add_respondent_color_row(respondents[index] as Dictionary, index)
	_updating_color_controls = false
	_style_respondent_color_rows()

func _add_respondent_color_row(respondent: Dictionary, index: int) -> void:
	var respondent_id := str(respondent.get("respondent_id", "")).strip_edges()
	if respondent_id.is_empty():
		return
	var default_color := str(respondent.get("default_color", "3b82f6")).strip_edges()
	var selected_color := str(_respondent_color_overrides.get(respondent_id, default_color)).strip_edges()
	var row := HBoxContainer.new()
	row.name = "RespondentColorRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "#%d  %s" % [int(respondent.get("respondent_number", index + 1)), str(respondent.get("display_label", "User %d" % (index + 1)))]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.name = "RespondentColorPicker"
	picker.custom_minimum_size = Vector2(52, 38)
	picker.color = Color(selected_color)
	picker.color_changed.connect(func(color: Color) -> void:
		_on_respondent_color_changed(respondent_id, default_color, color)
	)
	row.add_child(picker)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(func() -> void:
		_respondent_color_overrides.erase(respondent_id)
		_emit_settings_changed()
		_rebuild_respondent_color_rows()
		_update_summary_status()
	)
	row.add_child(reset_button)
	_respondent_colors_list.add_child(row)
	_respondent_color_rows.append({
		"container": row,
		"label": label,
		"picker": picker,
		"reset_button": reset_button
	})

func _on_respondent_color_changed(respondent_id: String, default_color: String, color: Color) -> void:
	if _updating_color_controls:
		return
	var selected := color.to_html(false)
	if selected == default_color.strip_edges().trim_prefix("#").to_lower():
		_respondent_color_overrides.erase(respondent_id)
	else:
		_respondent_color_overrides[respondent_id] = selected
	_emit_settings_changed()
	_update_summary_status()

func _scan_status_text() -> String:
	if _scan_report.is_empty():
		return "Choose a folder, then scan for answer JSON files."
	var rejected_count := (_scan_report.get("rejected_files", []) as Array).size()
	var warning_count := (_scan_report.get("warnings", []) as Array).size()
	var parts: Array[String] = [
		"%d compatible file(s), %d rejected file(s)." % [int(_scan_report.get("accepted_count", 0)), rejected_count]
	]
	if warning_count > 0:
		parts.append("%d warning(s)." % warning_count)
	return " ".join(parts)

func _rebuild_stats() -> void:
	_clear_container(_stats_grid)
	var aggregate: Dictionary = _scan_report.get("aggregate", {}) as Dictionary
	_stats_grid.add_child(_stat_tile("Compatible files", str(int(_scan_report.get("accepted_count", 0)))))
	_stats_grid.add_child(_stat_tile("Rejected files", str((_scan_report.get("rejected_files", []) as Array).size())))
	_stats_grid.add_child(_stat_tile("Responses tallied", str(int(aggregate.get("answered_response_total", 0)))))

func _rebuild_questions() -> void:
	_clear_container(_questions_list)
	var aggregate: Dictionary = _scan_report.get("aggregate", {}) as Dictionary
	if aggregate.is_empty() or int(aggregate.get("respondent_count", 0)) <= 0:
		var empty_label := Label.new()
		empty_label.text = "No compatible answer files have been scanned yet."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_body(empty_label)
		_questions_list.add_child(empty_label)
		return
	for section_value in aggregate.get("sections", []) as Array:
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value as Dictionary
		var section_label := Label.new()
		section_label.text = "Section %d  %s" % [int(section.get("section_number", 0)), str(section.get("title", "Section"))]
		SurveyStyle.style_heading(section_label, 18)
		_questions_list.add_child(section_label)
		for question_value in section.get("questions", []) as Array:
			if question_value is Dictionary:
				_questions_list.add_child(_question_card(question_value as Dictionary))

func _question_card(question_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_color := SurveyStyle.question_type_color(StringName(str(question_data.get("question_type", ""))))
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, type_color.darkened(0.18), 16, 1)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "Q%s  %s" % [str(question_data.get("display_number", "")), str(question_data.get("prompt", "Question"))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_body(title, SurveyStyle.TEXT_PRIMARY)
	stack.add_child(title)
	var meta := Label.new()
	meta.text = "%s | %d answer(s) | %s%% response rate" % [
		str(question_data.get("type_label", "Question")),
		int(question_data.get("answer_count", 0)),
		str(question_data.get("response_rate_percent", 0.0))
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(meta, type_color.lightened(0.1))
	stack.add_child(meta)
	for line in _detail_lines(question_data):
		var detail := Label.new()
		detail.text = line
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SurveyStyle.style_caption(detail, SurveyStyle.SOFT_WHITE)
		stack.add_child(detail)
	return panel

func _detail_lines(question_data: Dictionary) -> Array[String]:
	if _scrub_identifying_info and bool(question_data.get("asks_identifying_info", false)):
		return ["Identifying-marked answers are hidden by the current scrub setting."]
	var lines: Array[String] = []
	var question_type := StringName(str(question_data.get("question_type", "")))
	match question_type:
		SurveyQuestion.TYPE_SHORT_TEXT, SurveyQuestion.TYPE_LONG_TEXT, SurveyQuestion.TYPE_EMAIL, SurveyQuestion.TYPE_DATE:
			var samples: Array = question_data.get("text_answers", [])
			if samples.is_empty():
				return [str(question_data.get("summary_text", "No text answers."))]
			for sample_value in samples:
				if sample_value is Dictionary:
					lines.append(str((sample_value as Dictionary).get("text", "")).strip_edges())
				if lines.size() >= 12:
					break
			if samples.size() > lines.size():
				lines.append("+%d more text answer(s)" % (samples.size() - lines.size()))
		SurveyQuestion.TYPE_NUMBER, SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS:
			var stats: Dictionary = question_data.get("numeric_stats", {})
			if stats.is_empty():
				return [str(question_data.get("summary_text", "No numeric answers."))]
			lines.append("Average %s; min %s; max %s." % [str(stats.get("average", "")), str(stats.get("min", "")), str(stats.get("max", ""))])
			lines.append(_format_counts(question_data.get("option_counts", {}) as Dictionary))
		SurveyQuestion.TYPE_MATRIX:
			for row_value in question_data.get("matrix_rows", []) as Array:
				if row_value is Dictionary:
					var row: Dictionary = row_value as Dictionary
					lines.append("%s: %s" % [str(row.get("row", "")), _format_counts(row.get("option_counts", {}) as Dictionary)])
		SurveyQuestion.TYPE_RANKED_CHOICE:
			for option_value in question_data.get("ranked_options", []) as Array:
				if option_value is Dictionary:
					lines.append("%s average rank %s" % [str((option_value as Dictionary).get("option", "")), str((option_value as Dictionary).get("average_rank", ""))])
		_:
			lines.append(_format_counts(question_data.get("option_counts", {}) as Dictionary))
	return lines if not lines.is_empty() else [str(question_data.get("summary_text", "No answers yet."))]

func _format_counts(counts: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	for key in counts.keys():
		entries.append({"label": str(key), "count": int(counts.get(key, 0))})
	entries.sort_custom(Callable(self, "_sort_count_entries"))
	var parts: Array[String] = []
	for entry in entries:
		if int(entry.get("count", 0)) <= 0:
			continue
		parts.append("%s: %d" % [str(entry.get("label", "")), int(entry.get("count", 0))])
	return " | ".join(parts) if not parts.is_empty() else "No tallies yet."

func _sort_count_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_count := int(left.get("count", 0))
	var right_count := int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("label", "")) < str(right.get("label", ""))

func _stat_tile(label_text: String, value_text: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(tile, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 14, 1)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	tile.add_child(stack)
	var label := Label.new()
	label.text = label_text
	SurveyStyle.style_caption(label, SurveyStyle.SOFT_WHITE)
	stack.add_child(label)
	var value := Label.new()
	value.text = value_text
	SurveyStyle.style_heading(value, 22)
	stack.add_child(value)
	return tile

func _on_option_toggled(_enabled: bool) -> void:
	_recursive_scan = current_recursive_scan()
	_scrub_identifying_info = current_scrub_identifying_info()
	_emit_settings_changed()
	_rebuild_questions()
	_update_summary_status()

func _on_theme_selected(_index: int) -> void:
	_wrapped_theme_id = current_wrapped_theme_id()
	_emit_settings_changed()
	_update_summary_status()

func _on_gradient_selected(_index: int) -> void:
	_gradient_preset_id = current_gradient_preset_id()
	_emit_settings_changed()
	_update_summary_status()

func _emit_settings_changed() -> void:
	settings_changed.emit(
		current_recursive_scan(),
		current_scrub_identifying_info(),
		current_wrapped_theme_id(),
		current_gradient_preset_id(),
		current_respondent_color_overrides(),
		current_text_summary_mode()
	)

func _on_share_profile_show_toggled(enabled: bool) -> void:
	if _updating_profile_controls:
		return
	_share_profile["show_on_wrap"] = enabled
	_save_share_profile_from_controls()

func _on_share_profile_text_changed(_text: String) -> void:
	if _updating_profile_controls:
		return
	_save_share_profile_from_controls()

func _save_share_profile_from_controls() -> void:
	if _profile_name_field != null:
		_share_profile["profile_name"] = _profile_name_field.text
	var fields: Array[Dictionary] = []
	for row_value in _profile_field_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value as Dictionary
		var label_field: LineEdit = row.get("label_field", null) as LineEdit
		var value_field: LineEdit = row.get("value_field", null) as LineEdit
		if label_field == null or value_field == null:
			continue
		fields.append({
			"label": label_field.text,
			"value": value_field.text
		})
	_share_profile["fields"] = fields
	if _show_profile_checkbox != null:
		_share_profile["show_on_wrap"] = _show_profile_checkbox.button_pressed
	_share_profile = SURVEY_SHARE_PROFILE_STORE.normalize_profile(_share_profile, true)
	SURVEY_SHARE_PROFILE_STORE.save_profile(_share_profile)

func _on_add_profile_field_pressed() -> void:
	if _updating_profile_controls:
		return
	_add_profile_field_row()
	_save_share_profile_from_controls()

func _on_purge_profile_pressed() -> void:
	SURVEY_SHARE_PROFILE_STORE.purge_profile()
	_share_profile = SURVEY_SHARE_PROFILE_STORE.default_profile()
	_apply_share_profile_controls()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_requested.emit()

func _reset_scroll_position() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0
		_scroll.scroll_horizontal = 0

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
