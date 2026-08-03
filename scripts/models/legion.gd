class_name Legion
extends RefCounted

const DEFAULT_MAX_AP := 2

var unit_type: String
var team_id: String
var units: Array[Unit] = []
var tile_coords: Vector2i
var unit_count: int
var max_ap: int = DEFAULT_MAX_AP
var current_ap: int = DEFAULT_MAX_AP
## action_id -> remaining own-turns until ready (ticked on refresh_ap).
var action_cooldowns: Dictionary = {}
## Skip one tick after start so cooldown 1 blocks the next full turn.
var _cooldown_skip_tick: Dictionary = {}

func _init(unit_type: String, unit_count: int, tile_coords: Vector2i, team_id: String) -> void:
	self.unit_type = unit_type
	self.unit_count = unit_count
	self.tile_coords = tile_coords
	self.team_id = team_id
	_apply_unit_type_defaults()
	for i in range(unit_count):
		var unit = Unit.new(self.unit_type)
		units.append(unit)

func _apply_unit_type_defaults() -> void:
	var def := UnitDefs.get_def(unit_type)
	if def and def.ap > 0:
		max_ap = def.ap
	else:
		max_ap = DEFAULT_MAX_AP
	current_ap = max_ap

func has_ap() -> bool:
	return current_ap > 0

func can_afford(cost: int) -> bool:
	return current_ap >= cost

func spend_ap(cost: int) -> bool:
	if not can_afford(cost):
		return false
	current_ap -= cost
	return true

func spend_all_ap() -> void:
	current_ap = 0

func refresh_ap() -> void:
	current_ap = max_ap
	tick_cooldowns()
	for unit in units:
		unit.reset_turn_state()

func get_cooldown_remaining(action_id: String) -> int:
	return int(action_cooldowns.get(action_id, 0))

func is_action_ready(action_id: String) -> bool:
	return get_cooldown_remaining(action_id) <= 0

func start_cooldown(action_id: String, turns: int) -> void:
	if action_id.is_empty() or turns <= 0:
		return
	action_cooldowns[action_id] = turns
	# refresh_ap ticks at the start of each of our turns. Skipping the first tick
	# makes cooldown 1 mean "unavailable for the next turn", not "ready again
	# as soon as that turn starts".
	_cooldown_skip_tick[action_id] = true

func tick_cooldowns() -> void:
	var finished: Array[String] = []
	for action_id in action_cooldowns.keys():
		var key := String(action_id)
		if bool(_cooldown_skip_tick.get(key, false)):
			_cooldown_skip_tick[key] = false
			continue
		var left: int = int(action_cooldowns[key]) - 1
		if left <= 0:
			finished.append(key)
		else:
			action_cooldowns[key] = left
	for action_id in finished:
		action_cooldowns.erase(action_id)
		_cooldown_skip_tick.erase(action_id)
