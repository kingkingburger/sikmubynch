extends RefCounted

## 게임 HUD. 읽는 순서: 크리스탈(좌상단, 가장 크게) → 본진 구슬(좌하단) → 생존 시간·위협(가운데 위) → 건설 칸(하단) → 레이더.
## 어두운 금속 패널 + 금색 강조. 숫자·막대는 목표값을 향해 보간해 튀지 않는다. 전체 화면 번쩍임은 쓰지 않는다.

const UiKit := preload("res://scenes/ui/ui_kit.gd")
const GemIcon := preload("res://scenes/ui/gem_icon.gd")
const HqOrb := preload("res://scenes/ui/hq_orb.gd")
const BuildSlot := preload("res://scenes/ui/build_slot.gd")
const ShapePlate := preload("res://scenes/ui/shape_plate.gd")
const ThreatRadar := preload("res://scripts/threat_radar.gd")
const BuildingCatalog := preload("res://scripts/building_catalog.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")
const WaveSim := preload("res://sim/wave_sim.gd")

signal slot_pressed(slot_index: int)
signal resume_requested()
signal restart_requested()
signal title_requested()
signal pause_pressed()
signal speed_pressed(speed: float)
signal menu_pressed()
signal auto_play_pressed()

const INCOME_WINDOW := 2.0        # 초당 수입 표시 창
const GAIN_POPUP_INTERVAL := 0.35 # 획득 팝업 합산 간격
const MAX_GAIN_POPUPS := 5
const HINT_SECONDS := 30.0        # 조작 안내가 떠 있는 시간 (게임 시간)
const THREAT_SEGMENTS := 5

## 상단 오른쪽 조작 버튼 (정지·배속·메뉴). 아이콘은 직접 그린다
class CtrlButton extends Button:
	var kind: String = ""       # "pause" | "menu" | "" (텍스트)
	var active: bool = false
	var _hover: float = 0.0
	func _init(k: String, label_text: String) -> void:
		kind = k
		text = label_text
		custom_minimum_size = Vector2(46, 40)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_font_override("font", UiKit.FONT_BOLD)
		add_theme_font_size_override("font_size", 14)
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(s, empty)
	func _process(delta: float) -> void:
		_hover = lerpf(_hover, 1.0 if is_hovered() else 0.0, 1.0 - exp(-16.0 * delta))
		var c := UiKit.TEXT_2.lerp(UiKit.TEXT, _hover).lerp(UiKit.AMBER_HI, 1.0 if active else 0.0)
		add_theme_color_override("font_color", c)
		add_theme_color_override("font_hover_color", c)
		add_theme_color_override("font_pressed_color", c)
		queue_redraw()
	func _draw() -> void:
		if active:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.96, 0.72, 0.24, 0.16))
			draw_rect(Rect2(0, size.y - 2, size.x, 2), UiKit.AMBER)
		elif _hover > 0.01:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05 * _hover))
		var c := size * 0.5
		var col := UiKit.TEXT_2.lerp(UiKit.TEXT, _hover).lerp(UiKit.AMBER_HI, 1.0 if active else 0.0)
		match kind:
			"pause":
				if active:   # 정지 중이면 재생 삼각형
					draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -7), c + Vector2(7, 0), c + Vector2(-5, 7)]), col)
				else:
					draw_rect(Rect2(c.x - 6, c.y - 7, 4, 14), col)
					draw_rect(Rect2(c.x + 2, c.y - 7, 4, 14), col)
			"menu":
				for i in 3:
					draw_rect(Rect2(c.x - 8, c.y - 6 + i * 5, 16, 2), col)

var _canvas: CanvasLayer
var _root: Control
var _slot_types: Array = []
var _building_datas: Array = []

# 크리스탈
var _money_label: Label
var _income_label: Label
var _money_plate: PanelContainer
var _money_target: float = 0.0
var _money_shown: float = -1.0
var _money_pulse: float = 0.0
var _popups: Array = []           # [Label, age, start_y]
var _gain_accum: int = 0
var _gain_timer: float = 0.0
var _income_samples: Array = []   # [time, amount]
var _income_time: float = 0.0

