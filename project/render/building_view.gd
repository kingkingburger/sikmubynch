extends Node2D

## 건물 하나의 표현. 시뮬레이션 인덱스를 들고 HP를 읽기만 한다.
## 폴백 스프라이트: 이소메트릭 블록(윗면 마름모 + 좌우 측면) + 타입별 지붕 장식 + HP 바.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")

var sim_index: int = -1
var _tex: Texture2D = null    # assets/sprites/buildings/<name>.png 가 있으면 사용
var data: BuildingData
var tile_x: int = 0
var tile_y: int = 0
var size: int = 1

var _hp_ratio: float = 1.0
var _flash: float = 0.0
var _fire: float = 0.0        # 총구 섬광 세기 (0..1)
var _last_hp: float = -1.0
var _pulse: float = 0.0

func setup(index: int, bd: BuildingData, tx: int, ty: int) -> void:
	sim_index = index
	data = bd
	tile_x = tx
	tile_y = ty
	size = bd.size
	position = Iso.to_screen(float(tx) + float(size) * 0.5, float(ty) + float(size) * 0.5)
	_tex = SpriteFactory.load_sprite("buildings", SpriteFactory.building_sprite_key(bd.building_name))
	if _tex != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	var fire_age: int = tick_index - buildings.last_fire_tick[sim_index]
	var new_fire := clampf(1.0 - float(fire_age) / 3.0, 0.0, 1.0)
	var need := false
	if hp != _last_hp:
		_last_hp = hp
		_hp_ratio = ratio
		need = true
	if absf(new_flash - _flash) > 0.01:
		_flash = new_flash
		need = true
	if absf(new_fire - _fire) > 0.01:
		_fire = new_fire
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
	if _tex != null:
		_draw_sprite()
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

	# 지붕 장식. 발사 직후에는 반동(위로 튐)과 총구 섬광.
	var recoil := Vector2(0.0, -3.0 * _fire)
	var roof_center := (top_t + bottom_t) * 0.5 + recoil
	match data.building_type:
		BuildingData.BuildingType.GUN_TOWER:
			draw_circle(roof_center, 7.0, Color(0.25, 0.22, 0.18))
			draw_circle(roof_center, 4.0, Color(1.0, 0.9, 0.5))
			if _fire > 0.0:
				draw_circle(roof_center + Vector2(0, -6), 5.0 + 4.0 * _fire, Color(1.0, 0.95, 0.6, 0.9 * _fire))
		BuildingData.BuildingType.CANNON_TOWER:
			draw_circle(roof_center, 11.0, Color(0.2, 0.16, 0.14))
			draw_circle(roof_center, 6.0, Color(1.0, 0.5, 0.2))
			if _fire > 0.0:
				draw_circle(roof_center + Vector2(0, -8), 9.0 + 8.0 * _fire, Color(1.0, 0.7, 0.3, 0.85 * _fire))
		BuildingData.BuildingType.FROST_TOWER:
			var d := PackedVector2Array([
				roof_center + Vector2(0, -10), roof_center + Vector2(7, 0),
				roof_center + Vector2(0, 10), roof_center + Vector2(-7, 0)
			])
			draw_colored_polygon(d, Color(0.8, 0.97, 1.0))
			if _fire > 0.0:
				draw_circle(roof_center, 8.0 + 6.0 * _fire, Color(0.7, 0.95, 1.0, 0.6 * _fire))
		BuildingData.BuildingType.FLAME_TOWER:
			# 노즐 + 불씨. 발사 중에는 불꽃이 커진다
			draw_circle(roof_center, 8.0, Color(0.22, 0.14, 0.1))
			draw_circle(roof_center, 4.5, Color(1.0, 0.55, 0.15))
			var glow := 0.35 + 0.65 * _fire
			draw_circle(roof_center + Vector2(0, -5), 6.0 + 7.0 * _fire, Color(1.0, 0.5, 0.1, 0.75 * glow))
			draw_circle(roof_center + Vector2(0, -8), 3.0 + 4.0 * _fire, Color(1.0, 0.9, 0.4, 0.9 * glow))
		BuildingData.BuildingType.TESLA_TOWER:
			# 코일: 세로 막대 + 구체. 발사 시 구체가 밝아진다
			draw_line(roof_center + Vector2(0, 4), roof_center + Vector2(0, -14), Color(0.3, 0.28, 0.4), 4.0)
			draw_circle(roof_center + Vector2(0, -16), 6.0, Color(0.75, 0.7, 1.0))
			if _fire > 0.0:
				draw_circle(roof_center + Vector2(0, -16), 9.0 + 8.0 * _fire, Color(0.8, 0.75, 1.0, 0.7 * _fire))
		BuildingData.BuildingType.SNIPER_TOWER:
			# 긴 총열 + 조준경. 발사 시 총열 끝 섬광
			var barrel_end := roof_center + Vector2(14, -10)
			draw_line(roof_center, barrel_end, Color(0.2, 0.25, 0.22), 5.0)
			draw_line(roof_center, barrel_end, Color(0.55, 0.8, 0.65), 2.0)
			draw_circle(roof_center, 5.0, Color(0.3, 0.6, 0.45))
			if _fire > 0.0:
				draw_circle(barrel_end, 5.0 + 7.0 * _fire, Color(0.8, 1.0, 0.85, 0.95 * _fire))
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

