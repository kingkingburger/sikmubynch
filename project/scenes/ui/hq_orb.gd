extends Control

## 본진 체력 구슬 (디아블로식). 붉은 액체 높이가 체력 비율이고, 깎이면 출렁이며 부드럽게 내려간다.
## 공격받으면 테두리가 붉게 맥동한다. 전체 화면 효과는 쓰지 않는다.

const UiKit := preload("res://scenes/ui/ui_kit.gd")

var ratio: float = 1.0          # 목표 체력 비율
var _shown: float = 1.0         # 화면에 보이는 비율 (보간)
var _slosh: float = 0.0         # 출렁임 세기
var _time: float = 0.0
var _alarm: float = 0.0
var _hp_label: Label
var _caption: Label

func _init() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_hp_label = UiKit.display("", 30, Color(1, 0.97, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(_hp_label)
	_caption = UiKit.label(Locale.t("hq"), 13, Color(1, 0.86, 0.82), UiKit.FONT_BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_caption)

func set_hp(hp: float, max_hp: float) -> void:
	var r := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if r < ratio - 0.0005:
		_slosh = minf(_slosh + (ratio - r) * 30.0 + 0.4, 1.5)
	ratio = r
	_hp_label.text = UiKit.thousands(int(ceil(hp)))

func alarm() -> void:
	_alarm = 1.0

func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, ratio, 1.0 - exp(-6.0 * delta))
	_slosh = maxf(_slosh - delta * 1.2, 0.0)
	_alarm = maxf(_alarm - delta * 0.8, 0.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 8.0
	# 바깥 링 + 그림자
	draw_circle(c + Vector2(0, 4), r + 9.0, Color(0, 0, 0, 0.45))
	draw_circle(c, r + 8.0, Color(0.1, 0.11, 0.13))
	draw_circle(c, r + 6.0, Color(0.24, 0.26, 0.3))
	draw_circle(c, r + 2.0, Color(0.05, 0.05, 0.06))
	# 안쪽 빈 유리
	draw_circle(c, r, Color(0.09, 0.03, 0.035))
	# 액체: 원 안에서 물결치는 수면 아래만 채운다.
	# x마다 위(수면과 원 윗변 중 아래쪽)·아래(원 아랫변)를 구해 x-단조 다각형으로 만든다 (어느 수위에서도 삼각분할 가능)
	if _shown > 0.002:
		var level := c.y + r - 2.0 * r * _shown
		var amp := (2.0 + 5.0 * _slosh) * minf(_shown * 6.0, 1.0)
		var tops := PackedVector2Array()
		var bottoms := PackedVector2Array()
		var surface := PackedVector2Array()   # 실제 수면 구간만 (원 윗변에 막힌 곳은 뺀다)
		var samples := 40
		for i in range(samples + 1):
			var x := c.x - r + 2.0 * r * float(i) / float(samples)
			var dx := x - c.x
			var h := sqrt(maxf(r * r - dx * dx, 0.0))
			var wave := level + sin(_time * 3.2 + float(i) * 0.35) * amp
			var top := maxf(wave, c.y - h)
			var bottom := c.y + h
			if bottom - top > 0.5:
				tops.append(Vector2(x, top))
				bottoms.append(Vector2(x, bottom))
				if wave > c.y - h:
					surface.append(Vector2(x, top))
		if tops.size() >= 2:
			var poly := PackedVector2Array(tops)
			var cols := PackedColorArray()
			for i in range(bottoms.size() - 1, -1, -1):
				poly.append(bottoms[i])
			for p in poly:
				var t := clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)
				cols.append(Color(1.0, 0.36, 0.28).lerp(Color(0.38, 0.03, 0.05), t))
			draw_polygon(poly, cols)
			if surface.size() >= 2:
				draw_polyline(surface, Color(1.0, 0.62, 0.52, 0.8), 2.0, true)
	# 유리 반사
	draw_circle(c + Vector2(-r * 0.3, -r * 0.45), r * 0.28, Color(1, 1, 1, 0.1))
	draw_circle(c + Vector2(-r * 0.36, -r * 0.52), r * 0.12, Color(1, 1, 1, 0.14))
	# 링 강조 + 경보 맥동
	draw_arc(c, r + 4.0, 0.0, TAU, 64, Color(0.4, 0.43, 0.48), 1.5, true)
	if _alarm > 0.0:
		var pulse := 0.5 + 0.5 * sin(_time * 12.0)
		draw_arc(c, r + 4.0, 0.0, TAU, 64, Color(1.0, 0.25, 0.2, _alarm * (0.5 + 0.5 * pulse)), 4.0, true)
