extends RefCounted

## Team view for one activation: which other allies can still strike a given enemy this
## turn, and roughly how hard. Lets one legion pick the target the rest of the team can
## finish (focus fire) instead of scoring its fight in isolation.
##
## Cheap on purpose: no Monte Carlo. Each ally's follow-up is its raw strike power (every
## unit hits once, as in CombatResolver), melee discounted for losses to retaliation.

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")
const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")

## Melee follow-ups take retaliation and lose attackers mid-fight.
const MELEE_FOLLOWUP_MULT := 0.8

var session
var acting: Legion
## One row per ally that can still act: {"legion", "stands": Array[Vector2i]}.
var _allies: Array = []
var _followup_cache: Dictionary = {}  # target instance id -> float

## Usage: AiTeamPlanScript.new().setup(session, acting_legion)
func setup(p_session, p_acting: Legion):
	session = p_session
	acting = p_acting
	if p_session == null or p_acting == null:
		return self
	for L in p_session.legions:
		if L == null or L == p_acting or L.units.is_empty():
			continue
		if L.team_id != p_acting.team_id or not p_session.can_act_legion(L):
			continue
		_allies.append({"legion": L, "stands": _strike_stands(p_session, L)})
	return self

## Tiles the ally can stand on this turn with at least 1 AP left to attack: its own tile,
## plus empty tiles it can walk to.
static func _strike_stands(p_session, ally: Legion) -> Array:
	var stands: Array = [ally.tile_coords]
	var reach: Dictionary = MoveReachability.compute(p_session.battle_state(), ally)
	var cost: Dictionary = reach.get("cost", {})
	for dest in reach.get("reachable", []):
		var c: Vector2i = dest
		if int(cost.get(c, 999)) >= ally.current_ap:
			continue
		var tile: Tile = p_session.grid.get(c)
		if tile == null or not tile.walkable or tile.has_legion():
			continue
		stands.append(c)
	return stands

func ally_count() -> int:
	return _allies.size()

## Expected damage the other allies could still add to `target` this turn, summed over every
## ally that can reach a strike on it (each counted at its best stand).
func followup_damage(target: Legion) -> float:
	if target == null:
		return 0.0
	var key := target.get_instance_id()
	if _followup_cache.has(key):
		return float(_followup_cache[key])
	var total := 0.0
	for row in _allies:
		total += _best_strike(row["legion"], row["stands"], target.tile_coords, session.grid)
	_followup_cache[key] = total
	return total

static func _best_strike(ally: Legion, stands: Array, target_coords: Vector2i, grid: Dictionary = {}) -> float:
	var ids: Array = ActionDefs.legion_action_ids(ally)
	var can_melee := "melee_attack" in ids and ally.is_action_ready("melee_attack")
	var can_shoot := "ranged_attack" in ids and ally.is_action_ready("ranged_attack")
	var best := 0.0
	for s in stands:
		var d := HexPathfinder.hex_distance(s, target_coords)
		if can_melee and d == 1:
			best = maxf(best, melee_power(ally) * MELEE_FOLLOWUP_MULT)
		if can_shoot and d >= 1 and (d == 1 or grid.is_empty() or TerrainRules.has_los(grid, s, target_coords)):
			best = maxf(best, ranged_power(ally, d))
	return best

static func melee_power(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.attack)
	return t

static func ranged_power(legion: Legion, distance: int) -> float:
	var t := 0.0
	for u in legion.units:
		if u and u.ranged_attack > 0 and u.attack_range >= distance:
			t += float(u.ranged_attack)
	return t

## HP plus remaining shields: what the team must chew through to wipe the legion.
static func effective_hp(legion: Legion) -> float:
	var t := 0.0
	if legion == null:
		return t
	for u in legion.units:
		if u:
			t += maxf(0.0, float(u.current_health)) + maxf(0.0, float(u.shield_remaining))
	return t
