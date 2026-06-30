class_name SurveyJourneyWrapupStage
extends Control

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const BOSS_BAR_SCENE: PackedScene = preload("res://Scenes/UI/SurveyJourneyBossBar.tscn")
const RECAP_MOVE_IN_START := 0.16
const RECAP_MOVE_IN_END := 0.08
const RECAP_FOCUS_HOLD_START := 0.18
const RECAP_FOCUS_HOLD_END := 0.10
const RECAP_LAUNCH_START := 0.28
const RECAP_LAUNCH_END := 0.12
const RECAP_GAP_START := 0.12
const RECAP_GAP_END := 0.03
const PROJECTILE_START_SCALE := 0.78
const PROJECTILE_FOCUS_SCALE := 1.35
const PROJECTILE_LAUNCH_SCALE := 0.96
const PROJECTILE_MIN_WIDTH := 180.0
const PROJECTILE_MAX_WIDTH := 460.0
const PROJECTILE_WIDTH_PER_CHAR := 13.0

signal replay_requested
signal recap_finished(snapshot_hash: String)

var _center: CenterContainer
var _content_panel: PanelContainer
var _content_stack: VBoxContainer
var _boss_bar
var _verdict_label: Label
var _body_label: Label
var _recommendation_label: Label
var _replay_button: Button
var _fx_layer: Control
var _active_projectiles := 0
var _animating := false
var _last_snapshot_hash := ""

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if not is_node_ready():
		return
	SurveyStyle.apply_panel(_content_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 28, 1)
	SurveyStyle.style_heading(_verdict_label, 24)
	SurveyStyle.style_body(_body_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_body(_recommendation_label, SurveyStyle.TEXT_MUTED)
	SurveyStyle.apply_secondary_button(_replay_button)
	_boss_bar.refresh_theme()

func refresh_layout(viewport_size: Vector2) -> void:
	if not is_node_ready():
		return
	var compact: bool = viewport_size.x <= 720.0
	var journey_scale: float = SurveyStyle.journey_mobile_scale(viewport_size)
	_content_panel.custom_minimum_size = Vector2(maxf(minf(viewport_size.x - 36.0, 760.0), 280.0), 0.0)
	_content_stack.add_theme_constant_override("separation", int(round((12 if compact else 14) * journey_scale)))
	_verdict_label.add_theme_font_size_override("font_size", int(round((24 if compact else 28) * journey_scale)))
	_body_label.add_theme_font_size_override("font_size", int(round((15 if compact else 16) * journey_scale)))
	_recommendation_label.add_theme_font_size_override("font_size", int(round((14 if compact else 15) * journey_scale)))
	_replay_button.custom_minimum_size = Vector2(0.0, (44.0 * journey_scale) if compact else 40.0)
	_boss_bar.set_large_mode(true)
	_boss_bar.refresh_layout(viewport_size)

func show_settled_state(state: Dictionary, snapshot_hash: String = "") -> void:
	if not is_node_ready():
		return
	_last_snapshot_hash = snapshot_hash
	_set_result_text(state)
	_boss_bar.configure_from_state(state, false)
	_replay_button.visible = not snapshot_hash.strip_edges().is_empty()
	_replay_button.disabled = false
	_clear_projectiles()

func play_recap(state: Dictionary, projectile_entries: Array[Dictionary], snapshot_hash: String = "") -> void:
	if not is_node_ready():
		return
	_animating = true
	_last_snapshot_hash = snapshot_hash
	_replay_button.visible = true
	_replay_button.disabled = true
	_clear_projectiles()
	_set_result_text(state)
	_boss_bar.configure_from_state(_full_health_state(state), false)
	await get_tree().process_frame
	var total_entries := projectile_entries.size()
	for index in range(total_entries):
		var entry_value: Variant = projectile_entries[index]
		if not (entry_value is Dictionary):
			continue
		_active_projectiles = 1
		var progress := 1.0 if total_entries <= 1 else (float(index) / float(total_entries - 1))
		var timing := _timing_for_progress(progress)
		await _play_projectile(entry_value as Dictionary, timing)
		if index < total_entries - 1:
			var gap_duration := float(timing.get("gap", 0.0))
			if gap_duration > 0.0:
				await get_tree().create_timer(gap_duration).timeout
	_active_projectiles = 0
	var result: Dictionary = state.get("wrapup_result", {})
	if bool(result.get("is_victory", false)):
		SURVEY_UI_FEEDBACK.play_boss_victory()
		_boss_bar.show_callout(str(result.get("headline", "Boss Defeated")), SurveyStyle.HIGHLIGHT_GOLD)
	else:
		SURVEY_UI_FEEDBACK.play_boss_partial_result(str(result.get("tier", "")))
		_boss_bar.show_callout(str(result.get("headline", "Wrap Up")), SurveyStyle.SOFT_WHITE)
	_replay_button.disabled = false
	_animating = false
	recap_finished.emit(snapshot_hash)

func is_animating() -> bool:
	return _animating

func snapshot_hash() -> String:
	return _last_snapshot_hash

func _build_ui() -> void:
	if _center != null:
		return
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_content_panel = PanelContainer.new()
	_content_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_content_panel)

	_content_stack = VBoxContainer.new()
	_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_panel.add_child(_content_stack)

	_boss_bar = BOSS_BAR_SCENE.instantiate() if BOSS_BAR_SCENE != null else null
	if _boss_bar != null:
		_boss_bar.name = "WrapupBossBar"
		_content_stack.add_child(_boss_bar)

	_verdict_label = Label.new()
	_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_stack.add_child(_verdict_label)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_stack.add_child(_body_label)

	_recommendation_label = Label.new()
	_recommendation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_stack.add_child(_recommendation_label)

	_replay_button = Button.new()
	_replay_button.text = "Replay Recap"
	_replay_button.visible = false
	_replay_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_replay_button.pressed.connect(_on_replay_pressed)
	_content_stack.add_child(_replay_button)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.anchor_right = 1.0
	_fx_layer.anchor_bottom = 1.0
	_fx_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fx_layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

