extends Node

@export_group("Enemy")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")
@export var spawn_rate: float = 1.0
@export var enemy_limit: int = 100
@export var boss_spawn_time_seconds: float = 10.0

var enemy_count: int = 0
var should_spawn_enemies: bool = false
var boss_timer: float = 0.0
var boss_spawned: bool = false

func get_spawn_timer_delay() -> float:
	# Relative scale
	# Increase this to make the game harder on low values, but easier on high values,
	# relatively to what it would've been without the scaling
	var scale_exp := 1.3

	# Global scale
	# Increasing it makes the game easier, while decreasing makes it harder
	var scale_offset := 1.0

	# Use pow to scale up spawn rate on low enemy count, but scale it down on high enemy count
	# to try to keep the enemy amount on mid values
	var spawn_rate_multiplier := scale_offset + pow(enemy_count, scale_exp) / enemy_limit
	return (1.0 / spawn_rate) * spawn_rate_multiplier

func can_spawn_enemy() -> bool:
	return $SpawnTimer.is_stopped() and should_spawn_enemies and enemy_limit > enemy_count

func try_spawn_enemy() -> void:
	if not can_spawn_enemy():
		return

	$SpawnTimer.start(get_spawn_timer_delay())
	await $SpawnTimer.timeout

	spawn_enemy()

	# Request to spawn a new enemy
	try_spawn_enemy()

func _ready() -> void:
	Events.on_game_started.connect(on_game_started)
	Events.on_game_victory.connect(on_game_terminated)
	Events.on_game_failed.connect(on_game_terminated)
	
	
func _process(delta):
	if not should_spawn_enemies: return

	boss_timer += delta
	if boss_timer >= boss_spawn_time_seconds and not FreePlayManager._should_scale and not boss_spawned:
		spawn_boss()
		boss_timer = 0

func on_game_started() -> void:
	should_spawn_enemies = true
	try_spawn_enemy()

func on_game_terminated() -> void:
	should_spawn_enemies = false
	$SpawnTimer.stop()

func get_random_spawn_point() -> Vector2:
	var angle := randf() * PI * 2
	var direction := Vector2(cos(angle), sin(angle))
	return direction * Arena.radius

func spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as EnemyCharacter

	enemy.global_position = get_random_spawn_point()
	enemy.on_death.connect(_on_enemy_death)
	enemy_count += 1

	get_tree().root.add_child(enemy)
	
func spawn_boss() -> void:
	var boss := boss_scene.instantiate() as BossCharacter

	boss.global_position = get_random_spawn_point()
	boss_spawned = true
	enemy_count += 1

	get_tree().root.add_child(boss)

func _on_enemy_death(enemy: EnemyCharacter) -> void:
	enemy_count -= 1

	# The spawner could stop spawning due to limit, so try to start the spawning
	# process once again; the request will be ignored if the process is already running
	try_spawn_enemy()
