extends Node

## 화면 흔들림, 히트스톱, 정지·배속. Engine.time_scale에 의존하지 않는다.
## 게임 씬이 consume_sim_time()으로 이번 프레임에 시뮬레이션에 넘길 시간을 받아 간다.
## 타격감은 개별 처치가 아니라 틱 처치 수에 비례해 커진다(report_kills).

var shake_intensity: float = 0.0
var shake_decay: float = 9.0
var shake_offset: Vector2 = Vector2.ZERO

var hitstop_timer: float = 0.0
var game_speed: float = 1.0
var paused: bool = false
var _pause_reasons: Dictionary = {}

const SHAKE_MAX := 22.0

func _process(delta: float) -> void:
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(hitstop_timer - delta, 0.0)
	if shake_intensity > 0.0:
		shake_intensity = maxf(shake_intensity - shake_decay * delta * maxf(shake_intensity, 1.0), 0.0)
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity) * 0.6
		)
		if shake_intensity <= 0.05:
			shake_intensity = 0.0
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2.ZERO

## 이번 프레임에 시뮬레이션이 진행할 시간. 정지·히트스톱이면 0.
func consume_sim_time(delta: float) -> float:
	if paused or hitstop_timer > 0.0:
		return 0.0
	return delta * game_speed

func shake(intensity: float) -> void:
	shake_intensity = minf(maxf(shake_intensity, intensity), SHAKE_MAX)

func hitstop(duration: float) -> void:
	hitstop_timer = maxf(hitstop_timer, duration)

## 틱 처치 수에 비례한 피드백. 1마리는 거의 없고, 수십 마리부터 흔들린다.
func report_kills(count: int, explosion_kills: int) -> void:
	if count <= 0:
		return
	var s := 0.0
	if count >= 40:
		s = 14.0
		hitstop(0.06)
	elif count >= 15:
		s = 8.0
		hitstop(0.035)
	elif count >= 5:
		s = 4.0
	elif count >= 2:
		s = 1.5
	if explosion_kills >= 8:
		s = maxf(s, 6.0 + minf(float(explosion_kills) * 0.2, 8.0))
	if s > 0.0:
		shake(s)

func report_building_destroyed(is_hq: bool) -> void:
	shake(18.0 if is_hq else 5.0)

func set_game_speed(speed: float) -> void:
	game_speed = speed

func toggle_pause() -> void:
	set_pause_reason("manual", not _pause_reasons.has("manual"))

func set_pause_reason(reason: String, enabled: bool) -> void:
	if enabled:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	paused = not _pause_reasons.is_empty()

func has_pause_reason(reason: String) -> bool:
	return _pause_reasons.has(reason)

func cycle_speed() -> float:
	if game_speed < 1.5:
		set_game_speed(2.0)
	elif game_speed < 2.5:
		set_game_speed(3.0)
	else:
		set_game_speed(1.0)
	return game_speed

func reset() -> void:
	shake_intensity = 0.0
	shake_offset = Vector2.ZERO
	hitstop_timer = 0.0
	game_speed = 1.0
	_pause_reasons.clear()
	paused = false
