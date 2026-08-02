class_name TurnManager
extends RefCounted

const INVALID_COORDS := Vector2i(2147483647, 2147483647)

var team_order: Array[String] = []
var active_team_id: String = ""
var waited_coords: Array[Vector2i] = []

var _tab_index: int = 0

func _init(p_team_order: Array) -> void:
	team_order.clear()
	for team_id in p_team_order:
		team_order.append(String(team_id))

func start_match(first_team: String) -> void:
	active_team_id = first_team
	waited_coords.clear()
	_tab_index = 0

func end_team_turn(legions: Array[Legion]) -> String:
	active_team_id = _next_team_id()
	waited_coords.clear()
	_tab_index = 0
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
		if legion.tile_coords in waited_coords:
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

func wait_legion(coords: Vector2i) -> void:
	if coords not in waited_coords:
		waited_coords.append(coords)

func clear_wait(coords: Vector2i) -> void:
	waited_coords.erase(coords)

func _next_team_id() -> String:
	if team_order.is_empty():
		return active_team_id
	var idx := team_order.find(active_team_id)
	if idx < 0:
		return team_order[0]
	return team_order[(idx + 1) % team_order.size()]
