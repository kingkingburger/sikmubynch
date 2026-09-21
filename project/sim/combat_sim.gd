extends RefCounted

## Combat Sim — 타워 타겟팅, 발사체 진행, 피해·감속 적용, 처치 집계.
## 발사 방식 4가지: PROJECTILE(발사체), CHAIN(연쇄 즉발), AREA(반경 즉발), BEAM(직선 관통 즉발).
## 시너지 배율은 없다. 피해는 _apply_damage 한곳을 거친다(재도입 시 배율을 여기에 끼운다).

const SimConfig := preload("res://sim/sim_config.gd")

const MAX := SimConfig.MAX_PROJECTILES
const KIND_NONE := 0
const KIND_BULLET := 1
const KIND_SHELL := 2
const KIND_FROST := 3
const MODE_PROJECTILE := 0
const MODE_CHAIN := 1
const MODE_AREA := 2
const MODE_BEAM := 3
const PROJECTILE_TTL := 3.0
const QUERY_CAP := 512
const MAX_BOLTS := 256      # 연쇄 번개 선분 이벤트 상한 (틱당)
const MAX_BEAMS := 64
const MAX_FLAMES := 128

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
# 즉발 무기 표현용 선분: 연쇄 번개(볼트), 저격 빔, 화염(타워→목표 방향)
var bolt_count: int = 0
var bolt_x0: PackedFloat32Array
var bolt_y0: PackedFloat32Array
var bolt_x1: PackedFloat32Array
var bolt_y1: PackedFloat32Array
var beam_count: int = 0
var beam_x0: PackedFloat32Array
var beam_y0: PackedFloat32Array
var beam_x1: PackedFloat32Array
var beam_y1: PackedFloat32Array
var beam_kills: PackedInt32Array
var flame_count: int = 0
var flame_x: PackedFloat32Array
var flame_y: PackedFloat32Array
var flame_tx: PackedFloat32Array
var flame_ty: PackedFloat32Array
var flame_radius: PackedFloat32Array

var _query: PackedInt32Array
var _chain_visited: PackedInt32Array

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
	bolt_x0 = PackedFloat32Array()
	bolt_x0.resize(MAX_BOLTS)
	bolt_y0 = PackedFloat32Array()
	bolt_y0.resize(MAX_BOLTS)
	bolt_x1 = PackedFloat32Array()
	bolt_x1.resize(MAX_BOLTS)
	bolt_y1 = PackedFloat32Array()
	bolt_y1.resize(MAX_BOLTS)
	beam_x0 = PackedFloat32Array()
	beam_x0.resize(MAX_BEAMS)
	beam_y0 = PackedFloat32Array()
	beam_y0.resize(MAX_BEAMS)
	beam_x1 = PackedFloat32Array()
	beam_x1.resize(MAX_BEAMS)
	beam_y1 = PackedFloat32Array()
	beam_y1.resize(MAX_BEAMS)
	beam_kills = PackedInt32Array()
	beam_kills.resize(MAX_BEAMS)
	flame_x = PackedFloat32Array()
	flame_x.resize(MAX_FLAMES)
	flame_y = PackedFloat32Array()
	flame_y.resize(MAX_FLAMES)
	flame_tx = PackedFloat32Array()
	flame_tx.resize(MAX_FLAMES)
	flame_ty = PackedFloat32Array()
	flame_ty.resize(MAX_FLAMES)
	flame_radius = PackedFloat32Array()
	flame_radius.resize(MAX_FLAMES)
	_query = PackedInt32Array()
	_query.resize(QUERY_CAP)
	_chain_visited = PackedInt32Array()
	_chain_visited.resize(16)
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
	bolt_count = 0
	beam_count = 0
	flame_count = 0

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
func tick_towers(dt: float, buildings, enemies, grid, tick_index: int) -> void:
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
		var mode: int = buildings.t_mode[t]
		if mode == MODE_AREA:
			# 반경 안 전부 즉시 피해. 대상이 없으면 짧게 쉰다.
			var n: int = grid.query_circle(cx, cy, range_val, e_x, e_y, e_alive, _query)
			if n == 0:
				buildings.cooldown[i] = 0.1
				continue
			buildings.cooldown[i] = 1.0 / buildings.t_rate[t]
			buildings.last_fire_tick[i] = tick_index
			_fire_area(i, cx, cy, range_val, n, buildings.t_damage[t], enemies, tick_index)
			continue
		var target := -1
		if buildings.t_prefer_hp[t] != 0:
			target = _highest_hp_in_range(cx, cy, range_val, enemies, grid)
		else:
			target = grid.nearest(cx, cy, range_val, e_x, e_y, e_alive)
		if target < 0:
			buildings.cooldown[i] = 0.1
			continue
		buildings.cooldown[i] = 1.0 / buildings.t_rate[t]
		buildings.last_fire_tick[i] = tick_index
		shots_fired += 1
		match mode:
			MODE_CHAIN:
				_fire_chain(cx, cy, target, buildings.t_chain[t], buildings.t_chain_radius[t],
					buildings.t_damage[t], enemies, grid, tick_index)
			MODE_BEAM:
				_fire_beam(cx, cy, target, range_val, buildings.t_beam_width[t],
					buildings.t_damage[t], enemies, grid, tick_index)
			_:
				shots_fired -= 1   # fire()가 다시 센다
				_fire_projectile(i, t, cx, cy, target, buildings, enemies)

func _fire_projectile(i: int, t: int, cx: float, cy: float, target: int, buildings, enemies) -> void:
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
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

