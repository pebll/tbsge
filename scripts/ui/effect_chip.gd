extends PanelContainer

## A small chip for an ability (unit trait) or a status effect: emoji/icon (+ name, or
## + stacks for statuses). Hover shows the name and rule; right-click pins it (or opens
## the shared TooltipController popup when the owner passes one).
##
## Usage: EffectChipScript.make(effect_id, {"compact": true, "effect": status_dict,
##        "tooltip": TooltipController})

const EffectVisuals = preload("res://scripts/visu/effect_visuals.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var effect_id := ""
## Status instance ({"stacks", "turns_left"}) for status chips; empty for abilities.
var effect: Dictionary = {}
var compact := false
var tooltip_controller = null

var _hover: UiHoverTooltip = null
var _pinned := false

static func make(p_effect_id: String, opts: Dictionary = {}) -> Control:
	var chip = load("res://scripts/ui/effect_chip.gd").new()
	chip.effect_id = p_effect_id
	chip.effect = opts.get("effect", {})
	chip.compact = bool(opts.get("compact", false))
	chip.tooltip_controller = opts.get("tooltip", null)
	chip._build()
	return chip

func _build() -> void:
	var look: Dictionary = EffectVisuals.look(effect_id)
	var col: Color = look["color"]
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.lerp(UiTheme.COLOR_PANEL, 0.55)
	sb.border_color = col.darkened(0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 8
	sb.content_margin_right = 10 if not compact else 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon: Texture2D = look["icon"]
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(26, 26)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	else:
		row.add_child(_label(String(look["mark"]), 22))
	var text := ""
	if not compact:
		text = String(look["label"])
	var stacks := int(effect.get("stacks", 1))
	if stacks > 1:
		text = ("%s ×%d" % [text, stacks]) if not text.is_empty() else str(stacks)
	if not text.is_empty():
		row.add_child(_label(text, 20))
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_gui_input)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func title_text() -> String:
	var look: Dictionary = EffectVisuals.look(effect_id)
	return "%s %s" % [look["mark"], look["label"]]

func body_text() -> String:
	var look: Dictionary = EffectVisuals.look(effect_id)
	var lines := PackedStringArray()
	if not String(look["rule"]).is_empty():
		lines.append(String(look["rule"]))
	if not effect.is_empty():
		var meta := PackedStringArray()
		if int(effect.get("stacks", 1)) > 1:
			meta.append("Stacks: %d" % int(effect["stacks"]))
		var t := int(effect.get("turns_left", -1))
		meta.append("Until removed" if t < 0 else ("%d turn%s left" % [t, "" if t == 1 else "s"]))
		lines.append(" · ".join(meta))
	return "\n".join(lines)

func _ensure_hover() -> UiHoverTooltip:
	if _hover == null or not is_instance_valid(_hover):
		_hover = UiHoverTooltip.new()
		add_child(_hover)
	return _hover

func _on_enter() -> void:
	if not _pinned:
		_ensure_hover().present(title_text(), body_text(), self)

func _on_exit() -> void:
	if not _pinned and _hover != null and is_instance_valid(_hover):
		_hover.dismiss()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if tooltip_controller != null and is_instance_valid(tooltip_controller):
			if _hover != null and is_instance_valid(_hover):
				_hover.dismiss()
			var c := TooltipContent.new()
			c.title = title_text()
			c.body = body_text()
			tooltip_controller.show_for_control(self, c)
			return
		_pinned = true
		_ensure_hover().present(title_text(), body_text(), self)
		set_process_input(true)

## While pinned, the next click anywhere (or Escape) closes it.
func _input(event: InputEvent) -> void:
	if not _pinned:
		return
	var close := false
	if event is InputEventMouseButton and event.pressed:
		close = not get_global_rect().has_point(event.position) or event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close = true
	if close:
		_pinned = false
		if _hover != null and is_instance_valid(_hover):
			_hover.dismiss()

func _exit_tree() -> void:
	if _hover != null and is_instance_valid(_hover):
		_hover.dismiss()
