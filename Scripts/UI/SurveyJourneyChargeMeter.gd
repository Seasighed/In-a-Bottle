class_name SurveyJourneyChargeMeter
extends PanelContainer

var _stack: VBoxContainer
var _top_row: HBoxContainer
var _title_label: Label
var _state_label: Label
var _bar_shell: PanelContainer
var _fill: ColorRect
var _hint_label: Label
var _bar_tween: Tween
var _charge_ratio := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if not is_node_ready():
		return
	SurveyStyle.apply_panel(self, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	var shell_style := SurveyStyle.panel(SurveyStyle.SURFACE, SurveyStyle.BORDER, 999, 1)
	shell_style.content_margin_left = 4
	shell_style.content_margin_right = 4
	shell_style.content_margin_top = 4
	shell_style.content_margin_bottom = 4
	_bar_shell.add_theme_stylebox_override("panel", shell_style)
	SurveyStyle.style_caption(_title_label, SurveyStyle.SOFT_WHITE)
	SurveyStyle.style_caption(_state_label, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.style_caption(_hint_label, SurveyStyle.TEXT_MUTED)
	_fill.color = SurveyStyle.HIGHLIGHT_GOLD.lerp(SurveyStyle.ACCENT_ALT, 0.25)

func refresh_layout(viewport_size: Vector2) -> void:
	if not is_node_ready():
		return
	var compact: bool = viewport_size.x <= 640.0
	_stack.add_theme_constant_override("separation", 4 if compact else 5)
	_top_row.add_theme_constant_override("separation", 8 if compact else 10)
	custom_minimum_size = Vector2(220.0 if compact else 240.0, 0.0)
	_bar_shell.custom_minimum_size = Vector2(0.0, 14.0 if compact else 16.0)
	_title_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	_state_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	_hint_label.add_theme_font_size_override("font_size", 11 if compact else 12)

func set_charge_state(question: SurveyQuestion, completion_state: StringName, ratio: float) -> void:
	if not is_node_ready():
		return
	_charge_ratio = clampf(ratio, 0.0, 1.0)
	var state_text := "Empty"
	var hint_text := "Answer the question to charge an attack."
	match completion_state:
		SurveyQuestion.ANSWER_STATE_COMPLETE:
			state_text = "Ready"
			hint_text = "Press Next to unleash the hit."
		SurveyQuestion.ANSWER_STATE_PARTIAL:
			state_text = "Charging"
			hint_text = "Keep going to fully charge the attack."
	_title_label.text = "Attack Charge"
	if question != null and not question.prompt.strip_edges().is_empty():
		hint_text = "%s  %s" % [question.prompt.strip_edges(), hint_text]
	_state_label.text = state_text
	_hint_label.text = hint_text
	_refresh_fill(true)

func play_release() -> void:
	if not is_node_ready():
		return
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_fill.scale = Vector2(_fill.scale.x, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(_fill, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_fill, "modulate:a", 0.2, 0.1)
	tween.tween_property(_fill, "modulate:a", 1.0, 0.12)
	_bar_tween = tween
	_charge_ratio = 0.0

func source_global_position() -> Vector2:
	return _bar_shell.global_position + (_bar_shell.size * 0.5)

func _build_ui() -> void:
	if _stack != null:
		return
	_stack = VBoxContainer.new()
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_stack)

	_top_row = HBoxContainer.new()
	_top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_child(_top_row)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(_title_label)

	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_row.add_child(_state_label)

	_bar_shell = PanelContainer.new()
	_bar_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_child(_bar_shell)

	_fill = ColorRect.new()
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.anchor_right = 1.0
	_fill.anchor_bottom = 1.0
	_fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fill.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.scale = Vector2.ZERO
	_bar_shell.add_child(_fill)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack.add_child(_hint_label)

func _refresh_fill(animated: bool) -> void:
	if _fill == null:
		return
	SurveyStyle.set_charge_glow(_bar_shell, _charge_ratio, SurveyStyle.HIGHLIGHT_GOLD, SurveyStyle.ACCENT_ALT)
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_fill.scale = Vector2(_fill.scale.x, 1.0)
	if animated:
		_bar_tween = create_tween()
		_bar_tween.tween_property(_fill, "scale:x", _charge_ratio, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_fill.scale = Vector2(_charge_ratio, 1.0)
