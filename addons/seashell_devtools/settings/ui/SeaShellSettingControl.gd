@tool
extends HBoxContainer

signal value_submitted(item_id: String, value: Variant)
signal action_requested(item_id: String)

@export var ControlType: String = ""

var item: Resource
var settings_service: Node
var _value: Variant
var _suppress_signals := false

func _ready() -> void:
	if item != null:
		_build()

func bind_item(setting_item: Resource, service: Node) -> void:
	item = setting_item
	settings_service = service
	if is_inside_tree():
		_build()

func _build() -> void:
	_clear_children()
	if item == null:
		return
	_value = _get_current_value()
	var kind := str(item.get("Kind"))
	var type_name := _resolve_type_name()
	if kind == "Info":
		_add_readonly_value()
		return
	if kind == "Poll":
		_add_poll_placeholder()
		return
	if type_name == "Action":
		_add_action()
		return
	if not bool(item.call("is_editable")):
		_add_readonly_value()
		return
	match type_name:
		"Bool":
			_add_bool()
		"Float":
			_add_slider(false)
		"Integer":
			_add_slider(true)
		"Enum", "Choice":
			_add_dropdown(PackedStringArray())
		"Segmented":
			_add_segmented(PackedStringArray())
		"Keybind":
			_add_single_line("Press keys or type binding")
		"Action":
			_add_action()
		"Text":
			_add_single_line("Value")
		"MultilineText":
			_add_multiline()
		"Color":
			_add_color()
		"Path":
			_add_path_like("Path")
		"Resource":
			_add_path_like("Resource path")
		"Resolution":
			_add_dropdown(PackedStringArray(["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]))
		"QualityMatrix":
			_add_segmented(PackedStringArray(["Low", "Medium", "High", "Ultra"]))
		"Language":
			_add_dropdown(PackedStringArray(["English", "Spanish", "French", "German", "Japanese", "Korean", "Chinese"]))
		"FontScale":
			_add_font_scale()
		"SensitivityCurve":
			_add_single_line("linear, ease-in, ease-out, or curve points")
		"List":
			_add_list_like("Comma-separated values")
		"TagPicker":
			_add_list_like("Comma-separated tags")
		_:
			_add_single_line("Value")

func _resolve_type_name() -> String:
	return ControlType if not ControlType.is_empty() else str(item.get("ValueType"))

func _get_current_value() -> Variant:
	if settings_service != null and settings_service.has_method("get_value"):
		return settings_service.call("get_value", str(item.get("ItemId")))
	return item.get("DefaultValue")

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _add_readonly_value() -> void:
	var label := Label.new()
	label.text = _variant_to_text(_value)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func _add_poll_placeholder() -> void:
	var label := Label.new()
	label.text = "Poll schema"
	label.modulate = Color(0.75, 0.77, 0.8)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(label)

func _add_bool() -> void:
	var checkbox := CheckBox.new()
	checkbox.text = "Enabled"
	checkbox.button_pressed = bool(_value)
	checkbox.toggled.connect(_submit_value)
	add_child(checkbox)

func _add_slider(integer_only: bool) -> void:
	var min_value := float(item.get("MinValue"))
	var max_value := float(item.get("MaxValue"))
	var step := float(item.get("Step"))
	if is_equal_approx(min_value, max_value):
		min_value = 0.0
		max_value = 100.0
	if step <= 0.0:
		step = 1.0 if integer_only else 0.01
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(_value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = float(_value)
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size.x = 88.0
	slider.value_changed.connect(func(new_value: float) -> void:
		if _suppress_signals:
			return
		_suppress_signals = true
		spin.value = new_value
		_suppress_signals = false
		_submit_number(new_value, integer_only)
	)
	spin.value_changed.connect(func(new_value: float) -> void:
		if _suppress_signals:
			return
		_suppress_signals = true
		slider.value = clampf(new_value, min_value, max_value)
		_suppress_signals = false
		_submit_number(new_value, integer_only)
	)
	add_child(slider)
	add_child(spin)

func _add_dropdown(default_options: PackedStringArray) -> void:
	var option_button := OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _resolve_options(default_options)
	if options == null or options.is_empty():
		options = PackedStringArray([_variant_to_text(_value)])
	elif not options.has(str(_value)):
		options.append(str(_value))
	for index in range(options.size()):
		var option_text := str(options[index])
		option_button.add_item(option_text)
		if option_text == str(_value):
			option_button.select(index)
	option_button.item_selected.connect(func(index: int) -> void:
		_submit_value(option_button.get_item_text(index))
	)
	add_child(option_button)

func _add_segmented(default_options: PackedStringArray) -> void:
	var options := _resolve_options(default_options)
	if options == null or options.is_empty():
		_add_dropdown(PackedStringArray())
		return
	for option in options:
		var option_text := str(option)
		var button := Button.new()
		button.text = option_text
		button.toggle_mode = true
		button.button_pressed = option_text == str(_value)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_submit_value(option_text)
			_build()
		)
		add_child(button)

func _add_single_line(placeholder: String) -> void:
	var line_edit := LineEdit.new()
	line_edit.text = _variant_to_text(_value)
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_submitted.connect(func(text: String) -> void:
		_submit_value(text)
	)
	line_edit.focus_exited.connect(func() -> void:
		_submit_value(line_edit.text)
	)
	add_child(line_edit)

func _add_multiline() -> void:
	var text_edit := TextEdit.new()
	text_edit.text = _variant_to_text(_value)
	text_edit.custom_minimum_size.y = 96.0
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.focus_exited.connect(func() -> void:
		_submit_value(text_edit.text)
	)
	add_child(text_edit)

func _add_color() -> void:
	var picker := ColorPickerButton.new()
	picker.color = _value if typeof(_value) == TYPE_COLOR else Color.WHITE
	picker.custom_minimum_size.x = 96.0
	picker.color_changed.connect(func(color: Color) -> void:
		_submit_value(color)
	)
	add_child(picker)

func _add_path_like(placeholder: String) -> void:
	var line_edit := LineEdit.new()
	line_edit.text = _variant_to_text(_value)
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_submitted.connect(func(text: String) -> void:
		_submit_value(text)
	)
	line_edit.focus_exited.connect(func() -> void:
		_submit_value(line_edit.text)
	)
	add_child(line_edit)

func _add_font_scale() -> void:
	var original_min = item.get("MinValue")
	var original_max = item.get("MaxValue")
	var original_step = item.get("Step")
	if is_equal_approx(float(original_min), float(original_max)):
		item.set("MinValue", 0.75)
		item.set("MaxValue", 2.0)
	if float(original_step) <= 0.0 or is_equal_approx(float(original_step), 0.01):
		item.set("Step", 0.05)
	_add_slider(false)
	item.set("MinValue", original_min)
	item.set("MaxValue", original_max)
	item.set("Step", original_step)

func _add_list_like(placeholder: String) -> void:
	var line_edit := LineEdit.new()
	if typeof(_value) == TYPE_PACKED_STRING_ARRAY or typeof(_value) == TYPE_ARRAY:
		line_edit.text = ", ".join(Array(_value))
	else:
		line_edit.text = _variant_to_text(_value)
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_submitted.connect(func(text: String) -> void:
		_submit_value(text)
	)
	line_edit.focus_exited.connect(func() -> void:
		_submit_value(line_edit.text)
	)
	add_child(line_edit)

func _add_action() -> void:
	var button := Button.new()
	button.text = item.display_name() if item != null and item.has_method("display_name") else "Run"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		action_requested.emit(str(item.get("ItemId")))
	)
	add_child(button)

func _submit_number(new_value: float, integer_only: bool) -> void:
	_submit_value(int(round(new_value)) if integer_only else new_value)

func _submit_value(new_value: Variant) -> void:
	value_submitted.emit(str(item.get("ItemId")), new_value)

func _resolve_options(default_options: PackedStringArray) -> PackedStringArray:
	if settings_service != null and settings_service.has_method("resolve_options"):
		var resolved: Variant = settings_service.call("resolve_options", item)
		if typeof(resolved) == TYPE_PACKED_STRING_ARRAY:
			return resolved
		if typeof(resolved) == TYPE_ARRAY:
			return PackedStringArray(resolved)
	var options = item.get("Options")
	if options == null or options.is_empty():
		return default_options
	return PackedStringArray(options)

func _variant_to_text(value: Variant) -> String:
	if typeof(value) == TYPE_COLOR:
		return "#" + (value as Color).to_html(true)
	return str(value)