func _set_result_text(state: Dictionary) -> void:
	var result_value: Variant = state.get("wrapup_result", {})
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	_verdict_label.text = str(result.get("headline", "Wrap Up")).strip_edges()
	_body_label.text = str(result.get("body", "")).strip_edges()
	_recommendation_label.text = str(result.get("recommendation", "")).strip_edges()
	_boss_bar.set_header("Boss Recap", "Your saved answers are crashing back into the boss bar.", _health_status_text(state))
	_boss_bar.configure_from_state(state, false)

func _health_status_text(state: Dictionary) -> String:
	var health_percent := int(round(clampf(float(state.get("health_ratio", 1.0)), 0.0, 1.0) * 100.0))
	return "HP %d%%" % health_percent

func _timing_for_progress(progress: float) -> Dictionary:
	var normalized := clampf(progress, 0.0, 1.0)
	return {
		"move_in": lerpf(RECAP_MOVE_IN_START, RECAP_MOVE_IN_END, normalized),
		"focus_hold": lerpf(RECAP_FOCUS_HOLD_START, RECAP_FOCUS_HOLD_END, normalized),
		"launch": lerpf(RECAP_LAUNCH_START, RECAP_LAUNCH_END, normalized),
		"gap": lerpf(RECAP_GAP_START, RECAP_GAP_END, normalized)
	}

