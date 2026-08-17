class_name BattleExpectationEstimator
extends RefCounted

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")

const CACHE_MAX := 128

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func estimate(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i
) -> Dictionary:
	if attacker == null or defender == null or action_id.is_empty():
		return _empty_result()

	var is_heal := action_id == "self_heal" or action_id == "heal_ally"
	var sim_count := 1 if is_heal else GameSettings.battle_expectation_sim_count
	var cache_key := _cache_key(attacker, defender, action_id, from_coords, to_coords, sim_count)
	if _cache.has(cache_key):
		var cached: Dictionary = _cache[cache_key].duplicate(true)
		cached["cached"] = true
		if GameSettings.battle_expectation_log_timing:
			print(
				"[Expectation] cache hit (%d sims, %.2f ms stored) %s vs %s [%s]"
				% [
					int(cached.get("sim_count", 0)),
					float(cached.get("elapsed_ms", 0.0)),
					attacker.unit_type,
					defender.unit_type,
					action_id,
				]
			)
		return cached

	if is_heal:
		return _estimate_heal(attacker, defender, action_id, from_coords, to_coords, cache_key)

	var mode := CombatResolver.MODE_MELEE if action_id == "melee_attack" else CombatResolver.MODE_RANGED
	var distance := 1 if mode == CombatResolver.MODE_MELEE else HexPathfinder.hex_distance(from_coords, to_coords)

	var enemy_damage_samples: Array[int] = []
	var own_damage_samples: Array[int] = []
	var enemy_loss_samples: Array[int] = []
	var own_loss_samples: Array[int] = []

	var prev_quiet := CombatResolver.quiet
	CombatResolver.quiet = true
	var start_us := Time.get_ticks_usec()
	for i in sim_count:
		var sim_attacker := CombatSimSnapshot.clone_legion(attacker)
		var sim_defender := CombatSimSnapshot.clone_legion(defender)
		var combat: Dictionary = CombatResolver.resolve_combat(
			sim_attacker,
			sim_defender,
			10007 + i * 7919,
			{"mode": mode, "distance": distance}
		)
		var metrics := _metrics_from_sim(attacker, defender, sim_attacker, sim_defender, combat)
		enemy_damage_samples.append(metrics["enemy_damage"])
		own_damage_samples.append(metrics["own_damage"])
		enemy_loss_samples.append(metrics["enemy_losses"])
		own_loss_samples.append(metrics["own_losses"])
	CombatResolver.quiet = prev_quiet

	var elapsed_ms := float(Time.get_ticks_usec() - start_us) / 1000.0
	var result := {
		"enemy_damage_min": _array_min(enemy_damage_samples),
		"enemy_damage_max": _array_max(enemy_damage_samples),
		"own_damage_min": _array_min(own_damage_samples),
		"own_damage_max": _array_max(own_damage_samples),
		"enemy_losses_min": _array_min(enemy_loss_samples),
		"enemy_losses_max": _array_max(enemy_loss_samples),
		"own_losses_min": _array_min(own_loss_samples),
		"own_losses_max": _array_max(own_loss_samples),
		"sim_count": sim_count,
		"elapsed_ms": elapsed_ms,
		"cached": false,
		"action_id": action_id,
	}
	_store_cache(cache_key, result)

	if GameSettings.battle_expectation_log_timing:
		print(
			"[Expectation] %d sims in %.2f ms — enemy dmg %d-%d, own dmg %d-%d, enemy losses %d-%d, own losses %d-%d (%s vs %s)"
			% [
				sim_count,
				elapsed_ms,
				result["enemy_damage_min"],
				result["enemy_damage_max"],
				result["own_damage_min"],
				result["own_damage_max"],
				result["enemy_losses_min"],
				result["enemy_losses_max"],
				result["own_losses_min"],
				result["own_losses_max"],
				attacker.unit_type,
				defender.unit_type,
			]
		)
	return result

