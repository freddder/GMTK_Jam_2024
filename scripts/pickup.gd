class_name Pickup
extends Node2D

enum Type {
	Heal,
	Wipe,
	Invalid, # Always leave invalid as last
}

var heal_icon := preload("res://content/sprites/pickups/pickup_heal.png")
var wipe_icon := preload("res://content/sprites/pickups/pickup_wipe.png")

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var should_fly_towards_player := false
var pickup_type := Type.Invalid


func _ready() -> void:
	if pickup_type == Type.Invalid:
		pickup_type = randomize_pickup_type()

	modulate = Color.TRANSPARENT
	var tween := get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _physics_process(delta: float) -> void:
	if should_fly_towards_player:
		var speed := 600.0
		global_position = global_position.move_toward(player.global_position, speed * delta)


func _on_collision_area_area_entered(area: Area2D) -> void:
	player.activate_pickup(self)


func _on_fly_trigger_area_area_entered(area: Area2D) -> void:
	should_fly_towards_player = true


func randomize_pickup_type() -> Type:
	var type: Type = Type.values()[randi() % Type.size() - 1]
	match type:
		Type.Heal: $Sprite2D.set_texture(heal_icon)
		Type.Wipe: $Sprite2D.set_texture(wipe_icon)
	return type
