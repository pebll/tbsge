class_name MinigameRoot
extends Node2D

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CONFIG_PATH := "res://data/minigame/duel_r3.tres"

const COMBAT_HIT_BEAT := 0.4
const COMBAT_DEATH_BEAT := 0.6
const COMBAT_REPOSITION_BEAT := 0.45

@export var config_path: String = CONFIG_PATH

var session: MinigameSession
var presenter: MinigamePresenter
var battle_ui: MinigameBattleUI
var input_locked: bool = false

var _ui_layer: CanvasLayer
var _draft_panel: MinigameDraftPanel
var _turn_hud: TurnHud
var _pass_overlay: PanelContainer
var _status_label: Label
var _selected_deploy_coords: Vector2i = Vector2i(2147483646, 2147483646)
var _viewing_team: String = "GREEN"

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	var config: MinigameConfig = load(config_path)
	if config == null:
		push_error("Failed to load minigame config: %s" % config_path)
		return
	session = MinigameSession.new(config)
	presenter = $MinigamePresenter
	battle_ui = MinigameBattleUI.new(self)
	_setup_ui()
	presenter.build_map(session)
	_viewing_team = session.config.team_ids[0]
	_refresh_draft_view()
	EventBus.tile_clicked.connect(_on_draft_tile_clicked)

func _input(event: InputEvent) -> void:
	if input_locked:
		return
	if session.phase != MinigameSession.Phase.BATTLE:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		battle_ui.cycle_legion_tab()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		battle_ui.pass_current_legion()
		get_viewport().set_input_as_handled()

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)

	_draft_panel = preload("res://scenes/ui/minigame_draft_panel.tscn").instantiate()
	_ui_layer.add_child(_draft_panel)
	_draft_panel.ready_pressed.connect(_on_draft_ready)
	_draft_panel.clear_slot_pressed.connect(_on_draft_clear_slot)

	_turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	_ui_layer.add_child(_turn_hud)
	_turn_hud.hide()
	_turn_hud.next_turn_pressed.connect(_on_end_turn)

	_pass_overlay = PanelContainer.new()
	_pass_overlay.visible = false
	_pass_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pass_vbox := VBoxContainer.new()
	pass_vbox.set_anchors_preset(Control.PRESET_CENTER)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 36)
	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.pressed.connect(_on_pass_continue)
	pass_vbox.add_child(_status_label)
	pass_vbox.add_child(continue_btn)
	_pass_overlay.add_child(pass_vbox)
	_ui_layer.add_child(_pass_overlay)

func _refresh_draft_view() -> void:
	var view := session.get_view_state(_viewing_team)
	var draft: Dictionary = view.get("draft", {})
	_draft_panel.show_for_team(_viewing_team, draft)
	var slots: Array = view.get("deploy_slots", [])
	presenter.highlight_deploy_slots(slots, Color(0.85, 0.95, 0.85, 1.0))
	_mark_existing_placements(draft)

func _mark_existing_placements(draft: Dictionary) -> void:
	for p in draft.get("placements", []):
		var coords: Vector2i = p.get("coords", Vector2i.ZERO)
		var visu: TileVisu = presenter.tile_visu_at(coords)
		if visu:
			visu.modulate = Color(0.75, 0.9, 0.75)

func _on_draft_tile_clicked(coords: Vector2i) -> void:
	if session.phase != MinigameSession.Phase.DRAFT:
		return
	if input_locked or _pass_overlay.visible:
		return
	if session.active_draft_team != _viewing_team:
		return
	var slots: Array = session.get_deploy_slots(_viewing_team)
	if coords not in slots:
		return
	_selected_deploy_coords = coords
	var result := session.apply({
		"type": "draft_set_legion",
		"team": _viewing_team,
		"coords": coords,
		"unit_type": _draft_panel.get_selected_type(),
		"unit_count": _draft_panel.get_selected_count(),
	})
	if not result["ok"]:
		_status_label.text = result["error"]
	else:
		_refresh_draft_view()

func _on_draft_clear_slot() -> void:
	if _selected_deploy_coords == Vector2i(2147483646, 2147483646):
		return
	var result := session.apply({
		"type": "draft_clear_slot",
		"team": _viewing_team,
		"coords": _selected_deploy_coords,
	})
	if result["ok"]:
		_refresh_draft_view()

func _on_draft_ready() -> void:
	var result := session.apply({"type": "draft_ready", "team": _viewing_team})
	if not result["ok"]:
		_status_label.text = result["error"]
		return
	if session.phase == MinigameSession.Phase.BATTLE:
		_begin_battle()
		return
	_show_pass_overlay()

func _show_pass_overlay() -> void:
	var next_team := session.active_draft_team
	var team_res: Resource = TeamDefs.get_def(next_team)
	var name := next_team
	if team_res is TeamDefinition:
		name = (team_res as TeamDefinition).display_name
	_status_label.text = "Pass device to %s" % name
	_pass_overlay.show()
	_draft_panel.hide()
	presenter.clear_highlights()

