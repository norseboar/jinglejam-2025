# ✅ Gold System Implementation Plan

**Goal:** Add a gold/money system where players start with gold, earn gold by killing enemy units, and spend gold on upgrades and recruiting units.

---

## Status

- [x] Task 1: Add gold storage and management to Game
- [x] Task 2: Add unit properties for costs and rewards
- [x] Task 3: Connect unit death to gold rewards
- [x] Task 4: Add gold display to HUD
- [x] Task 5: Add gold display and cost enforcement to UpgradeScreen
- [x] Task 6: Set default values on unit scenes

---

## Summary

**Task 1: Add gold storage and management to Game** — Add gold variable, starting gold export, gold management methods, and gold_changed signal to `scripts/game.gd`.

**Task 2: Add unit properties for costs and rewards** — Add `base_recruit_cost`, `upgrade_cost`, and `gold_reward` export properties to `scripts/Unit.gd`.

**Task 3: Connect unit death to gold rewards** — Add death signal to `scripts/Unit.gd` and connect it in `scripts/game.gd` to award gold when enemies die.

**Task 4: Add gold display to HUD** — Add gold label to `scenes/ui/hud.tscn` and connect to gold_changed signal in `scripts/hud.gd`.

**Task 5: Add gold display and cost enforcement to UpgradeScreen** — Add gold label, connect to gold_changed signal, enforce costs on buttons, and update button text with costs in `scripts/upgrade_screen.gd` and `scenes/ui/upgrade_screen.tscn`.

**Task 6: Set default values on unit scenes** — Set `base_recruit_cost`, `upgrade_cost`, and `gold_reward` values on existing unit scenes.

---

## Tasks

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

### ✅ Task 1: Add gold storage and management to Game

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add gold-related variables and signal at the top of `scripts/game.gd`, after the existing signals:

```gdscript
# Signals
signal unit_placed(unit_type: String)
signal army_unit_placed(slot_index: int)
signal gold_changed(new_amount: int)  # NEW
```

- [x] **Step 2:** Add gold configuration and state variables after the existing game state variables:

```gdscript
# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"
var army: Array = []  # Array of ArmyUnit

# Gold system
@export var starting_gold := 100
var gold: int = 0
```

- [x] **Step 3:** Add gold management methods after the `_init_army()` function:

```gdscript
func add_gold(amount: int) -> void:
	"""Add gold and notify listeners."""
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	"""Spend gold if available. Returns true if successful, false if insufficient."""
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func can_afford(amount: int) -> bool:
	"""Check if player has enough gold."""
	return gold >= amount
```

- [x] **Step 4:** Initialize gold in `_ready()` function, after the signal connections:

```gdscript
func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)

	# Initialize gold
	gold = starting_gold
	gold_changed.emit(gold)

	load_level(current_level_index)
```

- [x] **Step 5:** Reset gold to starting_gold when starting a new run. In `load_level()`, add gold reset when army is cleared (defeat or new run):

```gdscript
func load_level(index: int) -> void:
	# Validate index first
	if index < 0 or index >= level_scenes.size():
		push_error("Invalid level index: %d (array size: %d)" % [index, level_scenes.size()])
		return

	var level_scene: PackedScene = level_scenes[index]
	if level_scene == null:
		push_error("Level scene at index %d is null! Make sure all entries in level_scenes array are assigned." % index)
		return

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

**Verify:**

- Ask user to:
  - Open `scripts/game.gd` and confirm no syntax errors
  - Verify the new variables and methods exist
  - Check that `gold` is initialized to `starting_gold` in `_ready()`

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Add unit properties for costs and rewards

**Files:** `scripts/Unit.gd`

- [x] **Step 1:** Add gold-related export properties after the existing display info exports:

```gdscript
# Display info
@export var display_name: String = "Unit"
@export var description: String = "A basic unit."

