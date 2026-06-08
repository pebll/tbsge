class_name AiDrafter
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

const UNIT_TYPES: Array[String] = [
	"AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT",
]

static func build_draft_commands(
	session: MinigameSession,
	team_id: String,
	rng: RandomNumberGenerator
) -> Array:
	var commands: Array = []
	var draft = session.drafts.get(team_id)
	if draft == null:
		return commands

	var slots: Array = session.get_deploy_slots(team_id)
	if slots.is_empty():
		commands.append({"type": "draft_ready", "team": team_id})
		return commands

	var shuffled: Array = slots.duplicate()
	shuffled.shuffle()

	var original_budget := int(draft.remaining_budget)
	var budget_left := original_budget
	var slot_budget := rng.randi_range(1, shuffled.size())
	for i in range(mini(slot_budget, shuffled.size())):
		if budget_left <= 0:
			break
		draft.remaining_budget = budget_left
		var coords: Vector2i = shuffled[i]
		var unit_type := _pick_unit_type_for_budget(budget_left, rng)
		if unit_type.is_empty():
			break
		var unit_count := _pick_unit_count(
			session, team_id, coords, unit_type, draft, rng, budget_left
		)
		if unit_count < 1:
			continue
		var cost := MinigameRulesScript.legion_cost(unit_type, unit_count)
		commands.append({
			"type": "draft_set_legion",
			"team": team_id,
			"coords": coords,
			"unit_type": unit_type,
			"unit_count": unit_count,
		})
		budget_left -= cost

	draft.remaining_budget = original_budget
	commands.append({"type": "draft_ready", "team": team_id})
	return commands

static func _pick_unit_type_for_budget(budget_left: int, rng: RandomNumberGenerator) -> String:
	var affordable: Array[String] = []
	for unit_type in UNIT_TYPES:
		if MinigameRulesScript.unit_price(unit_type) <= budget_left:
			affordable.append(unit_type)
	if affordable.is_empty():
		return ""
	return affordable[rng.randi() % affordable.size()]

static func _pick_unit_count(
	session: MinigameSession,
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	draft,
	rng: RandomNumberGenerator,
	budget_left: int
) -> int:
	var max_count := MinigameRulesScript.max_units_in_legion(
		unit_type, session.config.max_legion_fill
	)
	var count := rng.randi_range(1, max_count)
	while count >= 1:
		var cost := MinigameRulesScript.legion_cost(unit_type, count)
		if cost > budget_left:
			count -= 1
			continue
		var err := MinigameRulesScript.validate_draft_placement(
			team_id,
			coords,
			unit_type,
			count,
			draft,
			session.get_deploy_slots(team_id),
			session.config.max_legion_fill,
			session.grid
		)
		if err.is_empty():
			return count
		count -= 1
	return 0
