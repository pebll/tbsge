extends RefCounted

## 0.3 terrain: definitions, movement costs, cover, affinities, line of sight, map gen.

const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")
const MoveReachability = preload("res://scripts/battle/move_reachability.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	for t in [
		_test_definitions,
		_test_forest_costs_two_ap,
		_test_affinity_move_cost,
		_test_swap_pays_terrain,
		_test_forest_cover_and_desert_attack,
		_test_los_mountain_blocks,
		_test_map_is_mirrored_and_connected,
		_test_ranged_targeting_needs_los,
		_test_flyers,
		_test_fog_vision_and_targeting,
	]:
		if not t.call():
			return false
	print("Success: terrain tests")
	return true

func _board(terrain: Dictionary, specs: Array) -> Dictionary:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	for L in session.legions.duplicate():
		session.grid[L.tile_coords].legion = null
		session.legions.erase(L)
	for c in terrain.keys():
		var t: Tile = session.grid[c]
		t.terrain_type = terrain[c]
		t.walkable = TerrainRules.ground_walkable(terrain[c])
	var out: Array[Legion] = []
	for spec in specs:
		var team: String = started["team_a"] if spec[0] == "a" else started["team_b"]
		var legion := Legion.new(String(spec[1]), int(spec[2]), spec[3], team)
		legion.emit_global_events = false
		session.legions.append(legion)
		session.grid[spec[3]].legion = legion
		legion.refresh_ap()
		out.append(legion)
	return {"session": session, "legions": out}

## Affinities aren't on any shipped unit yet; tests put one on a copied definition.
func _give_affinity(L: Legion, affinity: Dictionary, only_type: String = "") -> void:
	for u in L.units:
		if not only_type.is_empty() and u.unit_type != only_type:
			continue
		var def: UnitDefinition = u.definition.duplicate()
		def.terrain_affinity = affinity
		u.definition = def

func _test_definitions() -> bool:
	for id in ["GRASS", "DESERT", "FOREST", "SWAMP", "WATER", "MOUNTAIN"]:
		if TerrainRules.get_def(id) == null:
			push_error("Missing terrain definition %s" % id)
			return false
	if TerrainRules.ground_walkable("WATER") or not TerrainRules.ground_walkable("SWAMP"):
		push_error("Walkability from data is wrong")
		return false
	return true

func _test_forest_costs_two_ap() -> bool:
	var b := _board({Vector2i(1, 0): "FOREST"}, [["a", "GOBLIN", 2, Vector2i(0, 0)]])
	var session = b["session"]
	var L: Legion = b["legions"][0]
	var reach: Dictionary = MoveReachability.compute(session.battle_state(), L)
	if int(reach["cost"].get(Vector2i(1, 0), -1)) != 2:
		push_error("Stepping into forest should cost 2: %s" % reach["cost"].get(Vector2i(1, 0)))
		return false
	if reach["cost"].has(Vector2i(2, 0)) and int(reach["cost"][Vector2i(2, 0)]) < 2:
		push_error("Paths through forest can't be cheaper than going round")
		return false
	var r: Dictionary = session.apply({"type": "use_action", "action_id": "move", "from": Vector2i(0, 0), "to": Vector2i(1, 0)})
	if not r.get("ok", false) or L.current_ap != 0:
		push_error("Moving into forest should spend 2 AP: %s ap=%d" % [r, L.current_ap])
		return false
	return true

func _test_affinity_move_cost() -> bool:
	var b := _board({Vector2i(1, 0): "FOREST"}, [
		["a", "TREANT", 1, Vector2i(0, 0)],
		["a", "GOBLIN", 1, Vector2i(0, 1)],
	])
	var tile: Tile = b["session"].grid[Vector2i(1, 0)]
	_give_affinity(b["legions"][0], {"FOREST": {"move_cost": 1}})
	if TerrainRules.enter_cost(b["legions"][0], tile) != 1:
		push_error("Treant walks through forest for 1 AP")
		return false
	var mixed := Legion.from_composition([["TREANT", 1], ["GOBLIN", 1]], Vector2i.ZERO, "GREEN")
	_give_affinity(mixed, {"FOREST": {"move_cost": 1}}, "TREANT")
	if TerrainRules.enter_cost(mixed, tile) != 2:
		push_error("A mixed legion moves at its slowest unit's cost")
		return false
	return true

