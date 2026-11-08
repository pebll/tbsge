extends RefCounted

## Terrain rules in one place: movement cost, cover, attack bonus, line of sight, vision.
## Terrain types are data (data/terrain/*.tres, TerrainDefinition); units can have
## per-terrain affinities (UnitDefinition.terrain_affinity) and the "flying" trait.
##
## A legion's step cost is the highest cost among its units (the slowest sets the pace).
## Flyers (every unit has the flying trait) pay 1 everywhere they may enter.

const DIR := "res://data/terrain"
const UnitTraits = preload("res://scripts/effects/unit_traits.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")

const IMPASSABLE := -1

static var _defs: Dictionary = {}
static var _loaded := false

static func get_def(terrain_id: String) -> Resource:
	_ensure_loaded()
	return _defs.get(terrain_id)

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _defs.keys():
		out.append(String(k))
	out.sort()
	return out

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for f in DirAccess.get_files_at(DIR):
		var name := String(f).trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def = load(DIR + "/" + name)
		if def != null and not String(def.id).is_empty():
			_defs[def.id] = def

static func ground_walkable(terrain_id: String) -> bool:
	var def = get_def(terrain_id)
	return def.walkable if def != null else not (terrain_id in ["MOUNTAIN", "WATER"])

## Every unit flies (a mixed legion is only as mobile as its slowest walker).
static func is_flyer(legion: Legion) -> bool:
	if legion == null or legion.units.is_empty():
		return false
	for u in legion.units:
		if u == null or not UnitTraits.has_trait(u, UnitTraits.FLYING):
			return false
	return true

static func _affinity(unit: Unit, terrain_id: String) -> Dictionary:
	if unit == null or unit.definition == null:
		return {}
	var a = unit.definition.terrain_affinity.get(terrain_id)
	return a if a is Dictionary else {}

## AP for `legion` to step onto `tile` (IMPASSABLE if it can't). Occupancy is not checked.
static func enter_cost(legion: Legion, tile: Tile) -> int:
	if tile == null or legion == null:
		return IMPASSABLE
	var def = get_def(tile.terrain_type)
	if is_flyer(legion):
		if def != null and not (def.flyer_can_cross and def.flyer_can_stop):
			return IMPASSABLE
		return 1
	if not tile.walkable:
		return IMPASSABLE
	var base: int = def.move_cost if def != null else 1
	var cost := 0
	for u in legion.units:
		var a := _affinity(u, tile.terrain_type)
		cost = maxi(cost, int(a.get("move_cost", base)))
	return maxi(1, cost if not legion.units.is_empty() else base)

## Combat modifiers per strike. `options` from combat_options(): attacker/defender terrain.
static func modify_strike(
	attacker_unit: Unit, attacker_terrain: String, target_unit: Unit, defender_terrain: String,
	mode: String, damage: float
) -> float:
	var d := damage
	if attacker_unit != null and not attacker_terrain.is_empty():
		d += float(_affinity(attacker_unit, attacker_terrain).get("attack", 0.0))
	if target_unit != null and not defender_terrain.is_empty():
		var def = get_def(defender_terrain)
		var flyer := UnitTraits.has_trait(target_unit, UnitTraits.FLYING)
		# Cover is for units on the ground.
		if def != null and not flyer:
			d *= def.ranged_defense if mode == "ranged" else def.melee_defense
		d *= float(_affinity(target_unit, defender_terrain).get("defense", 1.0))
	return maxf(0.0, d)

## Terrain the two legions fight on, for CombatResolver options.
static func combat_options(grid: Dictionary, from_coords: Vector2i, to_coords: Vector2i) -> Dictionary:
	var a: Tile = grid.get(from_coords)
	var b: Tile = grid.get(to_coords)
	return {
		"attacker_terrain": a.terrain_type if a else "",
		"defender_terrain": b.terrain_type if b else "",
	}

## Hexes strictly between a and b on the straight line (cube lerp, nudged off ties).
static func hexes_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := HexPathfinder.hex_distance(a, b)
	if n <= 1:
		return out
	var aq := float(a.x) + 1e-6
	var ar := float(a.y) + 1e-6
	var bq := float(b.x) + 1e-6
	var br := float(b.y) + 1e-6
	for i in range(1, n):
		var t := float(i) / float(n)
		var c := _cube_round(lerpf(aq, bq, t), lerpf(ar, br, t))
		if c != a and c != b and c not in out:
			out.append(c)
	return out

static func _cube_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))

## Line of sight: no LOS-blocking terrain strictly between the two hexes.
static func has_los(grid: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	for c in hexes_between(a, b):
		var t: Tile = grid.get(c)
		if t == null:
			continue
		var def = get_def(t.terrain_type)
		if def != null and def.blocks_los:
			return false
	return true

static func vision_mod(terrain_id: String) -> int:
	var def = get_def(terrain_id)
	return def.vision_mod if def != null else 0

static func label(terrain_id: String) -> String:
	var def = get_def(terrain_id)
	return def.display_name if def != null else terrain_id.capitalize()
