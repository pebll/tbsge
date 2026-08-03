class_name GameInput
extends RefCounted

## Sandbox-facing lock: wraps BattleInputLock and optionally clears overlays on begin.

const BattleInputLockScript = preload("res://scripts/battle/battle_input_lock.gd")

var _lock: BattleInputLockScript = BattleInputLockScript.new()
var _clear_overlays_fn: Callable = func() -> void: pass

func _init(clear_overlays_fn: Callable = Callable()) -> void:
	if clear_overlays_fn.is_valid():
		_clear_overlays_fn = clear_overlays_fn

func is_locked() -> bool:
	return _lock.is_locked()

func begin_action() -> void:
	_lock.begin()
	if _clear_overlays_fn.is_valid():
		_clear_overlays_fn.call()

func end_action() -> void:
	_lock.end()
