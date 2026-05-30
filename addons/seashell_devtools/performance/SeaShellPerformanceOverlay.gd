extends CanvasLayer
class_name SeaShellPerformanceOverlay

@export var service_path: NodePath = NodePath("..")
@export var panel_size := Vector2(560, 620)
@export_range(0.1, 2.0, 0.05) var refresh_interval := 0.25

var _service: Node
var _root_control: Control
var _perf_button: Button
var _panel: PanelContainer
var _tabs: TabContainer
var _headline_label: Label
var _scene_label: Label
var _spans_label: Label
var _catalog_label: Label
var _enabled_toggle: CheckButton
var _auto_capture_toggle: CheckButton
var _mode_select: OptionButton
var _threshold_spin: SpinBox
var _pre_roll_spin: SpinBox
var _post_roll_spin: SpinBox
var _buffer_spin: SpinBox
var _capture_status_label: Label
var _capture_list: ItemList
var _capture_detail_label: Label
var _session_label: Label
var _prompt_label: Label
var _refresh_elapsed := 0.0
var _last_monitor_modification_time := -1

func _ready() -> void:
	layer = 4095
	_build_ui()
	_resolve_service()
	_set_expanded(false)
	set_process(true)

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < refresh_interval:
		return
	_refresh_elapsed = 0.0
	_refresh()

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "PerformanceOverlayRoot"
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)

	_perf_button = Button.new()
	_perf_button.name = "PerfButton"
	_perf_button.text = "Perf"
	_perf_button.tooltip_text = "Open the Sea Shell performance overlay"
	_perf_button.custom_minimum_size = Vector2(96, 34)
	_perf_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_perf_button.anchor_left = 1.0
	_perf_button.anchor_right = 1.0
	_perf_button.offset_left = -108.0
	_perf_button.offset_top = 12.0
	_perf_button.offset_right = -12.0
	_perf_button.offset_bottom = 46.0
	_perf_button.pressed.connect(func() -> void:
		_set_expanded(true)
	)
	_root_control.add_child(_perf_button)

	_panel = PanelContainer.new()
	_panel.name = "PerformancePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -panel_size.x - 12.0
	_panel.offset_top = 52.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 52.0 + panel_size.y
	_root_control.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	var toolbar := HBoxContainer.new()
	content.add_child(toolbar)

	var title := Label.new()
	title.text = "Performance"
	title.theme_type_variation = "HeaderSmall"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh)
	toolbar.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func() -> void:
		_set_expanded(false)
	)
	toolbar.add_child(close_button)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_tabs)

	_build_live_tab()
	_build_capture_tab()
	_build_spikes_tab()
	_build_session_tab()

func _build_live_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Live"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(tab)

	_headline_label = _make_wrap_label()
	tab.add_child(_headline_label)

	_scene_label = _make_wrap_label()
	tab.add_child(_scene_label)

	_spans_label = _make_wrap_label()
	_spans_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_spans_label)

	_catalog_label = _make_wrap_label()
	_catalog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_catalog_label)

func _build_capture_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Capture"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(tab)

	_enabled_toggle = CheckButton.new()
	_enabled_toggle.text = "Sampling Enabled"
	_enabled_toggle.toggled.connect(func(enabled: bool) -> void:
		_set_setting("SeaShell.Performance.Enabled", enabled)
	)
	tab.add_child(_enabled_toggle)

	_auto_capture_toggle = CheckButton.new()
	_auto_capture_toggle.text = "Auto Spike Capture"
	_auto_capture_toggle.toggled.connect(func(enabled: bool) -> void:
		_set_setting("SeaShell.Performance.AutoCaptureEnabled", enabled)
	)
	tab.add_child(_auto_capture_toggle)

	var mode_row := HBoxContainer.new()
	tab.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "Mode"
	mode_label.custom_minimum_size = Vector2(120, 0)
	mode_row.add_child(mode_label)
	_mode_select = OptionButton.new()
	_mode_select.add_item("HybridSpikeBuffer")
	_mode_select.add_item("FullSession")
	_mode_select.item_selected.connect(func(index: int) -> void:
		_set_setting("SeaShell.Performance.CaptureMode", _mode_select.get_item_text(index))
	)
	mode_row.add_child(_mode_select)

	_threshold_spin = _add_numeric_row(tab, "Spike Threshold (ms)", 0.0, 500.0, 1.0, func(value: float) -> void:
		_set_setting("SeaShell.Performance.SpikeThresholdMs", value)
	)
	_pre_roll_spin = _add_numeric_row(tab, "Pre-Roll (s)", 0.0, 30.0, 0.25, func(value: float) -> void:
		_set_setting("SeaShell.Performance.PreRollSeconds", value)
	)
	_post_roll_spin = _add_numeric_row(tab, "Post-Roll (s)", 0.0, 30.0, 0.25, func(value: float) -> void:
		_set_setting("SeaShell.Performance.PostRollSeconds", value)
	)
	_buffer_spin = _add_numeric_row(tab, "Rolling Buffer (s)", 1.0, 120.0, 1.0, func(value: float) -> void:
		_set_setting("SeaShell.Performance.RollingBufferSeconds", int(round(value)))
	)

	var actions := HBoxContainer.new()
	tab.add_child(actions)

	var mark_button := Button.new()
	mark_button.text = "Mark Capture"
	mark_button.pressed.connect(func() -> void:
		_call_service("mark_capture", ["Overlay Mark", {}])
		_capture_status_label.text = "Queued manual capture."
	)
	actions.add_child(mark_button)

	var screenshot_button := Button.new()
	screenshot_button.text = "Mark Screenshot"
	screenshot_button.pressed.connect(func() -> void:
		_call_service("mark_capture", ["Overlay Screenshot", {"include_screenshot": true}])
		_capture_status_label.text = "Queued capture with screenshot."
	)
	actions.add_child(screenshot_button)

	var save_button := Button.new()
	save_button.text = "Save Session Snapshot"
	save_button.pressed.connect(func() -> void:
		var result: Dictionary = _call_service("persist_session_snapshot")
		_capture_status_label.text = String(result.get("message", result.get("reason", "Saved current performance session snapshot.")))
	)
	actions.add_child(save_button)

	_capture_status_label = _make_wrap_label()
	tab.add_child(_capture_status_label)

