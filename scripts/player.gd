class_name PlayerCharacter extends Area2D

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

@export_category("Swing")
@export var default_swing_radius: float = 50.0
@export var default_swing_angle: float = 45.0
@export var swing_angle_limit: float = 230.0

@export_category("Thrust")
@export var default_thrust_radius: float = 100.0
@export var default_thrust_thickness: float = 35.0

@export var default_camera_zoom: Vector2 = Vector2(2.3, 2.3)

@export_category("Charge")
@export var charge_speed: float = 1.0
@export var charge_exp: float = 0.6
@export var charge_delay: float = 1.0

var mouse_direction_angle_rad: float = 0.0
var attack_charge_start_time: float = 0.0
var charging_attack_type: AttackType = AttackType.Invalid

var active_attack_zone_data: AttackZoneData
var attack_area_color: Color = Color.RED
var attack_area_arc_segments: float = 0

func _ready() -> void:
	set_camera_zoom(default_camera_zoom, 0.0)
	clear_attack_data()

func handle_movement(delta: float) -> void:
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed := default_walk_speed
	var velocity := move_direction * walk_speed * delta
	position += velocity

func check_arena_bounds() -> void:
	var distance_from_center := position.length()
	if distance_from_center > Arena.radius:
		position = position.normalized() * Arena.radius

func _physics_process(delta: float) -> void:
	if !is_charging_attack():
		handle_movement(delta)
	check_arena_bounds()
	
func draw_attack_zone_swing_implementation() -> void:
	var origin := Vector2.ZERO
	var offset_angle := -PI / 2.0
	var width := 2.0
	
	draw_line(origin,
		Vector2(
			cos(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.start_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, width)

	draw_line(origin,
		Vector2(
			cos(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius,
			sin(active_attack_zone_data.end_angle + offset_angle) * active_attack_zone_data.radius),
		attack_area_color, width)

	draw_arc(origin, active_attack_zone_data.radius,
		active_attack_zone_data.start_angle + offset_angle, active_attack_zone_data.end_angle + offset_angle,
		attack_area_arc_segments, attack_area_color, width)
		
func draw_attack_zone_thrust_implementation() -> void:
	var origin := Vector2.ZERO
	
	var half_thickness := active_attack_zone_data.thickness / 2.0
	var radius := active_attack_zone_data.radius
	var local_coords_rect : Array = [
		[ half_thickness, 0.0 ],  [ half_thickness, radius ],
		[ -half_thickness, radius ], [ -half_thickness, 0.0 ]
	]
	
	var packed_array: PackedVector2Array
	for coord in local_coords_rect:
		packed_array.append(Vector2(coord[0], coord[1]).rotated(active_attack_zone_data.angle + PI))
		
	var colors: PackedColorArray
	colors.append(Color.RED)
	
	draw_polygon(packed_array, colors)

func _draw() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone_swing_implementation()
		AttackType.Thrust: draw_attack_zone_thrust_implementation()

func draw_attack_zone_swing(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data
	attack_area_arc_segments = maxf(6, active_attack_zone_data.radius / 5)

	queue_redraw()
	
func draw_attack_zone_thrust(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data

	queue_redraw()

func handle_mouse_direction() -> void:
	var mouse_position := get_local_mouse_position()
	mouse_direction_angle_rad = atan2(mouse_position.y, mouse_position.x) + PI / 2.0

	# Add half PI (90 degrees) because sprite looks upwards by default,
	# but rotation at 0 radians faces west
	$MouseDirectionSprite.rotation = mouse_direction_angle_rad

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
	print(mouse_direction_angle_rad)
	return attack_zone_data

func handle_attack_zone() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone_swing(get_attack_zone_data_swing())
		AttackType.Thrust: draw_attack_zone_thrust(get_attack_zone_data_thrust())

	if is_charging_attack():
		var zoom_power := get_charge_power() - 1.0
		var additional_zoom := zoom_power * 0.2
		var camera_zoom := default_camera_zoom - Vector2(additional_zoom, additional_zoom)
		set_camera_zoom(camera_zoom, 0.0)

func _process(delta: float) -> void:
	handle_mouse_direction()
	handle_attack_zone()

func set_camera_zoom(zoom: Vector2, duration: float = 0.2) -> void:
	if duration > 0.0:
		var tween = get_tree().create_tween()
		tween.tween_property($Camera2D, "zoom", zoom, duration)
	else:
		$Camera2D.set_zoom(zoom)

func clear_attack_data() -> void:
	$AttackShapeCast2D.shape = null
	$AttackShapeCast2D.position = Vector2.ZERO
	$AttackShapeCast2D.rotation = 0
	active_attack_zone_data = null
	charging_attack_type = AttackType.Invalid

	# Clear whatever we have drawn so far
	queue_redraw()

	# Return to original camera zoom
	set_camera_zoom(default_camera_zoom, 0.4)

func handle_primary_attack_input(event: InputEvent) -> void:
	var attack_type := AttackType.Swing
	var action_name := "primary_attack"
	if !is_charging_attack() && event.is_action_pressed(action_name):
		charging_attack_type = attack_type
		attack_charge_start_time = Time.get_ticks_msec()

	if charging_attack_type == attack_type && event.is_action_released(action_name):
		var attack_circle_shape := CircleShape2D.new()
		$AttackShapeCast2D.shape = attack_circle_shape
		attack_circle_shape.radius = active_attack_zone_data.radius

		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var collider := $AttackShapeCast2D.get_collider(collider_index) as Node2D
			var direction_to := global_position.direction_to(collider.global_position)
			var angle_to := atan2(direction_to.y, direction_to.x) + PI / 2.0
			if active_attack_zone_data.start_angle <= angle_to && active_attack_zone_data.end_angle >= angle_to:
				print("Damage ", $AttackShapeCast2D.get_collider(collider_index))
				collider.queue_free()

		clear_attack_data()

func handle_secondary_attack_input(event: InputEvent) -> void:
	var attack_type := AttackType.Thrust
	var action_name := "secondary_attack"
	if !is_charging_attack() && event.is_action_pressed(action_name):
		charging_attack_type = attack_type
		attack_charge_start_time = Time.get_ticks_msec()

	if charging_attack_type == attack_type && event.is_action_released(action_name):
		var attack_rectangle_shape := RectangleShape2D.new()
		$AttackShapeCast2D.shape = attack_rectangle_shape
		var angle := active_attack_zone_data.angle - PI / 2.0
		$AttackShapeCast2D.position = Vector2(cos(angle), sin(angle)) * active_attack_zone_data.radius / 2.0
		$AttackShapeCast2D.rotation = active_attack_zone_data.angle
		attack_rectangle_shape.size = Vector2(active_attack_zone_data.thickness, active_attack_zone_data.radius)

		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var collider := $AttackShapeCast2D.get_collider(collider_index) as Node2D
			print("Damage ", $AttackShapeCast2D.get_collider(collider_index))
			collider.queue_free()

		clear_attack_data()

func _input(event: InputEvent) -> void:
	if event.is_action("primary_attack"):
		handle_primary_attack_input(event)
	elif event.is_action("secondary_attack"):
		handle_secondary_attack_input(event)

func is_charging_attack() -> bool:
	return charging_attack_type != AttackType.Invalid

func get_charge_power() -> float:
	var charge_power := 1.0

	var charge_time := get_charging_time_seconds()
	if charge_time > charge_delay:
		charge_power *= pow(get_charging_time_seconds() * charge_speed, charge_exp)

	return charge_power

func get_charging_time_seconds() -> float:
	return 0.0 if !is_charging_attack() else (Time.get_ticks_msec() - attack_charge_start_time) / 1000.0
