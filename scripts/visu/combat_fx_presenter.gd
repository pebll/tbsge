class_name CombatFxPresenter
extends RefCounted

const ICON_DEATHS := preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_HP_LOST := preload("res://assets/icons/base_icons_sprites/damage.png")
const ICON_HEAL_REPORT := preload("res://assets/icons/base_icons_sprites/heart.png")
const ICON_SHIELD := preload("res://assets/icons/base_icons_sprites/shield.png")

const COLOR_SHIELD := Color(0.55, 0.88, 1.0)

const POPUP_LINGER := 3.3

var _host: Node
var _fx_layer: CanvasLayer
var _hp_fx_tail_epoch: int = 0

func _init(host: Node, fx_layer: CanvasLayer) -> void:
	_host = host
	_fx_layer = fx_layer

func show_combat_losses(
	hits: Array,
	deaths: Array,
	attacker: Legion,
	defender: Legion,
	attacker_world_pos: Vector2,
	defender_world_pos: Vector2
) -> void:
	if _fx_layer == null:
		return

	var hp_lost_by_legion: Dictionary = {}
	var shield_absorbed_by_legion: Dictionary = {}
	for h in hits:
		var def_legion: Legion = h.get("defender_legion")
		var lost := int(round(float(h.get("hp_lost", 0.0))))
		if def_legion and lost > 0:
			hp_lost_by_legion[def_legion] = int(hp_lost_by_legion.get(def_legion, 0)) + lost
		var absorbed := int(round(float(h.get("shield_absorbed", 0.0))))
		if def_legion and absorbed > 0:
			shield_absorbed_by_legion[def_legion] = (
				int(shield_absorbed_by_legion.get(def_legion, 0)) + absorbed
			)

	var deaths_by_legion: Dictionary = {}
	for d in deaths:
		var legion: Legion = d.get("legion")
		if legion:
			deaths_by_legion[legion] = int(deaths_by_legion.get(legion, 0)) + 1

	if attacker:
		spawn_losses_popup(
			attacker_world_pos,
			int(deaths_by_legion.get(attacker, 0)),
			int(hp_lost_by_legion.get(attacker, 0)),
			int(shield_absorbed_by_legion.get(attacker, 0))
		)
	if defender:
		spawn_losses_popup(
			defender_world_pos,
			int(deaths_by_legion.get(defender, 0)),
			int(hp_lost_by_legion.get(defender, 0)),
			int(shield_absorbed_by_legion.get(defender, 0))
		)

func spawn_losses_popup(
	world_pos: Vector2, deaths_count: int, hp_lost: int, shield_absorbed: int = 0
) -> void:
	if deaths_count <= 0 and hp_lost <= 0 and shield_absorbed <= 0:
		return
	var rows: Array = []
	if hp_lost > 0:
		rows.append({
			"icon": ICON_HP_LOST,
			"text": "%d" % hp_lost,
			"color": Color.WHITE,
			"tier": "primary",
		})
	if shield_absorbed > 0:
		rows.append({
			"icon": ICON_SHIELD,
			"text": "%d" % shield_absorbed,
			"color": COLOR_SHIELD,
			"tier": "primary",
		})
	if deaths_count > 0:
		rows.append({
			"icon": ICON_DEATHS,
			"text": "%d" % deaths_count,
			"color": Color.WHITE,
			"tier": "primary",
		})
	_spawn_floating_popup(world_pos, rows)

func spawn_heal_popup(world_pos: Vector2, healed_total: int) -> void:
	if healed_total <= 0:
		return
	_spawn_floating_popup(
		world_pos,
		[{"icon": ICON_HEAL_REPORT, "text": "+%d" % healed_total, "color": Color(0.55, 1.0, 0.65)}]
	)

func hide_hp_fx_later(legion_visus: Array) -> void:
	## Async cleanup — call via ActionFxTail.release(), not awaited by action playback.
	if _host == null or not _host.is_inside_tree():
		return
	_hp_fx_tail_epoch += 1
	var epoch := _hp_fx_tail_epoch
	var snapshot: Array = []
	for lv in legion_visus:
		if is_instance_valid(lv):
			snapshot.append(lv)
	await _host.get_tree().create_timer(POPUP_LINGER).timeout
	if epoch != _hp_fx_tail_epoch:
		return
	for lv in snapshot:
		if not is_instance_valid(lv):
			continue
		(lv as LegionVisu).hide_all_combat_hp_fx()

func dismiss_all() -> void:
	_hp_fx_tail_epoch += 1
	_clear_floating_popups()

func _clear_floating_popups() -> void:
	if _fx_layer == null:
		return
	for child in _fx_layer.get_children():
		child.queue_free()

func _spawn_floating_popup(world_pos: Vector2, rows: Array) -> void:
	if _fx_layer == null or _host == null or not _host.is_inside_tree():
		return

	var screen_pos := _host.get_viewport().get_canvas_transform() * world_pos
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.position = screen_pos + Vector2(-40, -170)
	block.modulate = Color(1, 1, 1, 0)
	_fx_layer.add_child(block)

	var icon_size_primary := Vector2(84, 84)
	var font_size_primary := 46
	var icon_size_secondary := Vector2(52, 52)
	var font_size_secondary := 30
	var outline_size := 10
	var outline_color := Color(0.0, 0.0, 0.0, 0.95)

	for row in rows:
		var tier := String(row.get("tier", "primary"))
		var is_secondary := tier == "secondary"
		var icon_size := icon_size_secondary if is_secondary else icon_size_primary
		var font_size := font_size_secondary if is_secondary else font_size_primary

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8 if is_secondary else 10)
		block.add_child(hbox)

		var icon := TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = row.get("icon")
		hbox.add_child(icon)

		var label := Label.new()
		label.text = String(row.get("text", ""))
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", row.get("color", Color.WHITE))
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("outline_color", outline_color)
		hbox.add_child(label)

	var tween := block.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(block, "modulate:a", 1.0, 0.22)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(block, "position", block.position + Vector2(0, -90), POPUP_LINGER)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(block, "modulate:a", 0.0, 0.28)
	tween.tween_callback(block.queue_free)
