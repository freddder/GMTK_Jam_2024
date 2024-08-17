extends Node

func _ready() -> void:
	Events.on_game_started.emit()
	var collision_circle := $CollisionShape2D.shape as CircleShape2D
	collision_circle.radius = Arena.radius
