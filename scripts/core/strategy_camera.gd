class_name StrategyCamera
extends Camera2D

@export var min_zoom: Vector2 = Vector2(0.28, 0.28)
@export var max_zoom: Vector2 = Vector2(3.5, 3.5)
@export var zoom_step: float = 1.12
@export var drag_pan_button: MouseButton = MOUSE_BUTTON_MIDDLE

var _pan_drag_active: bool = false
var _pan_drag_last_screen: Vector2

func _ready() -> void:
	make_current()
	zoom = Vector2(
		clampf(zoom.x, min_zoom.x, max_zoom.x),
		clampf(zoom.y, min_zoom.y, max_zoom.y)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == drag_pan_button:
			_pan_drag_active = mb.pressed
			if mb.pressed:
				_pan_drag_last_screen = mb.position
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(zoom_step)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(1.0 / zoom_step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pan_drag_active:
		var motion := event as InputEventMouseMotion
		var delta_screen := motion.position - _pan_drag_last_screen
		_pan_drag_last_screen = motion.position
		position -= delta_screen / zoom
		get_viewport().set_input_as_handled()

func _apply_zoom(multiplier: float) -> void:
	var old_zoom := zoom
	var new_zoom := Vector2(
		clampf(old_zoom.x * multiplier, min_zoom.x, max_zoom.x),
		clampf(old_zoom.y * multiplier, min_zoom.y, max_zoom.y)
	)
	if new_zoom == old_zoom:
		return

	var anchor := get_global_mouse_position()
	position = anchor - (anchor - position) * (new_zoom / old_zoom)
	zoom = new_zoom
