extends Control

func _ready():
	hide()

func _on_attack_pressed():
	print("Attack selected")
	hide()

func _on_move_pressed():
	print("Move selected")
	hide()

func _on_defend_pressed():
	print("Defend selected")
	hide()
