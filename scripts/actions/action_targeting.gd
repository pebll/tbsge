class_name ActionTargeting
extends RefCounted

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")
const Visibility = preload("res://scripts/terrain/visibility.gd")

static func available_actions(state: BattleStateScript, legion: Legion) -> Array[ActionDefinitionScript]:
	var out: Array[ActionDefinitionScript] = []
	for action in listed_actions(legion):
		if can_use(state, legion, action):
			out.append(action)
	return out

## All actions on the bar for this legion (usable + disabled).
static func listed_actions(legion: Legion) -> Array[ActionDefinitionScript]:
	var out: Array[ActionDefinitionScript] = []
	if legion == null:
		return out
	for action_id in ActionDefs.legion_action_ids(legion):
		var def: ActionDefinitionScript = ActionDefs.get_def(action_id)
		if def:
			out.append(def)
	return out

static func disable_reason(
	state: BattleStateScript,
	legion: Legion,
	action: ActionDefinitionScript,
	inspect_only: bool = false
) -> String:
	if legion == null or action == null:
		return "Unavailable"
	if not inspect_only and (state == null or not state.can_act_legion(legion)):
		return "Cannot act now"
	if inspect_only and state != null and not state.turn_manager.is_legion_active(legion):
		return "Enemy unit"
	var cd_left := legion.get_cooldown_remaining(action.id)
	if cd_left > 0:
		return "Ready in %d turn%s" % [cd_left, "s" if cd_left != 1 else ""]
	if not legion.can_afford(action.ap_cost):
		return "Not enough AP (%d needed)" % action.ap_cost
	if action.id == "ranged_attack" and not _legion_has_ranged(legion):
		return "This unit cannot shoot"
	if get_targets(state, legion, action).is_empty():
		match action.id:
			"self_heal":
				return "Already at full health"
			"heal_ally":
				return "No wounded ally in range"
			"move":
				return "No valid move"
			"melee_attack":
				return "No adjacent enemy"
			"ranged_attack":
				return "No enemy in range"
			"teleport":
				return "No empty tile in range"
			_:
				return "No valid target"
	return ""

static func can_use(state: BattleStateScript, legion: Legion, action: ActionDefinitionScript) -> bool:
	if legion == null or action == null:
		return false
	if not state.can_act_legion(legion):
		return false
	if not legion.is_action_ready(action.id):
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
	var raw := _raw_targets(state, legion, action)
	if not state.fog_of_war or raw.is_empty():
		return raw
	# Fog of war: enemies the team can't see can't be targeted.
	var seen: Dictionary = {}
	var computed := false
	var out: Array[Vector2i] = []
	for c in raw:
		var t: Tile = state.tile_at(c)
		if t != null and t.has_legion() and t.legion.team_id != legion.team_id:
			if not computed:
				seen = Visibility.visible_set(state.grid, legion.team_id)
				computed = true
			if not seen.has(c):
				continue
		out.append(c)
	return out

static func _raw_targets(
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
			return _with_los(state, from_coords, _coords_from_tiles(
				Utils.get_ranged_attackable_tiles(from_tile, state.grid, _legion_attack_range(legion))
			))
		ActionDefinitionScript.TargetingKind.ALLY_IN_RANGE:
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			return _with_los(state, from_coords, _coords_from_tiles(Utils.get_healable_ally_tiles(from_tile, state.grid, rng)))
		ActionDefinitionScript.TargetingKind.EMPTY_IN_RANGE:
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			return _coords_from_tiles(Utils.get_empty_tiles_in_range(from_tile, state.grid, rng))
		ActionDefinitionScript.TargetingKind.STATUS_ALLY, ActionDefinitionScript.TargetingKind.STATUS_ENEMY:
			var rng := ActionParams.resolve_int(legion, action, "target_range", action.target_range)
			var want_ally := action.targeting == ActionDefinitionScript.TargetingKind.STATUS_ALLY
			return _with_los(state, from_coords, _status_targets(state, legion, rng, want_ally))
	return []

## Ranged actions need line of sight (mountains block; adjacent hexes always see).
static func _with_los(state: BattleStateScript, from_coords: Vector2i, targets: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in targets:
		if TerrainRules.has_los(state.grid, from_coords, c):
			out.append(c)
	return out

## Legions within range (allies include this legion; distance 0) for status actions.
static func _status_targets(state: BattleStateScript, legion: Legion, rng: int, want_ally: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coords in state.grid.keys():
		var t: Tile = state.grid[coords]
		if t == null or not t.has_legion() or t.legion.units.is_empty():
			continue
		if (t.legion.team_id == legion.team_id) != want_ally:
			continue
		if HexPathfinder.hex_distance(legion.tile_coords, t.coords) <= rng:
			out.append(t.coords)
	return out

## Adjacent tiles this legion can pay to step onto (terrain cost), empty or holding an
## ally that can pay to step back (swap).
static func _move_targets(state: BattleStateScript, from_tile: Tile, legion: Legion) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in Utils.get_surrounding_coords(from_tile.coords):
		var t: Tile = state.tile_at(c)
		var cost := TerrainRules.enter_cost(legion, t)
		if cost < 0 or not legion.can_afford(cost):
			continue
		if t.has_legion():
			if t.legion.team_id != legion.team_id:
				continue
			var back := TerrainRules.enter_cost(t.legion, from_tile)
			if back < 0 or not t.legion.can_afford(back):
				continue
		out.append(c)
	return out

static func _coords_from_tiles(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in tiles:
		if t is Tile:
			out.append(t.coords)
	return out

static func _legion_needs_heal(legion: Legion) -> bool:
	for unit in legion.units:
		if unit != null and unit.current_health < unit.max_health:
			return true
	return false

static func _legion_has_ranged(legion: Legion) -> bool:
	return legion != null and legion.has_ranged()

static func _legion_attack_range(legion: Legion) -> int:
	return legion.max_attack_range() if legion != null else 0

static func is_swap_target(state: BattleStateScript, from_coords: Vector2i, to_coords: Vector2i) -> bool:
	var to_tile: Tile = state.tile_at(to_coords)
	if to_tile == null or not to_tile.has_legion():
		return false
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null or not from_tile.has_legion():
		return false
	var legion_a: Legion = from_tile.legion
	var legion_b: Legion = to_tile.legion
	return legion_a.team_id == legion_b.team_id and legion_b.can_afford(maxi(1, TerrainRules.enter_cost(legion_b, from_tile)))
