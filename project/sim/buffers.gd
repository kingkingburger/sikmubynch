extends RefCounted

## 고정 크기 Packed 배열 할당. 시뮬레이션·렌더러의 구조 배열(SoA)을 한 줄로 만든다.

static func f32(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a

static func i32(n: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(n)
	return a
