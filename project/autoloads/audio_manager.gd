extends Node

## BGM/SFX 재생 관리. 볼륨 제어, BGM 크로스페이드, SFX 풀링.

var _bgm_player: AudioStreamPlayer
var _bgm_fade_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

var master_volume: float = 0.8:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
var music_volume: float = 0.7:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		if _bgm_player:
			_bgm_player.volume_db = linear_to_db(music_volume)
		if _bgm_fade_player:
			_bgm_fade_player.volume_db = linear_to_db(music_volume)
var sfx_volume: float = 0.8:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)

# Preloaded SFX cache
var _sfx_cache: Dictionary = {}

# Crossfade state
var _fading: bool = false
var _fade_time: float = 0.0
const FADE_DURATION := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = linear_to_db(music_volume)
	add_child(_bgm_player)

	_bgm_fade_player = AudioStreamPlayer.new()
	_bgm_fade_player.bus = "Master"
	_bgm_fade_player.volume_db = linear_to_db(0.0)
	add_child(_bgm_fade_player)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_time += delta
	var t := clampf(_fade_time / FADE_DURATION, 0.0, 1.0)
	_bgm_fade_player.volume_db = linear_to_db(music_volume * (1.0 - t))
	_bgm_player.volume_db = linear_to_db(music_volume * t)
	if t >= 1.0:
		_fading = false
		_bgm_fade_player.stop()

func play_bgm(stream: AudioStream) -> void:
	if not stream:
		return
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	if _bgm_player.playing:
		# Crossfade: old → fade player, new → main player
		_bgm_fade_player.stream = _bgm_player.stream
		_bgm_fade_player.volume_db = _bgm_player.volume_db
		_bgm_fade_player.play(_bgm_player.get_playback_position())
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(0.0)
		_bgm_player.play()
		_fading = true
		_fade_time = 0.0
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(music_volume)
		_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_fade_player.stop()
	_fading = false

func play_sfx(stream: AudioStream, volume_offset_db: float = 0.0) -> void:
	if not stream:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(sfx_volume) + volume_offset_db
			p.play()
			return
	# All busy — steal oldest
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = linear_to_db(sfx_volume) + volume_offset_db
	_sfx_players[0].play()

func play_sfx_by_name(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	if not _sfx_cache.has(sfx_name):
		var path := "res://assets/audio/sfx/%s.ogg" % sfx_name
		if ResourceLoader.exists(path):
			_sfx_cache[sfx_name] = load(path)
		else:
			return
	play_sfx(_sfx_cache[sfx_name], volume_offset_db)
