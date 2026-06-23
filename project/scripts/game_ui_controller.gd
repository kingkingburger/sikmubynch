extends RefCounted

const ThreatRadar := preload("res://scripts/threat_radar.gd")
const TraitData := preload("res://scripts/data/trait_data.gd")

signal slot_pressed(slot_index: int)
signal card_selected(index: int)
signal card_skipped()
signal choice_selected(index: int)
signal resume_requested()
signal restart_requested()
signal title_requested()

var _canvas: CanvasLayer
var _mineral_label: Label
var _wave_info_label: Label
var _hp_label: Label
var _game_over_panel: PanelContainer
var _result_label: Label
var _slot_buttons: Array = []
var _threat_radar

var _card_panel: PanelContainer
var _card_buttons: Array = []
var _card_skip_btn: Button

var _synergy_label: Label
var _event_label: Label
var _event_timer: float = 0.0
var _choice_panel: PanelContainer
var _choice_buttons: Array = []
var _choice_label: Label
var _speed_label: Label
var _esc_panel: PanelContainer
var _debug_label: Label

func setup(root: Node, building_datas: Array) -> void:
	_canvas = CanvasLayer.new()
	root.add_child(_canvas)

	_setup_hud(building_datas)
	_setup_game_over_panel()
	_setup_card_ui()
	_setup_synergy_bar()
	_setup_event_ui()
	_setup_choice_ui()
	_setup_speed_label()
	_setup_esc_menu()
	_setup_debug_overlay()

func get_canvas() -> CanvasLayer:
	return _canvas

func tick(
	delta: float,
	map_size: int,
	buildings: Array,
	enemies: Array,
	hq: Node3D,
	debug_visible: bool,
	enemies_alive: int,
	units_alive: int,
	buildings_count: int,
	game_speed: float
) -> void:
	if debug_visible and _debug_label:
		_debug_label.text = "FPS: %d\nEnemies: %d\nUnits: %d\nBuildings: %d\nSpeed: %.1fx" % [
			Engine.get_frames_per_second(), enemies_alive, units_alive, buildings_count, game_speed
		]

	if _event_timer > 0.0:
		_event_timer -= delta
		if _event_timer <= 0.0 and _event_label:
			_event_label.visible = false

	if _threat_radar:
		_threat_radar.tick(delta, map_size, buildings, enemies, hq)

func update_hud(
	minerals: int,
	wave_number: int,
	kill_count: int,
	enemies_alive: int,
	between_waves: bool,
	wave_countdown: float,
	paused: bool,
	hq_hp: int
) -> void:
	if _mineral_label:
		_mineral_label.text = "$%d" % minerals
	if _wave_info_label:
		var next := ""
		if between_waves:
			next = "  |  Next: %ds" % int(ceil(wave_countdown))
		var pause := "  ||" if paused else ""
		_wave_info_label.text = "W%d  K:%d  E:%d%s%s" % [
			wave_number, kill_count, enemies_alive, next, pause
		]
	if _hp_label:
		_hp_label.text = "%d" % hq_hp

func update_slot_highlight(selected_slot: int) -> void:
	for i in _slot_buttons.size():
		var btn: Button = _slot_buttons[i]
		var style: StyleBoxFlat
		if i == selected_slot:
			style = _create_panel_style(
				Color(0.18, 0.14, 0.06, 0.95), Color(1.0, 0.85, 0.25), 3)
		else:
			style = _create_panel_style(
				Color(0.12, 0.1, 0.07, 0.75), Color(0.4, 0.3, 0.18, 0.5), 2)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)

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

func show_reward_cards(cards: Array) -> void:
	for i in 3:
		if i < cards.size():
			var card: RewardCard = cards[i]
			_card_buttons[i].text = "[%s]\n%s\n%s" % [
				card.get_rarity_name(), card.card_name, card.description
			]
			_card_buttons[i].visible = true
			var rcolor: Color = card.get_rarity_color()
			_card_buttons[i].add_theme_stylebox_override("normal", _create_panel_style(
				Color(0.08, 0.06, 0.04, 0.95), rcolor * 0.6, 2))
			_card_buttons[i].add_theme_stylebox_override("hover", _create_panel_style(
				Color(0.14, 0.11, 0.06, 0.95), rcolor, 3))
		else:
			_card_buttons[i].visible = false
	if _card_panel:
		_card_panel.visible = true

