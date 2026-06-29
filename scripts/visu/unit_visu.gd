class_name UnitVisu
extends Node2D

var unit : Unit
var direction_front: bool = true
var direction_right: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var idle_tween : Tween
@onready var active_tween : Tween
@onready var move_tween : Tween

var current_offset: Vector2 = Vector2(0, 0)
var local_position: Vector2 = Vector2(0, 0)

var _hp_fx_root: Control
var _hp_bar_chip: ProgressBar
var _hp_bar_now: ProgressBar
var _hp_fx_tween: Tween
var _hp_fx_token: int = 0
var _hp_fx_hide_tween: Tween
var _damage_hp_root: Control
var _damage_hp_bar: ProgressBar

const FLASH_SHADER := preload("res://assets/shaders/sprite_white_flash.gdshader")
const ICON_SHIELD := preload("res://assets/icons/base_icons_sprites/shield.png")
const COLOR_SHIELD_FLASH := Color(0.45, 0.82, 1.0)
const COLOR_HEAL_FLASH := Color(0.35, 0.95, 0.45)
const BASE_SPRITE_SCALE := Vector2(0.2, 0.2)
## Most unit sheets are ~352x384; vermine sheets are ~690x752 and need auto-normalizing.
const REFERENCE_SPRITE_HEIGHT := 384.0
const HP_BAR_WIDTH_PX := 74.0
## Base downward offset from texture top in world units (tuned at image_size 1.0).
const HP_BAR_WORLD_DROP_BELOW_TOP := 9.0
## Extra world drop as image_size goes below 1.0 (smaller units sit lower on the body).
const HP_BAR_DROP_PER_MISSING_IMAGE_SIZE := 14.0
## Fixed world size for HP UI — independent of per-unit sprite scale and idle juice.
const HP_BAR_DISPLAY_SCALE := BASE_SPRITE_SCALE

var _flash_mat: ShaderMaterial
var _flash_tween: Tween

func init(unit: Unit):
	self.unit = unit
	
func _ready() -> void:
	_setup_flash_shader()
	_build_hp_fx()
	_build_persistent_hp_bar()
	sync_damage_hp_bar()
	set_process(true)

func _process(_delta: float) -> void:
	_sync_hp_bar_transform()

func _hp_bar_world_drop() -> float:
	var def := _get_unit_def()
	var image_scale := def.image_size if def else 1.0
	var small_unit_extra := maxf(0.0, 1.0 - image_scale) * HP_BAR_DROP_PER_MISSING_IMAGE_SIZE
	return HP_BAR_WORLD_DROP_BELOW_TOP + small_unit_extra

func _hp_bar_anchor_position() -> Vector2:
	# Texture top tracks art bounds; drop is world-space so small units aren't left floating high.
	if not sprite:
		return Vector2.ZERO
	var tex: Texture2D = sprite.texture
	if tex == null:
		return sprite.position
	var base_scale := _get_base_scale()
	var tex_size := tex.get_size()
	var bar_visual_width := HP_BAR_WIDTH_PX * HP_BAR_DISPLAY_SCALE.x
	var top_center_x := sprite.offset.x
	var texture_top_world_y := sprite.position.y + (sprite.offset.y - tex_size.y * 0.5) * base_scale.y
	return Vector2(
		sprite.position.x + top_center_x * base_scale.x - bar_visual_width * 0.5,
		texture_top_world_y + _hp_bar_world_drop()
	)

func _sync_hp_bar_transform() -> void:
	if not sprite:
		return
	var anchor := _hp_bar_anchor_position()
	if _hp_fx_root:
		_hp_fx_root.position = anchor
		_hp_fx_root.scale = HP_BAR_DISPLAY_SCALE
	if _damage_hp_root:
		_damage_hp_root.position = anchor
		_damage_hp_root.scale = HP_BAR_DISPLAY_SCALE

func _setup_flash_shader() -> void:
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("flash_amount", 0.0)
	sprite.material = _flash_mat

func _get_unit_def() -> UnitDefinition:
	if unit == null:
		return null
	if unit.definition:
		return unit.definition
	return UnitDefs.get_def(unit.unit_type)

func _get_texture_normalize_scale(texture: Texture2D) -> float:
	if texture == null:
		return 1.0
	var tex_height := float(texture.get_height())
	if tex_height <= 0.0:
		return 1.0
	return REFERENCE_SPRITE_HEIGHT / tex_height

func _get_base_scale() -> Vector2:
	var def := _get_unit_def()
	var image_scale := def.image_size if def else 1.0
	var texture: Texture2D = def.icon if def and def.icon else sprite.texture
	var tex_norm := _get_texture_normalize_scale(texture)
	return BASE_SPRITE_SCALE * image_scale * tex_norm

