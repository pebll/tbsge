class_name AiDrafter
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const DraftPlacementScript = preload("res://scripts/minigame/draft_placement.gd")

const MIN_LEGIONS := 2
const RANDOM_PLACEMENT_ATTEMPTS := 24
const RANDOM_EXTRA_SPEND_ATTEMPTS := 32

static func build_draft_commands(
	session,
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
	var placements: Dictionary = {}
	var budget_left := int(draft.remaining_budget)
	var shuffled_slots := slots.duplicate()
	_shuffle(shuffled_slots, rng)

	var cheapest := _cheapest_unit_price()
	var max_legions := mini(
		shuffled_slots.size(),
		maxi(MIN_LEGIONS, budget_left / maxi(1, cheapest))
	)
	var legion_count := rng.randi_range(MIN_LEGIONS, max_legions)

	for coords in shuffled_slots:
		if placements.size() >= legion_count:
			break
		var placement := _try_random_placement(
			session, team_id, coords, draft, slots, placements, budget_left, rng, false
		)
		if placement.is_empty():
			continue
		budget_left = _apply_simulated_placement(placements, placement, draft, budget_left, snapshot)

	if placements.size() < MIN_LEGIONS:
		placements.clear()
		budget_left = int(snapshot["remaining_budget"])
		_sync_draft_simulation(draft, placements, budget_left, snapshot)
		for coords in shuffled_slots:
			if placements.size() >= MIN_LEGIONS:
				break
			var placement := _try_minimal_placement(
				session, team_id, coords, draft, slots, placements, budget_left
			)
			if placement.is_empty():
				continue
			budget_left = _apply_simulated_placement(placements, placement, draft, budget_left, snapshot)

	var extra_attempts := RANDOM_EXTRA_SPEND_ATTEMPTS
	while budget_left >= cheapest and extra_attempts > 0:
		extra_attempts -= 1
		if placements.size() >= shuffled_slots.size() and rng.randf() > 0.35:
			break
		if rng.randf() > 0.55:
			continue
		var coords: Vector2i = shuffled_slots[rng.randi() % shuffled_slots.size()]
		var allow_replace := placements.has(coords) or rng.randf() < 0.65
		var placement := _try_random_placement(
			session, team_id, coords, draft, slots, placements, budget_left, rng, allow_replace
		)
		if placement.is_empty():
			continue
		budget_left = _apply_simulated_placement(placements, placement, draft, budget_left, snapshot)

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

static func _try_random_placement(
	session,
	team_id: String,
	coords: Vector2i,
	draft,
	slots: Array,
	placements: Dictionary,
	budget_left: int,
	rng: RandomNumberGenerator,
	allow_replace: bool
) -> Dictionary:
	if placements.has(coords) and not allow_replace:
		return {}

	var unit_types := UnitDefs.get_all_ids()
	_shuffle(unit_types, rng)
	for _attempt in range(RANDOM_PLACEMENT_ATTEMPTS):
		var unit_type: String = unit_types[rng.randi() % unit_types.size()]
		var placement := _random_count_placement(
			session,
			team_id,
			coords,
			unit_type,
			draft,
			slots,
			placements,
			budget_left,
			rng
		)
		if not placement.is_empty():
			return placement
	return {}

static func _try_minimal_placement(
	session,
	team_id: String,
	coords: Vector2i,
	draft,
	slots: Array,
	placements: Dictionary,
	budget_left: int
) -> Dictionary:
	if placements.has(coords):
		return {}

	var best_price := 0
	var candidates: Array[String] = []
	for unit_type in UnitDefs.get_all_ids():
		var price := MinigameRulesScript.unit_price(unit_type)
		if price <= 0 or price > budget_left:
			continue
		if best_price == 0 or price < best_price:
			best_price = price
			candidates = [unit_type]
		elif price == best_price:
			candidates.append(unit_type)

	for unit_type in candidates:
		var placement := _random_count_placement(
			session,
			team_id,
			coords,
			unit_type,
			draft,
			slots,
			placements,
			budget_left,
			null,
			1,
			1
		)
		if not placement.is_empty():
			return placement
	return {}

static func _random_count_placement(
	session,
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	draft,
	slots: Array,
	placements: Dictionary,
	budget_left: int,
	rng: RandomNumberGenerator = null,
	min_count: int = 1,
	max_count_override: int = -1
) -> Dictionary:
	var current_cost := 0
	if placements.has(coords):
		var current: Dictionary = placements[coords]
		current_cost = MinigameRulesScript.legion_cost(current["unit_type"], current["unit_count"])

	var max_count := MinigameRulesScript.max_units_in_legion(
		unit_type, session.config.max_legion_fill
	)
	if max_count_override > 0:
		max_count = mini(max_count, max_count_override)

	var price := MinigameRulesScript.unit_price(unit_type)
	if price <= 0:
		return {}

	var affordable_max := (budget_left + current_cost) / price
	max_count = mini(max_count, affordable_max)
	var lowest := maxi(1, min_count)
	if max_count < lowest:
		return {}

	var count := lowest
	if max_count > lowest:
		count = (
			lowest
			if rng == null
			else rng.randi_range(lowest, max_count)
		)

	var spend := MinigameRulesScript.legion_cost(unit_type, count) - current_cost
	if spend <= 0 or spend > budget_left:
		return {}

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
	if not err.is_empty():
		return {}

	return {
		"coords": coords,
		"unit_type": unit_type,
		"unit_count": count,
		"spend": spend,
	}

static func _apply_simulated_placement(
	placements: Dictionary,
	placement: Dictionary,
	draft,
	budget_left: int,
	snapshot: Dictionary
) -> int:
	placements[placement["coords"]] = {
		"unit_type": placement["unit_type"],
		"unit_count": placement["unit_count"],
	}
	var new_budget := budget_left - int(placement["spend"])
	_sync_draft_simulation(draft, placements, new_budget, snapshot)
	return new_budget

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

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
