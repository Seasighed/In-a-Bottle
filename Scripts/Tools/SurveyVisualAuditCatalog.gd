class_name SurveyVisualAuditCatalog
extends RefCounted

const SURVEY_UI_FLOW_CATALOG = preload("res://Scripts/Tools/SurveyUiFlowCatalog.gd")
const SURVEY_UI_FLOW_FIXTURES = preload("res://Scripts/Tools/SurveyUiFlowFixtures.gd")
const SURVEY_TEMPLATE_LOADER = preload("res://Scripts/Survey/SurveyTemplateLoader.gd")
const QUESTION_VIEW_REGISTRY = preload("res://Scripts/UI/QuestionViewRegistry.gd")
const SURVEY_PREVIEW_CONFIG = preload("res://Scripts/UI/SurveyPreviewConfig.gd")

const OUTPUT_DIRECTORY := "user://visual_audit"
const ZIP_EXPORT_DIR := "user://visual_audit_exports"
const PHONE_VIEWPORT_ID := "phone_430x932"
const DESKTOP_VIEWPORT_ID := "desktop_1600x900"
const QUESTION_CARD_VIEWPORT := Vector2i(760, 940)
const FEATURE_IMAGE_VIEWPORT := Vector2i(1280, 720)
const QA_STATES := ["qa_home", "qa_tutorial", "qa_checklist"]
const FEEDBACK_STATES := ["feedback_armed_capture", "feedback_report_popup", "feedback_review_panel"]

static func build_flow_graph() -> Dictionary:
	return SURVEY_UI_FLOW_CATALOG.build_graph()

static func build_flow_capture_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for node_value in SURVEY_UI_FLOW_CATALOG.build_nodes():
		if not (node_value is Dictionary):
			continue
		var node_spec: Dictionary = (node_value as Dictionary).duplicate(true)
		var node_id := str(node_spec.get("id", "")).strip_edges()
		if node_id.is_empty():
			continue
		specs.append({
			"id": "%s__baseline" % node_id,
			"group": "flow_nodes",
			"surface": node_id,
			"variant": "baseline",
			"viewport_preset": _flow_node_viewport_id(node_spec),
			"viewport_size": node_spec.get("viewport_size", Vector2i.ZERO),
			"entry_route": "flow_node",
			"state_tags": ["baseline"],
			"include_in_flow_chart": true,
			"source_node_id": node_id,
			"source_kind": str(node_spec.get("source_kind", "")),
			"state": str(node_spec.get("state", "")),
			"title": str(node_spec.get("title", node_id)),
			"description": str(node_spec.get("description", "")),
			"group_label": str(node_spec.get("group", "")),
			"preview_size": node_spec.get("preview_size", Vector2.ZERO)
		})
	return specs

static func build_bundle_capture_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	specs.append_array(_main_screen_specs())
	specs.append_array(_qa_overlay_specs())
	specs.append_array(_feedback_overlay_specs())
	specs.append_array(_question_type_specs())
	specs.append_array(_custom_view_specs())
	specs.append_array(_feature_export_specs())
	return specs

static func flow_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for node_value in SURVEY_UI_FLOW_CATALOG.build_nodes():
		if not (node_value is Dictionary):
			continue
		var node_id := str((node_value as Dictionary).get("id", "")).strip_edges()
		if node_id.is_empty():
			continue
		ids.append(node_id)
	return ids

static func question_family_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in QUESTION_VIEW_REGISTRY.gallery_definitions():
		var family_id := _slug(str(definition.get("type", "")))
		if family_id.is_empty():
			continue
		ids.append(family_id)
	return ids

static func discovered_custom_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var seen := {}
	for spec in _custom_view_specs():
		var scene_path := str(spec.get("scene_path", "")).strip_edges()
		if scene_path.is_empty() or seen.has(scene_path):
			continue
		seen[scene_path] = true
		paths.append(scene_path)
	return paths

static func qa_state_ids() -> Array[String]:
	return QA_STATES.duplicate()

static func feedback_state_ids() -> Array[String]:
	return FEEDBACK_STATES.duplicate()

