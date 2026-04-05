class_name SurveyGamificationHud
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const SPRITE_ICON_HOST = preload("res://Scripts/UI/SpriteIconHost.gd")

@onready var _floating_layer: Control = $FloatingLayer
@onready var _toast_margin: MarginContainer = $ToastMargin
@onready var _toast_stack: VBoxContainer = $ToastMargin/ToastStack
@onready var _bottom_margin: MarginContainer = $BottomMargin
@onready var _bottom_shell: PanelContainer = $BottomMargin/BottomShell
@onready var _level_label: Label = $BottomMargin/BottomShell/BottomRow/LevelLabel
@onready var _bar_panel: PanelContainer = $BottomMargin/BottomShell/BottomRow/BarPanel
@onready var _segment_row: HBoxContainer = $BottomMargin/BottomShell/BottomRow/BarPanel/SegmentRow
@onready var _xp_label: Label = $BottomMargin/BottomShell/BottomRow/XpLabel
@onready var _buff_label: Label = $BottomMargin/BottomShell/BottomRow/BuffLabel

var _segment_controls: Array[Control] = []
var _toast_queue: Array[Dictionary] = []
var _toast_showing := false

func _ready() -> void:
	layer = 54
	visible = false
	_bottom_margin.visible = false
	_bottom_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	SurveyStyle.apply_panel(_bottom_shell, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 16, 1)
	var bar_style: StyleBoxFlat = SurveyStyle.panel(SurveyStyle.SURFACE, SurveyStyle.BORDER, 12, 1)
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 8
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	_bar_panel.add_theme_stylebox_override("panel", bar_style)
	SurveyStyle.style_caption(_level_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_xp_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_buff_label, SurveyStyle.HIGHLIGHT_GOLD)

func refresh_layout(viewport_size: Vector2) -> void:
	var horizontal_margin: float = clampf(viewport_size.x * 0.02, 12.0, 28.0)
	var vertical_margin: float = clampf(viewport_size.y * 0.02, 10.0, 22.0)
	_toast_margin.add_theme_constant_override("margin_left", int(horizontal_margin))
	_toast_margin.add_theme_constant_override("margin_top", int(vertical_margin))
	_bottom_margin.add_theme_constant_override("margin_left", int(horizontal_margin))
	_bottom_margin.add_theme_constant_override("margin_right", int(horizontal_margin))
	_bottom_margin.add_theme_constant_override("margin_bottom", int(vertical_margin))
	var compact: bool = viewport_size.x <= 640.0
	_bottom_shell.custom_minimum_size = Vector2(0.0, 32.0 if compact else 36.0)
	_xp_label.visible = not compact
	if compact:
		_buff_label.add_theme_font_size_override("font_size", 11)
	else:
		_buff_label.add_theme_font_size_override("font_size", 12)

func set_hud_visible(enabled: bool) -> void:
	visible = enabled

func configure_progress(progress: Dictionary) -> void:
	_apply_progress(progress)

func handle_award_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var hud_state: Dictionary = result.get("hud_state", {})
	_apply_progress(hud_state)
	var xp_awarded: int = int(result.get("xp_awarded", 0))
	if xp_awarded > 0:
		var multiplier: float = float(result.get("multiplier_applied", 1.0))
		var screen_pos: Vector2 = result.get("screen_pos", Vector2.ZERO)
		var meta: Dictionary = result.get("meta", {})
		var multiplier_suffix: String = ("  x%s" % _multiplier_text(multiplier)) if multiplier > 1.0 else ""
		_spawn_floating_popup("+%d XP%s" % [xp_awarded, multiplier_suffix], screen_pos)
		_spawn_reward_sprite(str(meta.get("question_reward_sprite", "")).strip_edges(), screen_pos)
		_spawn_orbs(screen_pos, xp_awarded)
		SURVEY_UI_FEEDBACK.play_xp_gain(clampf(float(xp_awarded) / 40.0, 0.25, 1.0))
	var buff_awarded_value: Variant = result.get("buff_awarded", {})
	var buff_awarded: Dictionary = buff_awarded_value as Dictionary if buff_awarded_value is Dictionary else {}
	var achievements_value: Variant = result.get("achievements_unlocked", [])
	var achievements: Array = achievements_value as Array if achievements_value is Array else []
	if not buff_awarded.is_empty() or int(result.get("leveled_to", 0)) > int(result.get("leveled_from", 0)) or not achievements.is_empty():
		SURVEY_UI_FEEDBACK.play_unlock()
	var toast_entries_value: Variant = result.get("toast_entries", [])
	if toast_entries_value is Array:
		for entry_value in toast_entries_value:
			if entry_value is Dictionary:
				_queue_toast(entry_value as Dictionary)