## 스프라이트 모드. 캔버스 바닥 중앙 = 발자국 마름모 아래 꼭짓점. 피격은 붉은 틴트, 발사는 상단 섬광.
func _draw_sprite() -> void:
	var s := float(size)
	var half := s * 0.5
	var bottom_b := Iso.to_screen(half, half)
	var top_b := Iso.to_screen(-half, -half)
	var right_b := Iso.to_screen(half, -half)
	var left_b := Iso.to_screen(-half, half)
	# 바닥 그림자
	var shadow := PackedVector2Array([
		top_b + Vector2(4.0, 2.0), right_b + Vector2(10.0, 4.0), bottom_b + Vector2(6.0, 6.0), left_b + Vector2(0.0, 4.0)
	])
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.35))
	var w := float(_tex.get_width())
	var h := float(_tex.get_height())
	var rect := Rect2(bottom_b.x - w * 0.5, bottom_b.y - h, w, h)
	var tint := Color.WHITE
	if _flash > 0.0:
		tint = Color(1.0, 1.0 - 0.6 * _flash, 1.0 - 0.6 * _flash)
	if data.building_type == BuildingData.BuildingType.HQ:
		var p := (sin(_pulse) + 1.0) * 0.5
		tint = tint.lightened(0.08 * p)
	draw_texture_rect(_tex, rect, false, tint)
	# 발사 섬광: 스프라이트 위쪽 1/4 지점
	if _fire > 0.0 and data.is_tower():
		var roof := Vector2(bottom_b.x, bottom_b.y - h * 0.78)
		var col := data.color.lightened(0.55)
		col.a = 0.9 * _fire
		var radius := 6.0 + 5.0 * _fire
		if data.building_type == BuildingData.BuildingType.CANNON_TOWER:
			radius = 10.0 + 8.0 * _fire
		draw_circle(roof, radius, col)
	# HP 바 (손상됐을 때만)
	if _hp_ratio < 0.999:
		var bw := 30.0 * s
		var bar_y := rect.position.y - 8.0
		var x0 := -bw * 0.5
		draw_rect(Rect2(x0 - 1.0, bar_y - 1.0, bw + 2.0, 6.0), Color(0.05, 0.05, 0.05, 0.9))
		var col := Color(0.2, 0.85, 0.3)
		if _hp_ratio < 0.3:
			col = Color(0.9, 0.2, 0.15)
		elif _hp_ratio < 0.6:
			col = Color(0.9, 0.75, 0.1)
		draw_rect(Rect2(x0, bar_y, bw * _hp_ratio, 4.0), col)
