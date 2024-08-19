extends CanvasLayer

@export var min_volume_db: float = -30.0
@export var max_volume_db: float = 0.0

func _ready() -> void:
	var slider_value := 1.0 - (AudioServer.get_bus_volume_db(0) / min_volume_db)
	$VBoxContainer/HSlider.set_value_no_signal(slider_value)
	AudioServer.set_bus_mute(0, slider_value == 0.0)


func _on_button_pressed() -> void:
	hide()

func _on_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, lerp(min_volume_db, max_volume_db, value))
	AudioServer.set_bus_mute(0, value == 0.0)