static func _main_screen_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for node_value in SURVEY_UI_FLOW_CATALOG.build_nodes():
		if not (node_value is Dictionary):
			continue
		var node_spec: Dictionary = node_value as Dictionary
		var node_id := str(node_spec.get("id", "")).strip_edges()
		if node_id.is_empty():
			continue
		var source_kind := str(node_spec.get("source_kind", "")).strip_edges()
		if source_kind == "question_gallery":
			specs.append({
				"id": "%s__sheet" % node_id,
				"group": "screens",
				"surface": node_id,
				"variant": "sheet",
				"viewport_preset": "question_gallery_sheet",
				"viewport_size": node_spec.get("viewport_size", SURVEY_UI_FLOW_CATALOG.GALLERY_VIEWPORT),
				"entry_route": "flow_node",
				"state_tags": ["gallery", "shared_ui"],
				"include_in_flow_chart": false,
				"source_node_id": node_id,
				"source_kind": source_kind,
				"state": str(node_spec.get("state", "")),
				"title": str(node_spec.get("title", node_id)),
				"description": str(node_spec.get("description", ""))
			})
			continue
		var variants := [PHONE_VIEWPORT_ID, DESKTOP_VIEWPORT_ID]
		for viewport_id in variants:
			specs.append({
				"id": "%s__%s" % [node_id, viewport_id],
				"group": "screens",
				"surface": node_id,
				"variant": viewport_id,
				"viewport_preset": viewport_id,
				"viewport_size": _viewport_size_for_capture(viewport_id, node_spec.get("viewport_size", SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT) as Vector2i),
				"entry_route": "flow_node",
				"state_tags": ["responsive", "phone" if viewport_id == PHONE_VIEWPORT_ID else "desktop"],
				"include_in_flow_chart": false,
				"source_node_id": node_id,
				"source_kind": source_kind,
				"state": str(node_spec.get("state", "")),
				"title": str(node_spec.get("title", node_id)),
				"description": str(node_spec.get("description", ""))
			})
		if node_id == "journey_upload":
			specs.append_array(_journey_upload_variants(node_spec))
	return specs

