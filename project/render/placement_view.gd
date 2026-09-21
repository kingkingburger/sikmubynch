extends Node2D

## 배치 고스트와 사거리 링. 마우스 아래 타일에 선택 건물의 발자국과 사거리를 보여준다.

const Iso := preload("res://render/iso.gd")

var data: BuildingData
var tile_x: int = -1
var tile_y: int = -1
var can_place: bool = false
var can_afford: bool = true
var shown: bool = false

func show_at(bd: BuildingData, tx: int, ty: int, placeable: bool, affordable: bool) -> void:
	data = bd
	tile_x = tx
	tile_y = ty
	can_place = placeable
	can_afford = affordable
	shown = true
	visible = true
	queue_redraw()

func hide_ghost() -> void:
	if shown:
		shown = false
		visible = false
		queue_redraw()

func _draw() -> void:
	if not shown or data == null:
		return
	var s := float(data.size)
	var col := Color(0.4, 0.85, 0.4, 0.4)
	if not can_place:
		col = Color(0.9, 0.2, 0.2, 0.4)
	elif not can_afford:
		col = Color(0.9, 0.6, 0.2, 0.4)
	var foot := Iso.tile_diamond(float(tile_x), float(tile_y), s)
	draw_colored_polygon(foot, col)
	var h := Iso.height_px(data.height)
	var lifted := Iso.tile_diamond(float(tile_x), float(tile_y), s, h)
	draw_polyline(PackedVector2Array([lifted[0], lifted[1], lifted[2], lifted[3], lifted[0]]), Color(col.r, col.g, col.b, 0.8), 1.5)
	draw_line(foot[1], lifted[1], Color(col.r, col.g, col.b, 0.6), 1.0)
	draw_line(foot[2], lifted[2], Color(col.r, col.g, col.b, 0.6), 1.0)
	draw_line(foot[3], lifted[3], Color(col.r, col.g, col.b, 0.6), 1.0)
	# 사거리 링 (타일 원 → 화면 타원)
	var range_val := 0.0
	var ring_col := Color(1.0, 0.5, 0.2, 0.55)
	if data.attack_range > 0.0:
		range_val = data.attack_range
		if data.building_type == BuildingData.BuildingType.FROST_TOWER:
			ring_col = Color(0.4, 0.8, 1.0, 0.55)
	if range_val > 0.0:
		var center := Iso.to_screen(float(tile_x) + s * 0.5, float(tile_y) + s * 0.5)
		draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, range_val * Iso.HALF_W * 1.4142, 0.0, TAU, 64, ring_col, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