# 가운데 위
var _time_label: Label
var _kills_label: Label
var _enemies_label: Label
var _threat_bars: Array = []
var _threat_shown: float = 0.0

# 오른쪽 위
var _btn_pause: CtrlButton
var _btn_speeds: Array = []
var _btn_menu: CtrlButton
var _btn_auto: CtrlButton

# 본진
var _orb
var _alert: PanelContainer
var _alert_timer: float = 0.0

# 건설
var _slots: Array = []
var _selected_slot: int = 0
var _tip: PanelContainer
var _tip_name: Label
var _tip_cost: Label
var _tip_desc: Label
var _tip_stats: HBoxContainer
var _tip_slot: int = -1
var _tip_hover_slot: int = -1
var _tip_timer: float = 0.0
var _tip_alpha: float = 0.0
var _bar: Control
var _hint: PanelContainer

var _threat_radar
var _debug_label: Label

# 오버레이
var _esc_overlay: Control
var _result_overlay: Control
var _result_card: PanelContainer

func setup(root: Node, building_datas: Array) -> void:
	_building_datas = building_datas
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	root.add_child(_canvas)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_root)
	_slot_types = BuildingCatalog.buildable_types()
	_build_money()
	_build_top_center()
	_build_controls()
	_build_hq()
	_build_bar()
	_build_radar()
	_build_tooltip()
	_build_hint()
	_build_debug()
	# 타이틀에서 검게 넘어온 화면을 부드럽게 연다
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fade)
	var t := fade.create_tween()
	t.tween_property(fade, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(fade.queue_free)

# ---------------------------------------------------------------------------
# 갱신
# ---------------------------------------------------------------------------

func tick(delta: float, sim, debug_visible: bool, debug_text: String) -> void:
	if debug_visible and _debug_label:
		_debug_label.text = debug_text
	if _threat_radar:
		_threat_radar.tick(delta, sim, sim.waves.heavy_sides())
	_tick_money(delta)
	_tick_alert(delta)
	_tick_tooltip(delta)
	if _hint and _hint.visible:
		var t: float = sim.waves.time
		_hint.modulate.a = clampf(HINT_SECONDS - t, 0.0, 1.0)
		if t > HINT_SECONDS:
			_hint.visible = false

## 이번 틱에 얻은 크리스탈 (게임 씬이 틱마다 호출)
func report_gain(amount: int) -> void:
	if amount <= 0:
		return
	_gain_accum += amount
	_income_samples.append([_income_time, amount])

func update_hud(sim, paused: bool) -> void:
	_money_target = float(sim.minerals)
	if _money_shown < 0.0:
		_money_shown = _money_target
	_time_label.text = UiKit.clock(sim.waves.time)
	_kills_label.text = UiKit.thousands(sim.kills)
	_enemies_label.text = UiKit.thousands(sim.enemies_alive())
	_orb.set_hp(sim.hq_hp(), sim.hq_max_hp())
	# 위협: 압박 배율(예고 없이 두꺼워지는 정도)을 5칸으로. 보간해서 칸이 부드럽게 차오른다
	var heat := clampf((sim.waves.pressure - WaveSim.PRESSURE_MIN) / (WaveSim.PRESSURE_MAX - WaveSim.PRESSURE_MIN), 0.0, 1.0)
	_threat_shown = lerpf(_threat_shown, 1.0 + heat * float(THREAT_SEGMENTS - 1), 0.08)
	for i in THREAT_SEGMENTS:
		var bar: ColorRect = _threat_bars[i]
		var fill := clampf(_threat_shown - float(i), 0.0, 1.0)
		var on_col := UiKit.AMBER if i < 3 else UiKit.DANGER
		bar.color = Color(0.16, 0.18, 0.21).lerp(on_col, fill)
	# 조작 버튼 상태
	_btn_pause.active = paused
	for b in _btn_speeds:
		b.active = is_equal_approx(float(b.get_meta("speed")), GameFeel.game_speed)
	for i in _slots.size():
		_slots[i].set_state(i == _selected_slot, sim.can_afford(_slot_types[i]))

func _tick_money(delta: float) -> void:
	_income_time += delta
	while not _income_samples.is_empty() and _income_time - _income_samples[0][0] > INCOME_WINDOW:
		_income_samples.pop_front()
	var total := 0
	for s in _income_samples:
		total += s[1]
	_income_label.text = Locale.t_fmt("income_label", [int(round(float(total) / INCOME_WINDOW))])
	# 숫자는 굴러가듯 목표값을 따라간다
	if _money_shown >= 0.0:
		_money_shown = lerpf(_money_shown, _money_target, 1.0 - exp(-12.0 * delta))
		if absf(_money_shown - _money_target) < 0.5:
			_money_shown = _money_target
		_money_label.text = UiKit.thousands(int(round(_money_shown)))
	# 팝업 합산
	_gain_timer -= delta
	if _gain_timer <= 0.0:
		_gain_timer = GAIN_POPUP_INTERVAL
		if _gain_accum > 0:
			_spawn_gain_popup(_gain_accum)
			_money_pulse = 1.0
			_gain_accum = 0
	_money_pulse = maxf(_money_pulse - delta * 5.0, 0.0)
	var s := 1.0 + 0.12 * _money_pulse * _money_pulse
	_money_label.pivot_offset = Vector2(0.0, _money_label.size.y * 0.5)
	_money_label.scale = Vector2(s, s)
	var keep: Array = []
	for p in _popups:
		p[1] += delta
		var lbl: Label = p[0]
		var t: float = p[1] / 1.1
		if t >= 1.0:
			lbl.queue_free()
			continue
		var ease_t := 1.0 - (1.0 - t) * (1.0 - t)
		lbl.position.y = p[2] - 30.0 * ease_t
		lbl.modulate.a = minf(t * 8.0, 1.0) * (1.0 - t * t)
		keep.append(p)
	_popups = keep

func _spawn_gain_popup(amount: int) -> void:
	if _popups.size() >= MAX_GAIN_POPUPS:
		var old: Array = _popups.pop_front()
		(old[0] as Label).queue_free()
	var big := amount >= 40
	var lbl := UiKit.display(Locale.t_fmt("gain_popup", [amount]), 24 if big else 19, UiKit.OK.lightened(0.15) if big else UiKit.OK)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	# 패널 오른쪽 옆에서 떠오른다 (화면 위로 잘리지 않게)
	var x := _money_plate.position.x + _money_plate.size.x + 8.0 + float(_popups.size() % 2) * 12.0
	var y := _money_plate.position.y + 30.0 - float(_popups.size() % 3) * 9.0
	lbl.position = Vector2(x, y)
	_root.add_child(lbl)
	_popups.append([lbl, 0.0, y])

func show_hq_warning() -> void:
	_alert_timer = 1.4
	_orb.alarm()

func _tick_alert(delta: float) -> void:
	_alert_timer = maxf(_alert_timer - delta, 0.0)
	var target := 1.0 if _alert_timer > 0.0 else 0.0
	_alert.modulate.a = lerpf(_alert.modulate.a, target, 1.0 - exp(-10.0 * delta))
	_alert.visible = _alert.modulate.a > 0.02

func update_slot_highlight(selected_slot: int, _datas: Array = []) -> void:
	var changed := selected_slot != _selected_slot
	_selected_slot = selected_slot
	for i in _slots.size():
		_slots[i].set_state(i == _selected_slot, _slots[i].affordable)
	# 키보드로 고르면 설명을 잠깐 보여준다
	if changed:
		_tip_timer = 1.8

## 배속 변경 알림 (버튼 상태는 update_hud가 GameFeel에서 읽는다)
func set_speed_label(_speed: float) -> void:
	pass

func set_debug_visible(visible: bool) -> void:
	_debug_label.visible = visible

func is_game_over_visible() -> bool:
	return _result_overlay != null and _result_overlay.visible

func set_esc_visible(visible: bool) -> void:
	if visible:
		if _esc_overlay:
			_esc_overlay.queue_free()
		_esc_overlay = _build_esc_menu()
		_fade_in(_esc_overlay, _esc_overlay.get_meta("card"))
	elif _esc_overlay:
		_esc_overlay.queue_free()
		_esc_overlay = null

# ---------------------------------------------------------------------------
# 구성: 상단
# ---------------------------------------------------------------------------

func _build_money() -> void:
	_money_plate = PanelContainer.new()
	_money_plate.position = Vector2(16, 14)
	_money_plate.custom_minimum_size = Vector2(214, 0)
	_money_plate.add_theme_stylebox_override("panel", UiKit.plate(UiKit.PANEL, UiKit.LINE, 10, 1, Vector4(16, 8, 18, 10)))
	_root.add_child(_money_plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	_money_plate.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var gem = GemIcon.new(30.0)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gem)
	_money_label = UiKit.display("0", 42, UiKit.CRYSTAL)
	row.add_child(_money_label)
	_income_label = UiKit.label("", 13, UiKit.OK, UiKit.FONT_BOLD)
	v.add_child(_income_label)

func _build_top_center() -> void:
	var timer := ShapePlate.new(0.0, 36.0)
	timer.draw_top_edge = false
	timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer.offset_left = -150.0
	timer.offset_right = 150.0
	timer.offset_top = 0.0
	timer.offset_bottom = 92.0
	_root.add_child(timer)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 8.0
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer.add_child(v)
	v.add_child(UiKit.caption(Locale.t("survival"), 11, UiKit.TEXT_3, HORIZONTAL_ALIGNMENT_CENTER))
	_time_label = UiKit.display("00:00", 40, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_time_label)
	var threat := HBoxContainer.new()
	threat.alignment = BoxContainer.ALIGNMENT_CENTER
	threat.add_theme_constant_override("separation", 3)
	threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(threat)
	for i in THREAT_SEGMENTS:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(27, 5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		threat.add_child(r)
		_threat_bars.append(r)
	_kills_label = _chip(Locale.t("kills"), UiKit.TEXT, -164.0, true)
	_enemies_label = _chip(Locale.t("enemies"), Color(1.0, 0.56, 0.52), 164.0, false)

## 가운데 위 양옆 칩. left면 x에서 왼쪽으로 자란다
func _chip(caption_text: String, value_color: Color, x: float, left: bool) -> Label:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 14.0
	p.offset_left = x
	p.offset_right = x
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if left else Control.GROW_DIRECTION_END
	p.add_theme_stylebox_override("panel", UiKit.plate(UiKit.PANEL, UiKit.LINE, 8, 1, Vector4(14, 4, 14, 4)))
	_root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var cap := UiKit.label(caption_text, 14, UiKit.TEXT_2, UiKit.FONT_SEMIBOLD)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cap)
	var val := UiKit.display("0", 22, value_color)
	val.custom_minimum_size = Vector2(52, 0)
	h.add_child(val)
	return val

func set_auto_play(enabled: bool) -> void:
	_btn_auto.active = enabled
	_btn_auto.text = Locale.t("auto_play_on" if enabled else "auto_play_off")

func _build_controls() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_right = -16.0
	p.offset_left = -16.0
	p.offset_top = 14.0
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.add_theme_stylebox_override("panel", UiKit.plate(UiKit.PANEL, UiKit.LINE, 8, 1, Vector4(0, 0, 0, 0)))
	_root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	p.add_child(h)
	_btn_auto = CtrlButton.new("", Locale.t("auto_play_off"))
	_btn_auto.custom_minimum_size.x = 110
	_btn_auto.tooltip_text = Locale.t("ctl_auto_play") + " (B)"
	_btn_auto.pressed.connect(auto_play_pressed.emit)
	h.add_child(_btn_auto)
	_btn_pause = CtrlButton.new("pause", "")
	_btn_pause.pressed.connect(pause_pressed.emit)
	h.add_child(_btn_pause)
	for spd in [1.0, 2.0, 3.0]:
		var b := CtrlButton.new("", "%d×" % int(spd))
		b.set_meta("speed", spd)
		b.pressed.connect(speed_pressed.emit.bind(spd))
		h.add_child(b)
		_btn_speeds.append(b)
	_btn_menu = CtrlButton.new("menu", "")
	_btn_menu.pressed.connect(menu_pressed.emit)
	h.add_child(_btn_menu)

# ---------------------------------------------------------------------------
# 구성: 하단
# ---------------------------------------------------------------------------

func _build_hq() -> void:
	_orb = HqOrb.new()
	_orb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_orb.offset_left = 16.0
	_orb.offset_right = 166.0
	_orb.offset_top = -164.0
	_orb.offset_bottom = -14.0
	_root.add_child(_orb)
	_alert = PanelContainer.new()
	_alert.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_alert.offset_left = 18.0
	_alert.offset_top = -204.0
	_alert.offset_bottom = -174.0
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert.add_theme_stylebox_override("panel", UiKit.plate(Color(0.42, 0.05, 0.04, 0.9), UiKit.DANGER, 4, 1, Vector4(12, 5, 12, 5)))
	_alert.modulate.a = 0.0
	_alert.visible = false
	_root.add_child(_alert)
	_alert.add_child(UiKit.label("⚠  " + Locale.t("hq_under_attack"), 13, Color(1, 0.86, 0.83), UiKit.FONT_BOLD))

func _build_bar() -> void:
	_bar = ShapePlate.new(22.0, 0.0)
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_left = 186.0
	_bar.offset_right = -186.0
	_bar.offset_top = -124.0
	_bar.offset_bottom = -12.0
	_root.add_child(_bar)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_top = 10.0
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(h)
	for i in _slot_types.size():
		var bd := _building_datas[_slot_types[i]] as BuildingData
		var icon := SpriteFactory.load_sprite("buildings", SpriteFactory.building_sprite_key(bd.building_name))
		var slot = BuildSlot.new(i + 1, icon, bd.cost)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.pressed.connect(slot_pressed.emit.bind(i))
		slot.mouse_entered.connect(func() -> void: _tip_hover_slot = i)
		slot.mouse_exited.connect(func() -> void:
			if _tip_hover_slot == i:
				_tip_hover_slot = -1)
		h.add_child(slot)
		_slots.append(slot)

func _build_radar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -168.0
	p.offset_right = -18.0
	p.offset_top = -164.0
	p.offset_bottom = -14.0
	p.add_theme_stylebox_override("panel", UiKit.plate(UiKit.PANEL, UiKit.LINE, 10, 1, Vector4(8, 8, 8, 8)))
	_root.add_child(p)
	var inner := Control.new()
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	_threat_radar = ThreatRadar.new(inner)
	var cap := UiKit.caption(Locale.t("threat"), 11, UiKit.TEXT_3)
	cap.position = Vector2(4, 2)
	inner.add_child(cap)

func _build_tooltip() -> void:
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.custom_minimum_size = Vector2(270, 0)
	_tip.add_theme_stylebox_override("panel", UiKit.plate(Color(0.07, 0.085, 0.11, 0.97), UiKit.LINE_HI, 8, 1, Vector4(14, 10, 14, 12)))
	_tip.visible = false
	_root.add_child(_tip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_tip_name = UiKit.display("", 21, UiKit.AMBER_HI)
	_tip_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tip_name)
	var gem = GemIcon.new(15.0)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gem)
	_tip_cost = UiKit.display("", 18, UiKit.CRYSTAL_HI)
	head.add_child(_tip_cost)
	_tip_desc = UiKit.label("", 13, UiKit.TEXT_2, UiKit.FONT_REGULAR)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(242, 0)
	v.add_child(_tip_desc)
	_tip_stats = HBoxContainer.new()
	_tip_stats.add_theme_constant_override("separation", 6)
	_tip_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tip_stats)

