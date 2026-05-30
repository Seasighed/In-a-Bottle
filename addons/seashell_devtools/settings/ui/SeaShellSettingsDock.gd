@tool
extends EditorDock

const SettingsPanelScene := preload("res://addons/seashell_devtools/settings/ui/SeaShellSettingsPanel.tscn")

var _panel: Control

func _ready() -> void:
	name = "Sea Shell Settings"
	_build()

func open_dock() -> void:
	visible = true
	if _panel != null and _panel.has_method("refresh"):
		_panel.call("refresh")

func refresh() -> void:
	if _panel != null and _panel.has_method("refresh"):
		_panel.call("refresh")

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_panel = SettingsPanelScene.instantiate()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panel)