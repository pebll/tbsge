extends RefCounted

const LegionSfxScript = preload("res://scripts/core/legion_sfx.gd")
const LegionSfxActionScript = preload("res://scripts/core/legion_sfx_action.gd")
const LegionSfxDefaultsScript = preload("res://scripts/core/legion_sfx_defaults.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_legion_sfx_defaults():
		return false
	if not _test_audio_bus_names():
		return false
	print("Success: Legion SFX / audio bus tests")
	return true

func _test_legion_sfx_defaults() -> bool:
	var select_stream: AudioStream = LegionSfxScript.stream_for("GOBLIN", LegionSfxAction.Kind.SELECT)
	if select_stream == null:
		push_error("Expected default select stream for GOBLIN")
		return false
	var move_stream: AudioStream = LegionSfxScript.stream_for("GOBLIN", LegionSfxAction.Kind.MOVE)
	if move_stream == null:
		push_error("Expected default move stream for GOBLIN")
		return false
	# Golem overrides move SFX.
	var golem_move: AudioStream = LegionSfxScript.stream_for("GOLEM", LegionSfxAction.Kind.MOVE)
	if golem_move == null:
		push_error("Expected GOLEM move override stream")
		return false
	if LegionSfxScript.uses_random_default_hit("GOBLIN") != true:
		push_error("GOBLIN should use random default hit SFX")
		return false
	if LegionSfxDefaultsScript.hit_streams().is_empty():
		push_error("Expected default hit stream pool")
		return false
	return true

func _test_audio_bus_names() -> bool:
	# AudioManager is an autoload; verify bus constants match project layout.
	if AudioManager.BUS_MENU != "Menu":
		push_error("Expected Menu bus name")
		return false
	if AudioManager.BUS_GAME != "Game":
		push_error("Expected Game bus name")
		return false
	if AudioManager.BUS_MUSIC != "Music":
		push_error("Expected Music bus name")
		return false
	for bus_name in [AudioManager.BUS_MENU, AudioManager.BUS_GAME, AudioManager.BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("Missing audio bus: %s" % bus_name)
			return false
	return true
