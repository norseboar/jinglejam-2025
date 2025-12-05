# ✅ Artillery Attack Implementation Plan

**Goal:** Add artillery-style attack for Dwarf Mortarman with delayed impact, falling projectile, target marker, and AOE damage.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

> ⚠️ **IMPORTANT:** Tasks 1 and 4 require Godot Editor work (creating/editing .tscn files). **STOP and ask the user to perform these steps manually.** Do NOT attempt to edit .tscn files programmatically.

---

## Status

- [x] Task 1: Create target marker scene
- [x] Task 2: Create artillery projectile
- [x] Task 3: Create artillery unit script
- [x] Task 4: Update Dwarf Mortarman to use artillery attack

---

## Summary

**Task 1: Create target marker scene** — Create a simple sprite scene that marks where the artillery shell will land.

**Task 2: Create artillery projectile** — Create a projectile that spawns off-screen, falls straight down, and deals AOE damage on impact.

**Task 3: Create artillery unit script** — Create a unit script that fires artillery: spawns marker, waits delay, spawns falling projectile.

**Task 4: Update Dwarf Mortarman to use artillery attack** — Change dwarf_mortarman.tscn to use the new artillery script and configure stats.

---

## Tasks

### ✅ Task 1: Create target marker scene

**Files:** `scenes/effects/target_marker.tscn`, `assets/sprites/effects/target_marker.png`

> ⚠️ **This entire task requires Godot Editor work. STOP and ask the user to perform these steps.**

- [ ] **Step 1:** **Godot Editor:** Create a placeholder target marker sprite:

1. Create folder `assets/sprites/effects/` if it doesn't exist
2. Create a simple circular/crosshair image (64x64 pixels) for the target marker, or use a placeholder colored circle
3. Save as `assets/sprites/effects/target_marker.png`

- [ ] **Step 2:** **Godot Editor:** Create `scenes/effects/target_marker.tscn`:

1. Create folder `scenes/effects/` if it doesn't exist
2. Create a new scene (Scene → New Scene)
3. Add a Sprite2D as root, rename it to "TargetMarker"
4. Assign the target marker texture to the Sprite2D
5. Set the modulate color to something visible (e.g., red with some transparency: `Color(1, 0, 0, 0.7)`)
6. Save as `scenes/effects/target_marker.tscn`

**Verify:** Ask user to confirm target_marker.tscn was created and shows a visible marker sprite.

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create artillery projectile

**Files:** `scripts/artillery_projectile.gd`

- [ ] **Step 1:** Create `scripts/artillery_projectile.gd`:

```gdscript
extends Node2D
class_name ArtilleryProjectile

## Projectile that falls from the sky and deals AOE damage on impact.

var speed := 400.0  # Fall speed, set by spawning unit
var damage := 1  # Set by spawning unit
var aoe_radius := 100.0  # Set by spawning unit
var armor_piercing := false  # Set by spawning unit

var target_position := Vector2.ZERO  # Where the projectile will land
var enemy_container: Node2D = null  # Container of valid targets

var target_marker: Node2D = null  # Reference to the marker to remove on impact


func _process(delta: float) -> void:
	# Move straight down
	position.y += speed * delta

	# Check if we've reached the target Y position
	if position.y >= target_position.y:
		_on_impact()


func _on_impact() -> void:
	# Deal AOE damage to all enemies in radius
	if enemy_container != null:
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue

			# Skip other projectiles
			if enemy is Projectile or enemy is ArtilleryProjectile:
				continue

			# Skip dead or dying units
			if enemy is Unit:
				if enemy.current_hp <= 0 or enemy.state == "dying":
					continue

			# Check if enemy is within AOE radius
			var distance := target_position.distance_to(enemy.position)
			if distance <= aoe_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, armor_piercing)

	# Remove the target marker
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.queue_free()

	# Destroy the projectile
	queue_free()


## Initialize the artillery projectile
func setup(target_pos: Vector2, targets: Node2D, dmg: int, radius: float, pierce: bool = false) -> void:
	target_position = target_pos
	enemy_container = targets
	damage = dmg
	aoe_radius = radius
	armor_piercing = pierce

	# Position at target X, but off-screen above (will be set by spawner)
	position.x = target_pos.x
```

**Verify:** Ask user to check that the file was created and has no syntax errors (open in Godot).

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Create artillery unit script

**Files:** `scripts/artillery_unit.gd`

- [ ] **Step 1:** Create `scripts/artillery_unit.gd`:

```gdscript
extends Unit
class_name ArtilleryUnit

## Artillery unit that fires indirect attacks - projectile goes up, lands on target with AOE damage.

@export var projectile_scene: PackedScene
@export var projectile_speed := 400.0  # Fall speed of the projectile
@export var target_marker_scene: PackedScene
@export var hit_delay := 1.5  # Seconds between animation finish and projectile spawn
@export var aoe_radius := 100.0  # Radius of impact damage

# Stored target position for the artillery strike
var _artillery_target_position := Vector2.ZERO
var _current_target_marker: Node2D = null


## Override to spawn target marker, wait, then spawn falling projectile
func _apply_attack_damage() -> void:
	if target == null or not is_instance_valid(target):
		return

	if projectile_scene == null:
		push_error("ArtilleryUnit has no projectile_scene assigned!")
		return

	# Store the target position at the moment of firing
	_artillery_target_position = target.global_position

	# Spawn target marker
	_spawn_target_marker()

	# Wait for hit_delay, then spawn the projectile
	get_tree().create_timer(hit_delay).timeout.connect(_spawn_artillery_projectile)


func _spawn_target_marker() -> void:
	if target_marker_scene == null:
		push_warning("ArtilleryUnit has no target_marker_scene assigned!")
		return

	_current_target_marker = target_marker_scene.instantiate()
	get_parent().add_child(_current_target_marker)
	_current_target_marker.global_position = _artillery_target_position


func _spawn_artillery_projectile() -> void:
	# Spawn projectile
	var projectile: ArtilleryProjectile = projectile_scene.instantiate() as ArtilleryProjectile
	if projectile == null:
		push_error("Failed to instantiate artillery projectile!")
		# Clean up marker if projectile fails
		if _current_target_marker != null and is_instance_valid(_current_target_marker):
			_current_target_marker.queue_free()
		return

	# Add to scene tree
	get_parent().add_child(projectile)

	# Position off-screen above the target
	# Get the viewport height and position above it
	var viewport_rect := get_viewport_rect()
	var spawn_y := viewport_rect.position.y - 50  # 50 pixels above top of screen
	projectile.global_position = Vector2(_artillery_target_position.x, spawn_y)

	# Setup projectile
	projectile.setup(_artillery_target_position, enemy_container, damage, aoe_radius, armor_piercing)
	projectile.speed = projectile_speed
	projectile.target_marker = _current_target_marker

	# Clear our reference (projectile now owns the marker)
	_current_target_marker = null
```

**Verify:** Ask user to check that the file was created and has no syntax errors (open in Godot).

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Update Dwarf Mortarman to use artillery attack

**Files:** `units/dwarves/dwarf_mortarman.tscn`, `units/dwarves/projectile_mortar.tscn`

> ⚠️ **This entire task requires Godot Editor work. STOP and ask the user to perform these steps. Do NOT attempt to edit .tscn files programmatically.**

- [ ] **Step 1:** **Godot Editor:** Update `units/dwarves/projectile_mortar.tscn` to use ArtilleryProjectile:

1. Open `units/dwarves/projectile_mortar.tscn` in the Godot editor
2. Select the root Projectile node
3. Change the script from `scripts/projectile.gd` to `scripts/artillery_projectile.gd`
4. Save the scene

> ⚠️ **STOP after Step 1 and confirm with user before continuing to Step 2.**

- [ ] **Step 2:** **Godot Editor:** Update `units/dwarves/dwarf_mortarman.tscn` to use ArtilleryUnit:

1. Open `units/dwarves/dwarf_mortarman.tscn` in the Godot editor
2. Select the root Dwarf_mortarman node
3. Change the script from `scripts/archer.gd` to `scripts/artillery_unit.gd`
4. In the Inspector, configure the new export variables:
   - `projectile_scene`: Keep as `units/dwarves/projectile_mortar.tscn`
   - `projectile_speed`: Set to `600.0` (fast fall)
   - `target_marker_scene`: Set to `scenes/effects/target_marker.tscn`
   - `hit_delay`: Set to `1.0` (1 second delay)
   - `aoe_radius`: Set to `80.0` (adjust as needed)
5. Save the scene

**Verify:** Ask user to:

1. Start a battle with a Dwarf Mortarman
2. Watch the mortarman attack - should see:
   - Attack animation plays
   - Target marker appears on the ground at enemy position
   - After ~1 second, projectile falls from top of screen
   - Projectile hits target, marker disappears
   - Enemies in the area take damage

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [x] Target marker appears when Dwarf Mortarman finishes attack animation
- [x] Projectile spawns off-screen and falls straight down after hit_delay
- [x] Projectile lands on target position and deals damage to nearby enemies
- [x] Target marker disappears on impact
- [x] AOE damage only affects enemies, not friendly units
- [x] All stats (hit_delay, aoe_radius, projectile_speed) are configurable in the editor
- [x] No errors in the console during artillery attacks
