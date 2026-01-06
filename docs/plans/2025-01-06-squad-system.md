# Squad System Implementation Plan

**Goal:** Replace individual unit placement with squad-based system where one draggable squad spawns multiple units at predefined positions.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Create Squad scene and script
- [x] Task 2: Add count stat to data structures
- [x] Task 3: Update Game to spawn squads instead of individual units
- [x] Task 4: Update recruiting to copy count
- [x] Task 5: Update UI to display count stat

---

## Summary

**Task 1: Create Squad scene and script** — Create new Squad container that holds multiple units and handles drag-and-drop.

**Task 2: Add count stat to data structures** — Add count export to Unit script and count field to ArmyUnit class.

**Task 3: Update Game to spawn squads instead of individual units** — Modify placement logic to instantiate Squad scenes that spawn their member units.

**Task 4: Update recruiting to copy count** — When recruiting enemies or creating army units, copy the count stat from Unit to ArmyUnit.

**Task 5: Update UI to display count stat** — Show squad count in the unit summary display.

---

## Tasks

### Task 1: Create Squad scene and script

**Files:** `scenes/squad.tscn`, `scripts/squad.gd`

- [ ] **Step 1:** **Godot Editor:** Create new scene `scenes/squad.tscn`:

  1. Create new scene in Godot
  2. Set root node as Node2D named "Squad"
  3. Add 6 Marker2D children named "Position1", "Position2", "Position3", "Position4", "Position5", "Position6"
  4. Position the markers where units should spawn (user will handle positioning)
  5. Move the DragHandle node from `units/unit.tscn` to this Squad scene as a child
  6. Save as `scenes/squad.tscn`

- [ ] **Step 2:** Create `scripts/squad.gd` with the following structure:

```gdscript
extends Node2D
class_name Squad

## Container for spawning multiple units in formation
## Handles drag-and-drop for the entire squad

var army_index := -1  # Index in Game.army array
var spawn_slot: SpawnSlot = null  # Which spawn slot this squad occupies
var drag_handle: UnitDragHandle = null  # Reference to drag handle child

@onready var position_markers: Array[Marker2D] = []


func _ready() -> void:
	# Collect position markers
	for i in range(1, 7):
		var marker := get_node_or_null("Position%d" % i) as Marker2D
		if marker:
			position_markers.append(marker)

	# Get drag handle reference
	drag_handle = get_node_or_null("DragHandle") as UnitDragHandle


func setup(unit_scene: PackedScene, count: int, upgrades: Dictionary, is_enemy: bool, enemy_container: Node2D, friendly_container: Node2D) -> void:
	"""Instantiate units at marker positions and configure them."""
	if unit_scene == null:
		push_error("Squad.setup called with null unit_scene")
		return

	# Clamp count to available positions
	var spawn_count := mini(count, position_markers.size())

	# Spawn units at first 'count' positions
	for i in range(spawn_count):
		var marker := position_markers[i]
		var unit: Unit = unit_scene.instantiate() as Unit
		if unit == null:
			push_error("Failed to instantiate unit in squad")
			continue

		# Configure unit properties BEFORE adding to tree
		unit.is_enemy = is_enemy
		unit.enemy_container = enemy_container
		unit.friendly_container = friendly_container
		unit.upgrades = upgrades.duplicate()
		unit.army_index = army_index  # Pass through army_index to units

		# Add unit as child at marker position
		add_child(unit)
		unit.position = marker.position

		# Store initial Y position (relative to squad)
		unit.initial_y_position = unit.global_position.y

		# Apply upgrades after added to tree
		unit.apply_upgrades()

		# Connect death signal if it's a player unit
		if not is_enemy:
			unit.player_unit_died.connect(_on_unit_died)


func _on_unit_died(unit_army_index: int) -> void:
	"""Forward unit death signal (units just disappear, no squad tracking needed)."""
	# Unit will remove itself, squad doesn't need to track deaths
	# All units respawn fresh for next battle
	pass
```

- [ ] **Step 3:** **Godot Editor:** Link script to scene:

  1. Open `scenes/squad.tscn`
  2. Select the Squad root node
  3. In Inspector, attach `scripts/squad.gd` as the script
  4. Save the scene

- [ ] **Step 4:** Update `scripts/unit_drag_handle.gd` to work with Squad parent instead of Unit parent:

Replace the `_get_drag_data` function (lines 34-82) with:

