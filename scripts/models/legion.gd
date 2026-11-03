class_name Legion
extends RefCounted

const DEFAULT_MAX_AP := 2

var unit_type: String
var team_id: String
var units: Array[Unit] = []
var tile_coords: Vector2i
## Living units in this legion (always units.size(); read-only).
var unit_count: int:
	get:
		return units.size()
var max_ap: int = DEFAULT_MAX_AP
var current_ap: int = DEFAULT_MAX_AP
## Done for this turn (wait/pass or a terminal action). Lives on the legion — not the
## tile — so moves, swaps, teleports and wipes never leave stale state behind.
## Cleared for every legion by TurnManager.end_team_turn.
var waited: bool = false
## action_id -> remaining own-turns until ready (ticked on refresh_ap).
var action_cooldowns: Dictionary = {}
## Skip one tick after start so cooldown 1 blocks the next full turn.
var _cooldown_skip_tick: Dictionary = {}
## False for headless simulation: skip EventBus autoload emits (unsafe off the main thread).
var emit_global_events: bool = true

func _init(unit_type: String, count: int, tile_coords: Vector2i, team_id: String) -> void:
	self.unit_type = unit_type
	self.tile_coords = tile_coords
	self.team_id = team_id
	_apply_unit_type_defaults()
	for i in range(count):
		var unit = Unit.new(self.unit_type)
		units.append(unit)

func _apply_unit_type_defaults() -> void:
	var def := UnitDefs.get_def(unit_type)
	if def and def.ap > 0:
		max_ap = def.ap
	else:
		max_ap = DEFAULT_MAX_AP
	current_ap = max_ap

## Capabilities aggregate over the legion's units, so rules never depend on which
## unit happens to be first (prerequisite for mixed legions).
func has_ranged() -> bool:
	for unit in units:
		if unit != null and unit.has_ranged():
			return true
	return false

## Longest shot any ranged-capable unit in the legion can take (0 = none).
func max_attack_range() -> int:
	var best := 0
	for unit in units:
		if unit != null and unit.has_ranged():
			best = maxi(best, unit.attack_range)
	return best

## Distinct unit types present, in first-seen order (falls back to unit_type).
func unit_types() -> Array[String]:
	var out: Array[String] = []
	for unit in units:
		if unit != null and unit.unit_type not in out:
			out.append(unit.unit_type)
	if out.is_empty() and not unit_type.is_empty():
		out.append(unit_type)
	return out

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
	var any_shield_restored := false
	for unit in units:
		if unit and unit.reset_turn_state():
			any_shield_restored = true
	if any_shield_restored and emit_global_events:
		EventBus.legion_shields_refilled.emit(self)

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
