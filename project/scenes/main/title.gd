extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300.0
	vbox.offset_top = -200.0
	vbox.offset_right = 300.0
	vbox.offset_bottom = 200.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SIKMUBYNCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Wave Defense + Auto Battle + Roguelike"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4))
	vbox.add_child(subtitle)

	# Start button
	var start_btn := Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(220, 60)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.border_color = Color(0.7, 0.55, 0.2)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	start_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.14, 0.11, 0.06, 0.95)
	hover.border_color = Color(0.95, 0.8, 0.3)
	start_btn.add_theme_stylebox_override("hover", hover)
	start_btn.pressed.connect(_on_start)

	var center := CenterContainer.new()
	center.add_child(start_btn)
	vbox.add_child(center)

	# Controls info
	var info := Label.new()
	info.text = "1-5: Build  |  WASD: Camera  |  Scroll: Zoom  |  Space: Pause  |  F: Speed"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.4, 0.38, 0.3))
	vbox.add_child(info)

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")
