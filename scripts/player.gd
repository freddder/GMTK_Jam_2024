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

signal health_changed

@export var default_walk_speed: float = 300.0
@export var default_camera_zoom := Vector2(1.2, 1.2)
@export var min_camera_zoom := Vector2(0.7, 0.7)
@export var knockback_limit: float = 1000.0
@export var default_health: float = 100.0
@export var camera_offset_distance_from_arena_bounds: float = 250.0
@export var ground_pound_texture: Texture2D = load("res://content/sprites/ground_pound.png")
@export var wipe_area_scene: PackedScene = load("res://scenes/wipe_area.tscn")

@export_category("Swing")
@export var default_swing_radius: float = 120.0
@export var default_swing_angle: float = 60.0
@export var swing_angle_limit: float = 150.0
@export var default_swing_damage: float = 35.0
@export var swing_charge_speed: float = 0.35
@export var default_swing_knockback_strength: float = 20.0
@export var default_swing_cooldown: float = 1

@export_category("Thrust")
@export var default_thrust_radius: float = 150.0
@export var default_thrust_thickness: float = 30.0
@export var default_thrust_damage: float = 50.0
@export var thrust_charge_speed: float = 0.5
@export var default_thrust_knockback_strength: float = 50
@export var default_thrust_cooldown: float = 1.5

@export_category("Ground Pound")
@export var default_ground_pound_radius: float = 40.0
@export var default_ground_pound_damage: float = 85.0
@export var ground_pound_charge_speed: float = 0.3
@export var default_ground_pound_knockback_strength: float = 35.0
@export var default_ground_pound_cooldown: float = 10.0

@export_category("Charge")
@export var charge_delay: float = 0.5
@export var charge_boost_power: float = 1.3
@export var seconds_for_charge_boost: float = 13.0

@export_category("Dash")
@export var default_dash_duration: float = 0.3
@export var default_dash_speed: float = 800.0
@export var default_dash_cooldown: float = 0.4
@export var dash_motion_trail_copy_lifespan: float = 0.2
@export var dash_motion_trail_creation_cooldown: float = 0.02
@export var dash_motion_trail_color := Color(0.0, 0.0, 0.8, 0.3)
@export var dash_motion_trail_mix_color: float = 0.7

@export_category("Camera Shake")
@export var shake_scale_rate: float = 500.0
@export var shake_scale_delay: float = 3.0

@export_category("Haste")
@export var haste_duration: float = 7.0
@export var haste_move_speed_multiplier : float = 1.6
@export var haste_dash_speed_multiplier: float = 2
@export var haste_charge_speed_multiplier: float = 1.7
@export var haste_motion_trail_creation_cooldown: float = 0.06
@export var haste_motion_trail_color := Color(0.0, 0.78, 0.8, 0.3)
@export var haste_motion_trail_mix_color: float = 0.7

@onready var noise_rand := RandomNumberGenerator.new()
@onready var game_hud := get_parent().find_child("GameHUD") as GameHUD

var mouse_direction_angle_rad: float = 0.0
var attack_charge_start_time: float = 0.0
var charging_attack_type := AttackType.Invalid
var wants_release_attack := false
var can_release_attack := true
var is_attack_animation_ongoing := false

var active_attack_zone_data: AttackZoneData
var attack_area_color := Color.RED
var attack_area_width: float = 2.5
var attack_area_arc_segments: float = 0.0

var health := default_health
var _charge_power: float = 0.0
var last_non_zero_movement_direction := Vector2.ZERO
var pending_knockback_forces: Array[Vector2]

var last_attack_end_time: Dictionary = {
	AttackType.Swing: 0.0,
	AttackType.Thrust: 0.0,
	AttackType.GroundPound: 0.0,
}

var last_dash_start_time: float = 0.0
var last_dash_end_time: float = 0.0
var is_dashing := false
var dash_direction := Vector2.ZERO
var should_be_invincible := false

var shake_strength: float = 0.0

var interpolated_power: float = 1.0
var power_interpolation_speed: float = 2.0


func _ready() -> void:
	activate_haste()
	var zoom: float = default_camera_zoom.x * (get_viewport_rect().size.x / 1280)
	default_camera_zoom = Vector2(zoom, zoom)

	set_camera_zoom(default_camera_zoom, 0.0)
	clear_attack_data()

	noise_rand.randomize()
	handle_post_normal_game_logic()


