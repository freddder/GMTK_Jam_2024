class_name EnemyCharacter
extends Area2D

signal on_death(this: EnemyCharacter)
@export var default_speed: float = 35.0
@export var default_health: float = 100.0
@export var mass: float = 0.05

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var pending_knockback_strength: float = 0.0
var health: float = default_health


func get_knockback_strength() -> float:
	return maxf(100.0, pending_knockback_strength / mass) if pending_knockback_strength > 0.0 else 0.0


func handle_movement(delta: float) -> void:
	var speed := default_speed
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)


func handle_knockback(delta: float) -> void:
	var target_position := player.global_position
	var knockback_strength_to_apply := get_knockback_strength() * delta
	global_position -= global_position.direction_to(target_position) * knockback_strength_to_apply
	pending_knockback_strength = max(pending_knockback_strength - knockback_strength_to_apply, 0.0)


func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_knockback(delta)


func take_hit(damage: float, knockback_strength: float) -> void:
	health -= damage
	pending_knockback_strength += knockback_strength
	if health <= 0:
		die()


func die() -> void:
	on_death.emit(self)
	queue_free()
