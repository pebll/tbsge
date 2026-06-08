class_name MinigameTestHelpers
extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")

const DUEL_CONFIG_PATH := "res://data/minigame/duel_r3.tres"

static func load_duel_config() -> MinigameConfigScript:
	return load(DUEL_CONFIG_PATH) as MinigameConfigScript

static func prepare_session(config_path: String = DUEL_CONFIG_PATH) -> MinigameSessionScript:
	var config: MinigameConfigScript = load(config_path) as MinigameConfigScript
	var session := MinigameSessionScript.new(config)
	for tile in session.grid.values():
		tile.terrain_type = "GRASS"
		tile.walkable = true
	session.refresh_deploy_slots()
	return session

static func team_a(session) -> String:
	return session.config.first_team_id()

static func team_b(session) -> String:
	return session.config.second_team_id()

static func start_two_legion_battle(session) -> Dictionary:
	var team_a_id := team_a(session)
	var team_b_id := team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	var slots_b: Array = session.get_deploy_slots(team_b_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})
	session.apply({
		"type": "draft_set_legion",
		"team": team_b_id,
		"coords": slots_b[0],
		"unit_type": "RAT_SPEAR",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": team_b_id})

	var legion_a: Legion = null
	var legion_b: Legion = null
	for legion in session.legions:
		if legion.team_id == team_a_id:
			legion_a = legion
		elif legion.team_id == team_b_id:
			legion_b = legion
	return {"a": legion_a, "b": legion_b, "team_a": team_a_id, "team_b": team_b_id}
