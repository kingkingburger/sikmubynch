extends Node

# Camera shake
var _camera: Camera3D
var _shake_intensity: float = 0.0
var _shake_decay: float = 8.0
var _camera_base_pos: Vector3

# Hit stop
var _hitstop_timer: float = 0.0

# Critical
const CRIT_CHANCE := 0.10
const CRIT_MULT := 2.0

# Game speed
var game_speed: float = 1.0
var paused: bool = false

func setup(camera: Camera3D, _canvas: CanvasLayer) -> void:
	_camera = camera
	_camera_base_pos = camera.position

func _process(delta: float) -> void:
	# Hit stop
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		Engine.time_scale = 0.05
		if _hitstop_timer <= 0.0:
			Engine.time_scale = game_speed if not paused else 0.0
		return

	# Camera shake
	if _shake_intensity > 0.0 and _camera:
		_shake_intensity = maxf(_shake_intensity - _shake_decay * delta, 0.0)
		var offset := Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity) * 0.5,
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_camera.position = _camera_base_pos + offset
		if _shake_intensity <= 0.01:
			_camera.position = _camera_base_pos
			_shake_intensity = 0.0

func shake(intensity: float = 0.3) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)

func hitstop(duration: float = 0.04) -> void:
	_hitstop_timer = duration

func roll_critical(base_damage: float, pos: Vector3 = Vector3.ZERO) -> float:
	if randf() < CRIT_CHANCE:
		shake(0.15)
		if pos != Vector3.ZERO:
			EffectsManager.spawn_crit_effect(pos)
		return base_damage * CRIT_MULT
	return base_damage

func set_game_speed(speed: float) -> void:
	game_speed = speed
	if not paused:
		Engine.time_scale = speed

func toggle_pause() -> void:
	paused = not paused
	Engine.time_scale = 0.0 if paused else game_speed

func cycle_speed() -> float:
	if game_speed < 1.5:
		set_game_speed(2.0)
	elif game_speed < 2.5:
		set_game_speed(3.0)
	elif game_speed < 4.0:
		set_game_speed(5.0)
	else:
		set_game_speed(1.0)
	return game_speed

func update_camera_base(pos: Vector3) -> void:
	_camera_base_pos = pos
	if _shake_intensity <= 0.0 and _camera:
		_camera.position = pos

func reset() -> void:
	_shake_intensity = 0.0
	_hitstop_timer = 0.0
	game_speed = 1.0
	paused = false
	Engine.time_scale = 1.0
