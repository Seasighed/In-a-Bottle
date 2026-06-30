@tool
extends Resource
class_name SeaShellSettingItem

const KIND_SETTING := "Setting"
const KIND_INFO := "Info"
const KIND_POLL := "Poll"

const APPLY_INSTANT := "Instant"
const APPLY_STAGED := "StagedApply"
const APPLY_RESTART := "RestartRequired"

const VALUE_BOOL := "Bool"
const VALUE_FLOAT := "Float"
const VALUE_INTEGER := "Integer"
const VALUE_ENUM := "Enum"
const VALUE_CHOICE := "Choice"
const VALUE_SEGMENTED := "Segmented"
const VALUE_KEYBIND := "Keybind"
const VALUE_ACTION := "Action"
const VALUE_TEXT := "Text"
const VALUE_MULTILINE_TEXT := "MultilineText"
const VALUE_COLOR := "Color"
const VALUE_PATH := "Path"
const VALUE_RESOURCE := "Resource"
const VALUE_RESOLUTION := "Resolution"
const VALUE_QUALITY_MATRIX := "QualityMatrix"
const VALUE_LANGUAGE := "Language"
const VALUE_FONT_SCALE := "FontScale"
const VALUE_SENSITIVITY_CURVE := "SensitivityCurve"
const VALUE_LIST := "List"
const VALUE_TAG_PICKER := "TagPicker"

const INPUT_DEVICE_CURSOR := "Cursor"
const INPUT_DEVICE_KEYBOARD := "Keyboard"
const INPUT_DEVICE_GAMEPAD := "Gamepad"
const INPUT_DEVICE_TOUCH := "Touch"
const INPUT_DEVICE_NONE := "None"
const INPUT_DEVICE_MIXED := "Mixed"
const INPUT_DEVICE_ORDER := [
	INPUT_DEVICE_CURSOR,
	INPUT_DEVICE_KEYBOARD,
	INPUT_DEVICE_GAMEPAD,
	INPUT_DEVICE_TOUCH,
	INPUT_DEVICE_MIXED,
	INPUT_DEVICE_NONE,
]

@export var ItemId := ""
@export_enum("Setting", "Info", "Poll") var Kind := KIND_SETTING
@export_enum("Bool", "Float", "Integer", "Enum", "Choice", "Segmented", "Keybind", "Action", "Text", "MultilineText", "Color", "Path", "Resource", "Resolution", "QualityMatrix", "Language", "FontScale", "SensitivityCurve", "List", "TagPicker") var ValueType := VALUE_TEXT
@export var Title := ""
@export var DisplayName := ""
@export_multiline var Description := ""
@export var GroupPath := ""
@export var Tags := PackedStringArray()
@export var Aliases := PackedStringArray()
@export var PrimaryInputDevice := ""
@export var SupportedInputDevices := PackedStringArray()
@export_multiline var InputDeviceNote := ""
@export var DefaultValue: Variant
@export var Options := PackedStringArray()
@export var MinValue := 0.0
@export var MaxValue := 1.0
@export var Step := 0.01
@export_enum("Instant", "StagedApply", "RestartRequired") var ApplyPolicy := APPLY_INSTANT
@export var DocsPath := ""
@export var DefinitionModifiedUnix := 0
@export var IsHidden := false
@export var IsLocked := false
@export_multiline var LockReason := ""
@export_multiline var UnlockHint := ""
@export var ColorHint := Color.WHITE
@export var IconName := ""
@export var HookIds := PackedStringArray()
@export var OptionProviderId := ""
@export var OptionProviderArgs: Dictionary = {}
@export var RuntimeApplyId := ""
@export var RuntimeApplyArgs: Dictionary = {}

func is_editable() -> bool:
	return Kind == KIND_SETTING and not IsLocked and not IsHidden and ValueType != VALUE_ACTION

func display_name() -> String:
	var trimmed := DisplayName.strip_edges()
	if not trimmed.is_empty():
		return trimmed
	trimmed = Title.strip_edges()
	return trimmed if not trimmed.is_empty() else ItemId.get_file()

func get_default_value() -> Variant:
	return DefaultValue

func get_definition_modified_unix() -> int:
	return DefinitionModifiedUnix if DefinitionModifiedUnix > 0 else Time.get_unix_time_from_system()