func _play_projectile(entry: Dictionary, timing: Dictionary) -> void:
	if not is_node_ready():
		_active_projectiles = max(_active_projectiles - 1, 0)
		return
	var projectile := _build_projectile_node(entry)
	_fx_layer.add_child(projectile)
	var start_global: Vector2 = _random_edge_position()
	var focus_global: Vector2 = _focus_lane_position()
	var target_global: Vector2 = _boss_bar.section_target_position(int(entry.get("section_index", -1)))
	var start_local: Vector2 = start_global - _fx_layer.global_position
	var focus_local: Vector2 = focus_global - _fx_layer.global_position
	var target_local: Vector2 = target_global - _fx_layer.global_position
	var projectile_size := _resolved_projectile_size(projectile)
	projectile.pivot_offset = projectile_size * 0.5
	projectile.position = start_local - projectile.pivot_offset
	projectile.modulate = Color(1, 1, 1, 0.0)
	projectile.scale = Vector2.ONE * PROJECTILE_START_SCALE
	var move_in_duration := float(timing.get("move_in", RECAP_MOVE_IN_START))
	var focus_hold_duration := float(timing.get("focus_hold", RECAP_FOCUS_HOLD_START))
	var launch_duration := float(timing.get("launch", RECAP_LAUNCH_START))
	var focus_tween := create_tween()
	focus_tween.parallel().tween_property(projectile, "modulate:a", 1.0, minf(0.08, move_in_duration))
	focus_tween.parallel().tween_property(projectile, "position", focus_local - projectile.pivot_offset, move_in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	focus_tween.parallel().tween_property(projectile, "scale", Vector2.ONE * PROJECTILE_FOCUS_SCALE, move_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await focus_tween.finished
	if focus_hold_duration > 0.0:
		await get_tree().create_timer(focus_hold_duration).timeout
	var launch_tween := create_tween()
	launch_tween.parallel().tween_property(projectile, "position", target_local - projectile.pivot_offset, launch_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	launch_tween.parallel().tween_property(projectile, "scale", Vector2.ONE * PROJECTILE_LAUNCH_SCALE, launch_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	launch_tween.parallel().tween_property(projectile, "modulate:a", 0.82, launch_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await launch_tween.finished
	_handle_projectile_impact(entry, target_local)
	if projectile != null and is_instance_valid(projectile):
		projectile.queue_free()
	_active_projectiles = max(_active_projectiles - 1, 0)

func _handle_projectile_impact(entry: Dictionary, target_local: Vector2) -> void:
	var section_index := int(entry.get("section_index", -1))
	var is_complete := bool(entry.get("counts_as_damage", false))
	var impact_spark := PanelContainer.new()
	impact_spark.custom_minimum_size = Vector2(16.0, 16.0)
	impact_spark.position = target_local - Vector2(8.0, 8.0)
	impact_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.apply_panel(impact_spark, Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.0), 999, 0)
	_fx_layer.add_child(impact_spark)
	var spark_tween := create_tween()
	spark_tween.parallel().tween_property(impact_spark, "scale", Vector2.ONE * 1.8, 0.18)
	spark_tween.parallel().tween_property(impact_spark, "modulate:a", 0.0, 0.18)
	spark_tween.finished.connect(Callable(impact_spark, "queue_free"))
	if is_complete:
		_boss_bar.animate_section_change(section_index, float(entry.get("damage_amount", 0.0)), false, 0.12, bool(entry.get("strong_hit", false)))
		SURVEY_UI_FEEDBACK.play_boss_hit(bool(entry.get("strong_hit", false)))
	else:
		_boss_bar.play_surface_hit(section_index, false, false)
		SURVEY_UI_FEEDBACK.play_boss_glancing()

func _build_projectile_node(entry: Dictionary) -> Control:
	var label_text := str(entry.get("label_text", "")).strip_edges()
	var attack_color := SurveyStyle.HIGHLIGHT_GOLD if bool(entry.get("counts_as_damage", false)) else Color(1, 1, 1, 0.88)
	var attack_size := int(round(((20.0 if get_viewport_rect().size.x <= 720.0 else 22.0) * SurveyStyle.journey_mobile_scale(get_viewport_rect().size))))
	var panel := MarginContainer.new()
	panel.custom_minimum_size = Vector2(clampf(float(label_text.length()) * PROJECTILE_WIDTH_PER_CHAR, PROJECTILE_MIN_WIDTH, PROJECTILE_MAX_WIDTH), 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("margin_left", 6)
	panel.add_theme_constant_override("margin_right", 6)
	panel.add_theme_constant_override("margin_top", 4)
	panel.add_theme_constant_override("margin_bottom", 4)
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_heading(label, attack_size, attack_color)
	label.add_theme_color_override("font_outline_color", SurveyStyle.TEXT_OUTLINE.darkened(0.18))
	label.add_theme_constant_override("outline_size", 4)
	panel.add_child(label)
	return panel

func _full_health_state(state: Dictionary) -> Dictionary:
	var resolved := state.duplicate(true)
	var sections_value: Variant = resolved.get("sections", [])
	if not (sections_value is Array):
		return resolved
	var full_sections: Array[Dictionary] = []
	for section_value in sections_value:
		if not (section_value is Dictionary):
			continue
		var section := (section_value as Dictionary).duplicate(true)
		section["current_health"] = float(section.get("max_health", 0.0))
		section["damage_ratio"] = 0.0
		section["is_broken"] = false
		full_sections.append(section)
	resolved["sections"] = full_sections
	resolved["total_damage"] = 0.0
	resolved["damage_ratio"] = 0.0
	resolved["health_ratio"] = 1.0
	return resolved

func _random_edge_position() -> Vector2:
	var rect := get_global_rect()
	var width := rect.size.x
	var height := rect.size.y
	match randi() % 4:
		0:
			return rect.position + Vector2(randf_range(0.0, width), -22.0)
		1:
			return rect.position + Vector2(width + 22.0, randf_range(0.0, height))
		2:
			return rect.position + Vector2(randf_range(0.0, width), height + 22.0)
		_:
			return rect.position + Vector2(-22.0, randf_range(0.0, height))

func _focus_lane_position() -> Vector2:
	var panel_rect := _content_panel.get_global_rect()
	var boss_rect: Rect2 = _boss_bar.get_global_rect()
	var verdict_rect: Rect2 = _verdict_label.get_global_rect()
	var x_position := panel_rect.get_center().x
	var min_y: float = boss_rect.end.y + 20.0
	var max_y: float = verdict_rect.position.y - 20.0
	var y_position := panel_rect.get_center().y
	if max_y >= min_y:
		y_position = lerpf(min_y, max_y, 0.5)
	return Vector2(
		clampf(x_position, panel_rect.position.x + 48.0, panel_rect.end.x - 48.0),
		clampf(y_position, panel_rect.position.y + 48.0, panel_rect.end.y - 48.0)
	)

func _resolved_projectile_size(projectile: Control) -> Vector2:
	if projectile == null:
		return Vector2.ZERO
	var resolved_size := projectile.get_combined_minimum_size()
	resolved_size.x = maxf(resolved_size.x, projectile.custom_minimum_size.x)
	resolved_size.y = maxf(resolved_size.y, projectile.custom_minimum_size.y)
	projectile.size = resolved_size
	return resolved_size

func _clear_projectiles() -> void:
	_active_projectiles = 0
	for child in _fx_layer.get_children():
		child.queue_free()

func _queue_projectile_free(node: Control) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()

func _on_replay_pressed() -> void:
	replay_requested.emit()