func handle_regular_movement(delta: float) -> void:
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed_multiplier := haste_move_speed_multiplier if is_haste_active() else 1.0
	var walk_speed := default_walk_speed * walk_speed_multiplier
	var velocity := move_direction * walk_speed * delta
	position += velocity

	if not velocity.is_zero_approx():
		last_non_zero_movement_direction = move_direction
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")


func handle_dash_movement(delta: float) -> bool:
	var dashing_time := (Time.get_ticks_msec() - last_dash_start_time) / 1000.0
	var dashing_remaining_time := default_dash_duration - dashing_time
	is_dashing = dashing_remaining_time > 0.0
	if not is_dashing:
		on_dash_finished()
		return false

	var dash_speed_multiplier := haste_move_speed_multiplier if is_haste_active() else 1.0
	var dash_speed := default_dash_speed * dash_speed_multiplier
	position += dash_direction * dash_speed * delta
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

	draw_line(origin, Vector2(
			cos(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, attack_area_width)

	draw_line(origin, Vector2(
			cos(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, attack_area_width)

	draw_arc(origin, active_attack_zone_data.radius,
		active_attack_zone_data.start_angle + offset_angle, active_attack_zone_data.end_angle + offset_angle,
		attack_area_arc_segments, attack_area_color, attack_area_width)


func draw_attack_zone_thrust_implementation() -> void:
	var half_thickness := active_attack_zone_data.thickness / 2.0
	var radius := active_attack_zone_data.radius
	var local_coords_rect: Array = [
		[ half_thickness, 0.0 ], [ half_thickness, radius ],
		[ -half_thickness, radius ], [ -half_thickness, 0.0 ]
	]

	var local_rotated_coords_rect: Array
	for coord in local_coords_rect:
		local_rotated_coords_rect.append(Vector2(coord[0], coord[1]).rotated(active_attack_zone_data.angle + PI))

	draw_line(local_rotated_coords_rect[0], local_rotated_coords_rect[1], attack_area_color, attack_area_width)
	draw_line(local_rotated_coords_rect[1], local_rotated_coords_rect[2], attack_area_color, attack_area_width)
	draw_line(local_rotated_coords_rect[2], local_rotated_coords_rect[3], attack_area_color, attack_area_width)
	draw_line(local_rotated_coords_rect[3], local_rotated_coords_rect[0], attack_area_color, attack_area_width)


func draw_attack_zone_ground_pound_implementation() -> void:
	var origin := Vector2.ZERO

	draw_circle(origin, active_attack_zone_data.radius, attack_area_color, false, attack_area_width)


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
	var mouse_position_sprite: Vector2 = mouse_position - $AnimatedSprite2D/MouseDirectionSprite.position
	var mouse_direction_sprite_angle_rad = atan2(mouse_position_sprite.y, mouse_position_sprite.x) + PI / 2.0
	$AnimatedSprite2D/MouseDirectionSprite.rotation = mouse_direction_sprite_angle_rad


func get_facing_direction() -> int:
	if is_attack_animation_ongoing:
		return -sign(global_position.x - get_global_mouse_position().x)

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
	attack_zone_data.radius = default_ground_pound_radius * radius_multiplier

	return attack_zone_data


func handle_attack_zone() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone_swing(get_attack_zone_data_swing())
		AttackType.Thrust: draw_attack_zone_thrust(get_attack_zone_data_thrust())
		AttackType.GroundPound: draw_attack_zone_ground_pound((get_attack_zone_data_ground_pound()))

	if is_charging_attack():
		var zoom_power := get_charge_power() - 1.0
		var additional_zoom := log(zoom_power * 0.2 + 1.0) / log(10.0)
		var camera_zoom := default_camera_zoom - Vector2(additional_zoom, additional_zoom)
		set_camera_zoom(camera_zoom, 0.0)


func get_charge_speed(attack_type: AttackType) -> float:
	match attack_type:
		AttackType.Swing: return swing_charge_speed
		AttackType.Thrust: return thrust_charge_speed
		AttackType.GroundPound: return ground_pound_charge_speed
	return 0.0


func handle_charging(delta: float) -> void:
	if not is_charging_attack():
		_charge_power = 1.0

	if not is_charge_post_delay():
		return

	# Haste buff
	var charge_speed_multiplier := haste_charge_speed_multiplier if is_haste_active() else 1.0

	var additional_charge := get_charge_speed(charging_attack_type) * charge_speed_multiplier
	_charge_power += additional_charge * delta


func handle_interpolated_charging(delta: float) -> void:
	var diff := get_charge_power() - interpolated_power
	interpolated_power += diff * delta * power_interpolation_speed


func handle_charging_visual_effects() -> void:
	var charge_effect: ColorRect = game_hud.find_child("ChargeEffect")
	var shader: ShaderMaterial = charge_effect.material
	var normalized_power := clampf(log(interpolated_power) * 0.7, 0.0, 1.0)
	shader.set_shader_parameter("line_density", lerp(0.0, 0.36, normalized_power))


func handle_charging_sound() -> void:
	if get_charge_power() > 1.0:
		if not $ChargeSFX.playing:
			$ChargeSFX.play()

		$ChargeSFX.pitch_scale = get_charge_power() / 2.0


func get_random_offset() -> Vector2:
	return Vector2(
		noise_rand.randf_range(-shake_strength, shake_strength),
		noise_rand.randf_range(-shake_strength, shake_strength)
	)


func handle_camera_view(delta: float) -> void:
	# Arena is at 0,0, so getting the player position length is effectively getting how far they
	# went off arena center; same thing applies to direction
	var distance_from_center := global_position.length()
	var direction := global_position.normalized()

	var max_distance_from_centre := Arena.radius - camera_offset_distance_from_arena_bounds
	var target_point := minf(max_distance_from_centre, distance_from_center) * direction
	$Camera2D.offset = target_point - $Camera2D.global_position

	if shake_scale_delay > get_charging_time_seconds():
		return

	shake_strength = lerpf(0.0, interpolated_power, shake_scale_rate * delta)
	if is_attack_animation_ongoing and interpolated_power > 1.0:
		$Camera2D.offset += get_random_offset()


func handle_sprite_opacity() -> void:
	# Changing "modulate.a" doesn't change the sprite opacity due to shader; this is a quick workaround
	var shader: ShaderMaterial = $AnimatedSprite2D.material
	shader.set_shader_parameter("opacity", modulate.a)


func _process(delta: float) -> void:
	handle_charging(delta)
	handle_interpolated_charging(delta)
	handle_camera_view(delta)
	handle_charging_visual_effects()
	if is_alive():
		handle_mouse_direction()
		handle_attack_zone()
		handle_charging_sound()
		handle_animation_side()

	handle_sprite_opacity()


func set_camera_zoom(zoom: Vector2, duration: float = 0.2) -> void:
	zoom.x = max(zoom.x, min_camera_zoom.x)
	zoom.y = max(zoom.y, min_camera_zoom.y)

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

	wants_release_attack = false
	can_release_attack = true

	# Clear whatever we have drawn so far
	queue_redraw()

	# Return to original camera zoom
	set_camera_zoom(default_camera_zoom, 0.4)


func play_attack_animation_start(attack_type: AttackType) -> void:
	var animation_name_prefix := get_attack_type_name(attack_type)
	if animation_name_prefix.is_empty():
		$AnimatedSprite2D.play("idle")
		return

	can_release_attack = false
	$AnimatedSprite2D.play(animation_name_prefix + "_start")

	await $AnimatedSprite2D.animation_finished

	can_release_attack = true
	if not wants_release_attack:
		$AnimatedSprite2D.play(animation_name_prefix + "_loop")
	else:
		on_attack_released()


func on_attack_started_charging(attack_type: AttackType) -> void:
	is_attack_animation_ongoing = true
	charging_attack_type = attack_type
	attack_charge_start_time = Time.get_ticks_msec()
	play_attack_animation_start(charging_attack_type)


func save_attack_end_time() -> void:
	assert(last_attack_end_time.has(charging_attack_type))
	last_attack_end_time[charging_attack_type] = Time.get_ticks_msec()


func handle_sound_on_attack_release() -> void:
	var is_charged: bool = get_charge_power() > 1.0
	match charging_attack_type:
		AttackType.Swing:
			if not is_charged:
				$NormalSwingSFX.play()
			else:
				$ChargedSwingSFX.play()

		AttackType.Thrust:
			if not is_charged:
				$NormalThrustSFX.play()
			else:
				$ChargedThrustSFX.play()

		AttackType.GroundPound: $GroundPoundSFX.play()


func get_attack_type_name(attack_type: AttackType) -> String:
	match attack_type:
		AttackType.Swing: return "swing"
		AttackType.Thrust: return "thrust"
		AttackType.GroundPound: return "ground_pound"

	return ""


func play_attack_release_animation() -> void:
	if charging_attack_type != AttackType.Invalid:
		var animation_name := get_attack_type_name(charging_attack_type) + "_finish"
		if animation_name != "_finish":
			$AnimatedSprite2D.play(animation_name)
			await $AnimatedSprite2D.animation_finished

		is_attack_animation_ongoing = false
		on_attack_animations_finished()


func get_attack_finish_release_delay() -> float:
	match charging_attack_type:
		AttackType.Swing: return 0.28
		AttackType.Thrust: return 0.28
		AttackType.GroundPound: return 0.28
	return 0.0


func on_attack_released() -> void:
	handle_sound_on_attack_release()
	play_attack_release_animation()

	# If we have to deal damage during the animation, not when it's done, this is going to help us;
	# it acts like anim notifies in UE
	await get_tree().create_timer(get_attack_finish_release_delay()).timeout
	on_attack_animations_finished()


func on_attack_animations_finished() -> void:
	if charging_attack_type == AttackType.Invalid:
		return

	match charging_attack_type:
		AttackType.Swing: release_primary_attack()
		AttackType.Thrust: release_secondary_attack()
		AttackType.GroundPound: release_heavy_attack()

	save_attack_end_time()
	clear_attack_data()


func release_primary_attack() -> void:
	var attack_polygon_shape: ConcavePolygonShape2D = ConcavePolygonShape2D.new()
	$AttackShapeCast2D.shape = attack_polygon_shape

	# Find cone center
	var center_angle := mouse_direction_angle_rad  - PI / 2.0
	var half_cone := active_attack_zone_data.angle / 2.0
	var cone_start_angle := center_angle - half_cone

	# Define segments amount
	var angle_step: float = 10.0
	var segmentsf: float = active_attack_zone_data.angle / deg_to_rad(angle_step)
	var segmentsi: int = segmentsf

	# Start from character center
	var polygon: PackedVector2Array
	polygon.push_back(Vector2.ZERO)

	for i in segmentsi + 1:
		# Find the angle
		var step := (segmentsf / segmentsi)
		var alpha := (i * step) / segmentsf
		var local_angle := alpha * active_attack_zone_data.angle
		var global_angle := cone_start_angle + local_angle

		# Translate angle to the world position
		var direction := Vector2(cos(global_angle), sin(global_angle))
		var vertex_position := direction * active_attack_zone_data.radius

		# Close last edge; start a new one
		polygon.push_back(vertex_position)
		polygon.push_back(vertex_position)

	# Finish on character centre
	polygon.push_back(Vector2.ZERO)

	# Apply the polygon
	attack_polygon_shape.set_segments(polygon)

	$AttackShapeCast2D.force_shapecast_update()
	for collider_index in $AttackShapeCast2D.get_collision_count():
		$AttackShapeCast2D.get_collider(collider_index).take_hit(
			scale_damage(default_swing_damage),
			scale_knockback(default_swing_knockback_strength))


func attack_start_fail_due_cooldown(attack_type: AttackType) -> void:
	$AttackCooldownSFX.play()


func handle_generic_attack_input(event: InputEvent, attack_type: AttackType, action_name: String) -> void:
	if (event.is_action_pressed(action_name) and not is_charging_attack()):
		if not is_attack_on_cooldown(attack_type):
			on_attack_started_charging(attack_type)
		else:
			attack_start_fail_due_cooldown(attack_type)

	if charging_attack_type == attack_type and event.is_action_released(action_name):
		if not can_release_attack:
			wants_release_attack = true
			return

		on_attack_released()


func release_secondary_attack() -> void:
	var attack_rectangle_shape := RectangleShape2D.new()
	$AttackShapeCast2D.shape = attack_rectangle_shape
	var angle := active_attack_zone_data.angle - PI / 2.0
	$AttackShapeCast2D.position = Vector2(cos(angle), sin(angle)) * active_attack_zone_data.radius / 2.0
	$AttackShapeCast2D.rotation = active_attack_zone_data.angle
	attack_rectangle_shape.size = Vector2(active_attack_zone_data.thickness, active_attack_zone_data.radius)

	$AttackShapeCast2D.force_shapecast_update()
	for collider_index in $AttackShapeCast2D.get_collision_count():
		var collider = $AttackShapeCast2D.get_collider(collider_index)
		collider.take_hit(scale_damage(default_thrust_damage), scale_knockback(default_thrust_knockback_strength))


func create_ground_pound_sprite(uniform_size: float) -> void:
	var ground_pound_sprite: Sprite2D = Sprite2D.new()

	ground_pound_sprite.texture = ground_pound_texture
	ground_pound_sprite.global_position = $AnimatedSprite2D/SwordSocket.global_position
	ground_pound_sprite.z_index = -10

	uniform_size = minf(uniform_size, 2000.0)
	var uniform_scale := uniform_size / ground_pound_sprite.texture.get_size().x
	ground_pound_sprite.scale = Vector2(uniform_scale, uniform_scale)

	get_parent().add_child(ground_pound_sprite)

	await get_tree().create_timer(maxf(1.0, uniform_size / 2000.0 * 3.0)).timeout

	var tween := get_tree().create_tween()
	tween.tween_property(ground_pound_sprite , "modulate", Color.TRANSPARENT, 1.0)


func release_heavy_attack() -> void:
	var attack_circle_shape := CircleShape2D.new()
	$AttackShapeCast2D.shape = attack_circle_shape
	attack_circle_shape.radius = active_attack_zone_data.radius

	$AttackShapeCast2D.force_shapecast_update()
	for collider_index in $AttackShapeCast2D.get_collision_count():
		var collider = $AttackShapeCast2D.get_collider(collider_index)
		collider.take_hit(scale_damage(default_ground_pound_damage), scale_knockback(default_ground_pound_knockback_strength))

	create_ground_pound_sprite(active_attack_zone_data.radius * 2.0)


func can_dash() -> bool:
	return should_move()


func handle_dash_input(event: InputEvent) -> void:
	if is_dashing:
		return

	var elapsed_time: float = ((Time.get_ticks_msec() - last_dash_end_time) / 1000.0
		if last_dash_end_time > 0 else 9999)
	var is_on_cooldown := default_dash_cooldown > elapsed_time
	if is_on_cooldown:
		return

	dash_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not dash_direction.is_zero_approx():
		on_dash_started()


func on_dash_started() -> void:
	last_dash_start_time = Time.get_ticks_msec()
	is_dashing = true

	$DashSFX.play()
	$DashMotionTrailTimer.one_shot = false
	$DashMotionTrailTimer.start(dash_motion_trail_creation_cooldown)


func on_dash_finished() -> void:
	last_dash_end_time = Time.get_ticks_msec()
	is_dashing = false

	$DashMotionTrailTimer.stop()


func can_attack() -> bool:
	return (is_alive()
		and not ($AnimatedSprite2D.animation == "hit_react" and $AnimatedSprite2D.is_playing())
		and not is_playing_attack_finish_animation())


func _input(event: InputEvent) -> void:
	if can_attack():
		handle_generic_attack_input(event, AttackType.Swing, "primary_attack")
		handle_generic_attack_input(event, AttackType.Thrust, "secondary_attack")
		handle_generic_attack_input(event, AttackType.GroundPound, "heavy_attack")

	if can_dash():
		if event.is_action_pressed("dash"):
			handle_dash_input(event)


func create_debug_explosions() -> void:
	var explosion_scene: PackedScene = load("res://scenes/explosion.tscn")
	for idx in 20:
		var explosion: Explosion = explosion_scene.instantiate()

		var angle := randf() * 2 * PI
		var direction := Vector2(cos(angle), sin(angle))
		var distance := randf() * Arena.radius

		explosion.global_position = direction * distance
		get_parent().add_child(explosion)


func is_playing_attack_finish_animation() -> bool:
	return $AnimatedSprite2D.is_playing() and $AnimatedSprite2D.animation.contains("_finish")


func should_move() -> bool:
	return (is_alive() and not is_charging_attack()
		and not ($AnimatedSprite2D.animation == "hit_react" and $AnimatedSprite2D.is_playing())
		and not is_playing_attack_finish_animation())


func is_charging_attack() -> bool:
	return charging_attack_type != AttackType.Invalid


func is_charge_post_delay() -> bool:
	return get_charging_time_seconds() > charge_delay


func get_charge_power() -> float:
	var additional_power: float = 0.0

	var charging_time := get_charging_time_seconds()
	if charging_time >= seconds_for_charge_boost:
		var base := charging_time - seconds_for_charge_boost
		additional_power = pow(base, charge_boost_power)

	# This should make the beginning of the charge be a little bit faster
	var warm_up: float = clamp(log(get_charging_time_seconds() + 1) * 0.1, 0.0, 0.4)
	additional_power += warm_up
#	print(warm_up)

	#	print(_charge_power, " ", additional_power)
	return _charge_power + additional_power


func get_charging_time_seconds() -> float:
	return 0.0 if not is_charging_attack() else (Time.get_ticks_msec() - attack_charge_start_time) / 1000.0


func scale_damage(damage: float) -> float:
	return damage * pow(get_charge_power(), 1.1)


func scale_knockback(knockback_strength: float) -> float:
	return minf(knockback_limit, knockback_strength * pow(get_charge_power(), 1.8))


func get_elapsed_time_since_attack_end(attack_type: AttackType) -> float:
	assert(last_attack_end_time.has(attack_type))
	var end_time = last_attack_end_time.get(attack_type)
	return (Time.get_ticks_msec() - end_time) / 1000.0 if end_time > 0 else 9999.9


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

	$HurtSFX.play()
	set_health(health - damage)
	if is_alive():
		if not is_charging_attack() and $AnimatedSprite2D.animation != "hit_react":
			$AnimatedSprite2D.play("hit_react")
		pending_knockback_forces.push_back(knockback_force)


func set_health(_health: float) -> void:
	health = clampf(_health, 0.0, default_health)
	health_changed.emit()
	if health <= 0:
		die()


func die() -> void:
	# Don't play any knockback since we're dead
	pending_knockback_forces.clear()

	# Don't collide with anything
	collision_mask = 0
	collision_layer = 0

	$HasteTimer.stop()

	# Drop any charging attack
	clear_attack_data()

	Events.on_player_death.emit()

	$DeathSFX.play()

	$AnimatedSprite2D.play("death")
	await $AnimatedSprite2D.animation_finished

	# Fade out
	var tween := get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.0)


func is_alive() -> bool:
	return health > 0.0


func get_charging_attack_radius() -> float:
	return active_attack_zone_data.radius if active_attack_zone_data else 0.0


func is_invincible() -> bool:
	return is_alive() and (is_dashing or should_be_invincible)


func create_motion_trail_copy(color: Color, mix_color: float) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture(
		$AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	var shader: ShaderMaterial = $AnimatedSprite2D.material.duplicate()
	shader.set_shader_parameter("r", color.r)
	shader.set_shader_parameter("g", color.g)
	shader.set_shader_parameter("b", color.b)
	shader.set_shader_parameter("opacity", color.a)
	shader.set_shader_parameter("mix_color", mix_color)
	sprite.material = shader

	sprite.global_position = $AnimatedSprite2D.global_position
	sprite.flip_h = $AnimatedSprite2D.flip_h
	sprite.z_index = z_index - 1

	get_parent().add_child(sprite)
	await get_tree().create_timer(dash_motion_trail_copy_lifespan).timeout
	sprite.queue_free()


func _on_dash_motion_trail_timer_timeout() -> void:
	create_motion_trail_copy(dash_motion_trail_color, dash_motion_trail_mix_color)


func activate_pickup(pickup: Pickup) -> void:
	match pickup.type:
		Pickup.Type.Heal: use_heal_pickup()
		Pickup.Type.Wipe: wipe_enemies()
		Pickup.Type.Haste: activate_haste()

	pickup.queue_free()


func use_heal_pickup() -> void:
	set_health(health + 20.0)
	$HealSFX.play()


func wipe_enemies() -> void:
	var wipe_area := wipe_area_scene.instantiate()
	add_child(wipe_area)


func activate_haste() -> void:
	$HasteTimer.start(haste_duration)
	$HasteSFX.play()
	$HasteTrailTimer.start(haste_motion_trail_creation_cooldown)


func is_haste_active() -> bool:
	return not $HasteTimer.is_stopped()


func _on_haste_timer_timeout() -> void:
	$HasteTrailTimer.stop()


func _on_haste_trail_timer_timeout() -> void:
	create_motion_trail_copy(haste_motion_trail_color, haste_motion_trail_mix_color)


func _on_death_sfx_finished():
	Events.done_playing_death_sfx.emit()


func handle_post_normal_game_logic() -> void:
	await Events.on_game_victory
	should_be_invincible = true
	await FreePlayManager.on_started
	wipe_enemies()
	set_health(default_health)
	should_be_invincible = false
