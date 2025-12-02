# ✅ Unit Upgrades Implementation Plan

**Goal:** Add a flexible upgrade system where units can have up to 3 upgrades (HP/damage), stored as dictionaries, with visual markers showing upgrade count.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Add upgrade data structures
- [x] Task 2: Set up base unit scene with upgrade markers
- [x] Task 3: Convert unit scenes to inherit from base
- [x] Task 4: Modify spawning to apply upgrades
- [x] Task 5: Fix army persistence between levels

---

## Summary

**Task 1: Add upgrade data structures** — Add `upgrades` dictionary to Unit.gd, EnemyMarker, and ArmyUnit class.

**Task 2: Set up base unit scene with upgrade markers** — Modify `unit.tscn` to include UpgradeMarkers node with 3 marker sprites.

**Task 3: Convert unit scenes to inherit from base** — Convert existing unit scenes to inherit from `unit.tscn` so they get upgrade markers automatically.

**Task 4: Modify spawning to apply upgrades** — Update Game.gd to copy upgrades from source (EnemyMarker/ArmyUnit) to Unit and apply them.

**Task 5: Fix army persistence between levels** — Change army initialization so upgrades persist between levels, only resetting on defeat.

---

## Tasks

### ✅ Task 1: Add upgrade data structures

**Files:** `scripts/unit.gd`, `scripts/enemy_marker.gd`, `scripts/game.gd`

- [x] **Step 1:** Add upgrade property and apply method to `scripts/unit.gd`.

Add after the existing state variables (around line 16):

```gdscript
# Upgrades
var upgrades: Dictionary = {}  # e.g., { "hp": 2, "damage": 1 }
```

Add these new methods at the end of the file (after the `die()` function):

```gdscript
func apply_upgrades() -> void:
	"""Apply upgrade bonuses to base stats and update visual markers."""
	for upgrade_type in upgrades:
		var count: int = upgrades[upgrade_type]
		match upgrade_type:
			"hp":
				max_hp += count
				current_hp = max_hp  # Refresh to new max
			"damage":
				damage += count

	_update_upgrade_markers()


func _update_upgrade_markers() -> void:
	"""Show the appropriate upgrade marker based on total upgrade count."""
	var upgrade_markers := get_node_or_null("UpgradeMarkers")
	if upgrade_markers == null:
		return

	var marker_1 := upgrade_markers.get_node_or_null("Marker1") as Sprite2D
	var marker_2 := upgrade_markers.get_node_or_null("Marker2") as Sprite2D
	var marker_3 := upgrade_markers.get_node_or_null("Marker3") as Sprite2D

	if marker_1 == null or marker_2 == null or marker_3 == null:
		return

	var total := 0
	for count in upgrades.values():
		total += count

	marker_1.visible = (total == 1)
	marker_2.visible = (total == 2)
	marker_3.visible = (total >= 3)
```

- [x] **Step 2:** Add upgrades export to `scripts/enemy_marker.gd`.

Add after the existing `unit_scene` export:

```gdscript
## Upgrades for the enemy unit (e.g., { "hp": 2, "damage": 1 })
@export var upgrades: Dictionary = {}
```

- [x] **Step 3:** Add upgrades property to the `ArmyUnit` class in `scripts/game.gd`.

Find the `ArmyUnit` class (around line 9) and add the upgrades property:

```gdscript
class ArmyUnit:
	var unit_type: String = ""
	var unit_scene: PackedScene = null
	var placed: bool = false
	var upgrades: Dictionary = {}  # NEW
```

**Verify:**

- Ask user to confirm scripts have no syntax errors
- Open Godot and check that EnemyMarker now shows an `upgrades` property in the inspector

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Set up base unit scene with upgrade markers

**Files:** `scenes/units/unit.tscn` (Godot Editor work)

This task requires Godot Editor work. The executor should ask the user to perform these steps.

- [x] **Step 1:** **Godot Editor:** Open `scenes/units/unit.tscn` and add the UpgradeMarkers structure:

1. Open `scenes/units/unit.tscn` in Godot
2. Select the root `Unit` node
3. Add a child Node2D, name it `UpgradeMarkers`
4. Position `UpgradeMarkers` above the unit (e.g., y = -20 to -30)
5. Add three Sprite2D children to UpgradeMarkers:
   - `Marker1` - for 1 upgrade
   - `Marker2` - for 2 upgrades
   - `Marker3` - for 3 upgrades
6. Set all three markers to `visible = false` in the inspector
7. For now, use placeholder textures or colored rectangles (can be improved later with proper art)

