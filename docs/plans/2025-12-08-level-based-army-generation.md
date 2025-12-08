# Level-Based Army Generation Implementation Plan

**Goal:** Replace hardcoded army generation parameters with configurable level resources that control difficulty multipliers, forced units, neutral rosters, and music selection.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Create LevelData resource class
- [ ] Task 2: Update Roster with intense music field
- [ ] Task 3: Update ArmyGenerator with new drafting logic
- [ ] Task 4: Update Game.gd to use levels array
- [ ] Task 5: Update music playing logic
- [ ] Task 6: Remove old neutral unlock logic

---

## Summary

**Task 1: Create LevelData resource class** — Define the resource structure that holds per-level configuration (multipliers, forced units, neutral roster, music flag).

**Task 2: Update Roster with intense music field** — Add optional intense music variant field to Roster resource.

**Task 3: Update ArmyGenerator with new drafting logic** — Implement forced units, minimum gold floor, faction unit requirement, and cheaper unit picking when low on gold.

**Task 4: Update Game.gd to use levels array** — Replace total_levels counter with LevelData array and pass level data through battle generation.

**Task 5: Update music playing logic** — Check level's use_intense_music flag and play appropriate track.

**Task 6: Remove old neutral unlock logic** — Delete the level-threshold-based neutral unlock system.

---

## Tasks

### Task 1: Create LevelData resource class

**Files:** `scripts/level_data.gd`

- [ ] **Step 1:** Create `scripts/level_data.gd` with the following structure:

```gdscript
extends Resource
class_name LevelData

## Low multiplier for enemy army value (e.g., 0.8 = 80% of player army value)
@export var low_multiplier: float = 0.8

## High multiplier for enemy army value (e.g., 1.2 = 120% of player army value)
@export var high_multiplier: float = 1.2

## Minimum gold value for enemy armies (overrides multiplier if needed)
@export var minimum_gold: int = 0

## Units that must appear in both battle options (drafted first)
@export var forced_units: Array[PackedScene] = []

## Optional neutral roster to include in unit pool
@export var neutral_roster: Roster = null

## If true, use intense music variant from enemy roster
@export var use_intense_music: bool = false
```

**Verify:** Ask user to confirm the file was created and check for any syntax errors.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Update Roster with intense music field

**Files:** `scripts/roster.gd`

- [ ] **Step 1:** Find the existing `battle_music` export variable in `scripts/roster.gd`

- [ ] **Step 2:** Add the intense music field immediately after `battle_music`:

```gdscript
## Intense variant battle music (used when level specifies use_intense_music)
@export var battle_music_intense: AudioStream = null
```

**Verify:** Ask user to open a Roster resource in the Godot editor and confirm the new `battle_music_intense` field appears in the inspector.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update ArmyGenerator with new drafting logic

**Files:** `scripts/army_generator.gd`

- [ ] **Step 1:** Update the `generate_army()` function signature:

Replace:
```gdscript
static func generate_army(
	roster: Roster,
	target_gold: int,
	max_slots: int,
	neutral_units: Array[PackedScene] = [],
	neutral_first_pick_chance: float = 0.0
) -> Array[ArmyUnit]:
```

With:
```gdscript
static func generate_army(
	roster: Roster,
	target_gold: int,
	max_slots: int,
	forced_units: Array[PackedScene] = [],
	neutral_roster: Roster = null,
	minimum_gold: int = 0
) -> Array[ArmyUnit]:
```

- [ ] **Step 2:** Update the function docstring to reflect new parameters:

```gdscript
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
```

- [ ] **Step 3:** At the start of the function body, apply minimum gold floor:

```gdscript
var army: Array[ArmyUnit] = []

# Apply minimum gold floor
if minimum_gold > 0:
	target_gold = max(target_gold, minimum_gold)

var remaining_gold := target_gold
```

- [ ] **Step 4:** Draft forced units before the main loop:

```gdscript
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
```

- [ ] **Step 5:** Build unit pool from roster + optional neutral roster:

Replace the old pool building code with:
```gdscript
# Build unit pool
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
```

- [ ] **Step 6:** Add helper function to check if a unit belongs to a roster:

```gdscript
static func _is_unit_in_roster(unit_scene: PackedScene, roster: Roster) -> bool:
	"""Check if a unit scene belongs to a roster."""
	if unit_scene == null or roster == null:
		return false
	return roster.units.has(unit_scene)
```

- [ ] **Step 7:** Update the main drafting loop to handle cheaper unit picking and faction requirement:

Replace the "else" block (adding new unit) in the main while loop with:
```gdscript
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
```

- [ ] **Step 8:** Add helper functions for affordable and cheapest unit selection:

```gdscript
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
```

**Verify:** Ask user to check for any syntax errors or linter issues in `scripts/army_generator.gd`.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Update Game.gd to use levels array

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Find and replace the `total_levels` export variable:

Replace:
```gdscript
## Total number of levels/battles in the game (used for completion tracking)
@export var total_levels: int = 10
```

With:
```gdscript
## Array of level data resources (defines difficulty progression)
@export var levels: Array[LevelData] = []
```

- [ ] **Step 2:** Update all references to `total_levels` to use `levels.size()`:

Find these locations and update:
- In `show_battle_end_modal()` call: `hud.show_battle_end_modal(victory, current_level_index + 1, levels.size())`
- In `_on_upgrade_confirmed()`: `if current_level_index >= levels.size() - 1:`

- [ ] **Step 3:** Remove the old neutral unlock logic:

Delete the entire `_get_neutral_units_for_current_level()` function.

