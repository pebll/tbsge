class_name MenuBackground
extends Node2D

const MenuStreamUtils = preload("res://scripts/core/menu_stream_utils.gd")

const UNITS: Array[String] = [
	"AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT",
]
const TEAM_IDS: Array[String] = ["GREEN", "BLUE"]

@export var scroll_direction: Vector2 = Vector2(-0.6, -0.2)
@export var scroll_speed: float = 40.0
@export var tile_size: float = 135.3
@export var tile_size_xy_ratio: float = 0.75
@export var view_margin_tiles: int = 2
@export var unit_density: float = 0.12
@export var menu_seed: int = 0
@export var cull_interval_frames: int = 3

var _tiles_container: Node2D
var _active_tiles: Dictionary = {}
var _scroll_offset: Vector2 = Vector2.ZERO
var _frame_counter: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if menu_seed != 0:
		_rng.seed = menu_seed
	else:
		_rng.randomize()
	scroll_direction = scroll_direction.normalized()

	var cam := get_parent().get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()

	_tiles_container = Node2D.new()
	_tiles_container.name = "Tiles"
	add_child(_tiles_container)
	_refresh_tiles()

func _process(delta: float) -> void:
	_scroll_offset += scroll_direction * scroll_speed * delta
	_tiles_container.position = _scroll_offset
	_frame_counter += 1
	if _frame_counter % cull_interval_frames == 0:
		_refresh_tiles()

func _get_tiles_local_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-600.0, -400.0, 1200.0, 800.0)

	var vp_size := get_viewport().get_visible_rect().size
	var half := vp_size / (2.0 * cam.zoom)
	var top_left_world := cam.global_position - half
	return Rect2(top_left_world - _scroll_offset, half * 2.0)

func _refresh_tiles() -> void:
	var local_rect := _get_tiles_local_rect()
	var bounds := MenuStreamUtils.coord_bounds_for_rect(
		local_rect, tile_size, tile_size_xy_ratio, view_margin_tiles
	)

	var needed: Dictionary = {}
	for coords in MenuStreamUtils.iter_coords_in_bounds(bounds):
		needed[coords] = true
		if not _active_tiles.has(coords):
			_spawn_tile(coords)

	var to_remove: Array[Vector2i] = []
	for coords in _active_tiles.keys():
		if not needed.has(coords):
			to_remove.append(coords)
	for coords in to_remove:
		_despawn_tile(coords)

func _spawn_tile(coords: Vector2i) -> void:
	var tile := Tile.new(coords.x, coords.y)
	var tile_visu: TileVisu = preload("res://scenes/hextile.tscn").instantiate()
	var world_pos := MenuStreamUtils.axial_to_world(
		coords.x, coords.y, tile_size, tile_size_xy_ratio
	)
	tile_visu.position = world_pos
	tile_visu.z_index = int(world_pos.y / 10.0)
	_tiles_container.add_child(tile_visu)
	tile_visu.init(tile)
	_configure_decorative_tile(tile_visu)

	if tile.walkable and _rng.randf() < unit_density:
		_spawn_decorative_legion(tile, tile_visu)

	_active_tiles[coords] = tile_visu

func _configure_decorative_tile(tile_visu: TileVisu) -> void:
	if tile_visu.qr_label:
		tile_visu.qr_label.visible = false
	var area: Area2D = tile_visu.get_node_or_null("Area2D") as Area2D
	if area:
		area.input_pickable = false
		area.monitoring = false
		area.monitorable = false

func _spawn_decorative_legion(tile: Tile, tile_visu: TileVisu) -> void:
	var unit_type: String = UNITS[_rng.randi() % UNITS.size()]
	var unit_count: int = _rng.randi_range(1, 8)
	var team_id: String = TEAM_IDS[_rng.randi() % TEAM_IDS.size()]
	var legion := Legion.new(unit_type, unit_count, tile.coords, team_id)
	var legion_visu: LegionVisu = preload("res://scenes/legion.tscn").instantiate()
	_tiles_container.add_child(legion_visu)
	legion_visu.init(legion)
	legion_visu.position = tile_visu.position
	tile.legion = legion
	tile_visu.legion_visu = legion_visu

func _despawn_tile(coords: Vector2i) -> void:
	var tile_visu: TileVisu = _active_tiles.get(coords)
	if tile_visu == null:
		_active_tiles.erase(coords)
		return
	if tile_visu.legion_visu and is_instance_valid(tile_visu.legion_visu):
		tile_visu.legion_visu.queue_free()
	tile_visu.queue_free()
	_active_tiles.erase(coords)
