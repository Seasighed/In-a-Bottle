@tool
extends Resource
class_name SeaShellSettingsPack

@export var PackId := ""
@export var DisplayName := ""
@export_multiline var Description := ""
@export var DocsRoot := ""
@export var DocsDirectory := "res://Sea Shell Docs/02 Systems/Settings Items"
@export var Items: Array[Resource] = []
@export var Groups := PackedStringArray()
@export var Tags := PackedStringArray()
@export var DefinitionModifiedUnix := 0

func get_items() -> Array:
	var result: Array = []
	for item in Items:
		if item is Resource and item.has_method("display_name"):
			result.append(item)
	return result

func get_docs_directory() -> String:
	var docs_root := DocsRoot.strip_edges()
	return docs_root if not docs_root.is_empty() else DocsDirectory

func get_item(item_id: String) -> Resource:
	for item in get_items():
		if str(item.get("ItemId")) == item_id:
			return item
	return null

func get_groups() -> PackedStringArray:
	var groups := Groups.duplicate()
	for item in get_items():
		var group := String(item.get("GroupPath")).strip_edges()
		if not group.is_empty() and not groups.has(group):
			groups.append(group)
	groups.sort()
	return groups

func get_all_tags() -> PackedStringArray:
	var tags := Tags.duplicate()
	for item in get_items():
		for tag in item.get("Tags"):
			var typed_tag := String(tag).strip_edges()
			if not typed_tag.is_empty() and not tags.has(typed_tag):
				tags.append(typed_tag)
	tags.sort()
	return tags