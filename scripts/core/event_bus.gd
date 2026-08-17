extends Node

signal tile_clicked(coords: Vector2i)
signal tile_right_clicked(coords: Vector2i)
signal tile_hover_entered(coords: Vector2i)
signal tile_hover_exited(coords: Vector2i)
signal turn_changed(active_team_id: String)
signal legion_ap_changed(legion: Legion)
signal legion_shields_refilled(legion: Legion)
## Fired during combat/heal playback so UI can mirror animated vitals.
signal unit_vitals_fx(unit: Unit, hp: float, shield: float)
signal battle_log_entry_added(entry: Dictionary)
## Incremental combat/heal stats while action playback runs (battle log live cards).
signal battle_log_live_tick(tick: Dictionary)