func hide_reward_cards() -> void:
	if _card_panel:
		_card_panel.visible = false

func update_synergy_bar() -> void:
	if not _synergy_label:
		return
	var trait_icons := {
		TraitData.TraitType.FIRE: "F",
		TraitData.TraitType.ICE: "I",
		TraitData.TraitType.POISON: "P",
		TraitData.TraitType.ELECTRIC: "E",
		TraitData.TraitType.FORTIFY: "D",
	}
	var text := ""
	for t in [TraitData.TraitType.FIRE, TraitData.TraitType.ICE, TraitData.TraitType.POISON,
			TraitData.TraitType.ELECTRIC, TraitData.TraitType.FORTIFY]:
		var count := SynergyManager.get_trait_count(t)
		if count > 0:
			var tier := SynergyManager.get_synergy_tier(t)
			var tier_mark := ""
			if tier >= 2:
				tier_mark = " **"
			elif tier >= 1:
				tier_mark = " *"
			var icon: String = trait_icons.get(t, "?")
			text += "[%s] %s x%d%s\n" % [icon, TraitData.get_trait_name(t), count, tier_mark]
	var cross := SynergyManager.get_cross_synergies()
	for c in cross:
		text += ">> %s\n" % c.to_upper()
	_synergy_label.text = text

func show_combat_event(event_name: String, description: String) -> void:
	_show_event_text("%s: %s" % [Locale.t(event_name), Locale.t(description)], 4.0)

func show_choice_event(event_name: String, description: String, choices: Array) -> void:
	if _choice_label:
		_choice_label.text = "%s\n%s" % [Locale.t(event_name), Locale.t(description)]
	for i in _choice_buttons.size():
		if i < choices.size():
			_choice_buttons[i].text = Locale.t(choices[i]["label"])
			_choice_buttons[i].visible = true
		else:
			_choice_buttons[i].visible = false
	if _choice_panel:
		_choice_panel.visible = true

func hide_choice_panel() -> void:
	if _choice_panel:
		_choice_panel.visible = false

func show_event_result(result: String) -> void:
	if result != "":
		_show_event_text(result, 3.0)

func set_esc_visible(visible: bool) -> void:
	if _esc_panel:
		_esc_panel.visible = visible

func _show_event_text(text: String, duration: float) -> void:
	if _event_label:
		_event_label.text = text
		_event_label.visible = true
		_event_timer = duration

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
	tr_panel.offset_left = -220.0
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
	portrait.custom_minimum_size = Vector2(160, 0)
	portrait.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.05, 0.04, 0.03, 0.9), Color(0.3, 0.25, 0.15, 0.4), 1))
	grid.add_child(portrait)
	var port_vbox := VBoxContainer.new()
	port_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(port_vbox)
	var port_title := Label.new()
	port_title.text = "SELECTED"
	port_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_title.add_theme_font_size_override("font_size", 9)
	port_title.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	port_vbox.add_child(port_title)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	port_vbox.add_child(_hp_label)
	var hp_sub := Label.new()
	hp_sub.text = "HQ HP"
	hp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_sub.add_theme_font_size_override("font_size", 10)
	hp_sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.65))
	port_vbox.add_child(hp_sub)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	grid.add_child(center)

	var wave_bar := HBoxContainer.new()
	wave_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(wave_bar)

	var build_hbox := HBoxContainer.new()
	build_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	build_hbox.add_theme_constant_override("separation", 3)
	center.add_child(build_hbox)

	for i in building_datas.size():
		var bd := building_datas[i] as BuildingData
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 68)
		var localized_name := Locale.t(bd.building_name)
		btn.text = "%d\n%s\n$%d" % [i + 1, localized_name.substr(0, 4).to_upper(), bd.cost]
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", Color(0.88, 0.78, 0.4))
		var ns := _create_panel_style(
			Color(0.1, 0.09, 0.07, 0.85), Color(0.3, 0.25, 0.15, 0.5), 2)
		ns.corner_radius_top_left = 4
		ns.corner_radius_top_right = 4
		ns.corner_radius_bottom_left = 4
		ns.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", ns)
		var hs := _create_panel_style(
			Color(0.18, 0.15, 0.08, 0.9), Color(0.9, 0.75, 0.25), 2)
		hs.corner_radius_top_left = 4
		hs.corner_radius_top_right = 4
		hs.corner_radius_bottom_left = 4
		hs.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_stylebox_override("pressed", hs)
		btn.add_theme_stylebox_override("focus", ns)
		btn.pressed.connect(slot_pressed.emit.bind(i))
		build_hbox.add_child(btn)
		_slot_buttons.append(btn)

	_threat_radar = ThreatRadar.new(grid)

