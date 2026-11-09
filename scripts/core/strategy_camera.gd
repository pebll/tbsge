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

# --- Framing: keep gameplay inside the part of the screen the HUD doesn't cover ---

const FRAME_DURATION := 0.35

var _frame_tween: Tween

## Screen rect left free by HUD panels, given insets (left, top, right, bottom) in pixels.
func safe_rect(insets: Vector4) -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(
		Vector2(insets.x, insets.y),
		Vector2(maxf(64.0, vp.x - insets.x - insets.z), maxf(64.0, vp.y - insets.y - insets.w))
	)

func world_to_screen(p: Vector2) -> Vector2:
	return (p - position) * zoom + get_viewport_rect().size * 0.5

## Zoom and pan so the world rect fills the safe area (never closer than max_fit_zoom).
func frame_world_rect(world: Rect2, insets: Vector4, max_fit_zoom: float = 2.6, animate: bool = true) -> void:
	var safe := safe_rect(insets)
	var z := minf(safe.size.x / maxf(world.size.x, 1.0), safe.size.y / maxf(world.size.y, 1.0))
	z = clampf(z, min_zoom.x, minf(max_zoom.x, max_fit_zoom))
	var new_zoom := Vector2(z, z)
	var vp := get_viewport_rect().size
	var new_pos := world.get_center() - (safe.get_center() - vp * 0.5) / z
	_tween_to(new_pos, new_zoom, animate)

## Pan as little as needed so the world rect sits inside the safe area (zoom unchanged).
func ensure_world_rect_visible(world: Rect2, insets: Vector4, animate: bool = true) -> void:
	var safe := safe_rect(insets)
	var a := world_to_screen(world.position)
	var b := world_to_screen(world.end)
	var shift := Vector2.ZERO
	for axis in 2:
		var lo: float = safe.position[axis]
		var hi: float = safe.end[axis]
		if b[axis] - a[axis] > hi - lo:
			shift[axis] = (a[axis] + b[axis]) * 0.5 - (lo + hi) * 0.5
		elif a[axis] < lo:
			shift[axis] = a[axis] - lo
		elif b[axis] > hi:
			shift[axis] = b[axis] - hi
	if shift == Vector2.ZERO:
		return
	_tween_to(position + shift / zoom, zoom, animate)

func _tween_to(new_pos: Vector2, new_zoom: Vector2, animate: bool) -> void:
	if _frame_tween and _frame_tween.is_running():
		_frame_tween.kill()
	if not animate or not is_inside_tree():
		position = new_pos
		zoom = new_zoom
		return
	_frame_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(self, "position", new_pos, FRAME_DURATION)
	_frame_tween.tween_property(self, "zoom", new_zoom, FRAME_DURATION)
