# ✅ Battle Phase Implementation Plan

**Goal:** Implement the battle phase — clicking "Fight!" starts the battle, units move and fight, battle ends when one side is eliminated.

**Parent Project:** `docs/project-plan.md` — Task 4

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Implement start battle function
- [x] Task 2: Add battle end detection in \_process
- [x] Task 3: Create helper functions to check unit counts

---

## Summary

**Task 1: Implement start battle function** — Fill in `_on_start_button_pressed()` to transition from placement to battle phase.

**Task 2: Add battle end detection in \_process** — Add `_process()` to check every frame if battle is over.

**Task 3: Create helper functions to check unit counts** — Add functions to count living units on each side.

---

## Tasks

### ✅ Task 1: Implement start battle function

**Files:** `scripts/game.gd`

- [x] **Step 1:** Replace the placeholder `_on_start_button_pressed()` function with this implementation:

```gdscript
func _on_start_button_pressed() -> void:
	# Only allow starting battle during placement phase
	if phase != "placement":
		return

	# Don't start if no player units spawned
	if player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return

	# Transition to battle phase
	phase = "battle"

	# Set all units to moving state
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("moving")

	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("moving")

	# Update UI
	spawn_button.visible = false
	spawn_button.disabled = true
	start_button.disabled = true
```

**Verify:**

- Ask user to:
  - Run the game scene
  - Spawn at least one player unit
  - Click "Fight!" button
  - Confirm all units start moving (player units move right, enemies move left)
  - Confirm "Add Unit" button disappears
  - Confirm "Fight!" button becomes disabled

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Add battle end detection in \_process

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add a `_process()` function after the `_ready()` function:

```gdscript
func _process(_delta: float) -> void:
	# Only check battle end during battle phase
	if phase != "battle":
		return

	# Check if battle is over
	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)

	# Battle ends when one side is eliminated
	if player_count == 0 or enemy_count == 0:
		_end_battle(player_count > 0)
```

- [x] **Step 2:** Add a placeholder `_end_battle()` function (will be fully implemented in Task 5):

```gdscript
func _end_battle(player_won: bool) -> void:
	phase = "end"

	# Stop all units from moving
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("idle")

	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("idle")

	# TODO: Handle survivors damaging fortress (Task 5)
	# TODO: Show restart button (Task 5)

	print("Battle ended! Player won: ", player_won)
```

**Verify:**

- Ask user to:
  - Run the game scene
  - Spawn units and start battle
  - Let units fight until one side is eliminated
  - Confirm battle ends (check console for "Battle ended!" message)
  - Confirm all units stop moving when battle ends

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Create helper functions to check unit counts

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add the `_count_living_units()` helper function before `_on_start_button_pressed()`:

```gdscript
func _count_living_units(container: Node2D) -> int:
	var count := 0
	for child in container.get_children():
		if child is Unit:
			var unit := child as Unit
			# Count units that are not dead or dying
			if unit.current_hp > 0 and unit.state != "dying":
				count += 1
	return count
```

**Verify:**

- Ask user to confirm:
  - The script has no syntax errors in Godot
  - The `_count_living_units()` function exists
  - Battle correctly detects when all units on one side are dead

**After this task:** STOP and ask user to verify manually before continuing.

---

## Final Code Reference

After all tasks, the relevant parts of `scripts/game.gd` should look like this:

```gdscript
func _ready() -> void:
	_setup_ui()
	_update_hp_display()
	_validate_spawn_slots()
	_spawn_enemies()


func _process(_delta: float) -> void:
	# Only check battle end during battle phase
	if phase != "battle":
		return

	# Check if battle is over
	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)

	# Battle ends when one side is eliminated
	if player_count == 0 or enemy_count == 0:
		_end_battle(player_count > 0)


func _count_living_units(container: Node2D) -> int:
	var count := 0
	for child in container.get_children():
		if child is Unit:
			var unit := child as Unit
			# Count units that are not dead or dying
			if unit.current_hp > 0 and unit.state != "dying":
				count += 1
	return count


func _end_battle(player_won: bool) -> void:
	phase = "end"

	# Stop all units from moving
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("idle")

	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("idle")

	# TODO: Handle survivors damaging fortress (Task 5)
	# TODO: Show restart button (Task 5)

	print("Battle ended! Player won: ", player_won)


func _on_start_button_pressed() -> void:
	# Only allow starting battle during placement phase
	if phase != "placement":
		return

	# Don't start if no player units spawned
	if player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return

	# Transition to battle phase
	phase = "battle"

	# Set all units to moving state
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("moving")

	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("moving")

	# Update UI
	spawn_button.visible = false
	spawn_button.disabled = true
	start_button.disabled = true
```

---

## Exit Criteria

- [x] Clicking "Fight!" transitions game to "battle" phase — Met by `_on_start_button_pressed()` setting `phase = "battle"`
- [x] All units switch to "moving" state when battle starts — Met by loops setting `child.set_state("moving")` for all units
- [x] Player units move right, enemy units move left — Handled by Unit.gd movement logic (verified by user)
- [x] Units stop and fight when enemies enter attack range — Handled by Unit.gd targeting logic (verified by user)
- [x] Battle ends when all units on one side are eliminated — Met by `_process()` checking `player_count == 0 or enemy_count == 0`
- [x] All units stop moving when battle ends — Met by `_end_battle()` setting all units to "idle" state
- [x] "Add Unit" button hides when battle starts — Met by `spawn_button.visible = false`
- [x] "Fight!" button disables when battle starts — Met by `start_button.disabled = true`
- [x] Console shows "Battle ended! Player won: true/false" message — Met by `print("Battle ended! Player won: ", player_won)`
- [x] No errors in Godot console — Verified by user
