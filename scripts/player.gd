class_name PlayerCharacter
extends Area2D

class AttackZoneData:
	var radius: float = 0.0
	var thickness: float = 0.0
	var angle: float = 0.0
	var start_angle: float = 0.0
	var end_angle: float = 0.0

enum AttackType {
	Invalid,
	Swing,
	Thrust,
	GroundPound,
}

@export var default_walk_speed: float = 300.0
@export var default_camera_zoom := Vector2(1.2, 1.2)
@export var knockback_limit: float = 1000.0
@export var default_health: float = 100.0
@export var camera_offset_distance_from_arena_bounds: float = 250.0

@export_category("Swing")
@export var default_swing_radius: float = 90.0
@export var default_swing_angle: float = 60.0
@export var swing_angle_limit: float = 150.0
@export var default_swing_damage: float = 35.0
@export var default_swing_knockback_strength: float = 20.0
@export var default_swing_cooldown: float = 1

@export_category("Thrust")
@export var default_thrust_radius: float = 130.0
@export var default_thrust_thickness: float = 30.0
@export var default_thrust_damage: float = 40.0
@export var default_thrust_knockback_strength: float = 40
@export var default_thrust_cooldown: float = 1.5

@export_category("Ground Pound")
@export var default_ground_pound_radius: float = 50.0
@export var default_ground_pound_damage: float = 30.0
@export var default_ground_pound_knockback_strength: float = 15.0
@export var default_ground_pound_cooldown: float = 2.0

@export_category("Charge")
@export var charge_speed: float = 1.0
@export var charge_exp: float = 0.6
@export var charge_delay: float = 0.5

@export_category("Dash")
@export var default_dash_duration: float = 0.3
@export var default_dash_speed: float = 800.0
@export var default_dash_cooldown: float = 0.4
@export var dash_motion_trail_copy_lifespan: float = 0.2
@export var dash_motion_trail_creation_cooldown: float = 0.02

var mouse_direction_angle_rad: float = 0.0
var attack_charge_start_time: float = 0.0
var charging_attack_type := AttackType.Invalid

var active_attack_zone_data: AttackZoneData
var attack_area_color := Color.RED
var attack_area_arc_segments: float = 0.0

var health := default_health
var last_non_zero_movement_direction := Vector2.ZERO
var pending_knockback_forces: Array[Vector2]

var last_attack_end_time: Dictionary = {
	AttackType.Swing: -2.0,
	AttackType.Thrust: -2.0,
	AttackType.GroundPound: -2.0,
}

var last_dash_start_time: float = -2.0
var last_dash_end_time: float = -2.0
var is_dashing := false
var dash_direction := Vector2.ZERO


func _ready() -> void:
	var zoom: float = default_camera_zoom.x * (get_viewport_rect().size.x / 1280)
	default_camera_zoom = Vector2(zoom, zoom)

	set_camera_zoom(default_camera_zoom, 0.0)
	clear_attack_data()


func handle_regular_movement(delta: float) -> void:
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed := default_walk_speed
	var velocity := move_direction * walk_speed * delta
	position += velocity

	if !velocity.is_zero_approx():
		last_non_zero_movement_direction = move_direction
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")


func handle_dash_movement(delta: float) -> bool:
	var dashing_time := (Time.get_ticks_msec() - last_dash_start_time) / 1000.0
	var dashing_remaining_time := default_dash_duration - dashing_time
	is_dashing = dashing_remaining_time > 0.0
	if !is_dashing:
		on_dash_finished()
		return false

	position += dash_direction * default_dash_speed * delta
	return true


func handle_movement(delta: float) -> void:
	if is_dashing and handle_dash_movement(delta):
		pass
	else:
		handle_regular_movement(delta)


func check_arena_bounds() -> void:
	var distance_from_center := position.length()
	if distance_from_center > Arena.radius:
		position = position.normalized() * Arena.radius


func get_knockback_force(force: Vector2) -> Vector2:
	var min_acceleration: float = 500.0
	return force.normalized() * minf(force.length(), min_acceleration)