func _apply_base_sprite_scale() -> void:
	if sprite:
		sprite.scale = _get_base_scale()

func _play_white_flash(duration: float) -> void:
	_play_color_flash(Color.WHITE, duration)

func _play_color_flash(color: Color, duration: float) -> void:
	if not _flash_mat:
		return
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
	_flash_mat.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_flash_amount(amount: float) -> void:
	if _flash_mat:
		_flash_mat.set_shader_parameter("flash_amount", amount)

func set_facing(direction: Vector2) -> void:
	# Like update_direction(), but without the little "juice_direct" nudge.
	direction_right = direction.x >= 0
	direction_front = direction.y >= 0
	update_sprite()

func _build_hp_fx() -> void:
	_hp_fx_root = Control.new()
	_hp_fx_root.visible = false
	_hp_fx_root.modulate = Color(1, 1, 1, 0)
	# Needs to render above tiles/units; keep below CANVAS_ITEM_Z_MAX.
	_hp_fx_root.z_index = 3500
	add_child(_hp_fx_root)

	_hp_fx_root.custom_minimum_size = Vector2(74, 14)

	_hp_bar_chip = ProgressBar.new()
	_hp_bar_chip.custom_minimum_size = Vector2(74, 14)
	_hp_bar_chip.show_percentage = false
	_hp_bar_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hp_bar_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_fx_root.add_child(_hp_bar_chip)

	_hp_bar_now = ProgressBar.new()
	_hp_bar_now.custom_minimum_size = Vector2(74, 14)
	_hp_bar_now.show_percentage = false
	_hp_bar_now.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hp_bar_now.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar_now.position = Vector2.ZERO
	_hp_fx_root.add_child(_hp_bar_now)

	# Style: chip bar (white), current hp bar (red).
	var chip_bg := StyleBoxFlat.new()
	chip_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	chip_bg.border_color = Color(0, 0, 0, 1)
	chip_bg.border_width_left = 1
	chip_bg.border_width_right = 1
	chip_bg.border_width_top = 1
	chip_bg.border_width_bottom = 1
	chip_bg.corner_radius_top_left = 5
	chip_bg.corner_radius_top_right = 5
	chip_bg.corner_radius_bottom_left = 5
	chip_bg.corner_radius_bottom_right = 5
	_hp_bar_chip.add_theme_stylebox_override("background", chip_bg)

	var chip_fill := StyleBoxFlat.new()
	chip_fill.bg_color = Color(1, 1, 1, 0.95)
	chip_fill.corner_radius_top_left = 5
	chip_fill.corner_radius_top_right = 5
	chip_fill.corner_radius_bottom_left = 5
	chip_fill.corner_radius_bottom_right = 5
	_hp_bar_chip.add_theme_stylebox_override("fill", chip_fill)

	var now_bg := StyleBoxFlat.new()
	now_bg.bg_color = Color(0, 0, 0, 0) # transparent, chip bar provides border/bg
	_hp_bar_now.add_theme_stylebox_override("background", now_bg)

	var now_fill := StyleBoxFlat.new()
	now_fill.bg_color = Color(0.65, 0.12, 0.10, 1)
	now_fill.corner_radius_top_left = 5
	now_fill.corner_radius_top_right = 5
	now_fill.corner_radius_bottom_left = 5
	now_fill.corner_radius_bottom_right = 5
	_hp_bar_now.add_theme_stylebox_override("fill", now_fill)

func _apply_damage_chip_bar_style() -> void:
	var chip_fill := StyleBoxFlat.new()
	chip_fill.bg_color = Color(1, 1, 1, 0.95)
	chip_fill.corner_radius_top_left = 5
	chip_fill.corner_radius_top_right = 5
	chip_fill.corner_radius_bottom_left = 5
	chip_fill.corner_radius_bottom_right = 5
	_hp_bar_chip.add_theme_stylebox_override("fill", chip_fill)

func _apply_heal_chip_bar_style() -> void:
	var chip_fill := StyleBoxFlat.new()
	chip_fill.bg_color = Color(0.25, 0.95, 0.38, 1)
	chip_fill.corner_radius_top_left = 5
	chip_fill.corner_radius_top_right = 5
	chip_fill.corner_radius_bottom_left = 5
	chip_fill.corner_radius_bottom_right = 5
	_hp_bar_chip.add_theme_stylebox_override("fill", chip_fill)

