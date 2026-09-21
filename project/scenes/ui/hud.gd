extends RefCounted

## HUD. 우선순위: 자원(가장 크고 먼저 읽힘) → 본진 위험 → 급증/스트림 경고 → 슬롯 → 레이더.
## 어두운 디아블로풍 패널 스타일. 전체 화면 플래시는 쓰지 않는다.
## 자원은 얻을 때 커졌다 돌아오고, 틱 단위로 합산한 "+$N" 팝업이 뜬다. 슬롯은 살 수 있으면 밝고 못 사면 어둡다.

const ThreatRadar := preload("res://scripts/threat_radar.gd")
const BuildingCatalog := preload("res://scripts/building_catalog.gd")

signal slot_pressed(slot_index: int)
signal resume_requested()
signal restart_requested()
signal title_requested()

const INCOME_WINDOW := 2.0        # 초당 수입 표시 창
const GAIN_POPUP_INTERVAL := 0.35 # 획득 팝업 합산 간격
const MAX_GAIN_POPUPS := 6

var _canvas: CanvasLayer
var _mineral_label: Label
var _income_label: Label
var _mineral_panel: PanelContainer
var _popup_root: Control
var _popups: Array = []           # [Label, age]
var _gain_accum: int = 0
var _gain_timer: float = 0.0
var _income_samples: Array = []   # [time, amount]
var _income_time: float = 0.0
var _mineral_pulse: float = 0.0
var _last_minerals: int = -1

var _info_label: Label
var _surge_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _hq_warn_label: Label
var _selected_name: Label
var _selected_desc: Label
var _game_over_panel: PanelContainer
var _result_label: Label
var _slot_buttons: Array = []
var _slot_cost_labels: Array = []
var _slot_name_labels: Array = []
var _slot_types: Array = []
var _slot_affordable: Array = []
var _selected_slot: int = 0
var _threat_radar
var _banner_label: Label
var _banner_timer: float = 0.0
var _speed_label: Label
var _esc_panel: PanelContainer
var _debug_label: Label
var _hq_warn_timer: float = 0.0
var _building_datas: Array = []

func setup(root: Node, building_datas: Array) -> void:
	_building_datas = building_datas
	_canvas = CanvasLayer.new()
	root.add_child(_canvas)
	_slot_types = BuildingCatalog.buildable_types()
	for i in _slot_types.size():
		_slot_affordable.append(true)
	_setup_hud(building_datas)
	_setup_banner()
	_setup_game_over_panel()
	_setup_speed_label()
	_setup_esc_menu()
	_setup_debug_overlay()

func get_canvas() -> CanvasLayer:
	return _canvas

# ---------------------------------------------------------------------------
# 갱신
# ---------------------------------------------------------------------------

func tick(delta: float, sim, debug_visible: bool, debug_text: String) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_label:
			_banner_label.visible = false
	if _hq_warn_timer > 0.0:
		_hq_warn_timer -= delta
		if _hq_warn_timer <= 0.0 and _hq_warn_label:
			_hq_warn_label.visible = false
	if debug_visible and _debug_label:
		_debug_label.text = debug_text
	if _threat_radar:
		_threat_radar.tick(delta, sim, sim.waves.spawn_sides if sim.waves.active else 0)
	_tick_money(delta)

## 이번 틱에 얻은 미네랄 (게임 씬이 틱마다 호출)
func report_gain(amount: int) -> void:
	if amount <= 0:
		return
	_gain_accum += amount
	_income_samples.append([_income_time, amount])

func _tick_money(delta: float) -> void:
	_income_time += delta
	# 수입 창 정리
	while not _income_samples.is_empty() and _income_time - _income_samples[0][0] > INCOME_WINDOW:
		_income_samples.pop_front()
	var total := 0
	for s in _income_samples:
		total += s[1]
	if _income_label:
		_income_label.text = Locale.t_fmt("income_label", [int(round(float(total) / INCOME_WINDOW))])
	# 팝업 합산
	_gain_timer -= delta
	if _gain_timer <= 0.0:
		_gain_timer = GAIN_POPUP_INTERVAL
		if _gain_accum > 0:
			_spawn_gain_popup(_gain_accum)
			_mineral_pulse = 1.0
			_gain_accum = 0
	# 숫자 펀치
	if _mineral_pulse > 0.0:
		_mineral_pulse = maxf(_mineral_pulse - delta * 4.0, 0.0)
		if _mineral_label:
			var s := 1.0 + 0.18 * _mineral_pulse
			_mineral_label.scale = Vector2(s, s)
	# 팝업 이동·소멸
	var keep: Array = []
	for p in _popups:
		p[1] += delta
		var lbl: Label = p[0]
		var t: float = p[1] / 1.1
		if t >= 1.0:
			lbl.queue_free()
			continue
		lbl.position.y = p[2] - 34.0 * t
		lbl.modulate.a = 1.0 - t * t
		keep.append(p)
	_popups = keep

