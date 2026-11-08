extends RefCounted

## 0.2 effects: poison, regeneration, lifesteal, pierce, empowered / weakened (+ the Rally
## and Curse actions that apply them).

const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const UnitTraits = preload("res://scripts/effects/unit_traits.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	for t in [
		_test_poison_ticks_every_unit,
		_test_poison_stacks_and_expires,
		_test_poison_on_hit_trait,
		_test_regeneration_at_own_turn_start,
		_test_lifesteal_heals_striker,
		_test_pierce_ignores_and_breaks_shield,
		_test_empowered_and_weakened,
		_test_rally_and_curse_actions,
		_test_projection_for_ai,
	]:
		if not t.call():
			return false
	print("Success: 0.2 effect tests")
	return true

func _legion(type: String, n: int, coords := Vector2i.ZERO, team := "GREEN") -> Legion:
	var L := Legion.new(type, n, coords, team)
	L.emit_global_events = false
	return L

## Fake a trait on one unit (tests don't depend on which shipped unit has it).
func _with_trait(L: Legion, key: String, value) -> Legion:
	for u in L.units:
		var def: UnitDefinition = u.definition.duplicate()
		def.traits = def.traits.duplicate()
		def.traits[key] = value
		u.definition = def
	return L

func _test_poison_ticks_every_unit() -> bool:
	var L := _legion("GOBLIN", 3)
	StatusEffects.apply(L, "poison", 2)
	var evs: Array = StatusEffects.turn_start([L], "GREEN")
	if evs.size() != 3:
		push_error("Poison should hit each of the 3 units: %d events" % evs.size())
		return false
	for u in L.units:
		if not is_equal_approx(float(u.current_health), float(u.max_health) - 2.0):
			push_error("Each unit should lose 2 HP")
			return false
	if not StatusEffects.turn_start([L], "BLUE").is_empty():
		push_error("Poison ticks only at the owner's turn start")
		return false
	return true

func _test_poison_stacks_and_expires() -> bool:
	var L := _legion("GOLEM", 1)
	StatusEffects.apply(L, "poison", 1, 2)
	StatusEffects.apply(L, "poison", 1, 2)
	if StatusEffects.stacks_of(L, "poison") != 2:
		push_error("Poison stacks add up")
		return false
	StatusEffects.turn_end([L], "GREEN")
	StatusEffects.turn_end([L], "GREEN")
	if StatusEffects.has_effect(L, "poison"):
		push_error("Poison should wear off after its turns")
		return false
	return true

func _test_poison_on_hit_trait() -> bool:
	var atk := _with_trait(_legion("ARCHER", 2), UnitTraits.POISON_ON_HIT, {"stacks": 1, "turns": 2})
	var def := _legion("GOLEM", 1, Vector2i(2, 0), "BLUE")
	def.units[0].shield_remaining = 0
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 3, {"mode": "ranged", "distance": 2})
	if StatusEffects.stacks_of(def, "poison") != 2:
		push_error("Two arrows should leave 2 poison stacks, got %d" % StatusEffects.stacks_of(def, "poison"))
		return false
	var applied := 0
	for ev in r["status_events"]:
		if ev["kind"] == "applied" and ev["status_id"] == "poison":
			applied += 1
	if applied != 2:
		push_error("Combat should report 2 poison applications")
		return false
	return true

func _test_regeneration_at_own_turn_start() -> bool:
	var L := _with_trait(_legion("GOLEM", 1), UnitTraits.REGENERATION, 3)
	L.units[0].current_health = 10
	var evs: Array = StatusEffects.turn_start([L], "GREEN")
	if evs.size() != 1 or evs[0]["kind"] != "heal" or not is_equal_approx(L.units[0].current_health, 13.0):
		push_error("Regeneration should heal 3 at own turn start: %s" % [evs])
		return false
	L.units[0].current_health = L.units[0].max_health
	if not StatusEffects.turn_start([L], "GREEN").is_empty():
		push_error("No regeneration event at full HP")
		return false
	return true

func _test_lifesteal_heals_striker() -> bool:
	var atk := _with_trait(_legion("GOBLIN", 1), UnitTraits.LIFESTEAL, 0.5)
	atk.units[0].current_health = 2
	var def := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")
	def.units[0].shield_remaining = 0
	def.units[0].attack = 0  # no return damage, isolate the heal
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 1, {"mode": "melee", "distance": 1})
	# 4 damage dealt -> +2 HP
	if not is_equal_approx(float(atk.units[0].current_health), 4.0):
		push_error("Lifesteal 50%% of 4 should heal 2 (HP %s)" % atk.units[0].current_health)
		return false
	var heals: Array = r["status_events"].filter(func(e): return e["kind"] == "heal")
	if heals.size() != 1:
		push_error("One lifesteal heal event expected")
		return false
	return true

