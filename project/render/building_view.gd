extends Node2D

## 건물 하나의 표현. 시뮬레이션 인덱스를 들고 HP를 읽기만 한다.
## 폴백 스프라이트: 이소메트릭 블록(윗면 마름모 + 좌우 측면) + 타입별 지붕 장식 + HP 바.

const Iso := preload("res://render/iso.gd")

var sim_index: int = -1
var data: BuildingData
var tile_x: int = 0
var tile_y: int = 0
var size: int = 1

var _hp_ratio: float = 1.0
var _flash: float = 0.0
var _last_hp: float = -1.0
var _pulse: float = 0.0

func setup(index: int, bd: BuildingData, tx: int, ty: int) -> void:
	sim_index = index
	data = bd
	tile_x = tx
	tile_y = ty
	size = bd.size
	position = Iso.to_screen(float(tx) + float(size) * 0.5, float(ty) + float(size) * 0.5)
	queue_redraw()

## 매 프레임 호출. HP 변화가 있을 때만 다시 그린다.
func update_from_sim(buildings, delta: float, tick_index: int) -> void:
	if sim_index < 0 or buildings.alive[sim_index] == 0:
		return
	var hp: float = buildings.hp[sim_index]
	var max_hp: float = buildings.max_hp[sim_index]
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var hit_age: int = tick_index - buildings.last_hit_tick[sim_index]
	var new_flash := clampf(1.0 - float(hit_age) / 4.0, 0.0, 1.0)
	var need := false
	if hp != _last_hp:
		_last_hp = hp
		_hp_ratio = ratio
		need = true
	if absf(new_flash - _flash) > 0.01:
		_flash = new_flash
		need = true
	if data.building_type == BuildingData.BuildingType.HQ:
		_pulse += delta * 2.0
		if _pulse > TAU:
			_pulse -= TAU
		need = true
	if need:
		queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var s := float(size)
	var half := s * 0.5
	var h := Iso.height_px(data.height)
	var base_col := data.color
	if _flash > 0.0:
		base_col = base_col.lerp(Color(1.0, 0.35, 0.3), _flash * 0.8)
	if data.building_type == BuildingData.BuildingType.HQ:
		var p := (sin(_pulse) + 1.0) * 0.5
		base_col = base_col.lightened(0.08 * p)
	# 꼭짓점 (노드 원점 = 발자국 중심)
	var top_b := Iso.to_screen(-half, -half)
	var right_b := Iso.to_screen(half, -half)
	var bottom_b := Iso.to_screen(half, half)
	var left_b := Iso.to_screen(-half, half)
	var lift := Vector2(0.0, h)
	var top_t := top_b - lift
	var right_t := right_b - lift
	var bottom_t := bottom_b - lift
	var left_t := left_b - lift

	# 바닥 그림자
	var shadow := PackedVector2Array([
		top_b + Vector2(4.0, 2.0), right_b + Vector2(10.0, 4.0), bottom_b + Vector2(6.0, 6.0), left_b + Vector2(0.0, 4.0)
	])
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.35))

	# 측면
	var left_face := PackedVector2Array([left_t, bottom_t, bottom_b, left_b])
	var right_face := PackedVector2Array([bottom_t, right_t, right_b, bottom_b])
	draw_colored_polygon(left_face, base_col.darkened(0.42))
	draw_colored_polygon(right_face, base_col.darkened(0.6))
	# 윗면
	var top_face := PackedVector2Array([top_t, right_t, bottom_t, left_t])
	draw_colored_polygon(top_face, base_col)
	# 외곽선
	var outline := base_col.darkened(0.75)
	draw_polyline(PackedVector2Array([top_t, right_t, bottom_t, left_t, top_t]), outline, 1.5)
	draw_line(left_t, left_b, outline, 1.5)
	draw_line(bottom_t, bottom_b, outline, 1.5)
	draw_line(right_t, right_b, outline, 1.5)
	draw_line(left_b, bottom_b, outline, 1.5)
	draw_line(bottom_b, right_b, outline, 1.5)

	# 지붕 장식
	var roof_center := (top_t + bottom_t) * 0.5
	match data.building_type:
		BuildingData.BuildingType.GUN_TOWER:
			draw_circle(roof_center, 7.0, Color(0.25, 0.22, 0.18))
			draw_circle(roof_center, 4.0, Color(1.0, 0.9, 0.5))
		BuildingData.BuildingType.CANNON_TOWER:
			draw_circle(roof_center, 11.0, Color(0.2, 0.16, 0.14))
			draw_circle(roof_center, 6.0, Color(1.0, 0.5, 0.2))
		BuildingData.BuildingType.FROST_TOWER:
			var d := PackedVector2Array([
				roof_center + Vector2(0, -10), roof_center + Vector2(7, 0),
				roof_center + Vector2(0, 10), roof_center + Vector2(-7, 0)
			])
			draw_colored_polygon(d, Color(0.8, 0.97, 1.0))
		BuildingData.BuildingType.HQ:
			var d := PackedVector2Array([
				roof_center + Vector2(0, -22), roof_center + Vector2(26, 0),
				roof_center + Vector2(0, 22), roof_center + Vector2(-26, 0)
			])
			draw_colored_polygon(d, base_col.lightened(0.25))
			draw_circle(roof_center, 8.0, Color(0.6, 0.85, 1.0))
		BuildingData.BuildingType.WALL:
			draw_line(top_t + Vector2(0, 4), bottom_t - Vector2(0, 4), outline, 1.0)
		_:
			pass

	# HP 바 (손상됐을 때만)
	if _hp_ratio < 0.999:
		var w := 30.0 * s
		var bar_y := top_t.y - 10.0
		var x0 := -w * 0.5
		draw_rect(Rect2(x0 - 1.0, bar_y - 1.0, w + 2.0, 6.0), Color(0.05, 0.05, 0.05, 0.9))
		var col := Color(0.2, 0.85, 0.3)
		if _hp_ratio < 0.3:
			col = Color(0.9, 0.2, 0.15)
		elif _hp_ratio < 0.6:
			col = Color(0.9, 0.75, 0.1)
		draw_rect(Rect2(x0, bar_y, w * _hp_ratio, 4.0), col)