func matches_search(query: String) -> bool:
	var normalized := query.strip_edges().to_lower()
	if normalized.is_empty():
		return true
	var normalized_device := normalize_input_device(query)
	if not normalized_device.is_empty():
		if get_primary_input_device() == normalized_device:
			return true
		if get_supported_input_devices().has(normalized_device):
			return true
	if ItemId.to_lower().contains(normalized):
		return true
	if display_name().to_lower().contains(normalized):
		return true
	if Description.to_lower().contains(normalized):
		return true
	for tag in Tags:
		if String(tag).to_lower().contains(normalized):
			return true
	for alias in Aliases:
		if String(alias).to_lower().contains(normalized):
			return true
	if get_primary_input_device().to_lower().contains(normalized):
		return true
	for device in get_supported_input_devices():
		if String(device).to_lower().contains(normalized):
			return true
	if InputDeviceNote.to_lower().contains(normalized):
		return true
	return false

func get_primary_input_device() -> String:
	var explicit := normalize_input_device(PrimaryInputDevice)
	if not explicit.is_empty():
		return explicit
	return _infer_primary_input_device()

func get_supported_input_devices() -> PackedStringArray:
	var explicit := _normalize_input_devices(SupportedInputDevices)
	if not explicit.is_empty():
		var primary := get_primary_input_device()
		if not primary.is_empty() and not explicit.has(primary):
			explicit.insert(0, primary)
		return explicit
	return _infer_supported_input_devices()

func normalize_input_device(device: String) -> String:
	var normalized := device.strip_edges()
	if normalized.is_empty():
		return ""
	match normalized.to_lower():
		"auto", "infer", "inferred", "default":
			return ""
		"cursor", "pointer", "mouse", "trackpad", "touchpad":
			return INPUT_DEVICE_CURSOR
		"keyboard", "key", "keys", "text":
			return INPUT_DEVICE_KEYBOARD
		"gamepad", "controller", "joypad", "joystick":
			return INPUT_DEVICE_GAMEPAD
		"touch", "touchscreen", "screen":
			return INPUT_DEVICE_TOUCH
		"none", "readonly", "read-only", "no input", "no_input":
			return INPUT_DEVICE_NONE
		"mixed", "multi", "multiple":
			return INPUT_DEVICE_MIXED
		_:
			for known in INPUT_DEVICE_ORDER:
				if normalized.nocasecmp_to(String(known)) == 0:
					return String(known)
	return ""