# Gold system properties
@export var base_recruit_cost := 10  # Base cost to recruit this unit type
@export var upgrade_cost := 5  # Cost per upgrade (HP or Damage)
@export var gold_reward := 5  # Gold given when this unit is killed
```

**Verify:**

- Ask user to:
  - Open `scripts/Unit.gd` and confirm no syntax errors
  - Verify the three new export properties exist
  - Check that they appear in the Inspector when selecting a Unit node

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Connect unit death to gold rewards

**Files:** `scripts/Unit.gd`, `scripts/game.gd`

- [x] **Step 1:** Add death signal to `scripts/Unit.gd`, after the existing class_name declaration:

```gdscript
extends Node2D
class_name Unit

# Signals
signal unit_died(gold_reward: int)  # NEW

# Stats
@export var max_hp := 3
```

- [x] **Step 2:** Emit the death signal in `die()` function, before the fade out. Modify the `die()` function:

```gdscript
func die() -> void:
	# Stop all movement and combat
	is_attacking = false
	target = null
	set_state("dying")

	# Award gold if this is an enemy unit
	if is_enemy:
		unit_died.emit(gold_reward)

	# Fade out before removing from scene
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
```

- [x] **Step 3:** Connect enemy unit death signals in `scripts/game.gd`. In `_spawn_enemies_from_level()`, connect the signal after adding the enemy to the scene tree:

```gdscript
func _spawn_enemies_from_level() -> void:
	if current_level == null:
		push_warning("current_level is null in _spawn_enemies_from_level")
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		push_warning("No EnemyMarkers node in level")
		return

	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue

		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			push_error("EnemyMarker at position %s has no unit_scene assigned!" % enemy_marker.global_position)
			return  # Stop spawning if any marker is misconfigured

		var enemy: Unit = enemy_marker.unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit from scene at marker %s!" % enemy_marker.global_position)
			return  # Stop spawning on instantiation failure

		# Configure enemy properties BEFORE adding to scene tree (so _ready() sees correct values)
		enemy.is_enemy = true
		enemy.enemy_container = player_units
		enemy.global_position = enemy_marker.global_position
		enemy.upgrades = enemy_marker.upgrades.duplicate()  # Copy upgrades

		enemy_units.add_child(enemy)
		enemy.apply_upgrades()  # Apply after added to tree

		# Connect death signal to award gold
		enemy.unit_died.connect(_on_enemy_unit_died)
```

- [x] **Step 4:** Add handler function for enemy death in `scripts/game.gd`, after the `_count_living_units()` function:

```gdscript
func _on_enemy_unit_died(gold_reward: int) -> void:
	"""Handle enemy unit death and award gold."""
	add_gold(gold_reward)
```

**Verify:**

- Ask user to:
  - Open `scripts/Unit.gd` and confirm no syntax errors
  - Open `scripts/game.gd` and confirm no syntax errors
  - Run the game and kill an enemy unit
  - Verify gold increases (check console output or HUD if gold display is already added)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Add gold display to HUD

**Files:** `scenes/ui/hud.tscn`, `scripts/hud.gd`

- [x] **Step 1:** **Godot Editor:** Add gold label to `scenes/ui/hud.tscn`:

  1. Open `scenes/ui/hud.tscn` in the Godot editor
  2. Select the HUD root node
  3. Add a new `Label` node as a child of HUD, name it `GoldLabel`
  4. Position it in the top-right area (or wherever makes sense visually)
  5. Set the text to "Gold: 100" as a placeholder
  6. In the Inspector, set a reasonable font size (e.g., 16-20)

- [x] **Step 2:** **Godot Editor:** Link the gold label in `scripts/hud.gd`:

  1. Select the HUD root node in `scenes/ui/hud.tscn`
  2. In the Inspector, find the Script section
  3. Add a new export variable: `@export var gold_label: Label`
  4. Drag the `GoldLabel` node from the scene tree into this export field

- [x] **Step 3:** Add gold label reference to `scripts/hud.gd`, after the existing node references:

```gdscript
# Node references (assign in inspector)
@export var phase_label: Label
@export var tray_panel: Panel
@export var unit_tray: GridContainer
@export var go_button: Button
@export var gold_label: Label  # NEW
```

- [x] **Step 4:** Add method to update gold display in `scripts/hud.gd`, after the `clear_tray_slot()` function:

```gdscript
func update_gold_display(amount: int) -> void:
	"""Update the gold label text."""
	if gold_label:
		gold_label.text = "Gold: %d" % amount
