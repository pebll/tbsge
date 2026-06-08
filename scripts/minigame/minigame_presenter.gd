class_name MinigamePresenter
extends "res://scripts/visu/grid_presenter.gd"

const LIFT_DEPLOY := 2.0
const LIFT_SELECTED := 4.0
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

var _draft_preview_by_coords: Dictionary = {}
var _draft_formation_seeds: Dictionary = {}
var _draft_price_tags: Dictionary = {}

func build_map(session) -> void:
	build_map_from_grid(session.grid)

func paint_deploy_zones(
	deploy_slots: Array,
	occupied_coords: Array,
	selected_coords: Vector2i
) -> void:
	clear_deploy_overlays()
	for coords in deploy_slots:
		var visu: TileVisu = grid_visu.get(coords)
		if not visu:
			continue
		if coords == selected_coords:
			visu.set_gameplay_overlay("selected", LIFT_SELECTED)
		elif coords in occupied_coords:
			visu.set_gameplay_overlay("deployed", LIFT_DEPLOY)
		else:
			visu.set_gameplay_overlay("deployable", LIFT_DEPLOY)

func clear_deploy_overlays() -> void:
	for visu in grid_visu.values():
		if visu:
			visu.set_gameplay_overlay("", 0.0)

func sync_draft_previews(placements: Array, team_id: String) -> void:
	var desired: Dictionary = {}
	for p in placements:
		var coords: Vector2i = p.get("coords", Vector2i.ZERO)
		var unit_type: String = String(p.get("unit_type", ""))
		var unit_count: int = int(p.get("unit_count", 0))
		if unit_type.is_empty() or unit_count < 1:
			continue
		desired[coords] = {"unit_type": unit_type, "unit_count": unit_count}

	for coords in _draft_preview_by_coords.keys().duplicate():
		if not desired.has(coords):
			_remove_draft_preview_at(coords)

	for coords in desired.keys():
		var data: Dictionary = desired[coords]
		var unit_type: String = String(data.get("unit_type", ""))
		var unit_count: int = int(data.get("unit_count", 0))
		if _draft_preview_by_coords.has(coords):
			_update_draft_preview_at(coords, unit_type, unit_count, team_id)
		else:
			_spawn_draft_preview_at(coords, unit_type, unit_count, team_id)

func sync_legions(session) -> void:
	_clear_draft_previews()
	super.sync_legions(session)

func get_draft_preview_legion_at(coords: Vector2i) -> Legion:
	return _draft_preview_by_coords.get(coords)

func _spawn_draft_preview_at(
	coords: Vector2i,
	unit_type: String,
	unit_count: int,
	team_id: String,
	formation_seed: int = -1
) -> void:
	var legion := Legion.new(unit_type, unit_count, coords, team_id)
	var seed := formation_seed if formation_seed >= 0 else randi()
	_draft_formation_seeds[coords] = seed
	_draft_preview_by_coords[coords] = legion
	spawn_legion_visu(legion, seed)
	_attach_price_tag(legion)

func _update_draft_preview_at(coords: Vector2i, unit_type: String, unit_count: int, team_id: String) -> void:
	var legion: Legion = _draft_preview_by_coords.get(coords)
	if legion == null:
		_spawn_draft_preview_at(coords, unit_type, unit_count, team_id)
		return
	var tile_visu: TileVisu = grid_visu.get(coords)
	var visu: LegionVisu = tile_visu.legion_visu if tile_visu else null
	if visu == null:
		_remove_draft_preview_at(coords)
		_spawn_draft_preview_at(coords, unit_type, unit_count, team_id)
		return
	if legion.unit_type != unit_type:
		var seed: int = int(_draft_formation_seeds.get(coords, randi()))
		_remove_draft_preview_at(coords)
		_spawn_draft_preview_at(coords, unit_type, unit_count, team_id, seed)
		return
	if (
		legion.unit_type == unit_type
		and legion.unit_count == unit_count
		and legion.units.size() == unit_count
		and visu.units.get_child_count() == unit_count
	):
		return
	visu.set_unit_count(unit_count)
	_update_price_tag(legion)

func _remove_draft_preview_at(coords: Vector2i) -> void:
	var legion: Legion = _draft_preview_by_coords.get(coords)
	if legion:
		_remove_legion_visu(legion)
	_draft_preview_by_coords.erase(coords)
	_draft_formation_seeds.erase(coords)

func _update_price_tag(legion: Legion) -> void:
	_attach_price_tag(legion)

func _remove_legion_visu(legion: Legion) -> void:
	_remove_price_tag(legion)
	super._remove_legion_visu(legion)

func _clear_draft_previews() -> void:
	for coords in _draft_preview_by_coords.keys().duplicate():
		_remove_draft_preview_at(coords)
	_draft_price_tags.clear()

func _attach_price_tag(legion: Legion) -> void:
	var visu: LegionVisu = legion_to_visu.get(legion)
	if not visu:
		return
	_remove_price_tag(legion)
	var tag := DraftLegionPriceTag.new()
	var cost := MinigameRulesScript.legion_cost(legion.unit_type, legion.units.size())
	tag.set_cost(cost)
	visu.add_child(tag)
	_draft_price_tags[legion] = tag

func _remove_price_tag(legion: Legion) -> void:
	var tag = _draft_price_tags.get(legion)
	if tag and is_instance_valid(tag):
		tag.queue_free()
	_draft_price_tags.erase(legion)

func _clear_map() -> void:
	_clear_draft_previews()
	super._clear_map()
