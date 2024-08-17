class_name EnemyCharacter extends Area2D

signal on_death(this: EnemyCharacter)

@export var default_speed: float = 35.0
@export var default_health: float = 100.0

@onready var player : PlayerCharacter = get_tree().get_first_node_in_group("player")

var pending_knockback_strength: float = 0.0
var health: float = default_health

func _physics_process(delta: float) -> void:
	var speed := default_speed
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)
	global_position -= global_position.direction_to(target_position) * pending_knockback_strength
	pending_knockback_strength = 0.0
	
func take_hit(damage_amount: float, knockback_strength: float):
	health -= damage_amount
	pending_knockback_strength += knockback_strength
	if health <= 0:
		queue_free()