func _fill_tooltip(slot: int) -> void:
	var bd := _building_datas[_slot_types[slot]] as BuildingData
	_tip_name.text = Locale.t(bd.building_name)
	_tip_cost.text = str(bd.cost)
	_tip_desc.text = Locale.t("desc_" + bd.building_name)
	for c in _tip_stats.get_children():
		c.queue_free()
	var stats: Array = []
	if bd.is_tower():
		stats.append([str(int(round(bd.damage))), Locale.t("stat_damage")])
		stats.append([Locale.t_fmt("stat_range_fmt", [int(round(bd.attack_range))]), Locale.t("stat_range")])
		var rate := "rate_slow"
		if bd.attack_rate >= 4.0:
			rate = "rate_very_fast"
		elif bd.attack_rate >= 2.0:
			rate = "rate_fast"
		elif bd.attack_rate >= 0.9:
			rate = "rate_normal"
		stats.append([Locale.t(rate), Locale.t("stat_rate")])
	else:
		stats.append([UiKit.thousands(int(bd.max_hp)), Locale.t("stat_hp")])
	for s in stats:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.35)
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		box.add_theme_stylebox_override("panel", sb)
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", -2)
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sv)
		sv.add_child(UiKit.display(s[0], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		sv.add_child(UiKit.label(s[1], 10, UiKit.TEXT_3, UiKit.FONT_SEMIBOLD, HORIZONTAL_ALIGNMENT_CENTER))
		_tip_stats.add_child(box)

func _tick_tooltip(delta: float) -> void:
	_tip_timer = maxf(_tip_timer - delta, 0.0)
	var want := _tip_hover_slot
	if want < 0 and _tip_timer > 0.0:
		want = _selected_slot
	if want >= 0 and want != _tip_slot:
		_tip_slot = want
		_fill_tooltip(want)
		_tip.reset_size()
	var target := 1.0 if want >= 0 else 0.0
	_tip_alpha = lerpf(_tip_alpha, target, 1.0 - exp(-18.0 * delta))
	_tip.visible = _tip_alpha > 0.02
	_tip.modulate.a = _tip_alpha
	if _tip.visible and _tip_slot >= 0:
		var slot: Control = _slots[_tip_slot]
		var vp := _root.size
		var x := slot.global_position.x + slot.size.x * 0.5 - _tip.size.x * 0.5
		x = clampf(x, 12.0, vp.x - _tip.size.x - 12.0)
		var y := _bar.global_position.y - _tip.size.y - 12.0 + 6.0 * (1.0 - _tip_alpha)
		_tip.position = Vector2(x, y)

func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_right = -186.0
	_hint.offset_left = -186.0
	_hint.offset_bottom = -134.0
	_hint.offset_top = -134.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_stylebox_override("panel", UiKit.plate(UiKit.PANEL, UiKit.LINE, 8, 1, Vector4(12, 6, 14, 6)))
	_root.add_child(_hint)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(h)
	h.add_child(_keycap("1"))
	h.add_child(UiKit.label("~", 13, UiKit.TEXT_2))
	h.add_child(_keycap("8"))
	h.add_child(UiKit.label(Locale.t("hint_build") + "   ·", 13, UiKit.TEXT))
	h.add_child(_keycap(Locale.t("key_lmb")))
	h.add_child(UiKit.label(Locale.t("hint_place") + "   ·", 13, UiKit.TEXT))
	h.add_child(_keycap(Locale.t("key_rmb")))
	h.add_child(UiKit.label(Locale.t("hint_demolish"), 13, UiKit.TEXT))

static func _keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.15)
	sb.border_color = UiKit.LINE_HI
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UiKit.label(text, 11, UiKit.TEXT, UiKit.FONT_BOLD, HORIZONTAL_ALIGNMENT_CENTER))
	return p