```gdscript
func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Handle drag-and-drop during preparation phase."""
	# Get parent (could be Unit or Squad)
	var parent := get_parent()
	if not parent:
		return null

	# Check phase - only allow dragging during preparation
	var game := get_tree().get_first_node_in_group("game") as Game
	if not game:
		return null

	if game.phase != "preparation":
		return null

	# Get army_index (works for both Unit and Squad)
	var parent_army_index := -1
	if parent.has("army_index"):
		parent_army_index = parent.army_index

	if parent_army_index < 0:
		return null

	if spawn_slot == null:
		return null

	# Create drag preview
	var preview: Control = null

	# Try to get sprite from first unit child (if parent is Squad)
	var sprite_frames: SpriteFrames = null
	if parent is Squad:
		# Get first Unit child's sprite
		for child in parent.get_children():
			if child is Unit:
				var unit := child as Unit
				if unit.animated_sprite and unit.animated_sprite.sprite_frames:
					sprite_frames = unit.animated_sprite.sprite_frames
					break
	elif parent is Unit:
		var unit := parent as Unit
		if unit.animated_sprite and unit.animated_sprite.sprite_frames:
			sprite_frames = unit.animated_sprite.sprite_frames

	if drag_preview_scene and sprite_frames:
		preview = drag_preview_scene.instantiate() as Control
		if preview:
			var preview_sprite: AnimatedSprite2D = preview.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if preview_sprite:
				preview_sprite.sprite_frames = sprite_frames
				preview_sprite.play("idle")
	else:
		# Fallback
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview

	set_drag_preview(preview)

	# Return drag data
	return {
		"army_index": parent_army_index,
		"source_spawn_slot": spawn_slot,
		"is_repositioning": true
	}
```

**Verify:**

- Ask user to confirm:
  - Squad scene exists at `scenes/squad.tscn` with 6 Position markers
  - Squad script is attached
  - DragHandle has been moved from unit.tscn to squad.tscn
  - No errors in Godot console

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Add count stat to data structures

**Files:** `scripts/unit.gd`, `scripts/army_unit.gd`

- [ ] **Step 1:** Add count export to `scripts/unit.gd` after existing @export variables (around line 40):

```gdscript
@export var upgrade_cost := 5  # Cost per upgrade (HP or Damage)
@export var count := 1  # How many units spawn in a squad (default 1 for backwards compatibility)
```

- [ ] **Step 2:** Add count field to `scripts/army_unit.gd` after existing fields (around line 7):

```gdscript
var upgrades: Dictionary = {}
var count: int = 1  # Squad size
```

- [ ] **Step 3:** Update `ArmyUnit.create_from_enemy()` to copy count (around line 9):

Replace the entire function with:

```gdscript
static func create_from_enemy(enemy_dict: Dictionary) -> ArmyUnit:
	"""Create an ArmyUnit from enemy dictionary data."""
	var army_unit := ArmyUnit.new()
	army_unit.unit_scene = enemy_dict.get("unit_scene")
	army_unit.unit_type = enemy_dict.get("unit_type", "")
	army_unit.upgrades = enemy_dict.get("upgrades", {}).duplicate()
	army_unit.count = enemy_dict.get("count", 1)  # Copy count if present
	army_unit.placed = false
	return army_unit
```

**Verify:**

- Ask user to confirm:
  - No linter errors in `scripts/unit.gd` or `scripts/army_unit.gd`
  - Count field exists with default value of 1

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update Game to spawn squads instead of individual units

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Update `place_unit_from_army()` function (starts around line 577) to spawn Squad instead of Unit:

Replace the entire function with:

```gdscript
func place_unit_from_army(army_index: int, slot: SpawnSlot) -> void:
	"""Place a squad from the army array onto a spawn slot."""
	if slot.is_occupied:
		return

	if army_index < 0 or army_index >= army.size():
		push_error("Invalid army index: %d (army size: %d)" % [army_index, army.size()])
		return

	var army_unit: ArmyUnit = army[army_index]
	if army_unit.placed:
		push_warning("Army unit at index %d already placed" % army_index)
		return

	if army_unit.unit_scene == null:
		push_error("Army unit at index %d has no unit_scene" % army_index)
		return

	# Load squad scene
	var squad_scene := preload("res://scenes/squad.tscn")
	var squad: Squad = squad_scene.instantiate() as Squad
	if squad == null:
		push_error("Failed to instantiate squad")
		return

	# Add squad to level's player_units container
	current_level.player_units.add_child(squad)

	# Set squad position to slot center
	squad.global_position = slot.get_slot_center()

	# Store references
	squad.army_index = army_index
	squad.spawn_slot = slot

	# Update drag handle's spawn slot reference
	if squad.drag_handle:
		squad.drag_handle.spawn_slot = slot

	# Setup squad (spawns units)
	squad.setup(
		army_unit.unit_scene,
		army_unit.count,
		army_unit.upgrades,
		false,  # is_enemy
		current_level.enemy_units,
		current_level.player_units
	)

	# Mark slot as occupied
	slot.set_occupied(true)

	# Mark army slot as placed
	army_unit.placed = true
	army_unit_placed.emit(army_index)

	# Notify HUD that a unit was placed
	unit_placed.emit(army_unit.unit_type)
```

