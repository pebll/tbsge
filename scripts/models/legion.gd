class_name Legion
extends RefCounted

const DEFAULT_MAX_AP := 2

## Label type: the most numerous unit type (ties: first seen). Single-type UI reads it
## (title, icon, click/move sounds). Rules, cost and stats read `units`: a legion can hold
## any mix of unit types. Assigning sets the fallback for an empty legion.
var unit_type: String:
	get:
		return primary_unit_type()
	set(value):
		_base_type = value
var _base_type: String = ""
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

func _init(p_unit_type: String, count: int, p_tile_coords: Vector2i, p_team_id: String) -> void:
	_base_type = p_unit_type
	tile_coords = p_tile_coords
	team_id = p_team_id
	for i in range(count):
		units.append(Unit.new(p_unit_type))
	refresh_max_ap()
	current_ap = max_ap

## A legion from a composition: [[unit_type, count], ...] (types may repeat).
static func from_composition(parts: Array, p_tile_coords: Vector2i, p_team_id: String) -> Legion:
	var first := ""
	for part in parts:
		if int(part[1]) > 0:
			first = String(part[0])
			break
	var legion := Legion.new(first, 0, p_tile_coords, p_team_id)
	for part in parts:
		for i in range(int(part[1])):
			legion.units.append(Unit.new(String(part[0])))
	legion.refresh_max_ap()
	legion.current_ap = legion.max_ap
	return legion

## The slowest unit type sets the pace: max AP = the lowest AP among the types present.
func refresh_max_ap() -> void:
	var best := -1
	for type_id in unit_types():
		var def := UnitDefs.get_def(type_id)
		var ap := def.ap if def and def.ap > 0 else DEFAULT_MAX_AP
		best = ap if best < 0 else mini(best, ap)
	max_ap = best if best > 0 else DEFAULT_MAX_AP

func primary_unit_type() -> String:
	var counts := {}
	var order: Array[String] = []
	for unit in units:
		if unit == null:
			continue
		if not counts.has(unit.unit_type):
			counts[unit.unit_type] = 0
			order.append(unit.unit_type)
		counts[unit.unit_type] += 1
	var best := _base_type
	var best_n := 0
	for t in order:
		if int(counts[t]) > best_n:
			best = t
			best_n = int(counts[t])
	return best

## [[unit_type, count], ...] in first-seen order.
func composition() -> Array:
	var counts := {}
	var order: Array[String] = []
	for unit in units:
		if unit == null:
			continue
		if not counts.has(unit.unit_type):
			counts[unit.unit_type] = 0
			order.append(unit.unit_type)
		counts[unit.unit_type] += 1
	var out: Array = []
	for t in order:
		out.append([t, int(counts[t])])
	return out

func is_mixed() -> bool:
	return unit_types().size() > 1

## Living units of one type.
func count_of(type_id: String) -> int:
	var n := 0
	for unit in units:
		if unit != null and unit.unit_type == type_id:
			n += 1
	return n

## Draft price of the living units (each unit at its own type's price).
func gold_value() -> int:
	var total := 0
	for unit in units:
		if unit == null:
			continue
		var def := UnitDefs.get_def(unit.unit_type)
		total += def.price if def else 5
	return total

## "Goblin" or "Goblin + Archer" (display names, composition order).
func display_name() -> String:
	var names: PackedStringArray = PackedStringArray()
	for type_id in unit_types():
		var def := UnitDefs.get_def(type_id)
		names.append(def.display_name if def and not def.display_name.is_empty() else type_id.capitalize())
	return " + ".join(names)

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
	if out.is_empty() and not _base_type.is_empty():
		out.append(_base_type)
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
