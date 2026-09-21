extends Camera2D

## 쿼터뷰 카메라. 타일 좌표 중심을 들고 화면 좌표로 변환한다. 흔들림은 GameFeel.shake_offset을 더한다.

const Iso := preload("res://render/iso.gd")

const PAN_SPEED_TILES := 28.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
const ZOOM_STEP := 1.15
const DEFAULT_ZOOM := 0.7

var center_tile: Vector2 = Vector2(64.0, 64.0)
var map_size: int = 128
var zoom_level: float = 1.0

func setup(size: int, start_center: Vector2) -> void:
	map_size = size
	center_tile = start_center
	zoom_level = DEFAULT_ZOOM
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

func zoom_by(factor: float, anchor_screen: Vector2, viewport_size: Vector2) -> void:
	var before := screen_to_world(anchor_screen, viewport_size)
	zoom_level = clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX)
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

func frame_tick(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		# 화면 기준 방향을 타일 기준으로 (W = 화면 위 = 타일 (-1,-1) 방향)
		var screen_delta := dir.normalized() * PAN_SPEED_TILES * delta * Iso.HALF_W
		var world_delta := Iso.to_world(screen_delta)
		center_tile += world_delta
		_clamp()
		_apply()
	apply_shake()