func _normalize_input_devices(devices: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	var raw_values: Array = []
	match typeof(devices):
		TYPE_PACKED_STRING_ARRAY:
			raw_values = Array(devices)
		TYPE_ARRAY:
			raw_values = devices
		TYPE_STRING:
			raw_values = String(devices).split(",", false)
		_:
			raw_values = []
	for raw_device in raw_values:
		var device := normalize_input_device(String(raw_device))
		if not device.is_empty() and not result.has(device):
			result.append(device)
	return result

func _infer_primary_input_device() -> String:
	match Kind:
		KIND_INFO, KIND_POLL:
			return INPUT_DEVICE_NONE
	match ValueType:
		VALUE_KEYBIND, VALUE_TEXT, VALUE_MULTILINE_TEXT, VALUE_PATH, VALUE_RESOURCE, VALUE_LIST, VALUE_TAG_PICKER, VALUE_SENSITIVITY_CURVE:
			return INPUT_DEVICE_KEYBOARD
		VALUE_BOOL, VALUE_FLOAT, VALUE_INTEGER, VALUE_ENUM, VALUE_CHOICE, VALUE_SEGMENTED, VALUE_ACTION, VALUE_COLOR, VALUE_RESOLUTION, VALUE_QUALITY_MATRIX, VALUE_LANGUAGE, VALUE_FONT_SCALE:
			return INPUT_DEVICE_CURSOR
		_:
			return INPUT_DEVICE_MIXED

func _infer_supported_input_devices() -> PackedStringArray:
	match Kind:
		KIND_INFO, KIND_POLL:
			return PackedStringArray([INPUT_DEVICE_NONE])
	match ValueType:
		VALUE_KEYBIND:
			return PackedStringArray([INPUT_DEVICE_KEYBOARD, INPUT_DEVICE_GAMEPAD])
		VALUE_TEXT, VALUE_MULTILINE_TEXT, VALUE_PATH, VALUE_RESOURCE, VALUE_LIST, VALUE_TAG_PICKER, VALUE_SENSITIVITY_CURVE:
			return PackedStringArray([INPUT_DEVICE_KEYBOARD])
		VALUE_FLOAT, VALUE_INTEGER, VALUE_FONT_SCALE:
			return PackedStringArray([INPUT_DEVICE_CURSOR, INPUT_DEVICE_KEYBOARD, INPUT_DEVICE_TOUCH])
		VALUE_BOOL, VALUE_ENUM, VALUE_CHOICE, VALUE_SEGMENTED, VALUE_ACTION, VALUE_RESOLUTION, VALUE_QUALITY_MATRIX, VALUE_LANGUAGE:
			return PackedStringArray([INPUT_DEVICE_CURSOR, INPUT_DEVICE_KEYBOARD, INPUT_DEVICE_GAMEPAD, INPUT_DEVICE_TOUCH])
		VALUE_COLOR:
			return PackedStringArray([INPUT_DEVICE_CURSOR, INPUT_DEVICE_TOUCH])
		_:
			return PackedStringArray([INPUT_DEVICE_MIXED])

func to_dictionary(include_runtime_fields := false) -> Dictionary:
	var data := {
		"id": ItemId,
		"kind": Kind,
		"value_type": ValueType,
		"display_name": DisplayName,
		"description": Description,
		"group_path": GroupPath,
		"tags": Array(Tags),
		"aliases": Array(Aliases),
		"primary_input_device": get_primary_input_device(),
		"supported_input_devices": Array(get_supported_input_devices()),
		"input_device_note": InputDeviceNote,
		"default_value": _encode_value(DefaultValue),
		"options": Array(Options),
		"min_value": MinValue,
		"max_value": MaxValue,
		"step": Step,
		"apply_policy": ApplyPolicy,
		"docs_path": DocsPath,
		"definition_modified_unix": DefinitionModifiedUnix,
		"is_hidden": IsHidden,
		"is_locked": IsLocked,
		"lock_reason": LockReason,
		"unlock_hint": UnlockHint,
		"color_hint": ColorHint.to_html(true),
		"icon_name": IconName,
		"hook_ids": Array(HookIds),
		"option_provider_id": OptionProviderId,
		"option_provider_args": OptionProviderArgs.duplicate(true),
		"runtime_apply_id": RuntimeApplyId,
		"runtime_apply_args": RuntimeApplyArgs.duplicate(true),
	}
	if include_runtime_fields:
		data["editable"] = is_editable()
	return data

func apply_dictionary(data: Dictionary) -> void:
	ItemId = String(data.get("id", ItemId))
	Kind = String(data.get("kind", Kind))
	ValueType = String(data.get("value_type", ValueType))
	DisplayName = String(data.get("display_name", DisplayName))
	Description = String(data.get("description", Description))
	GroupPath = String(data.get("group_path", GroupPath))
	Tags = PackedStringArray(data.get("tags", Array(Tags)))
	Aliases = PackedStringArray(data.get("aliases", Array(Aliases)))
	PrimaryInputDevice = normalize_input_device(String(data.get("primary_input_device", data.get("input_device", PrimaryInputDevice))))
	SupportedInputDevices = _normalize_input_devices(data.get("supported_input_devices", data.get("input_devices", Array(SupportedInputDevices))))
	InputDeviceNote = String(data.get("input_device_note", InputDeviceNote))
	DefaultValue = _decode_value(data.get("default_value", DefaultValue), ValueType)
	Options = PackedStringArray(data.get("options", Array(Options)))
	MinValue = float(data.get("min_value", MinValue))
	MaxValue = float(data.get("max_value", MaxValue))
	Step = float(data.get("step", Step))
	ApplyPolicy = String(data.get("apply_policy", ApplyPolicy))
	DocsPath = String(data.get("docs_path", DocsPath))
	DefinitionModifiedUnix = int(data.get("definition_modified_unix", DefinitionModifiedUnix))
	IsHidden = bool(data.get("is_hidden", IsHidden))
	IsLocked = bool(data.get("is_locked", IsLocked))
	LockReason = String(data.get("lock_reason", LockReason))
	UnlockHint = String(data.get("unlock_hint", UnlockHint))
	if data.has("color_hint"):
		ColorHint = Color.html(String(data.get("color_hint", ColorHint.to_html(true))))
	IconName = String(data.get("icon_name", IconName))
	HookIds = PackedStringArray(data.get("hook_ids", Array(HookIds)))
	OptionProviderId = String(data.get("option_provider_id", OptionProviderId))
	OptionProviderArgs = Dictionary(data.get("option_provider_args", OptionProviderArgs)).duplicate(true)
	RuntimeApplyId = String(data.get("runtime_apply_id", RuntimeApplyId))
	RuntimeApplyArgs = Dictionary(data.get("runtime_apply_args", RuntimeApplyArgs)).duplicate(true)

func _encode_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_COLOR:
		return {"__type": "Color", "value": (value as Color).to_html(true)}
	return value

func _decode_value(value: Variant, value_type: String) -> Variant:
	if typeof(value) == TYPE_DICTIONARY and String(value.get("__type", "")) == "Color":
		return Color.html(String(value.get("value", "ffffffff")))
	if value_type == VALUE_COLOR and typeof(value) == TYPE_STRING:
		return Color.html(String(value))
	return value
