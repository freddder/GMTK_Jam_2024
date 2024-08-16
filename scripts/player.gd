class_name Player extends Area2D

@export var default_walk_speed: float = 300.0

func handle_movement(delta: float) -> void:
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed := default_walk_speed
	var velocity := move_direction * walk_speed * delta
	position += velocity
	
func check_arena_bounds() -> void:
	var arena_size := 500.0
	var distance_from_center := position.length()
	if distance_from_center > arena_size:
		position = position.normalized() * arena_size

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	check_arena_bounds()
