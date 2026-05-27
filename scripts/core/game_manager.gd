class_name GameManager
extends Node2D

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

@export var map_radius: int = 3
var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75
const UNITS = ["AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT"]


@onready var grid_visu : Dictionary[Vector2i, TileVisu] = {}
@onready var grid_model : Dictionary[Vector2i, Tile] = {}
@onready var legions : Array[Legion] = []

var tilesContainer : Node
var ui : GameUI
var mapGenerator : MapGenerator
var tile_info_panel
var tile_info_layer: CanvasLayer
var combat_fx_layer: CanvasLayer

const ICON_DEATHS := preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_HP_LOST := preload("res://assets/icons/base_icons_sprites/heart.png")

func _ready():
	ui = GameUI.new(self)
	mapGenerator = MapGenerator.new(tile_size, tile_size_xy_ratio)
	# TODO: fix this when refactor mapgenerator
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	mapGenerator.generate_hex_map(map_radius, tilesContainer, self.grid_visu, self.grid_model)

	_setup_tile_info_ui()
	_setup_combat_fx_ui()

func _setup_tile_info_ui() -> void:
	tile_info_layer = CanvasLayer.new()
	tile_info_layer.name = "UI"
	add_child(tile_info_layer)

	tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	tile_info_layer.add_child(tile_info_panel)
	tile_info_panel.hide()

func _setup_combat_fx_ui() -> void:
	combat_fx_layer = CanvasLayer.new()
	combat_fx_layer.name = "CombatFX"
	combat_fx_layer.layer = 2
	add_child(combat_fx_layer)

# Todo: refactor HexTile to have a logic side?
func spawn_unit(coords: Vector2i):
	var tile = grid_model.get(coords)
	var tile_visu = grid_visu.get(coords)
	if not tile or not tile_visu:
		return

	# Spawns random legion at given coords
	if tile.has_legion() or not tile.walkable:
		print("tile not adequate for spawning")
		return # only spawn if tile is empty
	var legion = Legion.new(UNITS[randi()%8], randi()%8+1, coords)
	var legionVisu = preload("res://scenes/legion.tscn").instantiate()
	# TODO: refactor this into own folder (like for the tiles)
	self.add_child(legionVisu)
	legions.append(legion)
	tile.legion = legion
	tile_visu.legion_visu = legionVisu
	legionVisu.init(legion)
	legionVisu.position = tile_visu.position
	# Let Y-sort / internal unit z-indices handle draw order.

func inspect_tile(coords: Vector2i) -> void:
	if not tile_info_panel:
		return
	var tile: Tile = grid_model.get(coords)
	if not tile or not tile.has_legion():
		tile_info_panel.hide()
		return
	tile_info_panel.show_tile(tile)
	tile_info_panel.show()

func clear_inspect() -> void:
	if tile_info_panel:
		tile_info_panel.hide()

func move_unit(from_coords: Vector2i, to_coords: Vector2i):
	var from_tile = grid_model.get(from_coords)
	var to_tile = grid_model.get(to_coords)
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_tile or not to_tile or not from_visu or not to_visu:
		return
	if not from_tile.legion:
		return
	if to_tile.has_legion():
		return

	var legion: Legion = from_tile.legion
	var legion_visu: LegionVisu = from_visu.legion_visu

	from_tile.legion = null
	from_visu.legion_visu = null
	to_tile.legion = legion
	to_visu.legion_visu = legion_visu
	legion.tile_coords = to_coords

	legion_visu.juice_move(to_visu.position)

func attack_unit(from_coords: Vector2i, to_coords: Vector2i):
	var from_tile = grid_model.get(from_coords)
	var to_tile = grid_model.get(to_coords)
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_tile or not to_tile or not from_visu or not to_visu:
		return
	if not from_visu.legion_visu or not to_visu.legion_visu:
		return

	# Logic-only combat: update healths and remove dead units/legions.
	var attacker: Legion = from_tile.legion
	var defender: Legion = to_tile.legion
	if not attacker or not defender:
		return

	var result: Dictionary = CombatResolver.resolve_combat(attacker, defender, randi())
	var hits: Array = result.get("hits", [])
	var deaths: Array = result.get("deaths", [])

	# Snapshot initial positions in case a legion dies and gets removed.
	var attacker_world_pos: Vector2 = from_visu.legion_visu.global_position
	var defender_world_pos: Vector2 = to_visu.legion_visu.global_position

	# Build death lookup by hit index for immediate visual updates.
	var deaths_by_hit: Dictionary = {}
	for d in deaths:
		deaths_by_hit[d["hit_index"]] = d

	# Map model legions to their visu nodes (stable even when combat alternates).
	var legion_to_visu: Dictionary = {
		attacker: from_visu.legion_visu,
		defender: to_visu.legion_visu,
	}

	# Before the fight begins, make both legions face each other.
	var a_visu: LegionVisu = legion_to_visu.get(attacker)
	var d_visu: LegionVisu = legion_to_visu.get(defender)
	if a_visu and d_visu:
		var face_dir: Vector2 = (d_visu.global_position - a_visu.global_position).normalized()
		a_visu.update_direction(face_dir)
		d_visu.update_direction(-face_dir)

	# Play sequential animations: only attacker + target animate per hit.
	var gap_s := 0.3
	for h in hits:
		var atk_legion: Legion = h["attacker_legion"]
		var def_legion: Legion = h["defender_legion"]
		var atk_unit: Unit = h["attacker"]
		var def_unit: Unit = h["target"]
		var def_hp_before: float = float(h.get("target_hp_before", -1.0))
		var def_hp_after: float = float(h.get("target_hp_after", -1.0))

		var atk_visu: LegionVisu = legion_to_visu.get(atk_legion)
		var def_visu: LegionVisu = legion_to_visu.get(def_legion)
		if not atk_visu or not def_visu:
			continue

		var difference: Vector2 = def_visu.global_position - atk_visu.global_position
		var dir := difference.normalized()

		atk_visu.animate_unit_attack(atk_unit, dir)

		# If a unit dies on this hit, remove it from the defending legion visu immediately.
		var hit_idx: int = h["hit_index"]
		var died_on_hit := false
		if deaths_by_hit.has(hit_idx):
			var d = deaths_by_hit[hit_idx]
			if d.get("legion") == def_legion and d.get("unit") == def_unit:
				died_on_hit = true
				def_visu.animate_unit_death(def_unit, dir)

		# Only play the regular hit feedback if the unit survived this hit.
		if not died_on_hit:
			def_visu.animate_unit_hitted(def_unit, dir, def_hp_before, def_hp_after, float(def_unit.max_health))

		# Wait for animation to read sequentially.
		await get_tree().create_timer(gap_s).timeout

	# Re-pack surviving units after the fight sequence.
	for lv in legion_to_visu.values():
		if lv:
			lv.update_local_positions()
			lv.tween_units_to_local_positions()

	_show_combat_losses(hits, deaths, attacker, defender, attacker_world_pos, defender_world_pos)
	_hide_combat_hp_fx_later(legion_to_visu)

	_cleanup_dead_legion(from_coords)
	_cleanup_dead_legion(to_coords)

