class_name MinigameRules
extends RefCounted

const DEFAULT_UNIT_SIZE := 1.5
const DEFAULT_UNIT_PRICE := 5
const DEPLOY_ROW_COUNT := 2

static func get_unit_def(unit_type: String) -> UnitDefinition:
	return UnitDefs.get_def(unit_type)

static func unit_size(unit_type: String) -> float:
	var def := get_unit_def(unit_type)
	return def.size if def else DEFAULT_UNIT_SIZE

static func unit_price(unit_type: String) -> int:
	var def := get_unit_def(unit_type)
	return def.price if def else DEFAULT_UNIT_PRICE

static func legion_fill(unit_type: String, count: int) -> float:
	return unit_size(unit_type) * float(count)

static func max_units_in_legion(unit_type: String, max_fill: float = 12.0) -> int:
	var size := unit_size(unit_type)
	if size <= 0.0:
		return 1
	return maxi(1, int(floor(max_fill / size)))

static func legion_cost(unit_type: String, count: int) -> int:
	return unit_price(unit_type) * count

static func deploy_zone_coords(
	radius: int,
	team_id: String,
	_slot_count: int,
	team_ids: Array[String]
) -> Array[Vector2i]:
	var by_r: Dictionary = {}
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var coords := Vector2i(q, r)
			if not by_r.has(r):
				by_r[r] = []
			(by_r[r] as Array).append(coords)

	var r_values: Array = by_r.keys()
	r_values.sort()

	if r_values.size() < DEPLOY_ROW_COUNT:
		return []

	var target_rs: Array = []
	if team_ids.is_empty():
		return []
	if team_id == team_ids[0]:
		for i in range(DEPLOY_ROW_COUNT):
			target_rs.append(r_values[i])
	elif team_ids.size() > 1 and team_id == team_ids[1]:
		for i in range(DEPLOY_ROW_COUNT):
			target_rs.append(r_values[r_values.size() - 1 - i])
	else:
		return []

	var out: Array[Vector2i] = []
	for r in target_rs:
		for coords in by_r[r]:
			out.append(coords)

	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			if team_id == team_ids[0]:
				return a.y < b.y
			return a.y > b.y
		return a.x < b.x
	)
	return _filter_walkable(out)

static func deploy_back_row_coords(
	radius: int,
	team_id: String,
	team_ids: Array[String]
) -> Array[Vector2i]:
	var by_r: Dictionary = {}
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var coords := Vector2i(q, r)
			if not by_r.has(r):
				by_r[r] = []
			(by_r[r] as Array).append(coords)

	var r_values: Array = by_r.keys()
	r_values.sort()
	if r_values.is_empty() or team_ids.is_empty():
		return []

	var back_r: int
	if team_id == team_ids[0]:
		back_r = r_values[0]
	elif team_ids.size() > 1 and team_id == team_ids[1]:
		back_r = r_values[r_values.size() - 1]
	else:
		return []

	var out: Array[Vector2i] = []
	for coords in by_r[back_r]:
		out.append(coords)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x
	)
	return out

static func _filter_walkable(coords_list: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coords in coords_list:
		out.append(coords)
	return out

static func is_walkable_deploy_slot(grid: Dictionary, coords: Vector2i) -> bool:
	var tile = grid.get(coords)
	return tile != null and tile.walkable

static func validate_draft_placement(
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	unit_count: int,
	draft,
	deploy_slots: Array[Vector2i],
	max_fill: float,
	grid: Dictionary = {}
) -> String:
	if unit_type.is_empty():
		return "Unit type required"
	if coords not in deploy_slots:
		return "Not a deploy slot for this team"
	if not grid.is_empty() and not is_walkable_deploy_slot(grid, coords):
		return "Tile is not walkable"
	if unit_count < 1:
		return "Need at least one unit"
	var max_units := max_units_in_legion(unit_type, max_fill)
	if unit_count > max_units:
		return "Too many units for this type"
	if legion_fill(unit_type, unit_count) > max_fill + 0.001:
		return "Legion exceeds max size"
	var cost := legion_cost(unit_type, unit_count)
	var existing = draft.find_placement(coords)
	var old_cost: int = 0
	if existing:
		old_cost = legion_cost(existing.unit_type, existing.unit_count)
	if cost - old_cost > draft.remaining_budget:
		return "Not enough gold"
	return ""

static func count_living_units(legions: Array, team_id: String) -> int:
	var total := 0
	for legion in legions:
		if legion.team_id != team_id:
			continue
		total += legion.units.size()
	return total

static func team_has_army(legions: Array, team_id: String) -> bool:
	return count_living_units(legions, team_id) > 0
