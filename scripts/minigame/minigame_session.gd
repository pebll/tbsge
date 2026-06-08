class_name MinigameSession
extends RefCounted

const TurnManagerRes = preload("res://scripts/core/turn_manager.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const ActionResolverScript = preload("res://scripts/actions/action_resolver.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const DraftStateScript = preload("res://scripts/minigame/draft_state.gd")
const DraftPlacementScript = preload("res://scripts/minigame/draft_placement.gd")

enum Phase { DRAFT, BATTLE, ENDED }

var config
var phase: Phase = Phase.DRAFT
var grid: Dictionary = {}
var legions: Array[Legion] = []
var turn_manager: TurnManager
var winner: String = ""
var active_draft_team: String = ""
var deploy_slots: Dictionary = {}
var drafts: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(p_config) -> void:
	config = p_config
	grid = MapBuilderScript.build_grid(config.map_radius)
	turn_manager = TurnManagerRes.new(config.team_ids)
	_rng.seed = 1337
	for team_id in config.team_ids:
		drafts[team_id] = DraftStateScript.new(team_id, config.budget)
		deploy_slots[team_id] = _walkable_deploy_slots(
			MinigameRulesScript.deploy_zone_coords(
				config.map_radius,
				team_id,
				config.deploy_slot_count,
				config.team_ids
			)
		)
	if not config.team_ids.is_empty():
		active_draft_team = config.team_ids[0]

func apply(cmd: Dictionary) -> Dictionary:
	var cmd_type: String = String(cmd.get("type", ""))
	match phase:
		Phase.DRAFT:
			return _apply_draft(cmd_type, cmd)
		Phase.BATTLE:
			return _apply_battle(cmd_type, cmd)
		Phase.ENDED:
			return _fail("Match already ended")
	return _fail("Unknown phase")

func get_view_state(for_team: String) -> Dictionary:
	var out := {
		"phase": phase,
		"winner": winner,
		"config": {
			"id": config.id,
			"display_name": config.display_name,
			"map_radius": config.map_radius,
			"budget": config.budget,
			"deploy_slot_count": config.deploy_slot_count,
		},
		"active_draft_team": active_draft_team if phase == Phase.DRAFT else "",
		"active_battle_team": turn_manager.active_team_id if phase == Phase.BATTLE else "",
		"own_team": for_team,
	}
	if phase == Phase.DRAFT:
		out["deploy_slots"] = (deploy_slots.get(for_team, []) as Array).duplicate()
		var own_draft = drafts.get(for_team)
		if own_draft:
			out["draft"] = _serialize_draft(own_draft, true)
		for other_team in config.team_ids:
			if other_team == for_team:
				continue
			var other_draft = drafts.get(other_team)
			if other_draft:
				out["opponent_%s" % other_team] = _serialize_draft(other_draft, false)
	elif phase == Phase.BATTLE or phase == Phase.ENDED:
		out["legions"] = _serialize_legions(for_team)
	return out

func refresh_deploy_slots() -> void:
	for team_id in config.team_ids:
		deploy_slots[team_id] = _walkable_deploy_slots(
			MinigameRulesScript.deploy_zone_coords(
				config.map_radius,
				team_id,
				config.deploy_slot_count,
				config.team_ids
			)
		)

func get_deploy_slots(team_id: String) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	for c in deploy_slots.get(team_id, []):
		slots.append(c)
	return slots

func can_act_legion(legion: Legion) -> bool:
	return legion != null and _is_legion_on_grid(legion) and turn_manager.is_legion_active(legion) and legion.has_ap()

func get_legion_at(coords: Vector2i) -> Legion:
	return _legion_at(coords)

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

func pass_legion_or_force_wait(coords: Vector2i) -> void:
	var result := apply({"type": "pass_legion", "coords": coords})
	if result["ok"]:
		return
	turn_manager.wait_legion(coords)
	if AttackNearestEnemyBehavior.debug_enabled:
		print("[AI] force-wait %s (%s)" % [coords, result.get("error", "?")])

func _is_legion_on_grid(legion: Legion) -> bool:
	if legion == null:
		return false
	var tile: Tile = _tile_at(legion.tile_coords)
	return tile != null and tile.legion == legion

func _remove_legion_from_grid(legion: Legion) -> void:
	var tile: Tile = _tile_at(legion.tile_coords)
	if tile and tile.legion == legion:
		tile.legion = null

func battle_state() -> BattleStateScript:
	return BattleStateScript.from_minigame(self)

func get_available_actions(legion: Legion) -> Array[ActionDefinitionScript]:
	return ActionTargetingScript.available_actions(battle_state(), legion)

func get_action_targets(legion: Legion, action_id: String) -> Array[Vector2i]:
	var action: ActionDefinitionScript = ActionDefs.get_def(action_id)
	if action == null:
		return []
	return ActionTargetingScript.get_targets(battle_state(), legion, action)

func get_movable_coords(from_coords: Vector2i) -> Array[Vector2i]:
	return get_action_targets(_legion_at(from_coords), "move")

func get_attackable_coords(from_coords: Vector2i) -> Array[Vector2i]:
	return get_action_targets(_legion_at(from_coords), "melee_attack")

func get_swappable_coords(from_coords: Vector2i) -> Array[Vector2i]:
	var legion := _legion_at(from_coords)
	if legion == null:
		return []
	var move_targets := get_action_targets(legion, "move")
	var out: Array[Vector2i] = []
	for coords in move_targets:
		if ActionTargetingScript.is_swap_target(battle_state(), from_coords, coords):
			out.append(coords)
	return out

func _legion_at(coords: Vector2i) -> Legion:
	var tile: Tile = _tile_at(coords)
	return tile.legion if tile and tile.has_legion() else null

func _apply_draft(cmd_type: String, cmd: Dictionary) -> Dictionary:
	match cmd_type:
		"draft_set_legion":
			return _draft_set_legion(cmd)
		"draft_clear_slot":
			return _draft_clear_slot(cmd)
		"draft_ready":
			return _draft_ready(cmd)
		_:
			return _fail("Unknown draft command: %s" % cmd_type)

func _apply_battle(cmd_type: String, cmd: Dictionary) -> Dictionary:
	match cmd_type:
		"use_action":
			return _battle_use_action(cmd)
		"move":
			return _battle_use_action({
				"action_id": "move",
				"from": cmd.get("from", Vector2i.ZERO),
				"to": cmd.get("to", Vector2i.ZERO),
			})
		"swap":
			return _battle_use_action({
				"action_id": "move",
				"from": cmd.get("from", Vector2i.ZERO),
				"to": cmd.get("to", Vector2i.ZERO),
			})
		"attack":
			return _battle_use_action({
				"action_id": "melee_attack",
				"from": cmd.get("from", Vector2i.ZERO),
				"to": cmd.get("to", Vector2i.ZERO),
				"rng_seed": cmd.get("rng_seed", _rng.randi()),
			})
		"end_turn":
			return _battle_end_turn()
		"pass_legion":
			return _battle_pass_legion(cmd)
		"surrender":
			return _battle_surrender(cmd)
		_:
			return _fail("Unknown battle command: %s" % cmd_type)

func _draft_set_legion(cmd: Dictionary) -> Dictionary:
	var team_id: String = String(cmd.get("team", ""))
	if team_id != active_draft_team:
		return _fail("Not this team's draft turn")
	var coords: Vector2i = cmd.get("coords", Vector2i.ZERO)
	var unit_type: String = String(cmd.get("unit_type", ""))
	var unit_count: int = int(cmd.get("unit_count", 0))
	var draft = drafts.get(team_id)
	if draft == null:
		return _fail("Unknown team")
	if draft.ready:
		return _fail("Team already ready")

	var slots: Array = deploy_slots.get(team_id, [])
	var err: String = MinigameRulesScript.validate_draft_placement(
		team_id, coords, unit_type, unit_count, draft, slots, config.max_legion_fill, grid
	)
	if not err.is_empty():
		return _fail(err)

	var existing = draft.find_placement(coords)
	var old_cost: int = 0
	if existing:
		old_cost = MinigameRulesScript.legion_cost(existing.unit_type, existing.unit_count)
		existing.unit_type = unit_type
		existing.unit_count = unit_count
	else:
		draft.placements.append(DraftPlacementScript.new(coords, unit_type, unit_count))
	draft.remaining_budget += old_cost
	draft.remaining_budget -= MinigameRulesScript.legion_cost(unit_type, unit_count)
	return _ok(["draft_updated"], {"team": team_id, "coords": coords})

func _draft_clear_slot(cmd: Dictionary) -> Dictionary:
	var team_id: String = String(cmd.get("team", ""))
	if team_id != active_draft_team:
		return _fail("Not this team's draft turn")
	var coords: Vector2i = cmd.get("coords", Vector2i.ZERO)
	var draft = drafts.get(team_id)
	if draft == null:
		return _fail("Unknown team")
	if draft.ready:
		return _fail("Team already ready")
	var existing = draft.find_placement(coords)
	if existing == null:
		return _fail("No legion at slot")
	draft.remaining_budget += MinigameRulesScript.legion_cost(existing.unit_type, existing.unit_count)
	draft.remove_placement(coords)
	return _ok(["draft_updated"], {"team": team_id, "coords": coords})

func _draft_ready(cmd: Dictionary) -> Dictionary:
	var team_id: String = String(cmd.get("team", ""))
	if team_id != active_draft_team:
		return _fail("Not this team's draft turn")
	var draft = drafts.get(team_id)
	if draft == null:
		return _fail("Unknown team")
	if draft.placements.is_empty():
		return _fail("Place at least one legion before ready")
	draft.ready = true
	var events: Array = ["draft_ready"]
	var next_team := _next_draft_team(team_id)
	if next_team.is_empty():
		_begin_battle()
		events.append("battle_started")
	else:
		active_draft_team = next_team
		events.append("draft_turn_changed")
	return _ok(events, {"team": team_id})

func _begin_battle() -> void:
	phase = Phase.BATTLE
	legions.clear()
	for team_id in config.team_ids:
		var draft = drafts.get(team_id)
		if draft == null:
			continue
		for placement in draft.placements:
			var legion := Legion.new(
				placement.unit_type,
				placement.unit_count,
				placement.coords,
				team_id
			)
			legion.refresh_ap()
			legions.append(legion)
			var tile: Tile = grid.get(placement.coords)
			if tile:
				tile.legion = legion
	if not config.team_ids.is_empty():
		turn_manager.start_match(config.team_ids[0])

func _battle_use_action(cmd: Dictionary) -> Dictionary:
	var result: Dictionary = ActionResolverScript.resolve(battle_state(), cmd)
	if not result.get("ok", false):
		return _fail(String(result.get("error", "Action failed")))

	var payload: Dictionary = result.get("payload", {})
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

	var events: Array = result.get("events", []).duplicate()
	events.append_array(_check_victory_events())
	return _ok(events, payload)

func _battle_end_turn() -> Dictionary:
	if phase != Phase.BATTLE:
		return _fail("Not in battle")
	var next_team: String = turn_manager.end_team_turn(_typed_legions())
	return _ok(["turn_changed"], {"active_team": next_team})

func _battle_pass_legion(cmd: Dictionary) -> Dictionary:
	var coords: Vector2i = cmd.get("coords", Vector2i.ZERO)
	var tile: Tile = _tile_at(coords)
	if tile == null or not tile.has_legion():
		return _fail("No legion at tile")
	var legion: Legion = tile.legion
	if not can_act_legion(legion):
		return _fail("Legion cannot pass")
	turn_manager.wait_legion(coords)
	return _ok(["legion_passed"], {"coords": coords})

func _walkable_deploy_slots(zone_coords: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coords in zone_coords:
		if MinigameRulesScript.is_walkable_deploy_slot(grid, coords):
			out.append(coords)
	return out

func _typed_legions() -> Array[Legion]:
	var out: Array[Legion] = []
	for legion in legions:
		out.append(legion)
	return out

func _battle_surrender(cmd: Dictionary) -> Dictionary:
	var team_id: String = String(cmd.get("team", ""))
	if team_id.is_empty() or team_id not in config.team_ids:
		return _fail("Unknown team")
	winner = _opponent_of(team_id)
	phase = Phase.ENDED
	return _ok(["match_ended"], {"winner": winner, "reason": "surrender"})

func _check_victory_events() -> Array:
	if phase != Phase.BATTLE:
		return []
	var alive: Array[String] = []
	for team_id in config.team_ids:
		if MinigameRulesScript.team_has_army(legions, team_id):
			alive.append(team_id)
	if alive.size() <= 1:
		phase = Phase.ENDED
		winner = alive[0] if alive.size() == 1 else ""
		return ["match_ended"]
	return []

func _cleanup_empty_legion(coords: Vector2i) -> void:
	var tile: Tile = _tile_at(coords)
	if tile == null or tile.legion == null:
		return
	if tile.legion.units.size() > 0:
		return
	var legion: Legion = tile.legion
	legions.erase(legion)
	tile.legion = null

func _next_draft_team(current_team: String) -> String:
	var idx: int = config.team_ids.find(current_team)
	if idx < 0:
		return ""
	for i in range(1, config.team_ids.size()):
		var team_id: String = config.team_ids[(idx + i) % config.team_ids.size()]
		var draft = drafts.get(team_id)
		if draft and not draft.ready:
			return team_id
	return ""

func _opponent_of(team_id: String) -> String:
	for other in config.team_ids:
		if other != team_id:
			return other
	return ""

func _tile_at(coords: Vector2i) -> Tile:
	return grid.get(coords)

func _coords_from_tiles(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tile in tiles:
		out.append(tile.coords)
	return out

func _serialize_draft(draft, include_details: bool) -> Dictionary:
	var data := {
		"team_id": draft.team_id,
		"budget_total": draft.budget_total,
		"remaining_budget": draft.remaining_budget,
		"spent_budget": draft.spent_budget(),
		"ready": draft.ready,
		"slots_used": draft.slots_used(),
	}
	if include_details:
		var placements: Array = []
		for p in draft.placements:
			placements.append({
				"coords": p.coords,
				"unit_type": p.unit_type,
				"unit_count": p.unit_count,
				"cost": MinigameRulesScript.legion_cost(p.unit_type, p.unit_count),
				"fill": MinigameRulesScript.legion_fill(p.unit_type, p.unit_count),
			})
		data["placements"] = placements
	return data

func _serialize_legions(for_team: String) -> Array:
	var out: Array = []
	for legion in legions:
		if legion.units.is_empty():
			continue
		out.append({
			"team_id": legion.team_id,
			"unit_type": legion.unit_type,
			"unit_count": legion.units.size(),
			"coords": legion.tile_coords,
			"current_ap": legion.current_ap,
			"hidden": false,
		})
	return out

func _ok(events: Array, payload: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error": "", "events": events, "payload": payload}

func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "events": [], "payload": {}}
