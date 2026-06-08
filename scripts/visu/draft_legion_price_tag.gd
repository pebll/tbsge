class_name DraftLegionPriceTag
extends Node2D

const ICON_COIN := preload("res://assets/icons/base_icons_sprites/coin.png")

func _ready() -> void:
	z_index = 1100

func set_cost(cost: int) -> void:
	for child in get_children():
		child.queue_free()
	var icon := Sprite2D.new()
	icon.texture = ICON_COIN
	icon.scale = Vector2(0.09, 0.09)
	icon.position = Vector2(-28, 0)
	add_child(icon)
	var label := Label.new()
	label.text = "%d" % cost
	label.position = Vector2(-4, -18)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("outline_color", Color(0.1, 0.08, 0.05, 0.9))
	add_child(label)
	position = Vector2(0, -95)
