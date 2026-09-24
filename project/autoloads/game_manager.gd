extends Node

## 런 상태 요약. 시뮬레이션이 진실이고, 여기는 UI·타이틀·결과 화면이 읽는 거울이다.
## 게임 씬이 틱마다 sync()로 갱신한다.

signal minerals_changed(amount: int)
signal game_over_triggered()

var minerals: int = 150
var kill_count: int = 0
var game_time: float = 0.0
var peak_enemies: int = 0
var is_game_over: bool = false

## 개인 최고 기록 (런을 넘어 남는다). 테스트는 경로를 바꿔 실제 기록을 건드리지 않는다
var records_path: String = "user://records.cfg"
const RECORD_KEYS: Array[String] = ["time", "kills", "peak"]

func _process(delta: float) -> void:
	if not is_game_over and not GameFeel.paused:
		game_time += delta

func sync(sim) -> void:
	if minerals != sim.minerals:
		minerals = sim.minerals
		minerals_changed.emit(minerals)
	kill_count = sim.kills
	peak_enemies = sim.peak_alive()
	if sim.game_over and not is_game_over:
		is_game_over = true
		game_over_triggered.emit()

## 이전 최고 기록을 읽는다. 없으면 0
func load_records() -> Dictionary:
	var cfg := ConfigFile.new()
	var ok := cfg.load(records_path) == OK
	var out := {}
	for k in RECORD_KEYS:
		out[k] = float(cfg.get_value("best", k, 0.0)) if ok else 0.0
	out["runs"] = int(cfg.get_value("stats", "runs", 0)) if ok else 0
	return out

## 런 요약을 기록과 비교해 갱신한다. 반환: 이전 최고(best_*)와 갱신 여부(new_*)
func submit_run(summary: Dictionary) -> Dictionary:
	var prev := load_records()
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var result := {"runs": int(prev["runs"]) + 1}
	for k in RECORD_KEYS:
		var value := float(summary.get(k, 0.0))
		var best := float(prev[k])
		# 첫 런은 비교 대상이 없으므로 "갱신"으로 치지 않는다
		result["new_" + k] = int(prev["runs"]) > 0 and value > best
		result["best_" + k] = maxf(best, value)
		cfg.set_value("best", k, maxf(best, value))
	cfg.set_value("stats", "runs", result["runs"])
	cfg.save(records_path)
	return result

func reset() -> void:
	minerals = 150
	kill_count = 0
	game_time = 0.0
	peak_enemies = 0
	is_game_over = false
