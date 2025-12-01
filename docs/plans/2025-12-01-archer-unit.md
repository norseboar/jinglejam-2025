# ✅ Archer Unit Implementation Plan

**Goal:** Add support for multiple unit types (Swordsman, Archer) with inheritance-based architecture and ranged projectile combat.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Refactor Unit.gd to base class
- [x] Task 2: Create Swordsman unit
- [x] Task 3: Create Enemy unit
- [x] Task 4: Create Projectile
- [x] Task 5: Create Archer unit
- [x] Task 6: Update Game.gd and UI
- [x] Task 7: Clean up old files

---

## Summary

**Task 1: Refactor Unit.gd to base class** — Convert Unit.gd to a base class with @export stats, virtual attack method, and animation speed scaling.

**Task 2: Create Swordsman unit** — Create Swordsman.gd extending Unit with melee attack, and swordsman.tscn scene.

**Task 3: Create Enemy unit** — Create Enemy.gd extending Unit for enemy melee units, and enemy.tscn scene.

**Task 4: Create Projectile** — Create Projectile.gd and projectile.tscn for archer arrows.

**Task 5: Create Archer unit** — Create Archer.gd extending Unit with ranged attack that spawns projectiles, and archer.tscn scene.

**Task 6: Update Game.gd and UI** — Replace single spawn button with Swordsman/Archer buttons, update scene references.

**Task 7: Clean up old files** — Delete the old unit.tscn that's no longer needed.

---

## Tasks

### ✅ Task 1: Refactor Unit.gd to base class

**Files:** `scripts/Unit.gd`

- [x] **Step 1:** Add `@export` to all stat variables at the top of Unit.gd:

```gdscript
# Stats
@export var max_hp := 3
@export var current_hp := 3
@export var damage := 1
@export var speed := 100.0           # pixels per second
@export var attack_range := 50.0     # radius to detect enemies
@export var attack_cooldown := 1.0   # seconds between attacks
```

- [x] **Step 2:** Rename `_attack_target()` to `_perform_attack()` and make it virtual by changing it to just play animation and call a new overridable method. Replace the entire `_attack_target()` function with:

```gdscript
func _attack_target() -> void:
	if target == null or not is_instance_valid(target) or is_attacking:
		return

	# Set attacking flag and play animation
	is_attacking = true

	# Calculate animation speed to match attack cooldown
	var anim_speed_scale := _calculate_attack_animation_speed()
	animated_sprite.speed_scale = anim_speed_scale
	animated_sprite.play("attack")

	# Get animation duration (accounting for speed scale)
	var anim_duration := _get_attack_animation_duration() / anim_speed_scale

	if anim_duration > 0:
		get_tree().create_timer(anim_duration).timeout.connect(_on_attack_animation_finished)
	else:
		_on_attack_animation_finished()
```

- [x] **Step 3:** Add the new `_calculate_attack_animation_speed()` helper function after `_attack_target()`:

```gdscript
func _calculate_attack_animation_speed() -> float:
	var base_duration := _get_attack_animation_duration()
	if base_duration <= 0 or attack_cooldown <= 0:
		return 1.0
	# Scale animation to fit within attack cooldown
	# Leave a small buffer so animation completes before next attack
	var target_duration := attack_cooldown * 0.9
	return base_duration / target_duration


func _get_attack_animation_duration() -> float:
	var sprite_frames := animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation("attack"):
		return 0.0

	var frame_count := sprite_frames.get_frame_count("attack")
	var anim_speed := sprite_frames.get_animation_speed("attack")
	var anim_duration := 0.0

	for i in range(frame_count):
		var frame_duration_frames := sprite_frames.get_frame_duration("attack", i)
		var frame_duration_seconds := frame_duration_frames / anim_speed
		anim_duration += frame_duration_seconds

	return anim_duration
```

- [x] **Step 4:** Simplify `_on_attack_animation_finished()` to call a virtual method that subclasses can override. Replace it with:

```gdscript
func _on_attack_animation_finished() -> void:
	is_attacking = false

	# Reset animation speed scale
	animated_sprite.speed_scale = 1.0

	# Call virtual method for actual attack effect (subclasses override this)
	_apply_attack_damage()

	# Switch back to idle animation while waiting for next attack
	if state == "fighting" and animated_sprite:
		animated_sprite.play("idle")


## Virtual method - subclasses override this to implement their attack type
func _apply_attack_damage() -> void:
	# Default melee behavior - deal damage directly to target
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)
```

