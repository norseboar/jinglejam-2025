# Join Faction System Implementation Plan

**Goal:** Allow players to "join" the enemy faction when defeated, continuing with half the enemy's army value, and display final stats with letter grades after 10 battles.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Add win/loss tracking
- [ ] Task 2: Add UI elements to battle end modal
- [ ] Task 3: Implement join faction logic
- [ ] Task 4: Update battle end modal handlers
- [ ] Task 5: Add final stats screen UI
- [ ] Task 6: Implement final stats display logic

---

## Summary

**Task 1: Add win/loss tracking** — Add counters for battles won and lost to track throughout the campaign.

**Task 2: Add UI elements to battle end modal** — Add a second button and stats labels to the battle end modal scene.

**Task 3: Implement join faction logic** — Create the logic to generate a joined army and swap the player's roster.

**Task 4: Update battle end modal handlers** — Modify the HUD to handle join/restart button clicks and pass faction names.

**Task 5: Add final stats screen UI** — Add label references for displaying final statistics.

**Task 6: Implement final stats display logic** — Calculate letter grades and display final stats after battle 10.

---

## Tasks

### Task 1: Add win/loss tracking

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Add win/loss tracking variables after the existing state variables (around line 14):

```gdscript
# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"
var army: Array = []  # Array of ArmyUnit

# Win/loss tracking for campaign
var battles_won: int = 0
var battles_lost: int = 0  # Counts times player "joined" enemy faction
```

- [ ] **Step 2:** Update `_end_battle()` function to increment win counter on victory. Find the line `if victory and current_level_index < levels.size() - 1:` (around line 329) and add before it:

```gdscript
func _end_battle(victory: bool) -> void:
	phase = "battle_end"
	
	# Update HUD state to reflect the battle-end phase (keep battle UI while modal shows)
	if hud:
		hud.set_phase(phase, current_level_index + 1)

	# Stop all units (but don't reset dying units - they need to stay "dying" to prevent double gold)
	for child in player_units.get_children():
		if child is Unit and child.state != "dying":
			child.set_state("idle")
	for child in enemy_units.get_children():
		if child is Unit and child.state != "dying":
			child.set_state("idle")

	# Track wins and losses
	if victory:
		battles_won += 1
	# battles_lost will be incremented when player chooses to join (Task 3)

	# Capture enemy data for upgrade screen (only if victory and not last level, defeat will restart)
	if victory and current_level_index < levels.size() - 1:
		_capture_enemies_faced()
	
	# ... rest of function
```

**Verify:**
- Check that the code compiles with no syntax errors
- Confirm the tracking variables are added

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Add UI elements to battle end modal

**Files:** `scenes/ui/hud.tscn`

- [ ] **Step 1:** **Godot Editor:** Open `scenes/ui/hud.tscn` in the Godot editor

- [ ] **Step 2:** **Godot Editor:** Find the `BattleEndModal/Panel/PanelContainer/VBoxContainer` node in the scene tree

- [ ] **Step 3:** **Godot Editor:** Rename the existing `ConfirmButton` node to `RestartButton` for clarity

- [ ] **Step 4:** **Godot Editor:** Duplicate the `RestartButton` node (right-click → Duplicate) and rename the duplicate to `JoinButton`

- [ ] **Step 5:** **Godot Editor:** Set `JoinButton` visibility to hidden by default (in the Inspector, set `Visible` to off)

- [ ] **Step 6:** **Godot Editor:** Add three new Label nodes as children of `VBoxContainer` for stats display. Name them:
  - `WinsLabel`
  - `LossesLabel`
  - `GradeLabel`

- [ ] **Step 7:** **Godot Editor:** Set all three new labels to hidden by default (visibility off)

- [ ] **Step 8:** **Godot Editor:** Configure the labels' horizontal alignment to Center and vertical alignment to Center in the Inspector

- [ ] **Step 9:** **Godot Editor:** Save the scene

**Verify:**
- Ask user to:
  - Confirm the scene has both `JoinButton` and `RestartButton`
  - Confirm the three stat labels exist and are hidden
  - Confirm no errors appear when opening the scene

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Implement join faction logic

**Files:** `scripts/game.gd`

- [ ] **Step 1:** Add a new signal at the top of the file after the existing signals (around line 7):

```gdscript
# Signals
signal unit_placed(unit_type: String)
signal army_unit_placed(slot_index: int)
signal gold_changed(new_amount: int)
signal join_faction_requested()  # Emitted when player chooses to join enemy faction
```

- [ ] **Step 2:** Create the join faction handler function. Add after `_on_show_upgrade_screen_requested()` (around line 827):

