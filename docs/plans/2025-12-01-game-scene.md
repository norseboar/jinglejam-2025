# Game Scene Layout Implementation Plan

**Goal:** Build `game.tscn` — the battlefield with fortress, unit containers, and UI buttons.

**Parent Project:** `docs/project-plan.md` — Task 2

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Set up Game scene structure
- [x] Task 2: Create game.gd script
- [x] Task 3: Position battlefield elements
- [x] Task 4: Set up UI elements

---

## Summary

**Task 1: Set up Game scene structure** — Create the node hierarchy with Fortress, PlayerUnits, EnemyUnits, and UI nodes.

**Task 2: Create game.gd script** — Create the script with basic variables and attach to scene.

**Task 3: Position battlefield elements** — Place fortress on left, configure unit containers with y_sort.

**Task 4: Set up UI elements** — Add and position buttons and HP label.

---

## Tasks

### ✅ Task 1: Set up Game scene structure

**Files:** `scenes/game.tscn`

- [ ] **Step 1:** Open `scenes/game.tscn` in Godot

- [ ] **Step 2:** Rename the root node from `Node2D` to `Game`

- [ ] **Step 3:** Add child nodes to create this structure:

```
Game (Node2D)
├─ Fortress (Sprite2D)
├─ PlayerUnits (Node2D)
├─ EnemyUnits (Node2D)
└─ UI (CanvasLayer)
    ├─ SpawnButton (Button)
    ├─ StartButton (Button)
    ├─ RestartButton (Button)
    └─ HpLabel (Label)
```

To add each node:

- Right-click `Game` → Add Child Node → select the type
- For UI children: right-click `UI` → Add Child Node

- [ ] **Step 4:** Save the scene

**Verify:**

- Ask user to confirm:
  - Scene tree matches the structure above
  - All node names are correct (Game, Fortress, PlayerUnits, EnemyUnits, UI, SpawnButton, StartButton, RestartButton, HpLabel)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create game.gd script

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Create the file `scripts/game.gd` with the following content:

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


# Placeholder functions - will be implemented in Tasks 3-5
func _on_spawn_button_pressed() -> void:
	pass


func _on_start_button_pressed() -> void:
	pass


func _on_restart_button_pressed() -> void:
	pass
```

- [ ] **Step 2:** Attach the script to the Game scene:

  - Open `scenes/game.tscn`
  - Select the root `Game` node
  - In the Inspector, click the script property dropdown and select "Load"
  - Navigate to and select `scripts/game.gd`
  - Save the scene

- [ ] **Step 3:** Assign the unit scene to the export variable:
  - With the `Game` node selected, look in the Inspector
  - Find the `Unit Scene` property (under the script variables)
  - Drag `scenes/unit.tscn` from the FileSystem panel into this slot
  - Alternatively, click the dropdown and select "Load", then navigate to `scenes/unit.tscn`
  - Save the scene

**Verify:**

- Ask user to confirm:
  - `scripts/game.gd` exists
  - Script is attached to the Game node (script icon visible)
  - `Unit Scene` export shows `unit.tscn` assigned in Inspector

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Position battlefield elements

**Files:** `scenes/game.tscn`

- [ ] **Step 1:** Set up the Fortress sprite:

  - Select the `Fortress` node
  - In Inspector, under `Texture`, click dropdown → `New PlaceholderTexture2D`
  - Click on the PlaceholderTexture2D to expand it
  - Set `Size` to `64 x 128` (tall rectangle to represent a castle/tower)
  - Set `Fortress` position to `(50, 300)` (far left, vertically centered)
  - Optionally: Set `Modulate` color to a blue/gray to distinguish from units

- [ ] **Step 2:** Configure PlayerUnits container:

  - Select the `PlayerUnits` node
  - In Inspector, find `Y Sort Enabled` and check it ON
  - Position can stay at `(0, 0)` — child units use absolute positions

- [ ] **Step 3:** Configure EnemyUnits container:

  - Select the `EnemyUnits` node
  - In Inspector, find `Y Sort Enabled` and check it ON
  - Position can stay at `(0, 0)` — child units use absolute positions

- [ ] **Step 4:** Save the scene

**Verify:**

- Ask user to confirm:
  - Fortress appears as a tall rectangle on the left side of the viewport
  - Both `PlayerUnits` and `EnemyUnits` have `Y Sort Enabled` checked
  - Running the scene shows the fortress (press F5 or F6)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Set up UI elements

**Files:** `scenes/game.tscn`

- [ ] **Step 1:** Position the SpawnButton:

  - Select `UI/SpawnButton`
  - In Inspector, set these properties:
    - `Text`: `Add Unit`
    - `Position`: `(20, 500)` (bottom-left area)
    - `Size`: `(120, 40)` or use "Expand" to auto-size

- [ ] **Step 2:** Position the StartButton:

  - Select `UI/StartButton`
  - In Inspector, set these properties:
    - `Text`: `Fight!`
    - `Position`: `(160, 500)` (next to SpawnButton)
    - `Size`: `(100, 40)`

- [ ] **Step 3:** Position the RestartButton:

  - Select `UI/RestartButton`
  - In Inspector, set these properties:
    - `Text`: `Restart`
    - `Position`: `(280, 500)` (next to StartButton)
    - `Size`: `(100, 40)`
    - `Visible`: OFF (uncheck to hide it initially)

- [ ] **Step 4:** Position the HpLabel:

  - Select `UI/HpLabel`
  - In Inspector, set these properties:
    - `Text`: `HP: 10`
    - `Position`: `(20, 20)` (top-left corner)
  - Optionally adjust font size:
    - Under `Theme Overrides` → `Font Sizes` → `Font Size`: `24`

- [ ] **Step 5:** Save the scene

**Verify:**

- Ask user to:
  - Run the scene (F5 or F6)
  - Confirm UI elements are visible and positioned correctly:
    - "HP: 10" in top-left
    - "Add Unit" and "Fight!" buttons visible at bottom
    - "Restart" button should NOT be visible
  - Confirm clicking buttons doesn't cause errors (they do nothing yet, but shouldn't crash)

**After this task:** STOP and ask user to verify manually before continuing.

---

## Final Scene Structure

After all tasks, `scenes/game.tscn` should have:

```
Game (Node2D) [script: game.gd, unit_scene: unit.tscn]
├─ Fortress (Sprite2D) [position: (50, 300), texture: 64x128 placeholder]
├─ PlayerUnits (Node2D) [y_sort_enabled: true]
├─ EnemyUnits (Node2D) [y_sort_enabled: true]
└─ UI (CanvasLayer)
    ├─ SpawnButton (Button) [text: "Add Unit", position: (20, 500)]
    ├─ StartButton (Button) [text: "Fight!", position: (160, 500)]
    ├─ RestartButton (Button) [text: "Restart", position: (280, 500), visible: false]
    └─ HpLabel (Label) [text: "HP: 10", position: (20, 20)]
```

---

## Exit Criteria

- [ ] `scenes/game.tscn` has correct node hierarchy
- [ ] `scripts/game.gd` is attached to Game node
- [ ] `unit.tscn` is assigned to the `unit_scene` export variable
- [ ] Fortress is visible on left side of screen
- [ ] PlayerUnits and EnemyUnits have `y_sort_enabled` on
- [ ] SpawnButton shows "Add Unit" at bottom-left
- [ ] StartButton shows "Fight!" next to SpawnButton
- [ ] RestartButton is hidden
- [ ] HpLabel shows "HP: 10" at top-left
- [ ] Scene runs without errors
