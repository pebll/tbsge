extends Node

signal tile_clicked(coords: Vector2i)
signal tile_right_clicked(coords: Vector2i)
signal tile_hover_entered(coords: Vector2i)
signal tile_hover_exited(coords: Vector2i)
signal turn_changed(active_team_id: String)
signal legion_ap_changed(legion: Legion)
signal legion_shields_refilled(legion: Legion)
signal battle_log_entry_added(entry: Dictionary)
