class_name DefaultQuestionView
extends SurveyQuestionView

const TYPED_ANSWER_FIELD_SCENE := preload("res://Scenes/AnswerPrefabs/TypedAnswerField.tscn")
const CHECKBOX_OPTION_ROW_SCENE := preload("res://Scenes/AnswerPrefabs/CheckboxOptionRow.tscn")
const MULTIPLE_CHOICE_OPTION_ROW_SCENE := preload("res://Scenes/AnswerPrefabs/MultipleChoiceOptionRow.tscn")
@onready var _card: PanelContainer = $Card
@onready var _stack: VBoxContainer = $Card/Stack
@onready var _title_label: Label = $Card/Stack/TitleLabel
@onready var _description_label: Label = $Card/Stack/DescriptionLabel
@onready var _meta_label: Label = $Card/Stack/MetaLabel
@onready var _field_host: VBoxContainer = $Card/Stack/FieldHost

var _primary_control: Control

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SurveyStyle.style_heading(_title_label, 20)
	SurveyStyle.style_body(_description_label)
	SurveyStyle.style_caption(_meta_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.gui_input.connect(_on_card_gui_input)
	refresh_responsive_layout(get_viewport().get_visible_rect().size)
	super()

func _apply_question() -> void:
	if question == null:
		return

	_title_label.text = question.display_prompt()
	_description_label.text = question.description
	_description_label.visible = not question.description.is_empty()

	var bits: Array[String] = []
	if question.required:
		bits.append("Required")
	bits.append(_type_label(question.type))
	_meta_label.text = " | ".join(bits)

	_clear_children(_field_host)
	_primary_control = null

	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			_build_typed_answer_field(str(current_value if current_value != null else ""), question.placeholder, false, _on_short_text_changed)
		SurveyQuestion.TYPE_LONG_TEXT:
			_build_typed_answer_field(str(current_value if current_value != null else ""), question.placeholder, true, _on_long_text_changed)
		SurveyQuestion.TYPE_EMAIL:
			_build_typed_answer_field(str(current_value if current_value != null else ""), question.placeholder if not question.placeholder.is_empty() else "name@example.com", false, _on_email_changed)
		SurveyQuestion.TYPE_DATE:
			_build_typed_answer_field(str(current_value if current_value != null else ""), question.placeholder if not question.placeholder.is_empty() else "YYYY-MM-DD", false, _on_date_changed)
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			_build_single_choice_field()
		SurveyQuestion.TYPE_DROPDOWN:
			_build_dropdown_field()
		SurveyQuestion.TYPE_MULTI_CHOICE:
			_build_multi_choice_field()
		SurveyQuestion.TYPE_BOOLEAN:
			_build_boolean_field()
		SurveyQuestion.TYPE_SCALE:
			_build_scale_field()
		SurveyQuestion.TYPE_NUMBER:
			_build_number_field()
		_:
			_build_typed_answer_field(str(current_value if current_value != null else ""), question.placeholder, false, _on_short_text_changed)

	_apply_selection_state()
	refresh_responsive_layout(get_viewport().get_visible_rect().size)
	_refresh_layout_metrics()

func _apply_selection_state() -> void:
	var border_color := SurveyStyle.ACCENT_ALT if is_selected else SurveyStyle.BORDER
	var fill_color := SurveyStyle.SURFACE_MUTED if is_selected else SurveyStyle.SURFACE
	SurveyStyle.apply_panel(_card, fill_color, border_color, 20, 1)

func focus_primary_control() -> void:
	if _primary_control != null:
		_primary_control.grab_focus()

func refresh_responsive_layout(viewport_size: Vector2) -> void:
	var compact_layout: bool = viewport_size.x <= 640.0
	_stack.add_theme_constant_override("separation", 8 if compact_layout else 10)
	_field_host.add_theme_constant_override("separation", 8 if compact_layout else 10)
	SurveyStyle.style_heading(_title_label, 18 if compact_layout else 20)
	SurveyStyle.style_body(_description_label)
	SurveyStyle.style_caption(_meta_label)
	for child in _field_host.get_children():
		if child is TypedAnswerField:
			(child as TypedAnswerField).refresh_responsive_layout(viewport_size)
	_refresh_layout_metrics()

func _build_typed_answer_field(value: String, placeholder: String, multiline: bool, handler: Callable) -> void:
	var field := TYPED_ANSWER_FIELD_SCENE.instantiate() as TypedAnswerField
	if field == null:
		return
	_field_host.add_child(field)
	field.configure(value, placeholder, multiline)
	field.value_changed.connect(handler)
	register_selectable(field.get_primary_control())
	_primary_control = field.get_primary_control()

func _build_single_choice_field() -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	_field_host.add_child(holder)
	var button_group := ButtonGroup.new()
	var selected_value := str(current_value if current_value != null else "")
	for option in question.options:
		var row := MULTIPLE_CHOICE_OPTION_ROW_SCENE.instantiate() as MultipleChoiceOptionRow
		if row == null:
			continue
		holder.add_child(row)
		row.configure(option, option == selected_value, button_group)
		row.selected.connect(_on_single_choice_selected)
		register_selectable(row.get_primary_control())
		if _primary_control == null:
			_primary_control = row.get_primary_control()

func _build_dropdown_field() -> void:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.add_item("Choose one")
	for option in question.options:
		picker.add_item(option)
	var selected_value := str(current_value if current_value != null else "")
	var selected_index := 0
	for index in range(question.options.size()):
		if question.options[index] == selected_value:
			selected_index = index + 1
			break
	picker.select(selected_index)
	picker.item_selected.connect(_on_dropdown_selected.bind(picker))
	SurveyStyle.style_option_button(picker)
	_field_host.add_child(picker)
	register_selectable(picker)
	_primary_control = picker

func _build_multi_choice_field() -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	_field_host.add_child(holder)
	var selected_values: Array[String] = []
	if current_value is Array:
		for item in current_value:
			selected_values.append(str(item))
	for option in question.options:
		var row := CHECKBOX_OPTION_ROW_SCENE.instantiate() as CheckboxOptionRow
		if row == null:
			continue
		holder.add_child(row)
		row.configure(option, selected_values.has(option))
		row.toggled.connect(_on_multi_choice_toggled.bind(holder))
		register_selectable(row.get_primary_control())
		if _primary_control == null:
			_primary_control = row.get_primary_control()

func _build_boolean_field() -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	_field_host.add_child(holder)
	var button_group := ButtonGroup.new()
	var selected_value := ""
	match current_value:
		true:
			selected_value = "Yes"
		false:
			selected_value = "No"
	for option in ["Yes", "No"]:
		var row := MULTIPLE_CHOICE_OPTION_ROW_SCENE.instantiate() as MultipleChoiceOptionRow
		if row == null:
			continue
		holder.add_child(row)
		row.configure(option, option == selected_value, button_group)
		row.selected.connect(_on_boolean_selected)
		register_selectable(row.get_primary_control())
		if _primary_control == null:
			_primary_control = row.get_primary_control()

func _build_scale_field() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)

	var slider := HSlider.new()
	slider.min_value = question.min_value
	slider.max_value = question.max_value
	slider.step = question.step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = float(current_value if current_value != null else question.min_value)
	register_selectable(slider)

	var caption := Label.new()
	SurveyStyle.style_caption(caption)
	caption.text = "Current value: %s" % _format_number_value(slider.value)

	var bounds := HBoxContainer.new()
	var low := Label.new()
	low.text = question.left_label if not question.left_label.is_empty() else str(question.min_value)
	SurveyStyle.style_caption(low)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var high := Label.new()
	high.text = question.right_label if not question.right_label.is_empty() else str(question.max_value)
	SurveyStyle.style_caption(high)
	bounds.add_child(low)
	bounds.add_child(spacer)
	bounds.add_child(high)

	slider.value_changed.connect(_on_scale_value_changed.bind(caption))

	wrapper.add_child(slider)
	wrapper.add_child(bounds)
	wrapper.add_child(caption)
	_field_host.add_child(wrapper)
	_primary_control = slider

