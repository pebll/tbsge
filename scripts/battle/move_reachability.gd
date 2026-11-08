class_name MoveReachability
extends RefCounted

## Multi-AP move BFS: reachable tiles, path reconstruction, ambiguous first steps.

const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")
const Utils = preload("res://scripts/core/utils.gd")

## Returns { reachable: Array[Vector2i], cost: Dictionary, parents: Dictionary }
## Cheapest AP cost to every tile the legion can reach this turn (terrain costs via
## TerrainRules.enter_cost; swaps with allies allowed when the ally can pay its own step).
## `parents` keeps every predecessor on a cheapest path (ambiguous first steps).
static func compute(state: BattleStateScript, legion: Legion) -> Dictionary:
	var empty := {"reachable": [], "cost": {}, "parents": {}}
	if state == null or legion == null:
		return empty
	var budget := legion.current_ap
	if budget <= 0:
		return empty

	var start := legion.tile_coords
	var cost: Dictionary = {start: 0}
	var parents: Dictionary = {start: []}
	var done: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		# Small maps: linear min-pick is plenty.
		var bi := 0
		for i in range(1, frontier.size()):
			if int(cost[frontier[i]]) < int(cost[frontier[bi]]):
				bi = i
		var cur: Vector2i = frontier[bi]
		frontier.remove_at(bi)
		if done.has(cur):
			continue
		done[cur] = true
		var cur_cost: int = int(cost[cur])
		for step in _adjacent_steps(state, cur, legion, start):
			var nxt: Vector2i = step[0]
			var nxt_cost: int = cur_cost + int(step[1])
			if nxt_cost > budget:
				continue
			if not cost.has(nxt) or nxt_cost < int(cost[nxt]):
				cost[nxt] = nxt_cost
				parents[nxt] = [cur]
				frontier.append(nxt)
			elif nxt_cost == int(cost[nxt]):
				var plist: Array = parents[nxt]
				if cur not in plist:
					plist.append(cur)

	var reachable: Array[Vector2i] = []
	for c in cost.keys():
		if c == start:
			continue
		reachable.append(c)
	return {"reachable": reachable, "cost": cost, "parents": parents}

## Returns { ok, path, first_steps, ambiguous, cost }
static func analyze_destination(
	state: BattleStateScript,
	legion: Legion,
	dest: Vector2i
) -> Dictionary:
	var data := compute(state, legion)
	var cost: Dictionary = data["cost"]
	var parents: Dictionary = data["parents"]
	if not cost.has(dest) or dest == legion.tile_coords:
		return {"ok": false}

	var first_steps := first_steps_to(legion.tile_coords, dest, parents)
	var ambiguous := false
	if first_steps.size() > 1:
		for step in first_steps:
			if ActionTargetingScript.is_swap_target(state, legion.tile_coords, step):
				ambiguous = true
				break
		# Multiple non-swap first steps still matter if player cares about facing/path —
		# only re-ask when a swap is involved or steps differ and all are swaps/empty mix.
		if not ambiguous:
			ambiguous = false  # empty-only forks auto-resolve
	var path := reconstruct_path(legion.tile_coords, dest, parents, first_steps[0] if not first_steps.is_empty() else legion.tile_coords)
	return {
		"ok": true,
		"path": path,
		"first_steps": first_steps,
		"ambiguous": ambiguous and first_steps.size() > 1,
		"cost": int(cost[dest]),
	}

static func path_after_first_step(
	start: Vector2i,
	dest: Vector2i,
	first_step: Vector2i,
	parents: Dictionary
) -> Array[Vector2i]:
	return reconstruct_path(start, dest, parents, first_step)

static func first_steps_to(start: Vector2i, dest: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	var found: Dictionary = {}
	var stack: Array = [[dest]]
	while not stack.is_empty():
		var path: Array = stack.pop_back()
		var cur: Vector2i = path[path.size() - 1]
		if cur == start:
			if path.size() >= 2:
				found[path[path.size() - 2]] = true
			continue
		for p in parents.get(cur, []):
			if p in path:
				continue
			var np: Array = path.duplicate()
			np.append(p)
			stack.append(np)
	var out: Array[Vector2i] = []
	for fs in found.keys():
		out.append(fs)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	return out

static func reconstruct_path(
	start: Vector2i,
	dest: Vector2i,
	parents: Dictionary,
	required_first_step: Vector2i
) -> Array[Vector2i]:
	var stack: Array = [[dest]]
	while not stack.is_empty():
		var path: Array = stack.pop_back()
		var cur: Vector2i = path[path.size() - 1]
		if cur == start:
			if path.size() >= 2 and path[path.size() - 2] == required_first_step:
				path.reverse()
				var out: Array[Vector2i] = []
				for c in path:
					out.append(c)
				return out
			continue
		var plist: Array = parents.get(cur, [])
		# Prefer lexicographically smaller parents for determinism.
		var ordered: Array = plist.duplicate()
		ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y)
		)
		for p in ordered:
			if p in path:
				continue
			var np: Array = path.duplicate()
			np.append(p)
			stack.append(np)
	return [start, required_first_step]

## [[coords, ap_cost], ...] for one step from `from_coords`: empty enterable tiles, and
## allied legions to swap with when they can pay to step back onto `from_coords`.
static func _adjacent_steps(
	state: BattleStateScript,
	from_coords: Vector2i,
	legion: Legion,
	mover_start: Vector2i
) -> Array:
	var out: Array = []
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null:
		return out
	for c in Utils.get_surrounding_coords(from_coords):
		var t: Tile = state.tile_at(c)
		if t == null:
			continue
		var step_cost := TerrainRules.enter_cost(legion, t)
		if step_cost < 0:
			continue
		if t.has_legion() and t.legion != legion:
			var other: Legion = t.legion
			if other.team_id != legion.team_id:
				continue
			# The ally steps back onto from_coords (where the mover stood before this step).
			var back_cost := TerrainRules.enter_cost(other, from_tile if from_coords != mover_start else state.tile_at(mover_start))
			if back_cost < 0 or not other.can_afford(back_cost):
				continue
		out.append([c, step_cost])
	return out
