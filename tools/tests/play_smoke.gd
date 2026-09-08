extends SceneTree

# Five minutes of real elapsed time using viewport mouse input and normal resources.
var gm
var game
var output_dir: String
var started_ms: int
var next_action := 0.0
var next_sample := 0.0
var modal_since := -1.0
var last_modal := ""
var runs: Array = []
var samples: Array = []
var failures: Array[String] = []
var builds := 0
var rewards := 0
var captured: Dictionary = {}
var duration := 300.0
var ending := false

func _initialize() -> void:
	call_deferred("_run")

func click_at(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = pos
		button.pressed = pressed
		root.push_input(button)

func click_button(button: Button) -> void:
	click_at(button.get_global_rect().get_center())

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := find_button(child, caption)
		if found:
			return found
	return null

func capture(label: String) -> void:
	if captured.has(label) or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(output_dir.path_join(label + ".png"))
		captured[label] = true

func _run() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	output_dir = ProjectSettings.globalize_path("res://../build/play-smoke-" + stamp)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			duration = float(arg.trim_prefix("--seconds="))
	if duration <= 0.0:
		push_error("--seconds must be positive")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	gm = root.get_node("GameManager")
	seed(20260908)
	change_scene_to_file("res://scenes/main/title.tscn")
	await process_frame
	await process_frame
	await capture("title")
	var start := find_button(current_scene, root.get_node("Locale").t("start_game"))
	if start == null:
		push_error("Start button missing")
		quit(1)
		return
	click_button(start)
	await process_frame
	await process_frame
	if current_scene.scene_file_path != "res://scenes/main/game.tscn":
		push_error("Viewport click did not start game")
		quit(1)
		return
	game = current_scene
	game._debug_visible = true
	game._ui.set_debug_visible(true)
	started_ms = Time.get_ticks_msec()
	print("PLAY START: duration=", duration, " display=", DisplayServer.get_name())
	print("PLAY OUTPUT: ", output_dir)
	while not ending:
		await process_frame
		var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0
		if elapsed >= duration:
			ending = true
			break
		if elapsed >= next_sample:
			next_sample = elapsed + 1.0
			_sample(elapsed)
		if elapsed < next_action:
			continue
		next_action = elapsed + 0.5
		await _act(elapsed)
	await capture("finish")
	_record_run("time_limit")
	var report := {"elapsed_seconds": (Time.get_ticks_msec() - started_ms) / 1000.0,
		"builds": builds, "rewards": rewards, "runs": runs, "samples": samples, "failures": failures}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PLAY RESULT: builds=%d rewards=%d runs=%d failures=%d" % [builds, rewards, runs.size(), failures.size()])
	print("PLAY RUNS: ", JSON.stringify(runs))
	quit(0 if failures.is_empty() else 1)

func _sample(elapsed: float) -> void:
	var living := get_nodes_in_group("enemies").filter(func(enemy): return not enemy._dead).size()
	if living != game.enemies_alive:
		var message := "Enemy count mismatch: %d != %d" % [living, game.enemies_alive]
		if message not in failures:
			failures.append(message)
	var row := {"wall_s": snappedf(elapsed, 0.01), "run_s": snappedf(gm.game_time, 0.01),
		"wave": gm.wave_number, "kills": gm.kill_count, "enemies": living,
		"buildings": game._buildings_count, "minerals": gm.minerals,
		"hq_hp": snappedf(game._hq.current_hp, 0.1), "fps": Engine.get_frames_per_second()}
	samples.append(row)
	if int(elapsed) % 30 == 0:
		print("PLAY SAMPLE: ", JSON.stringify(row))

func _record_run(reason: String) -> void:
	runs.append({"reason": reason, "wave": gm.wave_number, "kills": gm.kill_count,
		"run_seconds": gm.game_time, "hq_hp": game._hq.current_hp})

func _act(elapsed: float) -> void:
	var modal := "game_over" if gm.is_game_over else ("reward" if game._awaiting_card else ("choice" if game._awaiting_choice else ""))
	if modal != last_modal:
		modal_since = elapsed
		last_modal = modal
	if modal != "":
		await capture(modal)
		if elapsed - modal_since < 2.0:
			return
		if modal == "game_over":
			_record_run("game_over")
			var restart := find_button(game._ui._game_over_panel, root.get_node("Locale").t("restart"))
			click_button(restart)
			await process_frame
			await process_frame
			game = current_scene
			game._debug_visible = true
			game._ui.set_debug_visible(true)
		elif modal == "reward":
			var best := 0
			var score := -1.0
			for i in game._pending_cards.size():
				var card = game._pending_cards[i]
				var value: float = card.effect_value
				if card.trait_type in [1, 3, 4]:
					value += 100.0
				if value > score:
					score = value
					best = i
			click_button(game._ui._card_buttons[best])
			rewards += 1
		else:
			# Use the safe/pass option; no forced challenge, resources, or damage.
			click_button(game._ui._choice_buttons[game._pending_choices.size() - 1])
		return
	await capture("battle")
	if gm.minerals < 50:
		return
	var sites := [Vector2i(126, 128), Vector2i(130, 128), Vector2i(128, 126), Vector2i(128, 130),
		Vector2i(126, 126), Vector2i(130, 130), Vector2i(126, 130), Vector2i(130, 126)]
	for tile in sites:
		if game.building_grid.has(tile):
			continue
		click_button(game._ui._slot_buttons[1])
		var before: int = game._buildings_count
		click_at(game._camera.unproject_position(Vector3(tile.x + 0.5, 0, tile.y + 0.5)))
		if game._buildings_count > before:
			builds += 1
		return
	for tile in sites:
		var building = game.building_grid.get(tile)
		if is_instance_valid(building) and building.level < 3:
			click_at(game._camera.unproject_position(building.position))
			return