- [ ] **Step 4:** Remove the `neutral_min_level` export variable (search for it and delete).

- [ ] **Step 5:** Update `generate_battle_options()` to use level data:

Replace the hardcoded multiplier logic:
```gdscript
# Old code to remove:
var low_multiplier := randf_range(0.5, 1.0)
var high_multiplier := randf_range(1.0, 1.5)
var low_target := int(army_value * low_multiplier)
var high_target := int(army_value * high_multiplier)
```

With:
```gdscript
# Get current level data
if current_level_index < 0 or current_level_index >= levels.size():
	push_error("Invalid current_level_index: %d (levels size: %d)" % [current_level_index, levels.size()])
	return result

var level_data := levels[current_level_index]

# Calculate target values using level multipliers
var low_target := int(army_value * level_data.low_multiplier)
var high_target := int(army_value * level_data.high_multiplier)

# Apply minimum gold floor
low_target = max(low_target, level_data.minimum_gold)
high_target = max(high_target, level_data.minimum_gold)
```

- [ ] **Step 6:** Update the two `ArmyGenerator.generate_army()` calls in `generate_battle_options()`:

Replace:
```gdscript
var neutral_units := _get_neutral_units_for_current_level()
var neutral_first_pick_chance := 0.66 if not neutral_units.is_empty() else 0.0
```

With nothing (delete those lines).

Replace:
```gdscript
var army_a := ArmyGenerator.generate_army(roster_a, targets[0], slot_count_a, neutral_units, neutral_first_pick_chance)
```

With:
```gdscript
var army_a := ArmyGenerator.generate_army(roster_a, targets[0], slot_count_a, level_data.forced_units, level_data.neutral_roster, level_data.minimum_gold)
```

Replace:
```gdscript
var army_b := ArmyGenerator.generate_army(roster_b, targets[1], slot_count_b, neutral_units, neutral_first_pick_chance)
```

With:
```gdscript
var army_b := ArmyGenerator.generate_army(roster_b, targets[1], slot_count_b, level_data.forced_units, level_data.neutral_roster, level_data.minimum_gold)
```

- [ ] **Step 7:** Update `_on_draft_complete()` to use first level data:

After the battlefield selection code, replace the neutral logic:
```gdscript
# Old code to remove:
var neutral_units := _get_neutral_units_for_current_level()
var neutral_first_pick_chance := 0.66 if not neutral_units.is_empty() else 0.0
var enemy_army := ArmyGenerator.generate_army(roster, target_value, slot_count, neutral_units, neutral_first_pick_chance)
```

With:
```gdscript
# Use first level data
if levels.is_empty():
	push_error("No levels defined in levels array!")
	return

var level_data := levels[0]
target_value = max(target_value, level_data.minimum_gold)

var enemy_army := ArmyGenerator.generate_army(roster, target_value, slot_count, level_data.forced_units, level_data.neutral_roster, level_data.minimum_gold)
```

**Verify:** Ask user to check for any syntax errors or linter issues in `scripts/game.gd`.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Update music playing logic

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Update `_play_battle_music()` function:

Replace the entire function body with:
```gdscript
func _play_battle_music() -> void:
	"""Play the battle music for the current enemy roster."""
	if not current_enemy_roster:
		push_warning("No current_enemy_roster set")
		return
	
	# Check if we have valid level data
	if current_level_index < 0 or current_level_index >= levels.size():
		push_warning("Invalid level index for music selection")
		# Fallback to normal music
		if current_enemy_roster.battle_music:
			MusicManager.play_track(current_enemy_roster.battle_music)
		return
	
	var level_data := levels[current_level_index]
	var track: AudioStream = null
	
	# Check if we should use intense music
	if level_data.use_intense_music and current_enemy_roster.battle_music_intense:
		track = current_enemy_roster.battle_music_intense
	else:
		track = current_enemy_roster.battle_music
	
	if track:
		MusicManager.play_track(track)
	else:
		push_warning("No battle music available for current roster")
```

**Verify:** Ask user to check for any syntax errors in the updated function.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 6: Remove old neutral unlock logic

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Verify that `_get_neutral_units_for_current_level()` was already deleted in Task 4 Step 3.

- [ ] **Step 2:** Verify that `neutral_min_level` export variable was already deleted in Task 4 Step 4.

- [ ] **Step 3:** Search the entire `scripts/game.gd` file for any remaining references to:
  - `neutral_min_level`
  - `_get_neutral_units_for_current_level`
  - `neutral_first_pick_chance`

- [ ] **Step 4:** If any references remain, remove them or update them to use the new level data system.

**Verify:** Ask user to search the codebase for "neutral_min_level" and "neutral_first_pick_chance" to confirm no references remain.

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] LevelData resource class exists and can be instantiated in Godot editor
- [ ] Roster resources show the `battle_music_intense` field in inspector
- [ ] ArmyGenerator drafts forced units before normal units
- [ ] ArmyGenerator respects minimum gold floor
- [ ] ArmyGenerator ensures at least one faction unit in final army
- [ ] ArmyGenerator picks cheaper units when low on gold instead of going into debt unnecessarily
- [ ] Game.gd has `levels` array instead of `total_levels` counter
- [ ] generate_battle_options() uses level data multipliers and forced units
- [ ] Music system checks `use_intense_music` flag and plays appropriate track
- [ ] Old neutral unlock threshold logic is completely removed
- [ ] No syntax errors or linter warnings in modified files
- [ ] User can create LevelData resources in Godot and assign them to Game node

