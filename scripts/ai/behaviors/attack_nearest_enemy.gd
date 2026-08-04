class_name AttackNearestEnemyBehavior
extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const Utils = preload("res://scripts/core/utils.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")

static var debug_enabled: bool = false

static func decide(session: MatchSessionScript, legion: Legion) -> Dictionary:
	var cmd := _decide_internal(session, legion)
	if debug_enabled:
		_log_decision(legion, cmd)
	return cmd

static func sort_actionable_by_enemy_distance(
	session: MatchSessionScript,
	actionable: Array[Vector2i]
) -> Array[Vector2i]:
	## Activation order tree (simple, deterministic):
	## 1) Closest to any enemy first (hex distance)
	## 2) Same distance: units that can attack now before pure movers
	## 3) Stable coord tie-break
	## Re-queried each activation so after a front unit moves/waits, the new
	## closest acts — rear units stop blocking each other less often.
	if actionable.is_empty():
		return actionable
	var enemies := _enemy_legions(session, session.turn_manager.active_team_id)
	if enemies.is_empty():
		return actionable.duplicate()

	var scored: Array[Dictionary] = []
	for coords in actionable:
		scored.append({
			"coords": coords,
			"dist": _min_enemy_distance(coords, enemies),
			"can_fight": _can_fight_now(session, coords),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = int(a["dist"])
		var db: int = int(b["dist"])
		if da != db:
			return da < db
		var fa: bool = bool(a["can_fight"])
		var fb: bool = bool(b["can_fight"])
		if fa != fb:
			return fa and not fb
		var ca: Vector2i = a["coords"]
		var cb: Vector2i = b["coords"]
		if ca.x != cb.x:
			return ca.x < cb.x
		return ca.y < cb.y
	)

	var sorted: Array[Vector2i] = []
	for row in scored:
		sorted.append(row["coords"])
	if debug_enabled:
		var parts: PackedStringArray = []
		for row in scored:
			parts.append(
				"%s(d=%d%s)"
				% [row["coords"], row["dist"], ",fight" if bool(row["can_fight"]) else ""]
			)
		print("[AI] Legion order (closest first): %s" % ", ".join(parts))
	return sorted

static func _can_fight_now(session: MatchSessionScript, coords: Vector2i) -> bool:
	var legion: Legion = session.get_legion_at(coords)
	if legion == null or not session.can_act_legion(legion):
		return false
	if not session.get_action_targets(legion, "melee_attack").is_empty():
		return true
	if not session.get_action_targets(legion, "ranged_attack").is_empty():
		return true
	return false

static func _decide_internal(session: MatchSessionScript, legion: Legion) -> Dictionary:
	if legion == null:
		return _cmd_pass(legion, "no legion")
	if legion.units.is_empty():
		return _cmd_pass(legion, "empty legion")
	if not session.can_act_legion(legion):
		return _cmd_pass(legion, "cannot act")

	var enemies := _enemy_legions(session, legion.team_id)
	if enemies.is_empty():
		return _cmd_pass(legion, "no enemies")

	# Greedy: score every legal action/target this activation; pick best net HP delta.
	var best_score := -INF
	var best_cmd: Dictionary = {}
	for action_id in ActionDefs.legion_action_ids(legion):
		if action_id == "move" or action_id == "teleport":
			continue
		var targets := session.get_action_targets(legion, action_id)
		for to_coords in targets:
			var score := AiActionScorer.score_action(session, legion, action_id, to_coords)
			if score > best_score:
				best_score = score
				best_cmd = {
					"type": "use_action",
					"action_id": action_id,
					"from": legion.tile_coords,
					"to": to_coords,
					"reason": "greedy score %.1f (%s -> %s)" % [score, action_id, to_coords],
				}

	# Prefer any combat/heal over movement — greedy already picked the best among them.
	if not best_cmd.is_empty():
		return best_cmd

	# Move toward nearest enemy with soft pathfinding + role positioning.
	if not legion.can_afford(1):
		return _cmd_pass(legion, "cannot afford move")

	var movable := session.get_movable_coords(legion.tile_coords)
	if movable.is_empty():
		return _cmd_pass(legion, "no empty adjacent tiles")

	var nearest: Legion = _find_nearest_enemy(legion.tile_coords, enemies)
	var best_step: Variant = _best_step_toward(
		session, legion.tile_coords, nearest.tile_coords, movable, legion.team_id, legion
	)
	var step_enemy_coords := nearest.tile_coords
	if best_step == null:
		for enemy in enemies:
			if enemy.tile_coords == nearest.tile_coords:
				continue
			best_step = _best_step_toward(
				session, legion.tile_coords, enemy.tile_coords, movable, legion.team_id, legion
			)
			if best_step != null:
				step_enemy_coords = enemy.tile_coords
				break
	if best_step != null:
		return {
			"type": "use_action",
			"action_id": "move",
			"from": legion.tile_coords,
			"to": best_step,
			"reason": "step toward enemy @ %s" % step_enemy_coords,
		}

	return _cmd_pass(legion, "no step toward enemy @ %s" % nearest.tile_coords)

static func _cmd_pass(legion: Legion, reason: String) -> Dictionary:
	return {
		"type": "pass",
		"coords": legion.tile_coords if legion else Vector2i.ZERO,
		"reason": reason,
	}

static func _log_decision(legion: Legion, cmd: Dictionary) -> void:
	if legion == null:
		return
	var team := legion.team_id
	var coords := legion.tile_coords
	var cmd_type := String(cmd.get("type", "?"))
	var reason := String(cmd.get("reason", ""))
	match cmd_type:
		"use_action":
			print(
				"[AI] %s @ %s %s -> %s (%s)"
				% [team, coords, cmd.get("action_id", "?"), cmd.get("to", "?"), reason]
			)
		_:
			print("[AI] %s @ %s PASS (%s)" % [team, coords, reason])

static func _enemy_legions(session: MatchSessionScript, team_id: String) -> Array[Legion]:
	var out: Array[Legion] = []
	for legion in session.legions:
		if legion.team_id != team_id and not legion.units.is_empty():
			out.append(legion)
	return out

static func _find_nearest_enemy(from_coords: Vector2i, enemies: Array[Legion]) -> Legion:
	var best: Legion = enemies[0]
	var best_dist := HexPathfinder.hex_distance(from_coords, best.tile_coords)
	for i in range(1, enemies.size()):
		var enemy: Legion = enemies[i]
		var dist := HexPathfinder.hex_distance(from_coords, enemy.tile_coords)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best

static func _pick_closest_coords(candidates: Array[Vector2i], from_coords: Vector2i) -> Vector2i:
	var best: Vector2i = candidates[0]
	var best_dist := HexPathfinder.hex_distance(from_coords, best)
	for i in range(1, candidates.size()):
		var c: Vector2i = candidates[i]
		var dist := HexPathfinder.hex_distance(from_coords, c)
		if dist < best_dist:
			best = c
			best_dist = dist
	return best

static func _min_enemy_distance(from_coords: Vector2i, enemies: Array[Legion]) -> int:
	var best := 2147483647
	for enemy in enemies:
		best = mini(best, HexPathfinder.hex_distance(from_coords, enemy.tile_coords))
	return best

static func _blocked_enemy_coords(session: MatchSessionScript, team_id: String, ignore_coords: Vector2i) -> Dictionary:
	var blocked: Dictionary = {}
	for legion in session.legions:
		if legion.tile_coords == ignore_coords:
			continue
		if legion.team_id != team_id:
			blocked[legion.tile_coords] = true
	return blocked

static func _best_step_toward(
	session: MatchSessionScript,
	from_coords: Vector2i,
	enemy_coords: Vector2i,
	movable: Array[Vector2i],
	team_id: String,
	legion: Legion = null
) -> Variant:
	var blocked := _blocked_enemy_coords(session, team_id, from_coords)
	# Near set: occupied tiles in the current movable neighborhood are hard blocks for planning.
	var hard_near: Dictionary = {}
	for step in movable:
		var tile: Tile = session.grid.get(step)
		if tile and tile.has_legion():
			hard_near[step] = true

	var frontline := legion == null or AiActionScorer.is_frontline(legion)
	var best_path: Array[Vector2i] = []
	var best_goal_score := INF

	var approach_hexes: Array[Vector2i] = []
	for goal in Utils.get_surrounding_coords(enemy_coords):
		approach_hexes.append(goal)
	# Backline prefers a ring at distance 2 when possible.
	if not frontline:
		var ring2: Dictionary = {}
		for adj in Utils.get_surrounding_coords(enemy_coords):
			for outer in Utils.get_surrounding_coords(adj):
				if HexPathfinder.hex_distance(outer, enemy_coords) == 2:
					ring2[outer] = true
		for c in ring2.keys():
			approach_hexes.append(c)

	for goal in approach_hexes:
		if goal == enemy_coords:
			continue
		var goal_tile: Tile = session.grid.get(goal)
		if goal_tile == null or not goal_tile.walkable:
			continue
		if goal_tile.has_legion() and goal in hard_near:
			continue
		var path := HexPathfinder.find_path(
			session.grid, from_coords, goal, blocked, true, hard_near
		)
		if path.size() < 2:
			continue
		var goal_pref := float(path.size())
		if frontline:
			goal_pref += float(HexPathfinder.hex_distance(goal, enemy_coords)) * 0.01
		else:
			# Prefer staying at ranged distance (2+) over hugging melee.
			var gd := HexPathfinder.hex_distance(goal, enemy_coords)
			goal_pref += 0.0 if gd >= 2 else 2.0
		if best_path.is_empty() or goal_pref < best_goal_score:
			best_goal_score = goal_pref
			best_path = path

	if best_path.size() >= 2:
		for i in range(1, best_path.size()):
			var step: Vector2i = best_path[i]
			if step in movable:
				return step

	return _choose_step_toward(from_coords, enemy_coords, movable, frontline)

static func _choose_step_toward(
	from_coords: Vector2i,
	enemy_coords: Vector2i,
	movable: Array[Vector2i],
	frontline: bool = true
) -> Variant:
	if movable.is_empty():
		return null

	var current_dist := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var prefer_closer := frontline or current_dist > 2

	var best_closer: Vector2i = Vector2i(2147483646, 2147483646)
	var best_closer_dist := current_dist
	for coords in movable:
		var dist := HexPathfinder.hex_distance(coords, enemy_coords)
		if dist < best_closer_dist:
			best_closer_dist = dist
			best_closer = coords
	if prefer_closer and best_closer_dist < current_dist:
		return best_closer

	# Backline at distance 1 tries to step away to 2 if possible.
	if not frontline and current_dist <= 1:
		var best_away: Variant = null
		var best_away_dist := current_dist
		for coords in movable:
			var dist := HexPathfinder.hex_distance(coords, enemy_coords)
			if dist > best_away_dist:
				best_away_dist = dist
				best_away = coords
		if best_away != null:
			return best_away

	if best_closer_dist < current_dist:
		return best_closer

	# Same-distance flank steps: prefer positive alignment, but accept any.
	var best_lateral: Vector2i = Vector2i(2147483646, 2147483646)
	var best_lateral_align := -INF
	var any_lateral: Variant = null
	for coords in movable:
		var dist := HexPathfinder.hex_distance(coords, enemy_coords)
		if dist != current_dist:
			continue
		if any_lateral == null:
			any_lateral = coords
		var align := _alignment_toward(from_coords, coords, enemy_coords)
		if align > best_lateral_align:
			best_lateral_align = align
			best_lateral = coords
	if best_lateral_align > 0.0:
		return best_lateral
	if any_lateral != null:
		return any_lateral

	var best_fallback: Vector2i = Vector2i(2147483646, 2147483646)
	var best_fallback_align := -INF
	for coords in movable:
		var align := _alignment_toward(from_coords, coords, enemy_coords)
		if align > best_fallback_align:
			best_fallback_align = align
			best_fallback = coords
	if best_fallback_align > 0.0:
		return best_fallback

	# Last resort: any legal step that does not increase distance.
	for coords in movable:
		if HexPathfinder.hex_distance(coords, enemy_coords) <= current_dist:
			return coords

	return null

static func _alignment_toward(from_coords: Vector2i, step_coords: Vector2i, goal_coords: Vector2i) -> float:
	var to_goal := _axial_to_cube(goal_coords) - _axial_to_cube(from_coords)
	var step_dir := _axial_to_cube(step_coords) - _axial_to_cube(from_coords)
	if to_goal == Vector3i.ZERO or step_dir == Vector3i.ZERO:
		return 0.0
	return float(to_goal.x * step_dir.x + to_goal.y * step_dir.y + to_goal.z * step_dir.z)

static func _axial_to_cube(axial: Vector2i) -> Vector3i:
	return Vector3i(axial.x, -axial.x - axial.y, axial.y)
