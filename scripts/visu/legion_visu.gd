class_name LegionVisu
extends Node2D

const BANNER_TEXTURES := [
	preload("res://assets/banners_sprites/banners_0_0.png"),
	preload("res://assets/banners_sprites/banners_0_1.png"),
	preload("res://assets/banners_sprites/banners_0_2.png"),
]

var legion: Legion
var _unit_to_visu: Dictionary = {}

@onready var units: Node2D = $Units
@onready var banner: Sprite2D = $Banner
var corpses: Node2D
@onready var idle_tween: Tween
@onready var active_tween: Tween
@onready var move_tween: Tween

var current_offset: Vector2 = Vector2(0, 0)
var _formation_seed: int = 0

func init(p_legion: Legion, formation_seed: int = -1) -> void:
	legion = p_legion
	_unit_to_visu.clear()
	_formation_seed = formation_seed if formation_seed >= 0 else randi()
	if corpses == null:
		corpses = Node2D.new()
		corpses.name = "Corpses"
		corpses.z_index = units.z_index
		add_child(corpses)
	for unit in legion.units:
		var unit_visu: UnitVisu = preload("res://scenes/unit.tscn").instantiate()
		unit_visu.init(unit)
		units.add_child(unit_visu)
		_unit_to_visu[unit] = unit_visu
	_apply_unit_layout()
	for child in units.get_children():
		child.start_idle_animation()
	sync_all_unit_hp_bars()
	_apply_team_banner()

func sync_all_unit_hp_bars() -> void:
	for uv in _unit_to_visu.values():
		if uv:
			uv.sync_damage_hp_bar()

func _apply_team_banner() -> void:
	if not banner:
		return
	var team = TeamDefs.get_def(legion.team_id)
	if team == null:
		banner.visible = false
		return
	var idx := clampi(team.banner_variant - 1, 0, BANNER_TEXTURES.size() - 1)
	banner.texture = BANNER_TEXTURES[idx]
	banner.self_modulate = team.color
	banner.visible = true

func _stable_jitter(i: int, amount: float) -> Vector2:
	var sx := sin(float(_formation_seed) + float(i) * 12.9898) * 43758.5453
	var sy := sin(float(_formation_seed) + float(i) * 78.233) * 12515.8731
	var rx := (fposmod(sx, 1.0) * 2.0 - 1.0) * amount
	var ry := (fposmod(sy, 1.0) * 2.0 - 1.0) * amount
	return Vector2(rx, ry)

func set_unit_count(new_count: int) -> void:
	if legion == null:
		return
	if (
		legion.unit_count == new_count
		and legion.units.size() == new_count
		and units.get_child_count() == new_count
	):
		return
	var unit_type := legion.unit_type
	while legion.units.size() < new_count:
		var unit := Unit.new(unit_type)
		legion.units.append(unit)
		var unit_visu: UnitVisu = preload("res://scenes/unit.tscn").instantiate()
		unit_visu.init(unit)
		units.add_child(unit_visu)
		_unit_to_visu[unit] = unit_visu
	while legion.units.size() > new_count:
		var removed: Unit = legion.units.pop_back()
		var unit_visu: UnitVisu = _unit_to_visu.get(removed)
		if unit_visu:
			_unit_to_visu.erase(removed)
			units.remove_child(unit_visu)
			unit_visu.free()
	legion.unit_count = new_count
	_apply_unit_layout()
	for child in units.get_children():
		child.start_idle_animation()

func _apply_unit_layout() -> void:
	update_local_positions()
	for child in units.get_children():
		child.update_sprite()

