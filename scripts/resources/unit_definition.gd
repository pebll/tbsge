class_name UnitDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export var max_health: int = 10
@export var attack: int = 3

## How much of a legion's 12-point capacity one unit consumes (default 1.5 → up to 8 units).
@export var size: float = 1.5
## Gold cost per individual unit (not per legion).
@export var price: int = 5

@export var icon: Texture2D
## Empty = legion uses default move / melee_attack / self_heal.
@export var action_ids: Array[String] = []
