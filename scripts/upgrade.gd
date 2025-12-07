extends Resource
class_name UnitUpgrade

enum StatType {
	MAX_HP,
	DAMAGE,
	SPEED,
	ATTACK_RANGE,
	ATTACK_SPEED,
	ARMOR,
	HEAL_AMOUNT
}

@export var stat_type: StatType = StatType.MAX_HP
@export var amount: int = 10
@export var label_text: String = "HP"  # Short abbreviation for UI. Can use \n for multi-line (e.g., "ATK\nCDN", "ATK\nRNG")
