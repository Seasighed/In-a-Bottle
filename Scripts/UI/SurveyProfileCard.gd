class_name SurveyProfileCard
extends PanelContainer

@onready var _stack: VBoxContainer = $Stack
@onready var _heading_label: Label = $Stack/HeadingRow/HeadingLabel
@onready var _title_badge: Label = $Stack/HeadingRow/TitleBadge
@onready var _subtitle_label: Label = $Stack/SubtitleLabel
@onready var _exp_panel: PanelContainer = $Stack/ExpPanel
@onready var _exp_total_label: Label = $Stack/ExpPanel/ExpStack/ExpTotalLabel
@onready var _level_label: Label = $Stack/ExpPanel/ExpStack/LevelLabel
@onready var _buff_label: Label = $Stack/ExpPanel/ExpStack/BuffLabel
@onready var _stats_heading: Label = $Stack/StatsHeadingLabel
@onready var _stats_grid: GridContainer = $Stack/StatsGrid
@onready var _survey_heading: Label = $Stack/SurveyHeadingLabel
@onready var _survey_grid: GridContainer = $Stack/SurveyGrid
@onready var _titles_heading: Label = $Stack/TitlesHeadingLabel
@onready var _titles_flow: HFlowContainer = $Stack/TitlesFlow
@onready var _achievements_heading: Label = $Stack/AchievementsHeadingLabel
@onready var _achievements_list: VBoxContainer = $Stack/AchievementsList

var _snapshot: Dictionary = {}

func _ready() -> void:
	refresh_theme()