func _on_pass_continue() -> void:
	_pass_overlay.hide()
	_viewing_team = session.active_draft_team
	_refresh_draft_view()

func _begin_battle() -> void:
	EventBus.tile_clicked.disconnect(_on_draft_tile_clicked)
	_draft_panel.hide()
	_pass_overlay.hide()
	presenter.clear_highlights()
	presenter.sync_legions(session)
	_turn_hud.show()
	_turn_hud.show_active_team(session.turn_manager.active_team_id)

func _on_end_turn() -> void:
	if input_locked:
		return
	battle_ui.deselect()
	var result := session.apply({"type": "end_turn"})
	if result["ok"]:
		_turn_hud.show_active_team(session.turn_manager.active_team_id)

func request_move(from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input_locked:
		return
	var legion: Legion = session.grid.get(from_coords).legion
	var result := session.apply({"type": "move", "from": from_coords, "to": to_coords})
	if not result["ok"]:
		return
	input_locked = true
	battle_ui.clear_overlays()
	var tween := presenter.tween_legion_move(legion, to_coords)
	if tween:
		await tween.finished
	presenter.remove_dead_legions(session)
	battle_ui.refresh_after_action(to_coords)
	input_locked = false
	_check_match_end()

func request_swap(from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input_locked:
		return
	var legion_a: Legion = session.grid.get(from_coords).legion
	var legion_b: Legion = session.grid.get(to_coords).legion
	var result := session.apply({"type": "swap", "from": from_coords, "to": to_coords})
	if not result["ok"]:
		return
	input_locked = true
	battle_ui.clear_overlays()
	var tweens := presenter.tween_legion_swap(legion_a, legion_b, to_coords, from_coords)
	for t in tweens:
		if t:
			await t.finished
	battle_ui.refresh_after_action(to_coords)
	input_locked = false

func request_attack(from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input_locked:
		return
	var result := session.apply({"type": "attack", "from": from_coords, "to": to_coords})
	if not result["ok"]:
		return
	input_locked = true
	battle_ui.deselect()
	await _play_combat_visuals(result["payload"].get("combat", {}), from_coords, to_coords)
	presenter.remove_dead_legions(session)
	input_locked = false
	_check_match_end()

func _play_combat_visuals(combat: Dictionary, from_coords: Vector2i, to_coords: Vector2i) -> void:
	var hits: Array = combat.get("hits", [])
	var deaths: Array = combat.get("deaths", [])
	var from_visu: TileVisu = presenter.tile_visu_at(from_coords)
	var to_visu: TileVisu = presenter.tile_visu_at(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu or not to_visu.legion_visu:
		return

	var legion_to_visu: Dictionary = {}
	for h in hits:
		var atk_legion: Legion = h["attacker_legion"]
		var def_legion: Legion = h["defender_legion"]
		if not legion_to_visu.has(atk_legion):
			var av: LegionVisu = presenter.get_legion_visu(atk_legion)
			if av:
				legion_to_visu[atk_legion] = av
		if not legion_to_visu.has(def_legion):
			var dv: LegionVisu = presenter.get_legion_visu(def_legion)
			if dv:
				legion_to_visu[def_legion] = dv

	var deaths_by_hit: Dictionary = {}
	for d in deaths:
		deaths_by_hit[d["hit_index"]] = d

	var a_visu: LegionVisu = from_visu.legion_visu
	var d_visu: LegionVisu = to_visu.legion_visu
	if a_visu and d_visu:
		var face_dir := (d_visu.global_position - a_visu.global_position).normalized()
		a_visu.update_direction(face_dir)
		d_visu.update_direction(-face_dir)

	for h in hits:
		var atk_legion: Legion = h["attacker_legion"]
		var def_legion: Legion = h["defender_legion"]
		var atk_unit: Unit = h["attacker"]
		var def_unit: Unit = h["target"]
		var atk_visu: LegionVisu = legion_to_visu.get(atk_legion)
		var def_visu: LegionVisu = legion_to_visu.get(def_legion)
		if not atk_visu or not def_visu:
			continue
		var dir := (def_visu.global_position - atk_visu.global_position).normalized()
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
				def_unit, dir,
				float(h.get("target_hp_before", -1.0)),
				float(h.get("target_hp_after", -1.0)),
				float(def_unit.max_health)
			)
		var beat := COMBAT_DEATH_BEAT if died_on_hit else COMBAT_HIT_BEAT
		await get_tree().create_timer(beat).timeout

	for lv in legion_to_visu.values():
		if lv:
			lv.update_local_positions()
			lv.tween_units_to_local_positions()
	await get_tree().create_timer(COMBAT_REPOSITION_BEAT).timeout

func _check_match_end() -> void:
	if session.phase != MinigameSession.Phase.ENDED:
		return
	battle_ui.deselect()
	_turn_hud.hide()
	_status_label.text = "%s wins!" % session.winner
	_pass_overlay.show()
