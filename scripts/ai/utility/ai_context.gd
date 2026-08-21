class_name AiContext
extends RefCounted

## Per-activation cache shared by candidate gen + feature extract.

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")

var session
var legion: Legion
var team_id: String = ""
var enemies: Array[Legion] = []
var allies: Array[Legion] = []
var focus: Legion = null
var map_radius_approx: float = 3.0
var reach: Dictionary = {}

static func build(p_session, p_legion: Legion) -> AiContext:
	var ctx := AiContext.new()
	ctx.session = p_session
	ctx.legion = p_legion
	if p_legion == null:
		return ctx
	ctx.team_id = p_legion.team_id
	ctx.map_radius_approx = _approx_map_radius(p_session)
	for L in p_session.legions:
		if L == null or L.units.is_empty():
			continue
		if L.team_id == p_legion.team_id:
			if L != p_legion:
				ctx.allies.append(L)
		else:
			ctx.enemies.append(L)
	ctx.focus = _pick_focus(p_legion.tile_coords, ctx.enemies)
	ctx.reach = MoveReachability.compute(p_session.battle_state(), p_legion)
	return ctx

static func _approx_map_radius(session) -> float:
	if session == null or session.grid.is_empty():
		return 3.0
	var best := 0
	for coords in session.grid.keys():
		var c: Vector2i = coords
		best = maxi(best, maxi(absi(c.x), absi(c.y)))
	return maxf(1.0, float(best))

static func _pick_focus(from_coords: Vector2i, enemies: Array[Legion]) -> Legion:
	if enemies.is_empty():
		return null
	var ranked: Array[Legion] = enemies.duplicate()
	ranked.sort_custom(func(a: Legion, b: Legion) -> bool:
		var sa := 0 if AiActionScorer.is_frontline(a) else 1
		var sb := 0 if AiActionScorer.is_frontline(b) else 1
		if sa != sb:
			return sa > sb
		var ha := _total_hp(a)
		var hb := _total_hp(b)
		if not is_equal_approx(ha, hb):
			return ha < hb
		return HexPathfinder.hex_distance(from_coords, a.tile_coords) < HexPathfinder.hex_distance(
			from_coords, b.tile_coords
		)
	)
	return ranked[0]

static func _total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.current_health)
	return t

func dist_to_focus(from_coords: Vector2i) -> float:
	if focus == null:
		return 0.0
	return float(HexPathfinder.hex_distance(from_coords, focus.tile_coords))
