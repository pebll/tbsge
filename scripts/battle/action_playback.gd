class_name ActionPlayback
extends RefCounted

## Visual playback for battle actions. Each play_* method awaits only blocking
## animation (attacks, tweens, reposition). Non-blocking report popups and lingering
## HP FX go through ActionFxTail.release() at the end.

const ActionFxTailScript = preload("res://scripts/battle/action_fx_tail.gd")
const CombatFxPresenterScript = preload("res://scripts/visu/combat_fx_presenter.gd")

const COMBAT_HIT_BEAT := 0.4
const COMBAT_DEATH_BEAT := 0.6
const COMBAT_REPOSITION_BEAT := 0.45

var _host: Node
var _tile_visu_at: Callable
var _legion_visu_at: Callable
var _combat_fx: CombatFxPresenter
var _fx_tail: ActionFxTail

func _init(
	host: Node,
	tile_visu_fn: Callable,
	legion_visu_fn: Callable,
	fx_layer: CanvasLayer
) -> void:
	_host = host
	_tile_visu_at = tile_visu_fn
	_legion_visu_at = legion_visu_fn
	_combat_fx = CombatFxPresenterScript.new(host, fx_layer)
	_fx_tail = ActionFxTailScript.new(_combat_fx)

func get_combat_fx() -> CombatFxPresenter:
	return _combat_fx

func dismiss_fx_tail() -> void:
	_combat_fx.dismiss_all()

func play_combat(from_coords: Vector2i, to_coords: Vector2i, combat: Dictionary, options: Dictionary = {}) -> void:
	var from_visu: TileVisu = _tile_visu_at.call(from_coords)
	var to_visu: TileVisu = _tile_visu_at.call(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu or not to_visu.legion_visu:
		return

	var attacker: Legion = from_visu.legion_visu.legion
	var defender: Legion = to_visu.legion_visu.legion
	if not attacker or not defender:
		return

	if options.get("deselect_before", false) and options.has("deselect"):
		var deselect: Callable = options["deselect"]
		if deselect.is_valid():
			deselect.call()

	var attacker_world_pos: Vector2 = from_visu.legion_visu.global_position
	var defender_world_pos: Vector2 = to_visu.legion_visu.global_position
	var hits: Array = combat.get("hits", [])
	var deaths: Array = combat.get("deaths", [])

	var legion_to_visu := _build_legion_visu_map(attacker, defender, hits)
	var deaths_by_hit: Dictionary = {}
	for d in deaths:
		deaths_by_hit[d["hit_index"]] = d

	var a_visu: LegionVisu = legion_to_visu.get(attacker)
	var d_visu: LegionVisu = legion_to_visu.get(defender)
	if a_visu and d_visu:
		var face_dir: Vector2 = (d_visu.global_position - a_visu.global_position).normalized()
		a_visu.update_direction(face_dir)
		d_visu.update_direction(-face_dir)

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

		var direction: Vector2 = (def_visu.global_position - atk_visu.global_position).normalized()
		atk_visu.animate_unit_attack(atk_unit, direction)
		AudioManager.play_unit_hit(atk_unit.unit_type)

		var hit_idx: int = h["hit_index"]
		var died_on_hit := false
		if deaths_by_hit.has(hit_idx):
			var death_entry = deaths_by_hit[hit_idx]
			if death_entry.get("legion") == def_legion and death_entry.get("unit") == def_unit:
				died_on_hit = true
				AudioManager.play_unit_death(def_unit.unit_type)
				def_visu.animate_unit_death(def_unit, direction)

		if not died_on_hit:
			var shield_absorbed := float(h.get("shield_absorbed", 0.0))
			def_visu.animate_unit_hitted(
				def_unit,
				direction,
				def_hp_before,
				def_hp_after,
				float(def_unit.max_health),
				shield_absorbed
			)

		var beat := COMBAT_DEATH_BEAT if died_on_hit else COMBAT_HIT_BEAT
		await _beat(beat)

	for lv in legion_to_visu.values():
		if lv:
			lv.update_local_positions()
			lv.tween_units_to_local_positions()
	await _beat(COMBAT_REPOSITION_BEAT)
	_restart_idle_animations(legion_to_visu)
	for lv in legion_to_visu.values():
		if lv:
			lv.sync_all_unit_hp_bars()

	if options.has("on_ap_changed"):
		var on_ap_changed: Callable = options["on_ap_changed"]
		if on_ap_changed.is_valid() and attacker:
			on_ap_changed.call(attacker)

	_fx_tail.release(
		func() -> void:
			_combat_fx.show_combat_losses(
				hits, deaths, attacker, defender, attacker_world_pos, defender_world_pos
			),
		legion_to_visu.values()
	)

func play_heal(coords: Vector2i, payload: Dictionary, options: Dictionary = {}) -> void:
	var tile_visu: TileVisu = _tile_visu_at.call(coords)
	if not tile_visu or not tile_visu.legion_visu:
		return

	var legion_visu: LegionVisu = tile_visu.legion_visu
	var legion: Legion = payload.get("legion")
	var world_pos: Vector2 = legion_visu.global_position

	for entry in payload.get("unit_heals", []):
		var unit: Unit = entry.get("unit")
		if unit == null:
			continue
		legion_visu.animate_unit_healed(
			unit,
			float(entry.get("hp_before", 0)),
			float(entry.get("hp_after", 0)),
			float(unit.max_health)
		)
		AudioManager.play_heal_sfx()
		await _beat(COMBAT_HIT_BEAT)

	legion_visu.update_local_positions()
	legion_visu.tween_units_to_local_positions()
	await _beat(COMBAT_REPOSITION_BEAT)
	legion_visu.start_idle_animation()
	legion_visu.sync_all_unit_hp_bars()

	if options.has("on_ap_changed"):
		var on_ap_changed: Callable = options["on_ap_changed"]
		if on_ap_changed.is_valid() and legion:
			on_ap_changed.call(legion)

	if options.get("deselect_after", false) and options.has("deselect"):
		var deselect: Callable = options["deselect"]
		if deselect.is_valid():
			deselect.call()

	_fx_tail.release(
		func() -> void:
			_combat_fx.spawn_heal_popup(world_pos, int(payload.get("healed_total", 0))),
		[legion_visu]
	)

func _build_legion_visu_map(attacker: Legion, defender: Legion, hits: Array) -> Dictionary:
	var legion_to_visu: Dictionary = {}
	_register_legion_visu(legion_to_visu, attacker)
	_register_legion_visu(legion_to_visu, defender)
	for h in hits:
		_register_legion_visu(legion_to_visu, h.get("attacker_legion"))
		_register_legion_visu(legion_to_visu, h.get("defender_legion"))
	return legion_to_visu

func _register_legion_visu(legion_to_visu: Dictionary, legion: Legion) -> void:
	if legion == null or legion_to_visu.has(legion):
		return
	var visu: LegionVisu = _legion_visu_at.call(legion)
	if visu:
		legion_to_visu[legion] = visu

func _restart_idle_animations(legion_to_visu: Dictionary) -> void:
	for lv in legion_to_visu.values():
		if lv and is_instance_valid(lv):
			lv.start_idle_animation()

func _beat(seconds: float) -> void:
	if _host and _host.is_inside_tree():
		await _host.get_tree().create_timer(seconds).timeout
