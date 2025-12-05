# Dynamic Army Generation Implementation Plan

**Goal:** Replace pre-designed battle scenarios with procedurally generated enemy armies based on player's army value.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Update Roster resource
- [ ] Task 2: Create EnemySpawnSlot marker
- [ ] Task 3: Create ArmyGenerator
- [ ] Task 4: Create BattleOptionData class
- [ ] Task 5: Add full_rosters and army value calculation to Game
- [ ] Task 6: Update BattleOption to accept generated data
- [ ] Task 7: Update BattleSelectScreen with new flow
- [ ] Task 8: Update Game spawning logic
- [ ] Task 9: Create example full roster
- [ ] Task 10: Convert a level to use EnemySpawnSlots

---

## Summary

**Task 1: Update Roster resource** — Add team_name, battlefields array, and upgrade_ratio to Roster.

**Task 2: Create EnemySpawnSlot marker** — Simple Marker2D for enemy spawn positions on battlefields.

**Task 3: Create ArmyGenerator** — Static class that generates random armies from a roster given a target gold value.

**Task 4: Create BattleOptionData class** — Data class to hold generated battle option (roster, battlefield, army).

**Task 5: Add full_rosters and army value calculation to Game** — Export full_rosters array, add calculate_army_value() function.

**Task 6: Update BattleOption to accept generated data** — New setup method that accepts BattleOptionData instead of level scene.

**Task 7: Update BattleSelectScreen with new flow** — Pick rosters, generate armies, show options with team names.

**Task 8: Update Game spawning logic** — Support spawning from generated army using EnemySpawnSlots.

**Task 9: Create example full roster** — Create a Humans full roster resource file.

**Task 10: Convert a level to use EnemySpawnSlots** — Replace EnemyMarkers with EnemySpawnSlots in level_01.

---

## Tasks

### Task 1: Update Roster resource

**Files:** `scripts/roster.gd`

- [ ] **Step 1:** Update the Roster resource to add new exports:

```gdscript
extends Resource
class_name Roster

## Display name for this roster/faction (e.g., "Human Army", "Dwarf Clan")
@export var team_name: String = "Unknown Army"

## Array of unit scenes available in this roster.
## For starting rosters: duplicates allowed (e.g., 4 squires to draft from)
## For full rosters: one entry per unit type (used for enemy generation)
@export var units: Array[PackedScene] = []

## Array of battlefield scenes this roster can fight on (full rosters only)
@export var battlefields: Array[PackedScene] = []

## Chance to upgrade an existing unit vs adding a new unit during army generation (0.0 to 1.0)
## Higher values = fewer but more upgraded units. Lower values = more units with fewer upgrades.
@export_range(0.0, 1.0) var upgrade_ratio := 0.3
```

**After this task:** STOP and ask user to verify the file has no errors and the exports appear in the inspector when viewing a Roster resource.

---

### Task 2: Create EnemySpawnSlot marker

**Files:** `scripts/enemy_spawn_slot.gd`

- [ ] **Step 1:** Create a simple Marker2D class for enemy spawn positions:

```gdscript
extends Marker2D
class_name EnemySpawnSlot

## Simple position marker for enemy spawn positions on battlefields.
## Unlike EnemyMarker, this does not specify which unit spawns here.
## The generated army determines what spawns at each slot.
## 
## Place these in order of priority - slot 0 gets the highest priority unit,
## slot 1 gets the second highest, etc.
```

**After this task:** STOP and ask user to verify the file exists with no errors.

---

### Task 3: Create ArmyGenerator

**Files:** `scripts/army_generator.gd`

- [ ] **Step 1:** Create the ArmyGenerator class with helper functions:

```gdscript
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
```

**After this task:** STOP and ask user to verify the file exists with no errors.

---

### Task 4: Create BattleOptionData class

**Files:** `scripts/battle_option_data.gd`

- [ ] **Step 1:** Create a data class to hold generated battle option information:

```gdscript
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
```

**After this task:** STOP and ask user to verify the file exists with no errors.

---

### Task 5: Add full_rosters and army value calculation to Game

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Add the full_rosters export after the existing `starting_roster` export (around line 36):

```gdscript
# Starting roster for draft phase
@export var starting_roster: Roster

## Array of full rosters for enemy army generation
@export var full_rosters: Array[Roster] = []
```

- [ ] **Step 2:** Add a variable to track total gold spent (after the `gold` variable, around line 15):

