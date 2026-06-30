extends SceneTree

const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const SURVEY_ANSWER_REVIEW = preload("res://Scripts/Survey/SurveyAnswerReview.gd")
const SURVEY_JOURNEY_SCENE = preload("res://Scenes/SurveyJourney.tscn")
const SURVEY_WRAPPED_CARD_SCRIPT = preload("res://Scripts/UI/SurveyAnswerWrappedCard.gd")

const TEMPLATE_DIR := "res://Dev/SurveyTemplates"
const OUTPUT_DIR := "res://exports/survey_fake_answer_screenshots"
const JOURNEY_VIEWPORT := Vector2i(1080, 1920)
const WRAPPED_VIEWPORT := Vector2i(1080, 1920)
const DEFAULT_FAKE_RESPONDENT_COUNT := 3
const CAPTURE_SCOPE_FULL := "full"
const CAPTURE_SCOPE_SAMPLE := "sample"
const WEIGHTED_OPTIONS_BY_QUESTION := {
	"region": ["North America", "North America", "North America", "Europe", "Southeast Asia", "Other or prefer not to say"],
	"playstyle": ["Daily progression focused", "Weekend or event focused", "Bossing focused", "Bossing focused", "Social or guild focused", "Mostly taking a break"],
	"main_archetype": ["Warrior-style", "Mage-style", "Thief-style", "Archer-style", "Pirate-style", "Hybrid or special kit", "I rotate too much to pick one"],
	"boss_frequency": ["Several times a week", "About once a week", "About once a week", "A few times a month", "Rarely", "Not currently"],
	"party_style": ["Mostly solo", "Guild or friend groups", "Static group", "Public recruitment", "Watching or learning before trying", "Not applicable"],
	"event_quality": ["They are useful but repetitive", "They are a major reason I play", "They feel too time demanding", "They mostly miss what I want", "I do not engage with events much"],
}
const MAPLESTORY_LONG_TEXT_BY_QUESTION := {
	"progression_friction": [
		"The routine feels best when progress is visible without needing every daily task.",
		"Upgrade planning is hard to explain to returning players without a guide open.",
		"Catch-up support matters most when friends are already several milestones ahead."
	],
	"challenge_story": [
		"A practice run with patient party members made harder content feel approachable.",
		"Scheduling was harder than the mechanics, even when everyone wanted to learn.",
		"Clear rewards felt great, but the variance made repeated attempts feel swingy."
	],
	"economy_concern": [
		"A deeper poll should separate cosmetic value from progression pressure.",
		"Market access and event supply probably need their own follow-up questions.",
		"I would ask how much price movement changes whether people log in."
	],
	"one_change": [
		"I would make community learning resources easier to find from inside the game loop.",
		"I would reduce the pressure to keep up with every event on every character.",
		"I would make group-finding less intimidating for players learning late-game content."
	]
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options := _proof_options_from_args()
	var respondent_counts: Array = options.get("respondent_counts", [DEFAULT_FAKE_RESPONDENT_COUNT])
	var capture_scope := str(options.get("capture_scope", CAPTURE_SCOPE_FULL))
	var survey_filter := str(options.get("survey_filter", "")).strip_edges()
	var output_root := ProjectSettings.globalize_path(OUTPUT_DIR).path_join(_safe_stamp(Time.get_datetime_string_from_system(true)))
	_prepare_output_directory(output_root)
	var scenarios: Array[Dictionary] = []
	for respondent_count_value in respondent_counts:
		var respondent_count := maxi(int(respondent_count_value), 1)
		var scenario_dir := output_root.path_join("respondents_%03d" % respondent_count)
		_prepare_output_directory(scenario_dir)
		var surveys: Array[Dictionary] = []
		var rejected: Array[Dictionary] = []
		for template_path in _builtin_template_paths():
			var survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(template_path)
			if survey == null:
				rejected.append({"path": template_path, "message": "Template did not load."})
				continue
			if not _survey_matches_filter(survey, template_path, survey_filter):
				continue
			var survey_result := await _capture_survey(survey, template_path, scenario_dir, respondent_count, capture_scope)
			surveys.append(survey_result)
		scenarios.append({
			"fake_respondent_count": respondent_count,
			"output_dir": scenario_dir,
			"survey_count": surveys.size(),
			"rejected": rejected,
			"surveys": surveys
		})
	var manifest := {
		"format": "survey_fake_answer_screenshot_proof_v2",
		"generated_at": Time.get_datetime_string_from_system(true),
		"display_server": DisplayServer.get_name(),
		"output_dir": output_root,
		"fake_respondent_count": int(respondent_counts[0]) if respondent_counts.size() == 1 else -1,
		"fake_respondent_counts": respondent_counts,
		"capture_scope": capture_scope,
		"survey_filter": survey_filter,
		"journey_viewport": _vector2i_dict(JOURNEY_VIEWPORT),
		"wrapped_viewport": _vector2i_dict(WRAPPED_VIEWPORT),
		"scenario_count": scenarios.size(),
		"survey_count": _scenario_survey_total(scenarios),
		"rejected_count": _scenario_rejected_total(scenarios),
		"rejected": (scenarios[0].get("rejected", []) as Array).duplicate(true) if not scenarios.is_empty() else [],
		"surveys": (scenarios[0].get("surveys", []) as Array).duplicate(true) if not scenarios.is_empty() else [],
		"scenarios": scenarios
	}
	var manifest_path := output_root.path_join("manifest.json")
	_write_json_file(manifest_path, manifest)
	print("SURVEY_TEMPLATE_SCREENSHOT_PROOF=%s" % JSON.stringify({
		"ok": true,
		"output_dir": output_root,
		"manifest_path": manifest_path,
		"scenario_count": scenarios.size(),
		"survey_count": _scenario_survey_total(scenarios),
		"rejected_count": _scenario_rejected_total(scenarios),
		"capture_scope": capture_scope
	}))
	quit(0)

func _capture_survey(survey: SurveyDefinition, template_path: String, output_root: String, respondent_count: int, capture_scope: String) -> Dictionary:
	var survey_slug := _safe_id("%s_%s" % [survey.id, template_path.get_file().get_basename()])
	var survey_dir := output_root.path_join(survey_slug)
	var wrapped_dir := survey_dir.path_join("wrapped")
	_prepare_output_directory(wrapped_dir)
	var records := _fake_records(survey, respondent_count)
	var aggregate: Dictionary = SURVEY_ANSWER_REVIEW.build_aggregate(survey, records)
	var wrap_options := _wrap_options_for_fake_export(aggregate, respondent_count)
	var first_answers: Dictionary = (records[0] as Dictionary).get("answers", {}) as Dictionary
	var review_capture := await _capture_journey_review(survey, template_path, first_answers)
	var review_path := survey_dir.path_join("journey_review_phone.png")
	var review_save_error := _save_capture_image(review_capture, review_path)
	var pages_data: Dictionary = SURVEY_ANSWER_REVIEW.build_wrapped_pages_data(
		survey,
		aggregate,
		false,
		{
			"profile_name": "Mushroom",
			"fields": [
				{"label": "Dataset", "value": "Fake answers"},
				{"label": "Responses", "value": str(respondent_count)}
			],
			"show_on_wrap": true
		},
		SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT,
		wrap_options
	)
	var wrapped_pages: Array[Dictionary] = []
	var pages: Array = pages_data.get("pages", [])
	for index in _page_indices_to_capture(pages, capture_scope):
		if not (pages[index] is Dictionary):
			continue
		var page: Dictionary = pages[index] as Dictionary
		var capture := await _capture_wrapped_page(page, pages_data)
		var file_name := str(page.get("file_name", "wrapped_%02d.png" % (index + 1)))
		var image_path := wrapped_dir.path_join(file_name)
		var save_error := _save_capture_image(capture, image_path)
		var metrics: Dictionary = capture.get("layout_metrics", {}) as Dictionary
		wrapped_pages.append({
			"page_number": int(page.get("page_number", index + 1)),
			"page_count": int(page.get("page_count", pages.size())),
			"page_kind": str(page.get("page_kind", "")),
			"section_id": str(page.get("section_id", "")),
			"file_name": file_name,
			"path": image_path,
			"save_error": save_error,
			"width": int((capture.get("image", null) as Image).get_width()) if capture.get("image", null) is Image else 0,
			"height": int((capture.get("image", null) as Image).get_height()) if capture.get("image", null) is Image else 0,
			"placeholder": bool(capture.get("placeholder", false)),
			"layout_metrics": metrics
		})
	return {
		"survey_id": survey.id,
		"title": survey.title,
		"template_path": template_path,
		"section_count": survey.sections.size(),
		"question_count": survey.total_questions(),
		"fake_respondent_count": records.size(),
		"output_dir": survey_dir,
		"capture_scope": capture_scope,
		"journey_review": {
			"path": review_path,
			"save_error": review_save_error,
			"width": int((review_capture.get("image", null) as Image).get_width()) if review_capture.get("image", null) is Image else 0,
			"height": int((review_capture.get("image", null) as Image).get_height()) if review_capture.get("image", null) is Image else 0,
			"placeholder": bool(review_capture.get("placeholder", false))
		},
		"wrapped_page_count": pages.size(),
		"captured_wrapped_page_count": wrapped_pages.size(),
		"wrapped_pages": wrapped_pages
	}

func _wrap_options_for_fake_export(aggregate: Dictionary, respondent_count: int) -> Dictionary:
	var presets := [
		SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_SOFT_WHITE,
		SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_MINT,
		SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_SKY,
		SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_AURORA
	]
	var respondents: Array = aggregate.get("respondents", []) as Array
	var overrides: Dictionary = {}
	if not respondents.is_empty() and respondents[0] is Dictionary:
		overrides[str((respondents[0] as Dictionary).get("respondent_id", ""))] = "ff6b6b"
	return {
		"gradient_preset_id": presets[posmod(respondent_count, presets.size())],
		"respondent_color_overrides": overrides,
		"text_summary_mode": SURVEY_ANSWER_REVIEW.WRAP_TEXT_SUMMARY_AUTO
	}

func _capture_journey_review(survey: SurveyDefinition, template_path: String, answers: Dictionary) -> Dictionary:
	var viewport := _create_viewport(JOURNEY_VIEWPORT)
	var journey: Control = SURVEY_JOURNEY_SCENE.instantiate()
	journey.set("persist_selected_template", false)
	viewport.add_child(journey)
	_fit_control_to_viewport(journey, JOURNEY_VIEWPORT)
	await _await_frames(5)
	journey.call("_load_survey_from_path", template_path, false)
	await _await_frames(4)
	journey.set("answers", answers.duplicate(true))
	journey.call("_refresh_all_views")
	await _await_frames(3)
	journey.call("_open_review_view")
	await _await_frames(8)
	return await _finalize_capture(viewport)

func _capture_wrapped_page(page: Dictionary, pages_data: Dictionary) -> Dictionary:
	var viewport := _create_viewport(WRAPPED_VIEWPORT)
	var card = SURVEY_WRAPPED_CARD_SCRIPT.new()
	viewport.add_child(card)
	card.custom_minimum_size = Vector2(WRAPPED_VIEWPORT)
	card.size = Vector2(WRAPPED_VIEWPORT)
	card.configure_page(page, pages_data)
	card.refresh_layout(float(WRAPPED_VIEWPORT.x))
	await _await_frames(4)
	var layout_metrics: Dictionary = card.get_layout_metrics() if card.has_method("get_layout_metrics") else {}
	var capture := await _finalize_capture(viewport)
	capture["layout_metrics"] = layout_metrics
	return capture

func _create_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	viewport.size = viewport_size
	root.add_child(viewport)
	return viewport

func _fit_control_to_viewport(control: Control, viewport_size: Vector2i) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.custom_minimum_size = Vector2(viewport_size)
	control.size = Vector2(viewport_size)

func _finalize_capture(viewport: SubViewport) -> Dictionary:
	await _await_frames(2)
	var image: Image = null
	var placeholder := false
	if DisplayServer.get_name() == "headless":
		image = Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("eef6ff"))
		placeholder = true
	else:
		await RenderingServer.frame_post_draw
		var texture := viewport.get_texture()
		if texture != null:
			image = texture.get_image()
	if image == null:
		image = Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("eef6ff"))
		placeholder = true
	var dimensions := Vector2i(image.get_width(), image.get_height())
	viewport.queue_free()
	await process_frame
	return {
		"image": image,
		"width": dimensions.x,
		"height": dimensions.y,
		"placeholder": placeholder
	}