## 사거리 안에서 HP가 가장 높은 적 (저격 타워). 없으면 -1.
func _highest_hp_in_range(cx: float, cy: float, radius: float, enemies, grid) -> int:
	var n: int = grid.query_circle(cx, cy, radius, enemies.pos_x, enemies.pos_y, enemies.alive, _query)
	var best := -1
	var best_hp := -1.0
	var hp: PackedFloat32Array = enemies.hp
	for k in range(n):
		var e := _query[k]
		if hp[e] > best_hp:
			best_hp = hp[e]
			best = e
	return best

## 연쇄 번개: 첫 대상에서 chain_radius 안의 아직 안 맞은 적으로 최대 chain_count번 튄다.
func _fire_chain(cx: float, cy: float, first: int, chain_count: int, chain_radius: float,
		damage: float, enemies, grid, tick_index: int) -> void:
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
	var e_alive: PackedInt32Array = enemies.alive
	var visited := 0
	var cur := first
	var px := cx
	var py := cy
	var hops := maxi(chain_count, 1)
	while cur >= 0 and visited < hops:
		var hx := e_x[cur]
		var hy := e_y[cur]
		_push_bolt(px, py, hx, hy)
		_push_hit(hx, hy, KIND_BULLET)
		if visited < _chain_visited.size():
			_chain_visited[visited] = cur
		visited += 1
		_apply_damage(cur, damage, enemies, tick_index)
		px = hx
		py = hy
		# 다음 대상: 반경 안에서 가장 가까운 미방문 적 (죽은 적은 alive=0이라 자동 제외)
		var n: int = grid.query_circle(px, py, chain_radius, e_x, e_y, e_alive, _query)
		var best := -1
		var best_d := chain_radius * chain_radius + 1.0
		for k in range(n):
			var e := _query[k]
			var seen := false
			for v in range(mini(visited, _chain_visited.size())):
				if _chain_visited[v] == e:
					seen = true
					break
			if seen:
				continue
			var dx := e_x[e] - px
			var dy := e_y[e] - py
			var d := dx * dx + dy * dy
			if d < best_d:
				best_d = d
				best = e
		cur = best

## 저격 빔: 타워에서 대상을 지나 사거리 끝까지 직선. 반폭 안의 적을 전부 관통한다.
func _fire_beam(cx: float, cy: float, target: int, range_val: float, half_width: float,
		damage: float, enemies, grid, tick_index: int) -> void:
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
	var dx := e_x[target] - cx
	var dy := e_y[target] - cy
	var len := sqrt(dx * dx + dy * dy)
	if len < 0.001:
		dx = 1.0
		dy = 0.0
		len = 1.0
	var ux := dx / len
	var uy := dy / len
	var ex := cx + ux * range_val
	var ey := cy + uy * range_val
	# 선분 중점 원으로 후보를 모은 뒤 선분 거리로 거른다
	var mx := (cx + ex) * 0.5
	var my := (cy + ey) * 0.5
	var n: int = grid.query_circle(mx, my, range_val * 0.5 + half_width, e_x, e_y, enemies.alive, _query)
	var kills := 0
	var w2 := half_width * half_width
	for k in range(n):
		var e := _query[k]
		var rx := e_x[e] - cx
		var ry := e_y[e] - cy
		var along := rx * ux + ry * uy
		if along < 0.0 or along > range_val:
			continue
		var perp_x := rx - ux * along
		var perp_y := ry - uy * along
		if perp_x * perp_x + perp_y * perp_y > w2:
			continue
		_push_hit(e_x[e], e_y[e], KIND_BULLET)
		if _apply_damage(e, damage, enemies, tick_index):
			kills += 1
	if beam_count < MAX_BEAMS:
		beam_x0[beam_count] = cx
		beam_y0[beam_count] = cy
		beam_x1[beam_count] = ex
		beam_y1[beam_count] = ey
		beam_kills[beam_count] = kills
	beam_count += 1

## 화염: 반경 안 전부 피해. 표현용으로 가장 가까운 적 방향을 남긴다.
func _fire_area(i: int, cx: float, cy: float, radius: float, n: int, damage: float, enemies, tick_index: int) -> void:
	var e_x: PackedFloat32Array = enemies.pos_x
	var e_y: PackedFloat32Array = enemies.pos_y
	var near := -1
	var near_d := 1.0e9
	for k in range(n):
		var e := _query[k]
		var dx := e_x[e] - cx
		var dy := e_y[e] - cy
		var d := dx * dx + dy * dy
		if d < near_d:
			near_d = d
			near = e
	var tx := cx
	var ty := cy
	if near >= 0:
		tx = e_x[near]
		ty = e_y[near]
	for k in range(n):
		_apply_damage(_query[k], damage, enemies, tick_index)
	if flame_count < MAX_FLAMES:
		flame_x[flame_count] = cx
		flame_y[flame_count] = cy
		flame_tx[flame_count] = tx
		flame_ty[flame_count] = ty
		flame_radius[flame_count] = radius
	flame_count += 1

func _push_bolt(x0: float, y0: float, x1: float, y1: float) -> void:
	if bolt_count < MAX_BOLTS:
		bolt_x0[bolt_count] = x0
		bolt_y0[bolt_count] = y0
		bolt_x1[bolt_count] = x1
		bolt_y1[bolt_count] = y1
	bolt_count += 1

func _push_hit(x: float, y: float, kind: int) -> void:
	if hit_count < SimConfig.MAX_HIT_EVENTS:
		hit_x[hit_count] = x
		hit_y[hit_count] = y
		hit_kind[hit_count] = kind
	hit_count += 1

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
	_push_hit(x, y, kind)
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
