class_name ArmyGenerator

## Maximum upgrades allowed per unit (hp + damage combined)
const MAX_UPGRADES_PER_UNIT := 3


static func generate_army(roster: Roster, target_gold: int, max_slots: int) -> Array[ArmyUnit]:
	"""
	Generate a random army from the given roster.

	Args:
		roster: The faction roster to pick units from
		target_gold: Target gold value for the army (can go slightly negative)
		max_slots: Maximum number of units (based on battlefield slot count)

	Returns:
		Array of ArmyUnit sorted by unit priority (highest first)
	"""
	var army: Array[ArmyUnit] = []
	var remaining_gold := target_gold

	while remaining_gold > 0:
		var can_add := army.size() < max_slots
		var can_upgrade := _has_upgradable_unit(army)

		# Check if we can do anything
		if not can_add and not can_upgrade:
			break  # Stop early - army is full and all units maxed

		# Decide action
		var should_upgrade := false
		if not can_add:
			# Army full, must upgrade
			should_upgrade = true
		elif not can_upgrade or army.is_empty():
			# No upgradable units or empty army, must add new unit
			should_upgrade = false
		else:
			# Roll against upgrade_ratio
			should_upgrade = randf() < roster.upgrade_ratio

		if should_upgrade:
			# Upgrade a random eligible unit
			var upgradable := _get_upgradable_units(army)
			var unit_to_upgrade: ArmyUnit = upgradable.pick_random()
			var upgrade_type: String = ["hp", "damage"].pick_random()
			unit_to_upgrade.upgrades[upgrade_type] = unit_to_upgrade.upgrades.get(upgrade_type, 0) + 1
			remaining_gold -= _get_upgrade_cost(unit_to_upgrade.unit_scene)
		else:
			# Add a new unit from the roster
			var unit_scene: PackedScene = roster.units.pick_random()
			var army_unit := ArmyUnit.new()
			army_unit.unit_scene = unit_scene
			army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
			army_unit.upgrades = {}
			army_unit.placed = false
			army.append(army_unit)
			remaining_gold -= _get_base_cost(unit_scene)

	# Sort by unit priority (highest first) for slot placement
	army.sort_custom(_compare_by_priority)

	return army


static func _has_upgradable_unit(army: Array[ArmyUnit]) -> bool:
	"""Check if any unit in the army can be upgraded."""
	for unit in army:
		if _get_total_upgrades(unit) < MAX_UPGRADES_PER_UNIT:
			return true
	return false


static func _get_upgradable_units(army: Array[ArmyUnit]) -> Array[ArmyUnit]:
	"""Get all units that can still be upgraded."""
	var result: Array[ArmyUnit] = []
	for unit in army:
		if _get_total_upgrades(unit) < MAX_UPGRADES_PER_UNIT:
			result.append(unit)
	return result


static func _get_total_upgrades(army_unit: ArmyUnit) -> int:
	"""Count total upgrades on a unit."""
	var total := 0
	for count in army_unit.upgrades.values():
		total += count
	return total


static func _get_base_cost(unit_scene: PackedScene) -> int:
	"""Get the base_recruit_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.base_recruit_cost
	instance.queue_free()
	return cost


static func _get_upgrade_cost(unit_scene: PackedScene) -> int:
	"""Get the upgrade_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.upgrade_cost
	instance.queue_free()
	return cost


static func _get_unit_priority(unit_scene: PackedScene) -> int:
	"""Get the priority from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var p := instance.priority
	instance.queue_free()
	return p


static func _compare_by_priority(a: ArmyUnit, b: ArmyUnit) -> bool:
	"""Compare function for sorting - higher priority first."""
	var priority_a := _get_unit_priority(a.unit_scene)
	var priority_b := _get_unit_priority(b.unit_scene)
	return priority_a > priority_b


static func calculate_army_value(army: Array[ArmyUnit]) -> int:
	"""Calculate the total gold value of an army."""
	var value := 0
	for army_unit in army:
		if army_unit.unit_scene == null:
			continue
		value += _get_base_cost(army_unit.unit_scene)
		var total_upgrades := _get_total_upgrades(army_unit)
		value += _get_upgrade_cost(army_unit.unit_scene) * total_upgrades
	return value
