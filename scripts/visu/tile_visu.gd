class_name TileVisu
extends Node2D

const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")
var base_sprite: Sprite2D
var terrain_sprite: Sprite2D
var qr_label: Label

@export var color_movable: Color = Color.GREEN
@export var color_selected: Color = Color.YELLOW
@export var color_attackable: Color = Color.RED
@export var color_ranged_attackable: Color = Color(1.0, 0.55, 0.12)
@export var color_attack_choice: Color = Color(0.95, 0.35, 0.55)
@export var color_swappable: Color = Color(0.35, 0.65, 0.95)
@export var color_deployable: Color = Color(0.45, 0.82, 0.55)
@export var color_deployed: Color = Color(0.55, 0.75, 0.95)
@export var color_healable: Color = Color(0.25, 1.0, 0.35)
@export var color_teleportable: Color = Color(0.55, 0.35, 1.0)

var tile: Tile
var legion_visu: LegionVisu = null

var active_tween: Tween
var base_y: float

var _gameplay_state: String = ""
var _gameplay_lift: float = 0.0
var _hover_boost: bool = false
var _spent: bool = false

const COLOR_SPENT := Color(0.72, 0.72, 0.74, 1.0)

static var _warned_missing: Dictionary = {}

func init(p_tile: Tile) -> void:
	tile = p_tile
	# This can be called before the node enters the tree (e.g. when the parent is added deferred),
	# so we must not rely on @onready here.
	base_sprite = get_node("base_sprite")
	qr_label = get_node("QR_Label")
	terrain_sprite = base_sprite.get_child(0)
	var tdef = TerrainRules.get_def(tile.terrain_type)
	if tdef != null and tdef.texture != null:
		var tex: Texture2D = tdef.texture
		var fit: Vector3 = tdef.texture_fit
		if tile.variant > 0 and tile.variant - 1 < tdef.variants.size():
			tex = tdef.variants[tile.variant - 1]
			if tile.variant - 1 < tdef.variant_fit.size():
				fit = tdef.variant_fit[tile.variant - 1]
		terrain_sprite.texture = tex
		_apply_terrain_fit(fit)
		# Tint lives on self_modulate so spent/hover modulate still applies on top.
		terrain_sprite.self_modulate = tdef.tint
	else:
		# Definition or its art failed to load (usually: new art not imported yet; open the
		# editor or run `godot --headless --import`). Warn once and fall back to grass.
		if not _warned_missing.has(tile.terrain_type):
			_warned_missing[tile.terrain_type] = true
			push_warning("Terrain art for %s did not load (re-import assets?); drawing grass instead." % tile.terrain_type)
		var grass = TerrainRules.get_def("GRASS")
		if grass != null and grass.texture != null:
			terrain_sprite.texture = grass.texture
			_apply_terrain_fit(grass.texture_fit)
	base_sprite.texture = load("res://assets/tiles_sliced/tiles_bottom/base.png")
	base_y = base_sprite.position.y
	qr_label.text = "(%d,%d,%d)" % [tile.cube_q, tile.cube_r, tile.cube_s]

## Place art of any size on the hex like the 700x650 originals: scale around the
## original centre, then shift by (dx, dy) original pixels.
const _TERRAIN_POS := Vector2(924.9999, 520)
const _TERRAIN_OFFSET := Vector2(-931.2499, -512.805)

func _apply_terrain_fit(fit: Vector3) -> void:
	var s := maxf(0.01, fit.x)
	terrain_sprite.position = _TERRAIN_POS
	terrain_sprite.scale = Vector2(s, s)
	var centre := _TERRAIN_POS + _TERRAIN_OFFSET + Vector2(fit.y, fit.z)
	terrain_sprite.offset = (centre - _TERRAIN_POS) / s

func has_legion_visu() -> bool:
	return legion_visu != null

func _on_mouse_entered():
	EventBus.tile_hover_entered.emit(tile.coords)

func _on_mouse_exited():
	EventBus.tile_hover_exited.emit(tile.coords)

func _on_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.tile_right_clicked.emit(tile.coords)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.tile_clicked.emit(tile.coords)

func set_gameplay_overlay(state: String, lift: float) -> void:
	_gameplay_state = state
	_gameplay_lift = lift
	_apply_state()
	_sync_lift()

func set_hover_boost(enabled: bool) -> void:
	_hover_boost = enabled
	_sync_lift()

## Fog of war: darken a tile the viewing team can't see.
const COLOR_FOG := Color(0.34, 0.34, 0.44, 1.0)
var _fogged := false

func set_fogged(fogged: bool) -> void:
	if _fogged == fogged:
		return
	_fogged = fogged
	modulate = COLOR_FOG if fogged else Color.WHITE

func is_fogged() -> bool:
	return _fogged

func set_spent(spent: bool) -> void:
	if _spent == spent:
		_apply_state()
		return
	_spent = spent
	_apply_state()

func _sync_lift() -> void:
	var target := _gameplay_lift
	if _hover_boost and _gameplay_lift > 0.0:
		target = 6.0
	juice_go_to(target)

func juice_go_to(target: float) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if legion_visu and legion_visu.active_tween and legion_visu.active_tween.is_running():
		legion_visu.active_tween.kill()
	var time := 0.8
	active_tween = create_tween()
	active_tween.tween_property(base_sprite, "position:y", base_y - target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if legion_visu:
		legion_visu.current_offset = Vector2(0, -target)
		legion_visu.active_tween = create_tween()
		legion_visu.active_tween.tween_property(legion_visu.units, "position:y", -target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func update_state(state: String) -> void:
	set_gameplay_overlay(state, _gameplay_lift)

func _apply_state() -> void:
	if not base_sprite:
		return
	if _gameplay_state == "selected":
		base_sprite.self_modulate = color_selected
	elif _gameplay_state == "attackable":
		base_sprite.self_modulate = color_attackable
	elif _gameplay_state == "ranged_attackable":
		base_sprite.self_modulate = color_ranged_attackable
	elif _gameplay_state == "attack_choice":
		base_sprite.self_modulate = color_attack_choice
	elif _gameplay_state == "swappable":
		base_sprite.self_modulate = color_swappable
	elif _gameplay_state == "movable":
		base_sprite.self_modulate = color_movable
	elif _gameplay_state == "deployable":
		base_sprite.self_modulate = color_deployable
	elif _gameplay_state == "deployed":
		base_sprite.self_modulate = color_deployed
	elif _gameplay_state == "healable":
		base_sprite.self_modulate = color_healable
	elif _gameplay_state == "teleportable":
		base_sprite.self_modulate = color_teleportable
	elif _spent:
		base_sprite.self_modulate = COLOR_SPENT
	else:
		base_sprite.self_modulate = Color.WHITE
