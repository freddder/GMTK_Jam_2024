class_name EnemyCharacter
extends Area2D

signal on_death(this: EnemyCharacter)

@export var default_speed: float = 35.0
@export var default_health: float = 100.0
@export var default_mass: float = 0.05
@export var default_damage: float = 7.5
@export var default_score : int = 100
@export var default_knockback_strength: float = 40.0
@export var default_attack_cooldown: float = 0.5
@export var min_strength_scale: float = 0.5
@export var max_strength_scale: float = 2.0

@export var drop_chance: int = 10 # out of 100

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var pending_knockback_strength: float = 0.0
var health: float = 0.0
var strength_scale: float = 0.0
var should_damage_player := true
var is_overlapping_with_player := false

var is_dying := false

var enemy_type_strings: Array = [
	"worm"
]

var type := ""

func _ready() -> void:
	# Randomize enemy scale
	strength_scale = randf_range(min_strength_scale, max_strength_scale)
	health = default_health * strength_scale
	scale = Vector2(strength_scale, strength_scale)

	# Randomize enemy sprite
	type = enemy_type_strings[randi() % enemy_type_strings.size()]
	$AnimatedSprite2D.play("%s_walk" % type, 1 / strength_scale)

	Events.on_enemy_spawned.emit(self)


func get_score() -> int:
	return default_score * (strength_scale + min_strength_scale)


func get_mass() -> float:
	return default_mass * strength_scale


func get_knockback_resist() -> float:
	return pow(strength_scale, 2.0)


func get_self_knockback_strength() -> float:
	return maxf(100.0, pending_knockback_strength / get_mass()) if pending_knockback_strength > 0.0 else 0.0


func handle_movement(delta: float) -> void:
	if not should_move():
		return

	var speed := default_speed / strength_scale
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)

	$AnimatedSprite2D.flip_h = target_position.x - position.x > 0


func handle_knockback(delta: float) -> void:
	if pending_knockback_strength == 0.0:
		return

	var target_position := player.global_position
	var knockback_strength_to_apply := get_self_knockback_strength() * delta
	global_position -= global_position.direction_to(target_position) * knockback_strength_to_apply
	pending_knockback_strength = max(pending_knockback_strength - knockback_strength_to_apply, 0.0)


func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_knockback(delta)


func take_hit(damage: float, knockback_strength: float) -> void:
	if is_dying:
		return

	health -= damage
	if health <= 0:
		start_dying()
	else:
		pending_knockback_strength += knockback_strength / strength_scale
		$AnimationPlayer.play("hit_react")
		$AnimatedSprite2D.play("%s_take_hit" % type)


func drop_pickup() -> void:
	var pickup_scene: PackedScene = load("res://scenes/pickup.tscn")
	var pickup: Pickup = pickup_scene.instantiate()
	pickup.global_position = global_position
	get_tree().get_root().add_child(pickup)


func start_dying(can_drop_pickup: bool = true) -> void:
	is_dying = true
	$AnimationPlayer.play("hit_react")

	# Make sure this animation matches AnimationPlayer death animation
	$AnimatedSprite2D.play("%s_death" % type)
	await $AnimatedSprite2D.animation_finished

	$AnimationPlayer.play("death")
	await $AnimationPlayer.animation_finished

	die(can_drop_pickup)


func die(can_drop_pickup: bool) -> void:
	if can_drop_pickup and randi() % 100 <= drop_chance:
		drop_pickup()

	on_death.emit(self)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area as PlayerCharacter != null:
		is_overlapping_with_player = true
		damage_player()


func _on_area_exited(area: Area2D) -> void:
	if area as PlayerCharacter != null:
		is_overlapping_with_player = false


func get_damage() -> float:
	return default_damage * strength_scale


func get_knockback_strength() -> float:
	return default_knockback_strength * strength_scale


func damage_player() -> void:
	if not $AttackCooldownTimer.is_stopped() or is_dying:
		return

	var knockback_force := global_position.direction_to(player.global_position) * get_knockback_strength()
	player.take_hit(get_damage(), knockback_force)

	should_damage_player = false
	$AttackCooldownTimer.start(default_attack_cooldown)
	await $AttackCooldownTimer.timeout
	should_damage_player = true

	if is_overlapping_with_player:
		damage_player()


func should_move() -> bool:
	return not is_dying and not Events.is_game_terminated


func _on_animation_finished():
	if $AnimatedSprite2D.animation != "%s_death" % type:
		$AnimatedSprite2D.play("%s_walk" % type, 1 / strength_scale)
