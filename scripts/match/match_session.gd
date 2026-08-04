class_name MatchSession
extends RefCounted

const TurnManagerRes = preload("res://scripts/core/turn_manager.gd")
const ActionResolverScript = preload("res://scripts/actions/action_resolver.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const BattleActionLogScript = preload("res://scripts/battle/battle_action_log.gd")
const BattleActionLogFormatterScript = preload("res://scripts/battle/battle_action_log_formatter.gd")

var grid: Dictionary = {}
var legions: Array[Legion] = []
var turn_manager: TurnManager
var team_ids: Array[String] = []
var action_log: BattleActionLogScript

func _init(p_team_ids: Array[String]) -> void:
	team_ids = p_team_ids.duplicate()
	turn_manager = TurnManagerRes.new(team_ids)
	action_log = BattleActionLogScript.new()

func battle_state() -> BattleStateScript:
	return BattleStateScript.from_session(self)

func can_act_legion(legion: Legion) -> bool:
	return (
		legion != null
		and _is_legion_on_grid(legion)
		and turn_manager.is_legion_active(legion)
		and legion.has_ap()
		and legion.tile_coords not in turn_manager.waited_coords
	)

func get_legion_at(coords: Vector2i) -> Legion:
	return _legion_at(coords)

func typed_legions() -> Array[Legion]:
	var out: Array[Legion] = []
	for legion in legions:
		out.append(legion)
	return out

func get_available_actions(legion: Legion) -> Array[ActionDefinitionScript]:
	return ActionTargetingScript.available_actions(battle_state(), legion)

func get_action_targets(legion: Legion, action_id: String) -> Array[Vector2i]:
	var action: ActionDefinitionScript = ActionDefs.get_def(action_id)
	if action == null:
		return []
	return ActionTargetingScript.get_targets(battle_state(), legion, action)

func get_actionable_coords() -> Array[Vector2i]:
	prune_stale_legions()
	var out: Array[Vector2i] = []
	for legion in legions:
		if legion.units.is_empty():
			continue
		if legion.team_id != turn_manager.active_team_id:
			continue
		if not legion.has_ap():
			continue
		if legion.tile_coords in turn_manager.waited_coords:
			continue
		if not _is_legion_on_grid(legion):
			continue
		out.append(legion.tile_coords)
	return out

func prune_stale_legions() -> void:
	for legion in legions.duplicate():
		if legion.units.is_empty():
			_remove_legion_from_grid(legion)
			legions.erase(legion)
			continue
		if not _is_legion_on_grid(legion):
			legions.erase(legion)

func resolve_use_action(cmd: Dictionary) -> Dictionary:
	var result: Dictionary = ActionResolverScript.resolve(battle_state(), cmd)
	if not result.get("ok", false):
		return _fail(String(result.get("error", "Action failed")))

	var payload: Dictionary = result.get("payload", {})
	_collect_cleanup_coords(payload)
	var ok_result := _ok(result.get("events", []).duplicate(), payload)
	_append_action_log(BattleActionLogFormatterScript.from_use_action(self, ok_result))
	return ok_result

func apply_end_turn() -> Dictionary:
	var ending_team: String = turn_manager.active_team_id
	var ending_turn: int = turn_manager.turn_index
	var next_team: String = turn_manager.end_team_turn(typed_legions())
	var ok_result := _ok(["turn_changed"], {
		"active_team": next_team,
		"ending_team": ending_team,
		"ending_turn": ending_turn,
	})
	_append_action_log(BattleActionLogFormatterScript.from_end_turn(
		self, ending_team, ending_turn, next_team
	))
	return ok_result

func get_movable_coords(from_coords: Vector2i) -> Array[Vector2i]:
	return get_action_targets(_legion_at(from_coords), "move")

func get_attackable_coords(from_coords: Vector2i) -> Array[Vector2i]:
	return get_action_targets(_legion_at(from_coords), "melee_attack")

func apply_pass_legion(coords: Vector2i) -> Dictionary:
	var tile: Tile = _tile_at(coords)
	if tile == null or not tile.has_legion():
		return _fail("No legion at tile")
	var legion: Legion = tile.legion
	if not can_act_legion(legion):
		return _fail("Legion cannot pass")
	turn_manager.wait_legion(coords)
	var ok_result := _ok(["legion_passed"], {"coords": coords})
	_append_action_log(BattleActionLogFormatterScript.from_pass_legion(self, coords))
	return ok_result

func _append_action_log(entry: Dictionary) -> void:
	if action_log == null or entry.is_empty():
		return
	action_log.append(entry)
	EventBus.battle_log_entry_added.emit(entry)

func _collect_cleanup_coords(payload: Dictionary) -> void:
	var cleanup_coords: Array[Vector2i] = []
	if payload.has("from"):
		cleanup_coords.append(payload["from"])
	if payload.has("to"):
		var to_c: Vector2i = payload["to"]
		if to_c not in cleanup_coords:
			cleanup_coords.append(to_c)
	if payload.has("coords"):
		var self_c: Vector2i = payload["coords"]
		if self_c not in cleanup_coords:
			cleanup_coords.append(self_c)
	for coords in cleanup_coords:
		_cleanup_empty_legion(coords)

func _legion_at(coords: Vector2i) -> Legion:
	var tile: Tile = _tile_at(coords)
	return tile.legion if tile and tile.has_legion() else null

func _is_legion_on_grid(legion: Legion) -> bool:
	if legion == null:
		return false
	var tile: Tile = _tile_at(legion.tile_coords)
	return tile != null and tile.legion == legion

func _remove_legion_from_grid(legion: Legion) -> void:
	var tile: Tile = _tile_at(legion.tile_coords)
	if tile and tile.legion == legion:
		tile.legion = null

func _cleanup_empty_legion(coords: Vector2i) -> void:
	var tile: Tile = _tile_at(coords)
	if tile == null:
		return
	if tile.legion != null and tile.legion.units.size() > 0:
		return
	if tile.legion != null:
		legions.erase(tile.legion)
		tile.legion = null
	# Resolver may already have nulled the tile; still drop wait stain + prune empties.
	turn_manager.clear_wait(coords)
	for legion in legions.duplicate():
		if legion.units.is_empty():
			legions.erase(legion)

func _tile_at(coords: Vector2i) -> Tile:
	return grid.get(coords)

func _ok(events: Array, payload: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error": "", "events": events, "payload": payload}

func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "events": [], "payload": {}}
