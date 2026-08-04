class_name TooltipController
extends Control

## Full-rect host: click-outside / Escape dismisses; anchors popup near cursor/control.

var _popup: TooltipPopup
var _dim: Control
var _visible_content: TooltipContent = null

func _ready() -> void:
	name = "TooltipController"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80

	_dim = Control.new()
	_dim.name = "DismissCatcher"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.hide()
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_popup = TooltipPopup.new()
	_popup.keyword_inspect_requested.connect(_on_keyword_inspect)
	add_child(_popup)
	_popup.hide()

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			dismiss()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			# Clicks on the popup (or its keyword chips) should not dismiss.
			if _popup and _popup.get_global_rect().has_point(event.position):
				return
			dismiss()
			get_viewport().set_input_as_handled()

func is_open() -> bool:
	return _popup != null and _popup.visible

func show_content(content: TooltipContent, global_anchor: Vector2) -> void:
	if content == null:
		dismiss()
		return
	_visible_content = content
	_popup.present(content)
	_dim.show()
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Stay above siblings added later on the same CanvasLayer.
	z_index = 80
	if get_parent():
		get_parent().move_child(self, -1)
	await get_tree().process_frame
	_place_near(global_anchor)

func show_for_control(control: Control, content: TooltipContent) -> void:
	if control == null:
		show_content(content, get_global_mouse_position())
		return
	var rect := control.get_global_rect()
	var anchor := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
	show_content(content, anchor)

func dismiss() -> void:
	_visible_content = null
	if _popup:
		_popup.hide()
	if _dim:
		_dim.hide()
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func wire_right_click(control: Control, content_fn: Callable) -> void:
	if control == null or not content_fn.is_valid():
		return
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			var content: TooltipContent = content_fn.call()
			if content:
				show_for_control(control, content)
			control.accept_event()
	)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			dismiss()
			_dim.accept_event()

func _on_keyword_inspect(keyword_id: String) -> void:
	var content := TooltipContent.for_keyword(keyword_id)
	var anchor := get_global_mouse_position()
	show_content(content, anchor)

func _place_near(global_anchor: Vector2) -> void:
	if _popup == null or not _popup.visible:
		return
	var viewport_size := get_viewport_rect().size
	var popup_size := _popup.get_combined_minimum_size()
	if _popup.size.x > 1.0:
		popup_size = _popup.size
	var local_anchor := global_anchor - global_position
	var pos := local_anchor + Vector2(12, -popup_size.y - 8)
	pos.x = clampf(pos.x, 8.0, max(8.0, viewport_size.x - popup_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, max(8.0, viewport_size.y - popup_size.y - 8.0))
	_popup.position = pos
	_popup.reset_size()