func _setup_game_over_panel() -> void:
	_game_over_panel = PanelContainer.new()
	_game_over_panel.visible = false
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(460, 280)
	_game_over_panel.offset_left = -230.0
	_game_over_panel.offset_top = -140.0
	_game_over_panel.offset_right = 230.0
	_game_over_panel.offset_bottom = 140.0
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

	var restart_btn := Button.new()
	restart_btn.text = Locale.t("restart")
	restart_btn.custom_minimum_size = Vector2(150, 46)
	var rb_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95), Color(0.7, 0.55, 0.2), 2)
	restart_btn.add_theme_stylebox_override("normal", rb_style)
	restart_btn.add_theme_stylebox_override("hover", _create_panel_style(
		Color(0.16, 0.12, 0.05, 0.95), Color(0.9, 0.75, 0.3), 2))
	restart_btn.add_theme_stylebox_override("pressed", rb_style)
	restart_btn.add_theme_stylebox_override("focus", rb_style)
	restart_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	restart_btn.add_theme_font_size_override("font_size", 17)
	restart_btn.pressed.connect(restart_requested.emit)
	var rb_center := CenterContainer.new()
	rb_center.add_child(restart_btn)
	vbox.add_child(rb_center)

func _setup_card_ui() -> void:
	_card_panel = PanelContainer.new()
	_card_panel.visible = false
	_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_panel.custom_minimum_size = Vector2(700, 320)
	_card_panel.offset_left = -350.0
	_card_panel.offset_top = -160.0
	_card_panel.offset_right = 350.0
	_card_panel.offset_bottom = 160.0
	_card_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.03, 0.03, 0.06, 0.96), Color(0.7, 0.55, 0.15), 3))
	_canvas.add_child(_card_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_card_panel.add_child(vbox)

	var title := Label.new()
	title.text = Locale.t("choose_reward")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 150)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		var card_normal := _create_panel_style(
			Color(0.07, 0.05, 0.03, 0.95), Color(0.5, 0.4, 0.2), 2)
		card_normal.corner_radius_top_left = 8
		card_normal.corner_radius_top_right = 8
		card_normal.corner_radius_bottom_left = 8
		card_normal.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", card_normal)
		var card_hover := _create_panel_style(
			Color(0.14, 0.11, 0.06, 0.95), Color(0.95, 0.8, 0.3), 3)
		card_hover.corner_radius_top_left = 8
		card_hover.corner_radius_top_right = 8
		card_hover.corner_radius_bottom_left = 8
		card_hover.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("hover", card_hover)
		btn.add_theme_stylebox_override("pressed", card_hover)
		btn.pressed.connect(card_selected.emit.bind(i))
		hbox.add_child(btn)
		_card_buttons.append(btn)

	_card_skip_btn = Button.new()
	_card_skip_btn.text = Locale.t("skip")
	_card_skip_btn.custom_minimum_size = Vector2(100, 36)
	_card_skip_btn.add_theme_font_size_override("font_size", 14)
	_card_skip_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_card_skip_btn.add_theme_stylebox_override("normal", _create_panel_style(
		Color(0.06, 0.05, 0.04, 0.9), Color(0.4, 0.35, 0.2), 1))
	_card_skip_btn.pressed.connect(card_skipped.emit)
	var skip_center := CenterContainer.new()
	skip_center.add_child(_card_skip_btn)
	vbox.add_child(skip_center)

