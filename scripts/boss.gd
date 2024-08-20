class_name BossCharacter
extends Area2D

@export var default_speed: float = 35.0
@export var default_health: float = 100.0
@export var default_damage: float = 7.5
@export var default_attack_cooldown: float = 0.5
@export var default_knockback_strength: float = 40.0

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var health: float = default_health
var is_dying := false
var is_casting := false
var should_damage_player := true
var is_overlapping_with_player := false


func _physics_process(delta: float) -> void:
	handle_movement(delta)


func handle_movement(delta: float) -> void:
	if not should_move() or not player:
		return

	var speed := default_speed
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)

	$AnimatedSprite2D.flip_h = target_position.x - position.x > 0
	$AnimatedSprite2D.play("walk")


func should_move() -> bool:
	return not is_dying and not Events.is_game_terminated and not is_casting

func take_hit(damage: float, knockback_strength: float) -> void:
	if is_dying:
		return

	health -= damage
	$AnimationPlayer.play("hit_react")
	if health <= 0:
		start_dying()
	else:
		$HitSFX.play()


func start_dying(can_drop_pickup: bool = true) -> void:
	assert(not is_dying)

	is_dying = true
	collision_layer = 0
	collision_mask = 0

	$AnimatedSprite2D.play("death")
	$DeathSFX.play()
	await $AnimatedSprite2D.animation_finished

	$AnimationPlayer.play("death")
	await $AnimationPlayer.animation_finished

	# TODO wait on_free_play_started
	#die()


func die() -> void:
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area as PlayerCharacter != null:
		is_overlapping_with_player = true
		damage_player()


func _on_area_exited(area: Area2D) -> void:
	if area as PlayerCharacter != null:
		is_overlapping_with_player = false


func damage_player() -> void:
	if not $AttackCooldownTimer.is_stopped() or is_dying:
		return

	var knockback_force := global_position.direction_to(player.global_position) * default_knockback_strength
	player.take_hit(default_damage, knockback_force)

	should_damage_player = false
	$AttackCooldownTimer.start(default_attack_cooldown)
	await $AttackCooldownTimer.timeout
	should_damage_player = true

	if is_overlapping_with_player:
		damage_player()
