# Draft System Implementation Plan

**Goal:** Replace the fixed starting team with a draft system where players buy units from a roster before their first battle.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Create Roster resource
- [ ] Task 2: Update game.gd for draft flow
- [ ] Task 3: Remove enemy de-duping
- [ ] Task 4: Add draft mode to upgrade_screen.gd
- [ ] Task 5: Update HUD to forward draft signals
- [ ] Task 6: Add Start Battle button and label swap in Godot editor
- [ ] Task 7: Create starting roster resource file

---

## Summary

**Task 1: Create Roster resource** — New simple resource class with an array of PackedScenes.

**Task 2: Update game.gd for draft flow** — Replace starting_unit_scenes with starting_roster, start game in draft mode, handle draft completion.

**Task 3: Remove enemy de-duping** — Simplify _capture_enemies_faced() to include all enemies.

**Task 4: Add draft mode to upgrade_screen.gd** — Add is_draft_mode state, show draft roster, swap labels/buttons, emit draft_complete signal.

**Task 5: Update HUD to forward draft signals** — Add show_draft_screen method and forward draft_complete signal.

**Task 6: Add Start Battle button and label swap in Godot editor** — Add new button, configure label for text swap.

**Task 7: Create starting roster resource file** — Create .tres file with initial roster units.

---

## Tasks

### Task 1: Create Roster resource

**Files:** `scripts/roster.gd`

- [ ] **Step 1:** Create the Roster resource class:

```gdscript
extends Resource
class_name Roster

## Array of unit scenes available in this roster. Duplicates allowed.
@export var units: Array[PackedScene] = []
```

**After this task:** STOP and ask user to verify the file exists and has no errors.

---

### Task 2: Update game.gd for draft flow

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Replace the starting_unit_scenes export with starting_roster:

Find:
```gdscript
# Starting units for the tray (can have duplicates)
@export var starting_unit_scenes: Array[PackedScene] = []
```

Replace with:
```gdscript
# Starting roster for draft phase
@export var starting_roster: Roster
```

- [ ] **Step 2:** Add draft mode state variable after the existing state variables:

Find:
```gdscript
var current_level: LevelRoot = null
```

Add after:
```gdscript
var is_draft_mode: bool = true
```

- [ ] **Step 3:** Update _ready() to start in draft mode instead of loading a level:

Find:
```gdscript
func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	hud.battle_select_advance.connect(_on_battle_select_advance)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)
	
	# Initialize gold
	gold = starting_gold
	gold_changed.emit(gold)
	
	load_level(current_level_index)
```

Replace with:
```gdscript
func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	hud.battle_select_advance.connect(_on_battle_select_advance)
	hud.draft_complete.connect(_on_draft_complete)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)
	
	# Initialize gold
	gold = starting_gold
	gold_changed.emit(gold)
	
	# Start in draft mode
	_show_draft_screen()
```

- [ ] **Step 4:** Add the _show_draft_screen() function after _ready():

```gdscript
func _show_draft_screen() -> void:
	"""Show the draft screen at game start."""
	# Set upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Initialize empty army
	army.clear()
	
	# Show draft screen via HUD
	hud.show_draft_screen(starting_roster)
```

- [ ] **Step 5:** Add the _on_draft_complete() handler after _on_battle_select_advance():

```gdscript
func _on_draft_complete() -> void:
	"""Handle draft completion - start first battle directly."""
	is_draft_mode = false
	# Load first level directly (no level select)
	load_level(0)
```