func _spawn_gain_popup(amount: int) -> void:
	if not _popup_root:
		return
	if _popups.size() >= MAX_GAIN_POPUPS:
		var old: Array = _popups.pop_front()
		(old[0] as Label).queue_free()
	var lbl := Label.new()
	lbl.text = Locale.t_fmt("gain_popup", [amount])
	var big := amount >= 40
	lbl.add_theme_font_size_override("font_size", 22 if big else 16)
	lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if big else Color(0.45, 0.95, 0.6))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 150.0 + float(_popups.size() % 3) * 14.0
	var y := 26.0
	lbl.position = Vector2(x, y)
	_popup_root.add_child(lbl)
	_popups.append([lbl, 0.0, y])

func update_hud(sim, paused: bool) -> void:
	if _mineral_label and sim.minerals != _last_minerals:
		_last_minerals = sim.minerals
		_mineral_label.text = "$%s" % _format_number(sim.minerals)
	if _info_label:
		var secs := int(sim.waves.time)
		var text := Locale.t_fmt("time_survived", [secs / 60, secs % 60])
		text += "  |  " + Locale.t_fmt("wave_label", [sim.waves.wave_number])
		text += "  |  " + Locale.t_fmt("kills_label", [sim.kills])
		text += "  |  " + Locale.t_fmt("enemies_label", [sim.enemies_alive()])
		if paused:
			text += "  ||"
		_info_label.text = text
	if _surge_label:
		var left := int(ceil(sim.waves.seconds_to_surge()))
		_surge_label.text = Locale.t_fmt("next_wave", [left])
		var urgent := left <= 5
		_surge_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3) if urgent else Color(0.75, 0.65, 0.4))
	if _hp_label:
		var hp := int(sim.hq_hp())
		var max_hp := int(sim.hq_max_hp())
		_hp_label.text = "%d / %d" % [hp, max_hp]
		var ratio := float(hp) / maxf(float(max_hp), 1.0)
		var col := Color(0.5, 0.75, 1.0)
		if ratio < 0.3:
			col = Color(1.0, 0.25, 0.2)
		elif ratio < 0.6:
			col = Color(1.0, 0.75, 0.3)
		_hp_label.add_theme_color_override("font_color", col)
		if _hp_bar:
			_hp_bar.value = ratio * 100.0
			var fill := _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill:
				fill.bg_color = col.darkened(0.2)
	_update_affordability(sim)

func _update_affordability(sim) -> void:
	for i in _slot_buttons.size():
		var type: int = _slot_types[i]
		var ok: bool = sim.can_afford(type)
		if ok == _slot_affordable[i]:
			continue
		_slot_affordable[i] = ok
		_apply_slot_style(i)

func _apply_slot_style(i: int) -> void:
	var btn: Button = _slot_buttons[i]
	var ok: bool = _slot_affordable[i]
	var selected := i == _selected_slot
	var style: StyleBoxFlat
	if selected:
		style = _create_panel_style(Color(0.2, 0.16, 0.06, 0.97), Color(1.0, 0.85, 0.25), 3)
	elif ok:
		style = _create_panel_style(Color(0.13, 0.11, 0.07, 0.9), Color(0.55, 0.45, 0.2, 0.8), 2)
	else:
		style = _create_panel_style(Color(0.07, 0.06, 0.06, 0.75), Color(0.25, 0.2, 0.15, 0.4), 1)
	_round(style, 6)
	btn.add_theme_stylebox_override("normal", style)
	var cost_lbl: Label = _slot_cost_labels[i]
	cost_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55) if ok else Color(0.95, 0.35, 0.3))
	var name_lbl: Label = _slot_name_labels[i]
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55) if ok else Color(0.5, 0.45, 0.35))
	btn.modulate = Color(1, 1, 1, 1.0) if ok else Color(1, 1, 1, 0.8)

