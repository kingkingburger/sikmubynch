extends RefCounted

## 2:1 이소메트릭 투영. 시뮬레이션 타일 좌표(x 오른쪽, y 아래) ↔ 화면 픽셀.
## 타일 1칸 = 가로 64px, 세로 32px 마름모.

const TILE_W := 64.0
const TILE_H := 32.0
const HALF_W := 32.0
const HALF_H := 16.0

static func to_screen(x: float, y: float) -> Vector2:
	return Vector2((x - y) * HALF_W, (x + y) * HALF_H)

static func to_screen_v(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * HALF_W, (p.x + p.y) * HALF_H)

static func to_world(s: Vector2) -> Vector2:
	var a := s.x / HALF_W
	var b := s.y / HALF_H
	return Vector2((a + b) * 0.5, (b - a) * 0.5)

## 타일 (tx, ty)의 마름모 꼭짓점 4개 (위, 오른쪽, 아래, 왼쪽), 높이 lift(px)만큼 올린다.
static func tile_diamond(tx: float, ty: float, size: float = 1.0, lift: float = 0.0) -> PackedVector2Array:
	var top := to_screen(tx, ty) - Vector2(0.0, lift)
	var right := to_screen(tx + size, ty) - Vector2(0.0, lift)
	var bottom := to_screen(tx + size, ty + size) - Vector2(0.0, lift)
	var left := to_screen(tx, ty + size) - Vector2(0.0, lift)
	return PackedVector2Array([top, right, bottom, left])

## 타일 단위 높이를 픽셀로. 블록 한 칸 높이 = 세로 32px 정도가 자연스럽다.
static func height_px(h: float) -> float:
	return h * TILE_H
