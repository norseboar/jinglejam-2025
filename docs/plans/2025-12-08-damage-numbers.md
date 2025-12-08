# Floating Damage Numbers Implementation Plan

**Goal:** Add floating damage numbers that appear above units when they take damage.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Create DamageNumber scene and script
- [ ] Task 2: Integrate damage numbers with unit damage system

---

## Summary

**Task 1: Create DamageNumber scene and script** — Build the damage number VFX scene with configurable properties and animation logic.

**Task 2: Integrate damage numbers with unit damage system** — Spawn damage numbers when units take damage in the `take_damage()` function.

---

## Tasks

### Task 1: Create DamageNumber scene and script

**Files:** `scenes/vfx/damage_number.tscn`, `scripts/damage_number.gd`

- [ ] **Step 1:** **Godot Editor:** Create a new scene `scenes/vfx/damage_number.tscn`:

  1. In Godot, click Scene → New Scene
  2. Select "Other Node" and choose `Node2D` as the root
  3. Name the root node `DamageNumber`
  4. Save the scene as `scenes/vfx/damage_number.tscn`

- [ ] **Step 2:** **Godot Editor:** Add a Label child to the DamageNumber node:

  1. Right-click the DamageNumber node
  2. Add Child Node → search for `Label`
  3. Select the Label node
  4. In the Inspector, under "Theme Overrides > Font Sizes", set Font Size to `16`
  5. Under "Theme Overrides > Fonts", click the dropdown next to "Font"
  6. Select "Load" and choose `assets/fonts/DungeonFont.ttf`
  7. Under "Layout", set Horizontal Alignment to `Center`
  8. Under "Theme Overrides > Colors", add an outline color:
     - Click the dropdown next to "Outline Color"
     - Select black (or very dark color) `#000000`
  9. Under "Theme Overrides > Constants", set Outline Size to `2`
  10. Save the scene

- [ ] **Step 3:** Create `scripts/damage_number.gd` with the following structure:

```gdscript
extends Node2D
class_name DamageNumber

## Floating damage number that appears when a unit takes damage

@export var color: Color = Color(0.9, 0.2, 0.2)  # Default red shade
@export var float_distance: float = 30.0  # How far up it floats in pixels
@export var float_duration: float = 0.8  # How long the animation takes in seconds
@export var random_horizontal_range: float = 15.0  # Random X offset range (±pixels)

@onready var label: Label = $Label


func setup(damage_amount: int) -> void:
	"""Initialize the damage number with the damage amount."""
	label.text = str(damage_amount)
	label.modulate = color


func _ready() -> void:
	"""Start the float animation."""
	# Calculate random horizontal offset
	var random_x := randf_range(-random_horizontal_range, random_horizontal_range)
	var target_position := position + Vector2(random_x, -float_distance)

	# Create tween for animation
	var tween := create_tween()
	tween.set_parallel(true)  # Run both animations simultaneously

	# Animate position (float up with random horizontal drift)
	tween.tween_property(self, "position", target_position, float_duration).set_ease(Tween.EASE_OUT)

	# Animate fade out
	tween.tween_property(label, "modulate:a", 0.0, float_duration).set_ease(Tween.EASE_OUT)

	# Cleanup when animation completes
	tween.finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	"""Destroy the damage number when animation completes."""
	queue_free()
```

- [ ] **Step 4:** **Godot Editor:** Attach the script to the DamageNumber scene:
  1. Open `scenes/vfx/damage_number.tscn` in the Godot editor
  2. Select the DamageNumber root node
  3. In the Inspector, click the script icon (paper with plus) next to the node name
  4. Select "Load" and choose `scripts/damage_number.gd`
  5. Save the scene

**Verify:** Ask user to confirm:

- `scenes/vfx/damage_number.tscn` exists with DamageNumber (Node2D) → Label structure
- `scripts/damage_number.gd` is attached to the DamageNumber node
- Label has DungeonFont, center alignment, and outline configured

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Integrate damage numbers with unit damage system

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add the DamageNumber preload at the top of `scripts/unit.gd` (after the class_name line):

```gdscript
const DamageNumber = preload("res://scenes/vfx/damage_number.tscn")
```

- [ ] **Step 2:** Create a helper function to spawn damage numbers. Add this function after the `take_damage()` function (around line 478):

```gdscript
func _spawn_damage_number(damage_amount: int) -> void:
	"""Spawn a floating damage number at this unit's position."""
	var damage_number := DamageNumber.instantiate()

	# Find the parent container to add the damage number to
	# We want to add it to the same level as units (not as a child of this unit)
	var world_container: Node2D = null
	if is_enemy and enemy_container != null:
		world_container = enemy_container.get_parent()
	elif not is_enemy and friendly_container != null:
		world_container = friendly_container.get_parent()

	if world_container == null:
		# Fallback: use parent
		world_container = get_parent()

	# Add to world and position at unit's sprite location
	world_container.add_child(damage_number)

	# Position at the top of the sprite
	if animated_sprite:
		# Get sprite bounds
		var sprite_height := 16.0  # Default fallback
		if animated_sprite.sprite_frames:
			var current_animation := animated_sprite.animation
			if animated_sprite.sprite_frames.has_animation(current_animation):
				var frame_count := animated_sprite.sprite_frames.get_frame_count(current_animation)
				if frame_count > 0:
					var frame_texture := animated_sprite.sprite_frames.get_frame_texture(current_animation, 0)
					if frame_texture:
						sprite_height = frame_texture.get_height()

		# Position at top of sprite
		damage_number.global_position = animated_sprite.global_position + Vector2(0, -sprite_height / 2)
	else:
		# Fallback to unit position
		damage_number.global_position = global_position

	# Setup the damage number
	damage_number.setup(damage_amount)
```

- [ ] **Step 3:** Call `_spawn_damage_number()` in the `take_damage()` function. Add this line after the `final_damage` calculation (around line 463, right after `final_damage = max(0, amount - total_armor)`):

```gdscript
	# Apply armor + heal_armor reduction unless attacker has armor piercing
	var final_damage := amount
	if not attacker_armor_piercing:
		var total_armor := armor + heal_armor
		final_damage = max(0, amount - total_armor)

	# Spawn damage number
	_spawn_damage_number(final_damage)

	current_hp -= final_damage
```

**Verify:** Ask user to:

- Run the game
- Start a battle
- Watch units take damage
- Confirm that damage numbers appear above units when hit
- Verify numbers float upward with random horizontal drift
- Verify numbers fade out as they float
- Verify numbers show the correct damage amount (including 0 when armor blocks all damage)

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Damage numbers appear above units when they take damage
- [ ] Numbers show the actual damage taken (post-armor calculation)
- [ ] Numbers showing "0" appear when armor blocks all damage
- [ ] Numbers float upward with random horizontal offset
- [ ] Numbers fade out smoothly during animation
- [ ] Numbers self-destruct after animation completes
- [ ] Multiple rapid hits produce multiple visible numbers
- [ ] Numbers persist even if the unit dies during animation
- [ ] No errors in the console during battles

---

## Future Enhancements

These are not part of this plan but can be added later:

- Add healing numbers (green color) in `receive_heal()` function
- Add shield/armor numbers when heal armor is applied
- Add color customization per damage type
- Add critical hit styling (larger font, different color)
