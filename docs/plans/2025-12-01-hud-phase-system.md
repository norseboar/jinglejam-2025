# HUD & Phase UX Implementation Plan

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

**Goal:** Add a reusable HUD, drag-and-drop spawn slots, level scenes, and modal-driven phase flow with prep/battle/upgrade states.

---

## Status

- [x] Task 0: Scene restructure
- [x] Task 1: HUD scene & script
- [x] Task 2: SpawnSlot scene
- [ ] Task 3: Level scenes setup
- [ ] Task 4: Game phase/level logic
- [ ] Task 5: Drag-drop wiring

---

## Summary

**Task 0: Scene restructure** — Remove fortress, move spawn slots to level scenes, add LevelContainer, and update game.gd paths/logic for the new SubViewport structure.

**Task 1: HUD scene & script** — Build `hud.tscn` with phase label, tray grid, Go button, and upgrade modal wired to a new script.

**Task 2: SpawnSlot scene** — Create `spawn_slot.tscn` with visual square and highlighting support.

**Task 3: Level scenes setup** — Add three level scenes that instance SpawnSlot and enemy markers.

**Task 4: Game phase/level logic** — Update `scripts/game.gd` to track levels, phases, HUD interactions, and victory modal confirmation.

**Task 5: Drag-drop wiring** — Hook HUD drag signals to unit placement logic with slot highlighting.

---

## Tasks

### ✅ Task 0: Scene restructure

**Files:** `scenes/game.tscn`, `scripts/game.gd`

This task reorganizes the scene tree for the new SubViewport structure and prepares for level scenes.

**Current structure (in SubViewport):**

```
UI (CanvasLayer)
GameWorld (Node2D)
├── Fortress (REMOVE)
├── EnemySpawnSlots (REMOVE - will come from level scenes)
├── PlayerSpawnSlots (REMOVE - will come from level scenes)
├── PlayerUnits (KEEP)
└── EnemyUnits (KEEP)
```

**Target structure (in SubViewport):**

```
UI (CanvasLayer)
└── (HUD will be added here in Task 1)
Gameplay (Node2D)
├── LevelContainer (Node2D) - level scenes load here
├── PlayerUnits (Node2D)
└── EnemyUnits (Node2D)
```

- [x] **Step 1:** **Godot Editor:** In `scenes/game.tscn`, rename `GameWorld` to `Gameplay`.

- [x] **Step 2:** **Godot Editor:** Delete the `Fortress` node under `Gameplay`.

- [x] **Step 3:** **Godot Editor:** Delete the `EnemySpawnSlots` and `PlayerSpawnSlots` nodes under `Gameplay` (they will be provided by level scenes).

- [x] **Step 4:** **Godot Editor:** Add a new `Node2D` named `LevelContainer` as a child of `Gameplay`. This is where level scenes will be loaded at runtime. Ensure it's the first child (above PlayerUnits/EnemyUnits) so units render on top.

- [x] **Step 5:** In `scripts/game.gd`, update the `@onready` node references to use the new SubViewport paths:

Replace:

```gdscript
@onready var fortress: Sprite2D = $Fortress
@onready var player_units: Node2D = $PlayerUnits
@onready var enemy_units: Node2D = $EnemyUnits
@onready var player_spawn_slots: Node2D = $PlayerSpawnSlots
@onready var enemy_spawn_slots: Node2D = $EnemySpawnSlots
```

With:

```gdscript
@onready var background_rect: TextureRect = $BackgroundRect
@onready var gameplay: Node2D = $SubViewportContainer/SubViewport/Gameplay
@onready var level_container: Node2D = $SubViewportContainer/SubViewport/Gameplay/LevelContainer
@onready var player_units: Node2D = $SubViewportContainer/SubViewport/Gameplay/PlayerUnits
@onready var enemy_units: Node2D = $SubViewportContainer/SubViewport/Gameplay/EnemyUnits
```

- [x] **Step 6:** In `scripts/game.gd`, remove or comment out the `player_hp` variable and `_update_hp_display()` function (fortress is gone).

- [x] **Step 7:** In `scripts/game.gd`, remove the `hp_label` export and its validation in `_validate_ui_references()`.

