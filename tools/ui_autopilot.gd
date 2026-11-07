extends Node

## Click-through UI smoke test. Runs the real game (needs a display, e.g. Xvfb), drives it
## only with injected mouse/keyboard events, saves screenshots and checks a few
## behaviours. Game state is read only to decide *where* to click and to assert.
##
##   tools/run_ui_autopilot.sh            (wraps Xvfb + OpenGL)
##   godot --path . --rendering-driver opengl3 res://tools/ui_autopilot.tscn -- OUT_DIR
## Runs as a normal scene (so autoloads boot exactly like the real game), then moves
## itself under the tree root so it survives scene changes.
##
## Exit code: 0 if every check passed, 1 otherwise.

const MENU_SCENE := "res://scenes/runnables/menu.tscn"
const MAX_HUMAN_TURNS := 8

var _out_dir := "user://autopilot"
var _hex = null
## "vs_ai" (default): play as a human vs the AI. "ai_vs_ai": watch AI-only turns advance.
var _scenario := "vs_ai"
const PHASE_BATTLE := 1
const PHASE_ENDED := 2
var _shot_index := 0
var _fails: Array[String] = []
var _ux_notes: Dictionary = {}  # note -> count
var _checks := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	# Optional second arg: global RNG seed (draft, map, combat) to replay a run.
	var run_seed := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else int(Time.get_unix_time_from_system()) % 100000
	_scenario = args[2] if args.size() > 2 else "vs_ai"
	# Optional 4th arg: comma list of settings to force for this run (not persisted).
	var flags: String = args[3] if args.size() > 3 else ""
	if "aidebug" in flags:
		GameSettings.set_ai_debug_enabled(true, false)
	if "moves" in flags:
		GameSettings.set_show_battle_log_moves(true, false)
	if "turns" in flags:
		GameSettings.set_show_battle_log_end_turns(true, false)
	_log("scenario %s flags [%s]" % [_scenario, flags])
	seed(run_seed)
	_log("seed %d (replay: tools/run_ui_autopilot.sh OUT_DIR %d)" % [run_seed, run_seed])
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_hex = load("res://scripts/ai/hex_pathfinder.gd")
	_start.call_deferred()

func _start() -> void:
	var tree := get_tree()
	# Survive change_scene: live directly under root, not inside the current scene.
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.change_scene_to_file(MENU_SCENE)
	_run()

# --- helpers -------------------------------------------------------------------------

func _log(msg: String) -> void:
	print("[AUTOPILOT] %s" % msg)

func _ux(note: String) -> void:
	_ux_notes[note] = int(_ux_notes.get(note, 0)) + 1
	_log("UX    %s" % note)

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		_log("PASS  %s" % what)
	else:
		_log("FAIL  %s" % what)
		_fails.append(what)

func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	_shot_index += 1
	var path := "%s/%02d_%s.png" % [_out_dir, _shot_index, label]
	img.save_png(path)
	_log("shot %s" % path)

