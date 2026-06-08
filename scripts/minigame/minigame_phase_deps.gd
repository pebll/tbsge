class_name MinigamePhaseDeps
extends RefCounted

var host: Node
var session
var presenter
var battle_ui
var action_runner
var action_playback
var setup_panel
var unit_picker
var turn_hud
var tile_info_panel
var pass_overlay
var status_label
var game_over_panel

func config():
	return session.config if session else null

func first_team_id() -> String:
	var cfg = config()
	if cfg == null or cfg.team_ids.is_empty():
		return ""
	return String(cfg.team_ids[0])

func is_ai_team(team_id: String) -> bool:
	var cfg = config()
	return cfg != null and team_id in cfg.ai_team_ids
