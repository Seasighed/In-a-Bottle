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

@export var ItemId := ""
@export_enum("Setting", "Info", "Poll") var Kind := KIND_SETTING
@export_enum("Bool", "Float", "Integer", "Enum", "Choice", "Segmented", "Keybind", "Action", "Text", "MultilineText", "Color", "Path", "Resource", "Resolution", "QualityMatrix", "Language", "FontScale", "SensitivityCurve", "List", "TagPicker") var ValueType := VALUE_TEXT
@export var Title := ""
@export var DisplayName := ""
@export_multiline var Description := ""
@export var GroupPath := ""
@export var Tags := PackedStringArray()
@export var Aliases := PackedStringArray()
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
	return false

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
