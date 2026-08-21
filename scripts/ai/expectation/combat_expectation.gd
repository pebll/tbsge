class_name CombatExpectation
extends RefCounted

## Monte Carlo combat expectation via the real CombatResolver (effects stay in one place).
## Use sim_count=1..2 for EA fitness; higher N for in-game rollout.

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")

## Default N for EA / headless fitness evaluation.
const TRAIN_SIM_COUNT := 2
## Default N for in-game UtilityBrain decisions.
const PLAY_SIM_COUNT := 12

static var _active_sim_count: int = PLAY_SIM_COUNT

static func set_sim_count(n: int) -> void:
	_active_sim_count = maxi(1, n)

static func get_sim_count() -> int:
	return _active_sim_count

static func use_train_mode() -> void:
	set_sim_count(TRAIN_SIM_COUNT)

static func use_play_mode() -> void:
	set_sim_count(PLAY_SIM_COUNT)

static func estimate_combat(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	sim_count: int = -1
) -> Dictionary:
	var empty := _empty()
	if attacker == null or defender == null:
		return empty
	if action_id != "melee_attack" and action_id != "ranged_attack":
		return empty

	var n := get_sim_count() if sim_count < 0 else maxi(1, sim_count)
	var mode := CombatResolver.MODE_MELEE if action_id == "melee_attack" else CombatResolver.MODE_RANGED
	var distance := 1 if mode == CombatResolver.MODE_MELEE else HexPathfinder.hex_distance(from_coords, to_coords)

	var enemy_loss_samples: Array[float] = []
	var own_loss_samples: Array[float] = []
	var enemy_kill_samples: Array[float] = []
	var own_kill_samples: Array[float] = []
	var kill_hits := 0

	var prev_quiet := CombatResolver.quiet
	CombatResolver.quiet = true
	var atk_hp0 := _total_hp(attacker)
	var def_hp0 := _total_hp(defender)
	var atk_n0 := attacker.units.size()
	var def_n0 := defender.units.size()

	for i in range(n):
		var sim_a := CombatSimSnapshot.clone_legion(attacker)
		var sim_d := CombatSimSnapshot.clone_legion(defender)
		CombatResolver.resolve_combat(
			sim_a,
			sim_d,
			10007 + i * 7919,
			{"mode": mode, "distance": distance}
		)
		var enemy_loss := maxf(0.0, def_hp0 - _total_hp(sim_d))
		var own_loss := maxf(0.0, atk_hp0 - _total_hp(sim_a))
		var enemy_kills := float(maxi(0, def_n0 - sim_d.units.size()))
		var own_kills := float(maxi(0, atk_n0 - sim_a.units.size()))
		enemy_loss_samples.append(enemy_loss)
		own_loss_samples.append(own_loss)
		enemy_kill_samples.append(enemy_kills)
		own_kill_samples.append(own_kills)
		if enemy_kills >= 1.0:
			kill_hits += 1
	CombatResolver.quiet = prev_quiet

	var mean_enemy := _mean(enemy_loss_samples)
	var mean_own := _mean(own_loss_samples)
	var mean_ek := _mean(enemy_kill_samples)
	var mean_ok := _mean(own_kill_samples)
	var spread := _maxv(enemy_loss_samples) - _minv(enemy_loss_samples)

	return {
		"enemy_loss_mean": mean_enemy,
		"own_loss_mean": mean_own,
		"enemy_kills_mean": mean_ek,
		"own_deaths_mean": mean_ok,
		"kill_prob": float(kill_hits) / float(n),
		"enemy_loss_spread": spread,
		"sim_count": n,
		"defender_hp": def_hp0,
		"attacker_hp": atk_hp0,
		"defender_units": def_n0,
		"attacker_units": atk_n0,
	}

static func _empty() -> Dictionary:
	return {
		"enemy_loss_mean": 0.0,
		"own_loss_mean": 0.0,
		"enemy_kills_mean": 0.0,
		"own_deaths_mean": 0.0,
		"kill_prob": 0.0,
		"enemy_loss_spread": 0.0,
		"sim_count": 0,
		"defender_hp": 1.0,
		"attacker_hp": 1.0,
		"defender_units": 0,
		"attacker_units": 0,
	}

static func _total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += maxf(0.0, float(u.current_health))
	return t

static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())

static func _minv(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var out := float(values[0])
	for v in values:
		out = minf(out, float(v))
	return out

static func _maxv(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var out := float(values[0])
	for v in values:
		out = maxf(out, float(v))
	return out