func handle_knockback(delta: float) -> void:
	var forces_to_remove: Array[int]
	for idx in pending_knockback_forces.size():
		var pending_force := pending_knockback_forces[idx]
		var applied_force := get_knockback_force(pending_force) * delta * 20.0
		position += applied_force
		pending_knockback_forces[idx] -= applied_force

		# Remove if it was completely used up
		if (pending_knockback_forces[idx].is_zero_approx() or
			sign(pending_force.x) != sign(pending_knockback_forces[idx].x) or
			sign(pending_force.y) != sign(pending_knockback_forces[idx].y)):
			forces_to_remove.push_back(idx)

	for idx in forces_to_remove:
		pending_knockback_forces.remove_at(idx)


func _physics_process(delta: float) -> void:
	if is_alive():
		if should_move():
			handle_movement(delta)

		handle_knockback(delta)
		check_arena_bounds()


func draw_attack_zone_swing_implementation() -> void:
	var origin := Vector2.ZERO
	var offset_angle := -PI / 2.0
	var width := 2.0

	draw_line(origin, Vector2(
			cos(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, width)

	draw_line(origin, Vector2(
			cos(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, width)

	draw_arc(origin, active_attack_zone_data.radius,
		active_attack_zone_data.start_angle + offset_angle, active_attack_zone_data.end_angle + offset_angle,
		attack_area_arc_segments, attack_area_color, width)


func draw_attack_zone_thrust_implementation() -> void:
	var half_thickness := active_attack_zone_data.thickness / 2.0
	var radius := active_attack_zone_data.radius
	var local_coords_rect: Array = [
		[ half_thickness, 0.0 ], [ half_thickness, radius ],
		[ -half_thickness, radius ], [ -half_thickness, 0.0 ]
	]

	var packed_array: PackedVector2Array
	for coord in local_coords_rect:
		packed_array.append(Vector2(coord[0], coord[1]).rotated(active_attack_zone_data.angle + PI))

	var colors: PackedColorArray
	colors.append(Color.RED)

	draw_polygon(packed_array, colors)


func draw_attack_zone_ground_pound_implementation() -> void:
	var origin := Vector2.ZERO
	var width := 2.0

	draw_circle(origin, active_attack_zone_data.radius, attack_area_color, width)


func _draw() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone_swing_implementation()
		AttackType.Thrust: draw_attack_zone_thrust_implementation()
		AttackType.GroundPound: draw_attack_zone_ground_pound_implementation()

func draw_attack_zone_swing(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data
	attack_area_arc_segments = maxf(6, active_attack_zone_data.radius / 5)

	queue_redraw()


func draw_attack_zone_thrust(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data

	queue_redraw()


func draw_attack_zone_ground_pound(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data

	queue_redraw()


func handle_mouse_direction() -> void:
	var mouse_position := get_local_mouse_position()

	# Add half PI (90 degrees) because sprite looks upwards by default,
	# but rotation at 0 radians faces west
	mouse_direction_angle_rad = atan2(mouse_position.y, mouse_position.x) + PI / 2.0
	$MouseDirectionSprite.rotation = mouse_direction_angle_rad


func get_facing_direction() -> int:
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Use current side direction if it's not zero, fallback on last non-zero direction otherwise;
	# if it's zero as well, add 0.1 so that it'll be positive, i.e. right
	return sign(move_direction.x if move_direction.x != 0.0 && should_move()
		else last_non_zero_movement_direction.x + 0.1)

func handle_animation_side() -> void:
	$AnimatedSprite2D.flip_h = get_facing_direction() < 0

func get_attack_zone_data_swing() -> AttackZoneData:
	var charge_power := get_charge_power()
	var attack_zone_data: AttackZoneData = AttackZoneData.new()

	var radius_multiplier := maxf(1.0, pow(charge_power, 1.13))
	attack_zone_data.radius = default_swing_radius * radius_multiplier

	var angle_multiplier := maxf(1.0, pow(charge_power, 1.13))
	attack_zone_data.angle = minf(deg_to_rad(default_swing_angle) * angle_multiplier, deg_to_rad(swing_angle_limit))

	attack_zone_data.start_angle = mouse_direction_angle_rad - attack_zone_data.angle / 2
	attack_zone_data.end_angle = mouse_direction_angle_rad + attack_zone_data.angle / 2

	return attack_zone_data


func get_attack_zone_data_thrust() -> AttackZoneData:
	var charge_power := get_charge_power()
	var attack_zone_data: AttackZoneData = AttackZoneData.new()

	var radius_multiplier := maxf(1.0, pow(charge_power, 1.13))
	attack_zone_data.radius = default_thrust_radius * radius_multiplier

	var thickness_offset := log(pow(charge_power, 7))
	attack_zone_data.thickness = default_thrust_thickness + thickness_offset

	attack_zone_data.angle = mouse_direction_angle_rad
	return attack_zone_data


func get_attack_zone_data_ground_pound() -> AttackZoneData:
	var charge_power := get_charge_power()
	var attack_zone_data: AttackZoneData = AttackZoneData.new()

	var radius_multiplier := maxf(1.0, pow(charge_power, 1.13))
	attack_zone_data.radius = default_swing_radius * radius_multiplier

	return attack_zone_data


func handle_attack_zone() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone_swing(get_attack_zone_data_swing())
		AttackType.Thrust: draw_attack_zone_thrust(get_attack_zone_data_thrust())
		AttackType.GroundPound: draw_attack_zone_ground_pound((get_attack_zone_data_ground_pound()))

	if is_charging_attack():
		var zoom_power := get_charge_power() - 1.0
		var additional_zoom := zoom_power * 0.2
		var camera_zoom := default_camera_zoom - Vector2(additional_zoom, additional_zoom)
		set_camera_zoom(camera_zoom, 0.0)


func handle_charging_sound() -> void:
	if get_charge_power() > 1.0:
		if not $ChargeSFX.playing:
			$ChargeSFX.play()

		$ChargeSFX.pitch_scale = get_charge_power() / 2.0


func handle_camera_view() -> void:
	# Arena is at 0,0, so getting the player position length is effectively getting how far they
	# went off arena center; same thing applies to direction
	var distance_from_center := global_position.length()
	var direction := global_position.normalized()

	var max_distance_from_centre := Arena.radius - camera_offset_distance_from_arena_bounds
	var target_point := minf(max_distance_from_centre, distance_from_center) * direction
	$Camera2D.offset = target_point - $Camera2D.global_position


func _process(delta: float) -> void:
	if is_alive():
		handle_mouse_direction()
		handle_attack_zone()
		handle_charging_sound()
		handle_animation_side()
		handle_camera_view()


func set_camera_zoom(zoom: Vector2, duration: float = 0.2) -> void:
	if duration > 0.0:
		var tween := get_tree().create_tween()
		tween.tween_property($Camera2D, "zoom", zoom, duration)
	else:
		$Camera2D.set_zoom(zoom)


func clear_attack_data() -> void:
	$ChargeSFX.stop()

	$AttackShapeCast2D.shape = null
	$AttackShapeCast2D.position = Vector2.ZERO
	$AttackShapeCast2D.rotation = 0
	active_attack_zone_data = null
	charging_attack_type = AttackType.Invalid

	# Clear whatever we have drawn so far
	queue_redraw()

	# Return to original camera zoom
	set_camera_zoom(default_camera_zoom, 0.4)


func on_attack_started_charging(attack_type: AttackType) -> void:
	# TODO: replace with attack animation
	$AnimatedSprite2D.play("idle")

	charging_attack_type = attack_type
	attack_charge_start_time = Time.get_ticks_msec()


func save_attack_end_time() -> void:
	assert(last_attack_end_time.has(charging_attack_type))
	last_attack_end_time[charging_attack_type] = Time.get_ticks_msec()


func handle_sound_on_attack_release() -> void:
	match charging_attack_type:
		AttackType.Swing: $SwingSFX.play()
		AttackType.Thrust: pass
		AttackType.GroundPound: pass


func on_attack_released() -> void:
	save_attack_end_time()
	handle_sound_on_attack_release()
	clear_attack_data()


func handle_primary_attack_input(event: InputEvent) -> void:
	var attack_type := AttackType.Swing
	var action_name := "primary_attack"
	if (!is_charging_attack()
		&& !is_attack_on_cooldown(attack_type)
		&& event.is_action_pressed(action_name)):
		on_attack_started_charging(attack_type)

	if charging_attack_type == attack_type && event.is_action_released(action_name):
		var attack_circle_shape := CircleShape2D.new()
		$AttackShapeCast2D.shape = attack_circle_shape
		attack_circle_shape.radius = active_attack_zone_data.radius

		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var enemy := $AttackShapeCast2D.get_collider(collider_index) as EnemyCharacter
			var direction_to := global_position.direction_to(enemy.global_position)
			var angle_to := atan2(direction_to.y, direction_to.x) + PI / 2.0
			if active_attack_zone_data.start_angle <= angle_to && active_attack_zone_data.end_angle >= angle_to:
				enemy.take_hit(scale_damage(default_swing_damage), scale_knockback(default_swing_knockback_strength))

		on_attack_released()


func handle_secondary_attack_input(event: InputEvent) -> void:
	var attack_type := AttackType.Thrust
	var action_name := "secondary_attack"
	if (!is_charging_attack()
		&& !is_attack_on_cooldown(attack_type)
		&& event.is_action_pressed(action_name)):
		on_attack_started_charging(attack_type)

	if charging_attack_type == attack_type && event.is_action_released(action_name):
		var attack_rectangle_shape := RectangleShape2D.new()
		$AttackShapeCast2D.shape = attack_rectangle_shape
		var angle := active_attack_zone_data.angle - PI / 2.0
		$AttackShapeCast2D.position = Vector2(cos(angle), sin(angle)) * active_attack_zone_data.radius / 2.0
		$AttackShapeCast2D.rotation = active_attack_zone_data.angle
		attack_rectangle_shape.size = Vector2(active_attack_zone_data.thickness, active_attack_zone_data.radius)

		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var collider := $AttackShapeCast2D.get_collider(collider_index) as EnemyCharacter
			collider.take_hit(scale_damage(default_thrust_damage), scale_knockback(default_thrust_knockback_strength))

		on_attack_released()


func handle_heavy_attack_input(event: InputEvent) -> void:
	var attack_type := AttackType.GroundPound
	var action_name := "heavy_attack"
	if (!is_charging_attack()
		&& !is_attack_on_cooldown(attack_type)
		&& event.is_action_pressed(action_name)):
		on_attack_started_charging(attack_type)

	if charging_attack_type == attack_type && event.is_action_released(action_name):
		var attack_circle_shape := CircleShape2D.new()
		$AttackShapeCast2D.shape = attack_circle_shape
		attack_circle_shape.radius = active_attack_zone_data.radius

		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var collider := $AttackShapeCast2D.get_collider(collider_index) as EnemyCharacter
			collider.take_hit(scale_damage(default_ground_pound_damage), scale_knockback(default_ground_pound_knockback_strength))

		on_attack_released()


func can_dash() -> bool:
	return should_move()


func handle_dash_input(event: InputEvent) -> void:
	var elapsed_time := (Time.get_ticks_msec() - last_dash_end_time) / 1000.0
	var is_on_cooldown := default_dash_cooldown > elapsed_time
	if is_on_cooldown:
		return

	dash_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if !dash_direction.is_zero_approx():
		on_dash_started()


func on_dash_started() -> void:
	last_dash_start_time = Time.get_ticks_msec()
	is_dashing = true

	$DashMotionTrailTimer.one_shot = false
	$DashMotionTrailTimer.start(dash_motion_trail_creation_cooldown)


func on_dash_finished() -> void:
	last_dash_end_time = Time.get_ticks_msec()
	is_dashing = false

	$DashMotionTrailTimer.stop()


func can_attack() -> bool:
	return (is_alive()
		and not ($AnimatedSprite2D.animation == "hit_react" and $AnimatedSprite2D.is_playing()))


func _input(event: InputEvent) -> void:
	if can_attack():
		if event.is_action("primary_attack"):
			handle_primary_attack_input(event)
		elif event.is_action("secondary_attack"):
			handle_secondary_attack_input(event)
		elif event.is_action("heavy_attack"):
			handle_heavy_attack_input(event)

	if can_dash():
		if event.is_action_pressed("dash"):
			handle_dash_input(event)


func should_move() -> bool:
	return (is_alive() and not is_charging_attack()
		and not ($AnimatedSprite2D.animation == "hit_react" and $AnimatedSprite2D.is_playing()))


func is_charging_attack() -> bool:
	return charging_attack_type != AttackType.Invalid


func get_charge_power() -> float:
	var charge_power: float = 1.0

	var charge_time := get_charging_time_seconds()
	if charge_time > charge_delay:
		charge_power *= pow(get_charging_time_seconds() * charge_speed, charge_exp)

	return charge_power


func get_charging_time_seconds() -> float:
	return 0.0 if !is_charging_attack() else (Time.get_ticks_msec() - attack_charge_start_time) / 1000.0


func scale_damage(damage: float) -> float:
	return damage * pow(get_charge_power(), 1.1)


func scale_knockback(knockback_strength: float) -> float:
	return minf(knockback_limit, knockback_strength * pow(get_charge_power(), 1.8))


func get_elapsed_time_since_attack_end(attack_type: AttackType) -> float:
	assert(last_attack_end_time.has(attack_type))
	return (Time.get_ticks_msec() - last_attack_end_time.get(attack_type)) / 1000.0


func get_attack_type_cooldown(attack_type: AttackType) -> float:
	var cooldown: float = -1.0
	match attack_type:
		AttackType.Swing: cooldown = default_swing_cooldown
		AttackType.Thrust: cooldown = default_thrust_cooldown
		AttackType.GroundPound: cooldown = default_ground_pound_cooldown

	return cooldown


func is_attack_on_cooldown(attack_type: AttackType) -> bool:
	return get_attack_type_cooldown(attack_type) > get_elapsed_time_since_attack_end(attack_type)


func take_hit(damage: float, knockback_force: Vector2) -> void:
	if is_invincible():
		return

	set_health(health - damage)
	if is_alive():
		if $AnimatedSprite2D.animation != "hit_react":
			$AnimatedSprite2D.play("hit_react")
		pending_knockback_forces.push_back(knockback_force)


func set_health(_health: float) -> void:
	health = clampf(_health, 0.0, default_health)
	print("Player health: ", health)
	if health <= 0:
		die()


func die() -> void:
	Events.on_player_death.emit()

	# Don't play any knockback since we're dead
	pending_knockback_forces.clear()

	# Don't collide with anything
	collision_mask = 0
	collision_layer = 0

	# Drop any charging attack
	clear_attack_data()

	# TODO replace with an actual animation
	$AnimationPlayer.play("death")


func is_alive() -> bool:
	return health > 0.0


func get_charging_attack_radius() -> float:
	return active_attack_zone_data.radius if active_attack_zone_data else 0.0


func is_invincible() -> bool:
	return is_alive() and is_dashing


func create_motion_trail_copy() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture(
		$AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	var shader: ShaderMaterial = $AnimatedSprite2D.material.duplicate()
	shader.set_shader_parameter("opacity", 0.3)
	shader.set_shader_parameter("r", 0.0)
	shader.set_shader_parameter("g", 0.0)
	shader.set_shader_parameter("b", 0.8)
	shader.set_shader_parameter("mix_color", 0.7)
	sprite.material = shader

	sprite.global_position = global_position
	sprite.z_index = z_index - 1

	get_parent().add_child(sprite)
	await get_tree().create_timer(dash_motion_trail_copy_lifespan).timeout
	sprite.queue_free()


func _on_dash_motion_trail_timer_timeout() -> void:
	create_motion_trail_copy()


func activate_pickup(pickup: Pickup) -> void:
	match pickup.pickup_type:
		Pickup.Type.Heal: set_health(health + 20.0)
		Pickup.Type.Wipe: wipe_enemies()

	pickup.queue_free()


func wipe_enemies() -> void:
	var wipe_area_scene: PackedScene = load("res://scenes/wipe_area.tscn")
	var wipe_area := wipe_area_scene.instantiate()
#	wipe_area.global_position = global_position
#	get_tree().get_root().add_child(wipe_area)
	add_child(wipe_area)
