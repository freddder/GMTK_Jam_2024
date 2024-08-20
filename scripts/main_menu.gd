extends Node

func _ready() -> void:
	$SettingsMenu.hide()


func _input(event: InputEvent) -> void:
	if $SettingsMenu.visible and event.is_action_pressed("pause_game"):
		_on_main_menu_button_pressed()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_level.tscn")


func _on_settings_button_pressed() -> void:
	$HUD.hide()
	$SettingsMenu.show()
	await $SettingsMenu.visibility_changed
	$HUD.show()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_main_menu_button_pressed():
	$HUD.show()
	$SettingsMenu.hide()
	await $SettingsMenu.visibility_changed
	$HUD.hide()
