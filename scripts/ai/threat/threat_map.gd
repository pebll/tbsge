class_name ThreatMap
extends RefCounted

## Lazy per-hex pressure from enemies (can they strike this tile now or after a walk?).

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")
const Utils = preload("res://scripts/core/utils.gd")

var session
var for_team_id: String = ""
var _cache: Dictionary = {}  # Vector2i -> float
var _enemy_reach: Dictionary = {}  # enemy instance_id -> Array[Vector2i] stands
var _max_seen: float = 0.0

static func build(p_session, for_team_id: String) -> ThreatMap:
	var map := ThreatMap.new()
	map.session = p_session
	map.for_team_id = for_team_id
	return map

func threat_at(coords: Vector2i) -> float:
	if _cache.has(coords):
		return float(_cache[coords])
	var total := 0.0
	if session == null:
		_cache[coords] = 0.0
		return 0.0
	for legion in session.legions:
		if legion == null or legion.units.is_empty():
			continue
		if legion.team_id == for_team_id:
			continue
		total += _enemy_threat_to(legion, coords)
	_cache[coords] = total
	_max_seen = maxf(_max_seen, total)
	return total

func threat_frac(coords: Vector2i) -> float:
	var raw := threat_at(coords)
	# Normalize against the hottest hex we've evaluated this activation.
	var denom := maxf(maxf(_max_seen, raw), 1.0)
	return clampf(raw / denom, 0.0, 1.0)

func _enemy_threat_to(enemy: Legion, hex: Vector2i) -> float:
	var action_ids: Array = ActionDefs.legion_action_ids(enemy)
	var melee_p := _legion_melee_power(enemy)
	var ranged_p := _legion_ranged_power(enemy)
	var shoot := _legion_shoot_range(enemy)
	var total := 0.0

	if "melee_attack" in action_ids and melee_p > 0.0:
		if HexPathfinder.hex_distance(enemy.tile_coords, hex) == 1:
			total += melee_p
	if "ranged_attack" in action_ids and ranged_p > 0.0 and shoot > 0:
		var d := HexPathfinder.hex_distance(enemy.tile_coords, hex)
		if d >= 1 and d <= shoot:
			total += ranged_p * (1.0 if d > 1 else 0.85)

	# Walk-then-strike using enemy max AP reachability (cached per enemy).
	var stands: Array = _stands_for(enemy)
	for stand in stands:
		var stand_coords: Vector2i = stand
		if stand_coords == enemy.tile_coords:
			continue
		if "melee_attack" in action_ids and melee_p > 0.0:
			if HexPathfinder.hex_distance(stand_coords, hex) == 1:
				total += melee_p * 0.75
		if "ranged_attack" in action_ids and ranged_p > 0.0 and shoot > 0:
			var d2 := HexPathfinder.hex_distance(stand_coords, hex)
			if d2 >= 1 and d2 <= shoot:
				total += ranged_p * 0.7 * (1.0 if d2 > 1 else 0.85)
	return total

func _stands_for(enemy: Legion) -> Array:
	var key := enemy.get_instance_id()
	if _enemy_reach.has(key):
		return _enemy_reach[key]
	var saved_ap := enemy.current_ap
	enemy.current_ap = maxi(enemy.current_ap, enemy.max_ap)
	var reach: Dictionary = MoveReachability.compute(session.battle_state(), enemy)
	enemy.current_ap = saved_ap
	var stands: Array = reach.get("reachable", []).duplicate()
	stands.append(enemy.tile_coords)
	_enemy_reach[key] = stands
	return stands

static func _legion_melee_power(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.attack)
	return t

static func _legion_ranged_power(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u and u.ranged_attack > 0:
			t += float(u.ranged_attack)
	return t

static func _legion_shoot_range(legion: Legion) -> int:
	var best := 0
	for u in legion.units:
		if u and u.attack_range > best and u.ranged_attack > 0:
			best = u.attack_range
	return best
