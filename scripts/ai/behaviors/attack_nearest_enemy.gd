class_name AttackNearestEnemyBehavior
extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const Utils = preload("res://scripts/core/utils.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")

static var debug_enabled: bool = true

static func decide(session: MatchSessionScript, legion: Legion) -> Dictionary:
	var cmd := _decide_internal(session, legion)
	if debug_enabled:
		_log_decision(legion, cmd)
	return cmd

static func sort_actionable_by_enemy_distance(
	session: MatchSessionScript,
	actionable: Array[Vector2i]
) -> Array[Vector2i]:
	if actionable.is_empty():
		return actionable
	var enemies := _enemy_legions(session, session.turn_manager.active_team_id)
	if enemies.is_empty():
		return actionable.duplicate()
	var sorted := actionable.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _min_enemy_distance(a, enemies)
		var db := _min_enemy_distance(b, enemies)
		if da == db:
			if a.x == b.x:
				return a.y < b.y
			return a.x < b.x
		return da < db
	)
	if debug_enabled:
		print("[AI] Legion order (nearest enemy first): %s" % str(sorted))
	return sorted

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

	var nearest: Legion = _find_nearest_enemy(legion.tile_coords, enemies)
	var nearest_coords := nearest.tile_coords
	var from_coords := legion.tile_coords

	var ranged_targets := session.get_action_targets(legion, "ranged_attack")
	if nearest_coords in ranged_targets:
		var dist := HexPathfinder.hex_distance(from_coords, nearest_coords)
		# Prefer ranged when out of melee, or when defender cannot shoot back at this distance.
		var melee_targets := session.get_attackable_coords(from_coords)
		var defender_can_return := false
		if not nearest.units.is_empty():
			var du: Unit = nearest.units[0]
			defender_can_return = du != null and du.attack_range >= dist and du.ranged_attack > 0
		if dist > 1 or nearest_coords not in melee_targets or not defender_can_return:
			return {
				"type": "use_action",
				"action_id": "ranged_attack",
				"from": from_coords,
				"to": nearest_coords,
				"reason": "ranged shot at nearest enemy @ %s (d=%d)" % [nearest_coords, dist],
			}

	var attackable := session.get_attackable_coords(from_coords)
	if nearest_coords in attackable:
		return {
			"type": "use_action",
			"action_id": "melee_attack",
			"from": from_coords,
			"to": nearest_coords,
			"reason": "adjacent to nearest enemy @ %s" % nearest_coords,
		}

	# If nearest is not in melee but another enemy is in ranged range, take the shot.
	if not ranged_targets.is_empty():
		var best_ranged: Vector2i = ranged_targets[0]
		var best_d := HexPathfinder.hex_distance(from_coords, best_ranged)
		for c in ranged_targets:
			var d := HexPathfinder.hex_distance(from_coords, c)
			if d < best_d:
				best_d = d
				best_ranged = c
		return {
			"type": "use_action",
			"action_id": "ranged_attack",
			"from": from_coords,
			"to": best_ranged,
			"reason": "ranged shot at enemy in range @ %s" % best_ranged,
		}

	if not legion.can_afford(1):
		return _cmd_pass(legion, "cannot afford move")

	var movable := session.get_movable_coords(from_coords)
	if movable.is_empty():
		return _cmd_pass(legion, "no empty adjacent tiles")

	var best_step: Variant = _best_step_toward(session, from_coords, nearest_coords, movable, legion.team_id)
	if best_step == null:
		return _cmd_pass(legion, "no step toward enemy @ %s" % nearest_coords)

	return {
		"type": "use_action",
		"action_id": "move",
		"from": from_coords,
		"to": best_step,
		"reason": "step toward enemy @ %s" % nearest_coords,
	}

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
	team_id: String
) -> Variant:
	var blocked := _blocked_enemy_coords(session, team_id, from_coords)
	var best_path: Array[Vector2i] = []

	for goal in Utils.get_surrounding_coords(enemy_coords):
		if goal == enemy_coords:
			continue
		var goal_tile: Tile = session.grid.get(goal)
		if goal_tile == null or not goal_tile.walkable:
			continue
		if goal_tile.has_legion() and goal_tile.legion.team_id != team_id:
			continue
		var path := HexPathfinder.find_path(session.grid, from_coords, goal, blocked)
		if path.size() < 2:
			continue
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

	if best_path.size() >= 2:
		for i in range(1, best_path.size()):
			var step: Vector2i = best_path[i]
			if step in movable:
				return step

	return _choose_step_toward(from_coords, enemy_coords, movable)

static func _choose_step_toward(
	from_coords: Vector2i,
	enemy_coords: Vector2i,
	movable: Array[Vector2i]
) -> Variant:
	if movable.is_empty():
		return null

	var current_dist := HexPathfinder.hex_distance(from_coords, enemy_coords)

	var best_closer: Vector2i = Vector2i(2147483646, 2147483646)
	var best_closer_dist := current_dist
	for coords in movable:
		var dist := HexPathfinder.hex_distance(coords, enemy_coords)
		if dist < best_closer_dist:
			best_closer_dist = dist
			best_closer = coords
	if best_closer_dist < current_dist:
		return best_closer

	var best_lateral: Vector2i = Vector2i(2147483646, 2147483646)
	var best_lateral_align := -INF
	for coords in movable:
		var dist := HexPathfinder.hex_distance(coords, enemy_coords)
		if dist != current_dist:
			continue
		var align := _alignment_toward(from_coords, coords, enemy_coords)
		if align > best_lateral_align:
			best_lateral_align = align
			best_lateral = coords
	if best_lateral_align > 0.0:
		return best_lateral

	var best_fallback: Vector2i = Vector2i(2147483646, 2147483646)
	var best_fallback_align := -INF
	for coords in movable:
		var align := _alignment_toward(from_coords, coords, enemy_coords)
		if align > best_fallback_align:
			best_fallback_align = align
			best_fallback = coords
	if best_fallback_align > 0.0:
		return best_fallback

	return null

static func _alignment_toward(from_coords: Vector2i, step_coords: Vector2i, goal_coords: Vector2i) -> float:
	var to_goal := _axial_to_cube(goal_coords) - _axial_to_cube(from_coords)
	var step_dir := _axial_to_cube(step_coords) - _axial_to_cube(from_coords)
	if to_goal == Vector3i.ZERO or step_dir == Vector3i.ZERO:
		return 0.0
	return float(to_goal.x * step_dir.x + to_goal.y * step_dir.y + to_goal.z * step_dir.z)

static func _axial_to_cube(axial: Vector2i) -> Vector3i:
	return Vector3i(axial.x, -axial.x - axial.y, axial.y)
