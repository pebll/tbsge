extends RefCounted

## Whole-turn planner: simulation copies are independent, the end-of-turn value is sane,
## and planning never touches the live board.

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const TurnSimSession = preload("res://scripts/ai/planning/turn_sim_session.gd")
const TurnPlanner = preload("res://scripts/ai/planning/turn_planner.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_clone_is_independent():
		return false
	if not _test_clone_keeps_turn_state():
		return false
	if not _test_evaluate_prefers_damage_dealt():
		return false
	if not _test_planning_leaves_live_board_untouched():
		return false
	if not _test_planned_turn_plays_out():
		return false
	print("Success: AI turn planner tests")
	return true

func _board(specs: Array) -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for L in session.legions.duplicate():
		var tile: Tile = session.grid.get(L.tile_coords)
		if tile:
			tile.legion = null
		session.legions.erase(L)
	var out: Array[Legion] = []
	for spec in specs:
		var team: String = started["team_a"] if spec[0] == "a" else started["team_b"]
		var coords: Vector2i = spec[3]
		var legion := Legion.new(String(spec[1]), int(spec[2]), coords, team)
		legion.emit_global_events = false
		session.legions.append(legion)
		session.grid[coords].legion = legion
		legion.refresh_ap()
		out.append(legion)
	return {"session": session, "legions": out}

static func _snapshot(session) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for L in session.legions:
		var hp: PackedStringArray = PackedStringArray()
		for u in L.units:
			hp.append("%s/%d" % [u.current_health, u.shield_remaining])
		parts.append("%s@%s:%d:%s:%s:%s" % [
			L.team_id, L.tile_coords, L.current_ap, L.waited, ",".join(hp), str(L.action_cooldowns)
		])
	return ";".join(parts)

func _test_clone_is_independent() -> bool:
	var b := _board([
		["a", "GOBLIN", 2, Vector2i(0, 0)],
		["b", "GOBLIN", 2, Vector2i(1, 0)],
	])
	var session = b["session"]
	var before := _snapshot(session)
	var sim = TurnSimSession.clone_from(session)
	var r: Dictionary = sim.apply({
		"type": "use_action", "action_id": "melee_attack",
		"from": Vector2i(0, 0), "to": Vector2i(1, 0), "rng_seed": 7,
	})
	if not r.get("ok", false):
		push_error("Melee in the simulation should succeed: %s" % r)
		return false
	if _snapshot(session) != before:
		push_error("Simulation leaked into the live session")
		return false
	if _snapshot(sim) == before:
		push_error("Simulation state should have changed")
		return false
	return true

func _test_clone_keeps_turn_state() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 1, Vector2i(-1, 0)],
		["b", "GOLEM", 1, Vector2i(2, -1)],
	])
	var session = b["session"]
	var L: Array[Legion] = b["legions"]
	L[0].current_ap = 1
	L[0].start_cooldown("self_heal", 2)
	L[1].waited = true
	L[2].units[0].current_health = 5
	L[2].units[0].shield_remaining = 1
	var sim = TurnSimSession.clone_from(session)
	if _snapshot(sim) != _snapshot(session):
		push_error("Clone differs:\n%s\n%s" % [_snapshot(sim), _snapshot(session)])
		return false
	if sim.turn_manager.active_team_id != session.turn_manager.active_team_id:
		push_error("Clone should keep the active team")
		return false
	if sim.get_actionable_coords() != session.get_actionable_coords():
		push_error("Clone should have the same actionable legions")
		return false
	return true

func _test_evaluate_prefers_damage_dealt() -> bool:
	var b := _board([
		["a", "GOBLIN", 2, Vector2i(-3, 0)],
		["b", "GOBLIN", 2, Vector2i(3, 0)],
	])
	var session = b["session"]
	var team: String = b["legions"][0].team_id
	var even := TurnPlanner.evaluate(session, team)
	b["legions"][1].units[0].current_health = 1
	var after_hit := TurnPlanner.evaluate(session, team)
	if after_hit <= even:
		push_error("Wounding an enemy should raise the value (%s -> %s)" % [even, after_hit])
		return false
	b["legions"][1].units.remove_at(0)
	if TurnPlanner.evaluate(session, team) <= after_hit:
		push_error("Killing the unit should be worth more than wounding it")
		return false
	return true

func _test_planning_leaves_live_board_untouched() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 2, Vector2i(3, -1)],
		["b", "GOBLIN", 2, Vector2i(2, -1)],
		["b", "GOBLIN", 2, Vector2i(-2, 1)],
	])
	var session = b["session"]
	var before := _snapshot(session)
	var brain = AiBrainRegistry.create("utility_planner")
	var order: Array[Vector2i] = brain.sort_actionable(session, session.get_actionable_coords())
	if _snapshot(session) != before:
		push_error("Planning changed the live board")
		return false
	if brain.planner == null or brain.planner.plans_made != 1:
		push_error("Expected exactly one plan for two actionable legions")
		return false
	var cmd: Dictionary = brain.decide(session, session.get_legion_at(order[0]))
	if cmd.get("type") != "use_action":
		push_error("Planned first move should be an action, got %s" % cmd)
		return false
	return true

## A whole AI turn with planning on applies cleanly and ends with every legion done.
func _test_planned_turn_plays_out() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 2, Vector2i(1, 0)],
		["a", "GOLEM", 1, Vector2i(-1, 0)],
		["b", "GOBLIN", 3, Vector2i(2, -1)],
		["b", "ARCHER", 2, Vector2i(3, -3)],
	])
	var session = b["session"]
	var brain = AiBrainRegistry.create("utility_planner")
	var AiBrainCommand = load("res://scripts/ai/ai_brain_command.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in range(30):
		var actionable: Array[Vector2i] = brain.sort_actionable(session, session.get_actionable_coords())
		if actionable.is_empty():
			return true
		var L: Legion = session.get_legion_at(actionable[0])
		AiBrainCommand.apply(session, brain.decide(session, L), actionable[0], L, rng, null)
		if session.phase != 1:
			return true
	push_error("Planned turn did not finish within 30 activations")
	return false