func _setup_synergy_bar() -> void:
	var syn_panel := PanelContainer.new()
	syn_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	syn_panel.offset_left = 6.0
	syn_panel.offset_top = 40.0
	syn_panel.custom_minimum_size = Vector2(140, 0)
	syn_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.04, 0.05, 0.7), Color(0.25, 0.22, 0.15, 0.3), 1))
	_canvas.add_child(syn_panel)
	_synergy_label = Label.new()
	_synergy_label.add_theme_font_size_override("font_size", 11)
	_synergy_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	syn_panel.add_child(_synergy_label)
	update_synergy_bar()

func _setup_event_ui() -> void:
	_event_label = Label.new()
	_event_label.visible = false
	_event_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event_label.offset_top = 50.0
	_event_label.offset_left = -200.0
	_event_label.offset_right = 200.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 20)
	_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_canvas.add_child(_event_label)

func _setup_choice_ui() -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.visible = false
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.custom_minimum_size = Vector2(440, 200)
	_choice_panel.offset_left = -220.0
	_choice_panel.offset_top = -100.0
	_choice_panel.offset_right = 220.0
	_choice_panel.offset_bottom = 100.0
	_choice_panel.add_theme_stylebox_override("panel", _create_panel_style(
		Color(0.04, 0.03, 0.06, 0.96), Color(0.5, 0.7, 0.3), 3))
	_canvas.add_child(_choice_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_choice_panel.add_child(vbox)

	_choice_label = Label.new()
	_choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_label.add_theme_font_size_override("font_size", 17)
	_choice_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_choice_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for i in 2:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 44)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		btn.add_theme_stylebox_override("normal", _create_panel_style(
			Color(0.08, 0.06, 0.04, 0.95), Color(0.5, 0.6, 0.3), 2))
		btn.add_theme_stylebox_override("hover", _create_panel_style(
			Color(0.14, 0.12, 0.06, 0.95), Color(0.7, 0.8, 0.3), 2))
		btn.pressed.connect(choice_selected.emit.bind(i))
		hbox.add_child(btn)
		_choice_buttons.append(btn)

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

	var btn_style := _create_panel_style(
		Color(0.08, 0.06, 0.04, 0.95), Color(0.6, 0.5, 0.2), 2)
	var btn_hover := _create_panel_style(
		Color(0.14, 0.11, 0.06, 0.95), Color(0.85, 0.72, 0.3), 2)

	var resume_btn := Button.new()
	resume_btn.text = Locale.t("resume")
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	resume_btn.add_theme_stylebox_override("normal", btn_style)
	resume_btn.add_theme_stylebox_override("hover", btn_hover)
	resume_btn.pressed.connect(resume_requested.emit)
	var c1 := CenterContainer.new()
	c1.add_child(resume_btn)
	vbox.add_child(c1)

	var restart_btn := Button.new()
	restart_btn.text = Locale.t("restart")
	restart_btn.custom_minimum_size = Vector2(200, 40)
	restart_btn.add_theme_font_size_override("font_size", 16)
	restart_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_stylebox_override("hover", btn_hover)
	restart_btn.pressed.connect(restart_requested.emit)
	var c2 := CenterContainer.new()
	c2.add_child(restart_btn)
	vbox.add_child(c2)

	var title_btn := Button.new()
	title_btn.text = Locale.t("title_screen")
	title_btn.custom_minimum_size = Vector2(200, 40)
	title_btn.add_theme_font_size_override("font_size", 16)
	title_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	title_btn.add_theme_stylebox_override("normal", btn_style)
	title_btn.add_theme_stylebox_override("hover", btn_hover)
	title_btn.pressed.connect(title_requested.emit)
	var c3 := CenterContainer.new()
	c3.add_child(title_btn)
	vbox.add_child(c3)

	var vol_label_color := Color(0.75, 0.68, 0.4)
	var slider_names := ["Master", "Music", "SFX"]
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
	_debug_label.offset_top = 180.0
	_debug_label.add_theme_font_size_override("font_size", 12)
	_debug_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_canvas.add_child(_debug_label)

func _create_panel_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
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
