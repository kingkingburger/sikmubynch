extends Button

## 건설 칸 하나: 실제 건물 그림 + 단축키 + 크리스탈 가격.
## 선택되면 금색 테두리로 떠오르고, 못 사면 흑백 + 빨간 가격. 상태 변화는 보간으로 부드럽게.

const UiKit := preload("res://scenes/ui/ui_kit.gd")
const GemIcon := preload("res://scenes/ui/gem_icon.gd")

const GRAY_SHADER := """
shader_type canvas_item;
uniform float gray = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(c.rgb, vec3(l) * 0.55, gray), c.a) * COLOR;
}
"""
static var _gray_shader: Shader

const SLOT_SIZE := Vector2(84, 92)

var selected: bool = false
var affordable: bool = true
var _lift: float = 0.0        # 선택 시 위로 뜨는 정도 (0..1, 보간)
var _hover: float = 0.0
var _gray: float = 0.0
var _flash: float = 0.0       # 방금 살 수 있게 된 순간 반짝
var _icon: TextureRect
var _mat: ShaderMaterial
var _key: Label
var _cost: Label
var _gem

func _init(hotkey: int, icon: Texture2D, cost: int) -> void:
	custom_minimum_size = SLOT_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, empty)
	if _gray_shader == null:
		_gray_shader = Shader.new()
		_gray_shader.code = GRAY_SHADER
	_icon = TextureRect.new()
	_icon.texture = icon
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(8, 6)
	_icon.size = Vector2(SLOT_SIZE.x - 16, 58)
	_mat = ShaderMaterial.new()
	_mat.shader = _gray_shader
	_icon.material = _mat
	add_child(_icon)
	_key = UiKit.label(str(hotkey), 11, UiKit.TEXT_3, UiKit.FONT_BOLD)
	_key.position = Vector2(6, 3)
	add_child(_key)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, SLOT_SIZE.y - 26)
	row.size = Vector2(SLOT_SIZE.x, 22)
	add_child(row)
	_gem = GemIcon.new(14.0)
	_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_gem)
	_cost = UiKit.display(str(cost), 17, UiKit.CRYSTAL_HI)
	row.add_child(_cost)

func set_state(is_selected: bool, can_afford: bool) -> void:
	if can_afford and not affordable:
		_flash = 1.0
	selected = is_selected
	affordable = can_afford

func _process(delta: float) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	_lift = lerpf(_lift, 1.0 if selected else 0.0, k)
	_hover = lerpf(_hover, 1.0 if is_hovered() else 0.0, k)
	_gray = lerpf(_gray, 0.0 if affordable else 1.0, k)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_mat.set_shader_parameter("gray", _gray)
	var cost_col := UiKit.CRYSTAL_HI.lerp(Color(1.0, 0.45, 0.4), _gray)
	_cost.add_theme_color_override("font_color", cost_col)
	_key.add_theme_color_override("font_color", UiKit.TEXT_3.lerp(UiKit.AMBER, _lift))
	var y := -6.0 * _lift - 2.0 * _hover
	_icon.position.y = 6.0 + y
	_key.position.y = 3.0 + y
	_icon.scale = Vector2.ONE * (1.0 + 0.04 * _hover)
	_icon.pivot_offset = _icon.size * 0.5
	queue_redraw()

func _draw() -> void:
	var y := -6.0 * _lift - 2.0 * _hover
	var r := Rect2(Vector2(0, y), SLOT_SIZE)
	# 선택 발광: 모서리 깎은 윤곽을 바깥으로 몇 겹 흐리게
	if _lift > 0.01:
		for i in 3:
			var g := float(i + 1) * 2.5
			var glow := _chamfer(r.grow(g), 6.0 + g)
			glow.append(glow[0])
			draw_polyline(glow, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, (0.3 - 0.08 * float(i)) * _lift), 2.5, true)
	var top := Color(0.14, 0.165, 0.2).lerp(Color(0.23, 0.18, 0.09), _lift)
	var bottom := Color(0.075, 0.09, 0.11).lerp(Color(0.09, 0.07, 0.03), _lift)
	top = top.lerp(top.lightened(0.12), _hover)
	var pts := _chamfer(r, 6.0)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - r.position.y) / r.size.y))
	draw_polygon(pts, cols)
	var border := UiKit.LINE.lerp(UiKit.LINE_HI, _hover).lerp(UiKit.AMBER, _lift)
	pts.append(pts[0])
	draw_polyline(pts, border, 1.0 + _lift, true)
	if _flash > 0.0:
		draw_polyline(pts, Color(UiKit.CRYSTAL.r, UiKit.CRYSTAL.g, UiKit.CRYSTAL.b, _flash), 2.0, true)

static func _chamfer(r: Rect2, c: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])
