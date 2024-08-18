class_name GameOverMenu
extends CanvasLayer


func _ready() -> void:
	Events.on_game_failed.connect(_on_game_failed)
	hide()


func _on_game_failed() -> void:
	show()


func _on_restart_button_pressed() -> void:
	get_tree().call_group("enemy", "queue_free")
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	get_tree().call_group("enemy", "queue_free")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