func configure(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if is_node_ready():
		_rebuild()

func refresh_theme() -> void:
	SurveyStyle.apply_panel(self, SurveyStyle.SURFACE, SurveyStyle.BORDER, 24, 1)
	SurveyStyle.apply_panel(_exp_panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 18, 1)
	SurveyStyle.style_heading(_heading_label, 24)
	SurveyStyle.style_caption(_title_badge, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.style_body(_subtitle_label)
	SurveyStyle.style_heading(_exp_total_label, 22, SurveyStyle.HIGHLIGHT_GOLD)
	SurveyStyle.style_body(_level_label, SurveyStyle.TEXT_PRIMARY)
	SurveyStyle.style_caption(_buff_label, SurveyStyle.SUCCESS)
	SurveyStyle.style_heading(_stats_heading, 18)
	SurveyStyle.style_heading(_survey_heading, 18)
	SurveyStyle.style_heading(_titles_heading, 18)
	SurveyStyle.style_heading(_achievements_heading, 18)
	_rebuild()

func refresh_layout(width: float) -> void:
	var compact := width <= 560.0
	_stats_grid.columns = 1 if compact else 2
	_survey_grid.columns = 1 if compact else 2

func _rebuild() -> void:
	if not is_node_ready():
		return
	var progress: Dictionary = _snapshot.get("progress", {})
	var stats: Dictionary = _snapshot.get("stats", {})
	var current_survey: Dictionary = _snapshot.get("current_survey", {})
	var titles_value: Variant = _snapshot.get("titles", PackedStringArray())
	var achievements_value: Variant = _snapshot.get("achievements", [])

	_heading_label.text = "Social Profile"
	_title_badge.text = str(_snapshot.get("current_title", "Wanderer")).strip_edges()
	_title_badge.visible = not _title_badge.text.is_empty()
	_subtitle_label.text = "Track your survey momentum, unlocked titles, achievements, and the current answer state of the survey you are working through."

	_exp_total_label.text = "%d XP" % int(_snapshot.get("xp_total", 0))
	_level_label.text = "Level %d  |  %d / %d XP" % [
		int(progress.get("level", 1)),
		int(progress.get("level_current", 0)),
		int(progress.get("level_target", 100))
	]
	_buff_label.text = str(progress.get("active_buff_label", "")).strip_edges()
	_buff_label.visible = not _buff_label.text.is_empty()

	_rebuild_stat_grid(_stats_grid, [
		{"label": "Questions Locked", "value": str(stats.get("questions_locked", 0))},
		{"label": "Sections Completed", "value": str(stats.get("sections_completed", 0))},
		{"label": "Surveys Completed", "value": str(stats.get("surveys_completed", 0))},
		{"label": "Buffs Earned", "value": str(stats.get("buffs_earned", 0))}
	])

	_rebuild_stat_grid(_survey_grid, [
		{"label": "Survey", "value": str(current_survey.get("title", "No active survey"))},
		{"label": "Answered", "value": str(current_survey.get("answered", 0))},
		{"label": "Unanswered", "value": str(current_survey.get("unanswered", 0))},
		{"label": "Partial", "value": str(current_survey.get("partial", 0))},
		{"label": "Complete", "value": str(current_survey.get("complete", 0))},
		{"label": "Sections Cleared", "value": "%d / %d" % [int(current_survey.get("sections_complete", 0)), int(current_survey.get("sections_total", 0))]}
	])

	_clear_container(_titles_flow)
	if titles_value is PackedStringArray:
		for title in titles_value:
			_titles_flow.add_child(_create_tag(str(title), SurveyStyle.HIGHLIGHT_GOLD))
	elif titles_value is Array:
		for title in titles_value:
			_titles_flow.add_child(_create_tag(str(title), SurveyStyle.HIGHLIGHT_GOLD))
	if _titles_flow.get_child_count() == 0:
		_titles_flow.add_child(_create_tag("No titles yet", SurveyStyle.TEXT_MUTED))

	_clear_container(_achievements_list)
	if achievements_value is Array and not (achievements_value as Array).is_empty():
		for entry_value in achievements_value:
			if not (entry_value is Dictionary):
				continue
			_achievements_list.add_child(_create_achievement_card(entry_value as Dictionary))
	else:
		var placeholder := Label.new()
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placeholder.text = "No achievements unlocked yet. Keep answering to fill out your inventory."
		SurveyStyle.style_body(placeholder)
		_achievements_list.add_child(placeholder)

func _rebuild_stat_grid(grid: GridContainer, entries: Array[Dictionary]) -> void:
	_clear_container(grid)
	for entry in entries:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, SurveyStyle.BORDER, 16, 1)
		var row := VBoxContainer.new()
		row.layout_mode = 2
		row.add_theme_constant_override("separation", 4)
		panel.add_child(row)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = str(entry.get("label", ""))
		SurveyStyle.style_caption(label, SurveyStyle.TEXT_MUTED)
		row.add_child(label)
		var value_label := Label.new()
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.text = str(entry.get("value", ""))
		SurveyStyle.style_body(value_label, SurveyStyle.TEXT_PRIMARY)
		value_label.add_theme_font_size_override("font_size", 16)
		row.add_child(value_label)
		grid.add_child(panel)

func _create_tag(text: String, accent_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, accent_color, 999, 1)
	var label := Label.new()
	label.text = text.strip_edges()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SurveyStyle.style_caption(label, accent_color if accent_color.a > 0.0 else SurveyStyle.TEXT_PRIMARY)
	panel.add_child(label)
	return panel

func _create_achievement_card(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SurveyStyle.apply_panel(panel, SurveyStyle.SURFACE_ALT, SurveyStyle.HIGHLIGHT_GOLD, 16, 1)
	var stack := VBoxContainer.new()
	stack.layout_mode = 2
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	var heading := Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.text = str(entry.get("label", "Achievement"))
	SurveyStyle.style_body(heading, SurveyStyle.TEXT_PRIMARY)
	stack.add_child(heading)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = str(entry.get("description", "")).strip_edges()
	SurveyStyle.style_caption(description, SurveyStyle.TEXT_MUTED)
	stack.add_child(description)
	var footer_parts: Array[String] = []
	var title_text := str(entry.get("title", "")).strip_edges()
	if not title_text.is_empty():
		footer_parts.append("Title: %s" % title_text)
	var unlocked_at := str(entry.get("unlocked_at", "")).strip_edges()
	if not unlocked_at.is_empty():
		footer_parts.append(unlocked_at)
	if not footer_parts.is_empty():
		var footer := Label.new()
		footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.text = "  |  ".join(footer_parts)
		SurveyStyle.style_caption(footer, SurveyStyle.HIGHLIGHT_GOLD)
		stack.add_child(footer)
	return panel

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