func _fake_records(survey: SurveyDefinition, respondent_count: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index in range(maxi(respondent_count, 1)):
		records.append({
			"source_name": "fake_respondent_%03d.json" % (index + 1),
			"answers": _fake_answers(survey, index)
		})
	return records

func _fake_answers(survey: SurveyDefinition, record_index: int) -> Dictionary:
	var answers: Dictionary = {}
	for section in survey.sections:
		for question in section.questions:
			answers[question.id] = _fake_answer(question, record_index)
	return answers

func _fake_answer(question: SurveyQuestion, record_index: int) -> Variant:
	match question.type:
		SurveyQuestion.TYPE_SHORT_TEXT:
			return "Demo response %d" % (record_index + 1)
		SurveyQuestion.TYPE_LONG_TEXT:
			return _long_text_answer(question, record_index)
		SurveyQuestion.TYPE_EMAIL:
			return "qa%d@ex.co" % (record_index + 1)
		SurveyQuestion.TYPE_DATE:
			return "2026-06-%02d" % ((record_index % 28) + 1)
		SurveyQuestion.TYPE_SINGLE_CHOICE, SurveyQuestion.TYPE_DROPDOWN:
			return _weighted_option_at(question, record_index)
		SurveyQuestion.TYPE_MULTI_CHOICE:
			return _multi_options(question, record_index)
		SurveyQuestion.TYPE_BOOLEAN:
			return record_index % 2 == 0
		SurveyQuestion.TYPE_SCALE, SurveyQuestion.TYPE_NPS, SurveyQuestion.TYPE_NUMBER:
			return _numeric_answer(question, record_index)
		SurveyQuestion.TYPE_RANKED_CHOICE:
			return _ranked_options(question, record_index)
		SurveyQuestion.TYPE_MATRIX:
			return _matrix_answer(question, record_index)
	return "Fake answer %d" % (record_index + 1)

func _option_at(question: SurveyQuestion, offset: int) -> String:
	if question.options.is_empty():
		return "Option %d" % (offset + 1)
	return str(question.options[offset % question.options.size()])

func _weighted_option_at(question: SurveyQuestion, offset: int) -> String:
	var weighted: Array = WEIGHTED_OPTIONS_BY_QUESTION.get(question.id, [])
	if not weighted.is_empty():
		return str(weighted[offset % weighted.size()])
	return _option_at(question, offset)

func _long_text_answer(question: SurveyQuestion, record_index: int) -> String:
	var samples: Array = MAPLESTORY_LONG_TEXT_BY_QUESTION.get(question.id, [])
	if not samples.is_empty():
		return str(samples[record_index % samples.size()])
	return "Synthetic longer answer %d with enough detail to preview wrapping, spacing, and summary behavior for this survey." % (record_index + 1)

func _multi_options(question: SurveyQuestion, record_index: int) -> Array[String]:
	var selected: Array[String] = []
	if question.options.is_empty():
		selected.append("Option %d" % (record_index + 1))
		return selected
	var count := clampi(1 + (record_index % mini(question.options.size(), 3)), 1, question.options.size())
	for offset in range(count):
		var option := str(question.options[(record_index + offset) % question.options.size()])
		if not selected.has(option):
			selected.append(option)
	return selected

func _numeric_answer(question: SurveyQuestion, record_index: int) -> int:
	var min_value := question.min_value
	var max_value := question.max_value
	if max_value <= min_value:
		return record_index + 1
	if question.type == SurveyQuestion.TYPE_NUMBER:
		var demo_numbers := [12, 25, 40]
		return clampi(int(demo_numbers[record_index % demo_numbers.size()]), min_value, max_value)
	var ratios := [0.35, 0.65, 0.9]
	var ratio := float(ratios[record_index % ratios.size()])
	return clampi(int(round(float(min_value) + (float(max_value - min_value) * ratio))), min_value, max_value)

func _ranked_options(question: SurveyQuestion, record_index: int) -> Array[String]:
	var ranked: Array[String] = []
	for index in range(question.options.size()):
		ranked.append(str(question.options[(index + record_index) % question.options.size()]))
	if ranked.is_empty():
		ranked.append("First choice")
	return ranked

func _matrix_answer(question: SurveyQuestion, record_index: int) -> Dictionary:
	var answer: Dictionary = {}
	for row_index in range(question.rows.size()):
		var row_name := str(question.rows[row_index])
		answer[row_name] = _option_at(question, row_index + record_index)
	return answer

func _builtin_template_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(TEMPLATE_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			paths.append(TEMPLATE_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths

func _proof_options_from_args() -> Dictionary:
	var options := {
		"respondent_counts": [DEFAULT_FAKE_RESPONDENT_COUNT],
		"capture_scope": CAPTURE_SCOPE_FULL,
		"survey_filter": ""
	}
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value).strip_edges()
		if argument.begins_with("--respondents="):
			options["respondent_counts"] = _parse_respondent_counts(argument.get_slice("=", 1))
		elif argument.begins_with("--counts="):
			options["respondent_counts"] = _parse_respondent_counts(argument.get_slice("=", 1))
		elif argument == "--sample-pages-only":
			options["capture_scope"] = CAPTURE_SCOPE_SAMPLE
		elif argument.begins_with("--survey="):
			options["survey_filter"] = argument.get_slice("=", 1).strip_edges()
		elif argument.begins_with("--template="):
			options["survey_filter"] = argument.get_slice("=", 1).strip_edges()
	if (options.get("respondent_counts", []) as Array).is_empty():
		options["respondent_counts"] = [DEFAULT_FAKE_RESPONDENT_COUNT]
	return options

func _parse_respondent_counts(value: String) -> Array[int]:
	var counts: Array[int] = []
	for part in value.split(",", false):
		var clean := str(part).strip_edges()
		if not clean.is_valid_int():
			continue
		var count := clampi(int(clean), 1, 1000)
		if not counts.has(count):
			counts.append(count)
	if counts.is_empty():
		counts.append(DEFAULT_FAKE_RESPONDENT_COUNT)
	return counts

func _survey_matches_filter(survey: SurveyDefinition, template_path: String, survey_filter: String) -> bool:
	if survey_filter.is_empty():
		return true
	var normalized_filter := _safe_id(survey_filter)
	return _safe_id(survey.id) == normalized_filter \
		or _safe_id(survey.title) == normalized_filter \
		or _safe_id(template_path.get_file()) == normalized_filter \
		or _safe_id(template_path.get_file().get_basename()) == normalized_filter

func _page_indices_to_capture(pages: Array, capture_scope: String) -> Array[int]:
	var indices: Array[int] = []
	if capture_scope != CAPTURE_SCOPE_SAMPLE:
		for index in range(pages.size()):
			indices.append(index)
		return indices
	if pages.is_empty():
		return indices
	indices.append(0)
	var last_index := pages.size() - 1
	if last_index > 0:
		indices.append(last_index)
	return indices

func _scenario_survey_total(scenarios: Array[Dictionary]) -> int:
	var total := 0
	for scenario in scenarios:
		total += int(scenario.get("survey_count", 0))
	return total

func _scenario_rejected_total(scenarios: Array[Dictionary]) -> int:
	var total := 0
	for scenario in scenarios:
		total += (scenario.get("rejected", []) as Array).size()
	return total

func _save_capture_image(capture: Dictionary, path: String) -> int:
	var image: Image = capture.get("image", null) as Image
	if image == null:
		return ERR_INVALID_DATA
	_prepare_output_directory(path.get_base_dir())
	return image.save_png(path)

func _prepare_output_directory(path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(path)
	if error != OK and not DirAccess.dir_exists_absolute(path):
		push_error("Failed to prepare output directory %s" % path)

func _write_json_file(path: String, payload: Variant) -> void:
	_prepare_output_directory(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _await_frames(count: int) -> void:
	for _index in range(maxi(count, 1)):
		await process_frame

func _trim_prompt(prompt: String, limit: int) -> String:
	var clean := prompt.strip_edges()
	if clean.length() <= limit:
		return clean
	return "%s..." % clean.substr(0, maxi(limit - 3, 0))

func _safe_stamp(value: String) -> String:
	return _safe_id(value.replace(":", "-").replace(" ", "_"))

func _safe_id(value: String) -> String:
	var safe := value.strip_edges().to_lower()
	if safe.is_empty():
		return "survey"
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		safe = safe.replace(token, "_")
	while safe.contains("__"):
		safe = safe.replace("__", "_")
	return safe.trim_prefix("_").trim_suffix("_")

func _vector2i_dict(value: Vector2i) -> Dictionary:
	return {
		"width": value.x,
		"height": value.y
	}