func _move_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	Input.warp_mouse(pos)
	await _frames(3)

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move_mouse(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(3)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(1)
	await _frames(3)

func _find_button(text: String, node: Node = null) -> Control:
	if node == null:
		node = get_tree().root
	if node is Control and node.is_visible_in_tree() and node.has_signal("pressed"):
		var t: Variant = node.get("text")
		if t is String and (t as String).strip_edges() == text:
			return node
	for c in node.get_children():
		var found := _find_button(text, c)
		if found:
			return found
	return null

func _is_disabled(b: Control) -> bool:
	for prop in ["disabled", "button_disabled"]:
		var v: Variant = b.get(prop)
		if v is bool and v:
			return true
	return false

func _click_button(text: String, timeout := 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		var b := _find_button(text)
		if b and not _is_disabled(b):
			await _click(b.get_global_rect().get_center())
			_log("clicked '%s'" % text)
			return true
		await _wait(0.2)
		t += 0.2
	_log("button '%s' not found" % text)
	return false

func _wheel(pos: Vector2, button: MouseButton, times: int) -> void:
	await _move_mouse(pos)
	for i in times:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = button
			ev.pressed = pressed
			Input.parse_input_event(ev)
		await _frames(2)

## Middle-drag the map like a player would.
func _drag_pan(from: Vector2, to: Vector2) -> void:
	await _move_mouse(from)
	var down := InputEventMouseButton.new()
	down.position = from
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	for i in range(1, 9):
		var p := from.lerp(to, float(i) / 8.0)
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.relative = (to - from) / 8.0
		Input.parse_input_event(mv)
		await _frames(1)
	var up := InputEventMouseButton.new()
	up.position = to
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)

func _is_clickable(pos: Vector2) -> bool:
	var rect := get_viewport().get_visible_rect().grow(-40.0)
	if not rect.has_point(pos):
		return false
	await _move_mouse(pos)
	# Any HUD control under the cursor would eat the click.
	return get_viewport().gui_get_hovered_control() == null

## Screen position of a tile, panning the camera first if it's hidden or under HUD.
## A middle-drag from A to B moves the map by (B - A); drags start at a HUD-free spot
## and are capped at 300 px so the cursor stays over the map.
func _visible_tile_pos(coords: Vector2i) -> Vector2:
	var pos := _tile_screen_pos(coords)
	for attempt in 6:
		if await _is_clickable(pos):
			return pos
		var spot := _free_map_spot()
		var delta := (spot - pos).limit_length(300.0)
		await _drag_pan(spot - delta * 0.5, spot + delta * 0.5)
		pos = _tile_screen_pos(coords)
	_log("tile %s still not clickable at %s" % [coords, pos])
	return pos

## A screen point usually clear of HUD (right of the battle log, between top HUD and action bar).
func _free_map_spot() -> Vector2:
	var r := get_viewport().get_visible_rect()
	return Vector2(r.size.x * 0.68, r.size.y * 0.42)

func _tile_screen_pos(coords: Vector2i) -> Vector2:
	var game := get_tree().current_scene
	var tv = game.presenter.tile_visu_at(coords)
	return tv.get_global_transform_with_canvas().origin

func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if bool(cond.call()):
			return true
		await _wait(0.1)
		t += 0.1
	return false

func _game():
	return get_tree().current_scene

func _phase() -> int:
	var g = _game()
	if g == null or g.get("session") == null:
		return -1
	return int(g.session.phase)

func _is_battle() -> bool:
	return _phase() == PHASE_BATTLE

func _is_human_turn() -> bool:
	var g = _game()
	if not _is_battle():
		return false
	return (not g.deps.is_ai_team(g.session.turn_manager.active_team_id)) and not g.battle.is_input_locked()

# --- scenario ------------------------------------------------------------------------

func _run() -> void:
	await _wait(2.0)
	await _shot("main_menu")

	_check(await _click_button("Play"), "main menu Play opens setup")
	await _wait(0.6)
	await _shot("setup")
	if _scenario == "ai_vs_ai":
		await _click_button("AI vs AI")
		await _wait(0.3)
	_check(await _click_button("Start"), "setup Start launches the match")
	if _scenario == "ai_vs_ai":
		await _run_ai_vs_ai()
		return _finish()
	await _wait(2.5)
	await _shot("draft_empty")

	_check(await _click_button("Random team"), "draft Random team")
	await _wait(1.0)
	await _shot("draft_random_team")
	_check(await _click_button("Ready for battle"), "draft Ready for battle")
	var in_battle: bool = await _wait_until(_is_battle, 20.0)
	_check(in_battle, "battle phase starts")
	if not in_battle:
		return _finish()
	await _wait(1.5)
	await _shot("battle_start")
	await _wheel(_free_map_spot(), MOUSE_BUTTON_WHEEL_DOWN, 3)
	await _wait(0.4)
	await _shot("battle_zoomed_out")

	var human_turns := 0
	var tested_pause := false
	while human_turns < MAX_HUMAN_TURNS and _is_battle():
		if not _is_human_turn():
			if not tested_pause and _game().battle.ai_running:
				await _test_pause_holds_ai()
				tested_pause = true
			await _wait_until(func() -> bool: return _is_human_turn() or not _is_battle(), 60.0)
			continue
		human_turns += 1
		await _play_human_turn(human_turns)
		if not _is_battle():
			break
		await _shot("turn%d_before_end" % human_turns)
		await _click_button("Next turn")
		await _wait(0.5)

	if _phase() == PHASE_ENDED:
		# The session ends when the last action resolves; the panel follows its playback.
		var shown: bool = await _wait_until(func() -> bool: return _find_button("Main menu") != null, 30.0)
		await _wait(0.5)
		await _shot("game_over")
		_check(shown, "game-over panel appears after the final playback")
	else:
		# Abandon from the pause menu, ideally while the AI is acting (old crash path).
		await _click_button("Next turn")
		await _wait_until(func() -> bool: return _game().battle.ai_running, 5.0)
		await _wait(0.3)
		_log("abandoning mid-AI turn (ai_running=%s)" % _game().battle.ai_running)
		await _key(KEY_ESCAPE)
		await _shot("pause_for_abandon")
		await _click_button("Abandon game")
		await _wait(3.0)
		await _shot("after_abandon")
		_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == MENU_SCENE, "abandon returns to main menu")
		# Give any leftover coroutines time to (not) blow up.
		await _wait(3.0)
	_finish()

