class_name AiCandidateGen
extends RefCounted

## Enumerate legal actions + move-then-strike plans (first command is the move).

const AiCandidateScript = preload("res://scripts/ai/utility/ai_candidate.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")

const COMBAT_ACTIONS: Array[String] = ["melee_attack", "ranged_attack"]
const HEAL_ACTIONS: Array[String] = ["self_heal", "heal_ally"]
const RELOCATE_ACTIONS: Array[String] = ["teleport"]

static func generate(session, legion: Legion, ctx: AiContext) -> Array:
	var out: Array = []
	if legion == null or not session.can_act_legion(legion):
		out.append(_pass(legion, "cannot act"))
		return out

	_append_from_tile(session, legion, legion.tile_coords, [], out)

	var reach: Dictionary = ctx.reach
	var cost: Dictionary = reach.get("cost", {})
	var parents: Dictionary = reach.get("parents", {})
	for dest in reach.get("reachable", []):
		var dest_coords: Vector2i = dest
		var step_cost := int(cost.get(dest_coords, 999))
		if step_cost <= 0 or step_cost > legion.current_ap:
			continue
		# Prefer empty destinations for plan standing (swaps are ok as pure moves).
		var tile: Tile = session.grid.get(dest_coords)
		if tile == null or not tile.walkable:
			continue
		var path := MoveReachability.reconstruct_path(
			legion.tile_coords,
			dest_coords,
			parents,
			_preferred_first_step(legion.tile_coords, dest_coords, parents)
		)
		if path.size() < 2:
			continue
		# Pure move candidate.
		var move_cand: AiCandidate = AiCandidateScript.new()
		move_cand.action_id = "move"
		move_cand.from = legion.tile_coords
		move_cand.to = path[1]
		move_cand.path = path
		move_cand.reason = "utility move -> %s" % dest_coords
		out.append(move_cand)

		var ap_left := legion.current_ap - step_cost
		if ap_left <= 0:
			continue
		if tile.has_legion() and tile.legion != legion:
			continue
		_append_combat_plans_from(session, legion, dest_coords, path, out)

	out.append(_pass(legion, "utility pass"))
	return out

static func _append_from_tile(
	session,
	legion: Legion,
	at_coords: Vector2i,
	move_path: Array[Vector2i],
	out: Array
) -> void:
	var action_ids: Array = ActionDefs.legion_action_ids(legion)
	for action_id in COMBAT_ACTIONS + HEAL_ACTIONS + RELOCATE_ACTIONS:
		if String(action_id) not in action_ids:
			continue
		var targets: Array = _targets_from(session, legion, at_coords, String(action_id))
		for to_coords in targets:
			var cand: AiCandidate = AiCandidateScript.new()
			if move_path.size() >= 2:
				cand.action_id = "move"
				cand.from = move_path[0]
				cand.to = move_path[1]
				cand.path = move_path
				cand.followup_action_id = String(action_id)
				cand.followup_to = to_coords
				cand.reason = "plan move->%s then %s" % [action_id, to_coords]
			else:
				cand.action_id = String(action_id)
				cand.from = at_coords
				cand.to = to_coords
				cand.reason = "utility %s -> %s" % [action_id, to_coords]
			out.append(cand)

static func _append_combat_plans_from(
	session,
	legion: Legion,
	at_coords: Vector2i,
	move_path: Array[Vector2i],
	out: Array
) -> void:
	_append_from_tile(session, legion, at_coords, move_path, out)

static func _targets_from(session, legion: Legion, at_coords: Vector2i, action_id: String) -> Array:
	var old := legion.tile_coords
	if at_coords == old:
		return session.get_action_targets(legion, action_id)

	var tile_old: Tile = session.grid.get(old)
	var tile_new: Tile = session.grid.get(at_coords)
	if tile_new == null:
		return []
	var prev_new = tile_new.legion
	if prev_new != null and prev_new != legion:
		return []
	legion.tile_coords = at_coords
	if tile_old and tile_old.legion == legion:
		tile_old.legion = null
	tile_new.legion = legion
	var targets: Array = session.get_action_targets(legion, action_id)
	legion.tile_coords = old
	if tile_old:
		tile_old.legion = legion
	tile_new.legion = prev_new
	return targets

static func _preferred_first_step(
	start: Vector2i, dest: Vector2i, parents: Dictionary
) -> Vector2i:
	var steps: Array[Vector2i] = MoveReachability.first_steps_to(start, dest, parents)
	if steps.is_empty():
		return start
	return steps[0]

static func _pass(legion: Legion, reason: String) -> AiCandidate:
	var cand: AiCandidate = AiCandidateScript.new()
	cand.action_id = "pass"
	cand.from = legion.tile_coords if legion else Vector2i.ZERO
	cand.to = cand.from
	cand.reason = reason
	return cand