- [x] **Step 5:** Remove the old debug print statements from the attack code (the ones that print frame durations).

**Verify:** Ask user to run the game with the existing unit.tscn. Units should still attack and deal damage. Animation speed may now scale based on attack cooldown.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create Swordsman unit

**Files:** `scripts/Swordsman.gd`, `scenes/swordsman.tscn`

- [x] **Step 1:** Create `scripts/Swordsman.gd`:

```gdscript
extends Unit
class_name Swordsman

## Swordsman - melee unit that attacks enemies up close.
## Uses default Unit behavior - no overrides needed.

func _ready() -> void:
	# Set default stats for swordsman (can be overridden in inspector)
	if max_hp == 3:  # Only set if using default
		max_hp = 3
	if attack_range == 50.0:
		attack_range = 50.0
	if attack_cooldown == 1.0:
		attack_cooldown = 1.0

	super._ready()
```

- [x] **Step 2:** **Godot Editor:** Create `scenes/swordsman.tscn`:

1. Open Godot editor
2. Create a new scene (Scene → New Scene)
3. Add a Node2D as root, rename it to "Swordsman"
4. Add an AnimatedSprite2D as a child of Swordsman
5. Attach `scripts/Swordsman.gd` to the Swordsman root node
6. Configure the AnimatedSprite2D:
   - Create or assign a SpriteFrames resource
   - Add animations: "idle", "walk", "attack" (can copy from existing unit or use placeholders)
7. Save as `scenes/swordsman.tscn`

**Verify:** Ask user to open swordsman.tscn in the editor. The scene should have a Swordsman root with AnimatedSprite2D child, and the script should be attached.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Create Enemy unit

**Files:** `scripts/Enemy.gd`, `scenes/enemy.tscn`

- [x] **Step 1:** Create `scripts/Enemy.gd`:

```gdscript
extends Unit
class_name Enemy

## Enemy - melee unit that fights for the enemy team.
## Uses default Unit behavior - no overrides needed.

func _ready() -> void:
	# Enemies are always on the enemy team
	is_enemy = true

	# Set default stats for enemy (can be overridden in inspector)
	if max_hp == 3:
		max_hp = 3
	if attack_range == 50.0:
		attack_range = 50.0
	if attack_cooldown == 1.0:
		attack_cooldown = 1.0

	super._ready()
```

- [x] **Step 2:** **Godot Editor:** Create `scenes/enemy.tscn`:

1. Open Godot editor
2. Create a new scene (Scene → New Scene)
3. Add a Node2D as root, rename it to "Enemy"
4. Add an AnimatedSprite2D as a child of Enemy
5. Attach `scripts/Enemy.gd` to the Enemy root node
6. Configure the AnimatedSprite2D:
   - Create or assign a SpriteFrames resource (can be same as swordsman or different color)
   - Add animations: "idle", "walk", "attack"
7. Save as `scenes/enemy.tscn`

**Verify:** Ask user to open enemy.tscn in the editor. The scene should have an Enemy root with AnimatedSprite2D child, and the script should be attached.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Create Projectile

**Files:** `scripts/Projectile.gd`, `scenes/projectile.tscn`

- [x] **Step 1:** Create `scripts/Projectile.gd`:

```gdscript
extends Node2D
class_name Projectile

## Projectile fired by ranged units. Moves in a direction until it hits an enemy or leaves the screen.

@export var speed := 400.0
@export var damage := 1
@export var hit_radius := 20.0  # How close to an enemy to count as a hit

var direction := Vector2.RIGHT
var enemy_container: Node2D = null  # Container of valid targets

@onready var visible_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	# Connect screen exit signal to destroy projectile
	visible_notifier.screen_exited.connect(queue_free)


func _process(delta: float) -> void:
	# Move in the set direction
	position += direction * speed * delta

	# Check for hits
	_check_for_hits()


func _check_for_hits() -> void:
	if enemy_container == null:
		return

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue

		# Skip dead or dying units
		if enemy is Unit:
			if enemy.current_hp <= 0 or enemy.state == "dying":
				continue

		var distance := position.distance_to(enemy.position)
		if distance < hit_radius:
			# Hit! Deal damage and destroy projectile
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			queue_free()
			return


## Initialize the projectile with direction and target container
func setup(dir: Vector2, targets: Node2D, dmg: int) -> void:
	direction = dir.normalized()
	enemy_container = targets
	damage = dmg

	# Rotate sprite to face direction
	rotation = direction.angle()
```

