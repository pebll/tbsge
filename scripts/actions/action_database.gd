class_name ActionDatabase
extends Resource

const ActionDefinition = preload("res://scripts/actions/action_definition.gd")

@export var defs: Array[Resource] = []

func get_def(id: String) -> ActionDefinition:
	for def in defs:
		if def and def.id == id:
			return def
	return null

func all_defs() -> Array:
	return defs.duplicate()
