extends RefCounted

## Combat Sim — 타워 타겟팅, 발사체 진행, 피해·감속 적용, 처치 집계.
## 시너지 배율은 없다. 피해는 _apply_damage 한곳을 거친다(재도입 시 배율을 여기에 끼운다).

const SimConfig := preload("res://sim/sim_config.gd")

const MAX := SimConfig.MAX_PROJECTILES
const KIND_NONE := 0
const KIND_BULLET := 1
const KIND_SHELL := 2
const KIND_FROST := 3
const PROJECTILE_TTL := 3.0
const QUERY_CAP := 512

# 발사체 배열
var p_alive: PackedInt32Array
var p_kind: PackedInt32Array
var p_x: PackedFloat32Array
var p_y: PackedFloat32Array
var p_prev_x: PackedFloat32Array
var p_prev_y: PackedFloat32Array
var p_tx: PackedFloat32Array       # 목표 지점 (셸) 또는 마지막 목표 위치
var p_ty: PackedFloat32Array
var p_target: PackedInt32Array     # 유도 대상 적 인덱스, 없으면 -1
var p_target_gen: PackedInt32Array # 대상의 generation (인덱스 재사용 구분)
var p_damage: PackedFloat32Array
var p_speed: PackedFloat32Array
var p_splash: PackedFloat32Array
var p_slow: PackedFloat32Array
var p_slow_dur: PackedFloat32Array
var p_ttl: PackedFloat32Array
var p_free: PackedInt32Array
var p_high: int = 0
var p_alive_count: int = 0

# 이번 틱 결과
var tick_kills: int = 0
var tick_damage_events: int = 0
var hit_count: int = 0
var hit_x: PackedFloat32Array
var hit_y: PackedFloat32Array
var hit_kind: PackedInt32Array
var explosion_count: int = 0
var explosion_x: PackedFloat32Array
var explosion_y: PackedFloat32Array
var explosion_radius: PackedFloat32Array
var explosion_kills: PackedInt32Array
var shots_fired: int = 0

var _query: PackedInt32Array

func _init() -> void:
	p_alive = PackedInt32Array()
	p_alive.resize(MAX)
	p_kind = PackedInt32Array()
	p_kind.resize(MAX)
	p_x = PackedFloat32Array()
	p_x.resize(MAX)
	p_y = PackedFloat32Array()
	p_y.resize(MAX)
	p_prev_x = PackedFloat32Array()
	p_prev_x.resize(MAX)
	p_prev_y = PackedFloat32Array()
	p_prev_y.resize(MAX)
	p_tx = PackedFloat32Array()
	p_tx.resize(MAX)
	p_ty = PackedFloat32Array()
	p_ty.resize(MAX)
	p_target = PackedInt32Array()
	p_target.resize(MAX)
	p_target_gen = PackedInt32Array()
	p_target_gen.resize(MAX)
	p_damage = PackedFloat32Array()
	p_damage.resize(MAX)
	p_speed = PackedFloat32Array()
	p_speed.resize(MAX)
	p_splash = PackedFloat32Array()
	p_splash.resize(MAX)
	p_slow = PackedFloat32Array()
	p_slow.resize(MAX)
	p_slow_dur = PackedFloat32Array()
	p_slow_dur.resize(MAX)
	p_ttl = PackedFloat32Array()
	p_ttl.resize(MAX)
	p_free = PackedInt32Array()
	hit_x = PackedFloat32Array()
	hit_x.resize(SimConfig.MAX_HIT_EVENTS)
	hit_y = PackedFloat32Array()
	hit_y.resize(SimConfig.MAX_HIT_EVENTS)
	hit_kind = PackedInt32Array()
	hit_kind.resize(SimConfig.MAX_HIT_EVENTS)
	explosion_x = PackedFloat32Array()
	explosion_x.resize(SimConfig.MAX_EXPLOSION_EVENTS)
	explosion_y = PackedFloat32Array()
	explosion_y.resize(SimConfig.MAX_EXPLOSION_EVENTS)
	explosion_radius = PackedFloat32Array()
	explosion_radius.resize(SimConfig.MAX_EXPLOSION_EVENTS)
	explosion_kills = PackedInt32Array()
	explosion_kills.resize(SimConfig.MAX_EXPLOSION_EVENTS)
	_query = PackedInt32Array()
	_query.resize(QUERY_CAP)
	clear_all()

func clear_all() -> void:
	p_alive.fill(0)
	p_free = PackedInt32Array()
	p_high = 0
	p_alive_count = 0
	clear_tick_results()

func clear_tick_results() -> void:
	tick_kills = 0
	tick_damage_events = 0
	hit_count = 0
	explosion_count = 0
	shots_fired = 0

func _alloc_projectile() -> int:
	var idx := -1
	if p_free.size() > 0:
		idx = p_free[p_free.size() - 1]
		p_free.resize(p_free.size() - 1)
	else:
		if p_high >= MAX:
			return -1
		idx = p_high
		p_high += 1
	p_alive[idx] = 1
	p_alive_count += 1
	return idx

func _free_projectile(idx: int) -> void:
	p_alive[idx] = 0
	p_alive_count -= 1
	p_free.append(idx)

func fire(kind: int, x: float, y: float, target: int, target_gen: int, tx: float, ty: float,
		damage: float, speed: float, splash: float, slow: float, slow_dur: float) -> int:
	var idx := _alloc_projectile()
	if idx < 0:
		return -1
	p_kind[idx] = kind
	p_x[idx] = x
	p_y[idx] = y
	p_prev_x[idx] = x
	p_prev_y[idx] = y
	p_tx[idx] = tx
	p_ty[idx] = ty
	p_target[idx] = target
	p_target_gen[idx] = target_gen
	p_damage[idx] = damage
	p_speed[idx] = speed
	p_splash[idx] = splash
	p_slow[idx] = slow
	p_slow_dur[idx] = slow_dur
	p_ttl[idx] = PROJECTILE_TTL
	shots_fired += 1
	return idx

