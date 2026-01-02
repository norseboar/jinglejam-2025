# Collision and Pathfinding System Implementation Plan

**Goal:** Replace the current boundary system with tilemap-based collision and navigation pathfinding, enabling units to intelligently route around obstacles while checking line of sight for targeting.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Set up collision layers project-wide
- [ ] Task 2: Create shared TileSet resource
- [ ] Task 3: Convert one level to tilemap (proof of concept)
- [ ] Task 4: Add navigation properties to Unit
- [ ] Task 5: Implement line of sight checking
- [ ] Task 6: Add end zone system to LevelRoot
- [ ] Task 7: Update unit movement to use navigation
- [ ] Task 8: Update game.gd to initialize navigation agents
- [ ] Task 9: Update Healer to check LOS
- [ ] Task 10: Update ArtilleryUnit to ignore obstacles
- [ ] Task 11: Clean up old boundary system

---

## Summary

**Task 1: Set up collision layers** — Configure project physics layers for blockers and units.

**Task 2: Create shared TileSet** — Build a reusable TileSet with collision shapes on appropriate layers.

**Task 3: Convert one level to tilemap** — Add tilemap and navigation to bridge.tscn as proof of concept.

**Task 4: Add navigation properties** — Add NavigationAgent2D reference and supporting properties to Unit.gd.

**Task 5: Implement line of sight** — Add raycast-based LOS checking function to Unit.gd.

**Task 6: Add end zone system** — Add end zone positions to LevelRoot for default unit targeting.

**Task 7: Update unit movement** — Modify \_do_movement() to use navigation pathfinding for ground units.

**Task 8: Initialize navigation agents** — Update game.gd to create NavigationAgent2D nodes when spawning units.

**Task 9: Update Healer LOS** — Modify healer.gd to check line of sight to wounded allies.

**Task 10: Update Artillery** — Remove boundary checks from artillery_unit.gd (artillery ignores obstacles).

**Task 11: Clean up boundaries** — Remove old level_bounds_area system from LevelRoot and Unit.

---

## Tasks

### Task 1: Set up collision layers project-wide

**Files:** Project Settings (Godot Editor)

- [ ] **Step 1:** **Godot Editor:** Configure physics layers in Project Settings:
  1. Open Project → Project Settings
  2. Navigate to Layer Names → 2D Physics
  3. Set layer names:
     - Layer 1: "TotalBlockers" (walls, solid obstacles - blocks movement AND line of sight)
     - Layer 2: "MovementBlockers" (low walls, barriers - blocks movement but NOT line of sight)
     - Layer 3: "Units" (for future unit collision if needed)

**After this task:** STOP and ask user to verify the layer names are set correctly in Project Settings.

**Verify:**

- Ask user to confirm layer names appear in Project Settings → Layer Names → 2D Physics

---

### Task 2: Create shared TileSet resource

**Files:** `resources/tilesets/level_tileset.tres` (new), sample tiles

