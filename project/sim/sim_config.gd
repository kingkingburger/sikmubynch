extends RefCounted

## 시뮬레이션 전역 상수. Node를 참조하지 않는다.
## 맵·틱·배열 상한은 여기서만 바꾼다.

const MAP_SIZE := 128
const CELLS := MAP_SIZE * MAP_SIZE
const TICK_RATE := 30
const TICK_DT := 1.0 / 30.0

const MAX_ENEMIES := 8192
const MAX_PROJECTILES := 4096
const MAX_BUILDINGS := 2048

const HQ_SIZE := 3
const HQ_MIN_TILE := 62            # HQ 좌상단 타일 (62..64)
const HQ_CENTER := Vector2(63.5, 63.5)

const FLOW_RECALC_DELAY_TICKS := 8  # 건설 후 Flow Field 재계산까지 대기 틱 (약 0.27초)

const START_MINERALS := 150
const BASE_INCOME_PER_SEC := 2.0   # 처치 외 기본 수입. 손이 멈추지 않게 하는 최소치
const DEMOLISH_REFUND := 0.5

## 렌더러·게임 필이 소비하는 틱 이벤트 상한. 넘치면 개수만 센다.
const MAX_DEATH_EVENTS := 1024
const MAX_HIT_EVENTS := 256
const MAX_EXPLOSION_EVENTS := 128

static func tile_index(tx: int, ty: int) -> int:
	return ty * MAP_SIZE + tx

static func in_bounds(tx: int, ty: int) -> bool:
	return tx >= 0 and tx < MAP_SIZE and ty >= 0 and ty < MAP_SIZE