func _build_spikes_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Spikes"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(tab)

	_capture_list = ItemList.new()
	_capture_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capture_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_capture_list.item_selected.connect(_on_capture_selected)
	tab.add_child(_capture_list)

	_capture_detail_label = _make_wrap_label()
	tab.add_child(_capture_detail_label)

func _build_session_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Session"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(tab)

	_session_label = _make_wrap_label()
	_session_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_session_label)

	var prompt_button := Button.new()
	prompt_button.text = "Export Codex Prompt"
	prompt_button.pressed.connect(func() -> void:
		var result: Dictionary = _call_service("export_session_prompt")
		_prompt_label.text = String(result.get("prompt_markdown", "No prompt was generated."))
	)
	tab.add_child(prompt_button)

	_prompt_label = _make_wrap_label()
	_prompt_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_prompt_label)

func _make_wrap_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _add_numeric_row(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, on_changed: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_changed)
	row.add_child(spin)
	return spin

func _set_expanded(expanded: bool) -> void:
	if _panel == null or _perf_button == null:
		return
	_panel.visible = expanded
	_perf_button.visible = not expanded
	if expanded:
		_refresh()

func _refresh() -> void:
	_resolve_service()
	if _service == null:
		_headline_label.text = "SeaShellPerformance is unavailable."
		return
	var frame: Dictionary = _call_service("get_last_frame_snapshot")
	var captures: Array = _call_service("get_capture_records")
	var session: Dictionary = _call_service("get_latest_session_snapshot")
	var active_spans: Array = _call_service("get_active_spans_snapshot")
	_refresh_live_tab(frame, active_spans)
	_refresh_capture_tab()
	_refresh_spikes_tab(captures)
	_refresh_session_tab(session)
	_refresh_custom_monitor_catalog()

func _refresh_live_tab(frame: Dictionary, active_spans: Array) -> void:
	if frame.is_empty():
		_headline_label.text = "Waiting for frame samples."
		_scene_label.text = ""
		_spans_label.text = ""
		return
	_headline_label.text = "Frame %d  |  %.2f ms  |  Physics %.2f ms  |  Nav %.2f ms  |  FPS %.1f" % [
		int(frame.get("frame_index", 0)),
		float(frame.get("frame_time_ms", 0.0)),
		float(frame.get("physics_time_ms", 0.0)),
		float(frame.get("navigation_time_ms", 0.0)),
		float(frame.get("fps_estimate", 0.0)),
	]
	var layer_name := String(Dictionary(frame.get("layer", {})).get("name", ""))
	_scene_label.text = "Scene: %s\nHovered: %s\nLayer: %s\nRecent Feedback: %s" % [
		String(frame.get("scene_file_path", "")),
		String(frame.get("hovered_control_path", "")),
		layer_name,
		", ".join(PackedStringArray(Array(frame.get("recent_feedback_event_ids", [])))),
	]
	var span_lines := PackedStringArray(["Active Spans:"])
	if active_spans.is_empty():
		span_lines.append("- None")
	else:
		for span in active_spans.slice(0, min(5, active_spans.size())):
			var record: Dictionary = Dictionary(span)
			span_lines.append("- %s: %.2f ms" % [String(record.get("span_id", "")), float(record.get("duration_ms", 0.0))])
	var metrics: Dictionary = Dictionary(frame.get("custom_metrics", {}))
	span_lines.append("")
	span_lines.append("Custom Metrics:")
	if metrics.is_empty():
		span_lines.append("- None")
	else:
		for metric_id in metrics.keys():
			span_lines.append("- %s: %s" % [String(metric_id), String(metrics.get(metric_id))])
	_spans_label.text = "\n".join(span_lines)