- [ ] **Step 1:** **Godot Editor:** Create a new TileSet resource:

  1. In FileSystem, navigate to `resources/` folder (create if doesn't exist)
  2. Create a subfolder called `tilesets/`
  3. Right-click in `tilesets/` folder → New Resource → TileSet
  4. Save as `level_tileset.tres`

- [ ] **Step 2:** **Godot Editor:** Add sample tiles to the TileSet:

  1. Open `level_tileset.tres` in the TileSet editor (bottom panel)
  2. For now, create 3 placeholder tiles:
     - Tile 0: "Floor" (no collision)
     - Tile 1: "Wall" (collision on Layer 1 - TotalBlockers)
     - Tile 2: "Low Barrier" (collision on Layer 2 - MovementBlockers)
  3. For each tile with collision:
     - Select the tile
     - In the right panel, go to Physics Layer 0 (or add physics layers)
     - Draw collision polygon covering the tile area
     - Set the collision layer in the tile properties

- [ ] **Step 3:** **Godot Editor:** Configure physics layers on tiles:
  1. For Wall tile (Tile 1): Set physics layer to Layer 1 (TotalBlockers)
  2. For Low Barrier tile (Tile 2): Set physics layer to Layer 2 (MovementBlockers)

**Note:** This creates a minimal TileSet. User can expand it later with actual art and more tile types.

**After this task:** STOP and ask user to verify the TileSet has been created with collision shapes.

**Verify:**

- Ask user to:
  - Open `level_tileset.tres` in TileSet editor
  - Confirm three tiles exist
  - Confirm Wall and Low Barrier tiles have collision shapes on correct layers

---

### Task 3: Convert one level to tilemap (proof of concept)

**Files:** `battlefields/bridge.tscn`

- [ ] **Step 1:** **Godot Editor:** Add TileMapLayer to bridge.tscn:

  1. Open `battlefields/bridge.tscn`
  2. Add a new child node to LevelRoot: TileMapLayer (not TileMap - use the newer TileMapLayer)
  3. Name it "CollisionTiles"
  4. Move it to be above Background in the scene tree (so it renders on top)
  5. In the Inspector, set the TileSet property to load `resources/tilesets/level_tileset.tres`

- [ ] **Step 2:** **Godot Editor:** Paint some example collision tiles:

  1. Select the CollisionTiles node
  2. In the TileMap editor (bottom panel), paint a few wall tiles along the edges
  3. Paint a low barrier somewhere in the middle (to test later)
  4. This is just for testing - user can adjust layout later

- [ ] **Step 3:** **Godot Editor:** Add NavigationRegion2D:

  1. Add a new child node to LevelRoot: NavigationRegion2D
  2. Name it "NavigationRegion"
  3. In the Inspector, create a new NavigationPolygon resource
  4. Set the NavigationPolygon's "Parsed Geometry Type" to "Static Colliders"
  5. Add the CollisionTiles node to the "Parsed Source Group" (might be called source geometry group)
  6. Set "Parsed Collision Mask" to Layer 1 + Layer 2 (both blocker types)

- [ ] **Step 4:** **Godot Editor:** Bake the navigation mesh:

  1. With NavigationRegion selected, click the "Bake NavigationPolygon" button in the toolbar
  2. You should see a blue overlay showing walkable areas (avoiding tiles with collision)

- [ ] **Step 5:** **Godot Editor:** Configure LevelRoot node paths:
  1. Select the LevelRoot node
  2. In the Inspector, verify these node paths are set:
     - `player_units` → should point to a Node2D for player units
     - `enemy_units` → should point to a Node2D for enemy units
  3. If these don't exist, create them as Node2D children of LevelRoot

**After this task:** STOP and ask user to verify the tilemap and navigation are visible in the editor.

**Verify:**

- Ask user to:
  - Open bridge.tscn
  - Confirm CollisionTiles node shows painted tiles
  - Confirm NavigationRegion shows blue walkable area overlay
  - Confirm walkable area avoids collision tiles

---

### Task 4: Add navigation properties to Unit

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add navigation-related properties after the existing properties (around line 70, after `var friendly_container`):

```gdscript
# Navigation system
var navigation_agent: NavigationAgent2D = null  # Set by Game when spawning (ground units only)
var initial_y_position: float = 0.0  # Stored Y position for end zone calculation
var has_line_of_sight_to_target: bool = false  # Whether current target has clear LOS
```

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to check that the game opens without errors (no need to test functionality yet)

---

### Task 5: Implement line of sight checking

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add line of sight checking function after `_get_level_bounds()` (around line 540):

```gdscript
func has_clear_line_of_sight_to(target_unit: Unit) -> bool:
	"""Check if there's a clear line of sight to the target unit.
	Uses raycasting on Layer 1 (TotalBlockers) only.
	Ground and flying units can shoot over Layer 2 (MovementBlockers)."""
	if target_unit == null or not is_instance_valid(target_unit):
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target_unit.global_position)
	query.collision_mask = 1  # Layer 1 only (TotalBlockers)
	query.exclude = [self]  # Don't hit ourselves

	var result := space_state.intersect_ray(query)
	return result.is_empty()  # Clear if no collision
```

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to check that the game opens without errors

---

### Task 6: Add end zone system to LevelRoot

**Files:** `scripts/level_root.gd`

- [ ] **Step 1:** Add end zone properties after the existing exports (around line 25):

```gdscript
## End zone X coordinates for default unit navigation
## Player units move toward end_zone_x_player, enemies move toward end_zone_x_enemy
@export var end_zone_x_player: float = 600.0  # Right side of screen
@export var end_zone_x_enemy: float = 40.0    # Left side of screen
```

- [ ] **Step 2:** Add helper function at the end of the file:

```gdscript
func get_end_zone_position(is_enemy: bool, y_position: float) -> Vector2:
	"""Get the end zone target position for a unit based on their team and Y position.
	Units target the opposite side of the map at their starting Y coordinate."""
	var x := end_zone_x_enemy if is_enemy else end_zone_x_player
	return Vector2(x, y_position)
```

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to:
  - Open any level scene (like bridge.tscn)
  - Select LevelRoot node
  - Confirm end_zone_x_player and end_zone_x_enemy appear in Inspector
  - Check that the game opens without errors

---

### Task 7: Update unit movement to use navigation

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add helper function to get navigation target after the `has_clear_line_of_sight_to()` function:

```gdscript
func _get_navigation_target() -> Vector2:
	"""Determine where the unit should move toward.
	Returns either: enemy position (for melee) or end zone (default/ranged)."""

	# If we have a target with line of sight
	if target != null and is_instance_valid(target) and has_line_of_sight_to_target:
		# Melee units move toward the enemy
		# We don't have a specific "melee" flag, so use attack_range as proxy
		# Units with short range (< 100) are melee, move toward enemy
		if attack_range < 100:
			return target.global_position

	# Default: move toward end zone at our starting Y
	var level := get_tree().get_first_node_in_group("level") as LevelRoot
	if level:
		return level.get_end_zone_position(is_enemy, initial_y_position)

	# Fallback: move in default direction
	var direction := 1.0 if not is_enemy else -1.0
	return global_position + Vector2(direction * 1000.0, 0)
```

- [ ] **Step 2:** Modify `_check_for_targets()` to also check and store line of sight. Replace the section after finding `closest_enemy` (around line 342-362) with:

```gdscript
	if closest_enemy != null:
		target = closest_enemy

		# Check line of sight (unless we're artillery - they ignore obstacles)
		if self is ArtilleryUnit:
			has_line_of_sight_to_target = true  # Artillery always has LOS
		else:
			has_line_of_sight_to_target = has_clear_line_of_sight_to(target as Unit)

		var distance_to_target := position.distance_to(closest_enemy.position)

		# If we're in attack range AND have line of sight, start fighting
		# (Ranged units need LOS to shoot, melee just need to be in range)
		var can_attack := distance_to_target <= (attack_range * 10.0 + 20.0)
		if attack_range < 100:  # Melee unit
			can_attack = can_attack  # Just needs range, not LOS
		else:  # Ranged unit
			can_attack = can_attack and has_line_of_sight_to_target

		if can_attack:
			set_state("fighting")

			# Only set initial attack timing on FIRST combat entry in this battle
			if not has_done_first_combat_entry:
				has_done_first_combat_entry = true
				# Apply stagger delay in the first 0.25 seconds of battle to prevent all units firing at once
				var time_since_battle_start := (Time.get_ticks_msec() - battle_start_time) / 1000.0
				if time_since_battle_start < 0.25:
					# Artillery gets longer stagger (0-0.5s) to spread out their shots more
					var stagger_max := 0.5 if self is ArtilleryUnit else 0.25
					time_since_attack = randf() * stagger_max
				else:
					time_since_attack = 999.0  # Large value = attack immediately
			# After first combat entry, time_since_attack continues tracking naturally
		# Otherwise, we'll keep moving towards them (state stays "moving")
```

- [ ] **Step 3:** Replace the entire `_do_movement()` function (around line 161-228) with navigation-aware movement:

```gdscript
func _do_movement(delta: float) -> void:
	# If unit has fly_height set and hasn't reached it yet, fly to that height first
	if fly_height >= 0 and not has_reached_fly_height:
		var viewport_rect := get_viewport_rect()
		var target_y := viewport_rect.position.y + fly_height  # fly_height is from top of screen
		var current_y := position.y

		# Check if we've reached the target height (with small threshold)
		if abs(current_y - target_y) < 5.0:
			# Snap to exact position and mark as reached
			position.y = target_y
			has_reached_fly_height = true
		else:
			# Fly towards target height
			var direction_y := -1.0 if current_y > target_y else 1.0  # Negative = up, positive = down
			position.y += direction_y * speed * 10.0 * delta

			# Don't overshoot
			if direction_y < 0 and position.y < target_y:
				position.y = target_y
				has_reached_fly_height = true
			elif direction_y > 0 and position.y > target_y:
				position.y = target_y
				has_reached_fly_height = true

		# While flying, don't do normal pathing yet
		return

	# Check for enemies first
	_check_for_targets()

	# Determine where to move
	var nav_target := _get_navigation_target()

	# Flying units ignore navigation and move directly
	if fly_height >= 0:
		var direction_to_target := (nav_target - global_position).normalized()
		var movement := direction_to_target * speed * 10.0 * delta
		position += movement
		animated_sprite.flip_h = direction_to_target.x < 0
		return

	# Ground units use navigation pathfinding
	if navigation_agent != null:
		# Update agent target if needed
		if navigation_agent.is_navigation_finished() or navigation_agent.target_position.distance_to(nav_target) > 50.0:
			navigation_agent.target_position = nav_target

		# Get next position on path
		if not navigation_agent.is_navigation_finished():
			var next_path_position := navigation_agent.get_next_path_position()
			var direction := (next_path_position - global_position).normalized()

			var movement := direction * speed * 10.0 * delta
			var separation := _apply_separation_force() * delta
			position += movement + separation

			animated_sprite.flip_h = direction.x < 0
	else:
		# Fallback if no navigation agent (shouldn't happen, but safe)
		# Move directly toward target
		var direction_to_target := (nav_target - global_position).normalized()
		var movement := direction_to_target * speed * 10.0 * delta
		var separation := _apply_separation_force() * delta
		position += movement + separation
		animated_sprite.flip_h = direction_to_target.x < 0
```

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to check that the game opens without errors (units won't pathfind properly yet because agents aren't created)

---

### Task 8: Update game.gd to initialize navigation agents

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Add navigation agent creation to `place_unit_from_army()`. After the line `unit.global_position = slot.get_slot_center()` (around line 620), add:

```gdscript
	# Store initial Y position for end zone calculation
	unit.initial_y_position = unit.global_position.y

	# Create navigation agent for ground units
	if unit.fly_height < 0:
		var nav_agent := NavigationAgent2D.new()
		nav_agent.path_desired_distance = 10.0
		nav_agent.target_desired_distance = 20.0
		nav_agent.radius = 16.0
		nav_agent.avoidance_enabled = true
		unit.add_child(nav_agent)
		unit.navigation_agent = nav_agent
		# Wait one frame for navigation to be ready
		await get_tree().process_frame
```

- [ ] **Step 2:** Add the same navigation agent creation to `_spawn_enemies_from_level()`. After the line `enemy.global_position = enemy_marker.global_position` (around line 457), add:

```gdscript
		# Store initial Y position for end zone calculation
		enemy.initial_y_position = enemy.global_position.y

		# Create navigation agent for ground units
		if enemy.fly_height < 0:
			var nav_agent := NavigationAgent2D.new()
			nav_agent.path_desired_distance = 10.0
			nav_agent.target_desired_distance = 20.0
			nav_agent.radius = 16.0
			nav_agent.avoidance_enabled = true
			enemy.add_child(nav_agent)
			enemy.navigation_agent = nav_agent
```

- [ ] **Step 3:** Add the same navigation agent creation to `_spawn_enemies_from_generated_army()`. After the line `enemy.global_position = slot.global_position` (around line 514), add:

```gdscript
		# Store initial Y position for end zone calculation
		enemy.initial_y_position = enemy.global_position.y

		# Create navigation agent for ground units
		if enemy.fly_height < 0:
			var nav_agent := NavigationAgent2D.new()
			nav_agent.path_desired_distance = 10.0
			nav_agent.target_desired_distance = 20.0
			nav_agent.radius = 16.0
			nav_agent.avoidance_enabled = true
			enemy.add_child(nav_agent)
			enemy.navigation_agent = nav_agent
```

**After this task:** STOP and ask user to verify navigation agents are created.

**Verify:**

- Ask user to:
  - Run the game
  - Start a battle
  - Pause and inspect a ground unit in the Remote scene tree
  - Confirm it has a NavigationAgent2D child node
  - Resume and observe if units are pathfinding around obstacles

---

### Task 9: Update Healer to check LOS

**Files:** `scripts/healer.gd`

- [ ] **Step 1:** Modify `_check_for_targets()` to filter allies by line of sight. Find the section that loops through friendlies (around line 118-150) and add LOS check. Replace the loop that finds `closest_ally` with:

```gdscript
	# Find closest wounded ally with clear line of sight
	for ally in friendly_container.get_children():
		if not is_instance_valid(ally):
			continue
		if not ally is Unit:
			continue

		var ally_unit := ally as Unit

		# Skip self
		if ally_unit == self:
			continue

		# Skip dead or dying units
		if ally_unit.current_hp <= 0 or ally_unit.state == "dying":
			continue

		# Skip allies at full HP
		if ally_unit.current_hp >= ally_unit.max_hp:
			continue

		# Check line of sight (healers can't heal through walls)
		if not has_clear_line_of_sight_to(ally_unit):
			continue

		var distance := position.distance_to(ally_unit.position)

		# Check if ally is within detection range
		if distance < detection_range and distance < closest_distance:
			closest_ally = ally_unit
			closest_distance = distance
```

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to:
  - Check that the game opens without errors
  - If possible, test with a healer unit to see if it respects obstacles

---

### Task 10: Update ArtilleryUnit to ignore obstacles

**Files:** `scripts/artillery_unit.gd`

- [ ] **Step 1:** Remove the `_is_position_within_bounds()` function entirely (around lines 119-128)

- [ ] **Step 2:** Remove all calls to `_is_position_within_bounds()`. Find the lines that call this function (around lines 43, 65, 95) and delete those checks. The pattern looks like:

```gdscript
# Filter out targets outside level bounds
if not _is_position_within_bounds(unit_enemy.global_position):
	continue
```

Delete those 3 lines in each place they appear.

**After this task:** STOP and ask user to verify no syntax errors.

**Verify:**

- Ask user to:
  - Check that the game opens without errors
  - Artillery units should target any visible enemy, ignoring obstacles

---

### Task 11: Clean up old boundary system

**Files:** `scripts/level_root.gd`, `scripts/unit.gd`, `scripts/healer.gd`

- [ ] **Step 1:** Remove boundary exports and function from `scripts/level_root.gd`. Delete:

  - The `level_bounds_area` export (around line 25)
  - The entire `get_level_bounds()` function (around lines 31-76)

- [ ] **Step 2:** Remove boundary checking from `scripts/unit.gd`. Find and delete the boundary constraint code in the old `_do_movement()` function if any remains (should be gone from Task 7, but double-check around line 216-228 in the original)

- [ ] **Step 3:** Remove boundary checking from `scripts/healer.gd`. Find and delete the boundary constraint code (around lines 100-110):

```gdscript
	# Constrain ground units (fly_height < 0) to level bounds (same as base Unit)
	if fly_height < 0:
		var bounds := _get_level_bounds()
		if not bounds.is_empty():
			var min_y: float = bounds.get("min_y", 0.0) as float
			var max_y: float = bounds.get("max_y", 360.0) as float
			var global_y: float = global_position.y
			var clamped_global_y: float = clamp(global_y, min_y, max_y)
			# Convert back to local position
			if clamped_global_y != global_y:
				global_position.y = clamped_global_y
```

- [ ] **Step 4:** **Godot Editor:** Remove level_bounds_area from existing levels:
  1. Open each level scene (bridge.tscn, etc.)
  2. Find and delete the PlayArea or level_bounds_area Control node
  3. Select LevelRoot node and clear the level_bounds_area export in Inspector

**After this task:** STOP and ask user to verify the old system is fully removed.

**Verify:**

- Ask user to:
  - Search codebase for "level_bounds_area" - should only appear in comments/deprecated notes
  - Search for "get_level_bounds()" - should not appear
  - Run the game and confirm units still move correctly (using navigation instead)

---

## Exit Criteria

- [ ] Bridge level (or one test level) has working tilemap with collision
- [ ] Navigation mesh is baked and visible in editor
- [ ] Ground units pathfind around obstacles using NavigationAgent2D
- [ ] Flying units ignore obstacles and move directly
- [ ] Ranged units only shoot when they have line of sight to target
- [ ] Melee units pathfind toward enemies once in line of sight
- [ ] Artillery units ignore all obstacles and shoot anything in range
- [ ] Healers check line of sight before healing allies
- [ ] Units naturally funnel through chokepoints
- [ ] Old level_bounds_area system is completely removed
- [ ] No console errors when running the game
