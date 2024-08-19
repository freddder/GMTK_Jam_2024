class_name Pickup
extends Node2D

enum Type {
	Heal,
	Wipe,
	Invalid, # Always leave invalid as last
}

@export var drop_chances: Gradient
@export var heal_icon: Texture2D = preload("res://content/sprites/pickups/pickup_heal.png")
@export var wipe_icon: Texture2D = preload("res://content/sprites/pickups/pickup_wipe.png")

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

var should_fly_towards_player := false
var type := Type.Invalid


func _ready() -> void:
	if type == Type.Invalid:
		type = randomize_pickup_type()

	match type:
		Type.Heal: $Sprite2D.set_texture(heal_icon)
		Type.Wipe: $Sprite2D.set_texture(wipe_icon)

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
	var sampled := drop_chances.sample(randf())
	for idx in drop_chances.colors.size():
		if sampled == drop_chances.get_color(idx):
			return idx
	return Type.Invalid