func show_hq_warning() -> void:
	if _hq_warn_label:
		_hq_warn_label.visible = true
	_hq_warn_timer = 1.2

func show_wave_banner(wave_number: int, wave_type: int, sides: int, count: int) -> void:
	if not _banner_label:
		return
	var type_key := "wave_scout"
	match wave_type:
		1: type_key = "wave_density"
		2: type_key = "wave_breach"
		3: type_key = "wave_storm"
	_banner_label.text = "%s  —  %s\n%s" % [
		Locale.t_fmt("wave_label", [wave_number]), Locale.t(type_key),
		Locale.t_fmt("from_side", [_side_text(sides), count])
	]
	var col := Color(1.0, 0.9, 0.4)
	if wave_type == 3:
		col = Color(1.0, 0.4, 0.3)
	elif wave_type == 2:
		col = Color(1.0, 0.65, 0.3)
	_banner_label.add_theme_color_override("font_color", col)
	_banner_label.visible = true
	_banner_timer = 3.0

func _side_text(sides: int) -> String:
	if sides == 0xF:
		return Locale.t("side_all")
	var names: Array = []
	if sides & 1:
		names.append(Locale.t("side_north"))
	if sides & 2:
		names.append(Locale.t("side_east"))
	if sides & 4:
		names.append(Locale.t("side_south"))
	if sides & 8:
		names.append(Locale.t("side_west"))
	return "/".join(names)

func update_slot_highlight(selected_slot: int, building_datas: Array) -> void:
	_selected_slot = selected_slot
	for i in _slot_buttons.size():
		_apply_slot_style(i)
	var type: int = _slot_types[selected_slot]
	var bd := building_datas[type] as BuildingData
	if _selected_name:
		_selected_name.text = "%s  $%d" % [Locale.t(bd.building_name), bd.cost]
	if _selected_desc:
		_selected_desc.text = Locale.t("desc_" + bd.building_name)

func set_speed_label(speed: float) -> void:
	if not _speed_label:
		return
	_speed_label.text = "%dx" % [int(speed)]
	_speed_label.visible = speed > 1.0

func set_debug_visible(visible: bool) -> void:
	if _debug_label:
		_debug_label.visible = visible

func show_game_over(result_text: String) -> void:
	if _game_over_panel:
		_game_over_panel.visible = true
	if _result_label:
		_result_label.text = result_text

func set_esc_visible(visible: bool) -> void:
	if _esc_panel:
		_esc_panel.visible = visible

static func _format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

# ---------------------------------------------------------------------------
# 구성
# ---------------------------------------------------------------------------

