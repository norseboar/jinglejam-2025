class_name ArmyGenerator

## Maximum upgrades allowed per unit (hp + damage combined)
const MAX_UPGRADES_PER_UNIT := 3


static func generate_army(
	roster: Roster,
	target_gold: int,
	max_slots: int,
	forced_units: Array[PackedScene] = [],
	neutral_roster: Roster = null,
	minimum_gold: int = 0
) -> Array[ArmyUnit]:
	"""
	Generate a random army from the given roster.

	Args:
		roster: The faction roster to pick units from
		target_gold: Target gold value for the army (can go slightly negative)
		max_slots: Maximum number of units (based on battlefield slot count)
		forced_units: Units that must appear in the army (drafted first)
		neutral_roster: Optional neutral roster to include in unit pool
		minimum_gold: Minimum gold value (overrides target_gold if higher)

	Returns:
		Array of ArmyUnit sorted by unit priority (highest first)
	"""
	var army: Array[ArmyUnit] = []

	# Apply minimum gold floor
	if minimum_gold > 0:
		target_gold = max(target_gold, minimum_gold)

	var remaining_gold := target_gold

	# Draft forced units first
	for unit_scene in forced_units:
		if unit_scene == null:
			continue

		var army_unit := ArmyUnit.new()
		army_unit.unit_scene = unit_scene
		army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
		army_unit.upgrades = {}
		army_unit.placed = false
		army.append(army_unit)
		remaining_gold -= _get_base_cost(unit_scene)

	var roster_pool := roster.units.duplicate()
	var neutral_pool: Array[PackedScene] = []
	if neutral_roster != null:
		neutral_pool = neutral_roster.units.duplicate()

	var combined_pool: Array[PackedScene] = []
	if not roster_pool.is_empty():
		combined_pool.append_array(roster_pool)
	if not neutral_pool.is_empty():
		combined_pool.append_array(neutral_pool)

	# Track if we've added at least one roster unit
	var has_faction_unit := false
	for army_unit in army:
		if _is_unit_in_roster(army_unit.unit_scene, roster):
			has_faction_unit = true
			break


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
			# Pick a random upgrade slot index (0, 1, or 2) from available upgrades
			var upgrade_slot := _get_random_upgrade_slot(unit_to_upgrade.unit_scene)
			if upgrade_slot >= 0:
				if not unit_to_upgrade.upgrades.has(upgrade_slot):
					unit_to_upgrade.upgrades[upgrade_slot] = 0
				unit_to_upgrade.upgrades[upgrade_slot] += 1
			remaining_gold -= _get_upgrade_cost(unit_to_upgrade.unit_scene)
		else:
			# Add a new unit from the roster
			if combined_pool.is_empty():
				break  # No units available to add

			var unit_scene: PackedScene = null

			# If we need a faction unit and don't have one yet, force pick from roster
			if not has_faction_unit and not roster_pool.is_empty():
				# Pick cheapest roster unit if out of budget
				if remaining_gold <= 0:
					unit_scene = _get_cheapest_unit(roster_pool)
				else:
					# Pick affordable roster unit
					var affordable := _get_affordable_units(roster_pool, remaining_gold)
					if not affordable.is_empty():
						unit_scene = affordable.pick_random()
					else:
						unit_scene = _get_cheapest_unit(roster_pool)
				has_faction_unit = true
			else:
				# Normal unit picking - try to pick affordable unit
				if remaining_gold > 0:
					var affordable := _get_affordable_units(combined_pool, remaining_gold)
					if not affordable.is_empty():
						unit_scene = affordable.pick_random()
					else:
						# No affordable units, but continue if we have space
						unit_scene = combined_pool.pick_random()
				else:
					# Out of gold but need to continue
					unit_scene = combined_pool.pick_random()

			if unit_scene == null:
				break

			var army_unit := ArmyUnit.new()
			army_unit.unit_scene = unit_scene
			army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
			army_unit.upgrades = {}
			army_unit.placed = false
			army.append(army_unit)
			remaining_gold -= _get_base_cost(unit_scene)

			# Track if we added a faction unit
			if _is_unit_in_roster(unit_scene, roster):
				has_faction_unit = true

	
		# Ensure at least one faction unit, even if it means going negative on gold
	if not has_faction_unit and not roster_pool.is_empty():
		var cheapest_faction_unit := _get_cheapest_unit(roster_pool)
		if cheapest_faction_unit != null:
			var army_unit := ArmyUnit.new()
			army_unit.unit_scene = cheapest_faction_unit
			army_unit.unit_type = cheapest_faction_unit.resource_path.get_file().get_basename()
			army_unit.upgrades = {}
			army_unit.placed = false
			army.append(army_unit)
			remaining_gold -= _get_base_cost(cheapest_faction_unit)
			has_faction_unit = true
			
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


static func _get_random_upgrade_slot(unit_scene: PackedScene) -> int:
	"""Get a random upgrade slot index (0-2) from the unit's available upgrades."""
	if unit_scene == null:
		return -1
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return -1
	var available := instance.available_upgrades
	instance.queue_free()
	if available.is_empty():
		return -1
	# Pick a random slot index (0, 1, or 2) that has an upgrade available
	var valid_slots: Array[int] = []
	for i in range(min(3, available.size())):
		if available[i] != null:
			valid_slots.append(i)
	if valid_slots.is_empty():
		return -1
	return valid_slots.pick_random()


static func _compare_by_priority(a: ArmyUnit, b: ArmyUnit) -> bool:
	"""Compare function for sorting - higher priority first."""
	var priority_a := _get_unit_priority(a.unit_scene)
	var priority_b := _get_unit_priority(b.unit_scene)
	return priority_a > priority_b


static func _is_unit_in_roster(unit_scene: PackedScene, roster: Roster) -> bool:
	"""Check if a unit scene belongs to a roster."""
	if unit_scene == null or roster == null:
		return false
	return roster.units.has(unit_scene)


static func _get_affordable_units(pool: Array[PackedScene], max_gold: int) -> Array[PackedScene]:
	"""Get all units from pool that cost <= max_gold."""
	var result: Array[PackedScene] = []
	for unit_scene in pool:
		if _get_base_cost(unit_scene) <= max_gold:
			result.append(unit_scene)
	return result


static func _get_cheapest_unit(pool: Array[PackedScene]) -> PackedScene:
	"""Get the cheapest unit from pool."""
	if pool.is_empty():
		return null

	var cheapest: PackedScene = pool[0]
	var cheapest_cost := _get_base_cost(cheapest)

	for unit_scene in pool:
		var cost := _get_base_cost(unit_scene)
		if cost < cheapest_cost:
			cheapest = unit_scene
			cheapest_cost = cost

	return cheapest


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
