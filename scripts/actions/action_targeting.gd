class_name ActionTargeting
extends RefCounted

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

static func available_actions(state: BattleStateScript, legion: Legion) -> Array[ActionDefinitionScript]:
	var out: Array[ActionDefinitionScript] = []
	for action_id in ActionDefs.legion_action_ids(legion):
		var def: ActionDefinitionScript = ActionDefs.get_def(action_id)
		if def and can_use(state, legion, def):
			out.append(def)
	return out

static func can_use(state: BattleStateScript, legion: Legion, action: ActionDefinitionScript) -> bool:
	if legion == null or action == null:
		return false
	if not state.can_act_legion(legion):
		return false
	if not legion.can_afford(action.ap_cost):
		return false
	if action.id == "ranged_attack" and not _legion_has_ranged(legion):
		return false
	return not get_targets(state, legion, action).is_empty()

static func get_targets(
	state: BattleStateScript,
	legion: Legion,
	action: ActionDefinitionScript
) -> Array[Vector2i]:
	if legion == null or action == null:
		return []
	var from_coords := legion.tile_coords
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null or from_tile.legion != legion:
		return []

	match action.targeting:
		ActionDefinitionScript.TargetingKind.SELF:
			if not _legion_needs_heal(legion):
				return []
			return [from_coords]
		ActionDefinitionScript.TargetingKind.ADJACENT_MOVE:
			return _move_targets(state, from_tile, legion)
		ActionDefinitionScript.TargetingKind.ADJACENT_ENEMY:
			return _coords_from_tiles(Utils.get_attackable_tiles(from_tile, state.grid))
		ActionDefinitionScript.TargetingKind.ENEMY_IN_RANGE:
			return _coords_from_tiles(
				Utils.get_ranged_attackable_tiles(from_tile, state.grid, _legion_attack_range(legion))
			)
		ActionDefinitionScript.TargetingKind.ALLY_IN_RANGE:
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			return _coords_from_tiles(Utils.get_healable_ally_tiles(from_tile, state.grid, rng))
	return []

static func _move_targets(state: BattleStateScript, from_tile: Tile, legion: Legion) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in Utils.get_movable_tiles(from_tile, state.grid):
		out.append(t.coords)
	for t in Utils.get_swappable_tiles(from_tile, state.grid):
		if t.legion and t.legion.can_afford(1):
			if t.coords not in out:
				out.append(t.coords)
	return out

static func _coords_from_tiles(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in tiles:
		if t is Tile:
			out.append(t.coords)
	return out

static func _legion_needs_heal(legion: Legion) -> bool:
	for unit in legion.units:
		if unit != null and int(unit.current_health) < int(unit.max_health):
			return true
	return false

static func _legion_has_ranged(legion: Legion) -> bool:
	if legion == null or legion.units.is_empty():
		return false
	var u: Unit = legion.units[0]
	return u != null and u.has_ranged()

static func _legion_attack_range(legion: Legion) -> int:
	if legion == null or legion.units.is_empty():
		return 0
	var u: Unit = legion.units[0]
	return u.attack_range if u else 0

static func is_swap_target(state: BattleStateScript, from_coords: Vector2i, to_coords: Vector2i) -> bool:
	var to_tile: Tile = state.tile_at(to_coords)
	if to_tile == null or not to_tile.has_legion():
		return false
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null or not from_tile.has_legion():
		return false
	var legion_a: Legion = from_tile.legion
	var legion_b: Legion = to_tile.legion
	return legion_a.team_id == legion_b.team_id and legion_b.can_afford(1)
