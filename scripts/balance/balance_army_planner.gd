class_name BalanceArmyPlanner
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const UnitDatabaseScript = preload("res://scripts/resources/unit_database.gd")

const UNIT_DB_PATH := "res://data/unit_db.tres"

## Packs budget into as few legions as needed, maxing each legion before starting the next.
static func plan_legion_sizes(
	unit_type: String,
	slot_count: int,
	budget: int,
	max_legion_fill: float
) -> Array[int]:
	if slot_count <= 0 or budget <= 0:
		return []

	var db: UnitDatabaseScript = load(UNIT_DB_PATH) as UnitDatabaseScript
	if db == null:
		return []
	var def = db.get_def(unit_type)
	if def == null or int(def.price) <= 0:
		return []

	var price: int = int(def.price)
	var remaining_budget: int = budget
	var max_per_legion: int = MinigameRulesScript.max_units_in_legion(unit_type, max_legion_fill)
	var out: Array[int] = []

	while remaining_budget >= price and out.size() < slot_count:
		var affordable_units: int = remaining_budget / price
		var legion_size: int = mini(max_per_legion, affordable_units)
		if legion_size <= 0:
			break
		out.append(legion_size)
		remaining_budget -= legion_size * price

	return out

static func plan_placements(
	unit_type: String,
	deploy_slots: Array,
	budget: int,
	max_legion_fill: float
) -> Array[Dictionary]:
	var sizes: Array[int] = plan_legion_sizes(unit_type, deploy_slots.size(), budget, max_legion_fill)
	var out: Array[Dictionary] = []
	for i in range(sizes.size()):
		out.append({
			"coords": deploy_slots[i],
			"unit_type": unit_type,
			"unit_count": sizes[i],
		})
	return out

static func total_units(placements: Array) -> int:
	var total := 0
	for placement in placements:
		total += int(placement.get("unit_count", 0))
	return total

