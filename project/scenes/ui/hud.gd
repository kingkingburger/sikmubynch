extends RefCounted

## 최소 HUD. 본진 위험 → 웨이브 → 미네랄 → 선택 건물 → 레이더 순으로 정보를 배치한다.
## 어두운 디아블로풍 패널 스타일을 유지한다. 전체 화면 플래시는 쓰지 않는다.

const ThreatRadar := preload("res://scripts/threat_radar.gd")
const BuildingCatalog := preload("res://scripts/building_catalog.gd")

signal slot_pressed(slot_index: int)
signal resume_requested()
signal restart_requested()
signal title_requested()

var _canvas: CanvasLayer
var _mineral_label: Label
var _wave_info_label: Label
var _hp_label: Label
var _hp_sub: Label
var _hq_warn_label: Label
var _selected_name: Label
var _selected_desc: Label
var _game_over_panel: PanelContainer
var _result_label: Label
var _slot_buttons: Array = []
var _slot_types: Array = []
var _threat_radar
var _banner_label: Label
var _banner_timer: float = 0.0
var _speed_label: Label
var _esc_panel: PanelContainer
var _debug_label: Label
var _hq_warn_timer: float = 0.0

func setup(root: Node, building_datas: Array) -> void:
	_canvas = CanvasLayer.new()
	root.add_child(_canvas)
	_slot_types = BuildingCatalog.buildable_types()
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

func update_hud(sim, paused: bool) -> void:
	if _mineral_label:
		_mineral_label.text = "$%d" % sim.minerals
	if _wave_info_label:
		var w: int = sim.waves.wave_number
		var text := Locale.t_fmt("wave_label", [w])
		text += "  |  " + Locale.t_fmt("kills_label", [sim.kills])
		text += "  |  " + Locale.t_fmt("enemies_label", [sim.enemies_alive()])
		if sim.waves.between:
			text += "  |  " + Locale.t_fmt("next_wave", [int(ceil(sim.waves.countdown))])
		if paused:
			text += "  ||"
		_wave_info_label.text = text
	if _hp_label:
		var hp := int(sim.hq_hp())
		var max_hp := int(sim.hq_max_hp())
		_hp_label.text = "%d / %d" % [hp, max_hp]
		var ratio := float(hp) / maxf(float(max_hp), 1.0)
		if ratio < 0.3:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		elif ratio < 0.6:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		else:
			_hp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))

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
	var side_text := Locale.t("side_all")
	if sides != 0xF:
		var names: Array = []
		if sides & 1:
			names.append(Locale.t("side_north"))
		if sides & 2:
			names.append(Locale.t("side_east"))
		if sides & 4:
			names.append(Locale.t("side_south"))
		if sides & 8:
			names.append(Locale.t("side_west"))
		side_text = "/".join(names)
	_banner_label.text = "%s  —  %s\n%s" % [
		Locale.t_fmt("wave_label", [wave_number]), Locale.t(type_key),
		Locale.t_fmt("from_side", [side_text, count])
	]
	var col := Color(1.0, 0.9, 0.4)
	if wave_type == 3:
		col = Color(1.0, 0.4, 0.3)
	elif wave_type == 2:
		col = Color(1.0, 0.65, 0.3)
	_banner_label.add_theme_color_override("font_color", col)
	_banner_label.visible = true
	_banner_timer = 3.0

func update_slot_highlight(selected_slot: int, building_datas: Array) -> void:
	for i in _slot_buttons.size():
		var btn: Button = _slot_buttons[i]
		var style: StyleBoxFlat
		if i == selected_slot:
			style = _create_panel_style(
				Color(0.18, 0.14, 0.06, 0.95), Color(1.0, 0.85, 0.25), 3)
		else:
			style = _create_panel_style(
				Color(0.12, 0.1, 0.07, 0.75), Color(0.4, 0.3, 0.18, 0.5), 2)
		_round(style, 6)
		btn.add_theme_stylebox_override("normal", style)
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

# ---------------------------------------------------------------------------
# 구성
# ---------------------------------------------------------------------------

func _setup_hud(building_datas: Array) -> void:
	_mineral_label = Label.new()
	_mineral_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mineral_label.offset_top = 6.0
	_mineral_label.offset_left = -80.0
	_mineral_label.offset_right = 80.0
	_mineral_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mineral_label.add_theme_font_size_override("font_size", 26)
	_mineral_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.95))
	_canvas.add_child(_mineral_label)

	var tr_panel := PanelContainer.new()
	tr_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_panel.offset_left = -300.0
	tr_panel.offset_top = 6.0
	tr_panel.offset_right = -8.0
	tr_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.06, 0.06, 0.08, 0.85), Color(0.3, 0.25, 0.15, 0.4), 1))
	_canvas.add_child(tr_panel)
	_wave_info_label = Label.new()
	_wave_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_info_label.add_theme_font_size_override("font_size", 13)
	_wave_info_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	tr_panel.add_child(_wave_info_label)

	# 본진 경고 (화면 상단 중앙, 작은 텍스트)
	_hq_warn_label = Label.new()
	_hq_warn_label.visible = false
	_hq_warn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hq_warn_label.offset_top = 40.0
	_hq_warn_label.offset_left = -200.0
	_hq_warn_label.offset_right = 200.0
	_hq_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hq_warn_label.text = Locale.t("hq_under_attack")
	_hq_warn_label.add_theme_font_size_override("font_size", 18)
	_hq_warn_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
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
	portrait.custom_minimum_size = Vector2(190, 0)
	portrait.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.05, 0.04, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	grid.add_child(portrait)
	var port_vbox := VBoxContainer.new()
	port_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	port_vbox.add_theme_constant_override("separation", 2)
	portrait.add_child(port_vbox)
	_hp_sub = Label.new()
	_hp_sub.text = Locale.t("hq_hp")
	_hp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_sub.add_theme_font_size_override("font_size", 10)
	_hp_sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	port_vbox.add_child(_hp_sub)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	port_vbox.add_child(_hp_label)
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
		btn.custom_minimum_size = Vector2(84, 72)
		var localized_name := Locale.t(bd.building_name)
		btn.text = "%d\n%s\n$%d" % [i + 1, localized_name, bd.cost]
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.88, 0.78, 0.4))
		var ns := _create_panel_style(
			Color(0.1, 0.09, 0.07, 0.85), Color(0.3, 0.25, 0.15, 0.5), 2)
		_round(ns, 4)
		btn.add_theme_stylebox_override("normal", ns)
		var hs := _create_panel_style(
			Color(0.18, 0.15, 0.08, 0.9), Color(0.9, 0.75, 0.25), 2)
		_round(hs, 4)
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_stylebox_override("pressed", hs)
		btn.add_theme_stylebox_override("focus", ns)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(slot_pressed.emit.bind(i))
		build_hbox.add_child(btn)
		_slot_buttons.append(btn)

	_threat_radar = ThreatRadar.new(grid, Locale.t("threat_radar"))

func _setup_banner() -> void:
	_banner_label = Label.new()
	_banner_label.visible = false
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.offset_top = 70.0
	_banner_label.offset_left = -300.0
	_banner_label.offset_right = 300.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 22)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_label.add_theme_constant_override("outline_size", 4)
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
	_speed_label.offset_top = 50.0
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
	_debug_label.offset_top = 40.0
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