```gdscript
var gold: int = 0
var total_gold_spent: int = 0  # Track gold spent for army value calculation
```

- [ ] **Step 3:** Update the `spend_gold` function to track spending (around line 85):

```gdscript
func spend_gold(amount: int) -> bool:
	"""Spend gold if available. Returns true if successful, false if insufficient."""
	if gold < amount:
		return false
	gold -= amount
	total_gold_spent += amount  # Track spending
	gold_changed.emit(gold)
	return true
```

- [ ] **Step 4:** Add the army value calculation function (add after `can_afford` function, around line 97):

```gdscript
func calculate_army_value() -> int:
	"""
	Calculate the total value of the player's army.
	Value = current gold + sum of (base_recruit_cost + upgrade_cost * upgrades) for each unit.
	"""
	var value := gold
	
	for army_unit in army:
		if army_unit.unit_scene == null:
			continue
		
		# Get unit costs by instantiating temporarily
		var instance := army_unit.unit_scene.instantiate() as Unit
		if instance == null:
			continue
		
		var base_cost := instance.base_recruit_cost
		var upgrade_cost := instance.upgrade_cost
		instance.queue_free()
		
		# Add base cost
		value += base_cost
		
		# Add upgrade costs (full price, not discounted)
		var total_upgrades := 0
		for count in army_unit.upgrades.values():
			total_upgrades += count
		value += upgrade_cost * total_upgrades
	
	return value
```

- [ ] **Step 5:** Add a variable to store the current generated enemy army (add after `enemies_faced` variable, around line 25):

```gdscript
var enemies_faced: Array = []  # Captured at end of battle for upgrade screen
var current_enemy_army: Array[ArmyUnit] = []  # Generated enemy army for current battle
```

**After this task:** STOP and ask user to verify game.gd has no errors and the new exports appear in the inspector.

---

### Task 6: Update BattleOption to accept generated data

**Files:** `scripts/battle_option.gd`

- [ ] **Step 1:** Add a new variable to store BattleOptionData (after `level_scene` variable, around line 14):

```gdscript
var level_scene: PackedScene = null
var option_data: BattleOptionData = null  # New: holds generated battle data
var is_selected: bool = false
```

- [ ] **Step 2:** Add a new setup method for generated data (after the existing `setup` function, around line 58):

```gdscript
func setup_from_data(index: int, data: BattleOptionData) -> void:
	"""Initialize this option with generated battle data."""
	option_index = index
	option_data = data
	level_scene = data.battlefield  # Store battlefield as level_scene for compatibility
	
	# Set army name from roster
	if army_name_label and data.roster:
		army_name_label.text = data.roster.team_name
	
	# Populate enemy slots from generated army
	_populate_slots_from_army(data.army)


func _populate_slots_from_army(generated_army: Array[ArmyUnit]) -> void:
	"""Populate the UnitSlotGroup with units from the generated army."""
	if enemy_slot_group == null:
		return
	
	var slots := enemy_slot_group.slots
	
	for i in range(slots.size()):
		var slot := slots[i]
		if i < generated_army.size():
			# Create a copy of the ArmyUnit for display
			var army_unit := generated_army[i]
			slot.set_unit(army_unit)
		else:
			slot.set_unit(null)
```

**After this task:** STOP and ask user to verify battle_option.gd has no errors.

---

### Task 7: Update BattleSelectScreen with new flow

**Files:** `scripts/battle_select_screen.gd`

- [ ] **Step 1:** Update the signal to emit BattleOptionData instead of PackedScene (line 4):

```gdscript
signal advance_pressed(option_data: BattleOptionData)
```

- [ ] **Step 2:** Replace the `level_scenes` variable with `option_data_list` (around line 16):

```gdscript
var selected_index: int = 0
var option_data_list: Array[BattleOptionData] = []  # Replaces level_scenes
```

- [ ] **Step 3:** Add a new method to show battle select with generated options (add after `show_battle_select`, around line 47):

```gdscript
func show_battle_select_generated(data_list: Array[BattleOptionData]) -> void:
	"""Show the battle select screen with generated battle options."""
	option_data_list = data_list
	selected_index = 0
	
	# Clear existing options
	_clear_options()
	
	# Create option for each data
	for i in range(data_list.size()):
		var data := data_list[i]
		_add_option_from_data(i, data)
	
	# Pre-select first option
	if options.size() > 0:
		options[0].set_selected(true)
	
	# Show screen
	visible = true


func _add_option_from_data(index: int, data: BattleOptionData) -> void:
	"""Add a battle option from generated data."""
	if battle_option_scene == null or options_container == null:
		push_error("battle_option_scene or options_container not assigned!")
		return
	
	var option := battle_option_scene.instantiate() as BattleOption
	if option == null:
		push_error("Failed to instantiate BattleOption!")
		return
	
	options_container.add_child(option)
	option.setup_from_data(index, data)
	option.selected.connect(_on_option_selected)
	options.append(option)
```

