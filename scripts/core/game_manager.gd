class_name GameManager
extends Node2D

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const TurnManagerRes = preload("res://scripts/core/turn_manager.gd")
const ActionResolverScript = preload("res://scripts/actions/action_resolver.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

@export var map_radius: int = 3
var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75
const UNITS = ["AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT"]
const TEAM_IDS: Array[String] = ["GREEN", "BLUE"]

@onready var grid_visu : Dictionary[Vector2i, TileVisu] = {}
@onready var grid_model : Dictionary[Vector2i, Tile] = {}
@onready var legions : Array[Legion] = []

var tilesContainer : Node
var ui : GameUI
var mapGenerator : MapGenerator
var tile_info_panel
var tile_info_layer: CanvasLayer
var combat_fx_layer: CanvasLayer
var turn_hud: TurnHud
var turn_manager: TurnManager
var input: GameInput

const ICON_DEATHS := preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_HP_LOST := preload("res://assets/icons/base_icons_sprites/heart.png")

## Combat pacing (seconds). Timers are used between hits — tween.finished is unreliable when tweens get killed/replaced.
const COMBAT_HIT_BEAT := 0.4
const COMBAT_DEATH_BEAT := 0.6
const COMBAT_REPOSITION_BEAT := 0.45

func _ready():
	input = GameInput.new(self)
	ui = GameUI.new(self)
	mapGenerator = MapGenerator.new(tile_size, tile_size_xy_ratio)
	# TODO: fix this when refactor mapgenerator
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	mapGenerator.generate_hex_map(map_radius, tilesContainer, self.grid_visu, self.grid_model)

	turn_manager = TurnManagerRes.new(TEAM_IDS)
	turn_manager.start_match(TEAM_IDS[0])
	_setup_tile_info_ui()
	_setup_combat_fx_ui()
	_setup_turn_hud()
	EventBus.legion_ap_changed.connect(_on_legion_ap_changed)

func _input(event: InputEvent) -> void:
	if input.is_locked():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		ui.cycle_legion_tab()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		ui.pass_current_legion()
		get_viewport().set_input_as_handled()

func can_act_legion(legion: Legion) -> bool:
	return legion != null and turn_manager.is_legion_active(legion) and legion.has_ap()

func can_select_legion_at(coords: Vector2i) -> bool:
	var tile: Tile = grid_model.get(coords)
	if not tile or not tile.has_legion():
		return false
	return can_act_legion(tile.legion)

func end_team_turn() -> void:
	ui.deselect()
	var next_team: String = turn_manager.end_team_turn(legions)
	if turn_hud:
		turn_hud.show_active_team(next_team)
	EventBus.turn_changed.emit(next_team)

func _notify_legion_ap_changed(legion: Legion) -> void:
	EventBus.legion_ap_changed.emit(legion)

func _on_legion_ap_changed(legion: Legion) -> void:
	if not tile_info_panel or not tile_info_panel.visible:
		return
	var tile: Tile = grid_model.get(legion.tile_coords)
	if tile and tile.has_legion():
		tile_info_panel.show_tile(tile)

func _setup_turn_hud() -> void:
	if not tile_info_layer:
		return
	turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	tile_info_layer.add_child(turn_hud)
	turn_hud.show_active_team(turn_manager.active_team_id)
	turn_hud.next_turn_pressed.connect(end_team_turn)

func _setup_tile_info_ui() -> void:
	tile_info_layer = CanvasLayer.new()
	tile_info_layer.name = "UI"
	add_child(tile_info_layer)

	tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	tile_info_layer.add_child(tile_info_panel)
	tile_info_panel.hide()

	var action_bar = preload("res://scenes/ui/battle_action_bar.tscn").instantiate()
	tile_info_layer.add_child(action_bar)
	ui.attach_action_bar(action_bar)

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
	var team_id: String = turn_manager.active_team_id
	var legion = Legion.new(UNITS[randi() % 8], randi() % 8 + 1, coords, team_id)
	legion.refresh_ap()
	var legionVisu = preload("res://scenes/legion.tscn").instantiate()
	# TODO: refactor this into own folder (like for the tiles)
	self.add_child(legionVisu)
	legions.append(legion)
	tile.legion = legion
	tile_visu.legion_visu = legionVisu
	legionVisu.init(legion)
	legionVisu.position = tile_visu.position
	_notify_legion_ap_changed(legion)
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

func move_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	var result := apply_battle_action("move", from_coords, to_coords)
	if not result.get("ok", false):
		return
	if "legion_moved" in result.get("events", []):
		var legion: Legion = result.get("payload", {}).get("legion")
		var tween := _animate_resolved_move(from_coords, to_coords)
		if legion:
			_notify_legion_ap_changed(legion)
		if tween:
			_finish_action_after_tweens([tween], func() -> void: pass)

func attack_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("melee_attack", from_coords, to_coords)

func swap_legions(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("move", from_coords, to_coords)

func apply_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> Dictionary:
	var cmd := {
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	if action_id == "melee_attack":
		cmd["rng_seed"] = randi()
	return ActionResolverScript.resolve(BattleStateScript.from_game_manager(self), cmd)

func use_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input.is_locked():
		return
	var result: Dictionary = apply_battle_action(action_id, from_coords, to_coords)
	if not result.get("ok", false):
		return

	input.begin_action()
	ui.clear_overlays()

	var events: Array = result.get("events", [])
	var payload: Dictionary = result.get("payload", {})
	var refresh_coords := from_coords
	var tweens: Array = []

	if "legion_moved" in events:
		tweens.append(_animate_resolved_move(from_coords, to_coords))
		refresh_coords = to_coords
		_notify_legion_ap_changed(payload.get("legion"))
	elif "legions_swapped" in events:
		tweens.append_array(_animate_resolved_swap(from_coords, to_coords))
		refresh_coords = to_coords
		var legion_a: Legion = grid_model.get(to_coords).legion
		var legion_b: Legion = grid_model.get(from_coords).legion
		_notify_legion_ap_changed(legion_a)
		_notify_legion_ap_changed(legion_b)
	elif "combat_resolved" in events:
		await _play_combat_visuals(from_coords, to_coords, payload.get("combat", {}))
		ui.deselect()
		input.end_action()
		return
	elif "legion_healed" in events:
		_notify_legion_ap_changed(payload.get("legion"))

	_finish_action_after_tweens(tweens, func() -> void:
		ui.refresh_after_action(refresh_coords)
		input.end_action()
	)

func _animate_resolved_move(from_coords: Vector2i, to_coords: Vector2i) -> Tween:
	var from_visu: TileVisu = grid_visu.get(from_coords)
	var to_visu: TileVisu = grid_visu.get(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu:
		return null
	var legion_visu: LegionVisu = from_visu.legion_visu
	from_visu.legion_visu = null
	to_visu.legion_visu = legion_visu
	return legion_visu.juice_move(to_visu.position)

func _animate_resolved_swap(from_coords: Vector2i, to_coords: Vector2i) -> Array:
	var from_visu: TileVisu = grid_visu.get(from_coords)
	var to_visu: TileVisu = grid_visu.get(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu or not to_visu.legion_visu:
		return []
	var visu_a: LegionVisu = from_visu.legion_visu
	var visu_b: LegionVisu = to_visu.legion_visu
	from_visu.legion_visu = visu_b
	to_visu.legion_visu = visu_a
	return [
		visu_a.juice_move(to_visu.position),
		visu_b.juice_move(from_visu.position),
	]

func _finish_action_after_tweens(tweens: Array, on_done: Callable) -> void:
	for tween in tweens:
		if tween != null and is_instance_valid(tween):
			await tween.finished
	if on_done.is_valid():
		on_done.call()

func _combat_beat(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _restart_legion_idle_animations(legion_to_visu: Dictionary) -> void:
	for lv in legion_to_visu.values():
		if lv and is_instance_valid(lv):
			lv.start_idle_animation()

func _play_combat_visuals(from_coords: Vector2i, to_coords: Vector2i, combat: Dictionary) -> void:
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu or not to_visu.legion_visu:
		return

	var attacker: Legion = from_visu.legion_visu.legion
	var defender: Legion = to_visu.legion_visu.legion
	if not attacker or not defender:
		return

	var hits: Array = combat.get("hits", [])
	var deaths: Array = combat.get("deaths", [])

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

		var hit_idx: int = h["hit_index"]
		var died_on_hit := false
		if deaths_by_hit.has(hit_idx):
			var d = deaths_by_hit[hit_idx]
			if d.get("legion") == def_legion and d.get("unit") == def_unit:
				died_on_hit = true
				def_visu.animate_unit_death(def_unit, dir)

		if not died_on_hit:
			def_visu.animate_unit_hitted(
				def_unit, dir, def_hp_before, def_hp_after, float(def_unit.max_health)
			)

		var beat := COMBAT_DEATH_BEAT if died_on_hit else COMBAT_HIT_BEAT
		await _combat_beat(beat)

	for lv in legion_to_visu.values():
		if lv:
			lv.update_local_positions()
			lv.tween_units_to_local_positions()
	await _combat_beat(COMBAT_REPOSITION_BEAT)
	_restart_legion_idle_animations(legion_to_visu)

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
