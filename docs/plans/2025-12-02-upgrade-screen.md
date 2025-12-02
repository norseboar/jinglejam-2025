# Upgrade Screen Plan

**Goal:** Replace the post-battle modal with a full upgrade screen showing your army and enemies faced.

---

## Status

- [x] Task 1: Update hud.gd with new exports and methods
- [x] Task 2: Update game.gd to capture enemies and show upgrade screen
- [x] Task 3: Create UpgradeScreen UI in Godot editor
- [ ] Task 4: Wire up exports and test

---

## Summary

**Task 1:** Create separate UpgradeScreen script with its own logic, update hud.gd to reference and delegate to it.
**Task 2:** Add enemy capture logic to game.gd, swap background when entering upgrade phase.
**Task 3:** Build the UpgradeScreen UI in the HUD scene (Godot editor work).
**Task 4:** Connect exports in inspector and verify it works.

---

## Tasks

### ✅ Task 1: Create UpgradeScreen script and update hud.gd

**Files:** `scripts/upgrade_screen.gd`, `scripts/hud.gd`

- [x] **Step 1:** Create new `scripts/upgrade_screen.gd` file with `UpgradeScreen` class:
  - Exports for `your_army_tray`, `enemies_faced_tray`, `continue_button`
  - Signal `continue_pressed(victory: bool)`
  - Methods: `show_upgrade_screen()`, `hide_upgrade_screen()`, `_populate_display_tray()`, `_get_texture_from_scene()`
  - Handler `_on_continue_button_pressed()` that emits the signal

- [x] **Step 2:** Update `hud.gd` to use UpgradeScreen:
  - Change export to `@export var upgrade_screen: UpgradeScreen` (single reference)
  - In `_ready()`, connect to `upgrade_screen.continue_pressed` signal
  - Update `show_upgrade_screen()` to delegate to `upgrade_screen.show_upgrade_screen()`
  - Update `hide_upgrade_screen()` to delegate to `upgrade_screen.hide_upgrade_screen()`
  - Add `_on_upgrade_screen_continue_pressed()` handler that forwards to `upgrade_confirmed` signal

**After this task:** STOP and wait for user to confirm before continuing.

---

### Task 2: Update game.gd to capture enemies and show upgrade screen

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Add new export and state variable. After line 20 (`var current_level_index := 0`), add:

```gdscript
# Upgrade screen
@export var upgrade_background: Texture2D
var enemies_faced: Array = []  # Captured at end of battle for upgrade screen
```

- [ ] **Step 2:** Add helper method to capture and deduplicate enemies. Add after `_spawn_enemies_from_level()`:

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

- [ ] **Step 3:** Modify `_end_battle()` to capture enemies and show upgrade screen. Replace the existing `_end_battle()` function:

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

	# Capture enemy data before we move on
	_capture_enemies_faced()
	
	# Swap to upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Show upgrade screen instead of modal
	hud.show_upgrade_screen(victory, army, enemies_faced)
```

- [ ] **Step 4:** In `load_level()`, ensure background swaps back. The existing code already does this (around line 147-148), so no change needed. Just verify it's there:

```gdscript
	# Set the game's background from level
	if background_rect and current_level.background_texture:
		background_rect.texture = current_level.background_texture
```

- [ ] **Step 5:** In `_on_upgrade_confirmed()`, hide upgrade screen. Add at the start of the function:

```gdscript
func _on_upgrade_confirmed(victory: bool) -> void:
	# Hide upgrade screen
	hud.hide_upgrade_screen()
	
	if victory:
		# ... rest of existing code
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### ✅ Task 3: Create UpgradeScreen UI in Godot editor

**This task is done entirely in the Godot editor.**

Open `scenes/ui/hud.tscn` and create the following structure:

1. **Add UpgradeScreen node:**
   - Add a new `Control` node as child of HUD, name it `UpgradeScreen`
   - Set it to be hidden by default (visible = false)
   - Set anchors to fill the entire screen (anchors_preset = Full Rect / 15)
   - Set mouse_filter to MOUSE_FILTER_IGNORE so it doesn't block input to things below

2. **Add Your Army panel (left side):**
   - Add a `Panel` or `PanelContainer` as child of UpgradeScreen
   - Position it on the left side of the screen (your choice on exact position)
   - Add a `Label` child for the header text "Your Army"
   - Add a `GridContainer` child, name it `YourArmyTray`
   - Set GridContainer columns to 5
   - Add 10 instances of `unit_tray_slot.tscn` as children of the GridContainer

3. **Add Enemies Faced panel (right side):**
   - Add another `Panel` or `PanelContainer` as child of UpgradeScreen
   - Position it on the right side of the screen
   - Add a `Label` child for the header text "Enemies Faced"
   - Add a `GridContainer` child, name it `EnemiesFacedTray`
   - Set GridContainer columns to 5
   - Add 10 instances of `unit_tray_slot.tscn` as children of the GridContainer

4. **Add Continue button:**
   - Add a `Button` as child of UpgradeScreen, name it `ContinueButton`
   - Set text to "Continue" or "Next Battle"
   - Position in bottom-right corner (anchor to bottom-right)

**After this task:** STOP and tell me when the UI is created so we can wire up the exports.

---

### Task 4: Wire up exports and test

**This task is done in the Godot editor.**

1. **Select the HUD node** in `scenes/ui/hud.tscn`

2. **Select the UpgradeScreen node** in `scenes/ui/hud.tscn` and assign its script:
   - In Inspector, click script icon next to node name
   - Select `scripts/upgrade_screen.gd`

3. **In the Inspector for UpgradeScreen node, assign the exports:**
   - `your_army_tray` → YourArmyTray (the GridContainer)
   - `enemies_faced_tray` → EnemiesFacedTray (the GridContainer)
   - `continue_button` → ContinueButton

4. **Select the HUD node** in `scenes/ui/hud.tscn`

5. **In the Inspector for HUD node, assign:**
   - `upgrade_screen` → UpgradeScreen node

6. **Select the Game node** in `scenes/game.tscn`

7. **In the Inspector, assign:**
   - `upgrade_background` → Your upgrade screen background texture (or leave empty for now to test)

5. **Test:**
   - Run the game
   - Win or lose a battle
   - Verify the upgrade screen appears (not the old modal)
   - Verify your army units appear in the left tray
   - Verify enemy types appear in the right tray (deduplicated)
   - Click Continue and verify you advance to the next level

**After this task:** Verify manually that everything works.

---

## Exit Criteria

- [ ] Battle ends → upgrade screen appears (not old modal)
- [ ] Your army tray shows your units
- [ ] Enemies faced tray shows unique enemy types from the level
- [ ] Continue button advances to next level
- [ ] Background swaps to upgrade background (if texture assigned)
- [ ] Background swaps back to level background when battle starts