- [x] **Step 2:** **Godot Editor:** Create `scenes/projectile.tscn`:

1. Open Godot editor
2. Create a new scene (Scene → New Scene)
3. Add a Node2D as root, rename it to "Projectile"
4. Add a Sprite2D as a child (for the arrow graphic - can use a placeholder rectangle for now)
5. Add a VisibleOnScreenNotifier2D as a child of Projectile
6. Attach `scripts/Projectile.gd` to the Projectile root node
7. Configure the Sprite2D:
   - Use a placeholder texture or simple arrow shape
   - Make sure it's centered and pointing right (since direction defaults to RIGHT)
8. Save as `scenes/projectile.tscn`

**Verify:** Ask user to open projectile.tscn in the editor. The scene should have Projectile root with Sprite2D and VisibleOnScreenNotifier2D children.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 5: Create Archer unit

**Files:** `scripts/Archer.gd`, `scenes/archer.tscn`

- [x] **Step 1:** Create `scripts/Archer.gd`:

```gdscript
extends Unit
class_name Archer

## Archer - ranged unit that fires projectiles at enemies from a distance.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0


func _ready() -> void:
	# Set default stats for archer (can be overridden in inspector)
	if max_hp == 3:
		max_hp = 2  # Archers are squishier
	if attack_range == 50.0:
		attack_range = 300.0  # Much longer range
	if attack_cooldown == 1.0:
		attack_cooldown = 1.5  # Slower attack
	if speed == 100.0:
		speed = 80.0  # Slower movement

	super._ready()


## Override to spawn a projectile instead of dealing direct damage
func _apply_attack_damage() -> void:
	if target == null or not is_instance_valid(target):
		return

	if projectile_scene == null:
		push_error("Archer has no projectile_scene assigned!")
		return

	# Spawn projectile
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_error("Failed to instantiate projectile!")
		return

	# Add to scene tree (add to parent so it's not a child of the archer)
	get_parent().add_child(projectile)

	# Position at archer's location
	projectile.global_position = global_position

	# Calculate direction to target
	var direction := (target.global_position - global_position).normalized()

	# Setup projectile
	projectile.setup(direction, enemy_container, damage)
	projectile.speed = projectile_speed
```

- [x] **Step 2:** **Godot Editor:** Create `scenes/archer.tscn`:

1. Open Godot editor
2. Create a new scene (Scene → New Scene)
3. Add a Node2D as root, rename it to "Archer"
4. Add an AnimatedSprite2D as a child of Archer
5. Attach `scripts/Archer.gd` to the Archer root node
6. Configure the AnimatedSprite2D:
   - Create or assign a SpriteFrames resource (different from swordsman to distinguish)
   - Add animations: "idle", "walk", "attack"
7. In the Inspector for the Archer node:
   - Set `Projectile Scene` to `scenes/projectile.tscn`
   - Optionally adjust other stats (attack_range, projectile_speed, etc.)
8. Save as `scenes/archer.tscn`

**Verify:** Ask user to open archer.tscn in the editor. The scene should have an Archer root with AnimatedSprite2D child, script attached, and projectile_scene assigned in the inspector.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 6: Update Game.gd and UI

**Files:** `scripts/game.gd`, `scenes/game.tscn`

- [x] **Step 1:** Update the scene references at the top of `game.gd`. Replace:

```gdscript
# Scene references
@export var unit_scene: PackedScene
```

With:

```gdscript
# Scene references
@export var swordsman_scene: PackedScene
@export var archer_scene: PackedScene
@export var enemy_scene: PackedScene
```

- [x] **Step 2:** Update the node references. Replace:

```gdscript
@onready var spawn_button: Button = $UI/SpawnButton
```

With:

```gdscript
@onready var swordsman_button: Button = $UI/SwordsmanButton
@onready var archer_button: Button = $UI/ArcherButton
```

- [x] **Step 3:** Update `_setup_ui()` to connect both buttons. Replace the spawn_button lines:

```gdscript
func _setup_ui() -> void:
	# Connect button signals
	swordsman_button.pressed.connect(_on_swordsman_button_pressed)
	archer_button.pressed.connect(_on_archer_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

	# Set initial button text
	swordsman_button.text = "Add Swordsman"
	archer_button.text = "Add Archer"
	start_button.text = "Fight!"
	restart_button.text = "Restart"

	# Hide restart button initially
	restart_button.visible = false

	# Disable start button initially (no units yet)
	start_button.disabled = true
```

