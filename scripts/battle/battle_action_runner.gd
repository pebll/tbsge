class_name BattleActionRunner
extends RefCounted

const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")
const GridPresenterScript = preload("res://scripts/visu/grid_presenter.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")

func play_result(
	host: Node,
	session: MatchSessionScript,
	presenter: GridPresenterScript,
	playback: ActionPlaybackScript,
	result: Dictionary,
	from_coords: Vector2i,
	hooks: Dictionary = {}
) -> bool:
	if not result.get("ok", false):
		return false

	var events: Array = result.get("events", [])
	var payload: Dictionary = result.get("payload", {})
	var to_coords: Vector2i = payload.get("to", from_coords)

	if not ("legion_healed" in events or "combat_resolved" in events or "legion_teleported" in events):
		_call_hook(hooks, "clear_overlays")

	if "legion_moved" in events:
		var legion: Legion = payload.get("legion")
		presenter.rewire_legion_tile(legion, from_coords, to_coords)
		var tween: Tween = presenter.tween_legion_move(legion, to_coords)
		if tween:
			await tween.finished
		_call_hook(hooks, "on_ap_changed", legion)
	elif "legion_teleported" in events:
		var legion: Legion = payload.get("legion")
		await playback.play_teleport(from_coords, to_coords, payload, {
			"deselect_after": true,
			"deselect": hooks.get("deselect", Callable()),
			"on_ap_changed": hooks.get("on_ap_changed", Callable()),
			"rewire": func() -> void:
				presenter.rewire_legion_tile(legion, from_coords, to_coords)
				var lv: LegionVisu = presenter.get_legion_visu(legion)
				if lv:
					var to_visu: TileVisu = presenter.tile_visu_at(to_coords)
					if to_visu:
						# Match spawn/move: local position under GridPresenter + refresh z-order.
						# global_position + stale depth left the sprite under tiles (invisible).
						lv.position = to_visu.position
						lv._sync_depth_sort(),
		})
		_call_hook(hooks, "deselect")
		_call_hook(hooks, "clear_overlays")
		_call_hook(hooks, "on_finished")
		return true
	elif "legions_swapped" in events:
		var legion_a: Legion = session.grid.get(to_coords).legion
		var legion_b: Legion = session.grid.get(from_coords).legion
		presenter.rewire_legion_tile(legion_a, from_coords, to_coords)
		presenter.rewire_legion_tile(legion_b, to_coords, from_coords)
		for tween in presenter.tween_legion_swap(legion_a, legion_b, to_coords, from_coords):
			if tween:
				await tween.finished
		_call_hook(hooks, "on_ap_changed", legion_a)
		_call_hook(hooks, "on_ap_changed", legion_b)
	elif "combat_resolved" in events:
		var played := await _play_combat(
			host, presenter, playback, from_coords, to_coords, payload.get("combat", {}), hooks
		)
		# Combat is terminal — always clear selection/overlays after it resolves.
		_call_hook(hooks, "deselect")
		_call_hook(hooks, "clear_overlays")
		_call_hook(hooks, "on_finished")
		return played
	elif "legion_healed" in events:
		var heal_coords: Vector2i = payload.get("to", payload.get("coords", from_coords))
		await playback.play_heal(heal_coords, payload, {
			"deselect_after": hooks.get("deselect_after_heal", false),
			"deselect": hooks.get("deselect", Callable()),
			"on_ap_changed": hooks.get("on_ap_changed", Callable()),
		})
		_call_hook(hooks, "on_finished")
		return true

	var refresh_coords := from_coords
	if "legion_moved" in events or "legions_swapped" in events:
		refresh_coords = to_coords

	presenter.remove_dead_legions(session)
	_call_hook(hooks, "refresh_after_action", refresh_coords)
	_call_hook(hooks, "on_finished")
	return true

func _play_combat(
	host: Node,
	presenter: GridPresenterScript,
	playback: ActionPlaybackScript,
	from_coords: Vector2i,
	to_coords: Vector2i,
	combat: Dictionary,
	hooks: Dictionary
) -> bool:
	var from_visu: TileVisu = presenter.tile_visu_at(from_coords)
	var to_visu: TileVisu = presenter.tile_visu_at(to_coords)
	var can_animate := (
		from_visu != null
		and to_visu != null
		and from_visu.legion_visu != null
		and to_visu.legion_visu != null
	)

	if can_animate:
		await playback.play_combat(from_coords, to_coords, combat, {
			"deselect_before": hooks.get("deselect_before_combat", false),
			"deselect": hooks.get("deselect", Callable()),
			"on_ap_changed": hooks.get("on_ap_changed", Callable()),
		})
	else:
		# Model already resolved; skip visuals rather than reporting failure.
		if hooks.get("deselect_before_combat", false):
			_call_hook(hooks, "deselect")

	if hooks.get("deselect_after_combat", false):
		_call_hook(hooks, "deselect")

	var session: MatchSessionScript = hooks.get("session")
	if session:
		presenter.cleanup_dead_legion_at(from_coords, session)
		presenter.cleanup_dead_legion_at(to_coords, session)
		presenter.remove_dead_legions(session)
	_call_hook(hooks, "clear_overlays")
	return true

func _call_hook(hooks: Dictionary, key: String, arg = null) -> void:
	if not hooks.has(key):
		return
	var hook: Callable = hooks[key]
	if hook.is_valid():
		if arg == null:
			hook.call()
		else:
			hook.call(arg)
