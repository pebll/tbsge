extends RefCounted

## Status-effect framework (0.1.5): model, stacking, durations, combat hooks, turn ticks,
## battle log, copies. Uses test-only effect types registered at runtime.

const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const StatusDefs = preload("res://scripts/effects/status_defs.gd")
const StatusDefinitionScript = preload("res://scripts/effects/status_definition.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const TurnSimSession = preload("res://scripts/ai/planning/turn_sim_session.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

## +2 damage per stack on every strike the owner makes.
class TestRage extends "res://scripts/effects/status_behavior.gd":
	func outgoing_damage(_o, effect, _u, _t, _tu, _m, damage):
		return damage + 2.0 * int(effect["stacks"])

## Owner takes half damage.
class TestStone extends "res://scripts/effects/status_behavior.gd":
	func incoming_damage(_o, _e, _u, _a, _au, _m, damage):
		return damage * 0.5

## Loses `stacks` HP on its first unit at each of its turn starts.
class TestBurn extends "res://scripts/effects/status_behavior.gd":
	func on_turn_start(owner, effect):
		if owner.units.is_empty():
			return []
		return [StatusEffects.damage_unit(owner, owner.units[0], float(effect["stacks"]), effect["id"])]

## Heals the striking unit 1 HP per hit it lands.
class TestLeech extends "res://scripts/effects/status_behavior.gd":
	func on_hit_dealt(owner, effect, hit):
		var u = hit["attacker"]
		if u == null or not (u in owner.units):
			return []
		return [StatusEffects.heal_unit(owner, u, 1.0, effect["id"])]

func run(_tree: SceneTree) -> bool:
	_register("test_rage", TestRage, "add", 2)
	_register("test_stone", TestStone, "refresh", 1)
	_register("test_burn", TestBurn, "refresh", 3)
	_register("test_leech", TestLeech, "refresh", -1)
	var ok := true
	for t in [
		_test_apply_and_stacking,
		_test_durations_count_owner_turns,
		_test_damage_hooks,
		_test_hit_hook_events,
		_test_turn_start_tick_kills_and_logs,
		_test_copies_carry_statuses,
		_test_no_statuses_no_change,
	]:
		if not t.call():
			ok = false
			break
	for id in ["test_rage", "test_stone", "test_burn", "test_leech"]:
		StatusDefs.unregister(id)
	if ok:
		print("Success: status effect tests")
	return ok

func _register(id: String, behavior: Script, stacking: String, turns: int) -> void:
	var def = StatusDefinitionScript.new()
	def.id = id
	def.display_name = id.capitalize()
	def.stacking = stacking
	def.default_turns = turns
	def.max_stacks = 5
	def.behavior = behavior
	StatusDefs.register(def)

func _legion(type: String, n: int, coords := Vector2i.ZERO, team := "GREEN") -> Legion:
	var L := Legion.new(type, n, coords, team)
	L.emit_global_events = false
	return L

func _test_apply_and_stacking() -> bool:
	var L := _legion("GOBLIN", 2)
	var ev := StatusEffects.apply(L, "test_rage", 2)
	if ev.get("kind") != "applied" or StatusEffects.stacks_of(L, "test_rage") != 2:
		push_error("apply should add the effect with 2 stacks: %s" % [L.statuses])
		return false
	StatusEffects.apply(L, "test_rage", 2)
	if StatusEffects.stacks_of(L, "test_rage") != 4:
		push_error("'add' stacking should sum stacks")
		return false
	StatusEffects.apply(L, "test_rage", 9)
	if StatusEffects.stacks_of(L, "test_rage") != 5:
		push_error("stacks should cap at max_stacks")
		return false
	StatusEffects.apply(L, "test_stone", 3, 1)
	StatusEffects.apply(L, "test_stone", 1, 4)
	var stone := StatusEffects.get_effect(L, "test_stone")
	if int(stone["stacks"]) != 3 or int(stone["turns_left"]) != 4:
		push_error("'refresh' keeps the larger stacks and duration: %s" % [stone])
		return false
	if not StatusEffects.remove(L, "test_stone") or StatusEffects.has_effect(L, "test_stone"):
		push_error("remove should drop the effect")
		return false
	return true

## Duration N = N of the owner's turns, counting the current one; counts down at the end
## of the owner's turn only.
func _test_durations_count_owner_turns() -> bool:
	var L := _legion("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	StatusEffects.apply(L, "test_stone", 1, 2)
	var legions := [L]
	StatusEffects.turn_end(legions, "BLUE")
	if int(StatusEffects.get_effect(L, "test_stone")["turns_left"]) != 2:
		push_error("The other team's turn must not count down the effect")
		return false
	StatusEffects.turn_end(legions, "GREEN")
	if int(StatusEffects.get_effect(L, "test_stone")["turns_left"]) != 1:
		push_error("The owner's turn end counts down by 1")
		return false
	var evs: Array = StatusEffects.turn_end(legions, "GREEN")
	if StatusEffects.has_effect(L, "test_stone") or evs.is_empty() or evs[0]["kind"] != "expired":
		push_error("At 0 the effect expires with an event: %s" % [evs])
		return false
	StatusEffects.apply(L, "test_leech")  # default -1: permanent
	for i in range(5):
		StatusEffects.turn_end(legions, "GREEN")
	if not StatusEffects.has_effect(L, "test_leech"):
		push_error("A permanent effect never expires")
		return false
	return true

func _test_damage_hooks() -> bool:
	var atk := _legion("GOBLIN", 1)  # attack 4
	var def := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")
	def.units[0].shield_remaining = 0
	StatusEffects.apply(atk, "test_rage", 3)  # +6
	StatusEffects.apply(def, "test_stone")    # halved
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 1, {"mode": "melee", "distance": 1})
	var first: Dictionary = r["hits"][0]
	if not is_equal_approx(float(first["raw_damage"]), 5.0):
		push_error("(4 + 6) halved should be 5, got %s" % first["raw_damage"])
		return false
	return true

func _test_hit_hook_events() -> bool:
	var atk := _legion("GOBLIN", 2)
	for u in atk.units:
		u.current_health = 3
	var def := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")
	StatusEffects.apply(atk, "test_leech")
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 2, {"mode": "melee", "distance": 1})
	var heals := 0
	for ev in r.get("status_events", []):
		if ev.get("kind") == "heal" and ev.get("status_id") == "test_leech":
			heals += 1
	if heals == 0:
		push_error("Leech should report heal events from on_hit_dealt: %s" % [r.get("status_events")])
		return false
	return true

