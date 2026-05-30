class_name SurveyUiFlowCanvas
extends Control

var _graph: Dictionary = {}
var _node_cards: Dictionary = {}
var _edges: Array[Dictionary] = []

func set_graph(graph: Dictionary, textures_by_id: Dictionary, export_paths_by_id: Dictionary) -> void:
	_graph = graph.duplicate(true)
	_edges.clear()
	_node_cards.clear()
	_clear_children()
	custom_minimum_size = Vector2(_graph.get("canvas_size", Vector2i(2400, 1800)))
	size = custom_minimum_size

	var edge_values: Variant = _graph.get("edges", [])
	if edge_values is Array:
		for edge_value in edge_values:
			if edge_value is Dictionary:
				_edges.append((edge_value as Dictionary).duplicate(true))

	var node_values: Variant = _graph.get("nodes", [])
	if node_values is Array:
		for node_value in node_values:
			if not (node_value is Dictionary):
				continue
			var node_spec: Dictionary = (node_value as Dictionary).duplicate(true)
			var node_id := str(node_spec.get("id", "")).strip_edges()
			if node_id.is_empty():
				continue
			var texture := textures_by_id.get(node_id) as Texture2D
			var export_path := str(export_paths_by_id.get(node_id, "")).strip_edges()
			var card := _build_node_card(node_spec, texture, export_path)
			add_child(card)
			card.position = node_spec.get("position", Vector2.ZERO) as Vector2
			card.resized.connect(queue_redraw)
			_node_cards[node_id] = card
	queue_redraw()