func _test_pierce_ignores_and_breaks_shield() -> bool:
	var atk := _with_trait(_legion("GOBLIN", 1), UnitTraits.PIERCE, true)
	var def := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")  # shield 3
	def.units[0].attack = 0
	var hp0 := float(def.units[0].current_health)
	CombatResolver.resolve_combat(atk, def, 1, {"mode": "melee", "distance": 1})
	if not is_equal_approx(hp0 - float(def.units[0].current_health), 4.0) or def.units[0].shield_remaining != 0:
		push_error("Pierce: full 4 damage and the shield breaks")
		return false
	var plain := _legion("GOBLIN", 1)
	var def2 := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")
	def2.units[0].attack = 0
	CombatResolver.resolve_combat(plain, def2, 1, {"mode": "melee", "distance": 1})
	if not is_equal_approx(hp0 - float(def2.units[0].current_health), 1.0):
		push_error("Without pierce the shield absorbs 3 of 4")
		return false
	return true

func _test_empowered_and_weakened() -> bool:
	var atk := _legion("GOBLIN", 1)
	StatusEffects.apply(atk, "empowered", 2)
	var def := _legion("GOLEM", 1, Vector2i(1, 0), "BLUE")
	def.units[0].shield_remaining = 0
	StatusEffects.apply(def, "weakened", 5)
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 1, {"mode": "melee", "distance": 1})
	if not is_equal_approx(float(r["hits"][0]["raw_damage"]), 6.0):
		push_error("Empowered 2: goblin hits for 6, got %s" % r["hits"][0]["raw_damage"])
		return false
	if r["hits"].size() > 1 and not is_equal_approx(float(r["hits"][1]["raw_damage"]), 2.0):
		push_error("Weakened 5: golem's 7 becomes 2, got %s" % r["hits"][1]["raw_damage"])
		return false
	return true

func _test_rally_and_curse_actions() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for x in session.legions.duplicate():
		session.grid[x.tile_coords].legion = null
		session.legions.erase(x)
	var caster := _with_trait(_legion("MAGE", 1, Vector2i(0, 0), started["team_a"]), "x", 0)
	caster.units[0].definition.action_ids = ["move", "rally", "curse"] as Array[String]
	var ally := _legion("GOBLIN", 2, Vector2i(1, 0), started["team_a"])
	var enemy := _legion("GOBLIN", 2, Vector2i(-2, 1), started["team_b"])
	for L in [caster, ally, enemy]:
		session.legions.append(L)
		session.grid[L.tile_coords].legion = L
		L.refresh_ap()
	var rally_targets: Array = session.get_action_targets(caster, "rally")
	if not (Vector2i(0, 0) in rally_targets and Vector2i(1, 0) in rally_targets) or Vector2i(-2, 1) in rally_targets:
		push_error("Rally targets self and allies only: %s" % [rally_targets])
		return false
	var curse_targets: Array = session.get_action_targets(caster, "curse")
	if curse_targets != [Vector2i(-2, 1)]:
		push_error("Curse targets enemies in range: %s" % [curse_targets])
		return false
	var r: Dictionary = session.apply({"type": "use_action", "action_id": "rally", "from": Vector2i(0, 0), "to": Vector2i(1, 0)})
	if not r.get("ok", false) or StatusEffects.stacks_of(ally, "empowered") != 2:
		push_error("Rally should empower the ally with 2 stacks: %s" % r)
		return false
	if caster.has_ap() and not caster.waited:
		push_error("Rally is terminal")
		return false
	session.apply({"type": "end_turn"})
	session.apply({"type": "end_turn"})
	var r2: Dictionary = session.apply({"type": "use_action", "action_id": "curse", "from": Vector2i(0, 0), "to": Vector2i(-2, 1)})
	if not r2.get("ok", false) or not StatusEffects.has_effect(enemy, "weakened"):
		push_error("Curse should weaken the enemy: %s" % r2)
		return false
	var found := false
	for e in session.action_log.entries:
		if e.get("action_id") == "curse":
			found = true
	if not found:
		push_error("Curse should be in the battle log")
		return false
	return true

func _test_projection_for_ai() -> bool:
	var L := _legion("GOBLIN", 2)
	StatusEffects.apply(L, "poison", 2, 2)
	var p := StatusEffects.projected_hp_change(L)
	if not is_equal_approx(p, -8.0):
		push_error("2 units x 2 stacks x 2 ticks = -8, got %s" % p)
		return false
	var R := _with_trait(_legion("GOLEM", 1), UnitTraits.REGENERATION, 3)
	R.units[0].current_health = R.units[0].max_health - 1
	if not is_equal_approx(StatusEffects.projected_hp_change(R), 1.0):
		push_error("Regeneration projection is capped by missing HP")
		return false
	return true
