extends Node

const LegionSfxActionScript = preload("res://scripts/core/legion_sfx_action.gd")
const LegionSfxScript = preload("res://scripts/core/legion_sfx.gd")
const LegionSfxDefaultsScript = preload("res://scripts/core/legion_sfx_defaults.gd")

const BUS_MENU := "Menu"
const BUS_GAME := "Game"
const BUS_MUSIC := "Music"

const SETTINGS_PATH := "user://audio_settings.cfg"
const SETTINGS_SECTION := "volume"

const DEFAULT_MENU_VOLUME := 1.0
const DEFAULT_GAME_VOLUME := 0.0
const DEFAULT_MUSIC_VOLUME := 1.0

const DEFAULT_MUSIC_STREAM := preload("res://assets/music/bgmusic_menu.wav")

const MAX_UI_SFX_PLAYERS := 6
const MAX_SELECT_SFX_PLAYERS := 6
const MAX_HIT_SFX_PLAYERS := 20
const MAX_HEAL_SFX_PLAYERS := 6
const MAX_MOVE_SFX_PLAYERS := 8
const MAX_DEATH_SFX_PLAYERS := 8

var menu_volume: float = DEFAULT_MENU_VOLUME
var game_volume: float = DEFAULT_GAME_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME

var sounds: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []
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

	_ui_players = _make_players(MAX_UI_SFX_PLAYERS, BUS_MENU)
	_select_players = _make_players(MAX_SELECT_SFX_PLAYERS, BUS_GAME)
	_hit_players = _make_players(MAX_HIT_SFX_PLAYERS, BUS_GAME)
	_heal_players = _make_players(MAX_HEAL_SFX_PLAYERS, BUS_GAME)
	_move_players = _make_players(MAX_MOVE_SFX_PLAYERS, BUS_GAME)
	_death_players = _make_players(MAX_DEATH_SFX_PLAYERS, BUS_GAME)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_load_settings()
	_apply_all_volumes()
	ensure_music()

## Keeps current playback if the same stream is already playing (survives scene changes).
func ensure_music(stream: AudioStream = null) -> void:
	if stream == null:
		stream = DEFAULT_MUSIC_STREAM
	if _music_player.playing and _music_player.stream == stream:
		return
	_music_player.stream = stream
	_music_player.play()

func _on_music_finished() -> void:
	# Restart instead of WAV loop points — this stream is IMA-ADPCM, which loops poorly.
	if _music_player.stream != null:
		_music_player.play()

func set_menu_volume(value: float, persist: bool = true) -> void:
	menu_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MENU, menu_volume)
	if persist:
		_save_settings()

func set_game_volume(value: float, persist: bool = true) -> void:
	game_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_GAME, game_volume)
	if persist:
		_save_settings()

func set_music_volume(value: float, persist: bool = true) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	if persist:
		_save_settings()

func play_sfx(sound_name: String) -> void:
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return
	_play_on_first_free(_ui_players, sounds[sound_name])

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
		stream = sounds.get("tile_click") as AudioStream
		if stream == null:
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

func _make_players(count: int, bus_name: String) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i in range(count):
		var player := AudioStreamPlayer.new()
		player.bus = bus_name
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

func _apply_all_volumes() -> void:
	_apply_bus_volume(BUS_MENU, menu_volume)
	_apply_bus_volume(BUS_GAME, game_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Audio bus not found: " + bus_name)
		return
	var muted := linear <= 0.0
	AudioServer.set_bus_mute(idx, muted)
	if muted:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		menu_volume = DEFAULT_MENU_VOLUME
		game_volume = DEFAULT_GAME_VOLUME
		music_volume = DEFAULT_MUSIC_VOLUME
		return
	menu_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, "menu", DEFAULT_MENU_VOLUME)), 0.0, 1.0)
	game_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, "game", DEFAULT_GAME_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, "music", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION, "menu", menu_volume)
	cfg.set_value(SETTINGS_SECTION, "game", game_volume)
	cfg.set_value(SETTINGS_SECTION, "music", music_volume)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save audio settings: %s" % error_string(err))
