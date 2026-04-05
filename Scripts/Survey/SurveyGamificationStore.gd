class_name SurveyGamificationStore
extends RefCounted

const STORE_PATH := "user://survey_gamification_profile.json"
const FORMAT_ID := "survey_gamification_profile"
const CURRENT_VERSION := 3
const LEVEL_XP_BASE := 100
const LEVEL_XP_STEP := 20
const SECTION_COMPLETE_XP := 28
const SURVEY_COMPLETE_XP := 72
const BUFF_ROLL_CHANCE := 0.22

const BUFF_DEFINITIONS := [
	{"id": "focus_burst", "label": "Focus Burst", "multiplier": 1.5, "remaining_actions": 3},
	{"id": "streak_spark", "label": "Streak Spark", "multiplier": 2.0, "remaining_actions": 2},
	{"id": "critical_flow", "label": "Critical Flow", "multiplier": 2.5, "remaining_actions": 2}
]

const ACHIEVEMENT_DEFINITIONS := [
	{"id": "first_click", "label": "First Lock-In", "description": "Lock in your first question.", "title": "Curious Clicker", "key": "questions_locked", "threshold": 1},
	{"id": "first_answer", "label": "Finding Rhythm", "description": "Lock in three questions.", "title": "Responder", "key": "questions_locked", "threshold": 3},
	{"id": "question_closer", "label": "Question Closer", "description": "Lock in five questions.", "title": "Momentum Builder", "key": "questions_locked", "threshold": 5},
	{"id": "section_scout", "label": "Section Scout", "description": "Finish your first section.", "title": "Section Scout", "key": "sections_completed", "threshold": 1},
	{"id": "survey_finisher", "label": "Survey Finisher", "description": "Finish an entire survey.", "title": "Survey Finisher", "key": "surveys_completed", "threshold": 1},
	{"id": "revisionist", "label": "Steady Pace", "description": "Lock in ten questions.", "title": "Steady Pace", "key": "questions_locked", "threshold": 10},
	{"id": "xp_sparked", "label": "XP Sparked", "description": "Reach 100 EXP.", "title": "Sparked", "key": "xp_total", "threshold": 100},
	{"id": "buffed", "label": "Buffed", "description": "Earn your first EXP multiplier buff.", "title": "Buff Bearer", "key": "buffs_earned", "threshold": 1},
	{"id": "completionist", "label": "Completionist", "description": "Finish three surveys.", "title": "Completionist", "key": "surveys_completed", "threshold": 3}
]

static var _rng := RandomNumberGenerator.new()
static var _rng_ready := false

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return default_profile()
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return default_profile()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return default_profile()
	return _normalize_profile(parsed as Dictionary)

static func save_profile(profile: Dictionary) -> bool:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var payload := _normalize_profile(profile)
	payload["saved_at"] = Time.get_datetime_string_from_system(true)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func default_profile() -> Dictionary:
	return {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"saved_at": "",
		"xp_total": 0,
		"stats": {
			"questions_locked": 0,
			"sections_completed": 0,
			"surveys_completed": 0,
			"buffs_earned": 0,
			"total_xp_gained": 0
		},
		"question_xp_totals": {},
		"titles": PackedStringArray(),
		"achievements": {},
		"active_buff": {}
	}

