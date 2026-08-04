extends RefCounted

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_first_hit_attacker_and_no_double_attacks():
		return false
	if not _test_alternate_then_drain_when_one_side_exhausts_attackers():
		return false
	if not _test_dead_unit_never_hits_back():
		return false
	if not _test_shield_absorbs_first_hit_only():
		return false
	if not _test_ranged_no_return_when_defender_out_of_range():
		return false
	if not _test_ranged_both_sides_when_eligible():
		return false
	if not _test_ranged_at_distance_one():
		return false
	print("Success: Combat logic tests")
	return true

func _mk_legion(unit_type: String, count: int, hp: int, atk: int) -> Legion:
	var l := Legion.new(unit_type, count, Vector2i.ZERO, "GREEN")
	for u in l.units:
		u.max_health = hp
		u.current_health = hp
		u.attack = atk
	return l

func _attackers_in_order(hits: Array) -> Array:
	var out := []
	for h in hits:
		out.append(h["attacker"])
	return out

func _targets_in_order(hits: Array) -> Array:
	var out := []
	for h in hits:
		out.append(h["target"])
	return out

func _test_first_hit_attacker_and_no_double_attacks() -> bool:
	var a := _mk_legion("GOBLIN", 2, 100, 1)
	var b := _mk_legion("GOLEM", 2, 100, 1)

	var result: Dictionary = CombatResolver.resolve_combat(a, b, 123)
	var hits: Array = result["hits"]
	if hits.size() == 0:
		push_error("Expected at least one hit")
		return false

	# First hit must come from attacking legion (a).
	if hits[0]["attacker_legion"] != a:
		push_error("First hit not from attacking legion")
		return false

	# No attacker should appear twice.
	var seen := {}
	for h in hits:
		var attacker = h["attacker"]
		if seen.has(attacker):
			push_error("Unit attacked twice, which is forbidden")
			return false
		seen[attacker] = true

	return true

func _test_alternate_then_drain_when_one_side_exhausts_attackers() -> bool:
	# Pattern example: A has 3, B has 1, nobody dies.
	# Expected attacker legions: A, B, A, A (B exhausted -> A drains remaining attackers).
	var a := _mk_legion("GOBLIN", 3, 1000, 1)
	var b := _mk_legion("GOLEM", 1, 1000, 1)

	var result: Dictionary = CombatResolver.resolve_combat(a, b, 7)
	var hits: Array = result["hits"]
	if hits.size() != 4:
		push_error("Expected 4 hits total, got %d" % hits.size())
		return false
	if hits[0]["attacker_legion"] != a:
		push_error("Expected hit 0 from A")
		return false
	if hits[1]["attacker_legion"] != b:
		push_error("Expected hit 1 from B")
		return false
	if hits[2]["attacker_legion"] != a or hits[3]["attacker_legion"] != a:
		push_error("Expected A to drain remaining attackers after B exhausts")
		return false
	return true

func _test_dead_unit_never_hits_back() -> bool:
	# Ensure a unit that dies before its turn never becomes an attacker.
	var a := _mk_legion("SCORPION_RIDER", 2, 10, 100) # will kill on hit
	var b := _mk_legion("GOBLIN", 2, 10, 1)

	var result: Dictionary = CombatResolver.resolve_combat(a, b, 42)
	var hits: Array = result["hits"]
	var deaths: Array = result["deaths"]

	# If a B unit died, it must not appear later as attacker.
	for d in deaths:
		var dead_unit = d["unit"]
		var dead_legion = d["legion"]
		var death_index: int = d["hit_index"]
		if dead_legion != b:
			continue
		for h in hits:
			if h["hit_index"] > death_index and h["attacker"] == dead_unit:
				push_error("Dead unit attacked after dying (should not hit back)")
				return false

	return true

func _test_shield_absorbs_first_hit_only() -> bool:
	var target := Unit.new("GOLEM")
	target.shield_max = 2
	target.shield_remaining = 2

	var first: Dictionary = target.absorb_damage(5.0)
	if int(first["applied"]) != 3 or int(first["absorbed"]) != 2:
		push_error("Expected shield 2 to reduce 5 damage to 3 on first hit")
		return false
	if target.shield_remaining != 0:
		push_error("Shield should be broken after first hit")
		return false

	var second: Dictionary = target.absorb_damage(5.0)
	if int(second["applied"]) != 5 or int(second["absorbed"]) != 0:
		push_error("Expected full 5 damage once shield is broken")
		return false

	target.shield_remaining = 0
	target.reset_turn_state()
	if target.shield_remaining != 2:
		push_error("reset_turn_state should restore shield at turn start")
		return false
	return true

func _mk_ranged_legion(unit_type: String, count: int, hp: int, ranged_atk: int, atk_range: int) -> Legion:
	var l := Legion.new(unit_type, count, Vector2i.ZERO, "GREEN")
	for u in l.units:
		u.max_health = hp
		u.current_health = hp
		u.attack = 1
		u.ranged_attack = ranged_atk
		u.attack_range = atk_range
	return l

func _test_ranged_no_return_when_defender_out_of_range() -> bool:
	# Range-2 shooter vs melee-only: only attacker side should hit.
	var a := _mk_ranged_legion("ARCHER", 2, 100, 4, 2)
	var b := _mk_legion("GOBLIN", 2, 100, 1)
	for u in b.units:
		u.attack_range = 0
		u.ranged_attack = 0

	var result: Dictionary = CombatResolver.resolve_combat(
		a, b, 11, {"mode": CombatResolver.MODE_RANGED, "distance": 2}
	)
	var hits: Array = result["hits"]
	if hits.size() != 2:
		push_error("Expected 2 ranged hits (attacker drain only), got %d" % hits.size())
		return false
	for h in hits:
		if h["attacker_legion"] != a:
			push_error("Defender should not return fire from range 2")
			return false
		if int(h["raw_damage"]) != 4:
			push_error("Ranged hits should use ranged_attack damage")
			return false
	return true

func _test_ranged_both_sides_when_eligible() -> bool:
	var a := _mk_ranged_legion("ARCHER", 1, 100, 3, 2)
	var b := _mk_ranged_legion("ARCHER", 1, 100, 2, 2)
	b.team_id = "BLUE"

	var result: Dictionary = CombatResolver.resolve_combat(
		a, b, 5, {"mode": CombatResolver.MODE_RANGED, "distance": 2}
	)
	var hits: Array = result["hits"]
	if hits.size() != 2:
		push_error("Expected 2 hits when both can shoot, got %d" % hits.size())
		return false
	if hits[0]["attacker_legion"] != a or hits[1]["attacker_legion"] != b:
		push_error("Expected A then B for mutual ranged combat")
		return false
	return true

func _test_ranged_at_distance_one() -> bool:
	## At distance 1, ranged still works; melee-only defender does not return fire at range mode.
	var a := _mk_ranged_legion("ARCHER", 1, 100, 5, 2)
	var b := _mk_legion("GOBLIN", 1, 100, 3)
	for u in b.units:
		u.attack_range = 0
		u.ranged_attack = 0
	var result: Dictionary = CombatResolver.resolve_combat(
		a, b, 9, {"mode": CombatResolver.MODE_RANGED, "distance": 1}
	)
	var hits: Array = result["hits"]
	if hits.size() != 1:
		push_error("Expected single ranged hit at d=1 vs melee, got %d" % hits.size())
		return false
	if int(hits[0]["raw_damage"]) != 5:
		push_error("Expected ranged_attack damage at d=1")
		return false
	return true

