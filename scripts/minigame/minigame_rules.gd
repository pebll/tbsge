class_name MinigameRules
extends RefCounted

const DEFAULT_UNIT_SIZE := 1.5
const DEFAULT_UNIT_PRICE := 5

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

static func zone_threshold(radius: int) -> int:
	return maxi(1, int(ceil(float(radius) / 2.0)))

static func deploy_zone_coords(
	radius: int,
	team_id: String,
	slot_count: int,
	team_ids: Array[String]
) -> Array[Vector2i]:
	var threshold := zone_threshold(radius)
	var candidates: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var coords := Vector2i(q, r)
			if _is_in_deploy_band(coords, team_id, threshold, team_ids):
				candidates.append(coords)

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			if team_id == team_ids[0]:
				return a.y < b.y
			return a.y > b.y
		return a.x < b.x
	)

	var out: Array[Vector2i] = []
	for i in range(mini(slot_count, candidates.size())):
		out.append(candidates[i])
	return out

static func _is_in_deploy_band(
	coords: Vector2i,
	team_id: String,
	threshold: int,
	team_ids: Array[String]
) -> bool:
	if team_ids.is_empty():
		return false
	if team_id == team_ids[0]:
		return coords.y <= -threshold
	if team_ids.size() > 1 and team_id == team_ids[1]:
		return coords.y >= threshold
	return false

static func validate_draft_placement(
	team_id: String,
	coords: Vector2i,
	unit_type: String,
	unit_count: int,
	draft,
	deploy_slots: Array[Vector2i],
	max_fill: float
) -> String:
	if unit_type.is_empty():
		return "Unit type required"
	if coords not in deploy_slots:
		return "Not a deploy slot for this team"
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
