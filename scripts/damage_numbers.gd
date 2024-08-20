extends Node


func display_damage_number(value: int, position: Vector2):
	var number = Label.new()
	number.global_position = position
	number.text = str(value)
	number.z_index = 5
	number.label_settings = LabelSettings.new()
	
	var damage_color = "#FFF"
	var label_size = 18
	if value > 120: 
		damage_color = Color.FIREBRICK
		label_size = 32
	elif value > 60: 
		damage_color = Color.DARK_ORANGE
		label_size = 24
	
	number.label_settings.font = preload("res://content/fonts/Adumu.ttf")
	number.label_settings.font_color = damage_color
	number.label_settings.font_size = label_size
	number.label_settings.outline_color = "#000"
	number.label_settings.outline_size = 1
	
	call_deferred("add_child", number)
	
	await number.resized
	number.pivot_offset = Vector2(number.size / 2)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 24, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "position:y", number.position.y, 0.5).set_ease(Tween.EASE_IN).set_delay(0.25)
	tween.tween_property(number, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN).set_delay(0.5)
	
	await tween.finished
	number.queue_free()
