class_name EnemyData
extends Resource

## 적 타입별 기본 정의. 웨이브 배율은 스폰 시 곱한다.

enum EnemyType { RUSHER, TANK, SPLITTER, MINI }

@export var enemy_name: String = ""
@export var enemy_type: EnemyType = EnemyType.RUSHER
@export var max_hp: float = 20.0
@export var dps: float = 8.0
@export var speed: float = 3.5
@export var mineral_reward: int = 3
@export var color: Color = Color.RED
@export var scale_factor: float = 1.0
@export var split_count: int = 0       # 사망 시 생성할 MINI 수
