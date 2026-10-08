extends Control

## 타이틀. 배경은 실제 게임 씬을 데모 모드로 돌린 화면(방어선과 몰려오는 무리)이고, 왼쪽에 로고·한 줄 소개·메뉴를 둔다.
## 플레이어가 읽는 문구만 둔다 (개발 용어·단축키 나열 없음). 조작은 "조작 방법"과 게임 첫 30초 안내로 보여준다.

const UiKit := preload("res://scenes/ui/ui_kit.gd")
const GameScene := preload("res://scenes/main/game.tscn")

var _ui: CanvasLayer
var _fade: ColorRect
var _panel: Control = null
var _starting := false

func _ready() -> void:
	var world := GameScene.instantiate()
	world.demo_mode = true
	add_child(world)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	fade_layer.add_child(_fade)
	_build_ui(true)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Locale.language_changed.connect(func() -> void: _build_ui(false))
	AudioManager.play_bgm_by_name("title")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _panel != null:
		if event.keycode == KEY_ESCAPE:
			_close_panel()
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		_on_start()

func _build_ui(animate: bool) -> void:
	if _ui:
		_ui.queue_free()
	_panel = null
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	# 왼쪽을 어둡게 (글자 읽히게) + 아래쪽 비네트
	root.add_child(_gradient(Vector2(0, 0), Vector2(1, 0), [
		[0.0, Color(0.024, 0.027, 0.04, 0.95)], [0.34, Color(0.024, 0.027, 0.04, 0.8)],
		[0.7, Color(0.024, 0.027, 0.04, 0.12)], [1.0, Color(0.024, 0.027, 0.04, 0.35)]]))
	root.add_child(_gradient(Vector2(0, 1), Vector2(0, 0.6), [
		[0.0, Color(0.024, 0.027, 0.04, 0.9)], [1.0, Color(0.024, 0.027, 0.04, 0.0)]]))

	# 오른쪽 위: 소리 · 언어
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.offset_right = -28.0
	top.offset_left = -28.0
	top.offset_top = 24.0
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var sound := _pill(Locale.t("sound_on") if AudioManager.master_volume >= 0.01 else Locale.t("sound_off"))
	sound.pressed.connect(func() -> void:
		if AudioManager.master_volume < 0.01:
			AudioManager.master_volume = 0.8
			AudioManager.play_bgm_by_name("title")
		else:
			AudioManager.master_volume = 0.0
		sound.text = Locale.t("sound_on") if AudioManager.master_volume >= 0.01 else Locale.t("sound_off"))
	top.add_child(sound)
	var lang := _pill("한국어 · English")
	lang.pressed.connect(Locale.toggle_lang)
	top.add_child(lang)

	# 왼쪽 기둥: 로고 · 소개 · 메뉴
	var col := VBoxContainer.new()
	col.position = Vector2(96, 72)
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 0)
	root.add_child(col)

	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 12)
	var line := ColorRect.new()
	line.color = UiKit.AMBER
	line.custom_minimum_size = Vector2(34, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kicker.add_child(line)
	var spaced := FontVariation.new()
	spaced.base_font = UiKit.FONT_BOLD
	spaced.spacing_glyph = 5
	kicker.add_child(UiKit.label("SIKMUBYNCH", 13, UiKit.AMBER, spaced))
	col.add_child(kicker)

	var logo := UiKit.display("식무변처", 118, Color(0.95, 0.925, 0.86))
	logo.add_theme_color_override("font_shadow_color", Color(0.43, 0.31, 0.07))
	logo.add_theme_constant_override("shadow_offset_y", 5)
	logo.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.9))
	logo.add_theme_constant_override("outline_size", 6)
	col.add_child(logo)

	col.add_child(_gap(10))
	col.add_child(UiKit.label(Locale.t("tagline"), 21, UiKit.TEXT, UiKit.FONT_BOLD))
	col.add_child(_gap(8))
	var sub := UiKit.label(Locale.t("tagline_sub"), 15, UiKit.TEXT_2, UiKit.FONT_REGULAR)
	sub.add_theme_constant_override("line_spacing", 4)
	col.add_child(sub)
	col.add_child(_gap(34))

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(300, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.add_theme_constant_override("separation", 10)
	col.add_child(menu)
	var start := _menu_button(Locale.t("start_game"), true, "Enter")
	start.pressed.connect(_on_start)
	menu.add_child(start)
	var how := _menu_button(Locale.t("how_to_play"), false)
	how.pressed.connect(_open_how_to_play)
	menu.add_child(how)
	var settings := _menu_button(Locale.t("settings"), false)
	settings.pressed.connect(_open_settings)
	menu.add_child(settings)
	var quit := _menu_button(Locale.t("quit"), false)
	quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit)

	# 왼쪽 아래: 개인 기록 (한 판이라도 했을 때만)
	var rec := GameManager.load_records()
	if int(rec["runs"]) > 0:
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		row.offset_left = 96.0
		row.offset_top = -86.0
		row.offset_bottom = -36.0
		row.add_theme_constant_override("separation", 26)
		root.add_child(row)
		row.add_child(_record(Locale.t("best_time"), UiKit.clock(float(rec["time"]))))
		row.add_child(_vline())
		row.add_child(_record(Locale.t("best_kills"), UiKit.thousands(int(rec["kills"]))))
		row.add_child(_vline())
		row.add_child(_record(Locale.t("runs"), Locale.t_fmt("runs_fmt", [int(rec["runs"])])))

	if animate:
		# 위에서부터 차례로 떠오른다
		var items: Array = col.get_children()
		for i in items.size():
			var it: Control = items[i]
			it.modulate.a = 0.0
			var t := it.create_tween()
			t.tween_interval(0.25 + 0.07 * float(i))
			t.tween_property(it, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _gradient(from: Vector2, to: Vector2, stops: Array) -> TextureRect:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _menu_button(text: String, primary: bool, key: String = "") -> Button:
	var b := UiKit.button(text, Vector2(300, 62 if primary else 50), 22 if primary else 18, primary)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if key != "":
		var k := UiKit.label(key, 12, UiKit.AMBER_DARK if primary else UiKit.TEXT_3, UiKit.FONT_BOLD)
		k.modulate.a = 0.55
		k.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		k.offset_left = -60.0
		k.offset_right = -20.0
		k.offset_top = -9.0
		k.offset_bottom = 9.0
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(k)
	UiKit.add_press_feel(b)
	return b

func _pill(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiKit.FONT_SEMIBOLD)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", UiKit.TEXT_2)
	b.add_theme_color_override("font_hover_color", UiKit.TEXT)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.06, 0.075, 0.095, 0.8 if state == "normal" else 0.95)
		s.border_color = UiKit.LINE if state == "normal" else UiKit.LINE_HI
		s.set_border_width_all(1)
		s.set_corner_radius_all(17)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 7
		s.content_margin_bottom = 7
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _record(caption_text: String, value: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UiKit.caption(caption_text, 11, UiKit.TEXT_3))
	v.add_child(UiKit.display(value, 24, UiKit.TEXT))
	return v

