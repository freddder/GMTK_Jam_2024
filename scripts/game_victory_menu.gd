class_name GameVictoryMenu
extends CanvasLayer


func _ready() -> void:
	Events.on_game_victory.connect(_on_game_victory)
	hide()


func _on_game_victory() -> void:
	show()


func _on_restart_button_pressed() -> void:
	get_tree().call_group("enemy", "queue_free")
	get_tree().change_scene_to_file("res://scenes/main_level.tscn")


func _on_main_menu_button_pressed() -> void:
	get_tree().call_group("enemy", "queue_free")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