func _apply_damage_now_bar_style() -> void:
	var now_fill := StyleBoxFlat.new()
	now_fill.bg_color = Color(0.65, 0.12, 0.10, 1)
	now_fill.corner_radius_top_left = 5
	now_fill.corner_radius_top_right = 5
	now_fill.corner_radius_bottom_left = 5
	now_fill.corner_radius_bottom_right = 5
	_hp_bar_now.add_theme_stylebox_override("fill", now_fill)

func _build_persistent_hp_bar() -> void:
	_damage_hp_root = Control.new()
	_damage_hp_root.visible = false
	_damage_hp_root.z_index = 3400
	add_child(_damage_hp_root)
	_damage_hp_root.custom_minimum_size = Vector2(74, 10)

	_damage_hp_bar = ProgressBar.new()
	_damage_hp_bar.custom_minimum_size = Vector2(74, 10)
	_damage_hp_bar.show_percentage = false
	_damage_hp_root.add_child(_damage_hp_bar)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg.border_color = Color(0, 0, 0, 1)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	_damage_hp_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.18, 0.14, 1)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	_damage_hp_bar.add_theme_stylebox_override("fill", fill)

func sync_damage_hp_bar() -> void:
	if unit == null or _damage_hp_bar == null or _damage_hp_root == null:
		return
	var max_v := maxf(1.0, float(unit.max_health))
	var current := clampf(float(unit.current_health), 0.0, max_v)
	if current >= max_v:
		_damage_hp_root.visible = false
		return
	_damage_hp_root.visible = true
	_damage_hp_bar.min_value = 0.0
	_damage_hp_bar.max_value = max_v
	_damage_hp_bar.value = current

func show_combat_hp_chip(hp_before: float, hp_after: float, hp_max: float) -> void:
	if not _hp_fx_root or not _hp_bar_chip or not _hp_bar_now:
		return
	if _damage_hp_root:
		_damage_hp_root.visible = false

	_hp_fx_token += 1
	if _hp_fx_tween and _hp_fx_tween.is_running():
		_hp_fx_tween.kill()
	if _hp_fx_hide_tween and _hp_fx_hide_tween.is_running():
		_hp_fx_hide_tween.kill()

	var max_v := maxf(1.0, hp_max)
	_hp_bar_chip.min_value = 0
	_hp_bar_chip.max_value = max_v
	_hp_bar_now.min_value = 0
	_hp_bar_now.max_value = max_v
	_apply_damage_now_bar_style()
	_apply_damage_chip_bar_style()

	_hp_fx_root.visible = true
	_hp_fx_root.modulate = Color(1, 1, 1, 0)

	# Front bar: drop quickly to the new HP.
	_hp_bar_now.value = clampf(hp_before, 0.0, max_v)
	_hp_bar_chip.value = clampf(hp_before, 0.0, max_v)

	_hp_fx_tween = create_tween()
	_hp_fx_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hp_fx_tween.tween_property(_hp_fx_root, "modulate:a", 1.0, 0.12)
	_hp_fx_tween.tween_property(_hp_bar_now, "value", clampf(hp_after, 0.0, max_v), 0.12)
	# Chip bar lags behind, then eases down.
	_hp_fx_tween.tween_interval(0.22)
	_hp_fx_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_fx_tween.tween_property(_hp_bar_chip, "value", clampf(hp_after, 0.0, max_v), 0.65)
	_hp_fx_tween.tween_callback(sync_damage_hp_bar)

func show_combat_hp_chip_heal(hp_before: float, hp_after: float, hp_max: float) -> void:
	if not _hp_fx_root or not _hp_bar_chip or not _hp_bar_now:
		return
	if _damage_hp_root:
		_damage_hp_root.visible = false

	_hp_fx_token += 1
	if _hp_fx_tween and _hp_fx_tween.is_running():
		_hp_fx_tween.kill()
	if _hp_fx_hide_tween and _hp_fx_hide_tween.is_running():
		_hp_fx_hide_tween.kill()

	var max_v := maxf(1.0, hp_max)
	_hp_bar_chip.min_value = 0
	_hp_bar_chip.max_value = max_v
	_hp_bar_now.min_value = 0
	_hp_bar_now.max_value = max_v
	_apply_damage_now_bar_style()
	_apply_heal_chip_bar_style()

	_hp_fx_root.visible = true
	_hp_fx_root.modulate = Color(1, 1, 1, 0)

	# Mirror of damage: green chip rises first, red current HP lags behind.
	_hp_bar_now.value = clampf(hp_before, 0.0, max_v)
	_hp_bar_chip.value = clampf(hp_before, 0.0, max_v)

	_hp_fx_tween = create_tween()
	_hp_fx_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hp_fx_tween.tween_property(_hp_fx_root, "modulate:a", 1.0, 0.12)
	_hp_fx_tween.tween_property(_hp_bar_chip, "value", clampf(hp_after, 0.0, max_v), 0.12)
	_hp_fx_tween.tween_interval(0.22)
	_hp_fx_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_fx_tween.tween_property(_hp_bar_now, "value", clampf(hp_after, 0.0, max_v), 0.65)
	_hp_fx_tween.tween_callback(sync_damage_hp_bar)

