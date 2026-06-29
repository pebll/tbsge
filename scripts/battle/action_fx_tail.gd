class_name ActionFxTail
extends RefCounted

## Cosmetic follow-up after a blocking action animation finishes.
##
## ActionPlayback play_* methods should await only the gameplay animation phase,
## then call release() so input unlocks immediately. Popups and lingering HP bars
## continue in the background (teleport, ranged attack, buff, etc. follow the same pattern).

var _combat_fx: CombatFxPresenter

func _init(combat_fx: CombatFxPresenter) -> void:
	_combat_fx = combat_fx

## spawn_fn: sync spawn of popups/overlays. hp_fx_legions: legions whose combat HP FX linger then hide.
func release(spawn_fn: Callable = Callable(), hp_fx_legions: Array = []) -> void:
	if spawn_fn.is_valid():
		spawn_fn.call()
	if hp_fx_legions.is_empty():
		return
	_combat_fx.hide_hp_fx_later(hp_fx_legions)
