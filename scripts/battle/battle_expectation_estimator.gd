class_name BattleExpectationEstimator
extends RefCounted

const ActionResolverScript = preload("res://scripts/actions/action_resolver.gd")
const TerrainRulesScript = preload("res://scripts/terrain/terrain_rules.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")
const CombatSampler = preload("res://scripts/battle/combat_sampler.gd")

const CACHE_MAX := 128

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func estimate(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	grid: Dictionary = {}
) -> Dictionary:
	if attacker == null or defender == null or action_id.is_empty():
		return _empty_result()
	var terrain: Dictionary = {} if grid.is_empty() else TerrainRulesScript.combat_options(grid, from_coords, to_coords)

	var is_heal := action_id == "self_heal" or action_id == "heal_ally"
	var sim_count := 1 if is_heal else GameSettings.battle_expectation_sim_count
	var cache_key := _cache_key(attacker, defender, action_id, from_coords, to_coords, sim_count) + str(terrain)
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

	var start_us := Time.get_ticks_usec()
	for row in CombatSampler.sample(attacker, defender, mode, distance, sim_count, terrain):
		enemy_damage_samples.append(int(round(float(row["enemy_hp_lost"]))))
		own_damage_samples.append(int(round(float(row["own_hp_lost"]))))
		enemy_loss_samples.append(int(row["enemy_deaths"]))
		own_loss_samples.append(int(row["own_deaths"]))

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

	if ActionParams.total_heal(caster, action) <= 0:
		var empty := _empty_result()
		empty["kind"] = "heal"
		empty["heal_min"] = 0
		empty["heal_max"] = 0
		empty["action_id"] = action_id
		_store_cache(cache_key, empty)
		return empty

	# Clone so we don't mutate the live battle legions during preview.
	var sim_caster := CombatSimSnapshot.clone_legion(caster)
	var sim_target := sim_caster if target == caster else CombatSimSnapshot.clone_legion(target)

	var prev_quiet := CombatResolver.quiet
	CombatResolver.quiet = true
	var start_us := Time.get_ticks_usec()
	# Same code path as the real heal (per-unit amounts, healers only in mixed legions).
	var healed_total := int(round(float(ActionResolverScript._apply_focused_heal(
		sim_caster, sim_target, ActionParams.unit_heal_amounts(sim_caster, action)
	)["healed_total"])))
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
	parts.append(str(legion.tile_coords))
	for unit in legion.units:
		if unit:
			parts.append("%s:%d/%d" % [unit.unit_type, int(round(unit.current_health)), unit.shield_remaining])
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
