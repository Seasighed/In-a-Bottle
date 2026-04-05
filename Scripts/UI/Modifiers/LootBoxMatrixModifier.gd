class_name LootBoxMatrixModifier
extends "res://Scripts/UI/SurveyQuestionModifier.gd"

const SURVEY_UI_FEEDBACK = preload("res://Scripts/UI/SurveyUiFeedback.gd")
const DEFAULT_FATIGUE_REROLL_THRESHOLD := 5
const DEFAULT_SPAM_THRESHOLD := 4
const DEFAULT_SPAM_WINDOW_SECONDS := 0.9
const DEFAULT_ACCEPT_HINT_TEXT := "Tap to accept"

var _rng := RandomNumberGenerator.new()
var _pending_by_row: Dictionary = {}
var _spin_timestamps_by_row: Dictionary = {}
var _reroll_count := 0
var _fatigue_emitted := false

func _on_attached() -> void:
	_rng.randomize()

func _on_detached() -> void:
	var matrix_view = _matrix_view()
	if matrix_view != null:
		matrix_view.modifier_clear_all_pending_matrix_values()
	_pending_by_row.clear()
	_spin_timestamps_by_row.clear()

func prefers_layout_hint(hint: StringName) -> bool:
	return hint == &"matrix_cycle_selector"

func intercept_action(action_name: StringName, context: Dictionary = {}) -> Dictionary:
	var matrix_view = _matrix_view()
	if matrix_view == null:
		return {}
	match action_name:
		&"matrix_layout_refreshed":
			for row_name_variant in _pending_by_row.keys():
				var row_name: String = str(row_name_variant)
				matrix_view.modifier_show_pending_matrix_value(row_name, str(_pending_by_row.get(row_name_variant, "")), _accept_hint_text(), false)
			return {"handled": false}
		&"matrix_cycle":
			var row_name: String = str(context.get("row_name", "")).strip_edges()
			if row_name.is_empty():
				return {}
			if _register_spin_and_detect_spam(row_name):
				_pending_by_row.erase(row_name)
				matrix_view.modifier_clear_pending_matrix_value(row_name)
				_record_possible_fatigue(2)
				return {"handled": true}
			var option: String = _random_option_for_row(row_name, matrix_view.modifier_matrix_options())
			if option.is_empty():
				return {}
			if _pending_by_row.has(row_name):
				_record_possible_fatigue(1)
			_pending_by_row[row_name] = option
			matrix_view.modifier_show_pending_matrix_value(row_name, option, _accept_hint_text(), true)
			SURVEY_UI_FEEDBACK.play_gamble_spin_tick(_rng.randf())
			return {"handled": true}
		&"matrix_value_tap":
			var row_name: String = str(context.get("row_name", "")).strip_edges()
			if row_name.is_empty() or not _pending_by_row.has(row_name):
				return {}
			var option: String = str(_pending_by_row.get(row_name, "")).strip_edges()
			if option.is_empty():
				return {"handled": true}
			_pending_by_row.erase(row_name)
			_spin_timestamps_by_row.erase(row_name)
			_reroll_count = max(0, _reroll_count - 1)
			matrix_view.modifier_commit_matrix_value(row_name, option)
			return {"handled": true}
	return {}

func on_answer_emitted(_value: Variant) -> void:
	if _pending_by_row.is_empty():
		return
	for row_name_variant in _pending_by_row.keys():
		var row_name: String = str(row_name_variant)
		if not str(_pending_by_row.get(row_name_variant, "")).is_empty():
			continue
		_pending_by_row.erase(row_name_variant)
		var matrix_view = _matrix_view()
		if matrix_view != null:
			matrix_view.modifier_clear_pending_matrix_value(row_name)

func _matrix_view():
	return host

func _register_spin_and_detect_spam(row_name: String) -> bool:
	var now: float = Time.get_unix_time_from_system()
	var timestamps: Array = _spin_timestamps_by_row.get(row_name, []) as Array
	var filtered: Array[float] = []
	for value in timestamps:
		var stamp: float = float(value)
		if now - stamp <= _spam_window_seconds():
			filtered.append(stamp)
	filtered.append(now)
	_spin_timestamps_by_row[row_name] = filtered
	return filtered.size() >= _spam_threshold()

func _random_option_for_row(row_name: String, options: PackedStringArray) -> String:
	if options.is_empty():
		return ""
	var excluded: PackedStringArray = PackedStringArray()
	var current_value: String = str(_pending_by_row.get(row_name, _matrix_view().modifier_current_matrix_value(row_name))).strip_edges()
	if not current_value.is_empty():
		excluded.append(current_value)
	if options.size() <= excluded.size():
		return options[_rng.randi_range(0, options.size() - 1)]
	var candidates: Array[String] = []
	for option in options:
		if not excluded.has(option):
			candidates.append(option)
	if candidates.is_empty():
		return options[_rng.randi_range(0, options.size() - 1)]
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _record_possible_fatigue(amount: int) -> void:
	if _fatigue_emitted:
		return
	_reroll_count += max(1, amount)
	if _reroll_count < _fatigue_reroll_threshold():
		return
	_fatigue_emitted = true
	var matrix_view = _matrix_view()
	if matrix_view != null:
		matrix_view.modifier_clear_all_pending_matrix_values()
	_request_fatigue("Question modifiers were paused for this run. You can turn them back on from the toast if you want the chaos again.")

func _accept_hint_text() -> String:
	var hint_text: String = str(question.modifier_settings.get("accept_hint_text", question.modifier_settings.get("prompt", DEFAULT_ACCEPT_HINT_TEXT))).strip_edges()
	return hint_text if not hint_text.is_empty() else DEFAULT_ACCEPT_HINT_TEXT

func _fatigue_reroll_threshold() -> int:
	return max(1, int(question.modifier_settings.get("fatigue_reroll_threshold", DEFAULT_FATIGUE_REROLL_THRESHOLD)))

func _spam_threshold() -> int:
	return max(2, int(question.modifier_settings.get("spam_threshold", DEFAULT_SPAM_THRESHOLD)))

func _spam_window_seconds() -> float:
	return maxf(0.15, float(question.modifier_settings.get("spam_window_seconds", DEFAULT_SPAM_WINDOW_SECONDS)))