```

- [x] **Step 5:** Connect to Game's gold_changed signal in `scripts/hud.gd`. In `_ready()`, get reference to Game and connect:

```gdscript
func _ready() -> void:
	# Connect Go button
	if go_button:
		go_button.pressed.connect(_on_go_button_pressed)

	# Connect battle end button
	if battle_end_button:
		battle_end_button.pressed.connect(_on_battle_end_button_pressed)

	# Connect upgrade screen continue signal
	if upgrade_screen:
		upgrade_screen.continue_pressed.connect(_on_upgrade_screen_continue_pressed)

	# Ensure modal is hidden initially
	if battle_end_modal:
		battle_end_modal.visible = false

	# Get all tray slot Controls and set them up for dragging
	if unit_tray:
		for child in unit_tray.get_children():
			if child is Control:
				tray_slots.append(child)
				child.set_meta("slot_index", tray_slots.size() - 1)

	# Connect to Game's gold_changed signal
	var game := get_tree().get_first_node_in_group("game") as Game
	if game:
		game.gold_changed.connect(update_gold_display)
		# Initialize display with current gold
		update_gold_display(game.gold)
```

**Verify:**

- Ask user to:
  - Open `scenes/ui/hud.tscn` in Godot editor and confirm `GoldLabel` exists
  - Verify `gold_label` export is linked in the Inspector
  - Run the game and verify gold displays in the HUD
  - Kill an enemy unit and verify gold updates in real-time

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 5: Add gold display and cost enforcement to UpgradeScreen

**Files:** `scenes/ui/upgrade_screen.tscn`, `scripts/upgrade_screen.gd`

- [x] **Step 1:** **Godot Editor:** Add gold label to `scenes/ui/upgrade_screen.tscn`:

  1. Open `scenes/ui/upgrade_screen.tscn` in the Godot editor
  2. Select the UpgradeScreen root node
  3. Add a new `Label` node as a child, name it `GoldLabel`
  4. Position it at the top of the screen (or wherever makes sense visually)
  5. Set the text to "Gold: 100" as a placeholder
  6. In the Inspector, set a reasonable font size (e.g., 16-20)

- [x] **Step 2:** **Godot Editor:** Link the gold label in `scripts/upgrade_screen.gd`:

  1. Select the UpgradeScreen root node in `scenes/ui/upgrade_screen.tscn`
  2. In the Inspector, find the Script section
  3. Add a new export variable: `@export var gold_label: Label`
  4. Drag the `GoldLabel` node from the scene tree into this export field

- [x] **Step 3:** Add gold label reference to `scripts/upgrade_screen.gd`, after the existing node references:

```gdscript
# Recruit pane references
@export var recruit_instructions: Node
@export var recruit_data: Node
@export var recruit_button: Button
@export var gold_label: Label  # NEW
```

- [x] **Step 4:** Add method to update gold display in `scripts/upgrade_screen.gd`, after the `_get_total_upgrades()` function:

```gdscript
func update_gold_display(amount: int) -> void:
	"""Update the gold label text."""
	if gold_label:
		gold_label.text = "Gold: %d" % amount
```

- [x] **Step 5:** Connect to Game's gold_changed signal in `scripts/upgrade_screen.gd`. In `_ready()`, get reference to Game and connect:

```gdscript
func _ready() -> void:
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

	# Connect upgrade pane buttons
	if hp_button:
		hp_button.pressed.connect(_on_hp_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)

	# Connect recruit button
	if recruit_button:
		recruit_button.pressed.connect(_on_recruit_button_pressed)

	# Hide editor background at runtime
	hide_editor_background()

	# Ensure screen is hidden initially
	visible = false

	# Connect to Game's gold_changed signal
	var game := _get_game()
	if game:
		game.gold_changed.connect(update_gold_display)
