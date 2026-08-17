class_name UiInteractable
extends Node

## Shared Control hover/select/entry juice. Attach as a child of the target Control
## (or call bind()). World tiles/legions are intentionally out of scope.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

signal hovered_changed(hovered: bool)
signal selected_changed(selected: bool)

var target: Control = null
var policy: UiTooltipPolicy = null
var tooltip_provider: Callable = Callable()
var enable_hover := true
var enable_select := true
var enable_entry := true
var selection_marker_enabled := true

var _hovered := false
var _selected := false
var _tween: Tween
var _marker: Panel
var _rest_modulate := Color.WHITE
var _bound := false

func _ready() -> void:
	if target == null and get_parent() is Control:
		bind(get_parent() as Control)

func bind(control: Control, tooltip_policy: UiTooltipPolicy = null) -> void:
	target = control
	if tooltip_policy:
		policy = tooltip_policy
	if target == null or _bound:
		return
	_bound = true
	_rest_modulate = target.modulate
	target.mouse_entered.connect(_on_mouse_entered)
	target.mouse_exited.connect(_on_mouse_exited)
	target.gui_input.connect(_on_gui_input)
	if not target.resized.is_connected(_on_target_resized):
		target.resized.connect(_on_target_resized)
	_ensure_marker()
	_sync_pivot()

func set_policy(tooltip_policy: UiTooltipPolicy) -> void:
	policy = tooltip_policy

func set_tooltip_provider(provider: Callable) -> void:
	tooltip_provider = provider

func is_hovered() -> bool:
	return _hovered

func is_selected() -> bool:
	return _selected

func play_scene_entry() -> void:
	if target == null or not enable_entry:
		return
	_sync_pivot()
	target.scale = Vector2(UiTheme.INTERACT_ENTRY_SCALE, UiTheme.INTERACT_ENTRY_SCALE)
	_kill_tween()
	_tween = target.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "scale", Vector2.ONE, UiTheme.INTERACT_ENTRY_DURATION)

func play_scene_leave() -> void:
	## Immediate despawn — no exit tween (per UX framework).
	_kill_tween()
	_hovered = false
	if _selected:
		set_selected(false)
	if target:
		target.hide()

func set_selected(selected: bool, from_input: bool = false) -> void:
	if from_input and not enable_select:
		return
	if _selected == selected:
		return
	_selected = selected
	selected_changed.emit(_selected)
	_apply_selection_visual()
	_tween_to_scale(_target_scale())
	if policy == null:
		return
	if _selected:
		policy.select(target, tooltip_provider)
	else:
		policy.deselect(target)

func toggle_selected() -> void:
	set_selected(not _selected, true)

func _on_mouse_entered() -> void:
	if target == null or not enable_hover:
		return
	_hovered = true
	hovered_changed.emit(true)
	_tween_to_scale(_target_scale())
	if policy and tooltip_provider.is_valid():
		policy.set_hover_tooltip_provider(tooltip_provider)
		policy.notify_hover_entered(target)

func _on_mouse_exited() -> void:
	if target == null:
		return
	_hovered = false
	hovered_changed.emit(false)
	_tween_to_scale(_target_scale())
	if policy:
		policy.notify_hover_exited(target)

func _on_gui_input(event: InputEvent) -> void:
	if not enable_select or target == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_selected()
		target.accept_event()

func _on_target_resized() -> void:
	_sync_pivot()
	_layout_marker()

func _target_scale() -> float:
	if _selected:
		return UiTheme.INTERACT_SELECT_SCALE
	if _hovered:
		return UiTheme.INTERACT_HOVER_SCALE
	return 1.0

func _tween_to_scale(scale_value: float) -> void:
	if target == null:
		return
	_sync_pivot()
	_kill_tween()
	var duration := UiTheme.INTERACT_SELECT_DURATION if _selected else UiTheme.INTERACT_HOVER_DURATION
	_tween = target.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "scale", Vector2(scale_value, scale_value), duration)

func _apply_selection_visual() -> void:
	if target == null:
		return
	if _selected:
		target.modulate = UiTheme.INTERACT_SELECT_MODULATE
	else:
		target.modulate = _rest_modulate
	if _marker:
		_marker.visible = selection_marker_enabled and _selected

func _ensure_marker() -> void:
	if target == null or _marker != null:
		return
	_marker = Panel.new()
	_marker.name = "SelectMarker"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.95, 0.82, 0.28, 1.0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	_marker.add_theme_stylebox_override("panel", sb)
	target.add_child(_marker)
	_layout_marker()

func _layout_marker() -> void:
	if _marker == null or target == null:
		return
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.offset_left = -2
	_marker.offset_top = -2
	_marker.offset_right = 2
	_marker.offset_bottom = 2

func _sync_pivot() -> void:
	if target:
		target.pivot_offset = target.size * 0.5

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null
