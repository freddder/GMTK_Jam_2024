extends Node

signal on_game_started
signal on_game_victory
signal on_game_failed
signal on_player_death

var is_game_terminated := false


func _ready() -> void:
	on_game_started.connect(_on_game_started)
	on_game_victory.connect(_on_game_terminated)
	on_game_failed.connect(_on_game_terminated)


func _on_game_started() -> void:
	is_game_terminated = false


func _on_game_terminated() -> void:
	is_game_terminated = true