**Suggested placeholder setup for each marker:**

- Create a small colored circle or star texture (8x8 or 16x16 pixels)
- Or use Godot's built-in icon: go to Sprite2D > Texture > Quick Load > search for "star" or use `icon.svg`
- Position markers side by side (e.g., x = -8, 0, 8 for the three markers)

The scene structure should look like:

```
Unit (Node2D)
├── AnimatedSprite2D
└── UpgradeMarkers (Node2D)
    ├── Marker1 (Sprite2D) - visible: false
    ├── Marker2 (Sprite2D) - visible: false
    └── Marker3 (Sprite2D) - visible: false
```

- [x] **Step 2:** **Godot Editor:** Save the scene.

**Verify:**

- Open `unit.tscn` and confirm the UpgradeMarkers node exists with three Sprite2D children
- All three markers should be invisible by default

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Convert unit scenes to inherit from base

**Files:** All scenes in `scenes/units/` (Godot Editor work)

This task converts existing unit scenes to inherit from `unit.tscn` so they automatically get the UpgradeMarkers. This is significant Godot Editor work.

- [ ] **Step 1:** **Godot Editor:** Convert `scenes/units/swordsman.tscn` to inherit from `unit.tscn`:

1. Note the current sprite frames resource path: `res://assets/spriteframes/knight.tres`
2. Note the current script: `res://scripts/swordsman.gd`
3. Delete `scenes/units/swordsman.tscn` (or rename to `swordsman_old.tscn` as backup)
4. Right-click on `scenes/units/unit.tscn` → "New Inherited Scene"
5. Save as `scenes/units/swordsman.tscn`
6. In the new inherited scene:
   - Select the root node, rename it to `Swordsman`
   - Select the root node, change the script to `res://scripts/swordsman.gd`
   - Select `AnimatedSprite2D`, change `sprite_frames` to `res://assets/spriteframes/knight.tres`
7. Save the scene

- [ ] **Step 2:** **Godot Editor:** Convert `scenes/units/knight.tscn` using the same process:

- Sprite frames: `res://assets/spriteframes/knight.tres`
- Script: `res://scripts/swordsman.gd`
- Root node name: `Knight`

- [ ] **Step 3:** **Godot Editor:** Convert `scenes/units/squire.tscn` using the same process:

- Sprite frames: `res://assets/spriteframes/squire.tres`
- Script: `res://scripts/swordsman.gd`
- Root node name: `Squire` (note: currently named "Swordsman" in the scene, fix this)

- [ ] **Step 4:** **Godot Editor:** Convert `scenes/units/archer.tscn`:

This one is slightly different because it has the `projectile_scene` export.

1. Note: sprite frames are embedded in the scene (sub_resource), script is `res://scripts/archer.gd`
2. Delete or backup `scenes/units/archer.tscn`
3. Create new inherited scene from `unit.tscn`, save as `scenes/units/archer.tscn`
4. In the new inherited scene:
   - Rename root to `Archer`
   - Change script to `res://scripts/archer.gd`
   - In inspector, set `projectile_scene` to `res://scenes/projectile.tscn`
   - For AnimatedSprite2D: You'll need to recreate the sprite frames or create a `.tres` file for archer sprites
   - If the archer had custom sprite frames, create `res://assets/spriteframes/archer.tres` with the same animations (idle, walk, attack)
5. Save the scene

- [ ] **Step 5:** **Godot Editor:** Convert `scenes/units/ballista.tscn`:

- Sprite frames: `res://assets/spriteframes/ballista.tres`
- Script: `res://scripts/archer.gd`
- Set `projectile_scene` to `res://scenes/projectile.tscn`
- Root node name: `Ballista`

**Verify:**

- Open each converted scene and confirm:
  - It shows "[inherited]" next to the root node name
  - The UpgradeMarkers node appears (inherited from base)
  - The AnimatedSprite2D has the correct sprite frames
  - The correct script is attached
- Run the game and verify units still spawn and animate correctly

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Modify spawning to apply upgrades

**Files:** `scripts/game.gd`

- [x] **Step 1:** Update `_spawn_enemies_from_level()` to copy and apply upgrades.

Find the function (around line 159) and modify it. Replace the section after instantiating the enemy:

```gdscript
func _spawn_enemies_from_level() -> void:
	if current_level == null:
		push_warning("current_level is null in _spawn_enemies_from_level")
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		push_warning("No EnemyMarkers node in level")
		return

	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue

		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			push_error("EnemyMarker at position %s has no unit_scene assigned!" % enemy_marker.global_position)
			return  # Stop spawning if any marker is misconfigured

		var enemy: Unit = enemy_marker.unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit from scene at marker %s!" % enemy_marker.global_position)
			return  # Stop spawning on instantiation failure

		# Configure enemy properties BEFORE adding to scene tree (so _ready() sees correct values)
		enemy.is_enemy = true
		enemy.enemy_container = player_units
		enemy.global_position = enemy_marker.global_position
		enemy.upgrades = enemy_marker.upgrades.duplicate()  # Copy upgrades

		enemy_units.add_child(enemy)
		enemy.apply_upgrades()  # Apply after added to tree
```

- [x] **Step 2:** Update `place_unit_from_army()` to copy and apply upgrades.

Find the function (around line 217) and add upgrade handling. Add these lines before the `slot.set_occupied(true)` line:

```gdscript
	unit.upgrades = army_unit.upgrades.duplicate()  # Copy upgrades
	unit.apply_upgrades()  # Apply after positioning
```

The full function should look like:

```gdscript
func place_unit_from_army(army_index: int, slot: SpawnSlot) -> void:
	"""Place a unit from the army array onto a spawn slot."""
	if slot.is_occupied:
		return

	if army_index < 0 or army_index >= army.size():
		push_error("Invalid army index: %d (army size: %d)" % [army_index, army.size()])
		return

	var army_unit: ArmyUnit = army[army_index]
	if army_unit.placed:
		push_warning("Army unit at index %d already placed" % army_index)
		return

	if army_unit.unit_scene == null:
		push_error("Army unit at index %d has no unit_scene" % army_index)
		return

	var unit: Unit = army_unit.unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit from scene at army index %d" % army_index)
		return

	player_units.add_child(unit)
	unit.is_enemy = false
	unit.enemy_container = enemy_units
	unit.global_position = slot.get_slot_center()
	unit.upgrades = army_unit.upgrades.duplicate()  # Copy upgrades
	unit.apply_upgrades()  # Apply after positioning

	slot.set_occupied(true)

	# Mark army slot as placed
	army_unit.placed = true
	army_unit_placed.emit(army_index)

	# Notify HUD that a unit was placed
	unit_placed.emit(army_unit.unit_type)
```

**Verify:**

- Ask user to:
  - Open a level scene (e.g., `level_01.tscn`)
  - Select an EnemyMarker and set its `upgrades` to `{ "hp": 2 }` in the inspector
  - Run the game
  - The enemy with upgrades should have more HP (verify by counting hits to kill)
  - If upgrade markers are set up, the marker should be visible

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 5: Fix army persistence between levels

**Files:** `scripts/game.gd`

- [x] **Step 1:** Modify `load_level()` to only initialize army when needed.

Find `load_level()` (around line 98) and change the army initialization logic. Replace:

```gdscript
	# Initialize/reset army from starting scenes
	_init_army()
```

With:

```gdscript
	# Only initialize army on first level or after it was cleared (defeat)
	if army.size() == 0:
		_init_army()
	else:
		# Reset placed status for new level (units can be placed again)
		for army_unit in army:
			army_unit.placed = false
```

- [x] **Step 2:** Modify `_on_upgrade_confirmed()` to clear army on defeat.

Find `_on_upgrade_confirmed()` (around line 287) and update the defeat handling:

```gdscript
func _on_upgrade_confirmed(victory: bool) -> void:
	if victory:
		# Advance to next level if not already at the last level
		if current_level_index < level_scenes.size() - 1:
			current_level_index += 1
		else:
			# Completed all levels - restart at level 1
			current_level_index = 0
			army.clear()  # Reset army for new run
	else:
		# On defeat, reset everything
		army.clear()  # Clear army so it reinitializes
		current_level_index = 0

	load_level(current_level_index)
```

**Verify:**

- Ask user to:
  - Play through level 1 and win
  - Check that placed units are available again in level 2 (placed = false reset works)
  - Lose a level and verify the game restarts at level 1 with fresh army

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [x] Units have an `upgrades` dictionary property
- [x] EnemyMarker has an `upgrades` export visible in inspector
- [x] Enemy units spawn with upgrades applied (stats modified)
- [x] Player units spawn with upgrades applied (stats modified)
- [x] Unit scenes inherit from base `unit.tscn` and have UpgradeMarkers nodes
- [x] Army persists between levels (upgrades not lost on victory)
- [x] Army resets on defeat
- [x] No errors in the console
