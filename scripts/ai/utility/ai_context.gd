class_name AiContext
extends RefCounted

## Per-activation cache shared by candidate gen + feature extract.

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")
const ThreatMapScript = preload("res://scripts/ai/threat/threat_map.gd")
const Utils = preload("res://scripts/core/utils.gd")
const AiTeamPlanScript = preload("res://scripts/ai/utility/ai_team_plan.gd")
const TerrainRulesScript = preload("res://scripts/terrain/terrain_rules.gd")

var session
var legion: Legion
var team_id: String = ""
var enemies: Array[Legion] = []
var allies: Array[Legion] = []
var focus: Legion = null
var map_radius_approx: float = 3.0
var reach: Dictionary = {}
var threat = null
## Walking distance (steps) from the focus legion over walkable tiles; legions are passable.
var focus_field: Dictionary = {}
var unreachable_dist: float = 0.0
var _team_plan = null

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
	ctx.unreachable_dist = float(maxi(1, p_session.grid.size()) * 2)
	_assign_focus(ctx, p_session, p_legion)
	ctx.reach = MoveReachability.compute(p_session.battle_state(), p_legion)
	ctx.threat = ThreatMapScript.build(p_session, p_legion.team_id)
	return ctx

static func _approx_map_radius(session) -> float:
	if session == null or session.grid.is_empty():
		return 3.0
	var best := 0
	for coords in session.grid.keys():
		var c: Vector2i = coords
		best = maxi(best, maxi(absi(c.x), absi(c.y)))
	return maxf(1.0, float(best))

## Picks the preferred enemy that the acting legion can walk to; falls back to the
## overall preference when none is reachable.
static func _assign_focus(ctx: AiContext, p_session, p_legion: Legion) -> void:
	for candidate in _rank_enemies(p_legion.tile_coords, ctx.enemies):
		var field := approach_field(p_session.grid, candidate.tile_coords, p_legion)
		if field.has(p_legion.tile_coords):
			ctx.focus = candidate
			ctx.focus_field = field
			return
	var ranked := _rank_enemies(p_legion.tile_coords, ctx.enemies)
	if not ranked.is_empty():
		ctx.focus = ranked[0]
		ctx.focus_field = approach_field(p_session.grid, ranked[0].tile_coords, p_legion)

## Walking cost (AP) from `origin` over walkable tiles, using each terrain's base move cost
## (forest / swamp count double). Legions are ignored because they move or swap.
## Approach cost to `origin` for this legion: walking costs for ground legions, straight
## hex distance for flyers (they cross water and mountains at 1 AP per hex).
static func approach_field(grid: Dictionary, origin: Vector2i, legion: Legion) -> Dictionary:
	if not TerrainRulesScript.is_flyer(legion):
		return walk_distance_field(grid, origin)
	var out: Dictionary = {}
	for c in grid.keys():
		out[c] = HexPathfinder.hex_distance(origin, c)
	return out

static func walk_distance_field(grid: Dictionary, origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var done: Dictionary = {}
	while not frontier.is_empty():
		var bi := 0
		for i in range(1, frontier.size()):
			if int(dist[frontier[i]]) < int(dist[frontier[bi]]):
				bi = i
		var cur: Vector2i = frontier[bi]
		frontier.remove_at(bi)
		if done.has(cur):
			continue
		done[cur] = true
		for nxt in Utils.get_surrounding_coords(cur):
			var tile: Tile = grid.get(nxt)
			if tile == null or not tile.walkable:
				continue
			var def = TerrainRulesScript.get_def(tile.terrain_type)
			var nd: int = int(dist[cur]) + (int(def.move_cost) if def != null else 1)
			if not dist.has(nxt) or nd < int(dist[nxt]):
				dist[nxt] = nd
				frontier.append(nxt)
	return dist

static func _rank_enemies(from_coords: Vector2i, enemies: Array[Legion]) -> Array[Legion]:
	if enemies.is_empty():
		return []
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
	return ranked

static func _total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.current_health)
	return t

func dist_to_focus(from_coords: Vector2i) -> float:
	if focus == null:
		return 0.0
	if focus_field.has(from_coords):
		return float(focus_field[from_coords])
	return unreachable_dist

## Built on first use: only combat candidates need it.
func team_plan():
	if _team_plan == null:
		_team_plan = AiTeamPlanScript.new().setup(session, legion)
	return _team_plan