func hide_combat_hp_fx(instant: bool = false) -> void:
	if not _hp_fx_root:
		return
	if _hp_fx_tween and _hp_fx_tween.is_running():
		_hp_fx_tween.kill()
	if _hp_fx_hide_tween and _hp_fx_hide_tween.is_running():
		_hp_fx_hide_tween.kill()

	if instant:
		_hp_fx_root.modulate.a = 0.0
		_hp_fx_root.visible = false
		sync_damage_hp_bar()
		return

	_hp_fx_hide_tween = create_tween()
	_hp_fx_hide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hp_fx_hide_tween.tween_property(_hp_fx_root, "modulate:a", 0.0, 0.22)
	_hp_fx_hide_tween.tween_callback(func ():
		if _hp_fx_root:
			_hp_fx_root.visible = false
		sync_damage_hp_bar()
	)

func update_direction(direction: Vector2):
	direction_right = direction.x >= 0
	direction_front = direction.y >= 0
	juice_direct(direction)
	update_sprite()
	
func update_sprite():
	var new_texture: Texture2D = null
	if unit and unit.definition:
		new_texture = unit.definition.icon
	if new_texture == null:
		push_warning("UnitVisu: no icon for unit type '%s'" % (unit.unit_type if unit else ""))
	var new_flip_h = !direction_right
	sprite.texture = new_texture
	sprite.flip_h = new_flip_h
	sprite.position = local_position
	_apply_base_sprite_scale()

func start_idle_animation() -> void:
	if idle_tween and idle_tween.is_running():
		idle_tween.kill()
	var base_scale := _get_base_scale()
	sprite.scale = base_scale
	var stretch_percentage := 0.02
	var scale_a := Vector2(
		base_scale.x * (1.0 - stretch_percentage),
		base_scale.y * (1.0 + stretch_percentage)
	)
	var scale_b := Vector2(
		base_scale.x * (1.0 + stretch_percentage),
		base_scale.y * (1.0 - stretch_percentage)
	)
	var loop_time := 1.0
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(sprite, "scale", scale_a, loop_time)
	idle_tween.tween_property(sprite, "scale", scale_b, loop_time)

