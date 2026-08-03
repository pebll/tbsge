class_name BattleInputLock
extends RefCounted

## Shared input lock for battle hosts (sandbox + minigame).
## Modes may also gate on AI / picker UI; this covers "action animation in flight".

var _locked: bool = false
var _depth: int = 0

func is_locked() -> bool:
	return _locked or _depth > 0

func begin() -> void:
	_depth += 1
	_locked = true

func end() -> void:
	_depth = maxi(0, _depth - 1)
	if _depth == 0:
		_locked = false

func set_locked(value: bool) -> void:
	_locked = value
	if not value:
		_depth = 0
