class_name LegionVisu
extends Node2D

var legion : Legion

@onready var units: Node2D = $Units
@onready var idle_tween : Tween
@onready var active_tween : Tween
@onready var move_tween : Tween

var current_offset: Vector2 = Vector2(0, 0)

func init(legion: Legion) -> void:
	self.legion = legion
	position = legion.tile.position
	for unit in self.legion.units:
		var unitVisu = preload("res://scenes/unit.tscn").instantiate()
		unitVisu.init(unit)
		units.add_child(unitVisu)
	update_local_positions()
	for unit in units.get_children():
		unit.update_sprite()
		unit.start_idle_animation()
		
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

		  # Add small random offset
		x += randf_range(-randomness, randomness)
		y += randf_range(-randomness, randomness)

		positions.append(Vector2(x, y))
		
	var children = units.get_children()
	for i in range(legion.unit_count):
		children[i].local_position = positions[i]

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
