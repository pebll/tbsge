class_name DraftState
extends RefCounted

var team_id: String
var budget_total: int
var remaining_budget: int
var placements: Array = []
var ready: bool = false

func _init(p_team_id: String, p_budget: int) -> void:
	team_id = p_team_id
	budget_total = p_budget
	remaining_budget = p_budget

func spent_budget() -> int:
	return budget_total - remaining_budget

func slots_used() -> int:
	return placements.size()

func find_placement(coords: Vector2i):
	for p in placements:
		if p.coords == coords:
			return p
	return null

func remove_placement(coords: Vector2i) -> void:
	for i in range(placements.size() - 1, -1, -1):
		if placements[i].coords == coords:
			placements.remove_at(i)
			return
