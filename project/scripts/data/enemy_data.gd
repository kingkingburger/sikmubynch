class_name EnemyData
extends Resource

enum EnemyType { RUSHER, SPLITTER, EXPLODER, TANK, ELITE_RUSHER, DESTROYER }

@export var enemy_name: String = ""
@export var enemy_type: EnemyType = EnemyType.RUSHER
@export var max_hp: float = 20.0
@export var dps: float = 8.0
@export var speed: float = 3.5
@export var mineral_reward: int = 3
@export var color: Color = Color.RED
@export var scale_factor: float = 1.0
@export var split_count: int = 2
@export var explode_radius: float = 2.5
@export var explode_damage: float = 30.0
