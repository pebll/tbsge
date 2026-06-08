class_name GameInput
extends RefCounted

## Blocks player commands while gameplay animations run.

var _clear_overlays_fn: Callable = func() -> void: pass
var _locked: bool = false

func _init(clear_overlays_fn: Callable = Callable()) -> void:
	if clear_overlays_fn.is_valid():
		_clear_overlays_fn = clear_overlays_fn

func is_locked() -> bool:
	return _locked

func begin_action() -> void:
	_locked = true
	if _clear_overlays_fn.is_valid():
		_clear_overlays_fn.call()

func end_action() -> void:
	_locked = false
