extends CanvasLayer

@export var min_volume_db: float = -30.0
@export var max_volume_db: float = 0.0

var bgm_bus_idx := 1
var sfx_bus_idx := 2

func _ready() -> void:
	var bgm_slider_value := 1.0 - (AudioServer.get_bus_volume_db(bgm_bus_idx) / min_volume_db)
	$OptionsTab/MusicSlider.set_value_no_signal(bgm_slider_value)
	AudioServer.set_bus_mute(bgm_bus_idx, bgm_slider_value == 0.0)

	var sfx_slider_value := 1.0 - (AudioServer.get_bus_volume_db(sfx_bus_idx) / min_volume_db)
	$OptionsTab/MusicSlider.set_value_no_signal(sfx_slider_value)
	AudioServer.set_bus_mute(sfx_bus_idx, sfx_slider_value == 0.0)


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(bgm_bus_idx, lerp(min_volume_db, max_volume_db, value))
	AudioServer.set_bus_mute(bgm_bus_idx, value == 0.0)


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(sfx_bus_idx, lerp(min_volume_db, max_volume_db, value))
	AudioServer.set_bus_mute(sfx_bus_idx, value == 0.0)


func _on_options_button_pressed():
	$OptionsTab.show()
	$ControlsTab.hide()
	$CreditsTab.hide()


func _on_controls_button_pressed():
	$OptionsTab.hide()
	$ControlsTab.show()
	$CreditsTab.hide()


func _on_credits_button_pressed():
	$OptionsTab.hide()
	$ControlsTab.hide()
	$CreditsTab.show()
