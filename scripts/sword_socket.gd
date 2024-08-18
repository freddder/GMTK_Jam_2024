class_name SwordSocket
extends Node2D

@export var blade_tip: Texture2D
@export var blade_core: Texture2D
@export var hilt: Texture2D


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-hilt.get_size() / 2.0, hilt.get_size())
	draw_texture_rect(hilt, rect, false)

	var scale := get_blade_scale()

	rect.size = blade_core.get_size() * Vector2(1.0, scale)
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_core, rect, false)

	rect.size = blade_tip.get_size()
	rect.position.x = -rect.size.x / 2.0
	rect.position.y -= rect.size.y

	draw_texture_rect(blade_tip, rect, false)


func get_blade_scale() -> float:
	var player := get_parent() as PlayerCharacter
	return pow(player.get_charge_power(), 1.8)