func _test_swap_pays_terrain() -> bool:
	var b := _board({Vector2i(0, 0): "FOREST"}, [
		["a", "GOBLIN", 1, Vector2i(0, 0)],
		["a", "GOBLIN", 1, Vector2i(1, 0)],
	])
	var session = b["session"]
	var in_forest: Legion = b["legions"][0]
	var on_grass: Legion = b["legions"][1]
	on_grass.current_ap = 1  # can't pay 2 to step into the forest
	if Vector2i(1, 0) in session.get_action_targets(in_forest, "move"):
		push_error("Swap needs the partner to afford its step into the forest")
		return false
	on_grass.current_ap = 2
	var r: Dictionary = session.apply({"type": "use_action", "action_id": "move", "from": Vector2i(0, 0), "to": Vector2i(1, 0)})
	if not r.get("ok", false) or in_forest.current_ap != 1 or on_grass.current_ap != 0:
		push_error("Swap: grass step 1 AP, forest step 2 AP (got %d / %d)" % [in_forest.current_ap, on_grass.current_ap])
		return false
	return true

func _test_forest_cover_and_desert_attack() -> bool:
	var atk := Legion.new("ARCHER", 1, Vector2i.ZERO, "GREEN")
	var def := Legion.new("GOBLIN", 1, Vector2i(2, 0), "BLUE")
	var r: Dictionary = CombatResolver.resolve_combat(atk, def, 1, {
		"mode": "ranged", "distance": 2, "attacker_terrain": "GRASS", "defender_terrain": "FOREST",
	})
	if not is_equal_approx(float(r["hits"][0]["raw_damage"]), 4.0 * 0.7):
		push_error("Forest cover: 4 ranged x0.7, got %s" % r["hits"][0]["raw_damage"])
		return false
	var rider := Legion.new("SCORPION_RIDER", 1, Vector2i.ZERO, "GREEN")
	_give_affinity(rider, {"DESERT": {"attack": 2}})
	var g := Legion.new("GOLEM", 1, Vector2i(1, 0), "BLUE")
	var r2: Dictionary = CombatResolver.resolve_combat(rider, g, 1, {
		"mode": "melee", "distance": 1, "attacker_terrain": "DESERT", "defender_terrain": "GRASS",
	})
	if not is_equal_approx(float(r2["hits"][0]["raw_damage"]), 10.0):
		push_error("Scorpion rider on desert: 8 + 2, got %s" % r2["hits"][0]["raw_damage"])
		return false
	var plain: Dictionary = CombatResolver.resolve_combat(atk, Legion.new("GOBLIN", 1, Vector2i(2, 0), "BLUE"), 1, {"mode": "ranged", "distance": 2})
	if not is_equal_approx(float(plain["hits"][0]["raw_damage"]), 4.0):
		push_error("No terrain options -> no terrain effects")
		return false
	return true

func _test_los_mountain_blocks() -> bool:
	var grid := {}
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(-q - r) <= 3:
				grid[Vector2i(q, r)] = Tile.new(q, r, "GRASS")
	grid[Vector2i(1, 0)] = Tile.new(1, 0, "MOUNTAIN")
	if TerrainRules.has_los(grid, Vector2i(0, 0), Vector2i(2, 0)):
		push_error("A mountain between should block line of sight")
		return false
	if not TerrainRules.has_los(grid, Vector2i(0, 0), Vector2i(0, 2)):
		push_error("Open line should be clear")
		return false
	if not TerrainRules.has_los(grid, Vector2i(0, 0), Vector2i(1, 0)):
		push_error("Adjacent targets always have line of sight")
		return false
	return true

func _test_map_is_mirrored_and_connected() -> bool:
	var teams: Array[String] = ["GREEN", "BLUE"]
	for seed_i in range(6):
		var grid: Dictionary = MapBuilderScript.build_grid(4, 1000 + seed_i, teams, true)
		for c in grid.keys():
			var v: Vector2i = c
			if grid[v].terrain_type != grid[-v].terrain_type:
				push_error("Map should be point-symmetric (seed %d, %s)" % [seed_i, v])
				return false
		var swamp_or_forest := false
		for t in grid.values():
			if t.terrain_type in ["FOREST", "SWAMP"]:
				swamp_or_forest = true
		if not swamp_or_forest and seed_i == 0:
			push_warning("No forest/swamp on a radius-4 map (unlikely but possible)")
	# Real matches are not mirrored.
	var asym := false
	for seed_i in range(6):
		var g: Dictionary = MapBuilderScript.build_grid(4, 2000 + seed_i, teams)
		for c in g.keys():
			if g[c].terrain_type != g[-c].terrain_type:
				asym = true
	if not asym:
		push_error("Unmirrored maps should not be symmetric")
		return false
	return true