func update_local_positions() -> void:
	var children := units.get_children()
	var count := children.size()
	if count == 0:
		return
	if count == 1:
		children[0].local_position = Vector2.ZERO
		return

	var base_spacing := 30
	var randomness := 5.0
	var positions: Array[Vector2] = []
	var cols := 2 if count == 4 else int(ceil(sqrt(count * 1.5)))
	var rows := int(ceil(float(count) / float(cols)))

	for i in range(count):
		var row := i / cols
		var col := i % cols
		var x: float = (float(col) - float(cols - 1) * 0.5) * float(base_spacing)
		var y: float = (float(row) - float(rows - 1) * 0.5) * float(base_spacing) * 0.8
		var jitter := _stable_jitter(i, randomness)
		positions.append(Vector2(x + jitter.x, y + jitter.y))

	for i in range(count):
		children[i].local_position = positions[i]

func refresh_unit_sprites() -> void:
	for u in units.get_children():
		u.update_sprite()

func tween_units_to_local_positions() -> Array[Tween]:
	var tweens: Array[Tween] = []
	for u in units.get_children():
		var t: Tween = u.juice_move(Vector2.ZERO)
		if t:
			tweens.append(t)
	return tweens

func get_unit_count() -> int:
	return legion.unit_count

func update_direction(direction: Vector2) -> void:
	for unit in units.get_children():
		unit.update_direction(direction)

func start_idle_animation() -> void:
	for unit in units.get_children():
		unit.start_idle_animation()

func juice_move(target_pos: Vector2) -> Tween:
	var move_time := 0.4
	update_local_positions()
	move_tween = create_tween()
	active_tween = move_tween
	move_tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for unit in units.get_children():
		unit.juice_move(target_pos)
	return move_tween

func juice_attack(direction: Vector2) -> void:
	for unit in units.get_children():
		unit.juice_attack(direction)

func juice_hitted(direction: Vector2) -> void:
	for unit in units.get_children():
		unit.juice_hitted(direction)

func juice_squish() -> void:
	for unit in units.get_children():
		unit.juice_squish()

func juice_direct(direction: Vector2) -> void:
	for unit in units.get_children():
		unit.juice_direct(direction)

func juice_direct_reset() -> void:
	for unit in units.get_children():
		unit.juice_direct_reset()

func get_unit_visu(unit: Unit) -> UnitVisu:
	return _unit_to_visu.get(unit)

func animate_unit_attack(unit: Unit, direction: Vector2) -> Tween:
	var uv: UnitVisu = get_unit_visu(unit)
	if not uv:
		return null
	uv.update_direction(direction)
	return uv.juice_attack(direction)

func animate_unit_hitted(unit: Unit, direction: Vector2, hp_before: float = -1.0, hp_after: float = -1.0, hp_max: float = -1.0) -> Tween:
	var uv: UnitVisu = get_unit_visu(unit)
	if not uv:
		return null
	uv.update_direction(-direction)
	if hp_before >= 0.0 and hp_after >= 0.0 and hp_max > 0.0:
		uv.show_combat_hp_chip(hp_before, hp_after, hp_max)
	else:
		uv.sync_damage_hp_bar()
	return uv.juice_hitted(direction)

func animate_unit_healed(unit: Unit, hp_before: float, hp_after: float, hp_max: float) -> Tween:
	var uv: UnitVisu = get_unit_visu(unit)
	if not uv:
		return null
	if hp_max > 0.0:
		uv.show_combat_hp_chip_heal(hp_before, hp_after, hp_max)
	return uv.juice_heal_jump()

func animate_unit_death(unit: Unit, direction: Vector2) -> Array[Tween]:
	var tweens: Array[Tween] = []
	var uv: UnitVisu = _unit_to_visu.get(unit)
	if not uv:
		return tweens

	uv.hide_combat_hp_fx(true)
	_unit_to_visu.erase(unit)
	if corpses and uv.get_parent() == units:
		units.remove_child(uv)
		corpses.add_child(uv)
	update_local_positions()
	tweens.append_array(tween_units_to_local_positions())

	uv.set_facing(-direction)
	var t := uv.juice_die(direction)
	if t:
		t.finished.connect(func() -> void:
			if is_instance_valid(uv):
				uv.queue_free()
		, CONNECT_ONE_SHOT)
		tweens.append(t)
	return tweens

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
	sync_all_unit_hp_bars()
