# ✅ Army Tracking Implementation Plan

**Goal:** Track player army composition with a central data structure, making tray slots consume on placement.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Add ArmyUnit data structure to Game
- [x] Task 2: Update HUD to work with army data
- [x] Task 3: Update SpawnSlot to pass slot index
- [x] Task 4: Connect signals and integrate

---

## Summary

**Task 1: Add ArmyUnit data structure to Game** — Create the ArmyUnit inner class and army array, add initialization method and new signal.

**Task 2: Update HUD to work with army data** — Add method to populate tray from army data and method to clear individual slots.

**Task 3: Update SpawnSlot to pass slot index** — Modify `_drop_data` to pass the army slot index to Game.

**Task 4: Connect signals and integrate** — Wire up the signal connection and update `load_level` to use the new system.

---

## Tasks

### ✅ Task 1: Add ArmyUnit data structure to Game

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add the `ArmyUnit` inner class at the top of the file, after the signals section:

```gdscript
# Army tracking
class ArmyUnit:
	var unit_type: String = ""
	var unit_scene: PackedScene = null
	var placed: bool = false
```

- [x] **Step 2:** Add the new signal after the existing `unit_placed` signal:

```gdscript
signal army_unit_placed(slot_index: int)
```

- [x] **Step 3:** Add the `army` array variable in the state section (after `var phase`):

```gdscript
var army: Array = []  # Array of ArmyUnit
```

- [x] **Step 4:** Add the `_init_army()` method after `_ready()`:

```gdscript
func _init_army() -> void:
	army.clear()
	for scene in starting_unit_scenes:
		var slot := ArmyUnit.new()
		slot.unit_scene = scene
		slot.unit_type = scene.resource_path.get_file().get_basename()
		slot.placed = false
		army.append(slot)
```

- [x] **Step 5:** Modify `place_unit_on_slot` to accept an `army_unit_index` parameter and emit the signal. Change the signature from:

```gdscript
func place_unit_on_slot(unit_type: String, slot: SpawnSlot) -> void:
```

to:

```gdscript
func place_unit_on_slot(unit_type: String, slot: SpawnSlot, army_unit_index: int = -1) -> void:
```

- [x] **Step 6:** Add army slot tracking at the end of `place_unit_on_slot`, before the existing `unit_placed.emit(unit_type)` line:

```gdscript
	# Mark army slot as placed
	if army_unit_index >= 0 and army_unit_index < army.size():
		army[army_unit_index].placed = true
		army_unit_placed.emit(army_unit_index)
```

**After this task:** STOP and ask user to verify the game still runs without errors before continuing.

---

### ✅ Task 2: Update HUD to work with army data

**Files:** `scripts/hud.gd`

- [x] **Step 1:** Add a new method `clear_tray_slot` after the `update_placed_count` method:

```gdscript
func clear_tray_slot(index: int) -> void:
	"""Clear a tray slot after its unit has been placed."""
	if index < 0 or index >= tray_slots.size():
		return

	var slot := tray_slots[index]
	slot.set_meta("unit_type", "")
	if slot.has_method("set_unit_texture"):
		slot.set_unit_texture(null)
```

- [x] **Step 2:** Add a new method `set_tray_from_army` after `set_tray_unit_scenes`. This method accepts the army array and populates the tray:

```gdscript
func set_tray_from_army(army_units: Array) -> void:
	"""Populate the tray from army slot data."""
	placed_unit_count = 0

	if not unit_tray:
		return

	for i in range(tray_slots.size()):
		var slot := tray_slots[i] as Control
		if not slot:
			continue

		if i < army_units.size():
			var army_unit = army_units[i]
			if army_unit.placed:
				# Slot already used, clear it
				slot.set_meta("unit_type", "")
				slot.set_meta("slot_index", i)
				if slot.has_method("set_unit_texture"):
					slot.set_unit_texture(null)
			else:
				# Slot available, populate it
				slot.set_meta("unit_type", army_unit.unit_type)
				slot.set_meta("slot_index", i)

				var texture: Texture2D = _get_texture_from_scene(army_unit.unit_scene)
				if slot.has_method("set_unit_texture"):
					slot.set_unit_texture(texture)
		else:
			slot.set_meta("unit_type", "")
			if slot.has_method("set_unit_texture"):
				slot.set_unit_texture(null)
```

**After this task:** STOP and ask user to verify the game still runs without errors before continuing.

---

### ✅ Task 3: Update SpawnSlot to pass slot index

**Files:** `scripts/spawn_slot.gd`

- [x] **Step 1:** Modify the `_drop_data` method to extract and pass the `slot_index` to Game. Change from:

```gdscript
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("unit_type"):
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			game.place_unit_on_slot(data["unit_type"], self)
```

to:

```gdscript
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("unit_type"):
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			var slot_index: int = data.get("slot_index", -1)
			game.place_unit_on_slot(data["unit_type"], self, slot_index)
```

**After this task:** STOP and ask user to verify the game still runs without errors before continuing.

---

### ✅ Task 4: Connect signals and integrate

**Files:** `scripts/game.gd`

- [x] **Step 1:** In `_ready()`, add a connection for the new `army_unit_placed` signal after the existing signal connections:

```gdscript
	army_unit_placed.connect(_on_army_unit_placed)
```

- [x] **Step 2:** Add the signal handler method after `_on_unit_placed`:

```gdscript
func _on_army_unit_placed(slot_index: int) -> void:
	if hud:
		hud.clear_tray_slot(slot_index)
```

- [x] **Step 3:** In `load_level()`, add a call to `_init_army()` near the beginning of the function, after the validation checks and before clearing units. Add this line after the `level_scene == null` check:

```gdscript
	# Initialize/reset army from starting scenes
	_init_army()
```

- [x] **Step 4:** In `load_level()`, change the tray population at the end from using `set_tray_unit_scenes` to using `set_tray_from_army`. Replace:

```gdscript
	# Populate tray with starting unit scenes
	if starting_unit_scenes.size() > 0:
		hud.set_tray_unit_scenes(starting_unit_scenes)
```

with:

```gdscript
	# Populate tray from army data
	if army.size() > 0:
		hud.set_tray_from_army(army)
```

**After this task:** STOP and ask user to verify manually before continuing.

**Verify:**

- Ask user to:
  - Run the game
  - Drag a unit from the tray to a spawn slot
  - Confirm the unit spawns AND the tray slot becomes empty
  - Drag another unit from a different slot, confirm it also works
  - Try to drag from an empty slot, confirm nothing happens
  - Click "Go" to start battle, lose intentionally
  - Confirm on retry, all tray slots are repopulated

---

## Exit Criteria

- [x] Dragging a unit from tray to battlefield spawns the unit
- [x] The tray slot becomes empty after successful placement
- [x] Empty tray slots cannot be dragged
- [x] Losing and retrying a level fully repopulates the tray
- [x] Winning and advancing to next level fully populates the tray
- [x] No errors in the console
