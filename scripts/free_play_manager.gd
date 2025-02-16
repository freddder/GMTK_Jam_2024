extends Node

signal on_started()

var _should_scale := false
var scaling_time: float = 0.0


func _ready() -> void:
	stop_scaling()
	Events.on_game_started.connect(stop_scaling)
	Events.on_game_failed.connect(stop_scaling)


func _process(delta: float) -> void:
	scaling_time += delta


func start_scaling() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	_should_scale = true
	on_started.emit()


func stop_scaling() -> void:
	process_mode = PROCESS_MODE_DISABLED
	_should_scale = false


func get_scale() -> float:
	return scaling_time / 60.0
