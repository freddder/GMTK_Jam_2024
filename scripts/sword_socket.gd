class_name SwordSocket
extends Node2D

@export var blade_tip: Texture2D
@export var blade_core: Texture2D
@export var hilt: Texture2D
@export var default_rotation: float = 30.0

@onready var player := get_parent() as PlayerCharacter
@onready var player_sprite: AnimatedSprite2D = player.find_child("AnimatedSprite2D")

var attack_radius_before_shrink: float = 0.0
var last_attack_radius: float = 0.0
var shrink_total_time: float = 0.3
var shrink_start_time: float = 0.0
var is_shrinking := false

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


var thrust_start_animation_offsets: Array[Vector2] = [
	Vector2(25.5, 28.0),
	Vector2(18.5, 32.5),
	Vector2(1.5, 36.0),
	Vector2(-13.0, 34.0),
]

var thrust_loop_animation_offsets: Array[Vector2] = [
	Vector2(-13.0, 34.0),
	Vector2(-13.0, 34.5),
	Vector2(-13.0, 34.0),
	Vector2(-13.0, 34.5),
	Vector2(-13.0, 34.0),
]

var thrust_finish_animation_offsets: Array[Vector2] = [
	Vector2(-13.0, 34.0),
	Vector2(-14.5, 34.0),
	Vector2(-16.0, 34.0),
	Vector2(-16.5, 33.0),
	Vector2(6.0, 33.5),
	Vector2(58.0, 35.5),
	Vector2(86.0, 35.5),
	Vector2(86.0, 35.5),
	Vector2(86.0, 35.5),
	Vector2(86.0, 35.5),
	Vector2(87.0, 35.5),
	Vector2(87.0, 35.5),
	Vector2(86.0, 40.0),
	Vector2(78.0, 43.0),
	Vector2(54.5, 41.0),
	Vector2(37.5, 36.0),
	Vector2(27.0, 28.0),
]


var ground_pound_start_animation_offsets: Array[Vector2] = [
	Vector2(23.0, 33.0),
	Vector2(24.0, 33.0),
	Vector2(27.0, 32.0),
	Vector2(31.0, 29.5),
	Vector2(36.5, 14.0),
	Vector2(28.0, 1.0),
	Vector2(21.0, -3.0),
]

var ground_pound_loop_animation_offsets: Array[Vector2] = [
	Vector2(20.0, -3.0),
	Vector2(19.0, -4.0),
	Vector2(19.2, -4.1),
	Vector2(19.0, -4.0),
	Vector2(19.5, -3.5),
	Vector2(20.0, -3.0),
]

var ground_pound_finish_animation_offsets: Array[Vector2] = [
	Vector2(20.0, -3.0),
	Vector2(19.0, -4.0),
	Vector2(29.5, -1.0),
	Vector2(52.0, 17.0),
	Vector2(52.0, 16.0),
	Vector2(52.0, 16.0),
	Vector2(52.0, 16.0),
	Vector2(52.0, 16.0),
	Vector2(52.0, 16.0),
	Vector2(52.0, 16.0),
	Vector2(35.5, 31.0),
	Vector2(18.0, 26.0),
]

var death_animation_offsets: Array[Vector2] = [
	Vector2(23.5, 26.0),
	Vector2(22.0, 26.5),
	Vector2(21.0, 25.5),
	Vector2(29.0, 28.0),
	Vector2(36.0, 28.0),
	Vector2(49.0, 19.5),
	Vector2(61.0, 30.0),
	Vector2(69.0, 46.0),
	Vector2(69.0, 46.0),
	Vector2(69.5, 46.0),
	Vector2(69.5, 46.0),
]

var thrust_start_animation_rotations: Array[float] = [
	default_rotation,
	55,
	88,
	90
]

var thrust_loop_animation_rotations: Array[float] = [
	90,
	92,
	90,
	88,
	90,
	92,
]

var thrust_finish_animation_rotations: Array[float] = [
	90,
	92,
	94,
	96,
	90,
	88,
	90,
	90,
	90,
	90,
	90,
	90,
	80,
	72,
	65,
	40,
	default_rotation
]


var ground_pound_start_animation_rotations: Array[float] = [
	50,
	55,
	60,
	55,
	30,
	-20,
	-25,
]

var ground_pound_loop_animation_rotations: Array[float] = [
	-25,
	-28,
	-26,
	-24,
	-26,
	-25,
]

var ground_pound_finish_animation_rotations: Array[float] = [
	-28,
	-30,
	30,
	45,
	55,
	58,
	65,
	70,
	40,
	30,
	20,
	default_rotation,
]

var death_animation_rotations: Array[float] = [
	default_rotation,
	28,
	-10,
	0,
	15,
	50,
	70,
	85,
	90,
	90,
	90,
]


func _process(delta: float) -> void:
	queue_redraw()

	set_position(get_custom_offset())
	rotation = get_custom_rotation() * get_horizontal_flip()


func _draw() -> void:
	var rect := Rect2(-hilt.get_size() / 2.0, hilt.get_size())
	draw_texture_rect(hilt, rect, false)

	rect.size = blade_core.get_size() + Vector2(0.0, compute_blade_length())
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_core, rect, false)

	rect.size = blade_tip.get_size()
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_tip, rect, false)


func compute_blade_length() -> float:
	var default_radius := blade_core.get_size().x
	var radius := player.get_charging_attack_radius()

	if last_attack_radius > radius or is_shrinking:
		if not is_shrinking:
			is_shrinking = true
			shrink_start_time = Time.get_ticks_msec()
			attack_radius_before_shrink = last_attack_radius

		var shrink_time := (Time.get_ticks_msec() - shrink_start_time) / 1000.0
		var alpha := minf(shrink_time / shrink_total_time, 1.0)
		radius = lerp(attack_radius_before_shrink, default_radius, alpha)

		if alpha == 1.0:
			is_shrinking = false

	var return_value := maxf(default_radius, radius - position.length() - hilt.get_size().length() / 2.0)
	last_attack_radius = radius

	return return_value


func get_horizontal_flip() -> float:
	return -1.0 if player_sprite.flip_h else 1.0


func get_custom_offset() -> Vector2:
	var return_value := Vector2.ZERO
	if player_sprite.animation == "idle":
		return_value = idle_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "run":
		return_value = run_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "hit_react":
		return_value = hit_react_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "thrust_start":
		return_value = thrust_start_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "thrust_loop":
		return_value = thrust_loop_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "thrust_finish":
		return_value = thrust_finish_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_start":
		return_value = ground_pound_start_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_loop":
		return_value = ground_pound_loop_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_finish":
		return_value = ground_pound_finish_animation_offsets[player_sprite.frame]
	elif player_sprite.animation == "death":
		return_value = death_animation_offsets[player_sprite.frame]

	return_value.x *= get_horizontal_flip()
	return return_value


func get_custom_rotation() -> float:
	var return_value := default_rotation
	if player_sprite.animation == "thrust_start":
		return_value = thrust_start_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "thrust_loop":
		return_value = thrust_loop_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "thrust_finish":
		return_value = thrust_finish_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_start":
		return_value = ground_pound_start_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_loop":
		return_value = ground_pound_loop_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "ground_pound_finish":
		return_value = ground_pound_finish_animation_rotations[player_sprite.frame]
	elif player_sprite.animation == "death":
		return_value = death_animation_rotations[player_sprite.frame]

	return deg_to_rad(return_value)