func _draw() -> void:
	if _edges.is_empty():
		return
	var label_font: Font = ThemeDB.fallback_font
	var label_font_size: int = ThemeDB.fallback_font_size
	for edge in _edges:
		var from_id := str(edge.get("from", "")).strip_edges()
		var to_id := str(edge.get("to", "")).strip_edges()
		var from_card := _node_cards.get(from_id) as Control
		var to_card := _node_cards.get(to_id) as Control
		if from_card == null or to_card == null:
			continue
		var from_rect := Rect2(from_card.position, from_card.size)
		var to_rect := Rect2(to_card.position, to_card.size)
		var start := _connection_anchor(from_rect, to_rect)
		var end := _connection_anchor(to_rect, from_rect)
		var points := _orthogonal_points(start, end)
		var edge_color := SurveyStyle.ACCENT_ALT.lightened(0.08)
		for index in range(points.size() - 1):
			draw_line(points[index], points[index + 1], edge_color, 4.0, true)
		_draw_arrow(points[points.size() - 2], points[points.size() - 1], edge_color)
		var label := str(edge.get("label", "")).strip_edges()
		if label_font != null and not label.is_empty():
			var midpoint := _polyline_midpoint(points)
			draw_string(label_font, midpoint + Vector2(10.0, -6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size, SurveyStyle.TEXT_MUTED)

func _build_node_card(node_spec: Dictionary, texture: Texture2D, export_path: String) -> PanelContainer:
	var preview_size := node_spec.get("preview_size", Vector2(280.0, 608.0)) as Vector2
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(preview_size.x + 28.0, preview_size.y + 146.0)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.apply_panel(card, _group_fill_color(str(node_spec.get("group", ""))), _group_border_color(str(node_spec.get("group", ""))), 20, 1)

	var stack := VBoxContainer.new()
	stack.layout_mode = 2
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)

	var badge := Label.new()
	badge.text = _group_title(str(node_spec.get("group", "")))
	badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_caption(badge, _group_border_color(str(node_spec.get("group", ""))).lightened(0.1))
	stack.add_child(badge)

	var title_label := Label.new()
	title_label.text = str(node_spec.get("title", "UI State"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SurveyStyle.style_heading(title_label, 18)
	stack.add_child(title_label)

	var description_label := Label.new()
	description_label.text = str(node_spec.get("description", "")).strip_edges()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.visible = not description_label.text.is_empty()
	SurveyStyle.style_body(description_label)
	description_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(description_label)

	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = preview_size
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.apply_panel(preview_frame, SurveyStyle.SURFACE_MUTED, SurveyStyle.BORDER, 14, 1)
	stack.add_child(preview_frame)

	var texture_rect := TextureRect.new()
	texture_rect.layout_mode = 1
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = texture
	preview_frame.add_child(texture_rect)

	var path_label := Label.new()
	path_label.text = _display_export_path(export_path)
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.visible = not path_label.text.is_empty()
	SurveyStyle.style_caption(path_label, SurveyStyle.TEXT_MUTED)
	path_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(path_label)

	return card

func _connection_anchor(source_rect: Rect2, target_rect: Rect2) -> Vector2:
	var delta := target_rect.get_center() - source_rect.get_center()
	if absf(delta.x) >= absf(delta.y):
		return Vector2(source_rect.end.x, source_rect.position.y + source_rect.size.y * 0.5) if delta.x >= 0.0 else Vector2(source_rect.position.x, source_rect.position.y + source_rect.size.y * 0.5)
	return Vector2(source_rect.position.x + source_rect.size.x * 0.5, source_rect.end.y) if delta.y >= 0.0 else Vector2(source_rect.position.x + source_rect.size.x * 0.5, source_rect.position.y)

func _orthogonal_points(start: Vector2, end: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = [start]
	if absf(end.x - start.x) >= absf(end.y - start.y):
		var mid_x := lerpf(start.x, end.x, 0.5)
		points.append(Vector2(mid_x, start.y))
		points.append(Vector2(mid_x, end.y))
	else:
		var mid_y := lerpf(start.y, end.y, 0.5)
		points.append(Vector2(start.x, mid_y))
		points.append(Vector2(end.x, mid_y))
	points.append(end)
	return points

func _draw_arrow(previous_point: Vector2, end_point: Vector2, color: Color) -> void:
	var direction := (end_point - previous_point).normalized()
	if direction == Vector2.ZERO:
		return
	var normal := Vector2(-direction.y, direction.x)
	var arrow_length := 14.0
	var arrow_width := 7.0
	var tip := end_point
	var left := tip - direction * arrow_length + normal * arrow_width
	var right := tip - direction * arrow_length - normal * arrow_width
	draw_line(tip, left, color, 4.0, true)
	draw_line(tip, right, color, 4.0, true)

func _polyline_midpoint(points: Array[Vector2]) -> Vector2:
	if points.size() < 2:
		return points[0] if not points.is_empty() else Vector2.ZERO
	var longest_length := -1.0
	var midpoint := points[0]
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if segment_length > longest_length:
			longest_length = segment_length
			midpoint = points[index].lerp(points[index + 1], 0.5)
	return midpoint

func _display_export_path(export_path: String) -> String:
	if export_path.is_empty():
		return ""
	var absolute_user_path := ProjectSettings.globalize_path("user://")
	if export_path.begins_with(absolute_user_path):
		return export_path.replace(absolute_user_path, "user://")
	return export_path

func _group_title(group: String) -> String:
	match group:
		"survey_app":
			return "Main Scene"
		"survey_journey":
			return "Journey Scene"
		"shared_ui":
			return "Shared UI"
	return "UI"

func _group_fill_color(group: String) -> Color:
	match group:
		"survey_app":
			return SurveyStyle.SURFACE
		"survey_journey":
			return SurveyStyle.SURFACE_ALT
		"shared_ui":
			return SurveyStyle.SURFACE_MUTED
	return SurveyStyle.SURFACE

func _group_border_color(group: String) -> Color:
	match group:
		"survey_app":
			return SurveyStyle.ACCENT
		"survey_journey":
			return SurveyStyle.HIGHLIGHT_GOLD
		"shared_ui":
			return SurveyStyle.ACCENT_ALT
	return SurveyStyle.BORDER

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
