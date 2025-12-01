# ✅ Unit Scene & Script Implementation Plan

**Goal:** Create `unit.tscn` — an animated unit that can move, fight, and die (with idle, walk, attack animations).

**Parent Project:** `docs/project-plan.md` — Task 1

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Create Unit scene structure
- [x] Task 2: Create Unit script with variables
- [x] Task 3: Implement movement behavior
- [x] Task 4: Implement targeting and fighting
- [x] Task 5: Implement damage and death

---

## Summary

**Task 1: Create Unit scene structure** — Build `unit.tscn` with a Node2D root and AnimatedSprite2D child (with idle, walk, attack animations).

**Task 2: Create Unit script with variables** — Create `unit.gd` with all state variables and attach to scene.

**Task 3: Implement movement behavior** — Add `_process()` logic for idle and moving states, play animations.

**Task 4: Implement targeting and fighting** — Add enemy detection and attack logic, play attack animation.

**Task 5: Implement damage and death** — Add `take_damage()` and `die()` functions.

---

## Tasks

### ✅ Task 1: Create Unit scene structure

**Files:** `scenes/unit.tscn`

- [ ] **Step 1:** Create a new scene in Godot with root node type `Node2D`, name it `Unit`

- [ ] **Step 2:** Add an `AnimatedSprite2D` child node to Unit

- [ ] **Step 3:** Set up the SpriteFrames resource:

  - Select the AnimatedSprite2D node
  - In the Inspector, find `Sprite Frames` property
  - Click the dropdown and select `New SpriteFrames`
  - Click on the SpriteFrames resource to open the SpriteFrames panel at the bottom

- [ ] **Step 4:** Create the three animations:

  - The "default" animation already exists — rename it to `idle`
  - Click the "Add Animation" button (page with + icon) to add `walk`
  - Click "Add Animation" again to add `attack`
  - Add your placeholder frames to each animation
  - Set appropriate FPS for each animation (e.g., 8 FPS)

- [ ] **Step 5:** Configure animation settings:

  - Select `idle` animation → enable "Loop" (click the loop icon)
  - Select `walk` animation → enable "Loop"
  - Select `attack` animation → leave Loop OFF (plays once per attack)

- [ ] **Step 6:** Save the scene as `scenes/unit.tscn`

**Verify:**

- Ask user to confirm:
  - `scenes/unit.tscn` exists
  - Scene tree shows `Unit (Node2D)` → `AnimatedSprite2D`
  - SpriteFrames has 3 animations: `idle`, `walk`, `attack`

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create Unit script with variables

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Create the file `scripts/unit.gd` with the following content:

```gdscript
extends Node2D
class_name Unit

# Stats
var max_hp := 3
var current_hp := 3
var damage := 1
var speed := 100.0           # pixels per second
var attack_range := 50.0     # radius to detect enemies
var attack_cooldown := 1.0   # seconds between attacks

# State
var is_enemy := false        # true = moves left (enemy), false = moves right (player)
var state := "idle"          # "idle" | "moving" | "fighting"
var target: Node2D = null    # current attack target
var time_since_attack := 0.0 # timer for attack cooldown

# Reference to the container holding enemies (set by game.gd when spawning)
var enemy_container: Node2D = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_hp = max_hp
	animated_sprite.play("idle")


func _process(delta: float) -> void:
	pass  # Will be implemented in next tasks
```

- [ ] **Step 2:** Attach the script to the Unit scene:
  - Open `scenes/unit.tscn`
  - Select the root `Unit` node
  - In the Inspector, click the script property and load `scripts/unit.gd`
  - Save the scene

**Verify:**

- Ask user to confirm:
  - `scripts/unit.gd` exists with the variables defined
  - The script is attached to the Unit scene (shows script icon next to Unit node)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Implement movement behavior

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add the movement direction logic. Replace the `_process` function:

```gdscript
func _process(delta: float) -> void:
	match state:
		"idle":
			pass  # Do nothing, waiting for battle to start
		"moving":
			_do_movement(delta)
		"fighting":
			_do_fighting(delta)


func set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		"idle":
			animated_sprite.play("idle")
		"moving":
			animated_sprite.play("walk")
		"fighting":
			pass  # Attack animation played per attack


func _do_movement(delta: float) -> void:
	# Determine movement direction based on team
	var direction := 1.0 if not is_enemy else -1.0  # Player moves right, enemy moves left

	# Flip sprite to face movement direction
	animated_sprite.flip_h = is_enemy

	# Move horizontally
	position.x += direction * speed * delta

	# Check for enemies in range
	_check_for_targets()


func _check_for_targets() -> void:
	if enemy_container == null:
		return

	var closest_enemy: Node2D = null
	var closest_distance := INF

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy is Unit and enemy.current_hp <= 0:
			continue  # Skip dead units

		var distance := position.distance_to(enemy.position)
		if distance < attack_range and distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		set_state("fighting")
		time_since_attack = attack_cooldown  # Attack immediately when entering combat
```

- [ ] **Step 2:** Add an empty placeholder for the fighting function:

```gdscript
func _do_fighting(delta: float) -> void:
	pass  # Will be implemented in Task 4
```