func juice_move(_target_pos: Vector2) -> Tween:
	var move_time = 0.4
	move_tween = create_tween()
	active_tween = create_tween()
	move_tween.tween_property(sprite, "position", local_position, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "rotation", 0, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return move_tween

func juice_attack(direction: Vector2) -> Tween:
	_stop_motion_tweens()
	var target_pos = direction * 30
	var target_rot = 0.3 * direction.x
	var attack_time = 0.2
	active_tween = create_tween()
	active_tween.tween_property(sprite, "position", current_offset + target_pos + local_position, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "position", current_offset + local_position, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", 0, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_callback(start_idle_animation)
	return active_tween

func _stop_motion_tweens() -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if idle_tween and idle_tween.is_running():
		idle_tween.kill()
	if move_tween and move_tween.is_running():
		move_tween.kill()

func juice_heal_jump() -> Tween:
	_stop_motion_tweens()
	_play_color_flash(COLOR_HEAL_FLASH, 0.5)

	var start_pos := sprite.position
	var jump_up := start_pos + Vector2(0, -16)
	var base_scale := _get_base_scale()
	var stretch_rise := Vector2(base_scale.x * 0.9, base_scale.y * 1.14)
	var squash_land := Vector2(base_scale.x * 1.16, base_scale.y * 0.84)
	var stretch_rebound := Vector2(base_scale.x * 0.94, base_scale.y * 1.08)

	active_tween = create_tween()
	active_tween.tween_property(sprite, "position", jump_up, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "scale", stretch_rise, 0.11).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "position", start_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(sprite, "scale", squash_land, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "scale", stretch_rebound, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "scale", base_scale, 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_callback(start_idle_animation)
	return active_tween

func juice_hitted(_direction: Vector2, shield_absorbed: float = 0.0) -> Tween:
	_stop_motion_tweens()

	if shield_absorbed > 0.0:
		_play_color_flash(COLOR_SHIELD_FLASH, 0.55)
		_spawn_shield_hit_icon()
	else:
		_play_white_flash(0.55)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var base_scale := _get_base_scale()
	var squish_angle := rng.randf_range(0.0, TAU)
	var fat := rng.randf_range(1.35, 1.65)
	var thin := rng.randf_range(0.55, 0.72)
	var squish_scale := Vector2(base_scale.x * fat, base_scale.y * thin)

	active_tween = create_tween()
	active_tween.tween_property(sprite, "rotation", squish_angle, 0.05)
	active_tween.parallel().tween_property(sprite, "scale", squish_scale, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "scale", base_scale, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_callback(start_idle_animation)
	return active_tween

func _spawn_shield_hit_icon() -> void:
	var icon := TextureRect.new()
	icon.texture = ICON_SHIELD
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(0.55, 0.88, 1.0, 0.0)
	icon.z_index = 3600
	add_child(icon)
	var start_pos := _hp_bar_anchor_position() + Vector2(18, -8)
	var jump_up := start_pos + Vector2(0, -26)
	icon.position = start_pos
	icon.scale = Vector2(0.65, 0.65)
	icon.pivot_offset = icon.custom_minimum_size * 0.5

	var tween := icon.create_tween()
	tween.tween_property(icon, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(icon, "position", jump_up, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position", start_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(icon.queue_free)

func juice_die(direction: Vector2) -> Tween:
	if idle_tween and idle_tween.is_running():
		idle_tween.kill()
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if move_tween and move_tween.is_running():
		move_tween.kill()
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()

	# Death should replace hit animation, but still flashes white.
	_play_white_flash(0.45)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var base_pos: Vector2 = sprite.position
	var base_scale := _get_base_scale()
	# Fly farther away from the impact.
	var knock_a := dir * rng.randf_range(34.0, 48.0) + Vector2(0, rng.randf_range(8.0, 14.0))
	var knock_b := knock_a + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(22.0, 36.0))

	# More inertia: big initial spin + damped wobble after.
	# Spin direction should oppose the impact direction for readability.
	var impact_sign := 1.0 if dir.x >= 0.0 else -1.0
	var spin_a := -impact_sign * rng.randf_range(2.2, 3.4)
	if rng.randf() < 0.25:
		spin_a *= -1.0 # occasional variation
	var spin_b := spin_a + (-impact_sign * rng.randf_range(0.9, 1.6))
	var spin_c := spin_b * 0.55
	var spin_d := spin_c * 0.45

	# ~50% height squish, widened to read as impact flatten.
	var mega_squish := Vector2(
		base_scale.x * rng.randf_range(1.35, 1.55),
		base_scale.y * rng.randf_range(0.45, 0.55)
	)
	# Keep the squish; don't "reset" scale at the end.

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "position", base_pos + knock_a, 0.16)
	active_tween.parallel().tween_property(sprite, "rotation", spin_a, 0.22)
	active_tween.parallel().tween_property(sprite, "scale", mega_squish, 0.14)

	# Main fall / tumble — fade starts here (not at the end).
	active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_property(sprite, "position", base_pos + knock_b, 0.36)
	active_tween.parallel().tween_property(sprite, "rotation", spin_b, 0.36)
	active_tween.parallel().tween_property(
		sprite, "scale", mega_squish * Vector2(rng.randf_range(0.85, 1.05), rng.randf_range(0.9, 1.15)), 0.28
	)
	active_tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.34)

	# Short ragdoll wobble while already fading out.
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "rotation", spin_c, 0.14)
	active_tween.parallel().tween_property(
		sprite, "position", base_pos + knock_b + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(2.0, 6.0)), 0.14
	)
	active_tween.parallel().tween_property(sprite, "rotation", spin_d, 0.1)

	return active_tween

func juice_squish():
	if active_tween and active_tween.is_running():
		return
	active_tween = create_tween()
	var anim_time := 0.1
	var scale_factor := 1.03
	var base_scale := _get_base_scale()
	var target_scale := Vector2(base_scale.x / scale_factor, base_scale.y * scale_factor)
	active_tween.tween_property(sprite, "scale", target_scale, anim_time / 2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "scale", base_scale, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

func juice_direct(direction: Vector2):
	var target_pos = -direction * 2
	var target_rot = -direction.x * 0.15
	if not direction_front:
		target_rot *= 1.2
	var attack_time = 0.2
	move_tween = create_tween()
	move_tween.tween_property(sprite, "position", current_offset + target_pos + local_position, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func juice_direct_reset():
	var target_pos = Vector2.ZERO
	var target_rot = 0
	var attack_time = 0.2
	move_tween = create_tween()
	move_tween.tween_property(sprite, "position", current_offset + target_pos + local_position, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