static func award_question_lock(profile: Dictionary, question: SurveyQuestion, base_xp: int, screen_pos: Vector2 = Vector2.ZERO, question_reward_key: String = "", max_question_xp: int = 0) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var question_id: String = question.id if question != null else ""
	var meta := {
		"question_id": question_id.strip_edges(),
		"question_type": str(question.type) if question != null else "",
		"question_base_xp": max(0, base_xp),
		"question_reward_key": question_reward_key.strip_edges(),
		"question_xp_cap": max(0, max_question_xp),
		"question_reward_count": question.reward_count if question != null and question.reward_count_configured else max(0, base_xp),
		"question_reward_sprite": question.reward_sprite.strip_edges() if question != null else ""
	}
	if question == null or base_xp <= 0:
		return _finalize_award_result(_empty_award_result(working_profile, "question_lock", "Question locked in", screen_pos, meta))
	var result := _award_profile_xp(working_profile, base_xp, "question_lock", "Question locked in", screen_pos, meta)
	var reward_applied: bool = int(result.get("xp_awarded", 0)) > 0
	var stats: Dictionary = result.get("stats", {})
	if reward_applied:
		stats["questions_locked"] = int(stats.get("questions_locked", 0)) + 1
		var toast_entries: Array = result.get("toast_entries", [])
		toast_entries.append({
			"text": "Question locked in",
			"kind": "question"
		})
		result["toast_entries"] = toast_entries
		if _should_grant_buff(result.get("profile", working_profile)):
			var buff := _grant_random_buff(result.get("profile", working_profile))
			if not buff.is_empty():
				stats["buffs_earned"] = int(stats.get("buffs_earned", 0)) + 1
				var buff_toast_entries: Array = result.get("toast_entries", [])
				buff_toast_entries.append({
					"text": "%s x%s for %d action(s)" % [str(buff.get("label", "Buff")), _multiplier_text(float(buff.get("multiplier", 1.0))), int(buff.get("remaining_actions", 0))],
					"kind": "buff"
				})
				result["toast_entries"] = buff_toast_entries
				result["buff_awarded"] = buff.duplicate(true)
	result["stats"] = stats
	return _finalize_award_result(result)

