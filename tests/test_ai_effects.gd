extends RefCounted

## 0.2: the AI uses and values the new effects (dev flow step 5: "the AI uses it").

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const TurnPlanner = preload("res://scripts/ai/planning/turn_planner.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	for t in [
		_test_shaman_rallies_the_striker,
		_test_sorcerer_curses_the_threat,
		_test_poison_counts_in_combat_estimate,
		_test_planner_values_poison_and_regen,
		_test_threat_reads_weakened,
	]:
		if not t.call():
			return false
	print("Success: AI effect tests")
	return true

func _board(specs: Array) -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for L in session.legions.duplicate():
		session.grid[L.tile_coords].legion = null
		session.legions.erase(L)
	var out: Array[Legion] = []
	for spec in specs:
		var team: String = started["team_a"] if spec[0] == "a" else started["team_b"]
		var legion := Legion.new(String(spec[1]), int(spec[2]), spec[3], team)
		legion.emit_global_events = false
		session.legions.append(legion)
		session.grid[spec[3]].legion = legion
		legion.refresh_ap()
		out.append(legion)
	return {"session": session, "legions": out}

static func _act(cmd: Dictionary) -> Array:
	if not String(cmd.get("followup_action_id", "")).is_empty():
		return [cmd["followup_action_id"], cmd.get("followup_to")]
	return [cmd.get("action_id"), cmd.get("to")]

func _test_shaman_rallies_the_striker() -> bool:
	var b := _board([
		["a", "RAT_SHAMAN", 2, Vector2i(-1, 0)],
		["a", "SCORPION_RIDER", 2, Vector2i(0, 0)],
		["b", "GOBLIN", 3, Vector2i(1, -1)],
	])
	var cmd: Dictionary = AiBrainRegistry.create("utility_hand_greedy").decide(b["session"], b["legions"][0])
	if _act(cmd) != ["rally", Vector2i(0, 0)]:
		push_error("Shaman should rally the riders before they strike, got %s" % cmd)
		return false
	return true

func _test_sorcerer_curses_the_threat() -> bool:
	var b := _board([
		["a", "RAT_SORCERER", 2, Vector2i(-2, 1)],
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["b", "SCORPION_RIDER", 2, Vector2i(1, -1)],
		["b", "SPIDER", 1, Vector2i(-3, 3)],
	])
	b["legions"][0].current_ap = 1  # stay put: compare the curses
	var cmd: Dictionary = AiBrainRegistry.create("utility_hand_greedy").decide(b["session"], b["legions"][0])
	if _act(cmd) != ["curse", Vector2i(1, -1)]:
		push_error("Sorcerer should curse the riders threatening the archers, got %s" % cmd)
		return false
	return true

func _test_poison_counts_in_combat_estimate() -> bool:
	var b := _board([
		["a", "VENOM_ARCHER", 3, Vector2i(0, 0)],
		["a", "ARCHER", 3, Vector2i(-1, 0)],
		["b", "GOLEM", 2, Vector2i(2, -1)],
	])
	var venom: Legion = b["legions"][0]
	var plain: Legion = b["legions"][1]
	var golem: Legion = b["legions"][2]
	# Same ranged damage per arrow so only the poison differs.
	for u in plain.units:
		u.ranged_attack = venom.units[0].ranged_attack
	var with_poison: Dictionary = CombatExpectation.estimate_combat(venom, golem, "ranged_attack", venom.tile_coords, golem.tile_coords, 8)
	var without: Dictionary = CombatExpectation.estimate_combat(plain, golem, "ranged_attack", venom.tile_coords, golem.tile_coords, 8)
	if float(with_poison["enemy_loss_mean"]) <= float(without["enemy_loss_mean"]) + 1.0:
		push_error("Poison should add expected loss: %s vs %s" % [with_poison["enemy_loss_mean"], without["enemy_loss_mean"]])
		return false
	if StatusEffects.has_effect(golem, "poison"):
		push_error("Estimates must not poison the live legion")
		return false
	return true

func _test_planner_values_poison_and_regen() -> bool:
	var b := _board([
		["a", "GOBLIN", 2, Vector2i(-3, 0)],
		["b", "TREANT", 1, Vector2i(3, 0)],
	])
	var session = b["session"]
	var team: String = b["legions"][0].team_id
	var treant: Legion = b["legions"][1]
	treant.units[0].current_health = 10
	var regen_v := TurnPlanner.evaluate(session, team, 0.0)
	var plain_treant_v := -TurnPlanner.army_value(treant) + TurnPlanner.army_value(b["legions"][0])
	if regen_v >= plain_treant_v:
		push_error("A regenerating enemy is worth more to them (less to us)")
		return false
	StatusEffects.apply(treant, "poison", 3, 2)
	if TurnPlanner.evaluate(session, team, 0.0) <= regen_v:
		push_error("Poisoning the enemy should raise our end-of-turn value")
		return false
	return true

func _test_threat_reads_weakened() -> bool:
	var b := _board([
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["b", "SCORPION_RIDER", 2, Vector2i(1, -1)],
	])
	var ThreatMapScript = load("res://scripts/ai/threat/threat_map.gd")
	var before: float = ThreatMapScript.build(b["session"], b["legions"][0].team_id).threat_at(Vector2i(0, 0))
	StatusEffects.apply(b["legions"][1], "weakened", 3)
	var after: float = ThreatMapScript.build(b["session"], b["legions"][0].team_id).threat_at(Vector2i(0, 0))
	if after >= before:
		push_error("Weakened enemies threaten less: %s -> %s" % [before, after])
		return false
	return true