## A status tick at turn start kills the last unit of a team: units leave, the legion is
## pruned, the battle log gets a status card and the match ends.
func _test_turn_start_tick_kills_and_logs() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var blue: Legion = started["b"]
	for u in blue.units:
		u.current_health = 1
	blue.units.resize(1)
	StatusEffects.apply(blue, "test_burn", 2)
	var r: Dictionary = session.apply({"type": "end_turn"})
	if not r.get("ok", false):
		push_error("end_turn failed: %s" % r)
		return false
	var evs: Array = r["payload"].get("status_events", [])
	var killed := false
	for ev in evs:
		if ev.get("kind") == "damage" and bool(ev.get("died", false)):
			killed = true
	if not killed:
		push_error("Burn should kill the last blue unit at blue's turn start: %s" % [evs])
		return false
	if blue in session.legions:
		push_error("The wiped legion should be pruned")
		return false
	if not ("match_ended" in r["events"]) or session.winner != started["team_a"]:
		push_error("Wiping the last legion at turn start should end the match: %s" % [r["events"]])
		return false
	var found_log := false
	for entry in session.action_log.entries:
		if String(entry.get("action_id", "")) == "status:test_burn":
			found_log = true
	if not found_log:
		push_error("The battle log should have a status:test_burn card")
		return false
	return true

func _test_copies_carry_statuses() -> bool:
	var L := _legion("GOBLIN", 2)
	StatusEffects.apply(L, "test_rage", 2, 3)
	var c: Legion = CombatSimSnapshot.clone_legion(L)
	if c.statuses != L.statuses:
		push_error("Combat clone should carry statuses")
		return false
	c.statuses[0]["stacks"] = 5
	if StatusEffects.stacks_of(L, "test_rage") != 2:
		push_error("Clone statuses must be independent copies")
		return false
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	StatusEffects.apply(started["a"], "test_stone", 1, 2)
	var sim = TurnSimSession.clone_from(session)
	if not StatusEffects.has_effect(sim.get_legion_at(started["a"].tile_coords), "test_stone"):
		push_error("Planner copy should carry statuses")
		return false
	return true

## Without statuses, combat results are identical to before (no hooks run).
func _test_no_statuses_no_change() -> bool:
	var a1 := _legion("GOBLIN", 3)
	var b1 := _legion("SKELETON", 3, Vector2i(1, 0), "BLUE")
	var r: Dictionary = CombatResolver.resolve_combat(a1, b1, 9, {"mode": "melee", "distance": 1})
	if not r.get("status_events", []).is_empty():
		push_error("No statuses -> no status events")
		return false
	for hit in r["hits"]:
		var expected := float(hit["attacker"].attack)
		if not is_equal_approx(float(hit["raw_damage"]), expected):
			push_error("Raw damage changed without statuses")
			return false
	return true
