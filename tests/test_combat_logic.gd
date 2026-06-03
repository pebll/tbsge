extends RefCounted

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_first_hit_attacker_and_no_double_attacks():
		return false
	if not _test_alternate_then_drain_when_one_side_exhausts_attackers():
		return false
	if not _test_dead_unit_never_hits_back():
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
	var a := _mk_legion("ARCHER", 2, 100, 1)
	var b := _mk_legion("OGRE", 2, 100, 1)

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
	var a := _mk_legion("ARCHER", 3, 1000, 1)
	var b := _mk_legion("OGRE", 1, 1000, 1)

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
	var a := _mk_legion("AXEMAN", 2, 10, 100) # will kill on hit
	var b := _mk_legion("ARCHER", 2, 10, 1)

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

