class_name SwordSocket
extends Node2D

@export var blade_tip: Texture2D
@export var blade_core: Texture2D
@export var hilt: Texture2D

@onready var player := get_parent() as PlayerCharacter
@onready var player_sprite: AnimatedSprite2D = player.find_child("AnimatedSprite2D")

var idle_animation_offsets: Array[Vector2] = [
	Vector2(25.0, 27.0),
	Vector2(25.0, 25.0),
	Vector2(25.0, 24.0),
	Vector2(25.0, 25.0),
]

var run_animation_offsets: Array[Vector2] = [
	Vector2(35.0, 10.0),
	Vector2(35.0, 13.0),
	Vector2(36.0, 14.0),
	Vector2(36.0, 15.0),
	Vector2(36.0, 14.0),
	Vector2(36.0, 12.0),
	Vector2(36.0, 10.0),
	Vector2(36.0, 12.0),
	Vector2(36.0, 14.0),
	Vector2(36.0, 15.0),
	Vector2(36.0, 13.0),
]

var hit_react_animation_offsets: Array[Vector2] = [
	Vector2(25.0, 26.0),
	Vector2(25.0, 26.0),
	Vector2(21.0, 22.0),
	Vector2(19.5, 19.0),
	Vector2(19.0, 19.0),
	Vector2(20.0, 22.0),
	Vector2(25.0, 31.0),
	Vector2(39.0, 20.0),
]


func _process(delta: float) -> void:
	queue_redraw()

	set_position(get_offset())
	rotation = abs(rotation) * get_horizontal_flip()


func _draw() -> void:
	var rect := Rect2(-hilt.get_size() / 2.0, hilt.get_size())
	draw_texture_rect(hilt, rect, false)

	rect.size = blade_core.get_size() + Vector2(0.0, get_blade_length())
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_core, rect, false)

	rect.size = blade_tip.get_size()
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_tip, rect, false)


func get_blade_length() -> float:
	return maxf(blade_core.get_size().x,
		player.get_charging_attack_radius() - position.length() - hilt.get_size().length() / 2.0)


func get_horizontal_flip() -> float:
	return -1.0 if player_sprite.flip_h else 1.0


func get_offset() -> Vector2:
	var return_value := Vector2.ZERO
	if player_sprite.animation == "idle":
		return_value = idle_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "run":
		return_value = run_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "hit_react":
		return_value = hit_react_animation_offsets[player_sprite.frame]

	return_value.x *= get_horizontal_flip()
	return return_value