```gdscript
func _on_join_faction_requested() -> void:
	"""Handle player choosing to join the enemy faction after defeat."""
	battles_lost += 1
	
	# Calculate half the enemy army's value
	var enemy_value := ArmyGenerator.calculate_army_value(current_enemy_army)
	var target_value := enemy_value / 2
	
	# Get slot count from current battlefield
	var slot_count := _count_enemy_slots(selected_level_scene)
	if slot_count <= 0:
		push_warning("Could not determine slot count for joined army, using 6")
		slot_count = 6
	
	# Generate new army with half enemy value using enemy roster
	var joined_army := ArmyGenerator.generate_army(
		current_enemy_roster,  # Pick from enemy roster
		target_value,          # Half the enemy army value
		slot_count,            # Max units based on battlefield
		[],                    # No forced units
		null,                  # No neutral roster
		0                      # No minimum gold
	)
	
	print("Joined %s faction with army value: %d (half of %d)" % [
		current_enemy_roster.team_name if current_enemy_roster else "unknown",
		ArmyGenerator.calculate_army_value(joined_army),
		enemy_value
	])
	
	# Store old player army to use as draft pool
	var old_army := army.duplicate(true)
	
	# Replace player army with joined army
	army = joined_army
	
	# Go to upgrade screen with swapped roles
	# Player keeps their gold, old army becomes available to recruit
	phase = "upgrade"
	if hud:
		hud.set_phase(phase, current_level_index + 1)
	
	# Swap to upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Clear leftover units from the battle
	_clear_all_units()
	
	# Hide the level (if present)
	if current_level:
		current_level.visible = false
	
	# Show upgrade screen with joined army and old army as draft pool
	# Pass false for victory state since this came from a defeat
	hud.show_upgrade_screen(false, army, old_army)
```

- [ ] **Step 3:** Find the `_return_to_title_screen()` function and verify it properly resets the win/loss counters. Add these lines at the beginning if not present:

```gdscript
func _return_to_title_screen() -> void:
	# Reset campaign tracking
	battles_won = 0
	battles_lost = 0
	current_level_index = 0
	
	# ... rest of existing function
```

**Verify:**
- Check that the code compiles with no syntax errors
- Confirm the join faction logic is added

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Update battle end modal handlers

**Files:** `scripts/hud.gd`

- [ ] **Step 1:** Add references to the new UI elements at the top of the file where other exports are defined (around line 8):

```gdscript
# Battle end modal references
@export var battle_end_modal: CanvasItem
@export var battle_end_label: Label
@export var battle_end_button: BaseButton  # This is the restart button
@export var battle_end_join_button: BaseButton  # New join button
```

- [ ] **Step 2:** Add a signal for join faction at the top of the file after existing signals (around line 6):

```gdscript
# Signals
signal start_battle_requested()
signal show_upgrade_screen_requested()
signal upgrade_confirmed(victory: bool)
signal draft_complete()
signal battle_select_advance(option_data: BattleOptionData)
signal join_faction_requested()  # New signal for joining enemy faction
```

- [ ] **Step 3:** Add a variable to store the enemy faction name after the existing state variables (around line 14):

```gdscript
# State
var last_victory_state: bool = false
var is_last_level: bool = false
var current_enemy_faction_name: String = ""  # Track for join button text
```

- [ ] **Step 4:** Update the `show_battle_end_modal()` function signature and implementation. Find the function (around line 230) and replace it:

```gdscript
func show_battle_end_modal(victory: bool, level: int, total_levels: int, enemy_faction_name: String = "") -> void:
	"""Show the battle end modal that leads to upgrade screen or join/restart options."""
	last_victory_state = victory
	is_last_level = (level >= total_levels)
	current_enemy_faction_name = enemy_faction_name
	
	if not battle_end_modal or not battle_end_label or not battle_end_button:
		return
	
	# Configure modal text and buttons based on state
	if victory:
		# Victory flow - hide join button, show single button
		if battle_end_join_button:
			battle_end_join_button.visible = false
		
		if is_last_level:
			# Last level completed - will show stats instead (handled in Task 6)
			battle_end_label.text = "Victory! You've completed all levels!"
			if battle_end_button is Button:
				battle_end_button.text = "View Results"
		else:
			battle_end_label.text = "Victory!"
			if battle_end_button is Button:
				battle_end_button.text = "Upgrade Army"
		
		if battle_end_button:
			battle_end_button.visible = true
	else:
		# Defeat flow - show both join and restart buttons
		battle_end_label.text = "Defeat!"
		
		# Show join button with faction name
		if battle_end_join_button:
			battle_end_join_button.visible = true
			if battle_end_join_button is Button:
				var faction_text := enemy_faction_name if enemy_faction_name != "" else "Enemy"
				battle_end_join_button.text = "Join %s" % faction_text
		
		# Show restart button
		if battle_end_button:
			battle_end_button.visible = true
			if battle_end_button is Button:
				battle_end_button.text = "Restart"
	
	# Show the modal
	battle_end_modal.visible = true
```

