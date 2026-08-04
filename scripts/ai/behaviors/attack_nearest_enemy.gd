class_name AttackNearestEnemyBehavior
extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const Utils = preload("res://scripts/core/utils.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")

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
	## Closest to any enemy first; fighters before pure movers; coord tie-break.
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

	# Greedy: score combat / heal / teleport; pick best.
	var best_score := -INF
	var best_cmd: Dictionary = {}
	for action_id in ActionDefs.legion_action_ids(legion):
		if action_id == "move":
			continue
		var targets := session.get_action_targets(legion, action_id)
		for to_coords in targets:
			var score := AiActionScorer.score_action(session, legion, action_id, to_coords)
			if action_id in ["melee_attack", "ranged_attack", "teleport"]:
				score += _focus_bonus_at(session, to_coords, enemies)
			if score > best_score:
				best_score = score
				best_cmd = {
					"type": "use_action",
					"action_id": action_id,
					"from": legion.tile_coords,
					"to": to_coords,
					"reason": "greedy score %.1f (%s -> %s)" % [score, action_id, to_coords],
				}

	if not best_cmd.is_empty():
		if String(best_cmd.get("action_id", "")) != "teleport" or best_score >= 0.5:
			return best_cmd

	if not legion.can_afford(1):
		return _cmd_pass(legion, "cannot afford move")

	var focus: Legion = _pick_focus_enemy(legion.tile_coords, enemies)
	var walk := _plan_walk_toward(session, legion, focus)
	if walk.is_empty() and enemies.size() > 1:
		for enemy in _enemies_by_focus(legion.tile_coords, enemies):
			if enemy == focus:
				continue
			walk = _plan_walk_toward(session, legion, enemy)
			if not walk.is_empty():
				focus = enemy
				break

	if walk.size() < 2:
		return _cmd_pass(legion, "no step toward enemy @ %s" % focus.tile_coords)

	return {
		"type": "use_action",
		"action_id": "move",
		"from": walk[0],
		"to": walk[1],
		"path": walk,
		"reason": "path toward focus @ %s (%d steps)" % [focus.tile_coords, walk.size() - 1],
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
			var path: Array = cmd.get("path", [])
			var dest = cmd.get("to", "?")
			if path.size() >= 2:
				dest = "%s..%s" % [path[1], path[path.size() - 1]]
			print(
				"[AI] %s @ %s %s -> %s (%s)"
				% [team, coords, cmd.get("action_id", "?"), dest, reason]
			)
		_:
			print("[AI] %s @ %s PASS (%s)" % [team, coords, reason])

static func _enemy_legions(session: MatchSessionScript, team_id: String) -> Array[Legion]:
	var out: Array[Legion] = []
	for legion in session.legions:
		if legion.team_id != team_id and not legion.units.is_empty():
			out.append(legion)
	return out

static func _min_enemy_distance(from_coords: Vector2i, enemies: Array[Legion]) -> int:
	var best := 2147483647
	for enemy in enemies:
		best = mini(best, HexPathfinder.hex_distance(from_coords, enemy.tile_coords))
	return best

## Support/ranged (non-frontline) first, then weakest total HP, then closer.
static func _pick_focus_enemy(from_coords: Vector2i, enemies: Array[Legion]) -> Legion:
	var ranked := _enemies_by_focus(from_coords, enemies)
	return ranked[0]

static func _enemies_by_focus(from_coords: Vector2i, enemies: Array[Legion]) -> Array[Legion]:
	var ranked: Array[Legion] = enemies.duplicate()
	ranked.sort_custom(func(a: Legion, b: Legion) -> bool:
		var sa := 0 if AiActionScorer.is_frontline(a) else 1
		var sb := 0 if AiActionScorer.is_frontline(b) else 1
		if sa != sb:
			return sa > sb
		var ha := _legion_total_hp(a)
		var hb := _legion_total_hp(b)
		if ha != hb:
			return ha < hb
		var da := HexPathfinder.hex_distance(from_coords, a.tile_coords)
		var db := HexPathfinder.hex_distance(from_coords, b.tile_coords)
		return da < db
	)
	return ranked

static func _legion_total_hp(legion: Legion) -> float:
	var t := 0.0
	for u in legion.units:
		if u:
			t += float(u.current_health)
	return t

static func _focus_bonus_at(session: MatchSessionScript, to_coords: Vector2i, enemies: Array[Legion]) -> float:
	var at: Legion = session.get_legion_at(to_coords)
	if at == null or at not in enemies:
		# Teleport onto empty: small bonus if closer to a preferred focus later handled in scorer.
		return 0.0
	var bonus := 0.0
	if not AiActionScorer.is_frontline(at):
		bonus += 8.0
	bonus += 12.0 / maxf(1.0, _legion_total_hp(at))
	return bonus

## Soft-plan a path to a stand goal; return legal empty walk prefix up to remaining AP.
static func _plan_walk_toward(
	session: MatchSessionScript,
	legion: Legion,
	enemy: Legion
) -> Array[Vector2i]:
	var from_coords := legion.tile_coords
	var goals := _stand_goals(session, legion, enemy)
	if goals.is_empty():
		return []

	var best_path: Array[Vector2i] = []
	var best_cost := INF
	for goal in goals:
		if goal == from_coords:
			# Already on a valid stand hex — no move needed.
			return []
		var path := HexPathfinder.find_path(
			session.grid, from_coords, goal, {}, true, {}
		)
		if path.size() < 2:
			continue
		var cost := _path_soft_cost(session.grid, path)
		if cost < best_cost:
			best_cost = cost
			best_path = path

	if best_path.size() < 2:
		return []

	return _legal_move_prefix(session, best_path, legion.current_ap)

static func _path_soft_cost(grid: Dictionary, path: Array[Vector2i]) -> float:
	var cost := 0.0
	for i in range(1, path.size()):
		var tile: Tile = grid.get(path[i])
		if tile != null and tile.has_legion():
			cost += HexPathfinder.SOFT_OCCUPANCY_COST
		else:
			cost += 1.0
	return cost

## Empty walkable tiles to stand on: shoot hexes for range>1, else adjacent to enemy.
static func _stand_goals(
	session: MatchSessionScript,
	legion: Legion,
	enemy: Legion
) -> Array[Vector2i]:
	var goals: Array[Vector2i] = []
	var shoot_range := _legion_shoot_range(legion)
	if shoot_range > 1:
		for coords in session.grid.keys():
			var tile: Tile = session.grid[coords]
			if tile == null or not tile.walkable:
				continue
			if tile.has_legion() and coords != legion.tile_coords:
				continue
			var dist := HexPathfinder.hex_distance(coords, enemy.tile_coords)
			if dist >= 1 and dist <= shoot_range:
				goals.append(coords)
		return goals

	for adj in Utils.get_surrounding_coords(enemy.tile_coords):
		var tile: Tile = session.grid.get(adj)
		if tile == null or not tile.walkable:
			continue
		if tile.has_legion() and adj != legion.tile_coords:
			continue
		goals.append(adj)
	return goals

static func _legion_shoot_range(legion: Legion) -> int:
	if legion == null:
		return 0
	if "ranged_attack" not in ActionDefs.legion_action_ids(legion):
		return 0
	var best := 0
	for u in legion.units:
		if u and u.attack_range > best and u.ranged_attack > 0:
			best = u.attack_range
	return best

## Walk the soft path only onto empty tiles, up to `max_steps` AP.
static func _legal_move_prefix(
	session: MatchSessionScript,
	path: Array[Vector2i],
	max_steps: int
) -> Array[Vector2i]:
	if path.size() < 2 or max_steps < 1:
		return []
	var out: Array[Vector2i] = [path[0]]
	var steps := 0
	for i in range(1, path.size()):
		if steps >= max_steps:
			break
		var step: Vector2i = path[i]
		var tile: Tile = session.grid.get(step)
		if tile == null or not tile.walkable:
			break
		# Effectively blocked: cannot enter occupied tiles (swap is a separate action).
		if tile.has_legion():
			break
		# Must stay adjacent to previous (path should already be).
		if HexPathfinder.hex_distance(out[out.size() - 1], step) != 1:
			break
		out.append(step)
		steps += 1
	if out.size() < 2:
		return []
	return out