- [ ] **Step 4:** Update the advance button handler to emit BattleOptionData (around line 91):

```gdscript
func _on_advance_button_pressed() -> void:
	"""Handle advance button press."""
	if selected_index < 0 or selected_index >= option_data_list.size():
		push_error("Invalid selected_index: %d" % selected_index)
		return
	
	var selected_data := option_data_list[selected_index]
	advance_pressed.emit(selected_data)
```

**After this task:** STOP and ask user to verify battle_select_screen.gd has no errors.

---

### Task 8: Update Game spawning logic

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Update the `_on_battle_select_advance` signal handler to accept BattleOptionData (around line 491):

```gdscript
func _on_battle_select_advance(option_data: BattleOptionData) -> void:
	"""Handle battle select advance - load the chosen battlefield with generated army."""
	current_enemy_army = option_data.army
	load_level_scene(option_data.battlefield)
```

- [ ] **Step 2:** Add a new function to spawn enemies from the generated army (add after `_spawn_enemies_from_level`, around line 258):

```gdscript
func _spawn_enemies_from_generated_army() -> void:
	"""Spawn enemies from the current_enemy_army using EnemySpawnSlots."""
	if current_level == null:
		push_warning("current_level is null in _spawn_enemies_from_generated_army")
		return
	
	if current_enemy_army.is_empty():
		push_warning("current_enemy_army is empty")
		return
	
	var spawn_slots_node := current_level.get_node_or_null("EnemySpawnSlots")
	if spawn_slots_node == null:
		push_warning("No EnemySpawnSlots node in level - falling back to EnemyMarkers")
		_spawn_enemies_from_level()
		return
	
	# Collect spawn slots
	var spawn_slots: Array[EnemySpawnSlot] = []
	for child in spawn_slots_node.get_children():
		if child is EnemySpawnSlot:
			spawn_slots.append(child)
	
	if spawn_slots.is_empty():
		push_warning("No EnemySpawnSlot nodes found in EnemySpawnSlots")
		return
	
	# Spawn units at slots (army is already sorted by priority)
	for i in range(mini(current_enemy_army.size(), spawn_slots.size())):
		var army_unit := current_enemy_army[i]
		var slot := spawn_slots[i]
		
		if army_unit.unit_scene == null:
			push_error("Generated army unit at index %d has no unit_scene!" % i)
			continue
		
		var enemy: Unit = army_unit.unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit at index %d!" % i)
			continue
		
		# Configure enemy
		enemy.is_enemy = true
		enemy.enemy_container = player_units
		enemy.global_position = slot.global_position
		enemy.upgrades = army_unit.upgrades.duplicate()
		
		enemy_units.add_child(enemy)
		enemy.apply_upgrades()
		
		# Connect death signal
		enemy.enemy_unit_died.connect(_on_enemy_unit_died)
```

- [ ] **Step 3:** Update `load_level_scene` to use the new spawn function when we have a generated army. Find the line `_spawn_enemies_from_level()` (around line 212) and replace it:

```gdscript
	# Spawn enemies - use generated army if available, otherwise use EnemyMarkers
	if not current_enemy_army.is_empty():
		_spawn_enemies_from_generated_army()
	else:
		_spawn_enemies_from_level()
```

- [ ] **Step 4:** Update `_capture_enemies_faced` to work with generated armies (around line 260). Replace the entire function:

```gdscript
func _capture_enemies_faced() -> void:
	"""Capture enemies for the upgrade screen - uses generated army if available."""
	enemies_faced.clear()
	
	# If we have a generated army, use that
	if not current_enemy_army.is_empty():
		for army_unit in current_enemy_army:
			enemies_faced.append({
				"unit_type": army_unit.unit_type,
				"unit_scene": army_unit.unit_scene,
				"upgrades": army_unit.upgrades.duplicate()
			})
		return
	
	# Fallback: read from EnemyMarkers (for non-generated levels)
	if current_level == null:
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return

	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue

		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue

		var unit_type: String = enemy_marker.unit_scene.resource_path.get_file().get_basename()
		enemies_faced.append({
			"unit_type": unit_type,
			"unit_scene": enemy_marker.unit_scene,
			"upgrades": enemy_marker.upgrades.duplicate()
		})
```

