class_name SurveyThemeDrawer
extends Control

signal theme_selected(theme_id: String)
signal theme_mode_requested(use_dark_mode: bool)

const DRAWER_MAX_WIDTH := 920.0
const DRAWER_OPEN_HEIGHT_PHONE := 164.0
const DRAWER_OPEN_HEIGHT_DESKTOP := 192.0
const DRAWER_TOP_CLEARANCE_PHONE := 76.0
const DRAWER_TOP_CLEARANCE_DESKTOP := 96.0
const DRAWER_CONTENT_BUFFER_PHONE := 8.0
const DRAWER_CONTENT_BUFFER_DESKTOP := 10.0

var _themes: Array = []
var _selected_theme_id := ""
var _use_dark_mode := true
var _expanded := true
var _last_layout_viewport_size := Vector2.ZERO
var _body_feedback_text := ""
var _body_feedback_is_error := false
var _body_feedback_token := 0

var _bounds: Control
var _center: Control
var _panel: Panel
var _stack: VBoxContainer
var _header_row: HBoxContainer
var _toggle_button: Button
var _mode_button: Button
var _content_stack: VBoxContainer
var _body_label: Label
var _scroll: ScrollContainer
var _card_row: HBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_rebuild_cards()
	_refresh_labels()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func configure(themes: Array, selected_theme_id: String, use_dark_mode: bool) -> void:
	_themes = themes.duplicate()
	_selected_theme_id = selected_theme_id.strip_edges().to_lower()
	_use_dark_mode = use_dark_mode
	_rebuild_cards()
	_refresh_labels()

func set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	_refresh_visibility_state()
	refresh_layout(get_viewport().get_visible_rect().size)
	_refresh_labels()

func show_feedback(message: String, is_error: bool = false, duration_seconds: float = 2.8) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		_clear_feedback()
		return
	_body_feedback_text = trimmed
	_body_feedback_is_error = is_error
	_body_feedback_token += 1
	var feedback_token := _body_feedback_token
	_apply_body_label_state()
	if duration_seconds <= 0.0:
		return
	await get_tree().create_timer(maxf(duration_seconds, 0.1)).timeout
	if feedback_token != _body_feedback_token:
		return
	_clear_feedback()

