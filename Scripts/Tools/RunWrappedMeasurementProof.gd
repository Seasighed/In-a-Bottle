extends SceneTree

const SURVEY_ANSWER_REVIEW = preload("res://Scripts/Survey/SurveyAnswerReview.gd")
const SURVEY_ANSWER_WRAPPED_CARD_SCRIPT = preload("res://Scripts/UI/SurveyAnswerWrappedCard.gd")
const SURVEY_UI_FLOW_FIXTURES = preload("res://Scripts/Tools/SurveyUiFlowFixtures.gd")
const SURVEY_VISUAL_AUDIT_RUNNER = preload("res://Scripts/Tools/SurveyVisualAuditRunner.gd")

const OUTPUT_DIR := "res://exports/wrapped_text_measurement"
const PAGE_SIZE := Vector2i(1080, 1920)
const EXPECTED_QUESTION_TYPES := [
	"short_text",
	"long_text",
	"single_choice",
	"multi_choice",
	"boolean",
	"scale",
	"ranked_choice",
	"dropdown",
	"email",
	"number",
	"date",
	"nps",
	"matrix"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	_prepare_output_directory(output_dir)
	var runner := SURVEY_VISUAL_AUDIT_RUNNER.new()
	root.add_child(runner)
	var survey: SurveyDefinition = SURVEY_UI_FLOW_FIXTURES.load_default_survey()
	if survey == null:
		push_error("Could not load the default survey for wrapped measurement proof.")
		quit(1)
		return
	var light_pages: Dictionary = runner.call("_sample_answer_review_pages_data", survey, SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT)
	var dark_pages: Dictionary = runner.call("_sample_answer_review_pages_data", survey, SURVEY_ANSWER_REVIEW.WRAP_THEME_DARK)
	var word_tally_pages: Dictionary = _word_tally_pages_data(survey)
	var proof_specs := [
		{"id": "phone_light_first", "pages_data": light_pages, "page_index": 0},
		{"id": "phone_dark_first", "pages_data": dark_pages, "page_index": 0},
		{"id": "phone_light_word_tallies", "pages_data": word_tally_pages, "wrapped_renderer": "text_word_tallies"},
		{"id": "phone_light_matrix", "pages_data": light_pages, "wrapped_renderer": "matrix_summary"},
		{"id": "phone_light_ranked", "pages_data": light_pages, "wrapped_renderer": "ranked_summary"},
		{"id": "phone_light_stats", "pages_data": light_pages, "page_kind": "stats"}
	]
	proof_specs.append_array(_question_type_proof_specs(light_pages))
	var question_type_coverage := _question_type_coverage(proof_specs)
	var report_entries: Array[Dictionary] = []
	for spec in proof_specs:
		var capture := await _capture_proof_page(spec as Dictionary, output_dir)
		report_entries.append(capture)
	var report := {
		"format": "survey_wrapped_measurement_proof_v1",
		"generated_at": Time.get_datetime_string_from_system(true),
		"display_server": DisplayServer.get_name(),
		"page_width": PAGE_SIZE.x,
		"page_height": PAGE_SIZE.y,
		"question_type_coverage": question_type_coverage,
		"captures": report_entries
	}
	var report_path := output_dir.path_join("measurement_report.json")
	_write_json_file(report_path, report)
	runner.queue_free()
	print("WRAPPED_MEASUREMENT_PROOF=%s" % JSON.stringify({
		"ok": true,
		"output_dir": output_dir,
		"report_path": report_path,
		"capture_count": report_entries.size()
	}))
	quit(0)

func _word_tally_pages_data(survey: SurveyDefinition) -> Dictionary:
	var text_values := [
		"Clear onboarding and compact sharing made the wrap useful.",
		"Useful sharing helped the review feel clear.",
		"Polish made the compact summary easier to share.",
		"Clear goals and helpful polish improved the review.",
		"Sharing the compact wrap felt useful and polished."
	]
	var records: Array[Dictionary] = []
	for index in range(text_values.size()):
		var answers := SURVEY_UI_FLOW_FIXTURES.sample_complete_answers(survey)
		for section in survey.sections:
			for question in section.questions:
				if question.type == SurveyQuestion.TYPE_SHORT_TEXT or question.type == SurveyQuestion.TYPE_LONG_TEXT:
					answers[question.id] = text_values[index]
		records.append({"source_name": "word_tally_%d.json" % (index + 1), "answers": answers})
	var aggregate: Dictionary = SURVEY_ANSWER_REVIEW.build_aggregate(survey, records)
	return SURVEY_ANSWER_REVIEW.build_wrapped_pages_data(
		survey,
		aggregate,
		true,
		{},
		SURVEY_ANSWER_REVIEW.WRAP_THEME_LIGHT,
		{"gradient_preset_id": SURVEY_ANSWER_REVIEW.WRAP_GRADIENT_AURORA}
	)

func _capture_proof_page(spec: Dictionary, output_dir: String) -> Dictionary:
	var pages_data: Dictionary = spec.get("pages_data", {}) as Dictionary
	var pages: Array = pages_data.get("pages", [])
	var page_index := clampi(int(spec.get("page_index", 0)), 0, maxi(pages.size() - 1, 0))
	var requested_kind := str(spec.get("page_kind", "")).strip_edges()
	if not requested_kind.is_empty():
		for index in range(pages.size()):
			if pages[index] is Dictionary and str((pages[index] as Dictionary).get("page_kind", "")) == requested_kind:
				page_index = index
				break
	var requested_renderer := str(spec.get("wrapped_renderer", "")).strip_edges()
	if not requested_renderer.is_empty():
		var found := false
		for index in range(pages.size()):
			if not (pages[index] is Dictionary):
				continue
			var page: Dictionary = pages[index] as Dictionary
			for question_value in page.get("questions", []) as Array:
				if question_value is Dictionary and str((question_value as Dictionary).get("wrapped_renderer", "")) == requested_renderer:
					page_index = index
					found = true
					break
			if found:
				break
	var page: Dictionary = pages[page_index] as Dictionary if pages.size() > 0 and pages[page_index] is Dictionary else pages_data
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	viewport.size = PAGE_SIZE
	root.add_child(viewport)
	var card = SURVEY_ANSWER_WRAPPED_CARD_SCRIPT.new()
	viewport.add_child(card)
	card.custom_minimum_size = Vector2(PAGE_SIZE)
	card.size = Vector2(PAGE_SIZE)
	card.configure_page(page, pages_data)
	card.refresh_layout(float(PAGE_SIZE.x))
	for _frame in range(4):
		await process_frame
	var metrics: Dictionary = card.get_layout_metrics() if card.has_method("get_layout_metrics") else {}
	var image: Image
	var placeholder := false
	if DisplayServer.get_name() == "headless":
		image = Image.create(PAGE_SIZE.x, PAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("101826") if str(page.get("theme_id", pages_data.get("theme_id", ""))) == SURVEY_ANSWER_REVIEW.WRAP_THEME_DARK else Color("eef6ff"))
		placeholder = true
	else:
		await RenderingServer.frame_post_draw
		image = viewport.get_texture().get_image()
	if image == null:
		image = Image.create(PAGE_SIZE.x, PAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("eef6ff"))
		placeholder = true
	var file_name := "%s.png" % str(spec.get("id", "wrapped_page"))
	var image_path := output_dir.path_join(file_name)
	image.save_png(image_path)
	viewport.queue_free()
	await process_frame
	return {
		"id": str(spec.get("id", "")),
		"image_path": image_path,
		"placeholder": placeholder,
		"page_number": int(page.get("page_number", page_index + 1)),
		"page_kind": str(page.get("page_kind", "")),
		"section_id": str(page.get("section_id", "")),
		"question_type": str(spec.get("question_type", "")),
		"renderer": requested_renderer,
		"layout_metrics": metrics
	}

func _question_type_proof_specs(pages_data: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var seen: Dictionary = {}
	for page_value in pages_data.get("pages", []) as Array:
		if not (page_value is Dictionary):
			continue
		var source_page: Dictionary = page_value as Dictionary
		if str(source_page.get("page_kind", "")) != "answers":
			continue
		for question_value in source_page.get("questions", []) as Array:
			if not (question_value is Dictionary):
				continue
			var question: Dictionary = question_value as Dictionary
			var question_type := str(question.get("question_type", "")).strip_edges()
			if question_type.is_empty() or seen.has(question_type):
				continue
			seen[question_type] = true
			specs.append({
				"id": "question_type_%s" % _safe_id(question_type),
				"pages_data": _single_question_pages_data(pages_data, source_page, question),
				"question_type": question_type,
				"page_index": 0
			})
	return specs

func _single_question_pages_data(source_pages_data: Dictionary, source_page: Dictionary, question: Dictionary) -> Dictionary:
	var pages_data: Dictionary = source_pages_data.duplicate(true)
	var page: Dictionary = source_page.duplicate(true)
	page["questions"] = [question.duplicate(true)]
	page["title"] = str(source_pages_data.get("survey_title", source_page.get("title", "Survey")))
	page["subtitle"] = "%s · %s" % [str(source_page.get("section_title", source_page.get("subtitle", "Section"))), str(question.get("question_type", "question"))]
	page["page_number"] = 1
	page["page_count"] = 1
	page["section_part_number"] = 1
	page["section_part_count"] = 1
	page["file_name"] = "question_type_%s.png" % _safe_id(str(question.get("question_type", "question")))
	pages_data["pages"] = [page]
	pages_data["page_count"] = 1
	return pages_data

func _question_type_coverage(proof_specs: Array) -> Dictionary:
	var covered: Array[String] = []
	for spec_value in proof_specs:
		if not (spec_value is Dictionary):
			continue
		var question_type := str((spec_value as Dictionary).get("question_type", "")).strip_edges()
		if not question_type.is_empty() and not covered.has(question_type):
			covered.append(question_type)
	var missing: Array[String] = []
	for expected in EXPECTED_QUESTION_TYPES:
		if not covered.has(expected):
			missing.append(expected)
	covered.sort()
	missing.sort()
	return {
		"expected": EXPECTED_QUESTION_TYPES.duplicate(),
		"covered": covered,
		"missing": missing,
		"covered_count": covered.size(),
		"expected_count": EXPECTED_QUESTION_TYPES.size()
	}

func _safe_id(value: String) -> String:
	var safe := value.strip_edges().to_lower()
	if safe.is_empty():
		return "question"
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		safe = safe.replace(token, "_")
	while safe.contains("__"):
		safe = safe.replace("__", "_")
	return safe.trim_prefix("_").trim_suffix("_")

func _prepare_output_directory(path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(path)
	if error != OK and not DirAccess.dir_exists_absolute(path):
		push_error("Failed to prepare output directory %s" % path)

func _write_json_file(path: String, payload: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
