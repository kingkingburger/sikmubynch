class_name BuildingData
extends Resource

@export var building_name: String = ""
@export var cost: int = 0
@export var max_hp: float = 100.0
@export var size: Vector2i = Vector2i(1, 1)
@export var color: Color = Color.WHITE
@export var dps: float = 0.0
@export var attack_range: float = 0.0
@export var attack_speed: float = 1.0
@export var trait_type: int = -1  # TraitData.TraitType, -1 = none
@export var mineral_per_sec: float = 0.0  # For miner
@export var buff_range: float = 0.0  # For buff tower
@export var buff_dps_mult: float = 0.0  # For buff tower
