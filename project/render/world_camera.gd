extends Camera2D

## 쿼터뷰 카메라. 타일 좌표 중심을 들고 화면 좌표로 변환한다. 흔들림은 GameFeel.shake_offset을 더한다.
## 휠 줌과 WASD 이동은 목표값을 향해 지수 보간한다 (한 칸씩 점프하지 않는다).

const Iso := preload("res://render/iso.gd")

const PAN_SPEED_TILES := 28.0
const PAN_RESPONSE := 12.0     # WASD 가감속 (1/초). 클수록 즉각적
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
const ZOOM_STEP := 1.15
const ZOOM_RESPONSE := 14.0    # 휠 줌 수렴 속도 (1/초)
const DEFAULT_ZOOM := 0.7

var center_tile: Vector2 = Vector2(64.0, 64.0)
var map_size: int = 128
var zoom_level: float = 1.0

var _zoom_target: float = 1.0
var _zoom_anchor: Vector2 = Vector2.ZERO   # 줌 중에 고정할 화면 좌표
var _pan_velocity: Vector2 = Vector2.ZERO  # 화면 px/초

func setup(size: int, start_center: Vector2) -> void:
	map_size = size
	center_tile = start_center
	zoom_level = DEFAULT_ZOOM
	_zoom_target = zoom_level
	zoom = Vector2(zoom_level, zoom_level)
	_apply()

func pan_tiles(delta_tiles: Vector2) -> void:
	center_tile += delta_tiles
	_clamp()
	_apply()

## 화면 픽셀 이동량을 타일 이동량으로 바꿔 팬
func pan_screen(delta_px: Vector2) -> void:
	var world_delta := Iso.to_world(delta_px / zoom_level)
	center_tile += world_delta
	_clamp()
	_apply()

## 즉시 줌 (도구·테스트용). 입력은 zoom_smooth를 쓴다.
func zoom_by(factor: float, anchor_screen: Vector2, viewport_size: Vector2) -> void:
	_set_zoom_anchored(clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX), anchor_screen, viewport_size)
	_zoom_target = zoom_level

## 휠 입력: 목표 줌만 바꾸고, frame_tick에서 앵커를 고정한 채 부드럽게 따라간다.
func zoom_smooth(factor: float, anchor_screen: Vector2) -> void:
	_zoom_target = clampf(_zoom_target * factor, ZOOM_MIN, ZOOM_MAX)
	_zoom_anchor = anchor_screen

func _set_zoom_anchored(new_zoom: float, anchor_screen: Vector2, viewport_size: Vector2) -> void:
	var before := screen_to_world(anchor_screen, viewport_size)
	zoom_level = new_zoom
	zoom = Vector2(zoom_level, zoom_level)
	var after := screen_to_world(anchor_screen, viewport_size)
	center_tile += before - after
	_clamp()
	_apply()

func _clamp() -> void:
	var pad := 6.0
	center_tile.x = clampf(center_tile.x, pad, float(map_size) - pad)
	center_tile.y = clampf(center_tile.y, pad, float(map_size) - pad)

func _apply() -> void:
	position = Iso.to_screen_v(center_tile)

func apply_shake() -> void:
	offset = GameFeel.shake_offset

## 화면 픽셀 → 타일 좌표
func screen_to_world(screen_pos: Vector2, viewport_size: Vector2) -> Vector2:
	var rel := (screen_pos - viewport_size * 0.5) / zoom_level
	return Iso.to_world(position + rel)

## 줌 보간 중인가 (고스트 위치 갱신용)
func is_zooming() -> bool:
	return absf(zoom_level - _zoom_target) > 0.0005

func frame_tick(delta: float, allow_input: bool = true) -> void:
	var dir := Vector2.ZERO
	if allow_input:
		if Input.is_key_pressed(KEY_W):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			dir.y += 1.0
		if Input.is_key_pressed(KEY_A):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			dir.x += 1.0
	# 화면 기준 목표 속도로 부드럽게 가감속 (W = 화면 위 = 타일 (-1,-1) 방향)
	var want := dir.normalized() * PAN_SPEED_TILES * Iso.HALF_W
	_pan_velocity = _pan_velocity.lerp(want, 1.0 - exp(-PAN_RESPONSE * delta))
	if _pan_velocity.length_squared() > 0.25:
		center_tile += Iso.to_world(_pan_velocity * delta)
		_clamp()
		_apply()
	elif dir == Vector2.ZERO:
		_pan_velocity = Vector2.ZERO
	if is_zooming():
		var vp := get_viewport_rect().size
		var z := lerpf(zoom_level, _zoom_target, 1.0 - exp(-ZOOM_RESPONSE * delta))
		if absf(z - _zoom_target) <= 0.0005:
			z = _zoom_target
		_set_zoom_anchored(z, _zoom_anchor, vp)
	apply_shake()
