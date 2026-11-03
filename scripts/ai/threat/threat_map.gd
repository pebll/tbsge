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
var _max_possible: float = -1.0

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
	return total

## Context-wide scale: the most any hex could be threatened (every enemy striking at once).
func max_possible() -> float:
	if _max_possible >= 0.0:
		return _max_possible
	var total := 0.0
	if session != null:
		for legion in session.legions:
			if legion == null or legion.units.is_empty() or legion.team_id == for_team_id:
				continue
			total += _strike_power(legion)
	_max_possible = total
	return total

func threat_frac(coords: Vector2i) -> float:
	return clampf(threat_at(coords) / maxf(max_possible(), 1.0), 0.0, 1.0)

## One enemy's contribution to a hex: its best single strike (max over the stands it can
## attack from), scaled by its remaining HP fraction.
func _enemy_threat_to(enemy: Legion, hex: Vector2i) -> float:
	var action_ids: Array = ActionDefs.legion_action_ids(enemy)
	var melee_p := _legion_melee_power(enemy) if "melee_attack" in action_ids else 0.0
	var ranged_p := _legion_ranged_power(enemy) if "ranged_attack" in action_ids else 0.0
	var shoot := _legion_shoot_range(enemy)
	if melee_p <= 0.0 and (ranged_p <= 0.0 or shoot <= 0):
		return 0.0
	var best := _strike_from(enemy.tile_coords, hex, melee_p, ranged_p, shoot, 1.0, 1.0)
	# Walk-then-strike using enemy max AP reachability (cached per enemy).
	for stand in _stands_for(enemy):
		var stand_coords: Vector2i = stand
		if stand_coords == enemy.tile_coords:
			continue
		best = maxf(best, _strike_from(stand_coords, hex, melee_p, ranged_p, shoot, 0.75, 0.7))
	return best * _hp_frac(enemy)

static func _strike_from(
	from: Vector2i, hex: Vector2i, melee_p: float, ranged_p: float, shoot: int,
	melee_mult: float, ranged_mult: float
) -> float:
	var d := HexPathfinder.hex_distance(from, hex)
	var out := 0.0
	if melee_p > 0.0 and d == 1:
		out = melee_p * melee_mult
	if ranged_p > 0.0 and shoot > 0 and d >= 1 and d <= shoot:
		out = maxf(out, ranged_p * ranged_mult * (1.0 if d > 1 else 0.85))
	return out

## Best single strike an enemy could land at full HP.
static func _strike_power(enemy: Legion) -> float:
	var action_ids: Array = ActionDefs.legion_action_ids(enemy)
	var melee_p := _legion_melee_power(enemy) if "melee_attack" in action_ids else 0.0
	var ranged_p := _legion_ranged_power(enemy) if "ranged_attack" in action_ids else 0.0
	return maxf(melee_p, ranged_p) * _hp_frac(enemy)

static func _hp_frac(legion: Legion) -> float:
	var cur := 0.0
	var mx := 0.0
	for u in legion.units:
		if u:
			cur += float(u.current_health)
			mx += float(u.max_health)
	return clampf(cur / maxf(mx, 1.0), 0.0, 1.0)

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
