class_name MoveReachability
extends RefCounted

## Multi-AP move BFS: reachable tiles, path reconstruction, ambiguous first steps.

const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

## Returns { reachable: Array[Vector2i], cost: Dictionary, parents: Dictionary }
static func compute(state: BattleStateScript, legion: Legion) -> Dictionary:
	var empty := {"reachable": [], "cost": {}, "parents": {}}
	if state == null or legion == null:
		return empty
	var max_steps := legion.current_ap
	if max_steps <= 0:
		return empty

	var start := legion.tile_coords
	var cost: Dictionary = {start: 0}
	var parents: Dictionary = {start: []}
	var queue: Array[Vector2i] = [start]
	var qi := 0

	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		var cur_cost: int = int(cost[cur])
		if cur_cost >= max_steps:
			continue
		for nxt in _adjacent_move_targets(state, cur, legion.team_id, start):
			var nxt_cost := cur_cost + 1
			if not cost.has(nxt):
				cost[nxt] = nxt_cost
				parents[nxt] = [cur]
				queue.append(nxt)
			elif int(cost[nxt]) == nxt_cost:
				var plist: Array = parents[nxt]
				if cur not in plist:
					plist.append(cur)
					parents[nxt] = plist

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

static func _adjacent_move_targets(
	state: BattleStateScript,
	from_coords: Vector2i,
	team_id: String,
	_mover_start: Vector2i
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null:
		return out
	for t in Utils.get_movable_tiles(from_tile, state.grid):
		out.append(t.coords)
	# Allow swaps with friendly legions from any reachable tile.
	for t in Utils.get_swappable_tiles(from_tile, state.grid):
		if t.legion and t.legion.team_id == team_id and t.legion.can_afford(1):
			if t.coords not in out:
				out.append(t.coords)
	return out
