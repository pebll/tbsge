class_name UiTooltipPolicy
extends RefCounted

## Coordinates when hover tooltips may appear vs selection-locked tooltips.
## Hover tooltips only while nothing is selected; select keeps tooltip until deselect.

signal selection_changed(has_selection: bool)

var _selected: Object = null
var _hover_tooltip_fn: Callable = Callable()
var _selected_tooltip_fn: Callable = Callable()
var _show_fn: Callable = Callable()
var _hide_fn: Callable = Callable()

func configure(
	show_fn: Callable,
	hide_fn: Callable
) -> void:
	_show_fn = show_fn
	_hide_fn = hide_fn

func has_selection() -> bool:
	return _selected != null and is_instance_valid(_selected)

func set_hover_tooltip_provider(provider: Callable) -> void:
	_hover_tooltip_fn = provider

func clear_hover_tooltip_provider() -> void:
	_hover_tooltip_fn = Callable()

func notify_hover_entered(source: Object) -> void:
	if has_selection():
		return
	if not _hover_tooltip_fn.is_valid():
		return
	var payload = _hover_tooltip_fn.call(source)
	if payload == null:
		return
	if _show_fn.is_valid():
		_show_fn.call(source, payload)

func notify_hover_exited(source: Object) -> void:
	if has_selection():
		return
	if _hide_fn.is_valid():
		_hide_fn.call(source)

func select(source: Object, tooltip_provider: Callable = Callable()) -> void:
	if has_selection() and _selected != source:
		deselect()
	_selected = source
	_selected_tooltip_fn = tooltip_provider
	selection_changed.emit(true)
	if tooltip_provider.is_valid():
		var payload = tooltip_provider.call(source)
		if payload != null and _show_fn.is_valid():
			_show_fn.call(source, payload)

func deselect(source: Object = null) -> void:
	if source != null and _selected != source:
		return
	var prev := _selected
	_selected = null
	_selected_tooltip_fn = Callable()
	selection_changed.emit(false)
	if prev != null and _hide_fn.is_valid():
		_hide_fn.call(prev)

func clear() -> void:
	deselect()
