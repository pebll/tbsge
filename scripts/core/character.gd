extends Node2D

@export var options_menu: Control

	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		print("Character clicked!")
		open_options_menu()


func open_options_menu():
	options_menu.show()
	options_menu.global_position = get_viewport().get_mouse_position()
