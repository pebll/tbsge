class_name GameInput
extends RefCounted

## Blocks player commands while gameplay animations run.

var _game: GameManager
var _locked: bool = false

func _init(game: GameManager) -> void:
	_game = game

func is_locked() -> bool:
	return _locked

func begin_action() -> void:
	_locked = true
	_game.ui.clear_overlays()

func end_action() -> void:
	_locked = false
