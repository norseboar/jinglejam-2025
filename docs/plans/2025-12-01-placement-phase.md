# ✅ Placement Phase Implementation Plan

**Goal:** Implement the placement phase — click button to spawn player units, enemies spawn automatically.

**Parent Project:** `docs/project-plan.md` — Task 3

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Implement spawn player unit function
- [x] Task 2: Implement spawn enemies function
- [x] Task 3: Wire up \_ready to spawn enemies

---

## Summary

**Task 1: Implement spawn player unit function** — Fill in `_on_spawn_button_pressed()` to spawn units when clicking "Add Unit".

**Task 2: Implement spawn enemies function** — Create `_spawn_enemies()` to spawn enemy units on the right side.

**Task 3: Wire up \_ready to spawn enemies** — Call `_spawn_enemies()` when the game starts.

---

## Tasks

### ✅ Task 1: Implement spawn player unit function

**Files:** `scripts/game.gd`

- [x] **Step 1:** Replace the placeholder `_on_spawn_button_pressed()` function with this implementation:

```gdscript
func _on_spawn_button_pressed() -> void:
	# Only allow spawning during placement phase
	if phase != "placement":
		return

	# Check if we have slots available
	if current_slot >= player_slots.size():
		spawn_button.disabled = true
		return

	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned in Game!")
		return

	# Instantiate the unit
	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit scene!")
		return

	# Configure the unit as a player unit
	unit.is_enemy = false
	unit.enemy_container = enemy_units  # Player units target enemies
	unit.position = player_slots[current_slot]

	# Add to player units container
	player_units.add_child(unit)

	# Move to next slot
	current_slot += 1

	# Disable button if all slots filled
	if current_slot >= player_slots.size():
		spawn_button.disabled = true
```

**Verify:**

- Ask user to:
  - Run the game scene
  - Click "Add Unit" button
  - Confirm a unit appears at the first slot position (around x=200)
  - Click again to spawn more units (up to 3)
  - Confirm button becomes disabled after 3 units

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Implement spawn enemies function

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add a new function `_spawn_enemies()` below the `_update_hp_display()` function:

```gdscript
func _spawn_enemies() -> void:
	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned in Game!")
		return

	# Spawn an enemy at each position
	for pos in enemy_positions:
		var enemy: Unit = unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit!")
			continue

		# Configure as enemy unit
		enemy.is_enemy = true
		enemy.enemy_container = player_units  # Enemies target player units
		enemy.position = pos

		# Add to enemy units container
		enemy_units.add_child(enemy)
```

- [x] **Step 2:** Add a helper function to clear all units (useful for restart later):

```gdscript
func _clear_all_units() -> void:
	# Remove all player units
	for child in player_units.get_children():
		child.queue_free()

	# Remove all enemy units
	for child in enemy_units.get_children():
		child.queue_free()
```

**Verify:**

- Ask user to confirm:
  - The script has no syntax errors in Godot
  - The two new functions exist: `_spawn_enemies()` and `_clear_all_units()`

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Wire up \_ready to spawn enemies

**Files:** `scripts/game.gd`

- [x] **Step 1:** Modify the `_ready()` function to spawn enemies on game start:

```gdscript
func _ready() -> void:
	_setup_ui()
	_update_hp_display()
	_spawn_enemies()  # Add this line
```

**Verify:**

- Ask user to:
  - Run the game scene
  - Confirm enemies appear on the right side of the screen (3 enemies at x=1000)
  - Confirm player can still click "Add Unit" to spawn player units on the left
  - Confirm all units are in "idle" state (not moving yet)

**After this task:** STOP and ask user to verify manually before continuing.

---

## Final Code Reference

After all tasks, `scripts/game.gd` should look like this:

```gdscript
extends Node2D
class_name Game

# Game state
var player_hp := 10
var phase := "placement"  # "placement" | "battle" | "end"

# Spawn slots for player units (will be adjusted based on screen size)
var player_slots := [
	Vector2(200, 150),
	Vector2(200, 300),
	Vector2(200, 450)
]
var current_slot := 0

# Enemy spawn positions
var enemy_positions := [
	Vector2(1000, 150),
	Vector2(1000, 300),
	Vector2(1000, 450)
]

# Scene references
@export var unit_scene: PackedScene

# Node references
@onready var fortress: Sprite2D = $Fortress
@onready var player_units: Node2D = $PlayerUnits
@onready var enemy_units: Node2D = $EnemyUnits
@onready var spawn_button: Button = $UI/SpawnButton
@onready var start_button: Button = $UI/StartButton
@onready var restart_button: Button = $UI/RestartButton
@onready var hp_label: Label = $UI/HpLabel


func _ready() -> void:
	_setup_ui()
	_update_hp_display()
	_spawn_enemies()


func _setup_ui() -> void:
	# Connect button signals
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

	# Set initial button text
	spawn_button.text = "Add Unit"
	start_button.text = "Fight!"
	restart_button.text = "Restart"

	# Hide restart button initially
	restart_button.visible = false


func _update_hp_display() -> void:
	hp_label.text = "HP: %d" % player_hp


func _spawn_enemies() -> void:
	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned in Game!")
		return

	# Spawn an enemy at each position
	for pos in enemy_positions:
		var enemy: Unit = unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit!")
			continue

		# Configure as enemy unit
		enemy.is_enemy = true
		enemy.enemy_container = player_units  # Enemies target player units
		enemy.position = pos

		# Add to enemy units container
		enemy_units.add_child(enemy)


func _clear_all_units() -> void:
	# Remove all player units
	for child in player_units.get_children():
		child.queue_free()

	# Remove all enemy units
	for child in enemy_units.get_children():
		child.queue_free()


func _on_spawn_button_pressed() -> void:
	# Only allow spawning during placement phase
	if phase != "placement":
		return

	# Check if we have slots available
	if current_slot >= player_slots.size():
		spawn_button.disabled = true
		return

	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned in Game!")
		return

	# Instantiate the unit
	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit scene!")
		return

	# Configure the unit as a player unit
	unit.is_enemy = false
	unit.enemy_container = enemy_units  # Player units target enemies
	unit.position = player_slots[current_slot]

	# Add to player units container
	player_units.add_child(unit)

	# Move to next slot
	current_slot += 1

	# Disable button if all slots filled
	if current_slot >= player_slots.size():
		spawn_button.disabled = true


func _on_start_button_pressed() -> void:
	pass  # Will be implemented in Task 4


func _on_restart_button_pressed() -> void:
	pass  # Will be implemented in Task 5
```

---

## Exit Criteria

- [x] Clicking "Add Unit" spawns a player unit at the next available slot
- [x] Player units appear on the left side (at Marker2D positions)
- [x] "Add Unit" button disables after all slots are filled
- [x] Enemies spawn automatically on the right side (at Marker2D positions)
- [x] Enemies appear when the game starts
- [x] All units start in "idle" state (not moving)
- [x] Player units have `is_enemy = false` and `enemy_container = enemy_units`
- [x] Enemy units have `is_enemy = true` and `enemy_container = player_units`
- [x] No errors in Godot console
