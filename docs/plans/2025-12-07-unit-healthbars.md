# Unit Healthbars Implementation Plan

**Goal:** Add vertical healthbars to units that display current health and use different colors for player vs enemy units.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Create healthbar script
- [ ] Task 2: Add healthbar to unit scene
- [ ] Task 3: Update unit script to call healthbar

---

## Summary

**Task 1: Create healthbar script** — Create `scripts/healthbar.gd` with health update logic and color management.

**Task 2: Add healthbar to unit scene** — Add the healthbar scene as a child of the unit scene.

**Task 3: Update unit script to call healthbar** — Add healthbar reference and update calls in `take_damage()`, `receive_heal()`, and `_ready()`.

---

## Tasks

### Task 1: Create healthbar script

**Files:** `scripts/healthbar.gd`

- [ ] **Step 1:** Create `scripts/healthbar.gd` with the following content:

```gdscript
extends Node2D
class_name Healthbar

## Healthbar component that displays unit health with a vertical fill bar.
## Fill color changes based on alignment (player = green, enemy = red).

@export var player_color: Color = Color(0.2, 0.8, 0.2)  # Green for player units
@export var enemy_color: Color = Color(0.9, 0.2, 0.2)   # Red for enemy units

var is_enemy: bool = false

@onready var fill: Sprite2D = $Fill


func _ready() -> void:
	# Set initial color based on alignment
	_update_color()


func set_alignment(enemy: bool) -> void:
	"""Set whether this healthbar is for an enemy unit."""
	is_enemy = enemy
	_update_color()


func update_health(current_hp: int, max_hp: int) -> void:
	"""Update the healthbar fill based on current and max HP."""
	if fill == null:
		return

	if max_hp <= 0:
		fill.scale.y = 0.0
		return

	# Calculate health fraction (0.0 to 1.0)
	var health_fraction := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

	# Update fill scale - since fill is anchored at bottom, scale.y controls height
	fill.scale.y = health_fraction


func _update_color() -> void:
	"""Update fill color based on alignment."""
	if fill == null:
		return

	fill.modulate = enemy_color if is_enemy else player_color
```

**Verify:**

- File `scripts/healthbar.gd` exists
- Code compiles without errors (check Godot output)

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Add healthbar to unit scene

**Files:** `scenes/healthbar.tscn`, `units/unit.tscn`

- [ ] **Step 1:** **Godot Editor:** Attach the healthbar script to the healthbar scene:

  1. Open `scenes/healthbar.tscn` in Godot
  2. Select the root Healthbar node
  3. In the Inspector, find the Script property
  4. Click the dropdown and select "Load"
  5. Navigate to `scripts/healthbar.gd` and select it
  6. Save the scene (Ctrl+S)

- [ ] **Step 2:** **Godot Editor:** Add the healthbar to the unit scene:
  1. Open `units/unit.tscn` in Godot
  2. Right-click on the root Unit node
  3. Select "Instantiate Child Scene"
  4. Navigate to `scenes/healthbar.tscn` and select it
  5. The Healthbar node should now appear as a child of Unit
  6. Position the healthbar where you want it (to the left of the unit)
  7. Save the scene (Ctrl+S)

**Verify:**

- Ask user to confirm:
  - `scenes/healthbar.tscn` has the healthbar script attached
  - `units/unit.tscn` has a Healthbar child node
  - Healthbar is positioned to the left of the unit sprite

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update unit script to call healthbar

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add healthbar reference to the node references section (around line 64):

```gdscript
# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var healthbar: Healthbar = $Healthbar
```

- [ ] **Step 2:** Update the `_ready()` function to initialize the healthbar (around line 66):

Add this code after setting `current_hp = max_hp` and before the sprite flip logic:

```gdscript
func _ready() -> void:
	current_hp = max_hp

	# Initialize healthbar
	if healthbar:
		healthbar.set_alignment(is_enemy)
		healthbar.update_health(current_hp, max_hp)

	# Flip sprite to face correct direction based on team
	# This must happen in _ready() so enemies face the correct direction immediately
	if animated_sprite:
```

- [ ] **Step 3:** Update the `take_damage()` function to update the healthbar (around line 349):

Add this code after the damage is applied to `current_hp` (line 363):

```gdscript
	current_hp -= final_damage

	# Update healthbar
	if healthbar:
		healthbar.update_health(current_hp, max_hp)

	# Visual feedback: flash the sprite red
```

- [ ] **Step 4:** Update the `receive_heal()` function to update the healthbar (around line 375):

Add this code after the heal is applied to `current_hp` (line 385):

```gdscript
	# Heal the unit, clamping to max_hp
	current_hp = min(current_hp + amount, max_hp)

	# Update healthbar
	if healthbar:
		healthbar.update_health(current_hp, max_hp)

	# Visual feedback: flash the sprite green
```

**Verify:**

- Ask user to:
  - Run the game and start a battle
  - Verify healthbars appear on all units (player and enemy)
  - Verify player units have green healthbars
  - Verify enemy units have red healthbars
  - Verify healthbars decrease when units take damage
  - Verify healthbars increase when healers heal units
  - Check for any errors in the console

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] All units display healthbars to the left of their sprites
- [ ] Player units have green healthbars
- [ ] Enemy units have red healthbars
- [ ] Healthbars accurately reflect current HP fraction (scale.y = current_hp / max_hp)
- [ ] Healthbars update when units take damage
- [ ] Healthbars update when units receive healing
- [ ] No errors in the console
