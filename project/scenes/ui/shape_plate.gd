extends Control

## 사다리꼴 금속 패널. 위쪽 두 모서리를 inset_top만큼, 아래쪽 두 모서리를 inset_bottom만큼 안으로 민다.
## 타이머 판(아래가 좁음)과 건설 바 배경(위가 좁음)에 쓴다. 세로 그라데이션 + 윗선 하이라이트.

const UiKit := preload("res://scenes/ui/ui_kit.gd")

var inset_top: float = 0.0
var inset_bottom: float = 0.0
var top_color := Color(0.12, 0.14, 0.175, 0.95)
var bottom_color := Color(0.05, 0.06, 0.08, 0.95)
var border := UiKit.LINE
var draw_top_edge: bool = true

func _init(top_inset: float = 0.0, bottom_inset: float = 0.0) -> void:
	inset_top = top_inset
	inset_bottom = bottom_inset
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([
		Vector2(inset_top, 0), Vector2(w - inset_top, 0),
		Vector2(w - inset_bottom, h), Vector2(inset_bottom, h)])
	# 그림자
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	draw_polygon(pts, PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	var outline := pts.duplicate()
	outline.append(pts[0])
	if not draw_top_edge:
		outline = PackedVector2Array([pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(outline, border, 1.0, true)
	# 안쪽 윗선 하이라이트
	draw_line(Vector2(inset_top + 2, 1.5), Vector2(w - inset_top - 2, 1.5), Color(1, 1, 1, 0.06), 1.0)
