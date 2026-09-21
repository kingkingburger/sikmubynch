extends Node

## 런 상태 요약. 시뮬레이션이 진실이고, 여기는 UI·타이틀·결과 화면이 읽는 거울이다.
## 게임 씬이 틱마다 sync()로 갱신한다.

signal minerals_changed(amount: int)
signal game_over_triggered()

var minerals: int = 150
var kill_count: int = 0
var wave_number: int = 1
var game_time: float = 0.0
var peak_enemies: int = 0
var is_game_over: bool = false

func _process(delta: float) -> void:
	if not is_game_over and not GameFeel.paused:
		game_time += delta

func sync(sim) -> void:
	if minerals != sim.minerals:
		minerals = sim.minerals
		minerals_changed.emit(minerals)
	kill_count = sim.kills
	wave_number = sim.waves.wave_number
	peak_enemies = sim.peak_alive()
	if sim.game_over and not is_game_over:
		is_game_over = true
		game_over_triggered.emit()

func reset() -> void:
	minerals = 150
	kill_count = 0
	wave_number = 1
	game_time = 0.0
	peak_enemies = 0
	is_game_over = false