- [ ] **Step 5:** Add the battle generation function (add after `calculate_army_value`):

```gdscript
func generate_battle_options() -> Array[BattleOptionData]:
	"""Generate two battle options from random rosters with scaled armies."""
	var result: Array[BattleOptionData] = []
	
	if full_rosters.size() < 2:
		push_error("Need at least 2 full rosters for battle generation!")
		return result
	
	# Calculate player army value
	var army_value := calculate_army_value()
	
	# Generate multipliers
	var low_multiplier := randf_range(0.5, 1.0)
	var high_multiplier := randf_range(1.0, 1.5)
	var low_target := int(army_value * low_multiplier)
	var high_target := int(army_value * high_multiplier)
	
	print("Player army value: %d" % army_value)
	print("Target values - Low: %d (%.1fx), High: %d (%.1fx)" % [low_target, low_multiplier, high_target, high_multiplier])
	
	# Pick 2 random rosters
	var roster_indices: Array[int] = []
	for i in range(full_rosters.size()):
		roster_indices.append(i)
	roster_indices.shuffle()
	
	var roster_a: Roster = full_rosters[roster_indices[0]]
	var roster_b: Roster = full_rosters[roster_indices[1]]
	
	# Randomly assign low/high targets
	var targets := [low_target, high_target]
	targets.shuffle()
	
	# Generate option A
	var battlefield_a: PackedScene = roster_a.battlefields.pick_random() if not roster_a.battlefields.is_empty() else null
	if battlefield_a == null:
		push_error("Roster '%s' has no battlefields!" % roster_a.team_name)
		return result
	
	var slot_count_a := _count_enemy_slots(battlefield_a)
	var army_a := ArmyGenerator.generate_army(roster_a, targets[0], slot_count_a)
	var value_a := ArmyGenerator.calculate_army_value(army_a)
	print("Generated '%s' army worth %d gold (target: %d)" % [roster_a.team_name, value_a, targets[0]])
	result.append(BattleOptionData.create(roster_a, battlefield_a, army_a, targets[0]))
	
	# Generate option B
	var battlefield_b: PackedScene = roster_b.battlefields.pick_random() if not roster_b.battlefields.is_empty() else null
	if battlefield_b == null:
		push_error("Roster '%s' has no battlefields!" % roster_b.team_name)
		return result
	
	var slot_count_b := _count_enemy_slots(battlefield_b)
	var army_b := ArmyGenerator.generate_army(roster_b, targets[1], slot_count_b)
	var value_b := ArmyGenerator.calculate_army_value(army_b)
	print("Generated '%s' army worth %d gold (target: %d)" % [roster_b.team_name, value_b, targets[1]])
	result.append(BattleOptionData.create(roster_b, battlefield_b, army_b, targets[1]))
	
	return result


func _count_enemy_slots(battlefield_scene: PackedScene) -> int:
	"""Count the number of EnemySpawnSlots in a battlefield scene."""
	if battlefield_scene == null:
		return 6  # Default fallback
	
	var instance := battlefield_scene.instantiate()
	if instance == null:
		return 6
	
	var count := 0
	var spawn_slots_node := instance.get_node_or_null("EnemySpawnSlots")
	if spawn_slots_node:
		for child in spawn_slots_node.get_children():
			if child is EnemySpawnSlot:
				count += 1
	
	instance.queue_free()
	return count if count > 0 else 6  # Fallback to 6 if no slots found
```

- [ ] **Step 6:** Update `_on_upgrade_confirmed` to use generated battle options instead of level pools (around line 503). Find the section that shows battle select (after `current_level_index += 1`) and replace it:

```gdscript
func _on_upgrade_confirmed(victory: bool) -> void:
	# Hide upgrade screen
	hud.hide_upgrade_screen()
	
	if victory:
		# Clear the generated army for next battle
		current_enemy_army.clear()
		
		# Advance level index (used for tracking progress)
		current_level_index += 1
		
		# Clear old level and units before showing battle select
		_clear_all_units()
		if current_level:
			current_level.queue_free()
			current_level = null
		
		# Generate new battle options
		var options := generate_battle_options()
		if options.size() >= 2:
			hud.show_battle_select_generated(options)
		else:
			push_error("Failed to generate battle options!")
	else:
		# On defeat, reset everything
		current_enemy_army.clear()
		army.clear()
		current_level_index = 0
		total_gold_spent = 0
		gold = starting_gold
		gold_changed.emit(gold)
		is_draft_mode = true
		_show_draft_screen()
```