func _hide_combat_hp_fx_later(legion_to_visu: Dictionary) -> void:
	# Keep bars visible a bit after the fight, similar to the losses popup linger.
	await get_tree().create_timer(3.3).timeout
	for lv in legion_to_visu.values():
		if lv:
			lv.hide_all_combat_hp_fx()

func _show_combat_losses(
	hits: Array,
	deaths: Array,
	attacker: Legion,
	defender: Legion,
	attacker_world_pos: Vector2,
	defender_world_pos: Vector2
) -> void:
	if not combat_fx_layer:
		return

	var hp_lost_by_legion: Dictionary = {}
	for h in hits:
		var def_legion: Legion = h.get("defender_legion")
		var lost := int(round(float(h.get("hp_lost", 0.0))))
		if def_legion and lost > 0:
			hp_lost_by_legion[def_legion] = int(hp_lost_by_legion.get(def_legion, 0)) + lost

	var deaths_by_legion: Dictionary = {}
	for d in deaths:
		var l: Legion = d.get("legion")
		if l:
			deaths_by_legion[l] = int(deaths_by_legion.get(l, 0)) + 1

	_spawn_losses_popup(attacker_world_pos, int(deaths_by_legion.get(attacker, 0)), int(hp_lost_by_legion.get(attacker, 0)))
	_spawn_losses_popup(defender_world_pos, int(deaths_by_legion.get(defender, 0)), int(hp_lost_by_legion.get(defender, 0)))

func _spawn_losses_popup(world_pos: Vector2, deaths_count: int, hp_lost: int) -> void:
	if deaths_count <= 0 and hp_lost <= 0:
		return

	var cam := get_viewport().get_camera_2d()
	var canvas_xform := get_viewport().get_canvas_transform()
	var screen_pos := canvas_xform * world_pos
	if cam:
		# Camera2D can alter canvas transform; keep this as a fallback anchor if needed.
		screen_pos = canvas_xform * world_pos

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.position = screen_pos + Vector2(-40, -170)
	block.modulate = Color(1, 1, 1, 0)
	combat_fx_layer.add_child(block)

	var icon_size := Vector2(84, 84)
	var font_size := 46
	var outline_size := 10
	var outline_color := Color(0.0, 0.0, 0.0, 0.95)

	if hp_lost > 0:
		var hp_row := HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 10)
		block.add_child(hp_row)

		var heart := TextureRect.new()
		heart.custom_minimum_size = icon_size
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture = ICON_HP_LOST
		hp_row.add_child(heart)

		var hp_label := Label.new()
		hp_label.text = "%d" % hp_lost
		hp_label.add_theme_font_size_override("font_size", font_size)
		hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
		hp_label.add_theme_constant_override("outline_size", outline_size)
		hp_label.add_theme_color_override("outline_color", outline_color)
		hp_row.add_child(hp_label)

	if deaths_count > 0:
		var deaths_row := HBoxContainer.new()
		deaths_row.add_theme_constant_override("separation", 10)
		block.add_child(deaths_row)

		var skull := TextureRect.new()
		skull.custom_minimum_size = icon_size
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skull.texture = ICON_DEATHS
		deaths_row.add_child(skull)

		var deaths_label := Label.new()
		deaths_label.text = "%d" % deaths_count
		deaths_label.add_theme_font_size_override("font_size", font_size)
		deaths_label.add_theme_color_override("font_color", Color(1, 1, 1))
		deaths_label.add_theme_constant_override("outline_size", outline_size)
		deaths_label.add_theme_color_override("outline_color", outline_color)
		deaths_row.add_child(deaths_label)

	var tween := block.create_tween()
	# Fast fade-in, long slow ascent, fast fade-out late.
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(block, "modulate:a", 1.0, 0.22)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(block, "position", block.position + Vector2(0, -90), 3.0)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(block, "modulate:a", 0.0, 0.28)
	tween.tween_callback(block.queue_free)

func _cleanup_dead_legion(coords: Vector2i) -> void:
	var tile: Tile = grid_model.get(coords)
	var visu: TileVisu = grid_visu.get(coords)
	if not tile or not visu:
		return
	if tile.legion and tile.legion.units.size() > 0:
		return
	if tile.legion:
		legions.erase(tile.legion)
	tile.legion = null
	if visu.legion_visu:
		visu.legion_visu.queue_free()
	visu.legion_visu = null