func refresh_theme() -> void:
	if _panel == null:
		return
	var fill := SurveyStyle.SURFACE
	fill.a = 0.96
	var compact_layout := _uses_compact_layout(_current_layout_viewport_size())
	var panel_style := SurveyStyle.panel(fill, SurveyStyle.BORDER, 24, 1)
	var panel_padding := int(_panel_padding(compact_layout))
	panel_style.content_margin_left = panel_padding
	panel_style.content_margin_right = panel_padding
	panel_style.content_margin_top = panel_padding
	panel_style.content_margin_bottom = panel_padding
	_panel.add_theme_stylebox_override("panel", panel_style)
	_stack.offset_left = panel_padding
	_stack.offset_top = panel_padding
	_stack.offset_right = -panel_padding
	_stack.offset_bottom = -panel_padding
	SurveyStyle.apply_secondary_button(_toggle_button)
	SurveyStyle.apply_primary_button(_mode_button)
	_toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle_button.add_theme_font_size_override("font_size", 13 if compact_layout else 15)
	_toggle_button.add_theme_constant_override("outline_size", 1 if compact_layout else 2)
	_mode_button.text = "Dark" if _use_dark_mode else "Light"
	_mode_button.tooltip_text = "Switch between the dark and light palette for the current theme."
	_mode_button.add_theme_font_size_override("font_size", 13 if compact_layout else 15)
	_mode_button.add_theme_constant_override("outline_size", 1 if compact_layout else 2)
	_tune_drawer_button_padding(_toggle_button, compact_layout)
	_tune_drawer_button_padding(_mode_button, compact_layout)
	_apply_body_label_state()
	_scroll.add_theme_stylebox_override("panel", SurveyStyle.panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	_hide_horizontal_scrollbar_chrome()
	_restyle_cards()
	_refresh_labels()

func refresh_layout(viewport_size: Vector2) -> void:
	_last_layout_viewport_size = viewport_size
	var phone_layout := viewport_size.x <= 480.0
	var compact_layout := _uses_compact_layout(viewport_size)
	var bottom_inset := 16.0 if compact_layout else 20.0
	var horizontal_inset := 8.0 if phone_layout else 18.0
	var header_height := _header_button_height(compact_layout)
	var collapsed_height := _collapsed_height(compact_layout)
	var stack_separation := _stack_separation(compact_layout)
	var content_separation := _content_separation(compact_layout)
	var target_scroll_height := _target_scroll_height(viewport_size, compact_layout)
	var open_height := _open_drawer_height(viewport_size, compact_layout)
	var top_clearance := DRAWER_TOP_CLEARANCE_PHONE if compact_layout else DRAWER_TOP_CLEARANCE_DESKTOP
	var max_drawer_height := maxf(viewport_size.y - bottom_inset - top_clearance, collapsed_height)
	if _bounds == null or _panel == null:
		return
	var panel_width := maxf(minf(viewport_size.x - (horizontal_inset * 2.0), DRAWER_MAX_WIDTH), 280.0)
	var drawer_height := minf(open_height if _expanded else collapsed_height, max_drawer_height)
	var panel_height := maxf(drawer_height - (_content_buffer(compact_layout) if _expanded else 0.0), collapsed_height)
	_center.offset_left = horizontal_inset
	_center.offset_top = 0.0
	_center.offset_right = -horizontal_inset
	_center.offset_bottom = 0.0
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = -drawer_height - bottom_inset
	offset_right = 0.0
	offset_bottom = -bottom_inset
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = Vector2(floor((maxf(viewport_size.x - (horizontal_inset * 2.0), panel_width) - panel_width) * 0.5), 0.0)
	_stack.add_theme_constant_override("separation", int(stack_separation))
	_header_row.add_theme_constant_override("separation", 6 if compact_layout else 10)
	_content_stack.add_theme_constant_override("separation", int(content_separation))
	var available_scroll_height := maxf(
		panel_height - collapsed_height - stack_separation - _estimated_body_height(compact_layout) - content_separation,
		64.0 if compact_layout else 88.0
	)
	_scroll.custom_minimum_size = Vector2(0.0, minf(target_scroll_height, available_scroll_height))
	_toggle_button.custom_minimum_size = Vector2(0.0, header_height)
	_mode_button.custom_minimum_size = Vector2(_mode_button_width(compact_layout), header_height)
	_body_label.add_theme_font_size_override("font_size", 10 if compact_layout else 13)
	_refresh_card_layout(compact_layout)

func has_themes() -> bool:
	return not _themes.is_empty()

func _build_ui() -> void:
	if _bounds != null:
		return
	_bounds = Control.new()
	_bounds.name = "Bounds"
	_bounds.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bounds.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bounds)

	_center = Control.new()
	_center.name = "Center"
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.clip_contents = true
	_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_bounds.add_child(_center)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = Vector2.ZERO
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_center.add_child(_panel)

	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_stack)

	_header_row = HBoxContainer.new()
	_header_row.name = "HeaderRow"
	_stack.add_child(_header_row)

	_toggle_button = Button.new()
	_toggle_button.name = "ToggleButton"
	_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle_button.text = "Themes"
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_header_row.add_child(_toggle_button)

	_mode_button = Button.new()
	_mode_button.name = "ModeButton"
	_mode_button.pressed.connect(_on_mode_button_pressed)
	_header_row.add_child(_mode_button)

	_content_stack = VBoxContainer.new()
	_content_stack.name = "ContentStack"
	_stack.add_child(_content_stack)

	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.text = "Tap a swatch to shift the whole survey mood."
	_content_stack.add_child(_body_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "ThemeScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.clip_contents = true
	_content_stack.add_child(_scroll)

	_card_row = HBoxContainer.new()
	_card_row.name = "ThemeCardRow"
	_card_row.add_theme_constant_override("separation", 10)
	_scroll.add_child(_card_row)

	_refresh_visibility_state()

func _refresh_visibility_state() -> void:
	if _content_stack != null:
		_content_stack.visible = _expanded

func _refresh_labels() -> void:
	if _toggle_button == null:
		return
	var card_count := _themes.size()
	var chevron := "v" if _expanded else ">"
	var mode_name := "Dark" if _use_dark_mode else "Light"
	_toggle_button.text = "%s Themes (%d) - %s" % [chevron, card_count, mode_name]
	_toggle_button.tooltip_text = "Show or hide the theme palette drawer."
	_apply_body_label_state()

func _rebuild_cards() -> void:
	if _card_row == null:
		return
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()
	for theme in _themes:
		if theme == null:
			continue
		_card_row.add_child(_build_theme_card(theme))
	_restyle_cards()

func _refresh_card_layout(compact_layout: bool) -> void:
	if _card_row == null:
		return
	_card_row.add_theme_constant_override("separation", 6 if compact_layout else 10)
	var viewport_size := _current_layout_viewport_size()
	var card_size := _card_minimum_size(viewport_size)
	for child in _card_row.get_children():
		var button := child as Button
		if button == null:
			continue
		button.custom_minimum_size = card_size

func _restyle_cards() -> void:
	if _card_row == null:
		return
	var viewport_size := _current_layout_viewport_size()
	var compact_layout := _uses_compact_layout(viewport_size)
	var preview_size := _preview_minimum_size(viewport_size)
	for child in _card_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var theme_id := str(button.get_meta("theme_id", "")).strip_edges().to_lower()
		var preview := button.get_node_or_null("Content/Preview") as TextureRect
		if preview != null:
			preview.texture = _preview_texture_for_theme(_theme_for_id(theme_id))
			preview.custom_minimum_size = preview_size
		var is_selected := theme_id == _selected_theme_id
		var fill := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE_ALT
		var border := SurveyStyle.ACCENT if is_selected else SurveyStyle.BORDER
		button.add_theme_stylebox_override("normal", SurveyStyle.panel(fill, border, 18, 2 if is_selected else 1))
		button.add_theme_stylebox_override("hover", SurveyStyle.panel(fill.lightened(0.03), SurveyStyle.ACCENT_ALT if is_selected else SurveyStyle.BORDER.lightened(0.08), 18, 2 if is_selected else 1))
		button.add_theme_stylebox_override("focus", SurveyStyle.panel(fill.lightened(0.03), SurveyStyle.ACCENT_ALT, 18, 2))
		button.add_theme_stylebox_override("pressed", SurveyStyle.panel(fill.darkened(0.03), SurveyStyle.ACCENT, 18, 2))
		button.add_theme_color_override("font_color", SurveyStyle.TEXT_PRIMARY)
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		button.add_theme_constant_override("outline_size", 0)
		var title_label := button.get_node_or_null("Content/Label") as Label
		if title_label != null:
			SurveyStyle.style_body(title_label, SurveyStyle.TEXT_PRIMARY)
			title_label.add_theme_constant_override("outline_size", 0)
			title_label.add_theme_font_size_override("font_size", 11 if compact_layout else 14)

func _build_theme_card(theme) -> Button:
	var viewport_size := _current_layout_viewport_size()
	var compact_layout := _uses_compact_layout(viewport_size)
	var button := Button.new()
	button.name = theme.normalized_theme_id()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = _card_minimum_size(viewport_size)
	button.set_meta("theme_id", theme.normalized_theme_id())
	button.pressed.connect(_on_theme_card_pressed.bind(theme.normalized_theme_id()))

	var content := MarginContainer.new()
	content.name = "Content"
	content.anchors_preset = PRESET_FULL_RECT
	var content_inset := 8.0 if compact_layout else 12.0
	content.offset_left = content_inset
	content.offset_top = content_inset
	content.offset_right = -content_inset
	content.offset_bottom = -content_inset
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4 if compact_layout else 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stack)

	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = _preview_minimum_size(viewport_size)
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture = _preview_texture_for_theme(theme)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(preview)

	var label := Label.new()
	label.name = "Label"
	label.text = theme.display_title()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)

	return button

