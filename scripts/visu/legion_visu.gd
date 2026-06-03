class_name LegionVisu
extends Node2D

const BANNER_TEXTURES := [
	preload("res://assets/banners_sprites/banners_0_0.png"),
	preload("res://assets/banners_sprites/banners_0_1.png"),
	preload("res://assets/banners_sprites/banners_0_2.png"),
]

var legion : Legion
var _unit_to_visu: Dictionary = {}

@onready var units: Node2D = $Units
@onready var banner: Sprite2D = $Banner
var corpses: Node2D
@onready var idle_tween : Tween
@onready var active_tween : Tween
@onready var move_tween : Tween

var current_offset: Vector2 = Vector2(0, 0)
var _formation_seed: int = 0

var _banner_rest_pos: Vector2 = Vector2.ZERO
var _banner_base_scale: Vector2 = Vector2.ONE
var _banner_idle_tween: Tween
var _banner_active_tween: Tween
var _banner_move_tween: Tween

const BANNER_BOB_PX := 2.5

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
	_apply_team_banner()

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
	_banner_rest_pos = banner.position
	_banner_base_scale = banner.scale
	banner.rotation = 0.0
	_start_banner_idle_animation()

func _reset_banner_transform() -> void:
	if not banner:
		return
	banner.position = _banner_rest_pos
	banner.rotation = 0.0
	banner.scale = _banner_base_scale

func _kill_banner_idle_tween() -> void:
	if _banner_idle_tween and _banner_idle_tween.is_running():
		_banner_idle_tween.kill()

func _kill_banner_action_tweens() -> void:
	if _banner_active_tween and _banner_active_tween.is_running():
		_banner_active_tween.kill()
	if _banner_move_tween and _banner_move_tween.is_running():
		_banner_move_tween.kill()

func _kill_banner_tweens() -> void:
	_kill_banner_idle_tween()
	_kill_banner_action_tweens()

func _start_banner_idle_animation() -> void:
	if not banner or not banner.visible:
		return
	_kill_banner_action_tweens()
	if _banner_idle_tween and _banner_idle_tween.is_running():
		return
	banner.rotation = 0.0
	banner.scale = _banner_base_scale
	var rest := _banner_rest_pos
	var bob_up := rest + Vector2(0, -BANNER_BOB_PX)
	banner.position = rest
	var loop_time := 1.2
	_banner_idle_tween = create_tween().set_loops()
	_banner_idle_tween.tween_property(banner, "position", bob_up, loop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_banner_idle_tween.tween_property(banner, "position", rest, loop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _banner_move_tilt(move_dir: Vector2) -> float:
	var dir := move_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	else:
		dir = dir.normalized()
	# Small tilt opposite travel; rotates around sprite offset (pole anchor).
	return clampf(-dir.x * 0.04 - dir.y * 0.015, -0.05, 0.05)

func _banner_juice_move(move_dir: Vector2, move_time: float) -> void:
	if not banner or not banner.visible:
		return
	_kill_banner_idle_tween()
	_kill_banner_action_tweens()
	banner.position = _banner_rest_pos
	banner.rotation = 0.0
	banner.scale = _banner_base_scale
	var tilt: float = _banner_move_tilt(move_dir)
	var lag_delay := 0.16
	var catch_up_time := move_time * 2.1

	_banner_move_tween = create_tween()
	_banner_move_tween.tween_property(banner, "rotation", tilt, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_banner_move_tween.tween_property(banner, "rotation", 0.0, catch_up_time).set_delay(lag_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_banner_move_tween.tween_callback(_start_banner_idle_animation)

func _start_banner_vanish_tween() -> Tween:
	if not banner or not banner.visible:
		return null
	_kill_banner_tweens()
	_reset_banner_transform()
	var base_scale := _banner_base_scale
	var tint: Color = banner.self_modulate
	_banner_active_tween = create_tween()
	_banner_active_tween.tween_property(banner, "rotation", 0.28, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_banner_active_tween.parallel().tween_property(banner, "scale", base_scale * 1.12, 0.08)
	_banner_active_tween.tween_property(banner, "scale", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_banner_active_tween.parallel().tween_method(
		func(a: float) -> void:
			banner.self_modulate = Color(tint.r, tint.g, tint.b, a),
		tint.a,
		0.0,
		0.42
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_banner_active_tween.parallel().tween_property(banner, "rotation", 0.55, 0.42)
	_banner_active_tween.tween_callback(func () -> void:
		if banner:
			banner.visible = false
	)
	return _banner_active_tween

func animate_banner_vanish() -> void:
	var t := _start_banner_vanish_tween()
	if t:
		await t.finished
	elif banner:
		banner.visible = false

func _await_tweens_parallel(tweens: Array) -> void:
	var pending := 0
	for tw in tweens:
		if tw == null:
			continue
		pending += 1
		tw.finished.connect(func () -> void: pending -= 1, CONNECT_ONE_SHOT)
	if pending == 0:
		return
	while pending > 0:
		await get_tree().process_frame

func _stable_jitter(i: int, amount: float) -> Vector2:
	# Deterministic pseudo-random jitter in [-amount, amount].
	# Avoids formations "shuffling" every time we re-pack.
	var sx := sin(float(_formation_seed) + float(i) * 12.9898) * 43758.5453
	var sy := sin(float(_formation_seed) + float(i) * 78.233) * 12515.8731
	var rx := (fposmod(sx, 1.0) * 2.0 - 1.0) * amount
	var ry := (fposmod(sy, 1.0) * 2.0 - 1.0) * amount
	return Vector2(rx, ry)

func update_local_positions():
	var children := units.get_children()
	var count := children.size()
	if count == 0:
		return
	if count == 1:
		children[0].local_position = Vector2.ZERO
		return

	var base_spacing = 30
	var randomness = 5 # pixels of random variation
	var positions: Array[Vector2] = []
	var cols := 1
	if count == 4:
		cols = 2
	else:
		cols = int(ceil(sqrt(count * 1.5)))  # slightly wider than tall

	var rows := int(ceil(float(count) / float(cols)))

	for i in range(count):
		var row := i / cols
		var col := i % cols

		# Center the formation on the legion origin
		var x: float = (float(col) - float(cols - 1) * 0.5) * float(base_spacing)
		var y: float = (float(row) - float(rows - 1) * 0.5) * float(base_spacing) * 0.8

		var jitter := _stable_jitter(i, float(randomness))
		positions.append(Vector2(x + jitter.x, y + jitter.y))

	for i in range(count):
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
	_start_banner_idle_animation()

func juice_move(target_pos: Vector2):
	var move_time = 0.4
	var move_dir := target_pos - position
	update_local_positions()
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for unit in units.get_children():
		unit.juice_move(target_pos)
	_banner_juice_move(move_dir, move_time)
		
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
		unit.juice_direct(direction)

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

	uv.hide_combat_hp_fx(true)

	# Keep the corpse at its world spot while survivors re-pack underneath.
	var death_global_pos := uv.global_position
	_unit_to_visu.erase(unit)
	if corpses and uv.get_parent() == units:
		uv.reparent(corpses, true)
	uv.global_position = death_global_pos

	update_local_positions()
	tween_units_to_local_positions()

	uv.set_facing(-direction)
	var death_tween := uv.juice_die(direction)
	var parallel_tweens: Array = []
	if death_tween:
		parallel_tweens.append(death_tween)
	if legion.units.is_empty():
		var banner_tween := _start_banner_vanish_tween()
		if banner_tween:
			parallel_tweens.append(banner_tween)
	await _await_tweens_parallel(parallel_tweens)
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