func _apply_progress(progress: Dictionary) -> void:
	var xp_total: int = max(0, int(progress.get("xp_total", 0)))
	var level: int = max(1, int(progress.get("level", 1)))
	var segment_count: int = max(8, int(progress.get("segment_count", 20)))
	var progress_ratio: float = clampf(float(progress.get("progress_ratio", 0.0)), 0.0, 1.0)
	var level_current: int = max(0, int(progress.get("level_current", 0)))
	var level_target: int = max(1, int(progress.get("level_target", 100)))
	var active_buff_label: String = str(progress.get("active_buff_label", "")).strip_edges()
	_level_label.text = "LV %d" % level
	_xp_label.text = "%d XP  |  %d / %d" % [xp_total, level_current, level_target]
	_buff_label.text = active_buff_label
	_buff_label.visible = not active_buff_label.is_empty()
	_ensure_segments(segment_count)
	var filled_segments: int = int(round(progress_ratio * float(segment_count)))
	for segment_index in range(_segment_controls.size()):
		var segment: Control = _segment_controls[segment_index]
		if segment == null:
			continue
		var segment_fill: ColorRect = segment.get_node_or_null("Fill") as ColorRect
		if segment_fill == null:
			continue
		segment_fill.color = SurveyStyle.HIGHLIGHT_GOLD if segment_index < filled_segments else SurveyStyle.BORDER

func _ensure_segments(target_count: int) -> void:
	while _segment_controls.size() > target_count:
		var control: Control = _segment_controls.pop_back()
		if control != null:
			control.queue_free()
	while _segment_controls.size() < target_count:
		var segment := PanelContainer.new()
		segment.custom_minimum_size = Vector2(0.0, 10.0)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.anchors_preset = Control.PRESET_FULL_RECT
		fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		fill.grow_vertical = Control.GROW_DIRECTION_BOTH
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = SurveyStyle.BORDER
		segment.add_child(fill)
		_segment_row.add_child(segment)
		_segment_controls.append(segment)

func _queue_toast(entry: Dictionary) -> void:
	var resolved_entry: Dictionary = entry.duplicate(true)
	var kind: String = str(resolved_entry.get("kind", "xp")).strip_edges()
	if kind == "xp" and not _toast_queue.is_empty():
		var last_index: int = _toast_queue.size() - 1
		var last_entry: Dictionary = _toast_queue[last_index]
		if str(last_entry.get("kind", "")).strip_edges() == "xp":
			_toast_queue[last_index] = resolved_entry
			return
	if _toast_queue.size() >= 6:
		_toast_queue.pop_front()
	_toast_queue.append(resolved_entry)
	if not _toast_showing:
		call_deferred("_show_next_toast")

func _show_next_toast() -> void:
	if _toast_showing or _toast_queue.is_empty():
		return
	_toast_showing = true
	var entry: Dictionary = _toast_queue.pop_front()
	var text: String = str(entry.get("text", "")).strip_edges()
	if text.is_empty():
		_toast_showing = false
		call_deferred("_show_next_toast")
		return
	var kind: String = str(entry.get("kind", "xp")).strip_edges()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 0)
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, _toast_border_color(kind), 14, 1)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(label, _toast_text_color(kind))
	panel.add_child(label)
	_toast_stack.add_child(panel)
	var intro := create_tween()
	intro.tween_property(panel, "modulate:a", 1.0, 0.1)
	await intro.finished
	await get_tree().create_timer(0.5).timeout
	var outro := create_tween()
	outro.tween_property(panel, "modulate:a", 0.0, 0.14)
	outro.tween_property(panel, "position:y", panel.position.y - 10.0, 0.14)
	await outro.finished
	if is_instance_valid(panel):
		panel.queue_free()
	_toast_showing = false
	if not _toast_queue.is_empty():
		call_deferred("_show_next_toast")

