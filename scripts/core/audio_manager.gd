extends Node

const LegionSfxActionScript = preload("res://scripts/core/legion_sfx_action.gd")
const LegionSfxScript = preload("res://scripts/core/legion_sfx.gd")
const LegionSfxDefaultsScript = preload("res://scripts/core/legion_sfx_defaults.gd")

const MAX_UI_SFX_PLAYERS := 6
const MAX_HIT_SFX_PLAYERS := 20
const MAX_HEAL_SFX_PLAYERS := 6
const MAX_MOVE_SFX_PLAYERS := 8
const MAX_DEATH_SFX_PLAYERS := 8

var sounds: Dictionary = {}
var _select_players: Array[AudioStreamPlayer] = []
var _hit_players: Array[AudioStreamPlayer] = []
var _heal_players: Array[AudioStreamPlayer] = []
var _move_players: Array[AudioStreamPlayer] = []
var _death_players: Array[AudioStreamPlayer] = []
var _hit_player_idx: int = 0
var _heal_player_idx: int = 0
var _move_player_idx: int = 0
var _death_player_idx: int = 0

func _ready() -> void:
	sounds["tile_click"] = preload("res://assets/sfx/ui/click.mp3")
	sounds["tile_hover"] = preload("res://assets/sfx/ui/hover.mp3")
	sounds["heal"] = preload("res://assets/sfx/combat/heal.wav")

	_select_players = _make_players(MAX_UI_SFX_PLAYERS)
	_hit_players = _make_players(MAX_HIT_SFX_PLAYERS)
	_heal_players = _make_players(MAX_HEAL_SFX_PLAYERS)
	_move_players = _make_players(MAX_MOVE_SFX_PLAYERS)
	_death_players = _make_players(MAX_DEATH_SFX_PLAYERS)

func play_sfx(sound_name: String) -> void:
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return
	_play_on_first_free(_select_players, sounds[sound_name])

func play_legion_sfx(unit_type: String, action: LegionSfxAction.Kind) -> void:
	match action:
		LegionSfxAction.Kind.SELECT:
			_play_select(unit_type)
		LegionSfxAction.Kind.MOVE:
			_play_move(unit_type)
		LegionSfxAction.Kind.HIT:
			_play_hit(unit_type)
		LegionSfxAction.Kind.DEATH:
			_play_death(unit_type)

func play_unit_click(unit_type: String) -> void:
	play_legion_sfx(unit_type, LegionSfxAction.Kind.SELECT)

func play_unit_move(unit_type: String) -> void:
	play_legion_sfx(unit_type, LegionSfxAction.Kind.MOVE)

func play_unit_hit(unit_type: String) -> void:
	play_legion_sfx(unit_type, LegionSfxAction.Kind.HIT)

func play_unit_death(unit_type: String) -> void:
	play_legion_sfx(unit_type, LegionSfxAction.Kind.DEATH)

func play_random_hit_sfx() -> void:
	var stream := LegionSfxDefaultsScript.random_hit_stream()
	if stream == null:
		push_warning("No default hit sounds loaded")
		return
	_play_round_robin(_hit_players, stream, _hit_player_idx)
	_hit_player_idx = (_hit_player_idx + 1) % _hit_players.size()

func play_heal_sfx() -> void:
	if not sounds.has("heal"):
		push_warning("Heal sound not found")
		return
	_play_round_robin(_heal_players, sounds["heal"], _heal_player_idx)
	_heal_player_idx = (_heal_player_idx + 1) % _heal_players.size()

func _play_select(unit_type: String) -> void:
	var stream := LegionSfxScript.stream_for(unit_type, LegionSfxAction.Kind.SELECT)
	if stream == null:
		play_sfx("tile_click")
		return
	_play_on_first_free(_select_players, stream)

func _play_move(unit_type: String) -> void:
	var stream := LegionSfxScript.stream_for(unit_type, LegionSfxAction.Kind.MOVE)
	if stream == null:
		return
	_play_round_robin(_move_players, stream, _move_player_idx)
	_move_player_idx = (_move_player_idx + 1) % _move_players.size()

func _play_hit(unit_type: String) -> void:
	if LegionSfxScript.uses_random_default_hit(unit_type):
		play_random_hit_sfx()
		return
	var stream := LegionSfxScript.stream_for(unit_type, LegionSfxAction.Kind.HIT)
	if stream == null:
		play_random_hit_sfx()
		return
	_play_round_robin(_hit_players, stream, _hit_player_idx)
	_hit_player_idx = (_hit_player_idx + 1) % _hit_players.size()

func _play_death(unit_type: String) -> void:
	var stream := LegionSfxScript.stream_for(unit_type, LegionSfxAction.Kind.DEATH)
	if stream == null:
		return
	_play_round_robin(_death_players, stream, _death_player_idx)
	_death_player_idx = (_death_player_idx + 1) % _death_players.size()

func _make_players(count: int) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i in range(count):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		players.append(player)
	return players

func _play_on_first_free(players: Array[AudioStreamPlayer], stream: AudioStream) -> void:
	for player in players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	_play_round_robin(players, stream, 0)

func _play_round_robin(players: Array[AudioStreamPlayer], stream: AudioStream, index: int) -> void:
	if players.is_empty():
		return
	var player := players[index % players.size()]
	player.stop()
	player.stream = stream
	player.play()