```

- [x] **Step 6:** Add helper method to get unit's upgrade cost from scene. Add this after `_get_total_upgrades()`:

```gdscript
func _get_unit_upgrade_cost(unit_scene: PackedScene) -> int:
	"""Get the upgrade_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.upgrade_cost
	instance.queue_free()
	return cost


func _get_unit_base_recruit_cost(unit_scene: PackedScene) -> int:
	"""Get the base_recruit_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.base_recruit_cost
	instance.queue_free()
	return cost
```

- [x] **Step 7:** Update `_refresh_upgrade_pane()` to check gold and update button text. Replace the existing function:

```gdscript
func _refresh_upgrade_pane() -> void:
	"""Update the upgrade pane based on selected army unit."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		# No selection - show instructions, hide data
		if upgrade_instructions:
			upgrade_instructions.visible = true
		if upgrade_data:
			upgrade_data.visible = false
		if hp_button:
			hp_button.disabled = true
		if damage_button:
			damage_button.disabled = true
		return

	# Has selection - hide instructions, show data
	if upgrade_instructions:
		upgrade_instructions.visible = false
	if upgrade_data:
		upgrade_data.visible = true

	# Get army unit data
	var army_unit = army_ref[selected_army_index]
	var total_upgrades := _get_total_upgrades(army_unit.upgrades)

	# Get upgrade cost from unit scene
	var upgrade_cost := _get_unit_upgrade_cost(army_unit.unit_scene)
	var game := _get_game()
	var can_afford_upgrade := game != null and game.can_afford(upgrade_cost)

	# Update unit summary (should be inside upgrade_data)
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.show_unit_from_scene(army_unit.unit_scene, army_unit.upgrades)

	# Disable buttons if maxed or can't afford
	var maxed := total_upgrades >= 3
	if hp_button:
		hp_button.disabled = maxed or not can_afford_upgrade
		hp_button.text = "+1 HP (%dgp)" % upgrade_cost
	if damage_button:
		damage_button.disabled = maxed or not can_afford_upgrade
		damage_button.text = "+1 DMG (%dgp)" % upgrade_cost
```

- [x] **Step 8:** Update `_refresh_recruit_pane()` to check gold and update button text. Replace the existing function:

```gdscript
func _refresh_recruit_pane() -> void:
	"""Update the recruit pane based on selected enemy unit."""
	if selected_enemy_index < 0 or selected_enemy_index >= enemies_faced_ref.size():
		# No selection - show instructions, hide data
		if recruit_instructions:
			recruit_instructions.visible = true
		if recruit_data:
			recruit_data.visible = false
		if recruit_button:
			recruit_button.disabled = true
			recruit_button.text = "Recruit"
		return

	# Has selection - hide instructions, show data
	if recruit_instructions:
		recruit_instructions.visible = false
	if recruit_data:
		recruit_data.visible = true

	# Get enemy data
	var enemy_data = enemies_faced_ref[selected_enemy_index]
	var enemy_scene: PackedScene = null
	var enemy_upgrades: Dictionary = {}

	if enemy_data is Dictionary:
		enemy_scene = enemy_data.get("unit_scene")
		enemy_upgrades = enemy_data.get("upgrades", {})
	else:
		enemy_scene = enemy_data.unit_scene
		enemy_upgrades = enemy_data.upgrades

	# Update unit summary (should be inside recruit_data)
	var unit_summary := recruit_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.show_unit_from_scene(enemy_scene, enemy_upgrades)

	# Check if already recruited
	if selected_enemy_index in recruited_indices:
		if recruit_button:
			recruit_button.disabled = true
			recruit_button.text = "Recruited"
		return

	# Check army size
	if army_ref.size() >= 10:
		if recruit_button:
			recruit_button.disabled = true
			recruit_button.text = "Recruited"
		return

	# Calculate recruit cost: base_recruit_cost + (upgrade_cost * total_upgrades)
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var recruit_cost := base_cost + (upgrade_cost * total_upgrades)

	# Check if can afford
	var game := _get_game()
	var can_afford := game != null and game.can_afford(recruit_cost)

	# Update button
	if recruit_button:
		recruit_button.disabled = not can_afford
		recruit_button.text = "Recruit (%dgp)" % recruit_cost
```

- [x] **Step 9:** Update `_on_hp_button_pressed()` to spend gold before upgrading:

```gdscript
func _on_hp_button_pressed() -> void:
	"""Handle HP upgrade button press."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		return

	var army_unit = army_ref[selected_army_index]
	var total := _get_total_upgrades(army_unit.upgrades)

	if total >= 3:
		return  # Already maxed

	# Get upgrade cost and check/spend gold
	var upgrade_cost := _get_unit_upgrade_cost(army_unit.unit_scene)
	var game := _get_game()
	if game == null or not game.spend_gold(upgrade_cost):
		return  # Can't afford

	# Add HP upgrade
	if not army_unit.upgrades.has("hp"):
		army_unit.upgrades["hp"] = 0
	army_unit.upgrades["hp"] += 1

	# Update stats display immediately
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates button states and text)
	_refresh_upgrade_pane()