func _setup_hud(building_datas: Array) -> void:
	# 자원 패널 (좌상단, 가장 크게)
	_mineral_panel = PanelContainer.new()
	_mineral_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mineral_panel.offset_left = 8.0
	_mineral_panel.offset_top = 8.0
	_mineral_panel.custom_minimum_size = Vector2(190, 0)
	_mineral_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.05, 0.06, 0.08, 0.92), Color(0.25, 0.6, 0.6, 0.6), 2))
	_canvas.add_child(_mineral_panel)
	var money_vbox := VBoxContainer.new()
	money_vbox.add_theme_constant_override("separation", 0)
	_mineral_panel.add_child(money_vbox)
	_mineral_label = Label.new()
	_mineral_label.text = "$0"
	_mineral_label.add_theme_font_size_override("font_size", 36)
	_mineral_label.add_theme_color_override("font_color", Color(0.45, 1.0, 1.0))
	_mineral_label.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.15, 0.9))
	_mineral_label.add_theme_constant_override("outline_size", 3)
	_mineral_label.pivot_offset = Vector2(20.0, 22.0)
	money_vbox.add_child(_mineral_label)
	_income_label = Label.new()
	_income_label.text = ""
	_income_label.add_theme_font_size_override("font_size", 13)
	_income_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))
	money_vbox.add_child(_income_label)
	_popup_root = Control.new()
	_popup_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_popup_root)

	# 우상단: 시간·급증·처치·적 + 다음 급증
	var tr_panel := PanelContainer.new()
	tr_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_panel.offset_left = -340.0
	tr_panel.offset_top = 8.0
	tr_panel.offset_right = -8.0
	tr_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.06, 0.06, 0.08, 0.85), Color(0.3, 0.25, 0.15, 0.4), 1))
	_canvas.add_child(tr_panel)
	var tr_vbox := VBoxContainer.new()
	tr_vbox.add_theme_constant_override("separation", 2)
	tr_panel.add_child(tr_vbox)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	tr_vbox.add_child(_info_label)
	_surge_label = Label.new()
	_surge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_surge_label.add_theme_font_size_override("font_size", 15)
	_surge_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	tr_vbox.add_child(_surge_label)

	# 본진 경고 (화면 상단 중앙)
	_hq_warn_label = Label.new()
	_hq_warn_label.visible = false
	_hq_warn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hq_warn_label.offset_top = 14.0
	_hq_warn_label.offset_left = -200.0
	_hq_warn_label.offset_right = 200.0
	_hq_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hq_warn_label.text = Locale.t("hq_under_attack")
	_hq_warn_label.add_theme_font_size_override("font_size", 20)
	_hq_warn_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_hq_warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hq_warn_label.add_theme_constant_override("outline_size", 4)
	_canvas.add_child(_hq_warn_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.custom_minimum_size = Vector2(0, 150)
	bottom.offset_top = -150.0
	bottom.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.08, 0.07, 0.06, 0.97), Color(0.35, 0.28, 0.15, 0.6), 2))
	_canvas.add_child(bottom)

	var grid := HBoxContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("separation", 0)
	bottom.add_child(grid)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(200, 0)
	portrait.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.05, 0.04, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	grid.add_child(portrait)
	var port_vbox := VBoxContainer.new()
	port_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	port_vbox.add_theme_constant_override("separation", 2)
	portrait.add_child(port_vbox)
	var hp_sub := Label.new()
	hp_sub.text = Locale.t("hq_hp")
	hp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_sub.add_theme_font_size_override("font_size", 10)
	hp_sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	port_vbox.add_child(hp_sub)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	port_vbox.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(150, 8)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.04, 0.05)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.6, 0.85)
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_center := CenterContainer.new()
	bar_center.add_child(_hp_bar)
	port_vbox.add_child(bar_center)
	var sel_title := Label.new()
	sel_title.text = Locale.t("selected")
	sel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_title.add_theme_font_size_override("font_size", 9)
	sel_title.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	port_vbox.add_child(sel_title)
	_selected_name = Label.new()
	_selected_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_name.add_theme_font_size_override("font_size", 13)
	_selected_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	port_vbox.add_child(_selected_name)
	_selected_desc = Label.new()
	_selected_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_desc.add_theme_font_size_override("font_size", 10)
	_selected_desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	port_vbox.add_child(_selected_desc)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 4)
	grid.add_child(center)

	var build_hbox := HBoxContainer.new()
	build_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	build_hbox.add_theme_constant_override("separation", 4)
	center.add_child(build_hbox)

	for i in _slot_types.size():
		var type: int = _slot_types[i]
		var bd := building_datas[type] as BuildingData
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(88, 76)
		btn.focus_mode = Control.FOCUS_NONE
		var hs := _create_panel_style(Color(0.18, 0.15, 0.08, 0.9), Color(0.9, 0.75, 0.25), 2)
		_round(hs, 6)
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_stylebox_override("pressed", hs)
		btn.pressed.connect(slot_pressed.emit.bind(i))
		build_hbox.add_child(btn)
		# 버튼 위에 겹치는 라벨 (클릭은 버튼이 받는다)
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 1)
		btn.add_child(vbox)
		var key_lbl := Label.new()
		key_lbl.text = str(i + 1)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4))
		vbox.add_child(key_lbl)
		var swatch := ColorRect.new()
		swatch.color = bd.color
		swatch.custom_minimum_size = Vector2(0, 5)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch_margin := MarginContainer.new()
		swatch_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_margin.add_theme_constant_override("margin_left", 22)
		swatch_margin.add_theme_constant_override("margin_right", 22)
		swatch_margin.add_child(swatch)
		vbox.add_child(swatch_margin)
		var name_lbl := Label.new()
		name_lbl.text = Locale.t(bd.building_name)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(name_lbl)
		var cost_lbl := Label.new()
		cost_lbl.text = "$%d" % bd.cost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(cost_lbl)
		_slot_buttons.append(btn)
		_slot_name_labels.append(name_lbl)
		_slot_cost_labels.append(cost_lbl)
		_apply_slot_style(i)

	_threat_radar = ThreatRadar.new(grid, Locale.t("threat_radar"))

