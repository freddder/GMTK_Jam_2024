class_name PauseMenu
extends CanvasLayer


var theme_time: float = 0.0


func _ready() -> void:
	hide()
	$SettingsMenu.hide()


func _input(event: InputEvent) -> void:
	if not Events.is_game_terminated and event.is_action_pressed("pause_game"):
		toggle_pause_game()


func toggle_pause_game() -> void:
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		$PauseTheme.play()
		$PauseTheme.seek(theme_time)
		show()
		$SettingsMenu.show()
	else:
		theme_time = $PauseTheme.get_playback_position()
		$PauseTheme.stop()
		hide()
		$SettingsMenu.hide()


func _on_resume_button_pressed() -> void:
	toggle_pause_game()


func _on_settings_button_pressed() -> void:
	hide()
	#$SettingsMenu.show()
	await $SettingsMenu.visibility_changed
	show()


func _on_quit_button_pressed() -> void:
	get_tree().call_group("enemy", "queue_free")
	get_tree().call_group("boss", "queue_free")
	get_tree().call_group("pickups", "queue_free")
	get_tree().call_group("special_attack", "queue_free")
	toggle_pause_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
