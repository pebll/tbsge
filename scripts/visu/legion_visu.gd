class_name LegionVisu
extends Node2D

var legion : Legion
var _unit_to_visu: Dictionary = {}

@onready var units: Node2D = $Units
var corpses: Node2D
@onready var idle_tween : Tween
@onready var active_tween : Tween
@onready var move_tween : Tween

var current_offset: Vector2 = Vector2(0, 0)
var _formation_seed: int = 0

func init(legion: Legion) -> void:
	self.legion = legion
	# position is set by GameManager from tile visual
	_unit_to_visu.clear()
	# Keep formation offsets stable across re-packs.
	_formation_seed = randi()
	if corpses == null:
		corpses = Node2D.new()
		corpses.name = "Corpses"
		# Keep dying units on same render layer as the formation.
		corpses.z_index = units.z_index
		add_child(corpses)
	for unit in self.legion.units:
		var unitVisu = preload("res://scenes/unit.tscn").instantiate()
		unitVisu.init(unit)
		units.add_child(unitVisu)
		_unit_to_visu[unit] = unitVisu
	update_local_positions()
	for unit in units.get_children():
		unit.update_sprite()
		unit.start_idle_animation()
		
func _stable_jitter(i: int, amount: float) -> Vector2:
	# Deterministic pseudo-random jitter in [-amount, amount].
	# Avoids formations "shuffling" every time we re-pack.
	var sx := sin(float(_formation_seed) + float(i) * 12.9898) * 43758.5453
	var sy := sin(float(_formation_seed) + float(i) * 78.233) * 12515.8731
	var rx := (fposmod(sx, 1.0) * 2.0 - 1.0) * amount
	var ry := (fposmod(sy, 1.0) * 2.0 - 1.0) * amount
	return Vector2(rx, ry)

func update_local_positions():
	var base_spacing = 30
	var randomness = 5 # pixels of random variation
	var positions = []
	var cols = 1
	if legion.unit_count == 4:
		cols = 2
	else:
		cols = ceil(sqrt(legion.unit_count * 1.5))  # slightly wider than tall

	for i in range(legion.unit_count):
		var row = i / int(cols)
		var col = i % int(cols)

		# Center the formation
		var x = (col - cols/2.0 + 0.5) * base_spacing
		var y = (row - ceil(legion.unit_count / cols) / 2.0 + 0.5) * base_spacing * 0.8

		var jitter := _stable_jitter(i, float(randomness))
		x += jitter.x
		y += jitter.y

		positions.append(Vector2(x, y))
		
	var children = units.get_children()
	for i in range(legion.unit_count):
		children[i].local_position = positions[i]

func refresh_unit_sprites() -> void:
	# Ensures unit visuals immediately reflect their local_position.
	for u in units.get_children():
		u.update_sprite()

func tween_units_to_local_positions() -> void:
	# Smoothly move each unit sprite to its `local_position` (no snapping).
	for u in units.get_children():
		u.juice_move(Vector2.ZERO)

func get_unit_count() -> int:
	return legion.unit_count

func update_direction(direction: Vector2):
	for unit in units.get_children():
		unit.update_direction(direction)

func start_idle_animation():
	for unit in units.get_children():
		unit.start_idle_animation()

func juice_move(target_pos: Vector2):
	var move_time = 0.4
	update_local_positions()
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for unit in units.get_children():
		unit.juice_move(target_pos)
		
func juice_attack(direction: Vector2):
	for unit in units.get_children():
		unit.juice_attack(direction)
	
func juice_hitted(direction: Vector2):
	for unit in units.get_children():
		unit.juice_hitted(direction)
		
func juice_squish():
	for unit in units.get_children():
		unit.juice_squish()

func juice_direct(direction: Vector2):
	for unit in units.get_children():
		unit.juice_direct()

func juice_direct_reset():
	for unit in units.get_children():
		unit.juice_direct_reset()

func get_unit_visu(unit: Unit) -> UnitVisu:
	return _unit_to_visu.get(unit)

func animate_unit_attack(unit: Unit, direction: Vector2) -> void:
	var uv: UnitVisu = get_unit_visu(unit)
	if not uv:
		return
	uv.update_direction(direction)
	uv.juice_attack(direction)

func animate_unit_hitted(unit: Unit, direction: Vector2, hp_before: float = -1.0, hp_after: float = -1.0, hp_max: float = -1.0) -> void:
	var uv: UnitVisu = get_unit_visu(unit)
	if not uv:
		return
	# Face the attacker while being hit.
	uv.update_direction(-direction)
	if hp_before >= 0.0 and hp_after >= 0.0 and hp_max > 0.0:
		uv.show_combat_hp_chip(hp_before, hp_after, hp_max)
	uv.juice_hitted(direction)

func animate_unit_death(unit: Unit, direction: Vector2) -> void:
	var uv: UnitVisu = _unit_to_visu.get(unit)
	if not uv:
		return

	# Hide instantly — the corpse flies away with the body, no fade.
	uv.hide_combat_hp_fx(true)

	# Remove from formation immediately so survivors can re-pack,
	# but keep the node alive long enough to play the death tween.
	_unit_to_visu.erase(unit)
	if corpses and uv.get_parent() == units:
		units.remove_child(uv)
		corpses.add_child(uv)
	update_local_positions()
	tween_units_to_local_positions()

	# Face attacker, but don't do the little direction "juice" nudge (it fights knockback).
	uv.set_facing(-direction)
	var t := uv.juice_die(direction)
	if t:
		await t.finished
	if is_instance_valid(uv):
		uv.queue_free()

func remove_unit(unit: Unit) -> void:
	var uv: UnitVisu = _unit_to_visu.get(unit)
	if uv:
		_unit_to_visu.erase(unit)
		uv.queue_free()
	update_local_positions()
	tween_units_to_local_positions()

func hide_all_combat_hp_fx() -> void:
	for uv in _unit_to_visu.values():
		if uv:
			uv.hide_combat_hp_fx()
