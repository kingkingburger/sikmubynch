class_name BuildingData
extends Resource

## 건물 타입별 정의. 시뮬레이션은 시작 시 이 값을 배열 테이블로 펼쳐 인덱스로 조회한다.

enum BuildingType { HQ, BARRICADE, WALL, GUN_TOWER, CANNON_TOWER, FROST_TOWER, FLAME_TOWER, TESLA_TOWER, SNIPER_TOWER }
enum ProjectileKind { NONE, BULLET, SHELL, FROST }
## 발사 방식. PROJECTILE은 발사체를 만들고, 나머지는 즉발이다.
enum AttackMode { PROJECTILE, CHAIN, AREA, BEAM }

@export var building_name: String = ""
@export var building_type: BuildingType = BuildingType.BARRICADE
@export var cost: int = 0
@export var max_hp: float = 100.0
@export var size: int = 1
@export var color: Color = Color.WHITE
@export var height: float = 0.4        # 렌더러가 쓰는 블록 높이 (타일 단위)

# 타워 전용
@export var damage: float = 0.0
@export var attack_rate: float = 0.0   # 초당 발사 수
@export var attack_range: float = 0.0  # 타일
@export var splash_radius: float = 0.0
@export var slow_amount: float = 0.0   # 0.5 = 50% 감속
@export var slow_duration: float = 0.0
@export var slow_radius: float = 0.0
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
@export var projectile_kind: ProjectileKind = ProjectileKind.NONE
@export var projectile_speed: float = 20.0
@export var chain_count: int = 0       # CHAIN: 한 발이 맞히는 최대 적 수
@export var chain_radius: float = 0.0  # CHAIN: 다음 적을 찾는 반경
@export var beam_width: float = 0.0    # BEAM: 관통 판정 반폭 (타일)
@export var prefer_high_hp: bool = false  # 사거리 안에서 HP가 가장 높은 적을 고른다 (저격)

func is_tower() -> bool:
	return attack_rate > 0.0
