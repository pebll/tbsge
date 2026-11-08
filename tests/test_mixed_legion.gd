extends RefCounted

## Mixed-legion data model (0.1.5): a legion is any set of units; rules, cost, stats and
## the AI read each unit's own type.

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const TurnSimSession = preload("res://scripts/ai/planning/turn_sim_session.gd")
const MatchBattleStats = preload("res://scripts/battle/match_battle_stats.gd")
const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiBrainCommand = preload("res://scripts/ai/ai_brain_command.gd")

func run(_tree: SceneTree) -> bool:
	for t in [
		_test_composition_and_identity,
		_test_cost_and_pace,
		_test_single_type_unchanged,
		_test_actions_are_the_union,
		_test_only_healers_heal,
		_test_ranged_strikes_only_with_shooters,
		_test_clones_keep_each_unit_type,
		_test_battle_stats_split_by_type,
		_test_ai_plays_mixed_legions,
	]:
		if not t.call():
			return false
	print("Success: mixed legion tests")
	return true

func _mixed(parts: Array, coords := Vector2i.ZERO, team := "GREEN") -> Legion:
	var L := Legion.from_composition(parts, coords, team)
	L.emit_global_events = false
	return L

func _test_composition_and_identity() -> bool:
	var L := _mixed([["GOBLIN", 1], ["ARCHER", 2], ["GOBLIN", 1]])
	if L.units.size() != 4:
		push_error("Expected 4 units, got %d" % L.units.size())
		return false
	if L.composition() != [["GOBLIN", 2], ["ARCHER", 2]]:
		push_error("Composition should merge repeats in first-seen order: %s" % [L.composition()])
		return false
	if not L.is_mixed() or L.unit_types() != ["GOBLIN", "ARCHER"]:
		push_error("Expected a mixed GOBLIN + ARCHER legion")
		return false
	# Tie (2/2): first seen wins; then the larger group.
	if L.unit_type != "GOBLIN":
		push_error("Label type on a tie should be the first seen, got %s" % L.unit_type)
		return false
	L.units.remove_at(0)
	if L.unit_type != "ARCHER":
		push_error("Label type should follow the most numerous type, got %s" % L.unit_type)
		return false
	if L.display_name().find("+") < 0:
		push_error("Mixed display name should list both types: %s" % L.display_name())
		return false
	if L.count_of("ARCHER") != 2:
		push_error("count_of ARCHER should be 2")
		return false
	return true

func _test_cost_and_pace() -> bool:
	var L := _mixed([["SCORPION_RIDER", 1], ["GOBLIN", 2]])
	var expected := UnitDefs.get_def("SCORPION_RIDER").price + 2 * UnitDefs.get_def("GOBLIN").price
	if L.gold_value() != expected:
		push_error("gold_value should price each unit at its own type: %d vs %d" % [L.gold_value(), expected])
		return false
	var fast := _mixed([["SCORPION_RIDER", 2]])
	if fast.max_ap <= L.max_ap:
		push_error("The slowest unit sets the pace: %d (mixed) vs %d (riders)" % [L.max_ap, fast.max_ap])
		return false
	if L.current_ap != L.max_ap:
		push_error("A new legion starts with full AP")
		return false
	return true

## A single-type legion behaves exactly as before.
func _test_single_type_unchanged() -> bool:
	var L := Legion.new("GOBLIN", 3, Vector2i.ZERO, "GREEN")
	if L.unit_type != "GOBLIN" or L.is_mixed() or L.composition() != [["GOBLIN", 3]]:
		push_error("Single-type legion identity changed")
		return false
	if L.gold_value() != 3 * UnitDefs.get_def("GOBLIN").price:
		push_error("Single-type cost changed")
		return false
	var empty := Legion.new("ARCHER", 0, Vector2i.ZERO, "GREEN")
	if empty.unit_type != "ARCHER" or empty.unit_types() != ["ARCHER"]:
		push_error("An empty legion keeps its constructor type as label")
		return false
	return true

func _test_actions_are_the_union() -> bool:
	var L := _mixed([["GOBLIN", 2], ["MAGE", 1]])
	var ids: Array = ActionDefs.legion_action_ids(L)
	for id in ["melee_attack", "ranged_attack", "heal_ally"]:
		if id not in ids:
			push_error("Mixed legion should be able to %s: %s" % [id, ids])
			return false
	return true

