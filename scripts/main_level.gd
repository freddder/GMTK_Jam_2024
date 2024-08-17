extends Node

func _ready() -> void:
	Events.on_game_started.emit()
