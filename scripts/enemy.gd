extends Area2D

@export var default_speed: float = 250.0

var player: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_node("../Player")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta: float) -> void:
	var direction: Vector2 = (player.position - position).normalized()
	var velocity := direction * default_speed * delta
	position += velocity