func _test_ranged_targeting_needs_los() -> bool:
	var b := _board({Vector2i(1, 0): "MOUNTAIN"}, [
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["b", "GOBLIN", 2, Vector2i(2, 0)],
		["b", "GOBLIN", 2, Vector2i(0, 2)],
	])
	var targets: Array = b["session"].get_action_targets(b["legions"][0], "ranged_attack")
	if Vector2i(2, 0) in targets or not (Vector2i(0, 2) in targets):
		push_error("The mountain hides (2,0) but not (0,2): %s" % [targets])
		return false
	return true

func _test_flyers() -> bool:
	var b := _board({Vector2i(1, 0): "WATER", Vector2i(2, 0): "MOUNTAIN", Vector2i(0, 1): "FOREST"}, [
		["a", "DRAGON_RIDER", 1, Vector2i(0, 0)],
		["a", "GOBLIN", 1, Vector2i(-1, 0)],
	])
	var session = b["session"]
	var dragon: Legion = b["legions"][0]
	var goblin: Legion = b["legions"][1]
	if not TerrainRules.is_flyer(dragon) or TerrainRules.is_flyer(goblin):
		push_error("Dragon riders fly, goblins don't")
		return false
	var reach: Dictionary = MoveReachability.compute(session.battle_state(), dragon)
	if int(reach["cost"].get(Vector2i(1, 0), -1)) != 1 or int(reach["cost"].get(Vector2i(2, 0), -1)) != 2:
		push_error("Flyers cross water and mountains at 1 AP per hex: %s" % [reach["cost"]])
		return false
	if int(reach["cost"].get(Vector2i(0, 1), -1)) != 1:
		push_error("Forest costs flyers 1 AP")
		return false
	var r: Dictionary = session.apply({"type": "use_action", "action_id": "move", "from": Vector2i(0, 0), "to": Vector2i(1, 0)})
	if not r.get("ok", false) or dragon.tile_coords != Vector2i(1, 0):
		push_error("A flyer can land on water: %s" % r)
		return false
	var mixed := Legion.from_composition([["DRAGON_RIDER", 1], ["GOBLIN", 1]], Vector2i.ZERO, "GREEN")
	if TerrainRules.is_flyer(mixed):
		push_error("A legion with walkers doesn't fly")
		return false
	# Cover doesn't protect flyers.
	var CombatResolverS = load("res://scripts/core/combat_resolver.gd")
	var archer := Legion.new("ARCHER", 1, Vector2i.ZERO, "BLUE")
	var target := Legion.new("GARGOYLE", 1, Vector2i(2, 0), "GREEN")
	target.units[0].shield_remaining = 0
	var res: Dictionary = CombatResolverS.resolve_combat(archer, target, 1, {"mode": "ranged", "distance": 2, "defender_terrain": "FOREST"})
	if not is_equal_approx(float(res["hits"][0]["raw_damage"]), 4.0):
		push_error("Forest cover doesn't apply to flyers, got %s" % res["hits"][0]["raw_damage"])
		return false
	return true

func _test_fog_vision_and_targeting() -> bool:
	var Visibility = load("res://scripts/terrain/visibility.gd")
	var b := _board({Vector2i(-1, 0): "FOREST", Vector2i(1, -1): "MOUNTAIN"}, [
		["a", "ARCHER", 2, Vector2i(0, 0)],
		["a", "GOBLIN", 1, Vector2i(-1, 0)],
		["b", "GOBLIN", 1, Vector2i(2, 0)],
		["b", "GOBLIN", 1, Vector2i(0, -3)],
	])
	var session = b["session"]
	var team: String = b["legions"][0].team_id
	var seen: Dictionary = Visibility.visible_set(session.grid, team)
	if not seen.has(Vector2i(2, 0)) or seen.has(Vector2i(0, -3)):
		push_error("Vision 2 sees (2,0) but not (0,-3)")
		return false
	if Visibility.vision_range(b["legions"][1], session.grid[Vector2i(-1, 0)]) != 1:
		push_error("Forest lowers vision to 1")
		return false
	if seen.has(Vector2i(2, -2)):
		push_error("The mountain at (1,-1) blocks sight to (2,-2)")
		return false
	# Targeting: an archer with range 3 can't shoot what nobody sees.
	b["legions"][0].units[0].attack_range = 3
	b["legions"][0].units[1].attack_range = 3
	session.fog_of_war = false
	var open_t: Array = session.get_action_targets(b["legions"][0], "ranged_attack")
	session.fog_of_war = true
	var fog_t: Array = session.get_action_targets(b["legions"][0], "ranged_attack")
	if not (Vector2i(0, -3) in open_t) or Vector2i(0, -3) in fog_t or not (Vector2i(2, 0) in fog_t):
		push_error("Fog hides (0,-3) from targeting: open %s fog %s" % [open_t, fog_t])
		return false
	return true
