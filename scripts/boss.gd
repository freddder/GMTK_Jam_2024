class_name BossCharacter
extends Area2D

signal on_death(this: BossCharacter)

enum AttackType {
	Explosions,
	Charge
}

@export var default_speed: float = 35.0
@export var default_health: float = 1000.0
@export var default_damage: float = 19.5
@export var default_attack_cooldown: float = 1.0
@export var default_knockback_strength: float = 200.0
@export var default_score: int = 2000

@export var attack_min_delay: float = 3.0
@export var attack_max_delay: float = 15.0

@export_category("Explosion")
@export var explosion_scene: PackedScene = load("res://scenes/explosion.tscn")
@export var explosion_min_amount: int = 15
@export var explosion_max_amount: int = 25
@export var pre_explosion_delay: float = 0.75
@export var explosion_animation_duration: float = 2.5

@export_category("Charge")
@export var charge_damage: float = 45.0
@export var charge_speed: float = 600.0
@export var charge_knockback_strength: float = 300.0
@export var charge_warmup_min_duration: float = 2.5
@export var charge_warmup_max_duration: float = 6.0
@export var charge_stun_duration: float = 6.0

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var health: float = default_health
var is_dying := false
var is_casting := false
var is_stunned := false
var is_in_charge := false
var is_about_to_charge := false
var should_damage_player := true
var is_overlapping_with_player := false
var charge_target := Vector2.ZERO


func _ready() -> void:
	delay_attack()

	Events.on_game_victory.connect(on_game_victory)
	Events.on_game_failed.connect(on_game_failed)

	Events.on_boss_spawned.emit(self)

	# debug
	await get_tree().create_timer(1.0).timeout
	$AttackTimer.stop()
#	attack_explosions()
	attack_charge()


func check_charge_run_wall_collision() -> void:
	var distance_from_centre: float
	if global_position.y < 0.0:
		distance_from_centre = $AnimatedSprite2D/HeadSocket.global_position.length()
	else:
		distance_from_centre = $AnimatedSprite2D/LegsSocket.global_position.length()

	if distance_from_centre > Arena.radius:
		on_charge_hit_wall()


func _process(delta: float) -> void:
	if is_in_charge:
		check_charge_run_wall_collision()
	if is_about_to_charge:
		queue_redraw()


func draw_charging_area() -> void:
	var half_thickness := 75.0
	var radius := 9999
	var local_coords_rect: Array = [
		[ half_thickness, 0.0 ], [ half_thickness, radius ],
		[ -half_thickness, radius ], [ -half_thickness, 0.0 ]
	]

	var direction := global_position.direction_to(player.global_position)
	var angle := atan2(direction.y, direction.x) + PI / 2.0

	var local_rotated_coords_rect: Array
	for coord in local_coords_rect:
		local_rotated_coords_rect.append(Vector2(coord[0], coord[1]).rotated(angle + PI))

	var color := Color.RED
	var width := 2.0

	draw_line(local_rotated_coords_rect[0], local_rotated_coords_rect[1], color, width)
	draw_line(local_rotated_coords_rect[1], local_rotated_coords_rect[2], color, width)
	draw_line(local_rotated_coords_rect[2], local_rotated_coords_rect[3], color, width)
	draw_line(local_rotated_coords_rect[3], local_rotated_coords_rect[0], color, width)


func _draw() -> void:
	if is_about_to_charge:
		draw_charging_area()


func handle_regular_movement(delta: float) -> void:
	if not should_move():
		return

	var speed := default_speed
	var target_position := player.global_position
	global_position = global_position.move_toward(target_position, speed * delta)

	$AnimatedSprite2D.flip_h = target_position.x - position.x > 0
	$AnimatedSprite2D.play("walk")


func handle_charge_run(delta: float) -> void:
	var speed := charge_speed
	var target_position := charge_target
	global_position = global_position.move_toward(target_position, speed * delta)

	$AnimatedSprite2D.play("charge_run")


func _physics_process(delta: float) -> void:
	if not is_in_charge:
		handle_regular_movement(delta)
	else:
		handle_charge_run(delta)


func is_in_hit_react() -> bool:
	return $AnimatedSprite2D.is_playing() and $AnimatedSprite2D.animation == "hit_react"


func should_move() -> bool:
	return (not is_in_hit_react() and not is_dying and not Events.is_game_terminated and not is_casting
		and not is_in_charge and not is_stunned and player != null)


func take_hit(damage: float, knockback_strength: float) -> void:
	if is_dying:
		return

	health -= damage
	DamageNumbers.display_damage_number(damage, global_position)
	$AnimationPlayer.play("hit_react")
	if health <= 0:
		start_dying()
	else:
		$HitSFX.play()

		if not is_casting and not is_in_charge and not is_stunned:
			$AnimatedSprite2D.play("hit_react")


