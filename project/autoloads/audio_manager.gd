extends Node

## BGM/SFX 재생 관리. 볼륨 제어, BGM 크로스페이드, SFX 풀링.
## 대량 처치는 개별 재생하지 않고 처치 수 구간별로 레이어를 쌓는다(play_kill_layer).

var _bgm_player: AudioStreamPlayer
var _bgm_fade_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 12
const SAME_SFX_MAX_CONCURRENT := 3

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

var _sfx_cache: Dictionary = {}

var _fading: bool = false
var _fade_time: float = 0.0
const FADE_DURATION := 1.0

# 같은 사운드가 짧은 시간에 몰리는 것을 막는 쿨다운
var _sfx_last_play: Dictionary = {}
const SFX_MIN_INTERVAL := 0.04

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

## 모든 재생 정지. 종료 직전(헤드리스 테스트 등)에 재생 중인 스트림이 누수로 잡히지 않게 한다.
func stop_all() -> void:
	stop_bgm()
	_bgm_player.stream = null
	_bgm_fade_player.stream = null
	for p in _sfx_players:
		p.stop()
		p.stream = null
	_sfx_cache.clear()

func play_sfx(stream: AudioStream, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var same := 0
	for p in _sfx_players:
		if p.playing and p.stream == stream:
			same += 1
	if same >= SAME_SFX_MAX_CONCURRENT:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(sfx_volume) + volume_offset_db
			p.pitch_scale = pitch
			p.play()
			return
	# All busy — steal first
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = linear_to_db(sfx_volume) + volume_offset_db
	_sfx_players[0].pitch_scale = pitch
	_sfx_players[0].play()

func play_sfx_by_name(sfx_name: String, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var last: float = _sfx_last_play.get(sfx_name, -1.0)
	if now - last < SFX_MIN_INTERVAL:
		return
	_sfx_last_play[sfx_name] = now
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	play_sfx(stream, volume_offset_db, pitch)

func _load_sfx(sfx_name: String) -> AudioStream:
	if not _sfx_cache.has(sfx_name):
		var base := "res://assets/audio/sfx/%s" % sfx_name
		var stream: AudioStream = null
		for ext in [".ogg", ".wav", ".mp3"]:
			var path: String = base + ext
			if ResourceLoader.exists(path):
				stream = load(path)
				break
		_sfx_cache[sfx_name] = stream
	return _sfx_cache[sfx_name]

## 틱 처치 수에 따라 사운드 레이어를 쌓는다. 1마리는 조용하고, 수십 마리는 폭발음이 겹친다.
func play_kill_layer(kill_count: int, explosion_kills: int) -> void:
	if kill_count <= 0:
		return
	if kill_count >= 30:
		play_sfx_by_name("explosion", 2.0, 0.8)
		play_sfx_by_name("death", 0.0, 0.7)
	elif kill_count >= 10:
		play_sfx_by_name("explosion", -3.0, 0.95)
		play_sfx_by_name("death", -3.0, 0.85)
	elif kill_count >= 3:
		play_sfx_by_name("death", -4.0, 0.95)
	else:
		play_sfx_by_name("death", -9.0, 1.0 + randf_range(-0.05, 0.05))
	if explosion_kills >= 5 and kill_count < 10:
		play_sfx_by_name("explosion", -4.0, 1.0)

func play_bgm_by_name(bgm_name: String) -> void:
	var base := "res://assets/audio/bgm/%s" % bgm_name
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = base + ext
		if ResourceLoader.exists(path):
			play_bgm(load(path))
			return