func _setup_banner() -> void:
	_banner_label = Label.new()
	_banner_label.visible = false
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.offset_top = 80.0
	_banner_label.offset_left = -320.0
	_banner_label.offset_right = 320.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 24)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_label.add_theme_constant_override("outline_size", 5)
	_canvas.add_child(_banner_label)

func _setup_game_over_panel() -> void:
	_game_over_panel = PanelContainer.new()
	_game_over_panel.visible = false
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(460, 320)
	_game_over_panel.offset_left = -230.0
	_game_over_panel.offset_top = -160.0
	_game_over_panel.offset_right = 230.0
	_game_over_panel.offset_bottom = 160.0
	_game_over_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.6, 0.5, 0.2), 3))
	_canvas.add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_game_over_panel.add_child(vbox)

	var go_title := Label.new()
	go_title.text = Locale.t("game_over")
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.add_theme_font_size_override("font_size", 40)
	go_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vbox.add_child(go_title)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 17)
	_result_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	vbox.add_child(_result_label)

	var restart_btn := _make_button(Locale.t("restart"), Vector2(150, 46), 17)
	restart_btn.pressed.connect(restart_requested.emit)
	var rb_center := CenterContainer.new()
	rb_center.add_child(restart_btn)
	vbox.add_child(rb_center)

func _setup_speed_label() -> void:
	_speed_label = Label.new()
	_speed_label.visible = false
	_speed_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_speed_label.offset_left = -60.0
	_speed_label.offset_top = 64.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.add_theme_font_size_override("font_size", 22)
	_speed_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	_canvas.add_child(_speed_label)

func _setup_esc_menu() -> void:
	_esc_panel = PanelContainer.new()
	_esc_panel.visible = false
	_esc_panel.set_anchors_preset(Control.PRESET_CENTER)
	_esc_panel.custom_minimum_size = Vector2(320, 380)
	_esc_panel.offset_left = -160.0
	_esc_panel.offset_top = -190.0
	_esc_panel.offset_right = 160.0
	_esc_panel.offset_bottom = 190.0
	_esc_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.6, 0.5, 0.2), 3))
	_canvas.add_child(_esc_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_esc_panel.add_child(vbox)

	var title := Label.new()
	title.text = Locale.t("paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	vbox.add_child(title)

	for entry in [["resume", resume_requested], ["restart", restart_requested], ["title_screen", title_requested]]:
		var btn := _make_button(Locale.t(entry[0]), Vector2(200, 40), 16)
		var sig: Signal = entry[1]
		btn.pressed.connect(sig.emit)
		var c := CenterContainer.new()
		c.add_child(btn)
		vbox.add_child(c)

	var vol_label_color := Color(0.75, 0.68, 0.4)
	var slider_names := [Locale.t("vol_master"), Locale.t("vol_music"), Locale.t("vol_sfx")]
	var slider_defaults := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	for i in 3:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(260, 28)
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = slider_names[i]
		lbl.custom_minimum_size = Vector2(55, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", vol_label_color)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = slider_defaults[i]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		slider.value_changed.connect(func(val: float) -> void:
			match idx:
				0: AudioManager.master_volume = val
				1: AudioManager.music_volume = val
				2: AudioManager.sfx_volume = val
		)
		row.add_child(slider)
		var cc := CenterContainer.new()
		cc.add_child(row)
		vbox.add_child(cc)

func _setup_debug_overlay() -> void:
	_debug_label = Label.new()
	_debug_label.visible = false
	_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_label.offset_left = 8.0
	_debug_label.offset_top = 90.0
	_debug_label.add_theme_font_size_override("font_size", 12)
	_debug_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_debug_label.add_theme_constant_override("outline_size", 3)
	_canvas.add_child(_debug_label)

func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	var style := _create_panel_style(Color(0.08, 0.06, 0.04, 0.95), Color(0.7, 0.55, 0.2), 2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", _create_panel_style(
		Color(0.16, 0.12, 0.05, 0.95), Color(0.9, 0.75, 0.3), 2))
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	return btn

func _round(style: StyleBoxFlat, r: int) -> void:
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r

func _create_panel_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	_round(style, 4)
	if border_color != Color.TRANSPARENT:
		style.border_color = border_color
		style.border_width_bottom = border_width
		style.border_width_top = border_width
		style.border_width_left = border_width
		style.border_width_right = border_width
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
