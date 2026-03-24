class_name UnitData
extends Resource

enum UnitType { SOLDIER, ARCHER, TANKER, BOMBER }

@export var unit_name: String = ""
@export var unit_type: UnitType = UnitType.SOLDIER
@export var max_hp: float = 80.0
@export var dps: float = 10.0
@export var speed: float = 4.0
@export var attack_range: float = 1.2
@export var color: Color = Color.BLUE
