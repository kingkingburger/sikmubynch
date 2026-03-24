extends Node

signal minerals_changed(amount: int)
signal game_over_triggered()

var minerals: int = 150
var kill_count: int = 0
var wave_number: int = 1
var game_time: float = 0.0
var is_game_over: bool = false

func _process(delta: float) -> void:
	if not is_game_over:
		game_time += delta

func add_minerals(amount: int) -> void:
	minerals += amount
	minerals_changed.emit(minerals)

func spend_minerals(amount: int) -> bool:
	if minerals >= amount:
		minerals -= amount
		minerals_changed.emit(minerals)
		return true
	return false

func add_kill() -> void:
	kill_count += 1

func trigger_game_over() -> void:
	is_game_over = true
	game_over_triggered.emit()

func reset() -> void:
	minerals = 150
	kill_count = 0
	wave_number = 1
	game_time = 0.0
	is_game_over = false
