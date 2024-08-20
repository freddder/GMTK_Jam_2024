extends CanvasLayer

@export var min_volume_db: float = -30.0
@export var max_volume_db: float = 0.0

func _ready() -> void:
	var slider_value := 1.0 - (AudioServer.get_bus_volume_db(0) / min_volume_db)
	$OptionsTab/MusicSlider.set_value_no_signal(slider_value)
	AudioServer.set_bus_mute(0, slider_value == 0.0)


func _on_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, lerp(min_volume_db, max_volume_db, value))
	AudioServer.set_bus_mute(0, value == 0.0)


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