static func _journey_upload_variants(node_spec: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for upload_variant in ["configured", "unconfigured"]:
		for viewport_id in [PHONE_VIEWPORT_ID, DESKTOP_VIEWPORT_ID]:
			specs.append({
				"id": "journey_upload__%s__%s" % [upload_variant, viewport_id],
				"group": "screens",
				"surface": "journey_upload",
				"variant": "%s_%s" % [upload_variant, viewport_id],
				"viewport_preset": viewport_id,
				"viewport_size": _viewport_size_for_capture(viewport_id, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT),
				"entry_route": "flow_node",
				"state_tags": ["responsive", "phone" if viewport_id == PHONE_VIEWPORT_ID else "desktop", upload_variant],
				"include_in_flow_chart": false,
				"source_node_id": "journey_upload",
				"source_kind": str(node_spec.get("source_kind", "")),
				"state": str(node_spec.get("state", "")),
				"upload_state": upload_variant,
				"title": str(node_spec.get("title", "Journey / Upload")),
				"description": str(node_spec.get("description", ""))
			})
	return specs

static func _qa_overlay_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for state_id in QA_STATES:
		for viewport_id in [PHONE_VIEWPORT_ID, DESKTOP_VIEWPORT_ID]:
			specs.append({
				"id": "%s__%s" % [state_id, viewport_id],
				"group": "screens",
				"surface": state_id,
				"variant": viewport_id,
				"viewport_preset": viewport_id,
				"viewport_size": _viewport_size_for_capture(viewport_id, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT),
				"entry_route": "qa_overlay",
				"state_tags": ["qa_mode", "overlay", "phone" if viewport_id == PHONE_VIEWPORT_ID else "desktop"],
				"include_in_flow_chart": false,
				"source_node_id": "",
				"title": state_id.replace("_", " ").capitalize()
			})
	return specs

static func _feedback_overlay_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for state_id in FEEDBACK_STATES:
		for viewport_id in [PHONE_VIEWPORT_ID, DESKTOP_VIEWPORT_ID]:
			specs.append({
				"id": "%s__%s" % [state_id, viewport_id],
				"group": "screens",
				"surface": state_id,
				"variant": viewport_id,
				"viewport_preset": viewport_id,
				"viewport_size": _viewport_size_for_capture(viewport_id, SURVEY_UI_FLOW_CATALOG.PHONE_VIEWPORT),
				"entry_route": "feedback_overlay",
				"state_tags": ["feedback", "overlay", "phone" if viewport_id == PHONE_VIEWPORT_ID else "desktop"],
				"include_in_flow_chart": false,
				"source_node_id": "",
				"title": state_id.replace("_", " ").capitalize()
			})
	return specs

static func _question_type_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for definition in QUESTION_VIEW_REGISTRY.gallery_definitions():
		var family_id := _slug(str(definition.get("type", "")))
		if family_id.is_empty():
			continue
		var base_question_config := _duplicate_variant(definition.get("question_config", {}))
		var answered_value := _duplicate_variant(definition.get("answer", null))
		var title := str(definition.get("title", family_id)).strip_edges()
		match family_id:
			"dropdown":
				specs.append(_question_type_spec(family_id, "collapsed", base_question_config, answered_value, title, str(definition.get("scene_path", ""))))
				specs.append(_question_type_spec(family_id, "expanded", base_question_config, answered_value, title, str(definition.get("scene_path", "")), ["expanded"]))
			"ranked_choice":
				specs.append(_question_type_spec(family_id, "initial", base_question_config, [], title, str(definition.get("scene_path", "")), ["blank"]))
				specs.append(_question_type_spec(family_id, "ordered", base_question_config, answered_value, title, str(definition.get("scene_path", "")), ["filled"]))
			"matrix":
				specs.append(_question_type_spec(family_id, "blank", base_question_config, {}, title, str(definition.get("scene_path", "")), ["blank"]))
				specs.append(_question_type_spec(family_id, "answered", base_question_config, answered_value, title, str(definition.get("scene_path", "")), ["filled"]))
			_:
				specs.append(_question_type_spec(family_id, "filled", base_question_config, answered_value, title, str(definition.get("scene_path", "")), ["filled"]))
	return specs

static func _custom_view_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var seen_scene_paths := {}
	for template_summary in SURVEY_TEMPLATE_LOADER.list_available_templates():
		var template_path := str(template_summary.get("path", "")).strip_edges()
		if template_path.is_empty():
			continue
		var survey: SurveyDefinition = SURVEY_TEMPLATE_LOADER.load_from_file(template_path)
		if survey == null:
			continue
		for section in survey.sections:
			for question in section.questions:
				if question == null or question.custom_view_scene == null:
					continue
				var scene_path := question.custom_view_scene.resource_path.strip_edges()
				if scene_path.is_empty():
					continue
				if scene_path == QUESTION_VIEW_REGISTRY.scene_path_for_type(question.type):
					continue
				if seen_scene_paths.has(scene_path):
					continue
				seen_scene_paths[scene_path] = true
				var scene_slug := _slug(scene_path.get_file().get_basename())
				specs.append({
					"id": "custom_view__%s__filled" % scene_slug,
					"group": "custom_views",
					"surface": scene_slug,
					"variant": "filled",
					"viewport_preset": "question_card",
					"viewport_size": QUESTION_CARD_VIEWPORT,
					"entry_route": "custom_view",
					"state_tags": ["filled", "custom_view"],
					"include_in_flow_chart": false,
					"source_node_id": "",
					"title": question.display_prompt(),
					"template_path": template_path,
					"scene_path": scene_path,
					"question_id": question.id,
					"question_type": str(question.type),
					"question": question,
					"answer": _duplicate_variant(SURVEY_UI_FLOW_FIXTURES.sample_complete_answer(question))
				})
	return specs

static func _feature_export_specs() -> Array[Dictionary]:
	return [
		{
			"id": "summary_image__default",
			"group": "features",
			"surface": "summary_image",
			"variant": "default",
			"viewport_preset": "feature_image",
			"viewport_size": FEATURE_IMAGE_VIEWPORT,
			"entry_route": "feature_export",
			"state_tags": ["summary", "exportable_image"],
			"include_in_flow_chart": false,
			"source_node_id": "",
			"title": "Summary Export Card"
		},
		{
			"id": "profile_image__default",
			"group": "features",
			"surface": "profile_image",
			"variant": "default",
			"viewport_preset": "feature_image",
			"viewport_size": FEATURE_IMAGE_VIEWPORT,
			"entry_route": "feature_export",
			"state_tags": ["profile", "exportable_image"],
			"include_in_flow_chart": false,
			"source_node_id": "",
			"title": "Profile Export Card"
		}
	]

static func _question_type_spec(family_id: String, variant: String, question_config: Variant, answer_value: Variant, title: String, scene_path: String, tags: Array[String] = []) -> Dictionary:
	return {
		"id": "question_type__%s__%s" % [family_id, variant],
		"group": "question_types",
		"surface": family_id,
		"variant": variant,
		"viewport_preset": "question_card",
		"viewport_size": QUESTION_CARD_VIEWPORT,
		"entry_route": "question_type",
		"state_tags": tags.duplicate(),
		"include_in_flow_chart": false,
		"source_node_id": "",
		"title": title,
		"scene_path": scene_path,
		"question_config": question_config,
		"answer": answer_value
	}

static func _flow_node_viewport_id(node_spec: Dictionary) -> String:
	var source_kind := str(node_spec.get("source_kind", "")).strip_edges()
	if source_kind == "question_gallery":
		return "question_gallery_sheet"
	return PHONE_VIEWPORT_ID

static func _viewport_size_for_capture(viewport_id: String, fallback: Vector2i) -> Vector2i:
	var preset_size := SURVEY_PREVIEW_CONFIG.resolution_size(viewport_id)
	return preset_size if preset_size != Vector2i.ZERO else fallback

static func _slug(raw_value: String) -> String:
	var value := raw_value.strip_edges().to_lower()
	if value.is_empty():
		return ""
	for token in [":", "/", "\\", " ", ".", ",", ";", "\"", "'", "?", "!", "(", ")", "[", "]", "{", "}"]:
		value = value.replace(token, "_")
	while value.contains("__"):
		value = value.replace("__", "_")
	return value.trim_prefix("_").trim_suffix("_")

static func _duplicate_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_STRING_ARRAY:
			return (value as PackedStringArray).duplicate()
	return value