func start_dying(can_drop_pickup: bool = true) -> void:
	assert(not is_dying)

	on_death.emit(self)
	is_dying = true
	collision_layer = 0
	collision_mask = 0

	# Make player invincible while the boss is dying
	player.should_be_invincible = true

	$AttackTimer.stop()
	$AnimatedSprite2D.play("death")
	$DeathSFX.play()
	await $AnimatedSprite2D.animation_finished

	Events.on_game_victory.emit()
	await FreePlayManager.on_started

	player.should_be_invincible = false

	$AnimationPlayer.play("death")
	await $AnimationPlayer.animation_finished

	die()


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

	if not is_stunned:
		var strength := default_knockback_strength if not is_in_charge else charge_knockback_strength
		var damage := default_damage if not is_in_charge else charge_damage
		var knockback_force := global_position.direction_to(player.global_position) * strength
		player.take_hit(damage, knockback_force)

	should_damage_player = false
	$AttackCooldownTimer.start(default_attack_cooldown)
	await $AttackCooldownTimer.timeout
	should_damage_player = true

	if is_overlapping_with_player:
		damage_player()


func randomize_attack_delay() -> float:
	return randf_range(attack_min_delay, attack_max_delay)


func delay_attack() -> void:
	$AttackTimer.start(randomize_attack_delay())


func create_explosions() -> void:
	# Randomly spawn explosions on the whole arena
	var explosion_amount := randi_range(explosion_min_amount, explosion_max_amount)
	for idx in explosion_amount:
		var explosion: Explosion = explosion_scene.instantiate()

		var angle := randf() * 2 * PI
		var direction := Vector2(cos(angle), sin(angle))
		var distance := randf() * Arena.radius

		explosion.global_position = direction * distance
		get_parent().add_child(explosion)

	# Spawn explosions specifically around the player
	var scripted_explosion_amount := randi_range(3, 7)
	var scripted_explosion_max_distance := 200.0
	for idx in scripted_explosion_amount:
		var explosion: Explosion = explosion_scene.instantiate()

		var angle := randf() * 2 * PI
		var direction := Vector2(cos(angle), sin(angle))
		var distance := randf() * scripted_explosion_max_distance

		explosion.global_position = player.global_position + direction * distance
		get_parent().add_child(explosion)


func play_cast_animation() -> void:
	$AnimatedSprite2D.play("cast_start")
	await $AnimatedSprite2D.animation_finished
	if $AnimatedSprite2D.animation == "cast_start":
		$AnimatedSprite2D.play("cast_loop")


func attack_explosions() -> void:
	is_casting = true

	play_cast_animation()
	await get_tree().create_timer(pre_explosion_delay).timeout

	if is_dying:
		return

	create_explosions()

	await get_tree().create_timer(explosion_animation_duration).timeout
	is_casting = false
	delay_attack()


func attack_charge() -> void:
	is_casting = true
	is_about_to_charge = true

	$AnimatedSprite2D.play("charge_warmup")
	await get_tree().create_timer(randf_range(charge_warmup_min_duration, charge_warmup_max_duration)).timeout

	# Stop drawing charge area
	queue_redraw()

	if is_dying:
		return

	# Try to charge way off arena
	charge_target = global_position.direction_to(player.global_position) * 9999.0
	$AnimatedSprite2D.flip_h = charge_target.x - position.x > 0

	is_about_to_charge = false
	is_casting = false
	is_in_charge = true


func play_stun_animation() -> void:
	$AnimatedSprite2D.play("charge_stun_start")
	await $AnimatedSprite2D.animation_finished
	if $AnimatedSprite2D.animation == "charge_stun_start":
		$AnimatedSprite2D.play("charge_stun_loop")


func on_charge_hit_wall() -> void:
	is_in_charge = false
	is_stunned = true

	play_stun_animation()
	await get_tree().create_timer(charge_stun_duration).timeout

	if is_dying:
		return

	$AnimatedSprite2D.play("charge_stun_recover")
	await $AnimatedSprite2D.animation_finished

	is_stunned = false
	delay_attack()


func _on_attack_timer_timeout() -> void:
	var attack_type: AttackType = AttackType.values().pick_random()
	match attack_type:
		AttackType.Explosions: attack_explosions()
		AttackType.Charge: attack_charge()


func on_game_victory() -> void:
	$AttackTimer.stop()


func on_game_failed() -> void:
	$AttackTimer.stop()

	# Play taunt on defeated player
	play_cast_animation()
