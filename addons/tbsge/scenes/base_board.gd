class_name TbsBaseBoard
extends Node2D


@export var controller: TbsGameController
@export var hex_tile_scene: PackedScene
@export var unit_scene: PackedScene
@export var tile_size: float = 64.0
@export var tile_size_xy_ratio: float = 1.4


var tiles: Dictionary = {}  # Vector2i -> TbsBaseHexTile
var units: Dictionary = {}  # int -> TbsBaseUnit


func _ready() -> void:
	print("[TBSGE] BaseBoard _ready, controller: ", controller)
	
	# If controller is null but we have a node path set, try to resolve it manually
	if controller == null:
		print("[TBSGE] Controller is null, trying manual lookup")
		if has_node("../GameController"):
			controller = get_node("../GameController")
			print("[TBSGE] Found controller via ../GameController: ", controller)
	
	if controller:
		controller.board_initialized.connect(_on_board_initialized)
		controller.unit_moved.connect(_on_unit_moved)
		controller.unit_attacked.connect(_on_unit_attacked)
		# In case the controller was initialized before this board,
		# spawn immediately if a board_state already exists.
		if controller.board_state != null:
			print("[TBSGE] BaseBoard detected existing board_state, spawning now")
			_on_board_initialized()
	else:
		print("[TBSGE] ERROR: BaseBoard has no controller!")


func _on_board_initialized() -> void:
	print("[TBSGE] BaseBoard _on_board_initialized")
	_spawn_tiles()
	_spawn_units()


func _spawn_tiles() -> void:
	print("[TBSGE] Spawning tiles")
	for coords: Vector2i in controller.board_state.tiles.keys():
		var tile_state: TbsTileState = controller.board_state.get_tile(coords)
		var terrain_def := controller.board_config.get_terrain_def(tile_state.terrain_id)

		var tile_node: TbsBaseHexTile = hex_tile_scene.instantiate()
		add_child(tile_node)
		# Use proper hex positioning from original mapgen
		var x := tile_size * (coords.x + 0.5 * coords.y)
		var y := tile_size * tile_size_xy_ratio * (0.75 * coords.y)
		tile_node.position = Vector2(x, y)
		tile_node.z_index = int(y / 10.0)
		tile_node.bind_state(tile_state, terrain_def)
		tile_node.pressed.connect(_on_tile_pressed)
		tiles[coords] = tile_node


func _spawn_units() -> void:
	print("[TBSGE] Spawning units")
	for unit_id in controller.board_state.units_by_id.keys():
		var unit_state: TbsUnitState = controller.board_state.get_unit(unit_id)
		var unit_def := controller.board_config.get_unit_def(unit_state.unit_def_id)

		var unit_node: TbsBaseUnit = unit_scene.instantiate()
		add_child(unit_node)
		var tile_node: TbsBaseHexTile = tiles.get(unit_state.coords, null)
		if tile_node:
			unit_node.position = tile_node.position + Vector2(0, -20)  # Offset like original
		unit_node.bind_state(unit_state, unit_def)
		units[unit_id] = unit_node


func _on_tile_pressed(tile_coords: Vector2i, _tile: TbsBaseHexTile) -> void:
	# For now, this board only emits; game-specific scripts decide what to do.
	# You can extend this class and override this method.
	pass


func _on_unit_moved(unit_state: TbsUnitState, from_coords: Vector2i, to_coords: Vector2i) -> void:
	var unit_node: TbsBaseUnit = units.get(unit_state.id, null)
	if not unit_node:
		return
	var from_tile: TbsBaseHexTile = tiles.get(from_coords, null)
	var to_tile: TbsBaseHexTile = tiles.get(to_coords, null)
	if not to_tile:
		return
	var from_pos := from_tile.position if from_tile else unit_node.position
	unit_node.play_move(from_pos, to_tile.position)


func _on_unit_attacked(attacker: TbsUnitState, target: TbsUnitState) -> void:
	var attacker_node: TbsBaseUnit = units.get(attacker.id, null)
	var target_node: TbsBaseUnit = units.get(target.id, null)
	if not attacker_node or not target_node:
		return
	var direction := (target_node.position - attacker_node.position).normalized()
	attacker_node.play_attack(direction)
