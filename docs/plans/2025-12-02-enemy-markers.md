# ✅ Enemy Markers Implementation Plan

**Goal:** Configure enemy units per level by assigning unit scenes to individual enemy markers, replacing the global enemy_scene system.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Create EnemyMarker script
- [x] Task 2: Update Game script to use marker unit scenes
- [x] Task 3: Remove enemy files and references
- [x] Task 4: Update level scenes (manual editor work)

---

## Summary

**Task 1: Create EnemyMarker script** — Create a custom Marker2D script with unit_scene export property for per-marker enemy configuration.

**Task 2: Update Game script to use marker unit scenes** — Modify `_spawn_enemies_from_level()` to read unit_scene from each EnemyMarker and remove the global enemy_scene export.

**Task 3: Remove enemy files and references** — Delete the old enemy.gd script and enemy.tscn scene, and remove enemy_scene assignment from game.tscn.

**Task 4: Update level scenes (manual editor work)** — Attach EnemyMarker script to Marker2D nodes in level scenes and assign unit scenes in the inspector.

---

## Tasks

### ✅ Task 1: Create EnemyMarker script

**Files:** `scripts/enemy_marker.gd`

- [x] **Step 1:** Create `scripts/enemy_marker.gd` with the following content:

```gdscript
extends Marker2D
class_name EnemyMarker

## The unit scene to spawn at this marker position
@export var unit_scene: PackedScene
```

**Verify:**

- Ask user to confirm:
  - `scripts/enemy_marker.gd` exists
  - The script has no syntax errors (Godot editor shows no red errors)
  - The class_name `EnemyMarker` is recognized (can be used in type checks)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Update Game script to use marker unit scenes

**Files:** `scripts/game.gd`

- [x] **Step 1:** Remove the `enemy_scene` export variable. Find and delete this line (around line 28):

```gdscript
@export var enemy_scene: PackedScene
```

- [x] **Step 2:** Replace the `_spawn_enemies_from_level()` function. Replace the entire function (lines 161-187) with:

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

		enemy_units.add_child(enemy)
		enemy.is_enemy = true
		enemy.enemy_container = player_units
		enemy.global_position = enemy_marker.global_position
```

**Verify:**

- Ask user to confirm:
  - The script has no syntax errors
  - The `enemy_scene` export variable is removed
  - The `_spawn_enemies_from_level()` function uses `EnemyMarker` type checks

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Remove enemy files and references

**Files:** `scripts/enemy.gd`, `scenes/units/enemy.tscn`, `scenes/game.tscn`

- [x] **Step 1:** Delete `scripts/enemy.gd`

- [x] **Step 2:** Delete `scenes/units/enemy.tscn`

- [x] **Step 3:** **Godot Editor:** Remove the `enemy_scene` assignment from `scenes/game.tscn`:
  1. Open `scenes/game.tscn` in the Godot editor
  2. Select the Game node (root node)
  3. In the Inspector, find the `enemy_scene` property
  4. Clear the value (set it to empty/null)
  5. Save the scene

**Note:** The `enemy_scene` export variable will still appear in the inspector (since it's defined in the script), but it's no longer used. We're removing it in Task 2, so this step is just cleaning up the scene assignment.

**Verify:**

- Ask user to confirm:
  - `scripts/enemy.gd` is deleted
  - `scenes/units/enemy.tscn` is deleted
  - The `enemy_scene` property in `scenes/game.tscn` is cleared (or will be cleared after Task 2 removes the export)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Update level scenes (manual editor work)

**Files:** `scenes/levels/level_01.tscn`, `scenes/levels/level_02.tscn`, `scenes/levels/level_03.tscn`

**Note:** This task requires manual work in the Godot editor. The executor should stop and ask the user to perform these steps.

- [x] **Step 1:** **Godot Editor:** For each level scene (`level_01.tscn`, `level_02.tscn`, `level_03.tscn`), attach the EnemyMarker script to each Marker2D node under the `EnemyMarkers` node:

  1. Open the level scene in the Godot editor
  2. Expand the `EnemyMarkers` node
  3. For each Marker2D child node:
     - Select the Marker2D node
     - In the Inspector, click the script icon next to the node name
     - Select `scripts/enemy_marker.gd` from the file dialog
     - The node should now show the script icon and have a `unit_scene` property in the Inspector
  4. Save the scene
  5. Repeat for all three level scenes

- [x] **Step 2:** **Godot Editor:** Assign unit scenes to each EnemyMarker in the inspector:
  1. For each Marker2D (now EnemyMarker) in each level scene:
     - Select the EnemyMarker node
     - In the Inspector, find the `unit_scene` property
     - Assign a unit scene (e.g., `scenes/units/swordsman.tscn`, `scenes/units/archer.tscn`, `scenes/units/knight.tscn`, etc.)
     - Each marker can have a different unit scene
  2. Save each level scene after assigning unit scenes

**Verify:**

- Ask user to:
  - Open each level scene and confirm all Marker2D nodes under `EnemyMarkers` have the EnemyMarker script attached
  - Confirm each EnemyMarker has a `unit_scene` assigned in the inspector
  - Run the game and load a level
  - Confirm enemies spawn at the marker positions with the correct unit types
  - Confirm enemies face the correct direction (facing left, opposite of player units)
  - Confirm no errors appear in the console

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] EnemyMarker script exists with `class_name EnemyMarker` and `unit_scene` export
- [ ] Game script uses `EnemyMarker` type checks and reads `unit_scene` from markers
- [ ] Game script no longer has `enemy_scene` export variable
- [ ] Old `enemy.gd` script is deleted
- [ ] Old `enemy.tscn` scene is deleted
- [ ] All level scenes have EnemyMarker script attached to Marker2D nodes
- [ ] Each EnemyMarker in level scenes has a `unit_scene` assigned
- [ ] Enemies spawn correctly at marker positions with assigned unit types
- [ ] Enemies face the correct direction (left, opposite of player units)
- [ ] No errors in the console when loading levels
- [ ] If a marker has no `unit_scene` assigned, the game errors and stops spawning (as designed)