- [x] **Step 8:** In `scripts/game.gd`, update `_end_battle()` to remove fortress damage logic—just determine win/loss by which side has survivors.

- [x] **Step 9:** In `scripts/game.gd`, remove or stub out `_validate_spawn_slots()`, `_get_player_spawn_positions()`, `_get_enemy_spawn_positions()` since spawn slots will come from loaded level scenes (these will be reimplemented in Task 3).

- [x] **Step 10:** Temporarily comment out `_spawn_enemies()` call in `_ready()` and the function body (enemies will spawn from level scenes in Task 4).

**Verify:**

- Ask user to open the project in Godot and confirm:
  - `Gameplay` node exists with `LevelContainer`, `PlayerUnits`, `EnemyUnits` as children
  - No `Fortress` or spawn slot nodes in `Gameplay`
  - Game runs without crash (buttons won't fully work yet since spawn logic is stubbed)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 1: HUD scene & script

**Files:** `scenes/ui/hud.tscn`, `scripts/hud.gd`, `scenes/game.tscn`

The HUD will be a `Control` node (not a CanvasLayer) that gets instanced inside the existing `UI` CanvasLayer in `game.tscn`.

- [x] **Step 1:** **Godot Editor:** Create `scenes/ui/hud.tscn` with a `Control` root named `HUD` set to full-rect anchor (fills parent). Add children for layout.
- [x] **Step 2:** Add a `Label` named `PhaseLabel` that will show text like "Level 1 – Preparation Phase".
- [x] **Step 3:** Add a bottom `Panel` (call it `TrayPanel`) containing a `GridContainer` named `UnitTray` configured for 2 columns × 5 rows (or 5 columns × 2 rows) to hold up to 10 unit icons; include placeholder `Control` nodes as slots.
- [x] **Step 4:** Add a `Button` named `GoButton` near the tray; default text "Go".
- [x] **Step 5:** Add a modal `ColorRect` overlay (`UpgradeModal`) with a `Panel` child that contains a `Label` (`UpgradeLabel`) and a `Button` (`UpgradeConfirmButton`). Hide the modal by default and ensure it blocks mouse input when visible.
- [x] **Step 6:** Attach `scripts/hud.gd` to the HUD root. Define signals `start_battle_requested`, `unit_drag_started(unit_type: String)`, and `upgrade_confirmed(victory: bool)`.
- [x] **Step 7:** Implement `set_phase(phase: String, level: int)` to update `PhaseLabel`, `set_tray_units(unit_defs: Array)` to populate the `UnitTray` placeholders with icons/idle sprites, and `show_upgrade_modal(victory: bool, level: int)` to configure modal text/button state before showing it.
- [x] **Step 8:** Handle Go button press by emitting `start_battle_requested` only when in preparation phase; disable it otherwise.
- [x] **Step 9:** For each unit icon Control, connect input to start a drag (placeholder logic returns the unit type and uses an icon as preview); emit `unit_drag_started`.

- [x] **Step 10:** **Godot Editor:** In `scenes/game.tscn`, delete the old UI elements under `SubViewportContainer/SubViewport/UI` (HpLabel, HBoxContainer with buttons).

- [x] **Step 11:** **Godot Editor:** Instance `scenes/ui/hud.tscn` as a child of the `UI` CanvasLayer in `scenes/game.tscn`.

- [x] **Step 12:** In `scripts/game.gd`, remove the old button/label exports (`swordsman_button`, `archer_button`, `start_button`, `restart_button`, `hp_label`) and add:

```gdscript
@onready var hud: Control = $SubViewportContainer/SubViewport/UI/HUD
```

- [x] **Step 13:** In `scripts/game.gd`, remove `_setup_ui()` and `_validate_ui_references()` functions (HUD handles its own setup). Update `_ready()` to not call these.

**Verify:**

- Ask user to run the game in Godot and confirm:
  - HUD displays with phase label at top showing placeholder text
  - Tray panel visible at bottom with 10 placeholder slots (2×5 grid)
  - Go button visible
  - Modal is hidden by default
  - No old buttons/labels visible

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: SpawnSlot scene

**Files:** `scenes/spawn_slot.tscn`, `scripts/spawn_slot.gd`

- [x] **Step 1:** **Godot Editor:** Create `scenes/spawn_slot.tscn` with `Area2D` root named `SpawnSlot`. Add:

  - `Sprite2D` child - a 32×32 square visual (can be a simple white square texture, or use a ColorRect inside a SubViewport if preferred). Set modulate to a semi-transparent color like `Color(1, 1, 1, 0.3)`.
  - `CollisionShape2D` child with a `RectangleShape2D` matching the sprite size (32×32).

- [x] **Step 2:** Create `scripts/spawn_slot.gd` and attach to the SpawnSlot root:

```gdscript
extends Area2D
class_name SpawnSlot

@export var slot_id: String = ""
@export var is_player_slot: bool = true

var is_occupied: bool = false
var is_highlighted: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func set_highlighted(active: bool) -> void:
	is_highlighted = active
	if sprite:
		sprite.modulate = Color(0, 1, 0, 0.5) if active else Color(1, 1, 1, 0.3)

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.3) if occupied else Color(1, 1, 1, 0.3)

func get_slot_center() -> Vector2:
	return global_position
```

- [x] **Step 3:** **Godot Editor:** Add the SpawnSlot to a group called `spawn_slots` for easy querying.

**Verify:**

- Ask user to open `scenes/spawn_slot.tscn` in Godot, confirm it shows a semi-transparent square. Run a quick test by instancing it somewhere and calling `set_highlighted(true)` to see the color change.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Level scenes setup

**Files:** `levels/level_01.tscn`, `levels/level_02.tscn`, `levels/level_03.tscn`, `scripts/level_root.gd`

Each level scene will have this structure:

```
LevelRoot (Node2D) - with level_root.gd attached
├── EditorBackground (Sprite2D) - visible only in editor for placement reference
├── PlayerSpawnSlots (Node2D)
│   └── SpawnSlot instances (10 total, 2×5 grid)
└── EnemyMarkers (Node2D)
    └── Marker2D nodes (one per enemy to spawn)
```

The level exports a `background_texture` that Game.gd uses to update the global BackgroundRect at runtime. The EditorBackground is for visual reference when editing the level scene but is hidden when the level loads.

- [ ] **Step 1:** Create `scripts/level_root.gd`:

```gdscript
extends Node2D
class_name LevelRoot

## The background texture for this level (applied to Game's BackgroundRect at runtime)
@export var background_texture: Texture2D

@onready var editor_background: Sprite2D = $EditorBackground

func _ready() -> void:
	# Hide the editor-only background at runtime
	if editor_background:
		editor_background.visible = false
```

- [ ] **Step 2:** **Godot Editor:** Create folder `levels/` if it doesn't exist.

- [ ] **Step 3:** **Godot Editor:** Create `levels/level_01.tscn` with a `Node2D` root named `LevelRoot`. Add:

  - Attach `scripts/level_root.gd` to the root
  - `EditorBackground` (Sprite2D) - assign the chess_table.jpg texture, position at (320, 180) to center in 640×360 viewport. This is for editor visibility only.
  - `PlayerSpawnSlots` (Node2D)
  - `EnemyMarkers` (Node2D)
  - In the Inspector, set `background_texture` export to `res://assets/backgrounds/chess_table.jpg`

- [ ] **Step 4:** **Godot Editor:** Under `PlayerSpawnSlots`, instance 10 `SpawnSlot` scenes (from `scenes/spawn_slot.tscn`) arranged in a 2×5 grid. Position them in the left portion of the play area. Suggested layout (adjust based on viewport size 640×360):

  - Row 1 (y ~200): x positions at 100, 140, 180, 220, 260
  - Row 2 (y ~240): x positions at 100, 140, 180, 220, 260

- [ ] **Step 5:** **Godot Editor:** Under `EnemyMarkers`, add 3 `Marker2D` nodes positioned on the right side of the play area (e.g., x ~450-550, y ~180-220). These mark where enemies will spawn.

- [ ] **Step 6:** **Godot Editor:** Duplicate `levels/level_01.tscn` to create `levels/level_02.tscn` and `levels/level_03.tscn`.

- [ ] **Step 7:** **Godot Editor:** Customize each level:
  - `level_01.tscn`: 3 enemy markers (easy), set `background_texture` to chess_table.jpg (or a unique texture)
  - `level_02.tscn`: 4 enemy markers (medium), optionally use a different background
  - `level_03.tscn`: 5 enemy markers (hard), optionally use a different background

**Verify:**

- Ask user to open each level scene in Godot, confirm structure is correct with 10 spawn slots and appropriate enemy markers.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Game phase/level logic

**Files:** `scripts/game.gd`

At this point, Task 0 has removed fortress logic, Task 1 set up HUD, Task 2 created SpawnSlot, and Task 3 created level scenes. This task wires everything together.

- [ ] **Step 1:** Add level tracking variables at the top of `scripts/game.gd`:

```gdscript
# Level management
var level_paths: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
]
var current_level_index := 0

# Current level references (set when level loads)
var current_level: Node2D = null
var player_spawn_slots: Node2D = null
```

- [ ] **Step 2:** Connect HUD signals in `_ready()`:

```gdscript
func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	load_level(current_level_index)
```

- [ ] **Step 3:** Implement `load_level(index: int)`:

```gdscript
func load_level(index: int) -> void:
	# Clear previous level
	if current_level != null:
		current_level.queue_free()
		current_level = null

	# Clear all units
	_clear_all_units()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Load new level scene
	var level_scene := load(level_paths[index]) as PackedScene
	current_level = level_scene.instantiate()
	level_container.add_child(current_level)

	# Update global background from level's exported texture
	if current_level is LevelRoot and current_level.background_texture:
		background_rect.texture = current_level.background_texture

	# Get references from loaded level
	player_spawn_slots = current_level.get_node("PlayerSpawnSlots")

	# Spawn enemies from level's enemy markers
	_spawn_enemies_from_level()

	# Reset all spawn slots to unoccupied
	_reset_spawn_slots()

	# Update HUD
	phase = "preparation"
	hud.set_phase(phase, index + 1)
	_set_spawn_slots_visible(true)
```

- [ ] **Step 4:** Implement `_spawn_enemies_from_level()` to read enemy markers from the loaded level and spawn enemy units:

```gdscript
func _spawn_enemies_from_level() -> void:
	if current_level == null or enemy_scene == null:
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		push_warning("No EnemyMarkers node in level")
		return

	for marker in enemy_markers.get_children():
		if marker is Marker2D:
			var enemy: Unit = enemy_scene.instantiate() as Unit
			enemy_units.add_child(enemy)
			enemy.is_enemy = true
			enemy.enemy_container = player_units
			enemy.global_position = marker.global_position
```

- [ ] **Step 5:** Implement helper functions for spawn slots:

```gdscript
func _set_spawn_slots_visible(visible: bool) -> void:
	if player_spawn_slots != null:
		player_spawn_slots.visible = visible

func _reset_spawn_slots() -> void:
	if player_spawn_slots == null:
		return
	for child in player_spawn_slots.get_children():
		if child is SpawnSlot:
			child.set_occupied(false)
			child.set_highlighted(false)
```

- [ ] **Step 6:** Implement `_on_start_battle_requested()` handler:

```gdscript
func _on_start_battle_requested() -> void:
	if phase != "preparation":
		return

	if player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return

	phase = "battle"
	hud.set_phase(phase, current_level_index + 1)
	_set_spawn_slots_visible(false)

	# Set all units to moving
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("moving")
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("moving")
```

- [ ] **Step 7:** Update `_process()` to check battle end and call `_end_battle(victory: bool)`:

```gdscript
func _process(_delta: float) -> void:
	if phase != "battle":
		return

	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)

	if enemy_count == 0:
		_end_battle(true)  # Player wins
	elif player_count == 0:
		_end_battle(false)  # Player loses
```

- [ ] **Step 8:** Update `_end_battle(victory: bool)`:

```gdscript
func _end_battle(victory: bool) -> void:
	phase = "upgrade"

	# Stop all units
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("idle")
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("idle")

	# Show upgrade modal
	hud.show_upgrade_modal(victory, current_level_index + 1)
```

- [ ] **Step 9:** Implement `_on_upgrade_confirmed(victory: bool)`:

```gdscript
func _on_upgrade_confirmed(victory: bool) -> void:
	if victory:
		# Advance to next level (clamp to last)
		current_level_index = mini(current_level_index + 1, level_paths.size() - 1)
	# else: reload same level (current_level_index unchanged)

	load_level(current_level_index)
```

- [ ] **Step 10:** Remove old functions that are no longer needed: `_on_swordsman_button_pressed`, `_on_archer_button_pressed`, `_on_start_button_pressed`, `_on_restart_button_pressed`, `_get_next_available_slot`, `_spawn_player_unit`. (Unit spawning will be handled via drag-drop in Task 5.)

**Verify:**

- Game won't be fully playable yet (no unit placement), but ask user to run the game and confirm:
  - Level 1 loads with spawn slots visible
  - Enemies appear at marker positions
  - HUD shows "Level 1 – Preparation Phase"
  - Go button doesn't work yet (no units to place)

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Drag-drop wiring

**Files:** `scripts/hud.gd`, `scripts/game.gd`

This task connects the HUD tray drag to actual unit placement on spawn slots.

- [ ] **Step 1:** In `scripts/hud.gd`, implement drag data for unit icons. Each tray slot needs to support Godot's drag-and-drop:

```gdscript
# In hud.gd, for each unit icon in the tray
func _get_drag_data_for_unit(unit_type: String, icon_texture: Texture2D) -> Variant:
	# Create a preview for the drag
	var preview := TextureRect.new()
	preview.texture = icon_texture
	preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(preview)

	# Return data that game.gd can use
	return {"unit_type": unit_type}
```

- [ ] **Step 2:** In `scripts/game.gd`, add a function to handle unit placement on a slot:

```gdscript
func place_unit_on_slot(unit_type: String, slot: SpawnSlot) -> void:
	if slot.is_occupied:
		return

	var unit_scene: PackedScene
	match unit_type:
		"swordsman":
			unit_scene = swordsman_scene
		"archer":
			unit_scene = archer_scene
		_:
			push_error("Unknown unit type: " + unit_type)
			return

	var unit: Unit = unit_scene.instantiate() as Unit
	player_units.add_child(unit)
	unit.is_enemy = false
	unit.enemy_container = enemy_units
	unit.global_position = slot.global_position

	slot.set_occupied(true)
```

- [ ] **Step 3:** In `scripts/spawn_slot.gd`, implement `_can_drop_data` and `_drop_data` to receive dragged units:

```gdscript
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("unit_type"):
		return false
	return not is_occupied

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("unit_type"):
		# Get the game node and call placement
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			game.place_unit_on_slot(data["unit_type"], self)
```

- [ ] **Step 4:** **Godot Editor:** Add the Game node to a group called `game` so SpawnSlot can find it.

- [ ] **Step 5:** In `scripts/spawn_slot.gd`, add visual feedback for drag hover:

```gdscript
func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if not is_occupied:
		set_highlighted(true)

func _on_mouse_exited() -> void:
	set_highlighted(false)
```

- [ ] **Step 6:** In `scripts/hud.gd`, update the tray to disable/hide icons when units are placed (track placed count vs max of 10).

- [ ] **Step 7:** Ensure drag-drop only works during preparation phase by checking `phase` in `_can_drop_data`.

**Verify:**

- Ask user to run the game and:
  - Drag a unit icon from the tray
  - Hover over spawn slots (they should highlight)
  - Drop on an empty slot (unit appears, slot turns gray)
  - Try dropping on an occupied slot (should not work)
  - Click Go to start battle
  - Confirm the full flow works: place units → battle → modal → next level

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Game scene restructured: no fortress, Gameplay node with LevelContainer
- [ ] HUD displays level & phase text, unit tray (2×5), Go button, and upgrade modal
- [ ] SpawnSlot scene created with highlighting support
- [ ] Three level scenes exist with spawn slots and enemy markers
- [ ] Levels load dynamically; enemies spawn from markers
- [ ] Dragging from tray to slots highlights targets and spawns units snapped to slots
- [ ] Battles run without fortress logic; victory/defeat determined by unit elimination
- [ ] Modal confirm advances to next level on win, restarts same level on loss
- [ ] Full loop playable: prep → place units → battle → outcome → next level/restart
