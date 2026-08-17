extends RefCounted

## Compile/load UI scripts that unit tests may never instantiate.

func run(_tree: SceneTree) -> bool:
	var paths: Array[String] = [
		"res://scripts/ui/interact/unit_footprint.gd",
		"res://scripts/ui/interact/ui_tooltip_policy.gd",
		"res://scripts/ui/interact/ui_interactable.gd",
		"res://scripts/ui/interact/ui_hover_tooltip.gd",
		"res://scripts/ui/ui_stat_icons.gd",
		"res://scripts/ui/legion_unit_cell.gd",
		"res://scripts/ui/legion_strip.gd",
		"res://scripts/battle/battle_expectation_estimator.gd",
		"res://scripts/ui/battle_expectation_bar.gd",
		"res://scripts/minigame/minigame_root.gd",
		"res://scripts/core/sandbox_root.gd",
		"res://scenes/ui/legion_strip.tscn",
	]
	for path in paths:
		if path.ends_with(".tscn"):
			var packed: PackedScene = load(path)
			if packed == null:
				push_error("Failed to load scene: %s" % path)
				return false
			var node := packed.instantiate()
			if node == null:
				push_error("Failed to instantiate scene: %s" % path)
				return false
			node.free()
		else:
			var script: GDScript = load(path)
			if script == null:
				push_error("Failed to load script: %s" % path)
				return false
			var err := script.reload()
			if err != OK:
				push_error("Script reload failed (%s): %s" % [err, path])
				return false
	print("Success: UI script smoke load")
	return true
