class_name ActionResolver
extends RefCounted

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")

static func resolve(state: BattleStateScript, cmd: Dictionary) -> Dictionary:
	var action_id: String = String(cmd.get("action_id", ""))
	var action: ActionDefinitionScript = ActionDefs.get_def(action_id)
	if action == null:
		return _fail("Unknown action: %s" % action_id)

	var from_coords: Vector2i = cmd.get("from", Vector2i.ZERO)
	var to_coords: Vector2i = cmd.get("to", Vector2i.ZERO)
	var from_tile: Tile = state.tile_at(from_coords)
	if from_tile == null or not from_tile.has_legion():
		return _fail("No legion at source tile")

	var legion: Legion = from_tile.legion
	if not ActionTargeting.can_use(state, legion, action):
		return _fail("Legion cannot use %s" % action_id)

	var targets := ActionTargeting.get_targets(state, legion, action)
	if to_coords not in targets:
		return _fail("Invalid target for %s" % action_id)

	match action.targeting:
		ActionDefinitionScript.TargetingKind.SELF:
			return _execute_self_heal(state, legion, action, from_coords)
		ActionDefinitionScript.TargetingKind.ADJACENT_MOVE:
			if ActionTargeting.is_swap_target(state, from_coords, to_coords):
				return _execute_swap(state, from_coords, to_coords, action)
			return _execute_move(state, from_coords, to_coords, action)
		ActionDefinitionScript.TargetingKind.ADJACENT_ENEMY:
			return _execute_melee_attack(state, from_coords, to_coords, action, cmd)
		ActionDefinitionScript.TargetingKind.ENEMY_IN_RANGE:
			return _execute_ranged_attack(state, from_coords, to_coords, action, cmd)

	return _fail("Unhandled action targeting")

static func _execute_move(
	state: BattleStateScript,
	from_coords: Vector2i,
	to_coords: Vector2i,
	action: ActionDefinitionScript
) -> Dictionary:
	var from_tile: Tile = state.tile_at(from_coords)
	var to_tile: Tile = state.tile_at(to_coords)
	if to_tile.has_legion():
		return _fail("Target tile occupied")

	var legion: Legion = from_tile.legion
	from_tile.legion = null
	to_tile.legion = legion
	legion.tile_coords = to_coords
	legion.spend_ap(action.ap_cost)
	_apply_terminal(state, legion, action, from_coords)
	# Moving onto a tile must not inherit a wait left by a destroyed previous occupant.
	state.turn_manager.clear_wait(to_coords)
	return _ok(["legion_moved"], {
		"action_id": action.id,
		"from": from_coords,
		"to": to_coords,
		"legion": legion,
	})

static func _execute_swap(
	state: BattleStateScript,
	from_coords: Vector2i,
	to_coords: Vector2i,
	action: ActionDefinitionScript
) -> Dictionary:
	var from_tile: Tile = state.tile_at(from_coords)
	var to_tile: Tile = state.tile_at(to_coords)
	var legion_a: Legion = from_tile.legion
	var legion_b: Legion = to_tile.legion

	from_tile.legion = legion_b
	to_tile.legion = legion_a
	legion_a.tile_coords = to_coords
	legion_b.tile_coords = from_coords
	legion_a.spend_ap(action.ap_cost)
	legion_b.spend_ap(action.ap_cost)
	_apply_terminal(state, legion_a, action, from_coords)
	return _ok(["legions_swapped"], {
		"action_id": action.id,
		"from": from_coords,
		"to": to_coords,
	})

static func _execute_melee_attack(
	state: BattleStateScript,
	from_coords: Vector2i,
	to_coords: Vector2i,
	action: ActionDefinitionScript,
	cmd: Dictionary
) -> Dictionary:
	var attacker: Legion = state.tile_at(from_coords).legion
	var defender: Legion = state.tile_at(to_coords).legion
	if defender == null:
		return _fail("No defender")

	var rng_seed: int = int(cmd.get("rng_seed", randi()))
	attacker.spend_ap(action.ap_cost)
	_apply_terminal(state, attacker, action, from_coords)
	var result: Dictionary = CombatResolver.resolve_combat(
		attacker,
		defender,
		rng_seed,
		{"mode": CombatResolver.MODE_MELEE, "distance": 1}
	)
	_cleanup_empty_legion(state, from_coords)
	_cleanup_empty_legion(state, to_coords)
	return _ok(["combat_resolved"], {
		"action_id": action.id,
		"from": from_coords,
		"to": to_coords,
		"combat": result,
	})

static func _execute_ranged_attack(
	state: BattleStateScript,
	from_coords: Vector2i,
	to_coords: Vector2i,
	action: ActionDefinitionScript,
	cmd: Dictionary
) -> Dictionary:
	var attacker: Legion = state.tile_at(from_coords).legion
	var defender: Legion = state.tile_at(to_coords).legion
	if defender == null:
		return _fail("No defender")

	var distance := HexPathfinder.hex_distance(from_coords, to_coords)
	var rng_seed: int = int(cmd.get("rng_seed", randi()))
	attacker.spend_ap(action.ap_cost)
	_apply_terminal(state, attacker, action, from_coords)
	var result: Dictionary = CombatResolver.resolve_combat(
		attacker,
		defender,
		rng_seed,
		{"mode": CombatResolver.MODE_RANGED, "distance": distance}
	)
	_cleanup_empty_legion(state, from_coords)
	_cleanup_empty_legion(state, to_coords)
	return _ok(["combat_resolved"], {
		"action_id": action.id,
		"from": from_coords,
		"to": to_coords,
		"combat": result,
	})

static func _execute_self_heal(
	state: BattleStateScript,
	legion: Legion,
	action: ActionDefinitionScript,
	coords: Vector2i
) -> Dictionary:
	var healed := 0
	var unit_heals: Array = []
	for unit in legion.units:
		if unit == null:
			continue
		var before := int(unit.current_health)
		unit.current_health = mini(before + action.heal_amount, int(unit.max_health))
		var after := int(unit.current_health)
		if after > before:
			var gained := after - before
			healed += gained
			unit_heals.append({
				"unit": unit,
				"hp_before": before,
				"hp_after": after,
				"hp_gained": gained,
			})
	legion.spend_ap(action.ap_cost)
	_apply_terminal(state, legion, action, coords)
	return _ok(["legion_healed"], {
		"action_id": action.id,
		"coords": coords,
		"healed_total": healed,
		"unit_heals": unit_heals,
		"legion": legion,
	})

static func _apply_terminal(
	state: BattleStateScript,
	legion: Legion,
	action: ActionDefinitionScript,
	coords: Vector2i
) -> void:
	if not action.terminal:
		return
	legion.spend_all_ap()
	state.finish_legion_turn(coords)

static func _cleanup_empty_legion(state: BattleStateScript, coords: Vector2i) -> void:
	var tile: Tile = state.tile_at(coords)
	if tile == null:
		return
	if tile.legion and tile.legion.units.is_empty():
		tile.legion = null
		# Don't leave a wait stain on a vacated tile — another ally may move in.
		state.turn_manager.clear_wait(coords)

static func _ok(events: Array, payload: Dictionary = {}) -> Dictionary:
	return {"ok": true, "events": events, "payload": payload}

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "events": [], "payload": {}}