- [x] **Step 4:** Update `_spawn_enemies()` to use `enemy_scene`. Replace:

```gdscript
var enemy: Unit = unit_scene.instantiate() as Unit
```

With:

```gdscript
var enemy: Unit = enemy_scene.instantiate() as Unit
```

- [x] **Step 5:** Replace `_on_spawn_button_pressed()` with two new functions:

```gdscript
func _on_swordsman_button_pressed() -> void:
	_spawn_player_unit(swordsman_scene)


func _on_archer_button_pressed() -> void:
	_spawn_player_unit(archer_scene)


func _spawn_player_unit(unit_scene: PackedScene) -> void:
	# Only allow spawning during placement phase
	if phase != "placement":
		return

	# Find next available spawn position
	var spawn_pos := _get_next_available_slot()
	if spawn_pos == Vector2.ZERO:
		# All slots are filled
		swordsman_button.disabled = true
		archer_button.disabled = true
		return

	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned!")
		return

	# Instantiate the unit
	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit scene!")
		return

	# Add to player units container first (needed for coordinate conversion)
	player_units.add_child(unit)

	# Configure the unit as a player unit
	unit.is_enemy = false
	unit.enemy_container = enemy_units  # Player units target enemies
	# Convert global spawn position to local position relative to player_units
	unit.global_position = spawn_pos

	# Disable buttons if all slots filled
	var spawn_positions := _get_player_spawn_positions()
	if player_units.get_child_count() >= spawn_positions.size():
		swordsman_button.disabled = true
		archer_button.disabled = true

	# Enable start button now that we have at least one unit
	start_button.disabled = false
```

- [x] **Step 6:** Update `_on_start_button_pressed()` to hide both buttons. Replace:

```gdscript
# Update UI
spawn_button.visible = false
spawn_button.disabled = true
```

With:

```gdscript
# Update UI
swordsman_button.visible = false
swordsman_button.disabled = true
archer_button.visible = false
archer_button.disabled = true
```

- [x] **Step 7:** Update `_on_restart_button_pressed()` to show both buttons. Replace:

```gdscript
# Reset UI to placement phase state
spawn_button.visible = true
spawn_button.disabled = false
```

With:

```gdscript
# Reset UI to placement phase state
swordsman_button.visible = true
swordsman_button.disabled = false
archer_button.visible = true
archer_button.disabled = false
```

- [x] **Step 8:** **Godot Editor:** Update `scenes/game.tscn`:

1. Open `scenes/game.tscn` in the Godot editor
2. Under UI (CanvasLayer):
   - Delete or rename SpawnButton
   - Add a new Button, name it "SwordsmanButton"
   - Add another new Button, name it "ArcherButton"
   - Position them side by side (manually position as desired)
3. Select the Game root node
4. In the Inspector, assign the scene exports:
   - `Swordsman Scene` → `scenes/swordsman.tscn`
   - `Archer Scene` → `scenes/archer.tscn`
   - `Enemy Scene` → `scenes/enemy.tscn`
5. Save the scene

**Verify:** Ask user to:

1. Run the game
2. Click "Add Swordsman" - a swordsman should appear at a spawn slot
3. Click "Add Archer" - an archer should appear at the next slot
4. Click "Fight!" - units should move and fight
5. Archers should fire projectiles at enemies from range
6. Swordsmen should engage in melee combat
7. Battle should resolve normally

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 7: Clean up old files

**Files:** `scenes/unit.tscn`

- [x] **Step 1:** Delete `scenes/unit.tscn` (it's no longer needed, replaced by swordsman/archer/enemy scenes)

**Verify:** Confirm the file is deleted and the game still runs correctly.

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [x] Can click "Add Swordsman" to spawn a melee player unit
- [x] Can click "Add Archer" to spawn a ranged player unit
- [x] Enemies spawn as separate enemy.tscn scenes
- [x] Swordsmen engage enemies in melee combat (short range)
- [x] Archers fire projectiles at enemies from long range
- [x] Projectiles travel toward target, hit enemies, deal damage, then disappear
- [x] Projectiles disappear when leaving the screen
- [x] Projectiles ignore friendly units
- [x] Attack animations scale to match attack cooldown
- [x] All unit stats are editable in the Inspector
- [x] Battle resolves correctly (win/lose conditions work)
- [x] Restart works and resets everything properly
