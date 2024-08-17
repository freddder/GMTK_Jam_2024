extends Node2D

var enemy = preload("res://scenes/enemy.tscn")

var spawn_points: Array[Node] = []
var enemies_count: int = 0
var enemy_spawn_cooldown: float = 1.0
var timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	timer += delta
	
	if timer >= enemy_spawn_cooldown:
		timer -= enemy_spawn_cooldown
		
		# Spawn an enemy at a random spawn point
		var point_to_spawn := spawn_points[randi() % spawn_points.size()]
		
		var new_enemy = enemy.instantiate()
		new_enemy.position = point_to_spawn.position
		
		get_node('/root/MainLevel').add_child(new_enemy) # probably change this
		enemies_count += 1
