class_name GameHUD
extends CanvasLayer

@onready var player: PlayerCharacter = get_tree().get_first_node_in_group("player")

func _ready():
	player.health_changed.connect(update_health_bar)
	update_health_bar()
	
func update_health_bar():
	$HealthBar.value = player.health * 100 / player.default_health
	
