class_name BalanceBattleRunner
extends RefCounted

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const BalanceArmyPlanner = preload("res://scripts/balance/balance_army_planner.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const UnitDatabaseScript = preload("res://scripts/resources/unit_database.gd")

const CONFIG_PATH := "res://data/minigame/balance_duel.tres"
const UNIT_DB_PATH := "res://data/unit_db.tres"
const BALANCE_BUDGET := 60
const MAX_TEAM_TURNS := 200

static func run(
	unit_type_a: String,
	unit_type_b: String,
	map_seed: int,
	combat_seed: int = 0,
	unit_a_moves_first: bool = true
) -> Dictionary:
	var config: MinigameConfigScript = load(CONFIG_PATH) as MinigameConfigScript
	if config == null:
		return _error("Failed to load balance config")

	if army_count_for_budget(unit_type_a) <= 0 or army_count_for_budget(unit_type_b) <= 0:
		return _error("Unit price exceeds balance budget")

	var session := MinigameSessionScript.new(config)
	session.grid = MapBuilderScript.build_grid(config.map_radius, map_seed, config.team_ids)
	session.refresh_deploy_slots()

	var team_green: String = config.first_team_id()
	var team_blue: String = config.second_team_id()
	var slots_green: Array = session.get_deploy_slots(team_green)
	var slots_blue: Array = session.get_deploy_slots(team_blue)
	if slots_green.is_empty() or slots_blue.is_empty():
		return _error("Could not resolve deploy slots")

	var green_unit_type: String = unit_type_a if unit_a_moves_first else unit_type_b
	var blue_unit_type: String = unit_type_b if unit_a_moves_first else unit_type_a

	var placements_green := BalanceArmyPlanner.plan_placements(
		green_unit_type, slots_green, BALANCE_BUDGET, config.max_legion_fill
	)
	var placements_blue := BalanceArmyPlanner.plan_placements(
		blue_unit_type, slots_blue, BALANCE_BUDGET, config.max_legion_fill
	)
	if placements_green.is_empty() or placements_blue.is_empty():
		return _error("Could not plan army placements")

	var count_a := army_count_for_budget(unit_type_a)
	var count_b := army_count_for_budget(unit_type_b)
	var legions_a := placements_green.size() if unit_a_moves_first else placements_blue.size()
	var legions_b := placements_blue.size() if unit_a_moves_first else placements_green.size()

	var setup_err := _setup_battle(session, team_green, team_blue, placements_green, placements_blue)
	if not setup_err.is_empty():
		return _error(setup_err)

	return _run_ai_battle(
		session,
		team_green,
		team_blue,
		unit_type_a,
		unit_type_b,
		green_unit_type,
		blue_unit_type,
		count_a,
		count_b,
		legions_a,
		legions_b,
		combat_seed
	)

static func _setup_battle(
	session,
	team_green: String,
	team_blue: String,
	placements_green: Array,
	placements_blue: Array
) -> String:
	var steps: Array[Dictionary] = []
	for placement in placements_green:
		steps.append({
			"type": "draft_set_legion",
			"team": team_green,
			"coords": placement["coords"],
			"unit_type": placement["unit_type"],
			"unit_count": placement["unit_count"],
		})
	steps.append({"type": "draft_ready", "team": team_green})
	for placement in placements_blue:
		steps.append({
			"type": "draft_set_legion",
			"team": team_blue,
			"coords": placement["coords"],
			"unit_type": placement["unit_type"],
			"unit_count": placement["unit_count"],
		})
	steps.append({"type": "draft_ready", "team": team_blue})

	for cmd in steps:
		var result: Dictionary = session.apply(cmd)
		if not result.get("ok", false):
			return String(result.get("error", "Draft setup failed"))
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		return "Expected battle phase after setup"
	return ""

static func _run_ai_battle(
	session,
	team_green: String,
	team_blue: String,
	unit_type_a: String,
	unit_type_b: String,
	green_unit_type: String,
	blue_unit_type: String,
	count_a: int,
	count_b: int,
	legions_a: int,
	legions_b: int,
	combat_seed: int
) -> Dictionary:
	var prev_ai_debug := AttackNearestEnemyBehavior.debug_enabled
	var prev_combat_quiet := CombatResolver.quiet
	AttackNearestEnemyBehavior.debug_enabled = false
	CombatResolver.quiet = true

	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = combat_seed

	var team_turns := 0
	while session.phase == MinigameSessionScript.Phase.BATTLE:
		var actionable := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(
			session,
			session.get_actionable_coords()
		)
		if actionable.is_empty():
			var end_result: Dictionary = session.apply({"type": "end_turn"})
			if not end_result.get("ok", false):
				break
			team_turns += 1
			if team_turns > MAX_TEAM_TURNS:
				AttackNearestEnemyBehavior.debug_enabled = prev_ai_debug
				CombatResolver.quiet = prev_combat_quiet
				return _timeout_result(
					unit_type_a,
					unit_type_b,
					count_a,
					count_b,
					legions_a,
					legions_b,
					team_turns
				)
			continue

		var coords: Vector2i = actionable[0]
		var legion: Legion = session.get_legion_at(coords)
		if legion == null:
			session.pass_legion_or_force_wait(coords)
			continue

		var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, legion)
		match String(cmd.get("type", "")):
			"use_action":
				var apply_cmd := {
					"type": "use_action",
					"action_id": String(cmd.get("action_id", "")),
					"from": cmd.get("from", coords),
					"to": cmd.get("to", coords),
				}
				if apply_cmd["action_id"] == "melee_attack":
					apply_cmd["rng_seed"] = combat_rng.randi()
				var result: Dictionary = session.apply(apply_cmd)
				if not result.get("ok", false):
					session.pass_legion_or_force_wait(coords)
			_:
				session.pass_legion_or_force_wait(coords)

		if session.phase == MinigameSessionScript.Phase.ENDED:
			break

	AttackNearestEnemyBehavior.debug_enabled = prev_ai_debug
	CombatResolver.quiet = prev_combat_quiet

	return _build_result(
		session.winner,
		team_green,
		team_blue,
		green_unit_type,
		blue_unit_type,
		unit_type_a,
		unit_type_b,
		count_a,
		count_b,
		legions_a,
		legions_b,
		team_turns,
		session,
		false
	)

