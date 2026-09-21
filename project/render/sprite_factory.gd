extends RefCounted

## 폴백 스프라이트 생성기. 아틀라스가 준비되기 전까지 색상 도형으로 개체를 그린다.
## 모든 개체 스프라이트는 바닥에 그림자 타원을 포함한다.

const SHADOW_ALPHA := 0.45
const SPRITE_ROOT := "res://assets/sprites/"

enum Shape { DIAMOND, HEX, SEAM_DIAMOND, DOT, BLOB }

static var _cache: Dictionary = {}

## assets/sprites/<category>/<name>.png 가 있으면 텍스처, 없으면 null (호출자가 폴백을 쓴다).
## 줌아웃에서 축소돼도 떨리지 않게 밉맵을 런타임에 만든다 (.import 설정에 의존하지 않는다).
## 호출자는 texture_filter 를 TEXTURE_FILTER_LINEAR_WITH_MIPMAPS 로 둔다.
static func load_sprite(category: String, name: String) -> Texture2D:
	var path := SPRITE_ROOT + category + "/" + name + ".png"
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded := load(path) as Texture2D
		if loaded != null:
			var img := loaded.get_image()
			if img != null and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
			else:
				tex = loaded
	_cache[path] = tex
	return tex

## 건물 이름(BuildingData.building_name) → 스프라이트 파일 이름
static func building_sprite_key(building_name: String) -> String:
	match building_name:
		"HQ": return "hq"
		"Barricade": return "barricade"
		"Wall": return "wall"
		"Gun Tower": return "gun_tower"
		"Cannon": return "cannon_tower"
		"Frost Tower": return "frost_tower"
		"Flame Tower": return "flame_tower"
		"Tesla Tower": return "tesla_tower"
		"Sniper Tower": return "sniper_tower"
	return building_name.to_lower().replace(" ", "_")

static func enemy_sprite_key(enemy_type: int) -> String:
	match enemy_type:
		EnemyData.EnemyType.RUSHER: return "rusher"
		EnemyData.EnemyType.TANK: return "tank"
		EnemyData.EnemyType.SPLITTER: return "splitter"
		EnemyData.EnemyType.MINI: return "mini"
	return "rusher"

## 2D MultiMesh용 사각 메시. QuadMesh는 캔버스에서 상하가 뒤집히므로 UV를 직접 지정한다.
## 정점 색은 흰색으로 명시한다. 색 속성이 없으면 GL Compatibility에서 커스텀 셰이더의 COLOR가 정점마다 달라진다.
static func make_quad_mesh(w: float, h: float) -> ArrayMesh:
	var hw := w * 0.5
	var hh := h * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-hw, -hh, 0.0))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(hw, -hh, 0.0))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(hw, hh, 0.0))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-hw, -hh, 0.0))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(hw, hh, 0.0))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(-hw, hh, 0.0))
	return st.commit()

## 맵 전체를 덮는 AABB. MultiMesh 캔버스 아이템이 컬링되지 않게 하고 AABB 재계산 비용을 없앤다.
static func map_aabb(map_size: int) -> AABB:
	var half_w := float(map_size) * 32.0
	var h := float(map_size) * 32.0
	return AABB(Vector3(-half_w - 256.0, -512.0, -1.0), Vector3(half_w * 2.0 + 512.0, h + 1024.0, 2.0))

## 적 스프라이트. px = 스프라이트 한 변(정사각형). 몸통은 위쪽 70%, 그림자는 아래쪽.
static func make_enemy_texture(shape: int, px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(px) * 0.5
	var body_h := float(px) * 0.72
	var body_cy := body_h * 0.5 + 1.0
	var body_w := float(px) * 0.62
	var shadow_cy := float(px) * 0.86
	var shadow_rx := float(px) * 0.36
	var shadow_ry := float(px) * 0.13
	var outline := color.darkened(0.55)
	var light := color.lightened(0.35)
	for y in range(px):
		for x in range(px):
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			# 그림자
			var sx := (fx - cx) / shadow_rx
			var sy := (fy - shadow_cy) / shadow_ry
			var sd := sx * sx + sy * sy
			if sd <= 1.0:
				var a := SHADOW_ALPHA * (1.0 - sd * 0.5)
				img.set_pixel(x, y, Color(0, 0, 0, a))
			# 몸통
			var u := (fx - cx) / (body_w * 0.5)
			var v := (fy - body_cy) / (body_h * 0.5)
			var d := _shape_distance(shape, u, v)
			if d <= 1.0:
				var c := color
				if d > 0.78:
					c = outline
				elif v < -0.2 and u < 0.1 and d < 0.6:
					c = light
				if shape == Shape.SEAM_DIAMOND and absf(u) < 0.12 and d < 0.78:
					c = Color(0.95, 1.0, 0.7)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func _shape_distance(shape: int, u: float, v: float) -> float:
	match shape:
		Shape.DIAMOND, Shape.SEAM_DIAMOND:
			return absf(u) + absf(v)
		Shape.HEX:
			return maxf(absf(v), absf(u) * 0.85 + absf(v) * 0.45)
		Shape.BLOB:
			return sqrt(u * u + v * v * 1.3)
		_:
			return sqrt(u * u + v * v)

## 부드러운 원. 발사체·파티클용.
static func make_dot_texture(px: int, soft: bool = true) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	for y in range(px):
		for x in range(px):
			var dx := (float(x) + 0.5 - c) / c
			var dy := (float(y) + 0.5 - c) / c
			var d := sqrt(dx * dx + dy * dy)
			if d <= 1.0:
				var a := 1.0
				if soft:
					a = clampf(1.0 - d * d, 0.0, 1.0)
				elif d > 0.75:
					a = 0.8
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## 방사형 발광 (HQ 바닥 글로우 등)
static func make_glow_texture(px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	for y in range(px):
		for x in range(px):
			var dx := (float(x) + 0.5 - c) / c
			var dy := (float(y) + 0.5 - c) / c
			var d := sqrt(dx * dx + dy * dy)
			if d <= 1.0:
				var a := pow(1.0 - d, 2.2) * color.a
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)