- [ ] **Step 2:** Update `_on_player_unit_died()` function (search for it in game.gd) to handle units dying from squads:

The function should already work because individual units still emit the signal. Just verify the function exists and doesn't need changes. If it references removing units from containers, it should still work because units are children of Squad which is a child of player_units.

**Verify:**

- Ask user to:
  - Run the game
  - Start a battle (or draft screen)
  - Drag a unit from tray to battlefield
  - Confirm that multiple units appear (if count > 1 on any unit)
  - Confirm the units can be dragged as a group
  - Check console for errors

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Update recruiting to copy count

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Find the `recruit_enemy()` function (around line 634) and update it to copy count from unit scene:

After line where we instantiate the unit to check its cost (search for "unit_instance.base_recruit_cost"), add code to read count:

Find this section (around line 650-670):

```gdscript
# Get cost from unit scene
var unit_instance := enemy_scene.instantiate() as Unit
if unit_instance == null:
	push_error("Failed to instantiate unit for recruit cost check")
	return
var base_cost := unit_instance.base_recruit_cost
var upgrade_cost := unit_instance.upgrade_cost
unit_instance.queue_free()
```

Change it to:

```gdscript
# Get cost and count from unit scene
var unit_instance := enemy_scene.instantiate() as Unit
if unit_instance == null:
	push_error("Failed to instantiate unit for recruit cost check")
	return
var base_cost := unit_instance.base_recruit_cost
var upgrade_cost := unit_instance.upgrade_cost
var unit_count := unit_instance.count  # Get squad size
unit_instance.queue_free()
```

- [ ] **Step 2:** When creating the new ArmyUnit in the same function, set the count field:

Find where we create the ArmyUnit (search for "new_army_unit := ArmyUnit.new()") and add:

```gdscript
new_army_unit.count = unit_count  # Copy squad size
```

- [ ] **Step 3:** Update the draft screen population in `show_draft_screen()` function (around line 153) to copy count:

Find this section:

```gdscript
for unit_scene in roster.units:
	var army_unit := ArmyUnit.new()
	army_unit.unit_scene = unit_scene
	army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
	army_unit.placed = false
	army_unit.upgrades = {}
	draft_roster.append(army_unit)
```

Change it to:

```gdscript
for unit_scene in roster.units:
	var army_unit := ArmyUnit.new()
	army_unit.unit_scene = unit_scene
	army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
	army_unit.placed = false
	army_unit.upgrades = {}

	# Get count from unit scene
	var temp_unit := unit_scene.instantiate() as Unit
	if temp_unit:
		army_unit.count = temp_unit.count
		temp_unit.queue_free()
	else:
		army_unit.count = 1

	draft_roster.append(army_unit)
```

**Verify:**

- Ask user to:
  - Run game and complete a battle
  - Recruit an enemy unit from the upgrade screen
  - Check that the recruited unit shows correct count
  - Start draft screen and verify units have count values

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Update UI to display count stat

**Files:** `scripts/unit_summary.gd`

- [ ] **Step 1:** Find where UnitSummary displays stats and add count display:

Search for where stats are displayed in `show_unit_from_scene()` function. Add count to the stats display after damage or another stat.

Look for the section that creates stat labels (search for "HP:" or "DMG:" or similar). Add a count display:

```gdscript
# Add after other stat displays (HP, DMG, etc.)
var count_label := Label.new()
count_label.text = "Count: %d" % unit_instance.count
# Add to appropriate container (follow existing pattern for other stats)
```

Note: The exact implementation depends on how UnitSummary is structured. Follow the existing pattern for displaying HP, damage, etc.

- [ ] **Step 2:** If UnitSummary has an icon-based display (like in unit slots), add a count badge:

If there's a visual display with unit icons, consider adding a small "x5" type badge. This may require Godot editor work to add a label node.

**Verify:**

- Ask user to:
  - Run game
  - Open upgrade screen or recruit screen
  - Select a unit
  - Confirm count stat is visible in the unit summary
  - Verify count shows correct value

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Squad scene exists with 6 position markers and drag handle
- [ ] Dragging a unit from tray spawns a squad with multiple units
- [ ] All units in squad move together when dragged
- [ ] Count stat displays in unit summary UI
- [ ] Recruiting copies count from unit scene to army unit
- [ ] Game can be played through draft → battle → upgrade cycle without errors
- [ ] Individual units in squad still fight independently
- [ ] No console errors during normal gameplay