- [ ] **Step 5:** Update the `_on_battle_end_button_pressed()` handler to handle the new flow (around line 326):

```gdscript
func _on_battle_end_button_pressed() -> void:
	"""Handle battle end button (restart/upgrade) - shows upgrade screen or restarts."""
	# Hide modal
	if battle_end_modal:
		battle_end_modal.visible = false
	
	# If defeat, this is the restart button - go to title screen
	if not last_victory_state:
		upgrade_confirmed.emit(false)
		return
	
	# If victory on last level, will show stats (Task 6 will update this)
	if is_last_level:
		upgrade_confirmed.emit(true)
		return
	
	# Otherwise, victory on non-last level - show upgrade screen
	show_upgrade_screen_requested.emit()
```

- [ ] **Step 6:** Add a new handler for the join button. Add after `_on_battle_end_button_pressed()`:

```gdscript
func _on_battle_end_join_button_pressed() -> void:
	"""Handle join faction button - player chooses to join enemy faction after defeat."""
	# Hide modal
	if battle_end_modal:
		battle_end_modal.visible = false
	
	# Emit signal to game to handle join logic
	join_faction_requested.emit()
```

- [ ] **Step 7:** **Godot Editor:** Connect the new join button signal:
1. Open `scenes/ui/hud.tscn` in the Godot editor
2. Select the `JoinButton` node
3. Go to the Node tab (next to Inspector)
4. Find the `pressed()` signal
5. Click Connect
6. Select the `HUD` node as the target
7. Set the method name to `_on_battle_end_join_button_pressed`
8. Click Connect

- [ ] **Step 8:** **Godot Editor:** Link the new `battle_end_join_button` export:
1. In `scenes/ui/hud.tscn`, select the root `HUD` node
2. In the Inspector, find the Script Variables section
3. Find `Battle End Join Button` in the exported variables
4. Drag the `JoinButton` node from the scene tree to this field (or click and select it)
5. Save the scene

**Verify:**
- Ask user to:
  - Confirm no syntax errors
  - Confirm the join button signal is connected in the scene
  - Confirm the export is linked in the inspector

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Add final stats screen UI

**Files:** `scripts/hud.gd`

- [ ] **Step 1:** Add export references for the stats labels in the exports section (around line 11):

```gdscript
# Battle end modal references
@export var battle_end_modal: CanvasItem
@export var battle_end_label: Label
@export var battle_end_button: BaseButton
@export var battle_end_join_button: BaseButton
@export var battle_end_wins_label: Label  # Shows "Banners defeated: X"
@export var battle_end_losses_label: Label  # Shows "Banners joined: Y"
@export var battle_end_grade_label: Label  # Shows "Rank: Z"
```

- [ ] **Step 2:** **Godot Editor:** Link the stats label exports:
1. Open `scenes/ui/hud.tscn` in the Godot editor
2. Select the root `HUD` node
3. In the Inspector, find the Script Variables section
4. Find `Battle End Wins Label` and drag the `WinsLabel` node to it
5. Find `Battle End Losses Label` and drag the `LossesLabel` node to it
6. Find `Battle End Grade Label` and drag the `GradeLabel` node to it
7. Save the scene

**Verify:**
- Ask user to:
  - Confirm all three label exports are linked in the inspector
  - Confirm no errors in the scene

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 6: Implement final stats display logic

**Files:** `scripts/hud.gd`, `scripts/game.gd`

- [ ] **Step 1:** Add a function to calculate letter grade in `scripts/hud.gd`. Add after the `show_battle_end_modal()` function:

```gdscript
func _calculate_letter_grade(wins: int, losses: int) -> String:
	"""Calculate letter grade based on win/loss ratio."""
	var total_battles := wins + losses
	if total_battles == 0:
		return "F"
	
	var win_rate := float(wins) / float(total_battles)
	
	if win_rate >= 1.0:  # 10/10 wins
		return "A"
	elif win_rate >= 0.8:  # 8-9/10 wins
		return "B"
	elif win_rate >= 0.6:  # 6-7/10 wins
		return "C"
	elif win_rate >= 0.4:  # 4-5/10 wins
		return "D"
	else:  # <4/10 wins
		return "F"
```

- [ ] **Step 2:** Add a function to show the final stats screen in `scripts/hud.gd`. Add after `_calculate_letter_grade()`:

