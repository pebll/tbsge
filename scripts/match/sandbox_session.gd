class_name SandboxSession
extends "res://scripts/match/match_session.gd"

const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const SandboxConfigScript = preload("res://scripts/match/sandbox_config.gd")

var config: SandboxConfigScript

func _init(p_config: SandboxConfigScript) -> void:
	config = p_config
	super._init(config.team_ids)
	grid = MapBuilderScript.build_grid(config.map_radius, -1, config.team_ids)
	if not team_ids.is_empty():
		turn_manager.start_match(team_ids[0])

func apply(cmd: Dictionary) -> Dictionary:
	var cmd_type: String = String(cmd.get("type", ""))
	match cmd_type:
		"use_action":
			return resolve_use_action(cmd)
		"spawn_unit":
			return _spawn_unit(cmd)
		"end_turn":
			return apply_end_turn()
		"pass_legion":
			return apply_pass_legion(cmd.get("coords", Vector2i.ZERO))
		_:
			return _fail("Unknown sandbox command: %s" % cmd_type)

func spawn_unit_at(coords: Vector2i, rng: RandomNumberGenerator = null) -> Dictionary:
	return apply({
		"type": "spawn_unit",
		"coords": coords,
		"rng": rng,
	})

func _spawn_unit(cmd: Dictionary) -> Dictionary:
	if not config.allow_spawn:
		return _fail("Spawning disabled")
	var coords: Vector2i = cmd.get("coords", Vector2i.ZERO)
	var tile: Tile = _tile_at(coords)
	if tile == null:
		return _fail("Invalid tile")
	if not tile.walkable or tile.has_legion():
		return _fail("Tile not adequate for spawning")

	var rng: RandomNumberGenerator = cmd.get("rng")
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var unit_ids := UnitDefs.get_all_ids()
	if unit_ids.is_empty():
		return _fail("No unit definitions")

	var team_id: String = turn_manager.active_team_id
	var legion := Legion.new(
		unit_ids[rng.randi() % unit_ids.size()],
		rng.randi() % 8 + 1,
		coords,
		team_id
	)
	legion.refresh_ap()
	legions.append(legion)
	tile.legion = legion
	return _ok(["unit_spawned"], {"legion": legion, "coords": coords})