func _test_only_healers_heal() -> bool:
	var L := _mixed([["GOBLIN", 2], ["MAGE", 1]])
	var heal = ActionDefs.get_def("heal_ally")
	var amounts: Array[int] = ActionParams.unit_heal_amounts(L, heal)
	var mage_heal := int(ActionParams.resolve_for_type("MAGE", heal, "heal_amount", heal.heal_amount))
	if amounts != [0, 0, mage_heal]:
		push_error("Only the mage should heal (%d): %s" % [mage_heal, amounts])
		return false
	if ActionParams.total_heal(L, heal) != mage_heal:
		push_error("total_heal should be the mage's amount")
		return false
	# Through the real resolver: one heal lands.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for x in session.legions.duplicate():
		session.grid[x.tile_coords].legion = null
		session.legions.erase(x)
	var caster := _mixed([["GOBLIN", 2], ["MAGE", 1]], Vector2i(0, 0), started["team_a"])
	var ally := _mixed([["GOBLIN", 3]], Vector2i(1, 0), started["team_a"])
	for u in ally.units:
		u.current_health = 1
	for leg in [caster, ally]:
		session.legions.append(leg)
		session.grid[leg.tile_coords].legion = leg
	var r: Dictionary = session.apply({
		"type": "use_action", "action_id": "heal_ally", "from": Vector2i(0, 0), "to": Vector2i(1, 0),
	})
	if not r.get("ok", false):
		push_error("heal_ally from a mixed legion failed: %s" % r)
		return false
	var heals: Array = r["payload"]["unit_heals"]
	if heals.size() != 1 or heals[0]["caster"].unit_type != "MAGE":
		push_error("Exactly one heal, cast by the mage: %s" % [heals])
		return false
	return true

func _test_ranged_strikes_only_with_shooters() -> bool:
	var atk := _mixed([["GOBLIN", 3], ["ARCHER", 1]])
	var def := _mixed([["GOLEM", 1]], Vector2i(2, 0), "BLUE")
	def.units[0].current_health = 999
	def.units[0].max_health = 999
	var result: Dictionary = CombatResolver.resolve_combat(atk, def, 5, {"mode": "ranged", "distance": 2})
	var by_attacker := 0
	for hit in result.get("hits", []):
		if hit.get("attacker_legion") == atk:
			by_attacker += 1
			if hit.get("attacker") == null or hit["attacker"].unit_type != "ARCHER":
				push_error("Only the archer can shoot at range 2")
				return false
	if by_attacker != 1:
		push_error("Expected exactly 1 ranged strike from the mixed legion, got %d" % by_attacker)
		return false
	return true

func _test_clones_keep_each_unit_type() -> bool:
	var L := _mixed([["GOBLIN", 2], ["MAGE", 1]])
	L.units[2].current_health = 3
	var c: Legion = CombatSimSnapshot.clone_legion(L)
	if c.composition() != L.composition() or c.units[2].current_health != 3:
		push_error("Combat clone lost the composition or HP")
		return false
	var full: Legion = TurnSimSession.clone_legion_full(L)
	if full.composition() != L.composition():
		push_error("Planner clone lost the composition")
		return false
	return true

func _test_battle_stats_split_by_type() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for x in session.legions.duplicate():
		session.grid[x.tile_coords].legion = null
		session.legions.erase(x)
	var L := _mixed([["GOBLIN", 2], ["ARCHER", 1]], Vector2i(0, 0), "GREEN")
	session.legions.append(L)
	var stats := MatchBattleStats.new()
	stats.begin(session)
	L.units.remove_at(0)  # one goblin dies
	var report: Dictionary = stats.build_report("")
	var rows := {}
	for row in report.get("by_type", []):
		rows[row["unit_type"]] = row
	if not rows.has("GOBLIN") or not rows.has("ARCHER"):
		push_error("Report should have a row per unit type: %s" % [rows.keys()])
		return false
	if int(rows["GOBLIN"]["green_lost"]) != 1 or int(rows["ARCHER"]["green_lost"]) != 0:
		push_error("Losses should land on the GOBLIN row only: %s" % [rows])
		return false
	return true

## The planning AI plays a full turn with mixed legions on both sides.
func _test_ai_plays_mixed_legions() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for x in session.legions.duplicate():
		session.grid[x.tile_coords].legion = null
		session.legions.erase(x)
	var specs := [
		[[["GOBLIN", 2], ["MAGE", 1]], Vector2i(0, 0), started["team_a"]],
		[[["GOLEM", 1], ["ARCHER", 2]], Vector2i(-1, 0), started["team_a"]],
		[[["OGRE", 1], ["SPIDER", 3]], Vector2i(2, -1), started["team_b"]],
	]
	for spec in specs:
		var leg := _mixed(spec[0], spec[1], spec[2])
		session.legions.append(leg)
		session.grid[leg.tile_coords].legion = leg
	var brain = AiBrainRegistry.create("utility_hand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for _i in range(20):
		var order: Array[Vector2i] = brain.sort_actionable(session, session.get_actionable_coords())
		if order.is_empty():
			return true
		var leg: Legion = session.get_legion_at(order[0])
		AiBrainCommand.apply(session, brain.decide(session, leg), order[0], leg, rng, null)
		if session.phase != 1:
			return true
	push_error("AI turn with mixed legions did not finish")
	return false
