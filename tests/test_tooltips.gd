extends RefCounted

const ActionParamsScript = preload("res://scripts/actions/action_params.gd")
const TooltipContentScript = preload("res://scripts/ui/tooltip/tooltip_content.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_glossary_lookup():
		return false
	if not _test_action_params_defaults_and_overrides():
		return false
	if not _test_tooltip_content_for_action():
		return false
	if not _test_tooltip_content_for_keyword_and_stat():
		return false
	print("Success: Tooltip / glossary / action params tests")
	return true

func _test_glossary_lookup() -> bool:
	if not KeywordDefs.has_keyword("terminal"):
		push_error("Glossary missing terminal")
		return false
	var label := KeywordDefs.get_label("terminal")
	if label != "Terminal":
		push_error("Expected Terminal label, got %s" % label)
		return false
	var definition := KeywordDefs.get_definition("terminal")
	if definition.is_empty() or "turn" not in definition.to_lower():
		push_error("Terminal definition looks wrong: %s" % definition)
		return false
	if KeywordDefs.get_definition("not_a_real_keyword") != "":
		push_error("Unknown keyword should return empty definition")
		return false
	return true

func _test_action_params_defaults_and_overrides() -> bool:
	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	if heal_def == null:
		push_error("Missing self_heal def")
		return false
	var legion := Legion.new("GOBLIN", 1, Vector2i.ZERO, "team_a")
	var default_heal := ActionParamsScript.resolve_int(legion, heal_def, "heal_amount", -1)
	if default_heal != heal_def.heal_amount:
		push_error("Expected default heal_amount %d, got %d" % [heal_def.heal_amount, default_heal])
		return false

	var unit_def: UnitDefinition = UnitDefs.get_def("GOBLIN")
	if unit_def == null:
		push_error("Missing GOBLIN unit def")
		return false
	var original_params: Dictionary = unit_def.action_params.duplicate(true)
	unit_def.action_params = {
		"self_heal": {"heal_amount": 9},
	}
	var overridden := ActionParamsScript.resolve_int(legion, heal_def, "heal_amount", -1)
	unit_def.action_params = original_params
	if overridden != 9:
		push_error("Expected override heal_amount 9, got %d" % overridden)
		return false

	# Missing key falls back to action default.
	unit_def.action_params = {"self_heal": {"target_range": 3}}
	var still_default := ActionParamsScript.resolve_int(legion, heal_def, "heal_amount", -1)
	unit_def.action_params = original_params
	if still_default != heal_def.heal_amount:
		push_error("Missing override key should use action default")
		return false
	return true

func _test_tooltip_content_for_action() -> bool:
	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	var content = TooltipContentScript.for_action(heal_def, null)
	if content.title != heal_def.display_name:
		push_error("Tooltip title mismatch")
		return false
	if "health" not in content.body.to_lower() and "heal" not in content.body.to_lower():
		push_error("Heal tooltip body missing heal language: %s" % content.body)
		return false
	if "terminal" not in content.keywords:
		push_error("Heal tooltip should include terminal keyword")
		return false
	if "AP" not in content.footer and "ap" not in content.footer.to_lower():
		push_error("Heal tooltip footer should mention AP cost")
		return false
	return true

func _test_tooltip_content_for_keyword_and_stat() -> bool:
	var kw = TooltipContentScript.for_keyword("cooldown")
	if kw.title != "Cooldown":
		push_error("Keyword tooltip title wrong")
		return false
	if kw.body.is_empty():
		push_error("Keyword tooltip body empty")
		return false
	var stat = TooltipContentScript.for_stat("shield", "2")
	if "Shield" not in stat.title:
		push_error("Stat tooltip title wrong")
		return false
	if "2" not in stat.body and "2" not in stat.footer:
		push_error("Stat tooltip should include current value")
		return false
	return true
