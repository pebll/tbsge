class_name TooltipContent
extends RefCounted

var title: String = ""
var body: String = ""
var icon: Texture2D = null
## Keyword ids shown as chips (glossary lookups).
var keywords: Array[String] = []
var footer: String = ""

static func for_keyword(keyword_id: String) -> TooltipContent:
	var c := TooltipContent.new()
	c.title = KeywordDefs.get_label(keyword_id)
	c.body = KeywordDefs.get_definition(keyword_id)
	if c.body.is_empty():
		c.body = "No definition yet."
	return c

static func for_stat(stat_id: String, value_text: String = "") -> TooltipContent:
	var c := TooltipContent.new()
	match stat_id:
		"attack":
			c.title = "Melee attack"
			c.body = "Damage dealt in close combat."
		"ranged_attack":
			c.title = "Ranged attack"
			c.body = "Damage dealt by ranged attacks."
		"health":
			c.title = "Health"
			c.body = "Hit points per unit. Legions die when all units fall."
		"unit_count":
			c.title = "Unit count"
			c.body = "How many units are in this legion right now."
		"ap":
			c.title = KeywordDefs.get_label("ap")
			c.body = KeywordDefs.get_definition("ap")
			c.keywords = ["ap"]
		"size":
			c.title = "Size"
			c.body = "How much of a legion's capacity one unit fills (cap 12)."
		"price":
			c.title = "Price"
			c.body = "Gold cost per individual unit when drafting."
		"shield":
			c.title = "Shield"
			c.body = "Absorbs damage from the first hit each unit takes per team turn."
		"range":
			c.title = KeywordDefs.get_label("range")
			c.body = KeywordDefs.get_definition("range")
			c.keywords = ["range"]
		_:
			c.title = stat_id.capitalize()
			c.body = value_text if not value_text.is_empty() else "Inspect this stat."
	if not value_text.is_empty() and stat_id not in ["ap", "range"]:
		c.body = "%s\nCurrent: %s" % [c.body, value_text]
	elif not value_text.is_empty():
		c.footer = "Current: %s" % value_text
	return c

static func for_action(
	action: ActionDefinition,
	legion: Legion = null
) -> TooltipContent:
	var c := TooltipContent.new()
	if action == null:
		c.title = "Unknown"
		c.body = "No action."
		return c
	c.title = action.display_name
	c.icon = action.icon
	c.body = _action_body(action, legion)
	c.keywords = _action_keywords(action)
	var ap := ActionParams.resolve_int(legion, action, "ap_cost", action.ap_cost)
	c.footer = "Cost: %d AP" % ap
	var rem := 0
	if legion:
		rem = legion.get_cooldown_remaining(action.id)
	if rem > 0:
		c.footer += " · Ready in %d" % rem
	else:
		var base_cd := ActionParams.resolve_int(legion, action, "cooldown", action.cooldown)
		if base_cd > 0:
			c.footer += " · Cooldown %d" % base_cd
	return c

static func _action_body(action: ActionDefinition, legion: Legion) -> String:
	if not action.tooltip_body.is_empty():
		return _fill_param_tokens(action.tooltip_body, action, legion)
	match action.id:
		"move":
			return "Move to an adjacent hex, or swap with an adjacent ally."
		"melee_attack":
			return "Strike an adjacent enemy. Ends this legion's turn."
		"ranged_attack":
			return "Shoot an enemy within range. Ends this legion's turn."
		"self_heal":
			var heal := ActionParams.resolve_int(legion, action, "heal_amount", action.heal_amount)
			return "Each unit restores %d health to the lowest-health ally in this legion. Ends this legion's turn." % heal
		"heal_ally":
			var heal := ActionParams.resolve_int(legion, action, "heal_amount", action.heal_amount)
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			return "Each unit heals the lowest-health ally within %d hexes for %d health. Ends this legion's turn." % [rng, heal]
		"teleport":
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			return "Blink to an empty tile within %d hexes. Costs 1 AP (does not end the turn)." % rng
		_:
			return "Use this action."

static func _fill_param_tokens(template: String, action: ActionDefinition, legion: Legion) -> String:
	var text := template
	var heal := ActionParams.resolve_int(legion, action, "heal_amount", action.heal_amount)
	var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
	text = text.replace("{heal}", str(heal))
	text = text.replace("{range}", str(rng))
	text = text.replace("{ap}", str(ActionParams.resolve_int(legion, action, "ap_cost", action.ap_cost)))
	return text

static func _action_keywords(action: ActionDefinition) -> Array[String]:
	var out: Array[String] = []
	for kid in action.keywords:
		if kid not in out:
			out.append(kid)
	if action.terminal and "terminal" not in out:
		out.append("terminal")
	if "ap" not in out:
		out.append("ap")
	if action.target_range > 0 and "range" not in out:
		out.append("range")
	if action.cooldown > 0 and "cooldown" not in out:
		out.append("cooldown")
	return out
