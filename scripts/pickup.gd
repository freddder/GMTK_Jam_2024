class_name Pickup
extends Node2D

enum Type {
	Heal,
	Wipe,
	Invalid = -1,
}

@export var drop_chances: Gradient
@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var should_fly_towards_player := false
var pickup_type := Type.Invalid


func _ready() -> void:
	if pickup_type == Type.Invalid:
		pickup_type = randomize_pickup_type()


func _physics_process(delta: float) -> void:
	if should_fly_towards_player:
		var speed := 600.0
		global_position = global_position.move_toward(player.global_position, speed * delta)


func _on_collision_area_area_entered(area: Area2D) -> void:
	player.activate_pickup(self)


func _on_fly_trigger_area_area_entered(area: Area2D) -> void:
	should_fly_towards_player = true


func randomize_pickup_type() -> Type:
	var sampled := drop_chances.sample(randf())
	for idx in drop_chances.colors.size():
		if sampled == drop_chances.get_color(idx):
			$ColorRect.color = sampled
			return idx
	return Type.Invalid
