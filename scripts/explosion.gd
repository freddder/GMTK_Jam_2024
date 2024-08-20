class_name Explosion
extends Area2D

@export var duration: float = 2.0
@export var default_damage: float = 10.0
@export var default_knockback_strength: float = 40.0
@export var damage_dist_multiplier: float = 1.5
@export var knockback_dist_multiplier: float = 4.0

var progress: float = 0.0
var is_player_inside := false

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if progress < 1.0:
		progress = minf(progress + delta / duration, 1.0)
		queue_redraw()

		if progress == 1.0 and not $AnimatedSprite2D.is_playing():
			explode()


func _draw() -> void:
	if progress == 1.0:
		return

	var outer_color := Color.RED
	var inner_color := Color(1.0, 0.0, 0.0, 0.1)
	var radius := get_radius()

	draw_circle(Vector2.ZERO, radius, outer_color, false, 2.5)
	draw_circle(Vector2.ZERO, radius, inner_color, true)
	draw_circle(Vector2.ZERO, radius * progress, outer_color, false, 2.5)


func explode() -> void:
	if is_player_inside:
		var direction := global_position.direction_to(player.global_position)
		var distance := global_position.distance_to(player.global_position)
		var inv_distance_norm := 1.0 + clampf((get_radius() - distance) / get_radius(), 0.0, 1.0)

		var damage := default_damage * (inv_distance_norm * damage_dist_multiplier)
		var knockback := direction * default_knockback_strength * (inv_distance_norm * knockback_dist_multiplier)
		player.take_hit(damage, knockback)

	$AnimatedSprite2D.play("explode")
	await $AnimatedSprite2D.animation_finished
	queue_free()


func get_radius() -> float:
	var circle := $CollisionShape2D.shape as CircleShape2D
	return circle.radius


func _on_area_entered(area: Area2D) -> void:
	is_player_inside = true


func _on_area_exited(area: Area2D) -> void:
	is_player_inside = false