func _uses_compact_layout(viewport_size: Vector2) -> bool:
	return viewport_size.x <= 480.0 or viewport_size.y <= 720.0

func _card_minimum_size(viewport_size: Vector2) -> Vector2:
	return Vector2(102.0, 78.0) if _uses_compact_layout(viewport_size) else Vector2(148.0, 122.0)

func _preview_minimum_size(viewport_size: Vector2) -> Vector2:
	return Vector2(34.0, 34.0) if _uses_compact_layout(viewport_size) else Vector2(62.0, 62.0)

func _panel_padding(compact_layout: bool) -> float:
	return 10.0 if compact_layout else 14.0

func _header_button_height(compact_layout: bool) -> float:
	return 32.0 if compact_layout else 42.0

func _mode_button_width(compact_layout: bool) -> float:
	return 68.0 if compact_layout else 92.0

func _stack_separation(compact_layout: bool) -> float:
	return 8.0 if compact_layout else 12.0

func _content_separation(compact_layout: bool) -> float:
	return 6.0 if compact_layout else 10.0

func _estimated_body_height(compact_layout: bool) -> float:
	return 24.0 if compact_layout else 34.0

func _collapsed_height(compact_layout: bool) -> float:
	return (_panel_padding(compact_layout) * 2.0) + _header_button_height(compact_layout)

