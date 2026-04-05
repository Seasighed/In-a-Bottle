class_name SurveyToastOverlay
extends CanvasLayer

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")

signal action_requested(action_id: String)

var _stack: VBoxContainer

func _ready() -> void:
	layer = 62
	_build_shell()
	refresh_theme()
	refresh_layout(get_viewport().get_visible_rect().size)

func refresh_theme() -> void:
	if _stack == null:
		return
	for child in _stack.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		var kind: String = str(panel.get_meta("toast_kind", "info"))
		SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, _border_color(kind), 16, 1)

func refresh_layout(viewport_size: Vector2) -> void:
	if _stack == null:
		return
	var margin: float = clampf(viewport_size.x * 0.025, 12.0, 28.0)
	_stack.offset_left = maxf(viewport_size.x - minf(viewport_size.x - (margin * 2.0), 420.0) - margin, margin)
	_stack.offset_top = margin
	_stack.custom_minimum_size = Vector2(clampf(viewport_size.x - (margin * 2.0), 240.0, 420.0), 0.0)

func show_toast(message: String, kind: String = "info", action_id: String = "", action_label: String = "", persistent: bool = false, duration_seconds: float = 3.6) -> void:
	var resolved_message: String = message.strip_edges()
	if resolved_message.is_empty():
		return
	if _stack == null:
		_build_shell()
	var panel := PanelContainer.new()
	panel.set_meta("toast_kind", kind)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.modulate = Color(1, 1, 1, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, _border_color(kind), 16, 1)

	var stack := VBoxContainer.new()
	stack.layout_mode = 2
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)

	var message_label := Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.text = resolved_message
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_body(message_label, SurveyStyle.TEXT_PRIMARY)
	stack.add_child(message_label)

	var has_action: bool = not action_id.strip_edges().is_empty() and not action_label.strip_edges().is_empty()
	if has_action:
		var action_row := HBoxContainer.new()
		action_row.layout_mode = 2
		action_row.add_theme_constant_override("separation", 8)
		stack.add_child(action_row)

		var action_button := Button.new()
		action_button.text = action_label.strip_edges()
		SurveyStyle.apply_primary_button(action_button)
		action_button.pressed.connect(_on_action_pressed.bind(action_id.strip_edges(), panel))
		action_button.mouse_entered.connect(_on_button_hovered)
		action_button.pressed.connect(_on_button_pressed_feedback)
		action_row.add_child(action_button)

		var dismiss_button := Button.new()
		dismiss_button.text = "Dismiss"
		SurveyStyle.apply_secondary_button(dismiss_button)
		dismiss_button.pressed.connect(_dismiss_toast.bind(panel))
		dismiss_button.mouse_entered.connect(_on_button_hovered)
		dismiss_button.pressed.connect(_on_button_pressed_feedback)
		action_row.add_child(dismiss_button)
	elif persistent:
		var dismiss_button := Button.new()
		dismiss_button.text = "Dismiss"
		SurveyStyle.apply_secondary_button(dismiss_button)
		dismiss_button.pressed.connect(_dismiss_toast.bind(panel))
		dismiss_button.mouse_entered.connect(_on_button_hovered)
		dismiss_button.pressed.connect(_on_button_pressed_feedback)
		stack.add_child(dismiss_button)

	_stack.add_child(panel)
	var intro := create_tween()
	intro.tween_property(panel, "modulate:a", 1.0, 0.12)
	if persistent or has_action:
		return
	call_deferred("_auto_dismiss_toast", panel, duration_seconds)

func _build_shell() -> void:
	if _stack != null:
		return
	_stack = VBoxContainer.new()
	_stack.name = "ToastStack"
	_stack.add_theme_constant_override("separation", 10)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.anchor_left = 0.0
	_stack.anchor_top = 0.0
	_stack.anchor_right = 0.0
	_stack.anchor_bottom = 0.0
	add_child(_stack)

func _auto_dismiss_toast(panel: PanelContainer, duration_seconds: float) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	await get_tree().create_timer(maxf(duration_seconds, 0.1)).timeout
	_dismiss_toast(panel)

func _dismiss_toast(panel: PanelContainer) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tween := create_tween()
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(panel, "position:y", panel.position.y - 8.0, 0.12)
	await tween.finished
	if panel != null and is_instance_valid(panel):
		panel.queue_free()

func _on_action_pressed(action_id: String, panel: PanelContainer) -> void:
	action_requested.emit(action_id)
	_dismiss_toast(panel)

func _on_button_hovered() -> void:
	SURVEY_UI_FEEDBACK.play_hover()

func _on_button_pressed_feedback() -> void:
	SURVEY_UI_FEEDBACK.play_select()

func _border_color(kind: String) -> Color:
	match kind:
		"warning":
			return SurveyStyle.HIGHLIGHT_GOLD
		"error":
			return SurveyStyle.DANGER
		"success":
			return SurveyStyle.SUCCESS
		"modifier":
			return SurveyStyle.ACCENT_ALT
	return SurveyStyle.BORDER