func _refresh_capture_tab() -> void:
	_enabled_toggle.button_pressed = bool(_setting_value("SeaShell.Performance.Enabled", true))
	_auto_capture_toggle.button_pressed = bool(_setting_value("SeaShell.Performance.AutoCaptureEnabled", true))
	var mode := String(_setting_value("SeaShell.Performance.CaptureMode", "HybridSpikeBuffer"))
	for index in range(_mode_select.item_count):
		if _mode_select.get_item_text(index) == mode:
			_mode_select.select(index)
			break
	_threshold_spin.value = float(_setting_value("SeaShell.Performance.SpikeThresholdMs", 25.0))
	_pre_roll_spin.value = float(_setting_value("SeaShell.Performance.PreRollSeconds", 4.0))
	_post_roll_spin.value = float(_setting_value("SeaShell.Performance.PostRollSeconds", 2.0))
	_buffer_spin.value = float(_setting_value("SeaShell.Performance.RollingBufferSeconds", 20.0))

func _refresh_spikes_tab(captures: Array) -> void:
	_capture_list.clear()
	for capture in captures:
		var record: Dictionary = Dictionary(capture)
		_capture_list.add_item("%s | %.2f ms | %s" % [
			String(record.get("label", record.get("capture_id", "Capture"))),
			float(record.get("max_frame_time_ms", 0.0)),
			String(record.get("scene_file_path", "")),
		])
	if captures.is_empty():
		_capture_detail_label.text = "No captures have been saved yet."
		return
	if _capture_list.item_count > 0 and _capture_list.is_anything_selected():
		_on_capture_selected(_capture_list.get_selected_items()[0])
	elif _capture_list.item_count > 0:
		_capture_list.select(_capture_list.item_count - 1)
		_on_capture_selected(_capture_list.item_count - 1)

func _refresh_session_tab(session: Dictionary) -> void:
	if session.is_empty():
		_session_label.text = "No session has been created yet."
		return
	_session_label.text = "Session Root: %s\nManifest: %s\nFrames: %s\nSchema: %s\nSummary: %s" % [
		String(session.get("session_root", "")),
		String(session.get("manifest_absolute_path", "")),
		String(session.get("frames_absolute_path", "")),
		String(session.get("metrics_schema_absolute_path", "")),
		String(session.get("summary_absolute_path", "")),
	]

func _refresh_custom_monitor_catalog() -> void:
	var modification_time := int(Performance.get_monitor_modification_time())
	if modification_time == _last_monitor_modification_time:
		return
	_last_monitor_modification_time = modification_time
	var names := Performance.get_custom_monitor_names()
	var lines := PackedStringArray(["Custom Monitor Catalog:"])
	if names.is_empty():
		lines.append("- No custom monitors registered.")
	else:
		for monitor_name in names:
			lines.append("- %s" % String(monitor_name))
	_catalog_label.text = "\n".join(lines)

func _on_capture_selected(index: int) -> void:
	var captures: Array = _call_service("get_capture_records")
	if index < 0 or index >= captures.size():
		return
	var capture: Dictionary = Dictionary(captures[index]).duplicate(true)
	_capture_detail_label.text = "Capture: %s\nReason: %s\nFrames: %d\nMax: %.2f ms\nScene: %s\nScreenshot: %s" % [
		String(capture.get("capture_id", "")),
		String(capture.get("reason", "")),
		int(capture.get("frame_count", 0)),
		float(capture.get("max_frame_time_ms", 0.0)),
		String(capture.get("scene_file_path", "")),
		String(capture.get("screenshot_absolute_path", "")),
	]

func _resolve_service() -> void:
	if _service != null and is_instance_valid(_service):
		return
	_service = get_node_or_null(service_path)
	if _service == null:
		_service = get_parent()

func _call_service(method_name: String, arguments: Array = []) -> Variant:
	_resolve_service()
	if _service == null or not _service.has_method(method_name):
		return {} if method_name.begins_with("get_") or method_name.ends_with("_snapshot") else null
	return _service.callv(method_name, arguments)

func _setting_value(item_id: String, fallback: Variant) -> Variant:
	var result = _call_service("get_setting_value", [item_id, fallback])
	return fallback if result == null else result

func _set_setting(item_id: String, value: Variant) -> void:
	_call_service("set_setting_value", [item_id, value])
