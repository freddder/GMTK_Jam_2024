class_name WipeArea
extends Area2D

var radius_growth_duration: float = 0.5
var min_radius: float = 0.0
var max_radius: float = 2000.0
var started_flashing := false

@onready var spawn_time := Time.get_ticks_msec()


func _ready() -> void:
	set_wipe_radius(min_radius)

func _process(delta: float) -> void:
	var alpha := get_alpha()
	set_wipe_radius(lerpf(min_radius, max_radius, alpha))
	rotation += PI * delta

	if get_lifetime_seconds() > radius_growth_duration * 2.0:
		queue_free()


func set_wipe_radius(radius: float) -> void:
	var new_scale = radius / $Sprite2D.texture.get_size().x
	$Sprite2D.scale = Vector2(new_scale, new_scale)
	$CollisionShape2D.shape.radius = radius


func get_lifetime_seconds() -> float:
	return (Time.get_ticks_msec() - spawn_time) / 1000.0


func get_lifetime_normalized() -> float:
	var lifetime := get_lifetime_seconds()
	return (lifetime if lifetime < radius_growth_duration else radius_growth_duration * 2.0 - lifetime) / radius_growth_duration


func get_alpha() -> float:
	return minf(log(get_lifetime_normalized() + 1.0) / log(1.8), 1.0)


func _on_area_entered(area: Area2D) -> void:
	var enemy := area as EnemyCharacter
	enemy.die()
