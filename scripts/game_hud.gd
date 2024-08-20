class_name GameHUD
extends CanvasLayer

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

func _ready():
	player.health_changed.connect(update_health_bar)
	update_health_bar()


func update_health_bar():
	$HealthBar.value = player.health / player.default_health


func _on_pause_button_pressed():
	$PauseMenu.toggle_pause_game()