- [ ] **Step 6:** Remove the _init_army() function entirely (it's no longer used):

Find and delete:
```gdscript
func _init_army() -> void:
	army.clear()
	for scene in starting_unit_scenes:
		var slot := ArmyUnit.new()
		slot.unit_scene = scene
		slot.unit_type = scene.resource_path.get_file().get_basename()
		slot.placed = false
		army.append(slot)
```

- [ ] **Step 7:** Update load_level_scene() to remove the army initialization logic that called _init_army():

Find:
```gdscript
	# Only initialize army on first level or after it was cleared (defeat)
	if army.size() == 0:
		_init_army()
		# Reset gold when starting new run
		gold = starting_gold
		gold_changed.emit(gold)
	else:
		# Reset placed status for new level (units can be placed again)
		for army_unit in army:
			army_unit.placed = false
```

Replace with:
```gdscript
	# Reset placed status for new level (units can be placed again)
	for army_unit in army:
		army_unit.placed = false
```

**After this task:** STOP and ask user to verify. The game will not run correctly yet (HUD changes needed), but there should be no syntax errors.

---

### Task 3: Remove enemy de-duping

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Simplify _capture_enemies_faced() to include all enemies without de-duplication:

Find:
```gdscript
func _capture_enemies_faced() -> void:
	"""Capture unique enemy types from current level for the upgrade screen."""
	enemies_faced.clear()
	
	if current_level == null:
		return
	
	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return
	
	# Track seen combinations to deduplicate
	var seen: Dictionary = {}  # key: "unit_type|upgrades_hash" -> bool
	
	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue
		
		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue
		
		# Create a unique key from unit type and upgrades
		var unit_type: String = enemy_marker.unit_scene.resource_path.get_file().get_basename()
		var upgrades_str: String = str(enemy_marker.upgrades)
		var key: String = unit_type + "|" + upgrades_str
		
		if seen.has(key):
			continue
		
		seen[key] = true
		enemies_faced.append({
			"unit_type": unit_type,
			"unit_scene": enemy_marker.unit_scene,
			"upgrades": enemy_marker.upgrades.duplicate()
		})
```

Replace with:
```gdscript
func _capture_enemies_faced() -> void:
	"""Capture all enemies from current level for the upgrade screen."""
	enemies_faced.clear()
	
	if current_level == null:
		return
	
	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return
	
	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue
		
		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue
		
		var unit_type: String = enemy_marker.unit_scene.resource_path.get_file().get_basename()
		enemies_faced.append({
			"unit_type": unit_type,
			"unit_scene": enemy_marker.unit_scene,
			"upgrades": enemy_marker.upgrades.duplicate()
		})
```

**After this task:** STOP and ask user to verify there are no syntax errors.

---

### Task 4: Add draft mode to upgrade_screen.gd

**Files:** `scripts/upgrade_screen.gd`

- [ ] **Step 1:** Add new signal at the top of the file after the existing signal:

Find:
```gdscript
signal continue_pressed(victory: bool)
```

Add after:
```gdscript
signal draft_complete()
```

- [ ] **Step 2:** Add new export for start battle button after continue_button:

Find:
```gdscript
@export var continue_button: BaseButton
```

Add after:
```gdscript
@export var start_battle_button: BaseButton
```

- [ ] **Step 3:** Add export for the enemy panel label (to swap text):

Find:
```gdscript
@export var gold_label: Label
```

Add after:
```gdscript
@export var enemy_panel_label: Label
```

- [ ] **Step 4:** Add draft mode state variables after recruited_indices:

Find:
```gdscript
var recruited_indices: Array[int] = []
```

Add after:
```gdscript
var is_draft_mode: bool = false
var draft_roster: Array = []  # Array of ArmyUnit created from roster
```

- [ ] **Step 5:** Connect the start battle button in _ready() after continue_button connection:

Find:
```gdscript
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
```

Add after:
```gdscript
	# Connect start battle button
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_button_pressed)
```

- [ ] **Step 6:** Add the show_draft_screen() function after show_upgrade_screen():

```gdscript
func show_draft_screen(roster: Roster) -> void:
	"""Show the upgrade screen in draft mode with roster units to buy."""
	is_draft_mode = true
	current_victory_state = true  # Not really relevant for draft
	
	# Store empty army reference (draft starts with no units)
	var game := _get_game()
	if game:
		army_ref = game.army
	else:
		army_ref = []
	
	# Convert roster to ArmyUnit array for the enemy tray
	draft_roster.clear()
	if roster:
		for unit_scene in roster.units:
			var army_unit := ArmyUnit.new()
			army_unit.unit_scene = unit_scene
			army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
			army_unit.placed = false
			army_unit.upgrades = {}
			draft_roster.append(army_unit)
	
	# Use draft_roster as the "enemies" to recruit from
	enemies_faced_ref = draft_roster
	
	# Reset selection state
	selected_army_index = -1
	selected_enemy_index = -1
	recruited_indices.clear()
	
	# Populate trays
	_populate_army_tray(army_slot_group, army_ref)
	_populate_enemy_tray(enemy_slot_group, draft_roster)
	
	# Reset panes to instruction state
	_refresh_upgrade_pane()
	_refresh_recruit_pane()
	
	# Update gold display
	if game:
		update_gold_display(game.gold)
	
	# Update label and buttons for draft mode
	_update_mode_display()
	
	# Show screen
	visible = true
```

- [ ] **Step 7:** Add the _update_mode_display() function after show_draft_screen():

```gdscript
func _update_mode_display() -> void:
	"""Update labels and buttons based on draft vs recruit mode."""
	if enemy_panel_label:
		if is_draft_mode:
			enemy_panel_label.text = "Draft your team"
		else:
			enemy_panel_label.text = "Recruit their army"
	
	# Show/hide appropriate button
	if start_battle_button:
		start_battle_button.visible = is_draft_mode
		# Disable until army has at least 1 unit
		start_battle_button.disabled = army_ref.size() < 1
	if continue_button:
		continue_button.visible = not is_draft_mode
```

- [ ] **Step 8:** Add the _on_start_battle_button_pressed() handler after _on_continue_button_pressed():

```gdscript
func _on_start_battle_button_pressed() -> void:
	"""Handle Start Battle button press in draft mode."""
	if army_ref.size() < 1:
		return  # Need at least 1 unit
	
	hide_upgrade_screen()
	draft_complete.emit()
```

- [ ] **Step 9:** Update show_upgrade_screen() to set is_draft_mode = false and call _update_mode_display():

Find the end of show_upgrade_screen(), before `visible = true`:
```gdscript
	# Update gold display
	var game := _get_game()
	if game:
		update_gold_display(game.gold)

	# Show upgrade screen
	visible = true
```

Replace with:
```gdscript
	# Update gold display
	var game := _get_game()
	if game:
		update_gold_display(game.gold)

	# Set recruit mode (not draft)
	is_draft_mode = false
	_update_mode_display()

	# Show upgrade screen
	visible = true
```

- [ ] **Step 10:** Update _on_recruit_button_pressed() to refresh the start battle button state. Find the end of the function:

Find:
```gdscript
	# Refresh pane immediately (updates button states and text)
	_refresh_recruit_pane()
```

Add after:
```gdscript
	# Update start battle button state (may now have enough units)
	if is_draft_mode and start_battle_button:
		start_battle_button.disabled = army_ref.size() < 1
```

**After this task:** STOP and ask user to verify there are no syntax errors.

---

### Task 5: Update HUD to forward draft signals

**Files:** `scripts/hud.gd`

- [ ] **Step 1:** Add new signal after existing signals:

Find the signals section at the top of the file and add:
```gdscript
signal draft_complete()
```

- [ ] **Step 2:** Connect the upgrade_screen's draft_complete signal in _ready(). Find where upgrade_screen signals are connected and add:

```gdscript
	if upgrade_screen:
		upgrade_screen.draft_complete.connect(_on_draft_complete)
```

- [ ] **Step 3:** Add the show_draft_screen() function that forwards to upgrade_screen:

```gdscript
func show_draft_screen(roster: Roster) -> void:
	"""Show the upgrade screen in draft mode."""
	if upgrade_screen:
		upgrade_screen.show_draft_screen(roster)
```

- [ ] **Step 4:** Add the _on_draft_complete() handler:

```gdscript
func _on_draft_complete() -> void:
	"""Forward draft complete signal from upgrade screen."""
	draft_complete.emit()
```

**After this task:** STOP and ask user to verify there are no syntax errors.

---

### Task 6: Add Start Battle button and label swap in Godot editor

**Files:** `scenes/game.tscn` (Godot editor)

- [ ] **Step 1:** **Godot Editor:** The user needs to create a Start Battle button sprite asset. Ask the user:
  - Do you have a "Start Battle" button sprite ready? 
  - If not, they need to create one similar to the Continue button but with "Start Battle" text.
  - The button needs normal, pressed, and hover states like the existing Continue button.

- [ ] **Step 2:** **Godot Editor:** Add the Start Battle button to the upgrade screen:
  1. Open `scenes/game.tscn`
  2. Navigate to SubViewportContainer > SubViewport > UI > HUD > UpgradeScreen > CenterPanel > VBoxContainer
  3. Duplicate the existing "Button" (Continue button)
  4. Rename the duplicate to "StartBattleButton"
  5. Assign the Start Battle button textures to this new button
  6. Position it (can be in same spot - they'll toggle visibility)

- [ ] **Step 3:** **Godot Editor:** Wire up the start_battle_button export on UpgradeScreen:
  1. Select the UpgradeScreen node
  2. In the Inspector, find the "Start Battle Button" export
  3. Assign the StartBattleButton node

- [ ] **Step 4:** **Godot Editor:** Wire up the enemy_panel_label export on UpgradeScreen:
  1. Select the UpgradeScreen node
  2. In the Inspector, find the "Enemy Panel Label" export
  3. Assign the Label node at: EnemyArmy > MarginContainer > VBoxContainer > Label

- [ ] **Step 5:** **Godot Editor:** Assign the starting_roster export on Game node (will do in Task 7 after creating the resource)

**After this task:** STOP and ask user to verify the buttons and label are wired up correctly in the inspector.

---

### Task 7: Create starting roster resource file

**Files:** `resources/starting_roster.tres` (Godot editor)

- [ ] **Step 1:** **Godot Editor:** Create the resources directory if it doesn't exist:
  1. In the FileSystem panel, right-click on `res://`
  2. Create New > Folder
  3. Name it "resources"

- [ ] **Step 2:** **Godot Editor:** Create the starting roster resource:
  1. Right-click on `res://resources/`
  2. Create New > Resource
  3. Select "Roster" from the list
  4. Save as `starting_roster.tres`

- [ ] **Step 3:** **Godot Editor:** Populate the roster with starting units:
  1. Select `starting_roster.tres`
  2. In the Inspector, expand the "Units" array
  3. Add the same units that were previously in starting_unit_scenes on the Game node (check game.tscn for the original values - likely 2 swordsmen and 2 archers)
  4. Save the resource

- [ ] **Step 4:** **Godot Editor:** Assign the roster to the Game node:
  1. Open `scenes/game.tscn`
  2. Select the Game node
  3. In the Inspector, find "Starting Roster"
  4. Drag `resources/starting_roster.tres` into the field (or use the dropdown to select it)
  5. Save the scene

**After this task:** STOP and ask user to verify the roster is assigned and contains the correct units.

---

## Exit Criteria

- [ ] Game starts in draft mode with empty army
- [ ] Draft screen shows roster units on the right with "Draft your team" label
- [ ] Can buy units from roster (removes them from available)
- [ ] Can upgrade drafted units before starting
- [ ] "Start Battle" button is disabled until at least 1 unit drafted
- [ ] Clicking "Start Battle" goes directly to first level (no level select)
- [ ] After battle victory, upgrade screen shows "Recruit their army" with all enemies (not de-duped)
- [ ] "Continue" button shows after battles (not "Start Battle")
- [ ] No console errors