func _build_number_field() -> void:
	var field := LineEdit.new()
	field.placeholder_text = question.placeholder if not question.placeholder.is_empty() else "Enter a number"
	field.text = str(current_value if current_value != null else "")
	SurveyStyle.style_line_edit(field)
	field.text_changed.connect(_on_number_changed)
	_field_host.add_child(field)
	register_selectable(field)
	_primary_control = field

func _format_number_value(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(value)

func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			emit_selected()

func _on_short_text_changed(value: String) -> void:
	emit_answer(value)

func _on_long_text_changed(value: String) -> void:
	emit_answer(value)

func _on_email_changed(value: String) -> void:
	emit_answer(value.strip_edges())

func _on_date_changed(value: String) -> void:
	emit_answer(value.strip_edges())

func _on_number_changed(value: String) -> void:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		emit_answer(null)
		return
	if trimmed.is_valid_int():
		emit_answer(int(trimmed))
		return
	if trimmed.is_valid_float():
		emit_answer(float(trimmed))
		return
	emit_answer(null)

func _on_single_choice_selected(value: String) -> void:
	emit_answer(value)

func _on_dropdown_selected(index: int, picker: OptionButton) -> void:
	SURVEY_UI_FEEDBACK.play_answer_select()
	SURVEY_UI_FEEDBACK.pulse(picker, 0.04, 0.15)
	emit_answer("" if index == 0 else picker.get_item_text(index))

func _on_multi_choice_toggled(_value: String, _pressed: bool, holder: VBoxContainer) -> void:
	var values: Array[String] = []
	for child in holder.get_children():
		var row := child as CheckboxOptionRow
		if row != null and row.is_checked():
			values.append(row.get_value())
	emit_answer(values)

func _on_boolean_selected(value: String) -> void:
	emit_answer(value == "Yes")

func _on_scale_value_changed(value: float, caption: Label) -> void:
	caption.text = "Current value: %s" % _format_number_value(value)
	if is_equal_approx(value, round(value)):
		emit_answer(int(round(value)))
	else:
		emit_answer(value)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.free()

func _type_label(kind: StringName) -> String:
	match kind:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_LONG_TEXT:
			return "Typed answer"
		SurveyQuestion.TYPE_EMAIL:
			return "Email"
		SurveyQuestion.TYPE_DATE:
			return "Date"
		SurveyQuestion.TYPE_NUMBER:
			return "Number"
		SurveyQuestion.TYPE_SINGLE_CHOICE:
			return "Multiple choice"
		SurveyQuestion.TYPE_DROPDOWN:
			return "Dropdown"
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return "Checkbox"
		SurveyQuestion.TYPE_BOOLEAN:
			return "Yes/No"
		SurveyQuestion.TYPE_SCALE:
			return "Scale"
		SurveyQuestion.TYPE_NPS:
			return "NPS"
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return "Ranked choice"
		SurveyQuestion.TYPE_MATRIX:
			return "Matrix"
	return "Question"


