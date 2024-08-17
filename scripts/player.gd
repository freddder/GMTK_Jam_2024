class_name PlayerCharacter extends Area2D

class AttackZoneData:
	var radius: float = 0
	var angle: float = 0
	var start_angle: float = 0
	var end_angle: float = 0

enum AttackType {
	Invalid,
	Swing,
}

@export var default_walk_speed: float = 300.0
@export var default_swing_radius: float = 50.0
@export var default_swing_angle: float = 45.0
@export var swing_angle_limit: float = 230.0
@export var default_camera_zoom: Vector2 = Vector2(2.3, 2.3)
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
	
func _draw() -> void:
	if !active_attack_zone_data:
		return
		
	var origin := Vector2.ZERO
	
	draw_line(origin, 
		Vector2(
			cos(active_attack_zone_data.start_angle) * active_attack_zone_data.radius, 
			sin(active_attack_zone_data.start_angle) * active_attack_zone_data.radius), 
		attack_area_color)
		
	draw_line(origin, 
		Vector2(
			cos(active_attack_zone_data.end_angle) * active_attack_zone_data.radius, 
			sin(active_attack_zone_data.end_angle) * active_attack_zone_data.radius), 
		attack_area_color)
		
	draw_arc(origin, active_attack_zone_data.radius, 
		active_attack_zone_data.start_angle, active_attack_zone_data.end_angle, 
		attack_area_arc_segments, attack_area_color)
	
func draw_attack_zone(attack_zone_data: AttackZoneData) -> void:
	attack_area_color = Color.RED
	active_attack_zone_data = attack_zone_data
	attack_area_arc_segments = maxf(6, active_attack_zone_data.radius / 20)
	
	queue_redraw()
	
func handle_mouse_direction() -> void:
	var mouse_position := get_local_mouse_position()
	mouse_direction_angle_rad = atan2(mouse_position.y, mouse_position.x)
	
	# Add half PI (90 degrees) because sprite looks upwards by default, 
	# but rotation at 0 radians faces west
	$MouseDirectionSprite.rotation = mouse_direction_angle_rad + PI / 2.0
	
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
	
func handle_attack_zone() -> void:
	match charging_attack_type:
		AttackType.Swing: draw_attack_zone(get_attack_zone_data_swing())
	
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

func _input(event: InputEvent) -> void:
	if !is_charging_attack() && event.is_action_pressed("primary_attack"):
		charging_attack_type = AttackType.Swing
		attack_charge_start_time = Time.get_ticks_msec()
		
	if charging_attack_type == AttackType.Swing && event.is_action_released("primary_attack"):
		var attack_zone_data : AttackZoneData = get_attack_zone_data_swing()
		
		var attack_circle_shape := $AttackShapeCast2D.shape as CircleShape2D
		attack_circle_shape.radius = attack_zone_data.radius
		
		$AttackShapeCast2D.force_shapecast_update()
		for collider_index in $AttackShapeCast2D.get_collision_count():
			var collider := $AttackShapeCast2D.get_collider(collider_index) as Node2D
			var direction_to := global_position.direction_to(collider.global_position)
			var angle_to := atan2(direction_to.y, direction_to.x)
			if attack_zone_data.start_angle <= angle_to && attack_zone_data.end_angle >= angle_to:
				print("Damage ", $AttackShapeCast2D.get_collider(collider_index))
			
		attack_circle_shape.radius = 0.0
		charging_attack_type = AttackType.Invalid
		active_attack_zone_data = null
		
		# Clear whatever we have drawn so far
		queue_redraw()
		
		# Return to original camera zoom
		set_camera_zoom(default_camera_zoom, 0.4)
		
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
