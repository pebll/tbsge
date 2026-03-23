extends Node

var sounds : Dictionary = {}
var sfx_players : Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 10

func _ready() -> void:
	# Pre-load sounds
	sounds["tile_click"] = preload('res://assets/sfx/click.mp3')
	sounds["tile_hover"] = preload("res://assets/sfx/hover_entry.mp3")
	
	# Create SFX audioStreamPlayers
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
func play_sfx(sound_name: String):
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return
	
	for player in sfx_players:
		if not player.playing:
			player.stream = sounds[sound_name]
			player.play()
			return
			
	push_warning("Sound not played because all players busy: " + sound_name)