func _content_buffer(compact_layout: bool) -> float:
	return DRAWER_CONTENT_BUFFER_PHONE if compact_layout else DRAWER_CONTENT_BUFFER_DESKTOP

func _target_scroll_height(viewport_size: Vector2, compact_layout: bool) -> float:
	return _card_minimum_size(viewport_size).y + (4.0 if compact_layout else 6.0)

func _open_drawer_height(viewport_size: Vector2, compact_layout: bool) -> float:
	var default_open_height := DRAWER_OPEN_HEIGHT_PHONE if compact_layout else DRAWER_OPEN_HEIGHT_DESKTOP
	var required_height := _collapsed_height(compact_layout) + _stack_separation(compact_layout) + _estimated_body_height(compact_layout) + _content_separation(compact_layout) + _target_scroll_height(viewport_size, compact_layout)
	return maxf(default_open_height, required_height + _content_buffer(compact_layout))

func _current_layout_viewport_size() -> Vector2:
	if _last_layout_viewport_size.x > 0.0 and _last_layout_viewport_size.y > 0.0:
		return _last_layout_viewport_size
	var viewport := get_viewport()
	return viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)

func _tune_drawer_button_padding(button: Button, compact_layout: bool) -> void:
	if button == null:
		return
	var horizontal_padding := 10.0 if compact_layout else 14.0
	var vertical_padding := 6.0 if compact_layout else 8.0
	for state_name in ["normal", "hover", "focus", "pressed"]:
		var style := button.get_theme_stylebox(state_name)
		if style is not StyleBoxFlat:
			continue
		var tuned_style := (style as StyleBoxFlat).duplicate()
		tuned_style.content_margin_left = horizontal_padding
		tuned_style.content_margin_right = horizontal_padding
		tuned_style.content_margin_top = vertical_padding
		tuned_style.content_margin_bottom = vertical_padding
		button.add_theme_stylebox_override(state_name, tuned_style)

func _hide_horizontal_scrollbar_chrome() -> void:
	if _scroll == null:
		return
	var horizontal_bar := _scroll.get_h_scroll_bar()
	if horizontal_bar == null:
		return
	horizontal_bar.visible = false
	horizontal_bar.custom_minimum_size.y = 0.0
	horizontal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _preview_texture_for_theme(theme) -> Texture2D:
	var colors: PackedColorArray = theme.preview_gradient_colors(_use_dark_mode) if theme != null else PackedColorArray([
		Color("9ca3af"),
		Color("6b7280"),
		Color("111827")
	])
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var texture := GradientTexture2D.new()
	texture.width = 96
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.gradient = gradient
	return texture

func _theme_for_id(theme_id: String):
	var normalized_id := theme_id.strip_edges().to_lower()
	for theme in _themes:
		if theme != null and theme.normalized_theme_id() == normalized_id:
			return theme
	return null

func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)

func _on_mode_button_pressed() -> void:
	theme_mode_requested.emit(not _use_dark_mode)

func _on_theme_card_pressed(theme_id: String) -> void:
	theme_selected.emit(theme_id)

func _apply_body_label_state() -> void:
	if _body_label == null:
		return
	_body_label.text = _body_feedback_text if not _body_feedback_text.is_empty() else _default_body_text()
	SurveyStyle.style_caption(_body_label, SurveyStyle.DANGER if _body_feedback_is_error else (SurveyStyle.ACCENT_ALT if not _body_feedback_text.is_empty() else SurveyStyle.TEXT_MUTED))

func _default_body_text() -> String:
	var mode_name := "Dark" if _use_dark_mode else "Light"
	var compact_layout := _uses_compact_layout(_current_layout_viewport_size())
	if _themes.is_empty():
		return "No theme resources are available for this build yet."
	if compact_layout:
		return "Pick a palette, then switch %s for the brighter or dimmer look." % mode_name
	return "Pick a palette family, then use %s mode if you want the brighter or dimmer variant." % mode_name

func _clear_feedback() -> void:
	_body_feedback_text = ""
	_body_feedback_is_error = false
	_apply_body_label_state()
