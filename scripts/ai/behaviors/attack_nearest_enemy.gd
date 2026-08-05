class_name AttackNearestEnemyBehavior
extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const Utils = preload("res://scripts/core/utils.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")
const AiActionScorer = preload("res://scripts/ai/ai_action_scorer.gd")
const ActionParams = preload("res://scripts/actions/action_params.gd")

static var debug_enabled: bool = false

## Heal only when the stack (or a unit) is this hurt — or when safely far from fights.
const HEAL_CRITICAL_RATIO := 0.45
const HEAL_CRITICAL_UNIT_RATIO := 0.35
const HEAL_SAFE_ENEMY_DISTANCE := 3
const HEAL_MIN_SCORE_CRITICAL := 1.0
const HEAL_MIN_SCORE_SAFE := 4.0

static func decide(session: MatchSessionScript, legion: Legion) -> Dictionary:
	var cmd := _decide_internal(session, legion)
	if debug_enabled:
		_log_decision(legion, cmd)
	return cmd

static func sort_actionable_by_enemy_distance(
	session: MatchSessionScript,
	actionable: Array[Vector2i]
) -> Array[Vector2i]:
	## Closest engage path first (soft pathfinding), then fighters, then coord tie-break.
	if actionable.is_empty():
		return actionable
	var enemies := _enemy_legions(session, session.turn_manager.active_team_id)
	if enemies.is_empty():
		return actionable.duplicate()

	var scored: Array[Dictionary] = []
	for coords in actionable:
		scored.append({
			"coords": coords,
			"dist": _min_path_engage_cost(session, coords, enemies),
			"can_fight": _can_fight_now(session, coords),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = float(a["dist"])
		var db: float = float(b["dist"])
		if not is_equal_approx(da, db):
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
				"%s(d=%.1f%s)"
				% [row["coords"], float(row["dist"]), ",fight" if bool(row["can_fight"]) else ""]
			)
		print("[AI] Legion order (path closest first): %s" % ", ".join(parts))
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

## Soft path cost to the nearest stand/engage hex vs any enemy. 0 if already fighting.
static func _min_path_engage_cost(
	session: MatchSessionScript,
	coords: Vector2i,
	enemies: Array[Legion]
) -> float:
	if _can_fight_now(session, coords):
		return 0.0
	var legion: Legion = session.get_legion_at(coords)
	if legion == null:
		return INF
	var best := INF
	for enemy in enemies:
		if enemy == null or enemy.units.is_empty():
			continue
		var goals := _stand_goals(session, legion, enemy)
		for goal in goals:
			if goal == coords:
				return 0.0
			var path := HexPathfinder.find_path(session.grid, coords, goal, {}, true)
			if path.size() < 2:
				continue
			best = minf(best, _path_soft_cost(session.grid, path))
	return best

## While threatening: take a 1-step flank that still attacks the same enemy, to unblock allies.
static func _best_attack_preserving_reposition(
	session: MatchSessionScript,
	legion: Legion,
	enemies: Array[Legion]
) -> Dictionary:
	if legion == null or legion.current_ap < 2:
		return {}
	if not legion.can_afford(1):
		return {}
	if not _team_has_other_ally(session, legion):
		return {}
	var threatened := _threatened_enemy_coords(session, legion)
	if threatened.is_empty():
		return {}

	var from := legion.tile_coords
	var movable := session.get_movable_coords(from)
	var best_to := Vector2i.ZERO
	var best_score := -INF
	var found := false
	for to_coords in movable:
		# Keep 1 AP for the follow-up attack.
		if HexPathfinder.hex_distance(from, to_coords) != 1:
			continue
		var tile: Tile = session.grid.get(to_coords)
		if tile == null or not tile.walkable or tile.has_legion():
			continue
		if not _still_threatens_from(session, legion, to_coords, threatened):
			continue
		var score := float(_empty_neighbor_count(session, to_coords))
		score += _ally_clearance_bonus(session, legion, to_coords)
		if _reposition_helps_allies(session, legion, enemies, from, to_coords):
			score += 4.0
		if score > best_score:
			best_score = score
			best_to = to_coords
			found = true
	if not found:
		return {}
	return {
		"type": "use_action",
		"action_id": "move",
		"from": from,
		"to": best_to,
		"path": [from, best_to],
		"reason": "flank-reposition to free path @ %s" % best_to,
	}

static func _team_has_other_ally(session: MatchSessionScript, legion: Legion) -> bool:
	for other in session.legions:
		if other != null and other != legion and other.team_id == legion.team_id and not other.units.is_empty():
			return true
	return false

static func _threatened_enemy_coords(session: MatchSessionScript, legion: Legion) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for action_id in ["melee_attack", "ranged_attack"]:
		for to_coords in session.get_action_targets(legion, action_id):
			if to_coords not in out:
				out.append(to_coords)
	return out

static func _still_threatens_from(
	session: MatchSessionScript,
	legion: Legion,
	from_coords: Vector2i,
	threatened: Array[Vector2i]
) -> bool:
	var old := legion.tile_coords
	var tile_old: Tile = session.grid.get(old)
	var tile_new: Tile = session.grid.get(from_coords)
	if tile_new == null or tile_new.has_legion():
		return false
	var prev_new = tile_new.legion
	legion.tile_coords = from_coords
	if tile_old and tile_old.legion == legion:
		tile_old.legion = null
	tile_new.legion = legion
	var still := false
	for action_id in ["melee_attack", "ranged_attack"]:
		for to_coords in session.get_action_targets(legion, action_id):
			if to_coords in threatened:
				still = true
				break
		if still:
			break
	legion.tile_coords = old
	if tile_old:
		tile_old.legion = legion
	tile_new.legion = prev_new
	return still

## True when at least one ally is farther from the fight (by path) and our hex sits on a soft path.
static func _reposition_helps_allies(
	session: MatchSessionScript,
	legion: Legion,
	enemies: Array[Legion],
	from_coords: Vector2i,
	_to_coords: Vector2i
) -> bool:
	if enemies.is_empty():
		return false
	var focus: Legion = _pick_focus_enemy(from_coords, enemies)
	for other in session.legions:
		if other == null or other == legion or other.team_id != legion.team_id:
			continue
		if other.units.is_empty():
			continue
		if not session.can_act_legion(other) and other.current_ap <= 0:
			# Still count waiting rear allies that need the lane next turn.
			pass
		var goals := _stand_goals(session, other, focus)
		for goal in goals:
			var path := HexPathfinder.find_path(
				session.grid, other.tile_coords, goal, {}, true
			)
			if path.size() < 2:
				continue
			if from_coords in path:
				return true
	# Also rotate when an ally is bird-adjacent behind us toward the enemy.
	for adj in Utils.get_surrounding_coords(from_coords):
		var tile: Tile = session.grid.get(adj)
		if tile == null or not tile.has_legion():
			continue
		var ally: Legion = tile.legion
		if ally.team_id != legion.team_id or ally == legion:
			continue
		var ally_d := HexPathfinder.hex_distance(ally.tile_coords, focus.tile_coords)
		var my_d := HexPathfinder.hex_distance(from_coords, focus.tile_coords)
		if ally_d > my_d:
			return true
	return false

static func _empty_neighbor_count(session: MatchSessionScript, coords: Vector2i) -> int:
	var n := 0
	for adj in Utils.get_surrounding_coords(coords):
		var tile: Tile = session.grid.get(adj)
		if tile != null and tile.walkable and not tile.has_legion():
			n += 1
	return n

static func _ally_clearance_bonus(
	session: MatchSessionScript,
	legion: Legion,
	coords: Vector2i
) -> float:
	var bonus := 0.0
	for adj in Utils.get_surrounding_coords(coords):
		var tile: Tile = session.grid.get(adj)
		if tile == null or not tile.has_legion():
			continue
		var other: Legion = tile.legion
		if other.team_id == legion.team_id and other != legion:
			bonus -= 1.5
	return bonus

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

	# 1) If already fighting: sidestep around the enemy when possible so allies can flow in,
	#    then strike next activation (needs move + attack AP).
	var reposition := _best_attack_preserving_reposition(session, legion, enemies)
	if not reposition.is_empty():
		return reposition

	# 2) Fight now if possible — never blink/heal away from a free attack.
	var combat := _best_action_of(session, legion, enemies, ["melee_attack", "ranged_attack"])
	if not combat.is_empty():
		return combat

	# 3) Critical heal only (low stack / dying unit) — before walking away from a crisis.
	var critical_heal := _best_justified_heal(session, legion, enemies, true)
	if not critical_heal.is_empty():
		return critical_heal

	# 4) Teleport only as an engage: needs leftover AP to strike after blink.
	if legion.current_ap >= 2:
		var blink := _best_engage_teleport(session, legion, enemies)
		if not blink.is_empty():
			return blink

	# 5) Walk toward focus — prefer closing over bandaging chip damage.
	if legion.can_afford(1):
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
		if walk.size() >= 2:
			return {
				"type": "use_action",
				"action_id": "move",
				"from": walk[0],
				"to": walk[1],
				"path": walk,
				"reason": "path toward focus @ %s (%d steps)" % [focus.tile_coords, walk.size() - 1],
			}

	# 6) Far-from-combat heal (chip OK only when not near the fight).
	var safe_heal := _best_justified_heal(session, legion, enemies, false)
	if not safe_heal.is_empty():
		return safe_heal

	if not legion.can_afford(1):
		return _cmd_pass(legion, "cannot afford move")
	return _cmd_pass(legion, "no step toward enemy")

static func _best_action_of(
	session: MatchSessionScript,
	legion: Legion,
	enemies: Array[Legion],
	action_ids: Array
) -> Dictionary:
	var best_score := -INF
	var best_cmd: Dictionary = {}
	for action_id in action_ids:
		if action_id not in ActionDefs.legion_action_ids(legion):
			continue
		var targets := session.get_action_targets(legion, String(action_id))
		for to_coords in targets:
			var score := AiActionScorer.score_action(session, legion, String(action_id), to_coords)
			if String(action_id) in ["melee_attack", "ranged_attack"]:
				score += _focus_bonus_at(session, to_coords, enemies)
			if score > best_score:
				best_score = score
				best_cmd = {
					"type": "use_action",
					"action_id": String(action_id),
					"from": legion.tile_coords,
					"to": to_coords,
					"score": score,
					"reason": "greedy score %.1f (%s -> %s)" % [score, action_id, to_coords],
				}
	return best_cmd

## Heal only when critical (require_critical) or safely far from enemies.
static func _best_justified_heal(
	session: MatchSessionScript,
	legion: Legion,
	enemies: Array[Legion],
	require_critical: bool
) -> Dictionary:
	var heal := _best_action_of(session, legion, enemies, ["self_heal", "heal_ally"])
	if heal.is_empty():
		return {}
	var action_id := String(heal.get("action_id", ""))
	var to_coords: Vector2i = heal.get("to", legion.tile_coords)
	var target := _heal_target_legion(session, legion, action_id, to_coords)
	if target == null:
		return {}

	var critical := _legion_needs_critical_heal(target)
	var far := _min_enemy_distance(legion.tile_coords, enemies) >= HEAL_SAFE_ENEMY_DISTANCE
	if require_critical:
		if not critical:
			return {}
	else:
		# Safe bandage: far from fights, not a crisis already handled above.
		if not far or critical:
			return {}

	var min_score := HEAL_MIN_SCORE_CRITICAL if require_critical else HEAL_MIN_SCORE_SAFE
	if float(heal.get("score", 0.0)) < min_score:
		return {}
	heal["reason"] = (
		"critical heal %.1f" % float(heal.get("score", 0.0))
		if require_critical
		else "safe heal %.1f (enemy dist >= %d)" % [float(heal.get("score", 0.0)), HEAL_SAFE_ENEMY_DISTANCE]
	)
	return heal

static func _heal_target_legion(
	session: MatchSessionScript,
	caster: Legion,
	action_id: String,
	to_coords: Vector2i
) -> Legion:
	if action_id == "heal_ally":
		return session.get_legion_at(to_coords)
	return caster

static func _legion_needs_critical_heal(legion: Legion) -> bool:
	if legion == null or legion.units.is_empty():
		return false
	var cur := 0.0
	var mx := 0.0
	for u in legion.units:
		if u == null:
			continue
		var u_max := float(u.max_health)
		var u_cur := float(u.current_health)
		cur += u_cur
		mx += u_max
		if u_max > 0.0 and (u_cur / u_max) <= HEAL_CRITICAL_UNIT_RATIO:
			return true
	if mx <= 0.0:
		return false
	return (cur / mx) <= HEAL_CRITICAL_RATIO

static func _best_engage_teleport(
	session: MatchSessionScript,
	legion: Legion,
	enemies: Array[Legion]
) -> Dictionary:
	if "teleport" not in ActionDefs.legion_action_ids(legion):
		return {}
	var targets := session.get_action_targets(legion, "teleport")
	var best_score := -INF
	var best_to := Vector2i.ZERO
	var found := false
	for to_coords in targets:
		if not _teleport_enables_melee(session, legion, to_coords):
			continue
		var score := AiActionScorer.score_action(session, legion, "teleport", to_coords)
		score += _focus_bonus_at(session, to_coords, enemies)
		# Mild preference for closing on soft targets already baked into scorer.
		if score > best_score:
			best_score = score
			best_to = to_coords
			found = true
	if not found:
		return {}
	return {
		"type": "use_action",
		"action_id": "teleport",
		"from": legion.tile_coords,
		"to": best_to,
		"reason": "engage teleport %.1f -> %s" % [best_score, best_to],
	}

static func _teleport_enables_melee(
	session: MatchSessionScript,
	legion: Legion,
	to_coords: Vector2i
) -> bool:
	var old := legion.tile_coords
	var tile_old: Tile = session.grid.get(old)
	var tile_new: Tile = session.grid.get(to_coords)
	if tile_new == null or tile_new.has_legion():
		return false
	var prev_new = tile_new.legion
	legion.tile_coords = to_coords
	if tile_old and tile_old.legion == legion:
		tile_old.legion = null
	tile_new.legion = legion
	var melee_targets: Array = session.get_action_targets(legion, "melee_attack")
	legion.tile_coords = old
	if tile_old:
		tile_old.legion = legion
	tile_new.legion = prev_new
	return not melee_targets.is_empty()

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
		return 0.0
	# Scale scorer focus (support + weak HP) for greedy combat/teleport pick.
	return AiActionScorer.focus_target_bonus(at) * 2.5

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
			session.grid, from_coords, goal, {}, true
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