- [ ] **Step 7:** Clear generated army in `_on_draft_complete` (around line 496):

```gdscript
func _on_draft_complete() -> void:
	"""Handle draft completion - start first battle directly."""
	is_draft_mode = false
	current_enemy_army.clear()  # Ensure clean state
	# Load first level directly (no level select)
	load_level(0)
```

**After this task:** STOP and ask user to verify game.gd has no errors.

---

### Task 9: Create example full roster

**Files:** `units/rosters/full_rosters/humans_full.tres` (Godot editor)

- [ ] **Step 1:** **Godot Editor:** Create the humans full roster resource:
  1. Right-click on `res://units/rosters/full_rosters/`
  2. Create New > Resource
  3. Select "Roster" from the list
  4. Save as `humans_full.tres`

- [ ] **Step 2:** **Godot Editor:** Configure the roster:
  1. Select `humans_full.tres`
  2. Set `Team Name` to "Human Army"
  3. Set `Upgrade Ratio` to 0.3 (or your preferred value)
  4. In the `Units` array, add ONE of each human unit (no duplicates):
     - `res://units/humans/squire.tscn`
     - `res://units/humans/knight.tscn`
     - `res://units/humans/ballista.tscn`
     - (Add any other human units that exist)
  5. Leave `Battlefields` empty for now (we'll add after Task 10)
  6. Save the resource

- [ ] **Step 3:** **Godot Editor:** Add the roster to Game node:
  1. Open `scenes/game.tscn`
  2. Select the Game node
  3. In the Inspector, find "Full Rosters" array
  4. Add `humans_full.tres` to the array
  5. Save the scene

**After this task:** STOP and ask user to verify the roster is created and assigned to Game.

---

### Task 10: Convert a level to use EnemySpawnSlots

**Files:** `levels/level_01.tscn` (Godot editor)

- [ ] **Step 1:** **Godot Editor:** Add EnemySpawnSlots container to level_01:
  1. Open `levels/level_01.tscn`
  2. Add a new Node2D as a child of the root LevelRoot node
  3. Name it "EnemySpawnSlots"

- [ ] **Step 2:** **Godot Editor:** Add EnemySpawnSlot markers:
  1. Select the EnemySpawnSlots node
  2. Add EnemySpawnSlot nodes as children (Marker2D with script)
  3. Position them at the same locations as the existing EnemyMarker nodes
  4. Add as many slots as you want enemies to be able to spawn (e.g., 6 slots)
  5. Order matters: slot 0 (first child) gets highest priority unit

- [ ] **Step 3:** **Godot Editor:** Optionally add a visual sprite to EnemySpawnSlot for editor visibility:
  1. You can add a Sprite2D child to each EnemySpawnSlot
  2. Use a simple marker icon
  3. These are just for editor placement help

- [ ] **Step 4:** **Godot Editor:** Add level_01 to the humans roster battlefields:
  1. Open `units/rosters/full_rosters/humans_full.tres`
  2. In the `Battlefields` array, add `res://levels/level_01.tscn`
  3. Save the resource

- [ ] **Step 5:** **Godot Editor:** Create a second full roster for testing (we need at least 2):
  1. Duplicate `humans_full.tres` 
  2. Rename to `humans_full_2.tres` (temporary for testing)
  3. Change `Team Name` to "Human Reserve"
  4. Keep the same units and battlefields
  5. Add this roster to Game's `Full Rosters` array

**After this task:** STOP and ask user to:
1. Run the game
2. Complete the draft phase
3. Win the first battle
4. Verify the battle select screen shows two generated options with team names
5. Verify selecting an option loads the battlefield with a generated enemy army

---

## Exit Criteria

- [ ] Roster resource has team_name, battlefields, and upgrade_ratio exports
- [ ] EnemySpawnSlot class exists and can be placed in levels
- [ ] ArmyGenerator creates random armies within target gold values
- [ ] Battle select screen shows team names from rosters (not level army_name)
- [ ] Generated armies spawn at EnemySpawnSlot positions
- [ ] Console logs "Player army value: X" when generating options
- [ ] Two battle options are shown with different rosters
- [ ] Enemy army composition varies between battles
- [ ] No errors in the console during normal gameplay