func _vline() -> ColorRect:
	var r := ColorRect.new()
	r.color = UiKit.LINE
	r.custom_minimum_size = Vector2(1, 34)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ---------------------------------------------------------------------------
# 패널: 조작 방법 · 설정
# ---------------------------------------------------------------------------

func _open_panel(title_text: String, width: float) -> VBoxContainer:
	_close_panel()
	AudioManager.play_sfx_by_name("ui_click", -6.0)
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(o)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.012, 0.018, 0.6)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_panel())
	o.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	card.add_theme_stylebox_override("panel", UiKit.plate(Color(0.075, 0.09, 0.115, 0.98), UiKit.LINE_HI, 12, 1, Vector4(32, 24, 32, 26)))
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UiKit.display(title_text, 30, UiKit.TEXT))
	var line := ColorRect.new()
	line.color = Color(0.17, 0.2, 0.24)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_panel = o
	o.modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var t := o.create_tween().set_parallel(true)
	t.tween_property(o, "modulate:a", 1.0, 0.2)
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v

func _close_panel() -> void:
	if _panel == null:
		return
	var p := _panel
	_panel = null
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 0.0, 0.15)
	t.tween_callback(p.queue_free)

func _add_close(v: VBoxContainer) -> void:
	v.add_child(_gap(6))
	var close := UiKit.button(Locale.t("close"), Vector2(0, 46), 16, false)
	close.pressed.connect(_close_panel)
	v.add_child(close)

func _open_how_to_play() -> void:
	var v := _open_panel(Locale.t("how_to_play"), 520.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var rows := [
		["1 ~ 8", "ctl_select"], [Locale.t("key_lmb"), "ctl_build"], [Locale.t("key_rmb"), "ctl_demolish"],
		[Locale.t("key_move"), "ctl_move"], [Locale.t("key_wheel"), "ctl_zoom"],
		["Space", "ctl_pause"], ["F", "ctl_speed"], ["B", "ctl_auto_play"], ["Esc", "ctl_menu"]]
	for r in rows:
		var key := UiKit.label(r[0], 14, UiKit.AMBER_HI, UiKit.FONT_BOLD)
		key.custom_minimum_size = Vector2(170, 0)
		grid.add_child(key)
		grid.add_child(UiKit.label(Locale.t(r[1]), 15, UiKit.TEXT, UiKit.FONT_REGULAR))
	_add_close(v)

func _open_settings() -> void:
	var v := _open_panel(Locale.t("settings"), 440.0)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	var ll := UiKit.label(Locale.t("language"), 14, UiKit.TEXT_2, UiKit.FONT_SEMIBOLD)
	ll.custom_minimum_size = Vector2(70, 0)
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang_row.add_child(ll)
	for i in 2:
		var b := UiKit.button("한국어" if i == 0 else "English", Vector2(120, 40), 15, Locale.current_lang == i)
		var target := i
		b.pressed.connect(func() -> void:
			if Locale.current_lang != target:
				Locale.toggle_lang())
		lang_row.add_child(b)
	v.add_child(lang_row)
	var names := ["vol_master", "vol_music", "vol_sfx"]
	var values := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiKit.label(Locale.t(names[i]), 14, UiKit.TEXT_2, UiKit.FONT_SEMIBOLD)
		l.custom_minimum_size = Vector2(70, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = values[i]
		s.focus_mode = Control.FOCUS_NONE
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiKit.slider_theme(s)
		var idx := i
		s.value_changed.connect(func(val: float) -> void:
			match idx:
				0: AudioManager.master_volume = val
				1: AudioManager.music_volume = val
				2: AudioManager.sfx_volume = val
		)
		row.add_child(s)
		v.add_child(row)
	_add_close(v)

func _on_start() -> void:
	if _starting:
		return
	_starting = true
	AudioManager.play_sfx_by_name("ui_click")
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/main/game.tscn"))
