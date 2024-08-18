class_name PauseMenu
extends CanvasLayer


func _ready() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if !Events.is_game_terminated and event.is_action_pressed("pause_game"):
		toggle_pause_game()


func toggle_pause_game() -> void:
	get_tree().paused = !get_tree().paused
	show() if get_tree().paused else hide()


func _on_resume_button_pressed() -> void:
	toggle_pause_game()


func _on_quit_button_pressed() -> void:
	toggle_pause_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