## AI-only match: every turn must hand over to the other AI within a time budget.
func _run_ai_vs_ai() -> void:
	var started: bool = await _wait_until(_is_battle, 30.0)
	_check(started, "AI vs AI: battle starts")
	if not started:
		await _shot("aivai_no_battle")
		return
	await _shot("aivai_start")
	for i in 6:
		if not _is_battle():
			break
		var tm = _game().session.turn_manager
		var turn: int = tm.turn_index
		var advanced: bool = await _wait_until(func() -> bool: return tm.turn_index != turn or not _is_battle(), 45.0)
		_check(advanced, "AI vs AI: turn %d (%s) ends within 45s" % [turn, tm.active_team_id])
		if not advanced:
			var g = _game()
			_log("stuck: ai_running=%s locked=%s actionable=%s" % [g.battle.ai_running, g.battle.is_input_locked(), g.session.get_actionable_coords()])
			await _shot("aivai_stuck_turn%d" % turn)
			return
	await _shot("aivai_end")

func _play_human_turn(turn_no: int) -> void:
	var g = _game()
	var team: String = g.session.turn_manager.active_team_id
	var acted := 0
	for _guard in 12:
		if not _is_human_turn():
			return
		var actionable: Array = g.session.get_actionable_coords()
		if actionable.is_empty():
			return
		var coords: Vector2i = actionable[0]
		var legion = g.session.get_legion_at(coords)
		var already: bool = g.battle_ui.interaction.has_selected and g.battle_ui.interaction.selected_coords == coords
		if not already:  # clicking the selected legion again would deselect it
			await _click(await _visible_tile_pos(coords))
			await _wait(0.3)
		var selected: bool = g.battle_ui.interaction.has_selected and g.battle_ui.interaction.selected_coords == coords
		_check(selected, "turn %d: clicking own legion selects it" % turn_no)
		var strip_ok: bool = g._legion_strip.visible and g._legion_strip.current_legion() == legion
		if not strip_ok:
			var shown = g._legion_strip.current_legion()
			_log("strip mismatch: selected %s %s@%s (already=%s) | strip visible=%s shows %s" % [
				legion.team_id, legion.unit_type, coords, already, g._legion_strip.visible,
				("%s %s@%s units=%d" % [shown.team_id, shown.unit_type, shown.tile_coords, shown.units.size()]) if shown else "none",
			])
			await _shot("turn%d_strip_mismatch" % turn_no)
		_check(strip_ok, "turn %d: legion strip shows the selection" % turn_no)
		if acted == 0:
			await _shot("turn%d_selected" % turn_no)
		if not selected:
			await _shot("turn%d_select_failed" % turn_no)
			return

		var attack := _first_target(g, legion, ["melee_attack", "ranged_attack"])
		if attack.size() > 0:
			await _do_attack(g, legion, coords, attack[0], attack[1], turn_no)
		else:
			var moved: bool = await _move_toward_enemy(g, legion, coords)
			if not moved:
				await _key(KEY_SPACE)  # wait/pass this legion
		acted += 1
		await _wait(0.4)
		if g.session.turn_manager.active_team_id != team:
			return

func _first_target(g, legion, ids: Array) -> Array:
	for id in ids:
		var targets: Array = g.session.get_action_targets(legion, id)
		if not targets.is_empty():
			return [id, targets[0]]
	return []