func _build_debug() -> void:
	_debug_label = UiKit.label("", 12, Color(0.55, 1.0, 0.6), UiKit.FONT_SEMIBOLD)
	_debug_label.visible = false
	_debug_label.position = Vector2(18, 110)
	_debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_debug_label.add_theme_constant_override("outline_size", 4)
	_root.add_child(_debug_label)

# ---------------------------------------------------------------------------
# 오버레이: 일시정지 메뉴 · 결과 화면
# ---------------------------------------------------------------------------

## 화면을 어둡게 덮는 오버레이 + 가운데 카드. 반환한 오버레이의 meta "card"가 카드다
func _overlay(card_width: float, dim: float) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(o)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.012, 0.018, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_width, 0)
	card.add_theme_stylebox_override("panel", UiKit.plate(Color(0.075, 0.09, 0.115, 0.98), UiKit.LINE_HI, 12, 1, Vector4(0, 0, 0, 0)))
	center.add_child(card)
	o.set_meta("card", card)
	return o

func _fade_in(overlay: Control, card: Control) -> void:
	overlay.modulate.a = 0.0
	card.scale = Vector2(0.95, 0.95)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var t := overlay.create_tween().set_parallel(true)
	t.tween_property(overlay, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_esc_menu() -> Control:
	var o := _overlay(360.0, 0.55)
	var card: PanelContainer = o.get_meta("card")
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 32)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 28)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	v.add_child(UiKit.display(Locale.t("paused"), 32, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_spacer(6))
	for entry in [["resume", resume_requested, true], ["restart", restart_requested, false], ["title_screen", title_requested, false]]:
		var b := UiKit.button(Locale.t(entry[0]), Vector2(0, 50 if entry[2] else 46), 18 if entry[2] else 16, entry[2])
		var sig: Signal = entry[1]
		b.pressed.connect(sig.emit)
		v.add_child(b)
	v.add_child(_spacer(8))
	var names := ["vol_master", "vol_music", "vol_sfx"]
	var values := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiKit.label(Locale.t(names[i]), 13, UiKit.TEXT_2, UiKit.FONT_SEMIBOLD)
		l.custom_minimum_size = Vector2(56, 0)
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
	return o

static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## data: ResultText.build()의 반환값
func show_game_over(data: Dictionary) -> void:
	_tip_hover_slot = -1
	if _result_overlay:
		_result_overlay.queue_free()
	var o := _overlay(660.0, 0.62)
	_result_overlay = o
	var card: PanelContainer = o.get_meta("card")
	_result_card = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)

	# 붉은 띠
	var ribbon := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.55, 0.07, 0.05)
	rs.corner_radius_top_left = 12
	rs.corner_radius_top_right = 12
	rs.corner_detail = 1
	rs.content_margin_top = 10
	rs.content_margin_bottom = 10
	ribbon.add_theme_stylebox_override("panel", rs)
	v.add_child(ribbon)
	ribbon.add_child(UiKit.display(Locale.t("hq_fallen"), 24, Color(1, 0.9, 0.87), HORIZONTAL_ALIGNMENT_CENTER))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 30)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 26)
	v.add_child(m)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	m.add_child(body)

	# 생존 시간 (0에서 굴러 올라간다) + 새 기록 딱지
	body.add_child(UiKit.caption(Locale.t("survival"), 12, UiKit.TEXT_3, HORIZONTAL_ALIGNMENT_CENTER))
	var big_row := HBoxContainer.new()
	big_row.alignment = BoxContainer.ALIGNMENT_CENTER
	big_row.add_theme_constant_override("separation", 12)
	body.add_child(big_row)
	var time_label := UiKit.display("00:00", 78, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	time_label.add_theme_constant_override("shadow_offset_y", 4)
	big_row.add_child(time_label)
	var badge: PanelContainer = null
	if data["new_time"]:
		badge = PanelContainer.new()
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", UiKit.plate(UiKit.AMBER, UiKit.AMBER_HI, 3, 1, Vector4(10, 4, 10, 4)))
		badge.add_child(UiKit.label(Locale.t("new_best"), 14, UiKit.AMBER_DARK, UiKit.FONT_BOLD))
		badge.rotation = deg_to_rad(-5.0)
		badge.scale = Vector2.ZERO
		big_row.add_child(badge)

	# 기록 칸 3개
	body.add_child(_spacer(20))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	body.add_child(tiles)
	tiles.add_child(_result_tile(Locale.t("kills"), UiKit.thousands(int(data["kills"])),
		Locale.t("new_best") if data["new_kills"] else Locale.t_fmt("best_fmt", [UiKit.thousands(int(data["best_kills"]))]), data["new_kills"]))
	tiles.add_child(_result_tile(Locale.t("peak"), UiKit.thousands(int(data["peak"])),
		Locale.t("new_best") if data["new_peak"] else Locale.t_fmt("best_fmt", [UiKit.thousands(int(data["best_peak"]))]), data["new_peak"]))
	tiles.add_child(_result_tile(Locale.t("built"), UiKit.thousands(int(data["built"])),
		Locale.t_fmt("lost_fmt", [int(data["lost"])]), false))
	if not data["new_time"] and float(data["best_time"]) > 0.0:
		body.add_child(_spacer(8))
		body.add_child(UiKit.label(Locale.t_fmt("best_fmt", [UiKit.clock(float(data["best_time"]))]) + " · " + Locale.t("survival"),
			12, UiKit.TEXT_3, UiKit.FONT_SEMIBOLD, HORIZONTAL_ALIGNMENT_CENTER))

	# 조언
	body.add_child(_spacer(18))
	var line := ColorRect.new()
	line.color = Color(0.17, 0.2, 0.24)
	line.custom_minimum_size = Vector2(0, 1)
	body.add_child(line)
	body.add_child(_spacer(14))
	body.add_child(UiKit.caption(Locale.t("advice_title"), 12, UiKit.AMBER))
	body.add_child(_spacer(6))
	for a in data["advice"]:
		body.add_child(_advice_row(a))

	# 버튼
	body.add_child(_spacer(22))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	body.add_child(buttons)
	var retry := _key_button(Locale.t("retry"), "R", true)
	retry.pressed.connect(restart_requested.emit)
	buttons.add_child(retry)
	var title := _key_button(Locale.t("to_title"), "Esc", false)
	title.pressed.connect(title_requested.emit)
	buttons.add_child(title)

	_fade_in(o, card)
	var t := o.create_tween()
	t.tween_interval(0.2)
	var secs := float(data["time"])
	t.tween_method(func(x: float) -> void: time_label.text = UiKit.clock(x), 0.0, secs, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if badge:
		badge.resized.connect(func() -> void: badge.pivot_offset = badge.size * 0.5)
		t.tween_property(badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void: AudioManager.play_sfx_by_name("build", -2.0, 1.4))

func _result_tile(caption_text: String, value: String, sub: String, highlight: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiKit.plate(Color(0, 0, 0, 0.3), Color(0.17, 0.2, 0.24), 6, 1, Vector4(14, 10, 14, 10)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(UiKit.caption(caption_text, 11, UiKit.TEXT_3))
	v.add_child(UiKit.display(value, 28, UiKit.TEXT))
	v.add_child(UiKit.label(sub, 12, UiKit.AMBER if highlight else UiKit.TEXT_3, UiKit.FONT_SEMIBOLD))
	return p

func _advice_row(a: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	match a["kind"]:
		"danger": sb.bg_color = Color(1.0, 0.3, 0.24, 0.18)
		"crystal": sb.bg_color = Color(0.37, 0.89, 1.0, 0.14)
		_: sb.bg_color = Color(0.96, 0.72, 0.24, 0.16)
	icon.add_theme_stylebox_override("panel", sb)
	if a["kind"] == "crystal":
		var c := CenterContainer.new()
		c.add_child(GemIcon.new(14.0))
		icon.add_child(c)
	else:
		icon.add_child(UiKit.label("!" if a["kind"] == "danger" else "✓", 14,
			UiKit.DANGER if a["kind"] == "danger" else UiKit.AMBER, UiKit.FONT_BOLD, HORIZONTAL_ALIGNMENT_CENTER))
	h.add_child(icon)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", UiKit.FONT_REGULAR)
	text.add_theme_font_override("bold_font", UiKit.FONT_BOLD)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_font_size_override("bold_font_size", 15)
	text.add_theme_color_override("default_color", UiKit.TEXT_2)
	text.text = "[color=#%s][b]%s[/b][/color]  %s" % [UiKit.TEXT.to_html(false), a["bold"], a["rest"]]
	h.add_child(text)
	return h

## 오른쪽에 흐린 단축키 표시가 붙은 버튼
func _key_button(text: String, key: String, primary: bool) -> Button:
	var b := UiKit.button(text, Vector2(210, 54 if primary else 54), 19 if primary else 17, primary)
	var k := UiKit.label(key, 12, UiKit.AMBER_DARK if primary else UiKit.TEXT_3, UiKit.FONT_BOLD)
	k.modulate.a = 0.6
	k.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	k.offset_left = -38.0
	k.offset_right = -14.0
	k.offset_top = -9.0
	k.offset_bottom = 9.0
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(k)
	return b
