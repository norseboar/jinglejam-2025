extends RefCounted
class_name ArmyUnit

var unit_type: String = ""
var unit_scene: PackedScene = null
var placed: bool = false
var upgrades: Dictionary = {}
var squad_count: int = 1  # Squad size

static func create_from_enemy(enemy_dict: Dictionary) -> ArmyUnit:
	"""Create an ArmyUnit from enemy dictionary data."""
	var army_unit := ArmyUnit.new()
	army_unit.unit_scene = enemy_dict.get("unit_scene")
	army_unit.unit_type = enemy_dict.get("unit_type", "")
	army_unit.upgrades = enemy_dict.get("upgrades", {}).duplicate()
	army_unit.squad_count = enemy_dict.get("squad_count", 1)  # Copy squad_count if present
	army_unit.placed = false
	return army_unit