static func award_section_complete(profile: Dictionary, section_id: String, section_title: String, screen_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var result := _award_profile_xp(working_profile, SECTION_COMPLETE_XP, "section_complete", "Section complete", screen_pos, {
		"section_id": section_id.strip_edges(),
		"section_title": section_title.strip_edges()
	})
	var stats: Dictionary = result.get("stats", {})
	stats["sections_completed"] = int(stats.get("sections_completed", 0)) + 1
	result["stats"] = stats
	var toast_entries: Array = result.get("toast_entries", [])
	toast_entries.append({
		"text": "Section complete: %s" % (section_title if not section_title.is_empty() else section_id),
		"kind": "section"
	})
	result["toast_entries"] = toast_entries
	return _finalize_award_result(result)

static func award_survey_complete(profile: Dictionary, survey_id: String, survey_title: String, screen_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var result := _award_profile_xp(working_profile, SURVEY_COMPLETE_XP, "survey_complete", "Survey complete", screen_pos, {
		"survey_id": survey_id.strip_edges(),
		"survey_title": survey_title.strip_edges()
	})
	var stats: Dictionary = result.get("stats", {})
	stats["surveys_completed"] = int(stats.get("surveys_completed", 0)) + 1
	result["stats"] = stats
	var toast_entries: Array = result.get("toast_entries", [])
	toast_entries.append({
		"text": "Survey complete: %s" % (survey_title if not survey_title.is_empty() else survey_id),
		"kind": "survey"
	})
	result["toast_entries"] = toast_entries
	return _finalize_award_result(result)

static func build_progress_state(profile: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var xp_total: int = max(0, int(working_profile.get("xp_total", 0)))
	var level: int = level_for_xp(xp_total)
	var level_start: int = xp_required_for_level(level)
	var level_target: int = xp_required_for_level(level + 1)
	var level_delta: int = max(level_target - level_start, 1)
	var current_into_level: int = xp_total - level_start
	var buff: Dictionary = _normalized_buff(working_profile.get("active_buff", {}))
	return {
		"xp_total": xp_total,
		"level": level,
		"level_current": current_into_level,
		"level_target": level_delta,
		"progress_ratio": clampf(float(current_into_level) / float(level_delta), 0.0, 1.0),
		"segment_count": 20,
		"active_buff": buff.duplicate(true),
		"active_buff_label": _buff_display_text(buff)
	}

static func build_profile_snapshot(profile: Dictionary, survey: SurveyDefinition, answers: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var stats: Dictionary = _normalized_stats(working_profile.get("stats", {}))
	var current_answered := 0
	var current_complete := 0
	var current_partial := 0
	var current_total := 0
	var current_sections_complete := 0
	if survey != null:
		for section in survey.sections:
			var section_complete := true
			for question in section.questions:
				current_total += 1
				var value: Variant = answers.get(question.id, null)
				var state: StringName = question.answer_completion_state(value)
				if state != SurveyQuestion.ANSWER_STATE_UNANSWERED:
					current_answered += 1
				if state == SurveyQuestion.ANSWER_STATE_COMPLETE:
					current_complete += 1
				elif state == SurveyQuestion.ANSWER_STATE_PARTIAL:
					current_partial += 1
					section_complete = false
				else:
					section_complete = false
			if section_complete and not section.questions.is_empty():
				current_sections_complete += 1
	var achievements: Array[Dictionary] = []
	var raw_achievements: Dictionary = working_profile.get("achievements", {})
	for definition in ACHIEVEMENT_DEFINITIONS:
		var achievement_id := str(definition.get("id", ""))
		if raw_achievements.has(achievement_id):
			var stored_value: Variant = raw_achievements.get(achievement_id, {})
			var stored_entry: Dictionary = stored_value as Dictionary if stored_value is Dictionary else {}
			achievements.append({
				"id": achievement_id,
				"label": str(definition.get("label", achievement_id)),
				"description": str(definition.get("description", "")),
				"title": str(definition.get("title", "")).strip_edges(),
				"unlocked_at": str(stored_entry.get("unlocked_at", ""))
			})
	achievements.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("unlocked_at", "")) > str(right.get("unlocked_at", ""))
	)
	var titles_value: Variant = working_profile.get("titles", PackedStringArray())
	var titles: PackedStringArray = PackedStringArray()
	if titles_value is PackedStringArray:
		titles = titles_value
	elif titles_value is Array:
		for item in titles_value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				titles.append(text)
	var current_title := titles[titles.size() - 1] if not titles.is_empty() else "Wanderer"
	return {
		"profile": working_profile.duplicate(true),
		"progress": build_progress_state(working_profile),
		"xp_total": int(working_profile.get("xp_total", 0)),
		"current_title": current_title,
		"titles": titles,
		"achievements": achievements,
		"stats": stats.duplicate(true),
		"current_survey": {
			"id": survey.id if survey != null else "",
			"title": survey.title if survey != null else "No active survey",
			"answered": current_answered,
			"unanswered": max(current_total - current_answered, 0),
			"complete": current_complete,
			"partial": current_partial,
			"total": current_total,
			"sections_complete": current_sections_complete,
			"sections_total": survey.sections.size() if survey != null else 0
		}
	}

static func build_profile_json(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot, "\t")

static func build_share_json(profile: Dictionary) -> String:
	var working_profile := _normalize_profile(profile)
	var payload := {
		"format": "survey_social_profile_share",
		"version": CURRENT_VERSION,
		"shared_at": Time.get_datetime_string_from_system(true),
		"xp_total": int(working_profile.get("xp_total", 0)),
		"stats": _normalized_stats(working_profile.get("stats", {})),
		"titles": working_profile.get("titles", PackedStringArray()),
		"achievements": working_profile.get("achievements", {}).duplicate(true)
	}
	return JSON.stringify(payload, "\t")

static func build_profile_csv(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("metric,value")
	var progress: Dictionary = snapshot.get("progress", {})
	var stats: Dictionary = snapshot.get("stats", {})
	var current_survey: Dictionary = snapshot.get("current_survey", {})
	lines.append(_csv_metric("level", str(progress.get("level", 1))))
	lines.append(_csv_metric("xp_total", str(snapshot.get("xp_total", 0))))
	lines.append(_csv_metric("current_title", str(snapshot.get("current_title", ""))))
	lines.append(_csv_metric("questions_locked", str(stats.get("questions_locked", 0))))
	lines.append(_csv_metric("sections_completed_total", str(stats.get("sections_completed", 0))))
	lines.append(_csv_metric("surveys_completed_total", str(stats.get("surveys_completed", 0))))
	lines.append(_csv_metric("current_survey_title", str(current_survey.get("title", ""))))
	lines.append(_csv_metric("current_survey_answered", str(current_survey.get("answered", 0))))
	lines.append(_csv_metric("current_survey_unanswered", str(current_survey.get("unanswered", 0))))
	lines.append(_csv_metric("current_survey_partial", str(current_survey.get("partial", 0))))
	lines.append(_csv_metric("current_survey_total", str(current_survey.get("total", 0))))
	var titles_value: Variant = snapshot.get("titles", PackedStringArray())
	if titles_value is PackedStringArray:
		for title in titles_value:
			lines.append(_csv_metric("title", str(title)))
	elif titles_value is Array:
		for title in titles_value:
			lines.append(_csv_metric("title", str(title)))
	var achievements_value: Variant = snapshot.get("achievements", [])
	if achievements_value is Array:
		for entry_value in achievements_value:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value as Dictionary
			lines.append(_csv_metric("achievement", "%s | %s" % [str(entry.get("label", "")), str(entry.get("description", ""))]))
	return "\n".join(lines) + "\n"

static func suggested_filename(stem: String, extension: String) -> String:
	var safe_stem := stem.to_lower().strip_edges().replace(" ", "_")
	if safe_stem.is_empty():
		safe_stem = "profile"
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return "%s_%s.%s" % [safe_stem, stamp, extension.to_lower()]

static func level_for_xp(xp_total: int) -> int:
	var resolved_xp: int = max(0, xp_total)
	var level: int = 1
	while resolved_xp >= xp_required_for_level(level + 1):
		level += 1
	return level

static func xp_required_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var total := 0
	for step in range(1, level):
		total += LEVEL_XP_BASE + ((step - 1) * LEVEL_XP_STEP)
	return total

static func suggested_max_xp_per_question(question_xp: int = 0) -> int:
	return max(0, question_xp)

static func _normalize_profile(raw_profile: Dictionary) -> Dictionary:
	var profile := default_profile()
	profile["xp_total"] = max(0, int(raw_profile.get("xp_total", profile.get("xp_total", 0))))
	profile["stats"] = _normalized_stats(raw_profile.get("stats", {}))
	profile["question_xp_totals"] = _normalized_question_xp_totals(raw_profile.get("question_xp_totals", {}))
	profile["achievements"] = _normalized_achievements(raw_profile.get("achievements", {}))
	profile["titles"] = _normalized_titles(raw_profile.get("titles", PackedStringArray()))
	profile["active_buff"] = _normalized_buff(raw_profile.get("active_buff", {}))
	profile["saved_at"] = str(raw_profile.get("saved_at", ""))
	return profile

static func _normalized_stats(value: Variant) -> Dictionary:
	var stats := (value as Dictionary) if value is Dictionary else {}
	var legacy_locked_value: int = 0
	if stats.has("questions_locked"):
		legacy_locked_value = int(stats.get("questions_locked", 0))
	elif stats.has("questions_completed"):
		legacy_locked_value = int(stats.get("questions_completed", 0))
	return {
		"questions_locked": max(0, legacy_locked_value),
		"sections_completed": max(0, int(stats.get("sections_completed", 0))),
		"surveys_completed": max(0, int(stats.get("surveys_completed", 0))),
		"buffs_earned": max(0, int(stats.get("buffs_earned", 0))),
		"total_xp_gained": max(0, int(stats.get("total_xp_gained", 0)))
	}

static func _normalized_achievements(value: Variant) -> Dictionary:
	var achievements := (value as Dictionary) if value is Dictionary else {}
	var normalized := {}
	for key in achievements.keys():
		var entry_value: Variant = achievements.get(key, {})
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		normalized[str(key)] = {
			"unlocked_at": str(entry.get("unlocked_at", "")),
			"label": str(entry.get("label", "")),
			"description": str(entry.get("description", "")),
			"title": str(entry.get("title", ""))
		}
	return normalized

static func _normalized_question_xp_totals(value: Variant) -> Dictionary:
	var totals := (value as Dictionary) if value is Dictionary else {}
	var normalized := {}
	for key_variant in totals.keys():
		var question_reward_key: String = str(key_variant).strip_edges()
		if question_reward_key.is_empty():
			continue
		var total_xp: int = max(0, int(totals.get(key_variant, 0)))
		if total_xp > 0:
			normalized[question_reward_key] = total_xp
	return normalized

static func _normalized_titles(value: Variant) -> PackedStringArray:
	var titles := PackedStringArray()
	if value is PackedStringArray:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty() and not titles.has(text):
				titles.append(text)
	elif value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty() and not titles.has(text):
				titles.append(text)
	return titles

static func _normalized_buff(value: Variant) -> Dictionary:
	var buff := (value as Dictionary) if value is Dictionary else {}
	if buff.is_empty():
		return {}
	var remaining_actions: int = max(0, int(buff.get("remaining_actions", 0)))
	var multiplier: float = maxf(1.0, float(buff.get("multiplier", 1.0)))
	if remaining_actions <= 0 or multiplier <= 1.0:
		return {}
	return {
		"id": str(buff.get("id", "buff")),
		"label": str(buff.get("label", "Buff")).strip_edges(),
		"multiplier": multiplier,
		"remaining_actions": remaining_actions
	}

static func _empty_award_result(profile: Dictionary, action_id: String, action_label: String, screen_pos: Vector2, meta: Dictionary = {}) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var xp_total: int = int(working_profile.get("xp_total", 0))
	var current_level: int = level_for_xp(xp_total)
	return {
		"profile": working_profile,
		"xp_awarded": 0,
		"base_xp": 0,
		"screen_pos": screen_pos,
		"action_id": action_id,
		"action_label": action_label,
		"meta": meta.duplicate(true),
		"leveled_from": current_level,
		"leveled_to": current_level,
		"multiplier_applied": 1.0,
		"toast_entries": [],
		"stats": _normalized_stats(working_profile.get("stats", {}))
	}

static func _question_xp_context(profile: Dictionary, meta: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var question_reward_key: String = str(meta.get("question_reward_key", "")).strip_edges()
	var question_xp_cap: int = max(0, int(meta.get("question_xp_cap", 0)))
	var question_xp_totals: Dictionary = _normalized_question_xp_totals(working_profile.get("question_xp_totals", {}))
	var current_total: int = 0
	if not question_reward_key.is_empty() and question_xp_cap > 0:
		current_total = int(question_xp_totals.get(question_reward_key, 0))
	return {
		"question_reward_key": question_reward_key,
		"question_xp_cap": question_xp_cap,
		"question_xp_totals": question_xp_totals,
		"question_xp_total_before": current_total,
		"question_xp_remaining": max(0, question_xp_cap - current_total) if question_xp_cap > 0 else 0
	}

static func _apply_question_xp_award(profile: Dictionary, requested_xp: int, meta: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var context: Dictionary = _question_xp_context(working_profile, meta)
	var question_reward_key: String = str(context.get("question_reward_key", "")).strip_edges()
	var question_xp_cap: int = int(context.get("question_xp_cap", 0))
	var question_xp_totals: Dictionary = context.get("question_xp_totals", {})
	var question_xp_total_before: int = int(context.get("question_xp_total_before", 0))
	var awarded_xp: int = max(0, requested_xp)
	if not question_reward_key.is_empty() and question_xp_cap > 0:
		awarded_xp = min(awarded_xp, int(context.get("question_xp_remaining", 0)))
		if awarded_xp > 0:
			question_xp_totals[question_reward_key] = question_xp_total_before + awarded_xp
		working_profile["question_xp_totals"] = question_xp_totals
	return {
		"profile": working_profile,
		"awarded_xp": awarded_xp,
		"question_reward_key": question_reward_key,
		"question_xp_cap": question_xp_cap,
		"question_xp_total_before": question_xp_total_before,
		"question_xp_total_after": question_xp_total_before + awarded_xp
	}

static func _award_profile_xp(profile: Dictionary, base_xp: int, action_id: String, action_label: String, screen_pos: Vector2, meta: Dictionary = {}) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	var buff: Dictionary = _normalized_buff(working_profile.get("active_buff", {}))
	var applied_multiplier := float(buff.get("multiplier", 1.0))
	var leveled_from := level_for_xp(int(working_profile.get("xp_total", 0)))
	var stats := _normalized_stats(working_profile.get("stats", {}))
	var requested_awarded_xp: int = maxi(1, int(round(float(base_xp) * applied_multiplier)))
	var question_award: Dictionary = _apply_question_xp_award(working_profile, requested_awarded_xp, meta)
	working_profile = _normalize_profile(question_award.get("profile", working_profile))
	var awarded_xp: int = int(question_award.get("awarded_xp", 0))
	if awarded_xp > 0:
		working_profile["xp_total"] = int(working_profile.get("xp_total", 0)) + awarded_xp
		stats["total_xp_gained"] = int(stats.get("total_xp_gained", 0)) + awarded_xp
	working_profile["stats"] = stats
	var toast_entries: Array = []
	if awarded_xp > 0:
		toast_entries.append({
			"text": "+%d XP%s" % [awarded_xp, ("  x%s" % _multiplier_text(applied_multiplier)) if applied_multiplier > 1.0 else ""],
			"kind": "xp"
		})
	if not buff.is_empty() and awarded_xp > 0:
		buff["remaining_actions"] = max(0, int(buff.get("remaining_actions", 0)) - 1)
		working_profile["active_buff"] = _normalized_buff(buff)
	var leveled_to := level_for_xp(int(working_profile.get("xp_total", 0)))
	return {
		"profile": working_profile,
		"xp_awarded": awarded_xp,
		"base_xp": base_xp,
		"screen_pos": screen_pos,
		"action_id": action_id,
		"action_label": action_label,
		"meta": meta.duplicate(true),
		"leveled_from": leveled_from,
		"leveled_to": leveled_to,
		"multiplier_applied": applied_multiplier,
		"toast_entries": toast_entries,
		"stats": stats,
		"question_reward_key": str(question_award.get("question_reward_key", "")),
		"question_xp_cap": int(question_award.get("question_xp_cap", 0)),
		"question_xp_total_before": int(question_award.get("question_xp_total_before", 0)),
		"question_xp_total_after": int(question_award.get("question_xp_total_after", 0))
	}

static func _apply_bonus_xp(result: Dictionary, bonus_xp: int) -> Dictionary:
	if bonus_xp <= 0:
		return result
	var working_profile := _normalize_profile(result.get("profile", {}))
	var awarded_xp: int = max(0, int(result.get("xp_awarded", 0)))
	var stats := _normalized_stats(working_profile.get("stats", {}))
	var question_award: Dictionary = _apply_question_xp_award(working_profile, bonus_xp, result.get("meta", {}))
	working_profile = _normalize_profile(question_award.get("profile", working_profile))
	var awarded_bonus_xp: int = int(question_award.get("awarded_xp", 0))
	awarded_xp += awarded_bonus_xp
	if awarded_bonus_xp > 0:
		working_profile["xp_total"] = int(working_profile.get("xp_total", 0)) + awarded_bonus_xp
		stats["total_xp_gained"] = int(stats.get("total_xp_gained", 0)) + awarded_bonus_xp
	var toast_entries: Array = result.get("toast_entries", [])
	if awarded_bonus_xp > 0 and toast_entries.is_empty():
		toast_entries.append({
			"text": "+%d XP%s" % [awarded_xp, ("  x%s" % _multiplier_text(float(result.get("multiplier_applied", 1.0)))) if float(result.get("multiplier_applied", 1.0)) > 1.0 else ""],
			"kind": "xp"
		})
	elif awarded_bonus_xp > 0:
		toast_entries[0] = {
			"text": "+%d XP%s" % [awarded_xp, ("  x%s" % _multiplier_text(float(result.get("multiplier_applied", 1.0)))) if float(result.get("multiplier_applied", 1.0)) > 1.0 else ""],
			"kind": "xp"
		}
	result["xp_awarded"] = awarded_xp
	result["profile"] = working_profile
	result["stats"] = stats
	result["toast_entries"] = toast_entries
	result["question_reward_key"] = str(question_award.get("question_reward_key", result.get("question_reward_key", "")))
	result["question_xp_cap"] = int(question_award.get("question_xp_cap", result.get("question_xp_cap", 0)))
	result["question_xp_total_after"] = int(question_award.get("question_xp_total_after", result.get("question_xp_total_after", 0)))
	return result

static func _finalize_award_result(result: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(result.get("profile", {}))
	var stats := _normalized_stats(result.get("stats", working_profile.get("stats", {})))
	working_profile["stats"] = stats
	result["stats"] = stats
	var leveled_from := int(result.get("leveled_from", level_for_xp(int(working_profile.get("xp_total", 0)))))
	var leveled_to := level_for_xp(int(working_profile.get("xp_total", 0)))
	result["leveled_to"] = leveled_to
	if leveled_to > leveled_from:
		var toast_entries: Array = result.get("toast_entries", [])
		toast_entries.append({
			"text": "Level %d reached" % leveled_to,
			"kind": "level"
		})
		result["toast_entries"] = toast_entries
	var achievements := _unlock_achievements(working_profile)
	if not achievements.is_empty():
		var toast_entries: Array = result.get("toast_entries", [])
		for achievement in achievements:
			toast_entries.append({
				"text": "Unlocked: %s" % str(achievement.get("label", "Achievement")),
				"kind": "unlock"
			})
			var title_unlocked := str(achievement.get("title_unlocked", "")).strip_edges()
			if not title_unlocked.is_empty():
				toast_entries.append({
					"text": "Title earned: %s" % title_unlocked,
					"kind": "title"
				})
		result["toast_entries"] = toast_entries
	result["profile"] = working_profile
	result["achievements_unlocked"] = achievements
	result["hud_state"] = build_progress_state(working_profile)
	var titles := _normalized_titles(working_profile.get("titles", PackedStringArray()))
	result["current_title"] = titles[titles.size() - 1] if not titles.is_empty() else "Wanderer"
	return result

static func _unlock_achievements(profile: Dictionary) -> Array[Dictionary]:
	var working_profile := _normalize_profile(profile)
	var stats := _normalized_stats(working_profile.get("stats", {}))
	var achievements: Dictionary = working_profile.get("achievements", {})
	var titles := _normalized_titles(working_profile.get("titles", PackedStringArray()))
	var unlocked_entries: Array[Dictionary] = []
	for definition in ACHIEVEMENT_DEFINITIONS:
		var achievement_id := str(definition.get("id", "")).strip_edges()
		if achievement_id.is_empty() or achievements.has(achievement_id):
			continue
		var key := str(definition.get("key", "")).strip_edges()
		var threshold: int = max(1, int(definition.get("threshold", 1)))
		var current_value: int = 0
		if key == "xp_total":
			current_value = int(working_profile.get("xp_total", 0))
		else:
			current_value = int(stats.get(key, 0))
		if current_value < threshold:
			continue
		var unlocked_entry := {
			"unlocked_at": Time.get_datetime_string_from_system(true),
			"label": str(definition.get("label", achievement_id)),
			"description": str(definition.get("description", "")),
			"title": str(definition.get("title", ""))
		}
		achievements[achievement_id] = unlocked_entry
		var title_text := str(unlocked_entry.get("title", "")).strip_edges()
		if not title_text.is_empty() and not titles.has(title_text):
			titles.append(title_text)
			unlocked_entry["title_unlocked"] = title_text
		unlocked_entries.append({
			"id": achievement_id,
			"label": str(unlocked_entry.get("label", "")),
			"description": str(unlocked_entry.get("description", "")),
			"title": title_text,
			"title_unlocked": str(unlocked_entry.get("title_unlocked", ""))
		})
	working_profile["achievements"] = achievements
	working_profile["titles"] = titles
	profile.clear()
	profile.merge(working_profile, true)
	return unlocked_entries

static func _should_grant_buff(profile: Dictionary) -> bool:
	var working_profile := _normalize_profile(profile)
	if not _normalized_buff(working_profile.get("active_buff", {})).is_empty():
		return false
	_ensure_rng()
	return _rng.randf() <= BUFF_ROLL_CHANCE

static func _grant_random_buff(profile: Dictionary) -> Dictionary:
	var working_profile := _normalize_profile(profile)
	_ensure_rng()
	var index := _rng.randi_range(0, BUFF_DEFINITIONS.size() - 1)
	var definition: Dictionary = BUFF_DEFINITIONS[index]
	var buff := {
		"id": str(definition.get("id", "buff")),
		"label": str(definition.get("label", "Buff")),
		"multiplier": float(definition.get("multiplier", 1.5)),
		"remaining_actions": int(definition.get("remaining_actions", 2))
	}
	working_profile["active_buff"] = buff
	profile.clear()
	profile.merge(working_profile, true)
	return buff

static func _ensure_rng() -> void:
	if _rng_ready:
		return
	_rng.randomize()
	_rng_ready = true

static func _values_match(left: Variant, right: Variant) -> bool:
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY:
		return JSON.stringify(left) == JSON.stringify(right)
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		return JSON.stringify(left) == JSON.stringify(right)
	return left == right

static func _buff_display_text(buff: Dictionary) -> String:
	if buff.is_empty():
		return ""
	return "%s x%s  |  %d action(s)" % [str(buff.get("label", "Buff")), _multiplier_text(float(buff.get("multiplier", 1.0))), int(buff.get("remaining_actions", 0))]

static func _multiplier_text(multiplier: float) -> String:
	if is_equal_approx(multiplier, round(multiplier)):
		return str(int(round(multiplier)))
	return str(snappedf(multiplier, 0.1))

static func _csv_metric(metric: String, value: String) -> String:
	return "\"%s\",\"%s\"" % [metric.replace("\"", "\"\""), value.replace("\"", "\"\"")]
