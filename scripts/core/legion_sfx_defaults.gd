class_name LegionSfxDefaults
extends RefCounted

## Global fallback streams when a unit has no per-action override.
## Replace placeholder assets under res://assets/sfx/defaults/ as real SFX are added.

const PATH_SELECT := "res://assets/sfx/defaults/select_placeholder.mp3"
const PATH_MOVE := "res://assets/sfx/defaults/move_placeholder.wav"
const PATH_DEATH := "res://assets/sfx/defaults/death_placeholder.wav"

const HIT_PATHS: Array[String] = [
	"res://assets/sfx/combat/hit/hit_01.ogg",
	"res://assets/sfx/combat/hit/hit_02.ogg",
	"res://assets/sfx/combat/hit/hit_03.ogg",
	"res://assets/sfx/combat/hit/hit_04.ogg",
	"res://assets/sfx/combat/hit/hit_05.ogg",
	"res://assets/sfx/combat/hit/hit_06.ogg",
	"res://assets/sfx/combat/hit/hit_07.ogg",
	"res://assets/sfx/combat/hit/hit_08.ogg",
	"res://assets/sfx/combat/hit/hit_09.ogg",
	"res://assets/sfx/combat/hit/hit_10.ogg",
]

static var _stream_cache: Dictionary = {}
static var _hit_streams: Array[AudioStream] = []

static func stream(action: LegionSfxAction.Kind) -> AudioStream:
	match action:
		LegionSfxAction.Kind.SELECT:
			return _cached_stream(PATH_SELECT)
		LegionSfxAction.Kind.MOVE:
			return _cached_stream(PATH_MOVE)
		LegionSfxAction.Kind.DEATH:
			return _cached_stream(PATH_DEATH)
		LegionSfxAction.Kind.HIT:
			return null
	return null

static func hit_streams() -> Array[AudioStream]:
	if _hit_streams.is_empty():
		for path in HIT_PATHS:
			var loaded: AudioStream = load(path)
			if loaded:
				_hit_streams.append(loaded)
	return _hit_streams

static func random_hit_stream() -> AudioStream:
	var streams := hit_streams()
	if streams.is_empty():
		return null
	return streams[randi() % streams.size()]

static func _cached_stream(path: String) -> AudioStream:
	if not _stream_cache.has(path):
		_stream_cache[path] = load(path)
	return _stream_cache[path]
