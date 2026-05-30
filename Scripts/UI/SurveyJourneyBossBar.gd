class_name SurveyJourneyBossBar
extends Control

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const EMPTY_LAYER_RATIO := 0.00001

var _stack: VBoxContainer
var _header_row: HBoxContainer
var _heading_label: Label
var _status_label: Label
var _subtitle_label: Label
var _detail_label: Label
var _bar_shell: PanelContainer
var _layer_stack: VBoxContainer
var _callout_label: Label
var _large_mode := false
var _layer_controls: Array[Control] = []
var _layer_fills: Array[ColorRect] = []
var _layer_flashes: Array[ColorRect] = []
var _layer_tweens: Array = []
var _section_max_healths: Array[float] = []
var _section_healths: Array[float] = []
var _callout_tween: Tween
var _bar_pulse_tween: Tween

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func set_large_mode(enabled: bool) -> void:
	if _large_mode == enabled:
		return
	_large_mode = enabled
	if is_node_ready():
		refresh_theme()
		refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if not is_node_ready():
		return
	SurveyStyle.style_heading(_heading_label, 18 if not _large_mode else 24)
	SurveyStyle.style_caption(_subtitle_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_caption(_status_label, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.style_caption(_detail_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.style_caption(_callout_label, SurveyStyle.HIGHLIGHT_GOLD)
	var shell_fill := SurveyStyle.SURFACE_ALT.lerp(SurveyStyle.SURFACE, 0.22)
	var shell_border := SurveyStyle.BORDER.lightened(0.08)
	_apply_shell_style(shell_fill, shell_border)
	_refresh_layer_styles()

func refresh_layout(viewport_size: Vector2) -> void:
	if not is_node_ready():
		return
	var compact: bool = viewport_size.x <= 640.0
	_stack.add_theme_constant_override("separation", 6 if compact and not _large_mode else (8 if compact else (10 if _large_mode else 8)))
	_header_row.add_theme_constant_override("separation", 8 if compact else 10)
	_layer_stack.add_theme_constant_override("separation", 1)
	var layer_count: int = max(_layer_controls.size(), 1)
	var layer_height := 9.0 if compact else 11.0
	if _large_mode:
		layer_height = 12.0 if compact else 14.0
	var minimum_shell := 34.0 if not _large_mode else 58.0
	var maximum_shell := 68.0 if not _large_mode else 112.0
	var shell_height := clampf((float(layer_count) * layer_height) + 8.0, minimum_shell, maximum_shell)
	_bar_shell.custom_minimum_size = Vector2(0.0, shell_height)
	custom_minimum_size = Vector2(0.0, shell_height + (62.0 if _large_mode else 48.0))
	_heading_label.add_theme_font_size_override("font_size", 22 if _large_mode and compact else (24 if _large_mode else (16 if compact else 18)))
	_status_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	_subtitle_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	_detail_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	_callout_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	for layer in _layer_controls:
		if layer == null:
			continue
		layer.custom_minimum_size = Vector2(0.0, layer_height)
	_refresh_fill_scales(false)

func set_header(title: String, subtitle: String = "", status_text: String = "", detail_text: String = "") -> void:
	if not is_node_ready():
		return
	_heading_label.text = title.strip_edges()
	_subtitle_label.text = subtitle.strip_edges()
	_subtitle_label.visible = not _subtitle_label.text.is_empty()
	_detail_label.text = detail_text.strip_edges()
	_detail_label.visible = not _detail_label.text.is_empty()
	set_status_text(status_text)

func set_status_text(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if not is_node_ready():
		return
	_status_label.text = text.strip_edges()
	_status_label.visible = not _status_label.text.is_empty()
	if color != Color(0, 0, 0, 0):
		SurveyStyle.style_caption(_status_label, color)
	else:
		SurveyStyle.style_caption(_status_label, SurveyStyle.HIGHLIGHT_GOLD)

func configure_from_state(state: Dictionary, animated: bool = false, duration: float = 0.18) -> void:
	if not is_node_ready():
		return
	var sections_value: Variant = state.get("sections", [])
	var sections: Array = sections_value as Array if sections_value is Array else []
	_ensure_layers(sections.size())
	_section_max_healths.clear()
	_section_healths.clear()
	for index in range(sections.size()):
		var section_value: Variant = sections[index]
		var section: Dictionary = section_value as Dictionary if section_value is Dictionary else {}
		_layer_controls[index].size_flags_stretch_ratio = 1.0
		_section_max_healths.append(maxf(float(section.get("max_health", 0.0)), 0.0))
		_section_healths.append(clampf(float(section.get("current_health", 0.0)), 0.0, _section_max_healths[index]))
	_layer_visibility(sections.size(), not animated)
	_refresh_layer_styles()
	_refresh_fill_scales(animated, duration)

func animate_section_change(section_index: int, amount: float, is_heal: bool = false, duration: float = 0.14, strong_hit: bool = false) -> void:
	if section_index < 0 or section_index >= _section_healths.size():
		return
	var resolved_amount := maxf(amount, 0.0)
	var max_health: float = _section_max_healths[section_index]
	if max_health <= 0.0 or resolved_amount <= 0.0:
		play_surface_hit(section_index, strong_hit, is_heal)
		return
	var delta := resolved_amount if is_heal else -resolved_amount
	_section_healths[section_index] = clampf(_section_healths[section_index] + delta, 0.0, max_health)
	if _section_ratio(section_index) > 0.0:
		_set_layer_visible(section_index, true)
	play_surface_hit(section_index, strong_hit, is_heal)
	_refresh_layer_styles()
	_refresh_fill_scale_for_index(section_index, true, duration)

func play_surface_hit(section_index: int, strong_hit: bool = false, is_heal: bool = false) -> void:
	if section_index < 0 or section_index >= _layer_controls.size():
		return
	var flash := _layer_flashes[section_index]
	if flash != null:
		flash.color = SurveyStyle.SUCCESS if is_heal else Color(1.0, 1.0, 1.0, 0.96)
		flash.modulate.a = 0.0
		var tween := create_tween()
		tween.parallel().tween_property(flash, "modulate:a", 0.9 if not is_heal else 0.72, 0.05)
		tween.tween_property(flash, "modulate:a", 0.0, 0.16 if not strong_hit else 0.22)
	if _bar_shell != null:
		_pulse_bar_shell(strong_hit, is_heal)

func show_callout(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if not is_node_ready():
		return
	var resolved_text := text.strip_edges()
	if resolved_text.is_empty():
		_callout_label.visible = false
		return
	_callout_label.text = resolved_text
	_callout_label.visible = true
	SurveyStyle.style_caption(_callout_label, color if color != Color(0, 0, 0, 0) else SurveyStyle.HIGHLIGHT_GOLD)
	_callout_label.modulate = Color(1, 1, 1, 0)
	if _callout_tween != null and _callout_tween.is_valid():
		_callout_tween.kill()
	_callout_tween = create_tween()
	_callout_tween.tween_property(_callout_label, "modulate:a", 1.0, 0.08)
	_callout_tween.tween_interval(0.44 if _large_mode else 0.28)
	_callout_tween.tween_property(_callout_label, "modulate:a", 0.0, 0.18)

func section_target_position(section_index: int) -> Vector2:
	if section_index < 0 or section_index >= _layer_controls.size():
		return bar_target_position()
	var layer := _layer_controls[section_index]
	if layer == null or not layer.visible:
		return bar_target_position()
	return layer.global_position + Vector2(layer.size.x * 0.5, layer.size.y * 0.5)

func bar_target_position() -> Vector2:
	return _bar_shell.global_position + (_bar_shell.size * 0.5)

func total_damage_ratio() -> float:
	var total_max := 0.0
	var total_current := 0.0
	for index in range(_section_max_healths.size()):
		total_max += _section_max_healths[index]
		total_current += _section_healths[index]
	if total_max <= 0.0:
		return 0.0
	return clampf((total_max - total_current) / total_max, 0.0, 1.0)

func visible_layer_count() -> int:
	var count := 0
	for index in range(_layer_controls.size()):
		var layer := _layer_controls[index]
		if layer != null and layer.visible:
			count += 1
	return count

func status_text() -> String:
	return _status_label.text if _status_label != null else ""

func detail_text() -> String:
	return _detail_label.text if _detail_label != null else ""

func layer_debug_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for index in range(_layer_controls.size()):
		var layer := _layer_controls[index]
		var fill := _layer_fills[index] if index < _layer_fills.size() else null
		snapshot.append({
			"index": index,
			"visible": layer != null and layer.visible,
			"fill_visible": fill != null and fill.visible,
			"layer_size": layer.size if layer != null else Vector2.ZERO,
			"fill_scale_x": fill.scale.x if fill != null else 0.0,
			"health_ratio": _section_ratio(index)
		})
	return snapshot

func shell_debug_position() -> Vector2:
	return _bar_shell.position if _bar_shell != null else Vector2.ZERO

func _build_ui() -> void:
	if _stack != null:
		return
	_stack = VBoxContainer.new()
	_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack.anchor_right = 1.0
	_stack.anchor_bottom = 1.0
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_stack)

	_header_row = HBoxContainer.new()
	_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_child(_header_row)

	_heading_label = Label.new()
	_heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_row.add_child(_heading_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.visible = false
	_header_row.add_child(_status_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.visible = false
	_stack.add_child(_subtitle_label)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.visible = false
	_stack.add_child(_detail_label)

	_bar_shell = PanelContainer.new()
	_bar_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_shell.clip_contents = true
	_stack.add_child(_bar_shell)

	_layer_stack = VBoxContainer.new()
	_layer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_shell.add_child(_layer_stack)

	_callout_label = Label.new()
	_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout_label.visible = false
	_stack.add_child(_callout_label)

func _ensure_layers(target_count: int) -> void:
	while _layer_controls.size() > target_count:
		var tween: Variant = _layer_tweens.pop_back()
		if tween != null and tween.is_valid():
			tween.kill()
		var flash: ColorRect = _layer_flashes.pop_back()
		if flash != null and is_instance_valid(flash):
			flash.queue_free()
		var fill: ColorRect = _layer_fills.pop_back()
		if fill != null and is_instance_valid(fill):
			fill.queue_free()
		var control: Control = _layer_controls.pop_back()
		if control != null and is_instance_valid(control):
			control.queue_free()
	while _layer_controls.size() < target_count:
		var layer := Control.new()
		layer.name = "SectionLayer%d" % (_layer_controls.size() + 1)
		layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.clip_contents = true
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.anchor_right = 1.0
		fill.anchor_bottom = 1.0
		fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		fill.grow_vertical = Control.GROW_DIRECTION_BOTH
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(fill)
		var flash := ColorRect.new()
		flash.name = "Flash"
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.anchor_right = 1.0
		flash.anchor_bottom = 1.0
		flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
		flash.grow_vertical = Control.GROW_DIRECTION_BOTH
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.modulate.a = 0.0
		layer.add_child(flash)
		_layer_stack.add_child(layer)
		_layer_controls.append(layer)
		_layer_fills.append(fill)
		_layer_flashes.append(flash)
		_layer_tweens.append(null)

func _layer_visibility(target_count: int, hide_empty_immediately: bool) -> void:
	for index in range(_layer_controls.size()):
		if index >= target_count:
			_set_layer_visible(index, false)
			continue
		if hide_empty_immediately:
			_set_layer_visible(index, _section_ratio(index) > 0.0)
		else:
			_set_layer_visible(index, true)

func _set_layer_visible(index: int, visible: bool) -> void:
	if index < 0 or index >= _layer_controls.size():
		return
	var layer := _layer_controls[index]
	if layer != null:
		layer.visible = visible
	var fill := _layer_fills[index] if index < _layer_fills.size() else null
	if fill != null:
		fill.visible = visible and _section_ratio(index) > 0.0
		if not fill.visible:
			fill.scale = Vector2(0.0, 1.0)
	var flash := _layer_flashes[index] if index < _layer_flashes.size() else null
	if flash != null and not visible:
		flash.modulate.a = 0.0

func _refresh_fill_scales(animated: bool, duration: float = 0.18) -> void:
	for index in range(_layer_fills.size()):
		_refresh_fill_scale_for_index(index, animated, duration)

func _refresh_fill_scale_for_index(section_index: int, animated: bool, duration: float) -> void:
	if section_index < 0 or section_index >= _layer_fills.size():
		return
	var fill := _layer_fills[section_index]
	if fill == null:
		return
	var target_ratio := _section_ratio(section_index)
	fill.pivot_offset = Vector2.ZERO
	if target_ratio > 0.0:
		fill.visible = true
		_set_layer_visible(section_index, true)
	if animated:
		var active_tween: Variant = _layer_tweens[section_index]
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()
		var tween: Tween = create_tween()
		tween.tween_property(fill, "scale:x", target_ratio, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(_on_fill_tween_finished.bind(section_index))
		_layer_tweens[section_index] = tween
	else:
		fill.scale = Vector2(target_ratio, 1.0)
		fill.visible = target_ratio > 0.0
		if target_ratio <= 0.0:
			_set_layer_visible(section_index, false)

func _on_fill_tween_finished(section_index: int) -> void:
	if section_index < 0 or section_index >= _layer_tweens.size():
		return
	_layer_tweens[section_index] = null
	if _section_ratio(section_index) <= 0.0:
		if section_index < _layer_fills.size() and _layer_fills[section_index] != null:
			_layer_fills[section_index].scale = Vector2(0.0, 1.0)
			_layer_fills[section_index].visible = false
		_set_layer_visible(section_index, false)

func _pulse_bar_shell(strong_hit: bool = false, is_heal: bool = false) -> void:
	if _bar_shell == null:
		return
	if _bar_pulse_tween != null and _bar_pulse_tween.is_valid():
		_bar_pulse_tween.kill()
	_bar_shell.pivot_offset = _bar_shell.size * 0.5
	_bar_shell.scale = Vector2.ONE
	var scale_target := Vector2(1.006, 1.025)
	var duration := 0.16
	if is_heal:
		scale_target = Vector2(1.004, 1.016)
	elif strong_hit:
		scale_target = Vector2(1.012, 1.04)
		duration = 0.2
	_bar_pulse_tween = create_tween()
	_bar_pulse_tween.tween_property(_bar_shell, "scale", scale_target, duration * 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bar_pulse_tween.tween_property(_bar_shell, "scale", Vector2.ONE, duration * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bar_pulse_tween.finished.connect(_reset_bar_shell_pulse)

func _reset_bar_shell_pulse() -> void:
	_bar_pulse_tween = null
	if _bar_shell != null:
		_bar_shell.scale = Vector2.ONE

func _refresh_layer_styles() -> void:
	for index in range(_layer_controls.size()):
		var ratio := _section_ratio(index)
		var fill := _layer_fills[index]
		if fill != null:
			fill.color = _fill_color_for_ratio(ratio)

func _section_ratio(section_index: int) -> float:
	if section_index < 0 or section_index >= _section_healths.size() or section_index >= _section_max_healths.size():
		return 0.0
	var max_health := _section_max_healths[section_index]
	if max_health <= 0.0:
		return 0.0
	var ratio := clampf(_section_healths[section_index] / max_health, 0.0, 1.0)
	return ratio if ratio > EMPTY_LAYER_RATIO else 0.0

func _fill_color_for_ratio(ratio: float) -> Color:
	if ratio <= 0.0:
		return SurveyStyle.SURFACE_MUTED.darkened(0.32)
	if ratio <= 0.33:
		return SurveyStyle.DANGER
	if ratio <= 0.66:
		return SurveyStyle.DANGER.lerp(SurveyStyle.HIGHLIGHT_GOLD, 0.34)
	return SurveyStyle.HIGHLIGHT_GOLD.lerp(SurveyStyle.SUCCESS, 0.18)

func _apply_shell_style(fill: Color, border: Color) -> void:
	SurveyStyle.apply_panel(_bar_shell, fill, border, 12 if not _large_mode else 16, 1)
	var style := _bar_shell.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 4
		style.content_margin_bottom = 4
