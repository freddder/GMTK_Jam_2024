class_name WipeArea
extends Area2D

var radius_growth_duration: float = 0.7
var min_radius: float = 0.0
var max_radius: float = 2000.0
var min_cutoff_hz: float = 2000.0
var max_cutoff_hz: float = 500.0

@onready var spawn_time := Time.get_ticks_msec()
@onready var low_pass_filter := AudioServer.get_bus_effect(0, 0) as AudioEffectLowPassFilter


func _ready() -> void:
	set_wipe_radius(min_radius)
	$WipeSFX.play()
	AudioServer.set_bus_effect_enabled(0, 0, true)

func _process(delta: float) -> void:
	if !is_visible():
		return

	var alpha := get_alpha()
	set_wipe_radius(lerpf(min_radius, max_radius, alpha))
	low_pass_filter.cutoff_hz = lerpf(min_cutoff_hz, max_cutoff_hz, alpha)
	rotation += PI * delta

	if get_lifetime_seconds() > radius_growth_duration * 2.0:
		hide()

		var tween := get_tree().create_tween()
		tween.tween_property(low_pass_filter, "cutoff_hz", 20500, 0.3)

		if $WipeSFX.is_playing():
			await $WipeSFX.finished
		AudioServer.set_bus_effect_enabled(0, 0, false)
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
	if not enemy:
		return

	enemy.find_child("AnimatedSprite2D").stop()
	enemy.is_dying = true

	var tween := get_tree().create_tween()
	tween.tween_property(enemy, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.1)
	await tween.finished

	if not enemy:
		return
		
	enemy.is_dying = false
	enemy.start_dying(false)
	enemy.queue_free()