## 타워 발사 판정
func tick_towers(dt: float, buildings, enemies, grid) -> void:
	var b_alive: PackedInt32Array = buildings.alive
	var b_type: PackedInt32Array = buildings.type_id
	var is_tower: PackedInt32Array = buildings.t_is_tower
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
	var e_alive: PackedInt32Array = enemies.alive
	for i in range(buildings.high):
		if b_alive[i] == 0:
			continue
		var t := b_type[i]
		if is_tower[t] == 0:
			continue
		var cd: float = buildings.cooldown[i] - dt
		if cd > 0.0:
			buildings.cooldown[i] = cd
			continue
		var cx: float = buildings.center_x(i)
		var cy: float = buildings.center_y(i)
		var range_val: float = buildings.t_range[t]
		var target: int = grid.nearest(cx, cy, range_val, e_x, e_y, e_alive)
		if target < 0:
			buildings.cooldown[i] = 0.1
			continue
		buildings.cooldown[i] = 1.0 / buildings.t_rate[t]
		var kind: int = buildings.t_proj_kind[t]
		var target_gen: int = enemies.generation[target]
		var tx := e_x[target]
		var ty := e_y[target]
		if kind == KIND_SHELL:
			# 리드 샷: 적 이동을 조금 예측한 지면 지점
			var dist := sqrt((tx - cx) * (tx - cx) + (ty - cy) * (ty - cy))
			var travel: float = dist / buildings.t_proj_speed[t]
			tx += (e_x[target] - enemies.prev_x[target]) * travel * 30.0 * 0.5
			ty += (e_y[target] - enemies.prev_y[target]) * travel * 30.0 * 0.5
			target = -1
		var splash: float = buildings.t_splash[t]
		var slow_dur := 0.0
		if kind == KIND_FROST:
			splash = buildings.t_slow_radius[t]
			slow_dur = buildings.t_slow_dur[t]
		fire(kind, cx, cy, target, target_gen, tx, ty,
			buildings.t_damage[t], buildings.t_proj_speed[t], splash,
			buildings.t_slow[t], slow_dur)

## 발사체 진행과 명중
func tick_projectiles(dt: float, enemies, grid, tick_index: int) -> void:
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
	var e_alive: PackedInt32Array = enemies.alive
	var e_gen: PackedInt32Array = enemies.generation
	for i in range(p_high):
		if p_alive[i] == 0:
			continue
		p_ttl[i] -= dt
		if p_ttl[i] <= 0.0:
			_free_projectile(i)
			continue
		var x := p_x[i]
		var y := p_y[i]
		p_prev_x[i] = x
		p_prev_y[i] = y
		var target := p_target[i]
		var tx := p_tx[i]
		var ty := p_ty[i]
		if target >= 0:
			if e_alive[target] != 0 and e_gen[target] == p_target_gen[i]:
				tx = e_x[target]
				ty = e_y[target]
				p_tx[i] = tx
				p_ty[i] = ty
			else:
				# 대상이 죽음: 마지막 위치로 계속 날아가 소멸
				p_target[i] = -1
				target = -1
		var dx := tx - x
		var dy := ty - y
		var dist := sqrt(dx * dx + dy * dy)
		var step := p_speed[i] * dt
		if dist <= step or dist < 0.05:
			p_x[i] = tx
			p_y[i] = ty
			_on_hit(i, tx, ty, target, enemies, grid, tick_index)
			_free_projectile(i)
			continue
		p_x[i] = x + dx / dist * step
		p_y[i] = y + dy / dist * step

func _on_hit(i: int, x: float, y: float, target: int, enemies, grid, tick_index: int) -> void:
	var kind := p_kind[i]
	if hit_count < SimConfig.MAX_HIT_EVENTS:
		hit_x[hit_count] = x
		hit_y[hit_count] = y
		hit_kind[hit_count] = kind
	hit_count += 1
	match kind:
		KIND_BULLET:
			if target >= 0:
				_apply_damage(target, p_damage[i], enemies, tick_index)
		KIND_SHELL:
			var radius := p_splash[i]
			var n: int = grid.query_circle(x, y, radius, enemies.pos_x, enemies.pos_y, enemies.alive, _query)
			var kills := 0
			var dmg := p_damage[i]
			for k in range(n):
				if _apply_damage(_query[k], dmg, enemies, tick_index):
					kills += 1
			if explosion_count < SimConfig.MAX_EXPLOSION_EVENTS:
				explosion_x[explosion_count] = x
				explosion_y[explosion_count] = y
				explosion_radius[explosion_count] = radius
				explosion_kills[explosion_count] = kills
			explosion_count += 1
		KIND_FROST:
			var radius := p_splash[i]
			var n: int = grid.query_circle(x, y, radius, enemies.pos_x, enemies.pos_y, enemies.alive, _query)
			var dmg := p_damage[i]
			var slow := p_slow[i]
			var dur := p_slow_dur[i]
			for k in range(n):
				var e := _query[k]
				enemies.apply_slow(e, slow, dur)
				_apply_damage(e, dmg, enemies, tick_index)

## 모든 피해는 여기를 거친다. 죽으면 true.
func _apply_damage(enemy: int, amount: float, enemies, tick_index: int) -> bool:
	tick_damage_events += 1
	if enemies.damage(enemy, amount, tick_index):
		tick_kills += 1
		return true
	return false
