class_name AiDrafter
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const DraftPlacementScript = preload("res://scripts/minigame/draft_placement.gd")

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

	var snapshot := _snapshot_draft(draft)
	var budget_left := int(draft.remaining_budget)
	var placements: Dictionary = {}

	while budget_left >= _cheapest_unit_price():
		_sync_draft_simulation(draft, placements, budget_left, snapshot)
		var action := _find_best_spend_action(
			session, team_id, slots, placements, draft, rng, budget_left
		)
		if action.is_empty():
			break
		var coords: Vector2i = action["coords"]
		placements[coords] = {
			"unit_type": action["unit_type"],
			"unit_count": action["unit_count"],
		}
		budget_left -= int(action["spend"])

	_restore_draft(draft, snapshot)

	for coords in placements.keys():
		var placement: Dictionary = placements[coords]
		commands.append({
			"type": "draft_set_legion",
			"team": team_id,
			"coords": coords,
			"unit_type": placement["unit_type"],
			"unit_count": placement["unit_count"],
		})

	commands.append({"type": "draft_ready", "team": team_id})
	return commands

static func _cheapest_unit_price() -> int:
	var cheapest := 0
	for unit_type in UnitDefs.get_all_ids():
		var price := MinigameRulesScript.unit_price(unit_type)
		if price <= 0:
			continue
		if cheapest == 0 or price < cheapest:
			cheapest = price
	return cheapest

static func _find_best_spend_action(
	session: MinigameSession,
	team_id: String,
	slots: Array,
	placements: Dictionary,
	draft,
	rng: RandomNumberGenerator,
	budget_left: int
) -> Dictionary:
	var best_spend := 0
	var candidates: Array[Dictionary] = []

	for coords in slots:
		if not placements.has(coords):
			for unit_type in UnitDefs.get_all_ids():
				var placement := _best_new_placement(
					session, team_id, coords, unit_type, draft, slots, budget_left
				)
				if placement.is_empty():
					continue
				var spend: int = placement["spend"]
				if spend > best_spend:
					best_spend = spend
					candidates.clear()
					candidates.append(placement)
				elif spend == best_spend:
					candidates.append(placement)
		else:
			var current: Dictionary = placements[coords]
			var current_cost := MinigameRulesScript.legion_cost(
				current["unit_type"], current["unit_count"]
			)
			for unit_type in UnitDefs.get_all_ids():
				var placement := _best_upgrade_placement(
					session,
					team_id,
					coords,
					unit_type,
					current_cost,
					draft,
					slots,
					budget_left
				)
				if placement.is_empty():
					continue
				var spend: int = placement["spend"]
				if spend > best_spend:
					best_spend = spend
					candidates.clear()
					candidates.append(placement)
				elif spend == best_spend:
					candidates.append(placement)

	if candidates.is_empty():
		return {}

	return candidates[rng.randi() % candidates.size()]

static func _best_new_placement(
	session: MinigameSession,
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	draft,
	slots: Array,
	budget_left: int
) -> Dictionary:
	var max_count := MinigameRulesScript.max_units_in_legion(
		unit_type, session.config.max_legion_fill
	)
	for count in range(max_count, 0, -1):
		var cost := MinigameRulesScript.legion_cost(unit_type, count)
		if cost > budget_left:
			continue
		var err := MinigameRulesScript.validate_draft_placement(
			team_id,
			coords,
			unit_type,
			count,
			draft,
			slots,
			session.config.max_legion_fill,
			session.grid
		)
		if err.is_empty():
			return {
				"coords": coords,
				"unit_type": unit_type,
				"unit_count": count,
				"spend": cost,
			}
	return {}

static func _best_upgrade_placement(
	session: MinigameSession,
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	current_cost: int,
	draft,
	slots: Array,
	budget_left: int
) -> Dictionary:
	var max_count := MinigameRulesScript.max_units_in_legion(
		unit_type, session.config.max_legion_fill
	)
	for count in range(max_count, 0, -1):
		var new_cost := MinigameRulesScript.legion_cost(unit_type, count)
		var spend := new_cost - current_cost
		if spend <= 0 or spend > budget_left:
			continue
		var err := MinigameRulesScript.validate_draft_placement(
			team_id,
			coords,
			unit_type,
			count,
			draft,
			slots,
			session.config.max_legion_fill,
			session.grid
		)
		if err.is_empty():
			return {
				"coords": coords,
				"unit_type": unit_type,
				"unit_count": count,
				"spend": spend,
			}
	return {}

static func _snapshot_draft(draft) -> Dictionary:
	var placement_snapshots: Array = []
	for placement in draft.placements:
		placement_snapshots.append(
			DraftPlacementScript.new(placement.coords, placement.unit_type, placement.unit_count)
		)
	return {
		"remaining_budget": int(draft.remaining_budget),
		"placements": placement_snapshots,
	}

static func _restore_draft(draft, snapshot: Dictionary) -> void:
	draft.remaining_budget = int(snapshot["remaining_budget"])
	draft.placements.clear()
	for placement in snapshot["placements"]:
		draft.placements.append(
			DraftPlacementScript.new(placement.coords, placement.unit_type, placement.unit_count)
		)

static func _sync_draft_simulation(
	draft,
	placements: Dictionary,
	budget_left: int,
	snapshot: Dictionary
) -> void:
	draft.remaining_budget = budget_left
	draft.placements.clear()
	for coords in placements.keys():
		var placement: Dictionary = placements[coords]
		draft.placements.append(
			DraftPlacementScript.new(
				coords,
				placement["unit_type"],
				placement["unit_count"]
			)
		)