**Verify:**

- Ask user to confirm:
  - The script has no syntax errors (Godot editor shows no red errors)
  - `_do_movement()` and `_check_for_targets()` functions exist

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Implement targeting and fighting

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Replace the `_do_fighting` function with the full implementation:

```gdscript
func _do_fighting(delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(target) or target.current_hp <= 0:
		target = null
		set_state("moving")
		return

	# Check if target moved out of range
	var distance := position.distance_to(target.position)
	if distance > attack_range * 1.2:  # Small buffer to prevent flickering
		target = null
		set_state("moving")
		return

	# Attack on cooldown
	time_since_attack += delta
	if time_since_attack >= attack_cooldown:
		time_since_attack = 0.0
		_attack_target()


func _attack_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	# Play attack animation
	animated_sprite.play("attack")

	if target.has_method("take_damage"):
		target.take_damage(damage)
```

**Verify:**

- Ask user to confirm:
  - The script has no syntax errors
  - `_do_fighting()` and `_attack_target()` functions exist

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 5: Implement damage and death

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add the `take_damage` function at the bottom of the script:

```gdscript
func take_damage(amount: int) -> void:
	current_hp -= amount

	# Visual feedback: flash the sprite red
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		# Reset color after a short delay
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if current_hp <= 0:
		die()


func _reset_color() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func die() -> void:
	# Remove from the scene
	queue_free()
```

- [ ] **Step 2:** Add a helper function to set the unit's color (useful for distinguishing player vs enemy):

```gdscript
func set_team_color(color: Color) -> void:
	if animated_sprite:
		animated_sprite.modulate = color
```

**Verify:**

- Ask user to:
  - Open `scripts/unit.gd` and confirm no syntax errors
  - Verify these functions exist: `take_damage()`, `die()`, `set_team_color()`

**After this task:** STOP and ask user to verify manually before continuing.

---

## Final Script Reference

After all tasks, `scripts/unit.gd` should contain:

```gdscript
extends Node2D
class_name Unit

# Stats
var max_hp := 3
var current_hp := 3
var damage := 1
var speed := 100.0
var attack_range := 50.0
var attack_cooldown := 1.0

# State
var is_enemy := false
var state := "idle"
var target: Node2D = null
var time_since_attack := 0.0
var enemy_container: Node2D = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_hp = max_hp
	animated_sprite.play("idle")


func _process(delta: float) -> void:
	match state:
		"idle":
			pass
		"moving":
			_do_movement(delta)
		"fighting":
			_do_fighting(delta)


func set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		"idle":
			animated_sprite.play("idle")
		"moving":
			animated_sprite.play("walk")
		"fighting":
			pass  # Attack animation played per attack


func _do_movement(delta: float) -> void:
	var direction := 1.0 if not is_enemy else -1.0
	animated_sprite.flip_h = is_enemy
	position.x += direction * speed * delta
	_check_for_targets()


func _check_for_targets() -> void:
	if enemy_container == null:
		return

	var closest_enemy: Node2D = null
	var closest_distance := INF

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy is Unit and enemy.current_hp <= 0:
			continue

		var distance := position.distance_to(enemy.position)
		if distance < attack_range and distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	if closest_enemy != null:
		target = closest_enemy
		set_state("fighting")
		time_since_attack = attack_cooldown


func _do_fighting(delta: float) -> void:
	if not is_instance_valid(target) or target.current_hp <= 0:
		target = null
		set_state("moving")
		return

	var distance := position.distance_to(target.position)
	if distance > attack_range * 1.2:
		target = null
		set_state("moving")
		return

	time_since_attack += delta
	if time_since_attack >= attack_cooldown:
		time_since_attack = 0.0
		_attack_target()


func _attack_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	animated_sprite.play("attack")

	if target.has_method("take_damage"):
		target.take_damage(damage)


func take_damage(amount: int) -> void:
	current_hp -= amount

	if animated_sprite:
		animated_sprite.modulate = Color.RED
		get_tree().create_timer(0.1).timeout.connect(_reset_color)

	if current_hp <= 0:
		die()


func _reset_color() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func die() -> void:
	queue_free()


func set_team_color(color: Color) -> void:
	if animated_sprite:
		animated_sprite.modulate = color
```

---

## Exit Criteria

- [x] `scenes/unit.tscn` exists with Node2D root and AnimatedSprite2D child
- [x] AnimatedSprite2D has 3 animations: `idle`, `walk`, `attack`
- [x] `scripts/unit.gd` is attached to the Unit scene
- [x] Unit has all stat variables (max_hp, damage, speed, attack_range, attack_cooldown)
- [x] Unit has all state variables (is_enemy, state, target, time_since_attack, enemy_container)
- [x] Unit plays `idle` animation on start
- [x] Unit plays `walk` animation when moving
- [x] Unit plays `attack` animation when attacking
- [x] Unit can move when state is "moving"
- [x] Unit can detect enemies within attack_range
- [x] Unit can attack and deal damage
- [x] Unit can take damage and die (queue_free)
- [x] No script errors in Godot editor
