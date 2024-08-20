class_name GameVictoryMenu
extends CanvasLayer


func _ready() -> void:
	Events.on_game_victory.connect(_on_game_victory)
	hide()


func _on_game_victory() -> void:
	await get_tree().create_timer(1.0).timeout
	show()
	get_tree().paused = true


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().call_group("enemy", "queue_free")
	get_tree().change_scene_to_file("res://scenes/main_level.tscn")


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().call_group("enemy", "queue_free")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_free_play_button_pressed() -> void:
	get_tree().paused = false
	hide()
	Events.is_game_terminated = false
	FreePlayManager.start_scaling()