```

- [x] **Step 10:** Update `_on_damage_button_pressed()` to spend gold before upgrading:

```gdscript
func _on_damage_button_pressed() -> void:
	"""Handle Damage upgrade button press."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		return

	var army_unit = army_ref[selected_army_index]
	var total := _get_total_upgrades(army_unit.upgrades)

	if total >= 3:
		return  # Already maxed

	# Get upgrade cost and check/spend gold
	var upgrade_cost := _get_unit_upgrade_cost(army_unit.unit_scene)
	var game := _get_game()
	if game == null or not game.spend_gold(upgrade_cost):
		return  # Can't afford

	# Add damage upgrade
	if not army_unit.upgrades.has("damage"):
		army_unit.upgrades["damage"] = 0
	army_unit.upgrades["damage"] += 1

	# Update stats display immediately
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates button states and text)
	_refresh_upgrade_pane()
```

- [x] **Step 11:** Update `_on_recruit_button_pressed()` to spend gold before recruiting:

```gdscript
func _on_recruit_button_pressed() -> void:
	"""Handle Recruit button press."""
	if selected_enemy_index < 0 or selected_enemy_index >= enemies_faced_ref.size():
		return

	# Check if already recruited
	if selected_enemy_index in recruited_indices:
		return

	# Check army size
	if army_ref.size() >= 10:
		return

	# Get enemy data
	var enemy_data = enemies_faced_ref[selected_enemy_index]
	var enemy_scene: PackedScene = null
	var enemy_upgrades: Dictionary = {}

	if enemy_data is Dictionary:
		enemy_scene = enemy_data.get("unit_scene")
		enemy_upgrades = enemy_data.get("upgrades", {})
	else:
		enemy_scene = enemy_data.unit_scene
		enemy_upgrades = enemy_data.upgrades

	# Calculate recruit cost
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var recruit_cost := base_cost + (upgrade_cost * total_upgrades)

	# Spend gold
	var game := _get_game()
	if game == null or not game.spend_gold(recruit_cost):
		return  # Can't afford

	# Create new ArmyUnit and add to army
	if game:
		game.recruit_enemy(enemy_data)
		# Update army_ref to reflect the new unit
		army_ref = game.army

	# Mark as recruited
	recruited_indices.append(selected_enemy_index)

	# Refresh pane immediately (updates button states and text)
	_refresh_recruit_pane()
```

- [x] **Step 12:** Update `show_upgrade_screen()` to refresh panes when screen opens (so costs are recalculated):

```gdscript
func show_upgrade_screen(victory: bool, player_army: Array, enemies_faced: Array) -> void:
	"""Show the upgrade screen with army and enemy data."""
	current_victory_state = victory

	# Store references
	army_ref = player_army
	enemies_faced_ref = enemies_faced

	# Reset selection state
	selected_army_index = -1
	selected_enemy_index = -1
	recruited_indices.clear()

	# Populate trays and connect slots
	_populate_army_tray(your_army_tray, player_army)
	_populate_enemy_tray(enemies_faced_tray, enemies_faced)

	# Reset panes to instruction state
	_refresh_upgrade_pane()
	_refresh_recruit_pane()

	# Update gold display
	var game := _get_game()
	if game:
		update_gold_display(game.gold)

	# Show upgrade screen
	visible = true
```

**Verify:**

- Ask user to:
  - Open `scenes/ui/upgrade_screen.tscn` in Godot editor and confirm `GoldLabel` exists
  - Verify `gold_label` export is linked in the Inspector
  - Run the game, win a battle, and open upgrade screen
  - Verify gold displays on upgrade screen
  - Select a unit and verify upgrade buttons show costs like "+1 HP (5gp)"
  - Verify buttons disable when gold is insufficient
  - Select an enemy and verify recruit button shows cost like "Recruit (20gp)"
  - Try upgrading/recruiting and verify gold decreases

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 6: Set default values on unit scenes

**Files:** `scenes/units/squire.tscn`, `scenes/units/knight.tscn`, `scenes/units/ballista.tscn`

- [x] **Step 1:** **Godot Editor:** Set default values on `scenes/units/squire.tscn`:

  1. Open `scenes/units/squire.tscn` in the Godot editor
  2. Select the Squire root node (or the Unit instance)
  3. In the Inspector, find the new export properties:
     - Set `base_recruit_cost` to 10
     - Set `upgrade_cost` to 5
     - Set `gold_reward` to 5

- [x] **Step 2:** **Godot Editor:** Set default values on `scenes/units/knight.tscn`:

  1. Open `scenes/units/knight.tscn` in the Godot editor
  2. Select the Knight root node (or the Unit instance)
  3. In the Inspector, set:
     - Set `base_recruit_cost` to 12 (or different value if desired)
     - Set `upgrade_cost` to 5 (or different value if desired)
     - Set `gold_reward` to 6 (or different value if desired)

- [x] **Step 3:** **Godot Editor:** Set default values on `scenes/units/ballista.tscn`:
  1. Open `scenes/units/ballista.tscn` in the Godot editor
  2. Select the Ballista root node (or the Unit instance)
  3. In the Inspector, set:
     - Set `base_recruit_cost` to 15 (or different value if desired)
     - Set `upgrade_cost` to 5 (or different value if desired)
     - Set `gold_reward` to 8 (or different value if desired)

**Verify:**

- Ask user to:
  - Open each unit scene in Godot editor
  - Verify the three properties are set in the Inspector
  - Run the game and verify units have the expected costs/rewards

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Player starts with gold (configurable via `starting_gold` export on Game)
- [ ] Gold increases in real-time when enemy units are killed during battle
- [ ] Gold displays in HUD during all phases
- [ ] Gold displays on upgrade screen
- [ ] Upgrade buttons show cost in format "+1 HP (5gp)" and disable when unaffordable
- [ ] Recruit button shows cost in format "Recruit (20gp)" and disables when unaffordable
- [ ] Upgrading a unit spends gold and prevents upgrade if insufficient gold
- [ ] Recruiting a unit spends gold (base_cost + upgrade_cost \* upgrades) and prevents recruit if insufficient gold
- [ ] Gold resets to starting_gold when starting a new run (defeat or completing all levels)
- [ ] All unit scenes have `base_recruit_cost`, `upgrade_cost`, and `gold_reward` values set
