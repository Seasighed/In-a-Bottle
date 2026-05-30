@tool
extends RefCounted
class_name SeaShellFeedbackInventoryCompat

const ITEM_USE_FLASH_DURATION := 0.22

static func apply_slot_input_passthrough(root_control: Control) -> int:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("apply_input_passthrough"):
		return 0
	return int(feedback.call("apply_input_passthrough", root_control))

static func play_item_use_success(slot: Control, sfx_profile := "generic", payload: Dictionary = {}) -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("emit_event"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable.", "duration": 0.0, "protected_time": 0.0}
	var event_payload := payload.duplicate(true)
	event_payload["sfx_profile"] = _normalize_sfx_profile(sfx_profile)
	return feedback.call("emit_event", "Inventory.ItemUse.Success", slot, event_payload, {
		"duration": ITEM_USE_FLASH_DURATION,
		"protected_time": ITEM_USE_FLASH_DURATION,
	})

static func play_use_flash(slot: Control, duration: float = ITEM_USE_FLASH_DURATION) -> Dictionary:
	var feedback := _feedback()
	if feedback == null or not feedback.has_method("flash_control"):
		return {"ok": false, "error": "SeaShellFeedback is unavailable."}
	return feedback.call("flash_control", slot, duration)

static func resolve_item_use_sfx_profile(item_definition: Dictionary) -> String:
	var explicit := String(item_definition.get("sfx_profile", "")).strip_edges().to_lower()
	if _is_known_profile(explicit):
		return explicit
	var item_symbol := String(item_definition.get("symbol", item_definition.get("item_id", ""))).strip_edges().to_upper()
	var category := String(item_definition.get("category", item_definition.get("kind", ""))).strip_edges().to_lower()
	var tags := PackedStringArray()
	for tag in item_definition.get("tags", []):
		tags.append(String(tag).strip_edges().to_lower())
	if _any_token_matches(item_symbol, category, tags, ["POTION", "HEAL", "REVIVE", "RECOVERY", "HP"]):
		return "recovery"
	if _any_token_matches(item_symbol, category, tags, ["STATUS", "ANTIDOTE", "PARALY", "AWAKEN", "BURN", "ICE", "CURE"]):
		return "status"
	if _any_token_matches(item_symbol, category, tags, ["ETHER", "ELIXIR", "PP"]):
		return "pp"
	if _any_token_matches(item_symbol, category, tags, ["VITAMIN", "BOOST", "RARE_CANDY", "EV_BERRY", "PROTEIN", "IRON", "CALCIUM"]):
		return "boost"
	if not String(item_definition.get("tm_hm_move_symbol", "")).strip_edges().is_empty():
		return "special"
	if _any_token_matches(item_symbol, category, tags, ["STONE", "TM", "HM", "SPECIAL"]):
		return "special"
	return "generic"

static func play_success_for_item(slot: Control, item_definition: Dictionary, payload: Dictionary = {}) -> Dictionary:
	return play_item_use_success(slot, resolve_item_use_sfx_profile(item_definition), payload)

static func _normalize_sfx_profile(raw: Variant) -> String:
	var profile := String(raw).strip_edges().to_lower()
	return profile if _is_known_profile(profile) else "generic"

static func _is_known_profile(profile: String) -> bool:
	return ["generic", "recovery", "status", "pp", "boost", "special"].has(profile)

static func _any_token_matches(item_symbol: String, category: String, tags: PackedStringArray, needles: Array) -> bool:
	var haystack := "%s %s %s" % [item_symbol.to_upper(), category.to_upper(), " ".join(Array(tags)).to_upper()]
	for needle in needles:
		if haystack.contains(String(needle).to_upper()):
			return true
	return false

static func _feedback() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SeaShellFeedback")
