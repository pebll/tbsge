class_name PassBrain
extends AiBrain

## Curriculum stage 1–2: always pass.

func _init() -> void:
	id = "curriculum_pass"
	display_name = "Curriculum Pass"

func decide(_session, legion: Legion) -> Dictionary:
	return {
		"type": "pass",
		"coords": legion.tile_coords if legion else Vector2i.ZERO,
		"reason": "curriculum pass",
	}
