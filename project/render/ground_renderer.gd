extends Node2D

## 지면. 맵 마름모, 타일 격자, 바닥 얼룩, HQ 글로우를 한 번만 그린다.

const Iso := preload("res://render/iso.gd")
const SpriteFactory := preload("res://render/sprite_factory.gd")

const TILES_PER_TEXTURE := 8.0   # 지면 텍스처 1장이 덮는 타일 수 (1024px → 타일당 128px 탑다운)

var map_size: int = 128
var hq_center: Vector2 = Vector2(63.5, 63.5)
var _patches: Array = []   # [Vector2 tile, size, Color]
var _ground_tex: Texture2D = null

func setup(size: int, hq: Vector2, seed_value: int) -> void:
	map_size = size
	hq_center = hq
	_ground_tex = SpriteFactory.load_sprite("ground", "ground")
	if _ground_tex != null:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_patches.clear()
	for i in range(220):
		var tx := rng.randf_range(0.0, float(size) - 3.0)
		var ty := rng.randf_range(0.0, float(size) - 3.0)
		var s := rng.randf_range(1.5, 4.0)
		var shade := rng.randf_range(-0.02, 0.03)
		var moss := rng.randf() < 0.35
		var c := Color(0.075 + shade, 0.085 + shade + (0.03 if moss else 0.0), 0.06 + shade, 0.9)
		_patches.append([Vector2(tx, ty), s, c])

	# HQ 글로우
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.make_glow_texture(256, Color(0.2, 0.35, 0.7, 0.35))
	glow.position = Iso.to_screen_v(hq_center)
	glow.scale = Vector2(2.6, 1.3)
	glow.z_index = 1
	add_child(glow)
	queue_redraw()

func _draw() -> void:
	var s := float(map_size)
	# 바닥 마름모
	var base := PackedVector2Array([
		Iso.to_screen(0.0, 0.0), Iso.to_screen(s, 0.0), Iso.to_screen(s, s), Iso.to_screen(0.0, s)
	])
	var grid_col := Color(0.11, 0.13, 0.08, 0.55)
	var chunk_col := Color(0.15, 0.13, 0.08, 0.7)
	if _ground_tex != null:
		# 텍스처 지면: 타일 좌표를 UV로 (이소 투영은 아핀이라 두 삼각형으로 정확히 맞는다)
		var u := s / TILES_PER_TEXTURE
		var uvs := PackedVector2Array([Vector2(0, 0), Vector2(u, 0), Vector2(u, u), Vector2(0, u)])
		var cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		draw_polygon(base, cols, uvs, _ground_tex)
		grid_col = Color(0.0, 0.0, 0.0, 0.18)
		chunk_col = Color(0.0, 0.0, 0.0, 0.3)
	else:
		draw_colored_polygon(base, Color(0.07, 0.08, 0.055))
		# 얼룩
		for p in _patches:
			var t: Vector2 = p[0]
			var sz: float = p[1]
			draw_colored_polygon(Iso.tile_diamond(t.x, t.y, sz), p[2])
	# 격자
	for i in range(map_size + 1):
		var fi := float(i)
		var col := chunk_col if i % 8 == 0 else grid_col
		var w := 1.5 if i % 8 == 0 else 1.0
		draw_line(Iso.to_screen(fi, 0.0), Iso.to_screen(fi, s), col, w)
		draw_line(Iso.to_screen(0.0, fi), Iso.to_screen(s, fi), col, w)
	# 외곽
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), Color(0.3, 0.25, 0.15), 3.0)
