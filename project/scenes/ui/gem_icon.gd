extends Control

## 크리스탈 아이콘. 텍스처 없이 다각형으로 그린다 (자원 표시에 "$" 대신 쓴다).

const UiKit := preload("res://scenes/ui/ui_kit.gd")

var tint: Color = Color.WHITE

func _init(px: float = 16.0) -> void:
	custom_minimum_size = Vector2(px * 0.875, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Vector2(w * 0.5, 0.0)
	var ul := Vector2(0.0, h * 0.32)
	var ur := Vector2(w, h * 0.32)
	var bl := Vector2(w * 0.22, h)
	var br := Vector2(w * 0.78, h)
	var mid := Vector2(w * 0.5, h)
	var outline := Color(0.03, 0.2, 0.27) * tint
	# 왼쪽 밝은 면, 오른쪽 어두운 면, 위쪽 반사
	draw_colored_polygon(PackedVector2Array([top, ul, bl, mid]), UiKit.CRYSTAL_HI * tint)
	draw_colored_polygon(PackedVector2Array([top, mid, br, ur]), Color(0.15, 0.6, 0.78) * tint)
	draw_colored_polygon(PackedVector2Array([top, ul, Vector2(w * 0.5, h * 0.32)]), Color(1, 1, 1, 0.9) * tint)
	draw_polyline(PackedVector2Array([top, ur, br, bl, ul, top]), outline, 1.2, true)