func _spawn_floating_popup(text: String, screen_pos: Vector2) -> void:
	if text.is_empty():
		return
	var rect := get_viewport().get_visible_rect()
	var resolved_pos: Vector2 = screen_pos
	if resolved_pos == Vector2.ZERO:
		resolved_pos = rect.size * 0.5
	resolved_pos.x = clampf(resolved_pos.x, 18.0, rect.size.x - 120.0)
	resolved_pos.y = clampf(resolved_pos.y, 24.0, rect.size.y - 48.0)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = resolved_pos + Vector2(12.0, -8.0)
	label.scale = Vector2.ONE * 0.92
	label.modulate = Color(1, 1, 1, 0)
	SurveyStyle.style_heading(label, 16, SurveyStyle.HIGHLIGHT_GOLD)
	_floating_layer.add_child(label)
	var tween := create_tween()
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.12)
	tween.parallel().tween_property(label, "position:y", label.position.y - 24.0, 0.28)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.28)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()

func _spawn_reward_sprite(sprite_path: String, screen_pos: Vector2) -> void:
	if sprite_path.is_empty():
		return
	var texture: Texture2D = ResourceLoader.load(sprite_path) as Texture2D
	if texture == null:
		return
	var rect := get_viewport().get_visible_rect()
	var resolved_pos: Vector2 = screen_pos
	if resolved_pos == Vector2.ZERO:
		resolved_pos = rect.size * 0.5
	resolved_pos.x = clampf(resolved_pos.x, 28.0, rect.size.x - 44.0)
	resolved_pos.y = clampf(resolved_pos.y, 28.0, rect.size.y - 44.0)
	var icon = SPRITE_ICON_HOST.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.position = resolved_pos + Vector2(-30.0, -24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, 0)
	_floating_layer.add_child(icon)
	icon.set_icon(texture, Color.WHITE, 28.0)
	var tween := create_tween()
	tween.parallel().tween_property(icon, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(icon, "position:y", icon.position.y - 10.0, 0.18)
	tween.tween_interval(0.1)
	tween.parallel().tween_property(icon, "position:y", icon.position.y - 24.0, 0.26)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.26)
	await tween.finished
	if is_instance_valid(icon):
		icon.queue_free()

func _spawn_orbs(screen_pos: Vector2, xp_awarded: int) -> void:
	var rect := get_viewport().get_visible_rect()
	var resolved_pos: Vector2 = screen_pos
	if resolved_pos == Vector2.ZERO:
		resolved_pos = rect.size * 0.5
	var orb_count: int = clampi(3 + int(round(float(xp_awarded) / 10.0)), 3, 8)
	for orb_index in range(orb_count):
		var orb := PanelContainer.new()
		orb.custom_minimum_size = Vector2(8.0, 8.0)
		orb.size = Vector2(8.0, 8.0)
		orb.position = resolved_pos + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SurveyStyle.apply_panel(orb, SurveyStyle.HIGHLIGHT_GOLD, SurveyStyle.HIGHLIGHT_GOLD.lightened(0.12), 999, 0)
		_floating_layer.add_child(orb)
		var drift: Vector2 = Vector2(randf_range(-36.0, 36.0), randf_range(-54.0, -18.0))
		var tween := create_tween()
		tween.parallel().tween_property(orb, "position", orb.position + drift, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(orb, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(orb, "scale", Vector2.ONE * randf_range(0.6, 1.4), 0.4)
		tween.finished.connect(_queue_orb_free.bind(orb))

func _queue_orb_free(orb: Control) -> void:
	if orb != null and is_instance_valid(orb):
		orb.queue_free()

func _toast_border_color(kind: String) -> Color:
	match kind:
		"unlock", "title":
			return SurveyStyle.HIGHLIGHT_GOLD
		"level":
			return SurveyStyle.ACCENT_ALT
		"buff":
			return SurveyStyle.SUCCESS
		"section":
			return SurveyStyle.ACCENT
		"survey":
			return SurveyStyle.SUCCESS
	return SurveyStyle.BORDER

func _toast_text_color(kind: String) -> Color:
	match kind:
		"unlock", "title":
			return SurveyStyle.HIGHLIGHT_GOLD
		"level":
			return SurveyStyle.ACCENT_ALT
		"buff":
			return SurveyStyle.SUCCESS
		"section":
			return SurveyStyle.TEXT_PRIMARY
		"survey":
			return SurveyStyle.SUCCESS
	return SurveyStyle.TEXT_PRIMARY

func _multiplier_text(multiplier: float) -> String:
	if is_equal_approx(multiplier, round(multiplier)):
		return str(int(round(multiplier)))
	return str(snappedf(multiplier, 0.1))
