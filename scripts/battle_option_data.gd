extends RefCounted
class_name BattleOptionData

## The roster/faction this option represents
var roster: Roster

## The battlefield scene for this option
var battlefield: PackedScene

## The generated army (Array of ArmyUnit)
var army: Array[ArmyUnit]

## The target gold value used to generate this army
var target_gold: int


static func create(p_roster: Roster, p_battlefield: PackedScene, p_army: Array[ArmyUnit], p_target_gold: int) -> BattleOptionData:
	"""Factory method to create a BattleOptionData instance."""
	var data := BattleOptionData.new()
	data.roster = p_roster
	data.battlefield = p_battlefield
	data.army = p_army
	data.target_gold = p_target_gold
	return data