```gdscript
func show_final_stats(wins: int, losses: int) -> void:
	"""Show the final statistics screen with letter grade."""
	if not battle_end_modal or not battle_end_label:
		return
	
	# Hide join button (not used in final screen)
	if battle_end_join_button:
		battle_end_join_button.visible = false
	
	# Show restart button
	if battle_end_button:
		battle_end_button.visible = true
		if battle_end_button is Button:
			battle_end_button.text = "Return to Title"
	
	# Hide the main label (we'll use the stat labels instead)
	if battle_end_label:
		battle_end_label.visible = false
	
	# Calculate grade
	var grade := _calculate_letter_grade(wins, losses)
	
	# Show and populate stats labels
	if battle_end_wins_label:
		battle_end_wins_label.visible = true
		battle_end_wins_label.text = "Banners defeated: %d" % wins
	
	if battle_end_losses_label:
		battle_end_losses_label.visible = true
		battle_end_losses_label.text = "Banners joined: %d" % losses
	
	if battle_end_grade_label:
		battle_end_grade_label.visible = true
		battle_end_grade_label.text = "Rank: %s" % grade
	
	# Show the modal
	battle_end_modal.visible = true
	
	print("Final stats - Wins: %d, Losses: %d, Grade: %s" % [wins, losses, grade])
```

- [ ] **Step 3:** Update `show_battle_end_modal()` to hide stats labels for non-final screens. Find the function and add at the beginning (right after the variable assignments):

```gdscript
func show_battle_end_modal(victory: bool, level: int, total_levels: int, enemy_faction_name: String = "") -> void:
	"""Show the battle end modal that leads to upgrade screen or join/restart options."""
	last_victory_state = victory
	is_last_level = (level >= total_levels)
	current_enemy_faction_name = enemy_faction_name
	
	# Hide stats labels (only used in final stats screen)
	if battle_end_wins_label:
		battle_end_wins_label.visible = false
	if battle_end_losses_label:
		battle_end_losses_label.visible = false
	if battle_end_grade_label:
		battle_end_grade_label.visible = false
	
	# Ensure main label is visible (hidden in final stats)
	if battle_end_label:
		battle_end_label.visible = true
	
	# ... rest of existing function
```

- [ ] **Step 4:** Update `_end_battle()` in `scripts/game.gd` to pass enemy faction name and check for final battle. Find the line where `hud.show_battle_end_modal()` is called (around line 339) and replace:

```gdscript
func _end_battle(victory: bool) -> void:
	phase = "battle_end"
	
	# ... existing code ...
	
	# Play victory or defeat jingle (and duck current music)
	if victory:
		MusicManager.play_jingle_and_duck(MusicManager.victory_jingle)
	else:
		MusicManager.play_jingle_and_duck(MusicManager.defeat_jingle)
	
	# Check if this is the final battle (battle 10)
	var is_final_battle := (current_level_index >= levels.size() - 1)
	
	if is_final_battle and victory:
		# Show final stats instead of normal victory modal
		if hud:
			hud.show_final_stats(battles_won, battles_lost)
	else:
		# Show normal battle end modal (with join option on defeat)
		var enemy_faction_name := current_enemy_roster.team_name if current_enemy_roster else ""
		hud.show_battle_end_modal(victory, current_level_index + 1, levels.size(), enemy_faction_name)
	
	# Update auto-deploy button state (should be disabled during upgrade phase)
	if hud:
		hud._update_auto_deploy_button_state()
```

- [ ] **Step 5:** Connect the join faction signal. In `scripts/game.gd`, find the `_ready()` function and add the signal connection with the other HUD signal connections:

```gdscript
func _ready() -> void:
	# ... existing code ...
	
	# Connect HUD signals
	if hud:
		hud.start_battle_requested.connect(_on_start_battle_requested)
		hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
		hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
		hud.draft_complete.connect(_on_draft_complete)
		hud.battle_select_advance.connect(_on_battle_select_advance)
		hud.join_faction_requested.connect(_on_join_faction_requested)  # Add this line
	
	# ... rest of existing code ...
```

**Verify:**
- Ask user to:
  - Run the game and play through to battle 10
  - Win battle 10 and verify the stats screen appears
  - Verify the stats show correct wins/losses/grade
  - Lose a battle and verify "Join [Faction]" and "Restart" buttons appear
  - Click "Join" and verify you get half the enemy army value
  - Verify your old army appears in the draft pool
  - Verify you keep your gold after joining
  - Complete a campaign with different win/loss ratios and verify letter grades are correct

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Win/loss tracking works throughout the campaign
- [ ] On defeat, "Join [Faction]" and "Restart" buttons appear
- [ ] Clicking "Join" generates army with half enemy value from enemy roster
- [ ] After joining, old player army is available in draft pool
- [ ] Gold is preserved when joining
- [ ] After battle 10 (victory), final stats screen appears
- [ ] Stats screen shows: "Banners defeated: X", "Banners joined: Y", "Rank: Z"
- [ ] Letter grades calculate correctly: A (100%), B (80-90%), C (60-70%), D (40-50%), F (<40%)
- [ ] "Return to Title" button works on final stats screen
- [ ] Win/loss counters reset when returning to title screen
- [ ] No errors in console during any of these flows

