extends Node

func _ready() -> void:
	$SettingsMenu.hide()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_level.tscn")


func _on_settings_button_pressed() -> void:
	$HUD.hide()
	$SettingsMenu.show()
	await $SettingsMenu.visibility_changed
	$HUD.show()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
