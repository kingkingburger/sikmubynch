extends Node

## 화면 흔들림, 슬로모션, 정지·배속. Engine.time_scale에 의존하지 않는다.
## 게임 씬이 consume_sim_time()으로 이번 프레임에 시뮬레이션에 넘길 시간을 받아 간다.
## 타격감은 개별 처치가 아니라 틱 처치 수에 비례해 커진다(report_kills).
##
## 부드러움 원칙:
## - 흔들림은 매 프레임 새 난수가 아니라 연속 노이즈를 따라 움직인다. 세기는 빠르게 올라가고 지수로 줄어든다.
## - 시뮬레이션을 딱 멈추는 히트스톱은 쓰지 않는다. 대량 처치에서 매 틱 멈춰 화면이 끊겨 보였다.
##   대신 시간 배율을 잠깐 낮췄다가 부드럽게 되돌리는 슬로모션을 쓰고, 연달아 걸리지 않게 쿨다운을 둔다.

const SHAKE_MAX := 22.0
const SHAKE_ATTACK := 30.0     # 세기가 목표까지 올라가는 속도 (1/초)
const SHAKE_DECAY := 5.5       # 세기가 줄어드는 지수 속도 (1/초)
const SHAKE_FREQ := 14.0       # 흔들림 노이즈 진행 속도 (초당 샘플 거리)
const SLOWMO_RECOVER := 3.2    # 슬로모션에서 1.0으로 돌아오는 속도 (1/초)
const SLOWMO_COOLDOWN := 1.4   # 슬로모션 재발동 최소 간격 (초)

var shake_intensity: float = 0.0   # 현재 세기 (px)
var shake_offset: Vector2 = Vector2.ZERO
var _shake_target: float = 0.0
var _shake_t: float = 0.0
var _noise_x := FastNoiseLite.new()
var _noise_y := FastNoiseLite.new()

var time_dilation: float = 1.0     # 시뮬레이션 시간 배율 (슬로모션)
var _slowmo_cooldown: float = 0.0
var game_speed: float = 1.0
var paused: bool = false
var _pause_reasons: Dictionary = {}

func _ready() -> void:
	for n in [_noise_x, _noise_y]:
		(n as FastNoiseLite).noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		(n as FastNoiseLite).frequency = 1.0
	_noise_x.seed = 17
	_noise_y.seed = 91

func _process(delta: float) -> void:
	_tick_shake(delta)
	_tick_slowmo(delta)

func _tick_shake(delta: float) -> void:
	# 목표 세기로 빠르게 올라가고, 목표는 지수로 줄어든다 → 튀지 않고 이어지는 흔들림
	_shake_target *= exp(-SHAKE_DECAY * delta)
	if shake_intensity < _shake_target:
		shake_intensity = lerpf(shake_intensity, _shake_target, 1.0 - exp(-SHAKE_ATTACK * delta))
	else:
		shake_intensity = _shake_target
	if shake_intensity <= 0.05:
		shake_intensity = 0.0
		_shake_target = 0.0
		shake_offset = shake_offset.lerp(Vector2.ZERO, minf(20.0 * delta, 1.0))
		return
	_shake_t += delta * SHAKE_FREQ
	shake_offset = Vector2(
		_noise_x.get_noise_1d(_shake_t) * shake_intensity,
		_noise_y.get_noise_1d(_shake_t) * shake_intensity * 0.6
	)

func _tick_slowmo(delta: float) -> void:
	if _slowmo_cooldown > 0.0:
		_slowmo_cooldown = maxf(_slowmo_cooldown - delta, 0.0)
	if time_dilation < 1.0:
		time_dilation = minf(1.0, 1.0 - (1.0 - time_dilation) * exp(-SLOWMO_RECOVER * delta))
		if time_dilation > 0.995:
			time_dilation = 1.0

## 이번 프레임에 시뮬레이션이 진행할 시간. 정지면 0.
func consume_sim_time(delta: float) -> float:
	if paused:
		return 0.0
	return delta * game_speed * time_dilation

func shake(intensity: float) -> void:
	_shake_target = minf(maxf(_shake_target, intensity), SHAKE_MAX)

## 시뮬레이션을 잠깐 느리게 한다 (scale까지 떨어졌다가 부드럽게 1.0으로). 쿨다운 중이면 무시.
func slowmo(scale: float) -> void:
	if _slowmo_cooldown > 0.0:
		return
	time_dilation = minf(time_dilation, scale)
	_slowmo_cooldown = SLOWMO_COOLDOWN

## 틱 처치 수에 비례한 피드백. 1마리는 거의 없고, 수십 마리부터 흔들린다.
func report_kills(count: int, explosion_kills: int) -> void:
	if count <= 0:
		return
	var s := 0.0
	if count >= 40:
		s = 12.0
		slowmo(0.45)
	elif count >= 15:
		s = 7.0
	elif count >= 5:
		s = 3.5
	elif count >= 2:
		s = 1.5
	if explosion_kills >= 8:
		s = maxf(s, 6.0 + minf(float(explosion_kills) * 0.2, 8.0))
	if s > 0.0:
		shake(s)

func report_building_destroyed(is_hq: bool) -> void:
	shake(18.0 if is_hq else 5.0)
	if is_hq:
		slowmo(0.25)

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
	_shake_target = 0.0
	shake_offset = Vector2.ZERO
	time_dilation = 1.0
	_slowmo_cooldown = 0.0
	game_speed = 1.0
	_pause_reasons.clear()
	paused = false
