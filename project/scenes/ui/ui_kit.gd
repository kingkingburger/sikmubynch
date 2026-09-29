extends RefCounted

## 공통 UI 스타일: 색, 폰트, 패널, 버튼, 라벨. 타이틀·HUD·결과 화면이 같은 모양을 쓰게 한다.
## 방향: 어두운 금속 패널(모서리 깎음) + 금색 강조 + 크리스탈 청록. 제목·숫자는 Black Han Sans, 본문은 Pretendard.

const FONT_DISPLAY: FontFile = preload("res://assets/fonts/BlackHanSans-Regular.ttf")
const FONT_REGULAR: FontFile = preload("res://assets/fonts/Pretendard-Regular.otf")
const FONT_SEMIBOLD: FontFile = preload("res://assets/fonts/Pretendard-SemiBold.otf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/Pretendard-Bold.otf")

const PANEL := Color(0.075, 0.09, 0.115, 0.94)
const PANEL_HI := Color(0.12, 0.14, 0.175, 0.96)
const LINE := Color(0.23, 0.27, 0.32)
const LINE_HI := Color(0.34, 0.38, 0.44)
const AMBER := Color(0.96, 0.72, 0.24)
const AMBER_HI := Color(1.0, 0.84, 0.48)
const AMBER_DARK := Color(0.11, 0.08, 0.02)
const CRYSTAL := Color(0.37, 0.89, 1.0)
const CRYSTAL_HI := Color(0.73, 0.96, 1.0)
const DANGER := Color(1.0, 0.3, 0.24)
const OK := Color(0.48, 0.88, 0.54)
const TEXT := Color(0.925, 0.9, 0.84)
const TEXT_2 := Color(0.6, 0.64, 0.68)
const TEXT_3 := Color(0.42, 0.46, 0.52)

## 모서리를 깎은 패널 (corner_detail 1 = 둥글지 않고 직선으로 깎임)
static func plate(bg: Color = PANEL, border: Color = LINE, cut: int = 8, border_w: int = 1, pad: Vector4 = Vector4(14, 10, 14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(cut)
	s.corner_detail = 1
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s

static func label(text: String, size: int, color: Color = TEXT, font: Font = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l

## 숫자·제목용 (Black Han Sans, 얇은 그림자)
static func display(text: String, size: int, color: Color = TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, FONT_DISPLAY, align)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

## 작은 대문자형 캡션 (자간 넓게 보이도록 SemiBold + 흐린 색)
static func caption(text: String, size: int = 11, color: Color = TEXT_3,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return label(text, size, color, FONT_BOLD, align)

## primary: 금색으로 채운 주 버튼. 아니면 어두운 패널 버튼 (호버 시 금색 테두리)
static func button(text: String, min_size: Vector2, font_size: int = 18, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", font_size)
	var pad := Vector4(22, 8, 22, 8)
	if primary:
		b.add_theme_color_override("font_color", AMBER_DARK)
		b.add_theme_color_override("font_hover_color", AMBER_DARK)
		b.add_theme_color_override("font_pressed_color", AMBER_DARK)
		b.add_theme_stylebox_override("normal", plate(AMBER, AMBER_HI, 6, 1, pad))
		b.add_theme_stylebox_override("hover", plate(AMBER_HI, Color(1, 0.93, 0.72), 6, 1, pad))
		b.add_theme_stylebox_override("pressed", plate(AMBER.darkened(0.12), AMBER_HI, 6, 1, pad))
	else:
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", AMBER_HI)
		b.add_theme_color_override("font_pressed_color", AMBER)
		b.add_theme_stylebox_override("normal", plate(Color(0.08, 0.095, 0.12, 0.82), LINE, 6, 1, pad))
		b.add_theme_stylebox_override("hover", plate(Color(0.13, 0.12, 0.09, 0.92), AMBER, 6, 1, pad))
		b.add_theme_stylebox_override("pressed", plate(Color(0.16, 0.13, 0.07, 0.95), AMBER, 6, 1, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

## 버튼 누름·호버에 짧은 크기 반응 (부드러운 손맛)
static func add_press_feel(b: Control) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		AudioManager.play_sfx_by_name("ui_click", -18.0, 1.6)
	)
	b.mouse_exited.connect(func() -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

static func slider_theme(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.035, 0.045)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	fill.set_corner_radius_all(2)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture(16, AMBER_HI)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", _knob_texture(18, Color.WHITE))

static func _knob_texture(px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	for y in px:
		for x in px:
			# 마름모 손잡이
			var d := absf(x - c) + absf(y - c)
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)

## 천 단위 쉼표
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]
