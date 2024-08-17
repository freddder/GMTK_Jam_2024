class_name EnemyCharacter extends Area2D

signal on_death(this: EnemyCharacter)

@export var default_speed: float = 35.0

@onready var player : PlayerCharacter = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	var speed := default_speed
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)