static func _timeout_result(
	unit_type_a: String,
	unit_type_b: String,
	count_a: int,
	count_b: int,
	legions_a: int,
	legions_b: int,
	team_turns: int
) -> Dictionary:
	return {
		"ok": true,
		"winner": "",
		"winner_unit_type": "",
		"team_a": "",
		"team_b": "",
		"unit_type_a": unit_type_a,
		"unit_type_b": unit_type_b,
		"count_a": count_a,
		"count_b": count_b,
		"legions_a": legions_a,
		"legions_b": legions_b,
		"team_turns": team_turns,
		"survivors_a": 0,
		"survivors_b": 0,
		"timed_out": true,
	}

static func _build_result(
	winner_team: String,
	team_green: String,
	team_blue: String,
	green_unit_type: String,
	blue_unit_type: String,
	unit_type_a: String,
	unit_type_b: String,
	count_a: int,
	count_b: int,
	legions_a: int,
	legions_b: int,
	team_turns: int,
	session,
	timed_out: bool
) -> Dictionary:
	var winner_unit_type := ""
	if not winner_team.is_empty():
		if winner_team == team_green:
			winner_unit_type = green_unit_type
		elif winner_team == team_blue:
			winner_unit_type = blue_unit_type

	var survivors_green := _living_unit_count(session, team_green)
	var survivors_blue := _living_unit_count(session, team_blue)
	var survivors_a := survivors_green if green_unit_type == unit_type_a else survivors_blue
	var survivors_b := survivors_blue if blue_unit_type == unit_type_b else survivors_green

	return {
		"ok": true,
		"winner": winner_team,
		"winner_unit_type": winner_unit_type,
		"team_a": team_green if green_unit_type == unit_type_a else team_blue,
		"team_b": team_blue if blue_unit_type == unit_type_b else team_green,
		"unit_type_a": unit_type_a,
		"unit_type_b": unit_type_b,
		"count_a": count_a,
		"count_b": count_b,
		"legions_a": legions_a,
		"legions_b": legions_b,
		"team_turns": team_turns,
		"survivors_a": survivors_a,
		"survivors_b": survivors_b,
		"timed_out": timed_out,
	}

static func _living_unit_count(session, team_id: String) -> int:
	return MinigameRulesScript.count_living_units(session.legions, team_id)

static func army_count_for_budget(unit_type: String, budget: int = BALANCE_BUDGET) -> int:
	return _army_count_for_budget(unit_type, budget)

static func _army_count_for_budget(unit_type: String, budget: int = BALANCE_BUDGET) -> int:
	var db: UnitDatabaseScript = load(UNIT_DB_PATH) as UnitDatabaseScript
	if db == null:
		return 0
	var def = db.get_def(unit_type)
	if def == null or def.price <= 0:
		return 0
	return budget / def.price

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
