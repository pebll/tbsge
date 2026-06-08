class_name ZoomInvariantBackground
extends Sprite2D

## Counter-scales against the parent Camera2D zoom so this sprite keeps a fixed
## on-screen size and stays anchored to the camera view.

var _base_scale: Vector2

func _ready() -> void:
	_base_scale = scale

func _process(_delta: float) -> void:
	var cam := get_parent() as Camera2D
	if cam == null:
		return
	scale = _base_scale / cam.zoom