static func _estimate_heal(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	cache_key: String
) -> Dictionary:
	# ActionDefs is expected to exist as a global singleton (autoload).
	var action = ActionDefs.get_def(action_id)
	if action == null:
		return _empty_result()

	# Deterministic: the heal resolves by repeatedly picking the lowest HP wounded unit.
	var caster := attacker
	var target := defender
	if action_id == "self_heal":
		target = attacker

	var heal_amount := ActionParams.resolve_int(caster, action, "heal_amount", action.heal_amount)
	if heal_amount <= 0:
		var empty := _empty_result()
		empty["kind"] = "heal"
		empty["heal_min"] = 0
		empty["heal_max"] = 0
		empty["action_id"] = action_id
		_store_cache(cache_key, empty)
		return empty

	# Clone so we don't mutate the live battle legions during preview.
	var sim_caster := CombatSimSnapshot.clone_legion(caster)
	var sim_target := CombatSimSnapshot.clone_legion(target)

	var prev_quiet := CombatResolver.quiet
	CombatResolver.quiet = true
	var start_us := Time.get_ticks_usec()
	var healed_total := _apply_focused_heal_total(sim_caster, sim_target, heal_amount)
	var elapsed_ms := float(Time.get_ticks_usec() - start_us) / 1000.0
	CombatResolver.quiet = prev_quiet

	var result := {
		"kind": "heal",
		"heal_min": int(healed_total),
		"heal_max": int(healed_total),
		# Keep combat keys so the bar can be defensive.
		"enemy_damage_min": 0,
		"enemy_damage_max": 0,
		"own_damage_min": 0,
		"own_damage_max": 0,
		"enemy_losses_min": 0,
		"enemy_losses_max": 0,
		"own_losses_min": 0,
		"own_losses_max": 0,
		"sim_count": 1,
		"elapsed_ms": elapsed_ms,
		"cached": false,
		"action_id": action_id,
	}
	_store_cache(cache_key, result)

	if GameSettings.battle_expectation_log_timing:
		print(
			"[Expectation] 1 heal sim in %.2f ms — healed %d (%s vs %s)"
			% [elapsed_ms, result["heal_min"], attacker.unit_type, defender.unit_type]
		)
	return result

static func _apply_focused_heal_total(caster: Legion, target: Legion, heal_amount: int) -> int:
	if caster == null or target == null or heal_amount <= 0:
		return 0

	var healed := 0
	for caster_unit in caster.units:
		if caster_unit == null:
			continue
		var focus := _pick_lowest_hp_wounded_snapshot(target)
		if focus == null:
			break
		var before := int(focus.current_health)
		var after := mini(before + heal_amount, int(focus.max_health))
		if after > before:
			healed += after - before
		# Apply so subsequent picks see the updated HP.
		focus.current_health = float(after)
	return healed

static func _pick_lowest_hp_wounded_snapshot(legion: Legion) -> Unit:
	if legion == null:
		return null
	var best: Unit = null
	var best_hp := 2147483647
	for unit in legion.units:
		if unit == null:
			continue
		var hp := int(unit.current_health)
		if hp >= int(unit.max_health):
			continue
		if hp < best_hp:
			best_hp = hp
			best = unit
	return best

static func _metrics_from_sim(
	orig_attacker: Legion,
	orig_defender: Legion,
	sim_attacker: Legion,
	sim_defender: Legion,
	_combat: Dictionary
) -> Dictionary:
	var enemy_damage := int(round(_legion_hp_total(orig_defender) - _legion_hp_total(sim_defender)))
	var own_damage := int(round(_legion_hp_total(orig_attacker) - _legion_hp_total(sim_attacker)))
	enemy_damage = maxi(0, enemy_damage)
	own_damage = maxi(0, own_damage)
	var enemy_losses := maxi(0, orig_defender.units.size() - sim_defender.units.size())
	var own_losses := maxi(0, orig_attacker.units.size() - sim_attacker.units.size())
	return {
		"enemy_damage": enemy_damage,
		"own_damage": own_damage,
		"enemy_losses": enemy_losses,
		"own_losses": own_losses,
	}

static func _legion_hp_total(legion: Legion) -> float:
	var total := 0.0
	for unit in legion.units:
		if unit:
			total += maxf(0.0, float(unit.current_health))
	return total

static func _cache_key(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	sim_count: int
) -> String:
	return "%s|%s|%s|%s|%s|%d" % [
		_legion_fingerprint(attacker),
		_legion_fingerprint(defender),
		action_id,
		from_coords,
		to_coords,
		sim_count,
	]

static func _legion_fingerprint(legion: Legion) -> String:
	var parts: PackedStringArray = []
	parts.append(legion.team_id)
	parts.append(legion.unit_type)
	parts.append(str(legion.tile_coords))
	for unit in legion.units:
		if unit:
			parts.append("%d/%d" % [int(round(unit.current_health)), unit.shield_remaining])
	return "|".join(parts)

static func _store_cache(key: String, value: Dictionary) -> void:
	if _cache.size() >= CACHE_MAX:
		var oldest_key: String = _cache.keys()[0]
		_cache.erase(oldest_key)
	_cache[key] = value.duplicate(true)

static func _array_min(values: Array) -> int:
	if values.is_empty():
		return 0
	var out: int = values[0]
	for v in values:
		out = mini(out, int(v))
	return out

static func _array_max(values: Array) -> int:
	if values.is_empty():
		return 0
	var out: int = values[0]
	for v in values:
		out = maxi(out, int(v))
	return out

static func _empty_result() -> Dictionary:
	return {
		"kind": "combat",
		"enemy_damage_min": 0,
		"enemy_damage_max": 0,
		"own_damage_min": 0,
		"own_damage_max": 0,
		"enemy_losses_min": 0,
		"enemy_losses_max": 0,
		"own_losses_min": 0,
		"own_losses_max": 0,
		"sim_count": 0,
		"elapsed_ms": 0.0,
		"cached": false,
		"action_id": "",
	}