func _do_attack(g, legion, from: Vector2i, action_id: String, target: Vector2i, turn_no: int) -> void:
	# Hover first: expectation preview.
	var tpos: Vector2 = await _visible_tile_pos(target)
	await _move_mouse(tpos)
	await _wait(0.6)
	await _shot("turn%d_attack_preview_%s" % [turn_no, action_id])
	# Hover state only refreshes on motion; nudge so a panel that popped up under a
	# still cursor is detected (a real click there would land on it).
	await _move_mouse(tpos + Vector2(1, 0))
	if get_viewport().gui_get_hovered_control() != null:
		# The hover preview popped up over the very tile being targeted.
		_ux("attack preview panel covers the hovered target tile (click would hit the HUD)")
		var spot := Vector2(_free_map_spot().x, get_viewport().get_visible_rect().size.y * 0.30)
		var delta := (spot - tpos).limit_length(400.0)
		await _drag_pan(spot - delta * 0.5, spot + delta * 0.5)
		tpos = _tile_screen_pos(target)
		await _move_mouse(tpos)
		await _wait(0.6)
	var log_before: int = g.session.action_log.entries.size()
	await _click(tpos)
	# Melee+ranged on same target opens a choice popup; pick the first option if so.
	await _wait(0.25)
	if g.battle_ui.interaction.get("_attack_choice_popup") != null and is_instance_valid(g.battle_ui.interaction._attack_choice_popup):
		var popup: Control = g.battle_ui.interaction._attack_choice_popup
		await _shot("turn%d_attack_choice" % turn_no)
		var btns := popup.find_children("*", "BaseButton", true, false)
		if not btns.is_empty():
			await _click((btns[0] as Control).get_global_rect().get_center())
	await _wait(0.5)
	# Mid-combat: attacker must still be selected/inspected (fix: keep selection in combat).
	var mid_locked: bool = g.battle.is_input_locked()
	await _shot("turn%d_mid_combat" % turn_no)
	if mid_locked:
		_check(g._legion_strip.visible and g._legion_strip.current_legion() == legion, "turn %d: attacker stays in legion strip during combat" % turn_no)
	await _wait_until(func() -> bool: return not g.battle.is_input_locked(), 30.0)
	await _wait(0.6)
	await _shot("turn%d_after_combat" % turn_no)
	_check(g.session.action_log.entries.size() > log_before, "turn %d: combat logged" % turn_no)
	if _is_battle() and not legion.units.is_empty():
		_check(g._legion_strip.visible and g._legion_strip.current_legion() == legion, "turn %d: attacker still inspected after combat" % turn_no)
	_check_log_deaths(g)

func _check_log_deaths(g) -> void:
	# Battle-log fix: live loss counter must equal the logged total, not stick at 1.
	var entries: Array = g.session.action_log.entries
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if String(e.get("action_id", "")) in ["melee_attack", "ranged_attack"]:
			var total := int(e.get("caster_deaths", 0)) + int(e.get("target_deaths", 0))
			if total >= 2:
				_log("last combat had %d losses — check the battle-log chips in the screenshot" % total)
			return

func _move_toward_enemy(g, legion, from: Vector2i) -> bool:
	var reach: Array = g.battle_ui.interaction.target_coords
	if reach.is_empty():
		var moves: Array = g.session.get_action_targets(legion, "move")
		reach = moves
	if reach.is_empty():
		return false
	var enemy = null
	var best_d := 1 << 30
	for L in g.session.legions:
		if L.team_id != legion.team_id and not L.units.is_empty():
			var d: int = _hex.hex_distance(from, L.tile_coords)
			if d < best_d:
				best_d = d
				enemy = L
	if enemy == null:
		return false
	var best: Vector2i = reach[0]
	var bd := 1 << 30
	for c in reach:
		var tile: Tile = g.session.grid.get(c)
		if tile == null or tile.has_legion():
			continue
		var d: int = _hex.hex_distance(c, enemy.tile_coords)
		if d < bd:
			bd = d
			best = c
	if bd >= _hex.hex_distance(from, enemy.tile_coords):
		return false
	await _click(await _visible_tile_pos(best))
	await _wait_until(func() -> bool: return not g.battle.is_input_locked(), 10.0)
	await _wait(0.3)
	return legion.tile_coords != from

func _test_pause_holds_ai() -> void:
	var g = _game()
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	await _shot("pause_during_ai")
	var paused_open: bool = g.deps.pause_menu.is_open()
	_check(paused_open, "Esc opens pause menu during AI turn")
	var log_before: int = g.session.action_log.entries.size()
	await _wait(3.0)
	var log_after: int = g.session.action_log.entries.size()
	# One in-flight action may finish; the AI must not keep issuing new ones.
	_check(log_after - log_before <= 1, "AI holds while paused (%d new log entries in 3s)" % (log_after - log_before))
	await _click_button("Resume")
	await _wait(0.3)

func _finish() -> void:
	_log("checks: %d, failed: %d" % [_checks, _fails.size()])
	for note in _ux_notes:
		_log("  ux finding (x%d): %s" % [_ux_notes[note], note])
	for f in _fails:
		_log("  failed: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)
