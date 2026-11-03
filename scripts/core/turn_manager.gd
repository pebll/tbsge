class_name TurnManager
extends RefCounted

const INVALID_COORDS := Vector2i(2147483647, 2147483647)

var team_order: Array[String] = []
var active_team_id: String = ""
## Increments each time a team ends their turn (starts at 1).
var turn_index: int = 1

var _tab_index: int = 0

func _init(p_team_order: Array) -> void:
	team_order.clear()
	for team_id in p_team_order:
		team_order.append(String(team_id))

func start_match(first_team: String) -> void:
	active_team_id = first_team
	_tab_index = 0
	turn_index = 1

func end_team_turn(legions: Array[Legion]) -> String:
	active_team_id = _next_team_id()
	_tab_index = 0
	turn_index += 1
	clear_all_waits(legions)
	for legion in legions:
		if legion.team_id == active_team_id:
			legion.refresh_ap()
	return active_team_id

func is_legion_active(legion: Legion) -> bool:
	return legion != null and legion.team_id == active_team_id

func get_actionable_coords(legions: Array[Legion]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for legion in legions:
		if legion.team_id != active_team_id:
			continue
		if not legion.has_ap():
			continue
		if legion.waited:
			continue
		out.append(legion.tile_coords)
	return out

func tab_next(legions: Array[Legion]) -> Vector2i:
	var actionable := get_actionable_coords(legions)
	if actionable.is_empty():
		return INVALID_COORDS
	if _tab_index >= actionable.size():
		_tab_index = 0
	var coords: Vector2i = actionable[_tab_index]
	_tab_index = (_tab_index + 1) % actionable.size()
	return coords

func wait_legion(legion: Legion) -> void:
	if legion != null:
		legion.waited = true

func clear_wait(legion: Legion) -> void:
	if legion != null:
		legion.waited = false

func is_waited(legion: Legion) -> bool:
	return legion != null and legion.waited

func clear_all_waits(legions: Array) -> void:
	for legion in legions:
		if legion != null:
			legion.waited = false

func _next_team_id() -> String:
	if team_order.is_empty():
		return active_team_id
	var idx := team_order.find(active_team_id)
	if idx < 0:
		return team_order[0]
	return team_order[(idx + 1) % team_order.size()]
