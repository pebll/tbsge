class_name MinigameConfig
extends Resource

@export var id: String = "duel"
@export var display_name: String = "Duel"
@export var map_radius: int = 3
@export var budget: int = 50
@export var deploy_slot_count: int = 7
@export var team_ids: Array[String] = ["GREEN", "BLUE"]
@export var ai_team_ids: Array[String] = ["BLUE"]
@export var max_legion_fill: float = 12.0

func first_team_id() -> String:
	return team_ids[0] if not team_ids.is_empty() else ""

func second_team_id() -> String:
	return team_ids[1] if team_ids.size() > 1 else ""

func is_ai_team(team_id: String) -> bool:
	return team_id in ai_team_ids
