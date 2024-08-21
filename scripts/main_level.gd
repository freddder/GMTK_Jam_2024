extends Node

var score: int = 0

func _ready() -> void:
	Events.on_game_started.emit()
	Events.on_player_death.connect(_on_player_death)
	Events.on_enemy_spawned.connect(_on_enemy_spawned)
	Events.on_boss_spawned.connect(_on_boss_spawned)
	Events.on_game_victory.connect(play_victory_theme)
	Events.on_game_failed.connect(on_game_failed)
	Events.done_playing_death_sfx.connect(play_death_theme)
	FreePlayManager.on_started.connect(on_freeplay_started)

	var tween := get_tree().create_tween()
	var original_volume: float = $BattleTheme.volume_db
	$BattleTheme.volume_db = -20.0
	tween.tween_property($BattleTheme, "volume_db", original_volume, 1.0)


func _exit_tree() -> void:
	FreePlayManager.stop_scaling()


func _on_player_death() -> void:
	Events.on_game_failed.emit()
	$BattleTheme.stop()


func _on_enemy_spawned(enemy: EnemyCharacter) -> void:
	enemy.on_death.connect(_on_enemy_death)


func _on_enemy_death(enemy: EnemyCharacter) -> void:
	add_score(enemy.get_score())

func _on_boss_spawned(boss: BossCharacter) -> void:
	boss.on_death.connect(_on_boss_death)
	$BattleTheme.stop()
	$BossTheme.play()


func _on_boss_death(boss: BossCharacter) -> void:
	add_score(boss.default_score)


func add_score(_score: float) -> void:
	score += _score
	$GameHUD/ScoreLabel.text = "Score: " + str(score)


func play_death_theme() -> void:
	$DeathTheme.play()


func play_victory_theme() -> void:
	$VictoryTheme.play()
	$BossTheme.stop()


func on_game_failed() -> void:
	$BossTheme.stop()
	$BattleTheme.stop()


func on_freeplay_started() -> void:
	$VictoryTheme.stop()
	$BattleTheme.play()
