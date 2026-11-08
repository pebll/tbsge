extends "res://scripts/match/match_session.gd"

## Throwaway copy of a battle for the turn planner: same grid, legions (HP, shields, AP,
## cooldowns, waited) and active team, nothing shared with the live match. No action log,
## no EventBus, no draft state. Supports the commands the AI issues (use_action,
## pass_legion) plus the victory check, so brains and AiBrainCommand run on it unchanged.

const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

enum Phase { DRAFT, BATTLE, ENDED }

var phase: int = Phase.BATTLE
var winner: String = ""

static func clone_from(src) -> Object:
	var sim = load("res://scripts/ai/planning/turn_sim_session.gd").new(src.team_ids)
	sim.emit_global_events = false
	sim.action_log = null
	sim.turn_manager.active_team_id = src.turn_manager.active_team_id
	sim.turn_manager.turn_index = src.turn_manager.turn_index
	sim.set_match_seed(int(src.match_seed))
	for coords in src.grid.keys():
		var t: Tile = src.grid[coords]
		var copy := Tile.new(t.cube_q, t.cube_r, t.terrain_type)
		copy.walkable = t.walkable
		sim.grid[coords] = copy
	for L in src.legions:
		if L == null or L.units.is_empty():
			continue
		var c := clone_legion_full(L)
		sim.legions.append(c)
		var tile: Tile = sim.grid.get(c.tile_coords)
		if tile != null and src.grid.get(c.tile_coords) != null and src.grid[c.tile_coords].legion == L:
			tile.legion = c
	return sim

## Like CombatSimSnapshot.clone_legion, plus the turn state the planner needs.
static func clone_legion_full(L: Legion) -> Legion:
	var c: Legion = CombatSimSnapshot.clone_legion(L)
	c.emit_global_events = false
	c.waited = L.waited
	c.action_cooldowns = L.action_cooldowns.duplicate()
	c._cooldown_skip_tick = L._cooldown_skip_tick.duplicate()
	return c

func apply(cmd: Dictionary) -> Dictionary:
	if phase != Phase.BATTLE:
		return _fail("Match already ended")
	match String(cmd.get("type", "")):
		"use_action":
			var result := resolve_use_action(cmd)
			if result.get("ok", false):
				_check_victory()
			return result
		"pass_legion":
			return apply_pass_legion(cmd.get("coords", Vector2i.ZERO))
	return _fail("Unsupported in turn simulation: %s" % cmd.get("type", ""))

func pass_legion_or_force_wait(coords: Vector2i) -> void:
	if apply({"type": "pass_legion", "coords": coords}).get("ok", false):
		return
	for legion in legions:
		if legion.tile_coords == coords:
			turn_manager.wait_legion(legion)
	prune_stale_legions()

func _check_victory() -> void:
	var alive: Array[String] = []
	for team_id in team_ids:
		if MinigameRulesScript.team_has_army(legions, team_id):
			alive.append(team_id)
	if alive.size() <= 1:
		phase = Phase.ENDED
		winner = alive[0] if alive.size() == 1 else ""
