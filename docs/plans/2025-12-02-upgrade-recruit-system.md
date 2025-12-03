# ✅ Upgrade & Recruit System Implementation Plan

**Goal:** Add clickable unit selection to the upgrade screen with upgrade pane (HP/Damage buttons) for army units and recruit pane for enemy units, including unit info display (sprite, name, description, stats).

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [x] Task 1: Add unit display properties to Unit.gd
- [x] Task 2: Create upgrade slot script with click selection
- [x] Task 3: Create reusable UnitSummary scene
- [x] Task 4: Add panes to upgrade screen scene (Godot Editor)
- [x] Task 5: Add selection and pane state to upgrade_screen.gd
- [x] Task 6: Implement upgrade functionality
- [x] Task 7: Implement recruit functionality

---

## Summary

**Task 1: Add unit display properties** — Add `display_name` and `description` exports to Unit.gd so each unit scene can define its name and description.

**Task 2: Create upgrade slot script** — New script for upgrade screen slots that handles click-to-select and selection highlight.

**Task 3: Create reusable UnitSummary scene** — Create a scene with sprite, name, description, and stats display that can be instanced in both panes.

**Task 4: Add panes to upgrade screen scene** — Godot editor work to add upgrade pane and recruit pane, each containing a UnitSummary instance plus action buttons.

**Task 5: Add selection and pane state** — Update upgrade_screen.gd with selection tracking, slot connections, unit info display, and pane refresh logic.

**Task 6: Implement upgrade functionality** — Add HP/Damage upgrade logic with 3-upgrade cap and immediate UI feedback.

**Task 7: Implement recruit functionality** — Add recruit logic with army size check and immediate "Recruited" state feedback.

---

## Tasks

### ✅ Task 1: Add unit display properties to Unit.gd

**Files:** `scripts/unit.gd`

- [x] **Step 1:** Add display properties to `scripts/unit.gd`. Add these exports after the existing stat exports (around line 10):

```gdscript
# Display info
@export var display_name: String = "Unit"
@export var description: String = "A basic unit."
```

- [x] **Step 2:** **Godot Editor:** Set display_name and description for each unit scene. Ask the user to update these in the inspector for each unit:

**`scenes/units/swordsman.tscn`:**

- `display_name`: "Swordsman"
- `description`: "A reliable melee fighter."

**`scenes/units/squire.tscn`:**

- `display_name`: "Squire"
- `description`: "A young warrior in training."

**`scenes/units/knight.tscn`:**

- `display_name`: "Knight"
- `description`: "An armored melee combatant."

**`scenes/units/archer.tscn`:**

- `display_name`: "Archer"
- `description`: "Attacks from range with arrows."

**`scenes/units/ballista.tscn`:**

- `display_name`: "Ballista"
- `description`: "Powerful siege weapon with long range."

(User can adjust these descriptions as they like)

**Verify:**

- Ask user to:
  - Open a unit scene (e.g., `swordsman.tscn`)
  - Confirm `display_name` and `description` exports appear in the inspector
  - Set values for all unit scenes

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create upgrade slot script with click selection

**Files:** `scripts/upgrade_slot.gd`

- [x] **Step 1:** Create `scripts/upgrade_slot.gd` with the following content:

```gdscript
extends Control
class_name UpgradeSlot

signal slot_clicked(slot_index: int)

@export var texture_rect: TextureRect
@export var selection_highlight: ColorRect

var slot_index: int = -1


func _ready() -> void:
	# Ensure selection highlight is hidden initially
	if selection_highlight:
		selection_highlight.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)
			accept_event()


func set_selected(selected: bool) -> void:
	"""Show or hide the selection highlight."""
	if selection_highlight:
		selection_highlight.visible = selected


func set_unit_texture(texture: Texture2D) -> void:
	"""Set the unit texture to display in this slot."""
	if texture_rect:
		texture_rect.texture = texture


func has_unit() -> bool:
	"""Check if this slot has a unit texture assigned."""
	return texture_rect != null and texture_rect.texture != null
```

- [x] **Step 2:** **Godot Editor:** Update `scenes/ui/unit_upgrade_slot.tscn` to use the new script:

1. Open `scenes/ui/unit_upgrade_slot.tscn` in Godot
2. Select the root `UnitUpgradeSlot` node
3. In the Inspector, change the script from `tray_slot_drag.gd` to `upgrade_slot.gd`
4. In the Inspector, set `selection_highlight` to point to the `SelectedRect` node
5. Verify `texture_rect` still points to `TextureRect`
6. Save the scene

**Verify:**

- Ask user to:
  - Open `unit_upgrade_slot.tscn` and confirm it uses `upgrade_slot.gd`
  - Confirm `selection_highlight` and `texture_rect` exports are assigned
  - No errors in the console

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Create reusable UnitSummary scene

**Files:** `scripts/unit_summary.gd`, `scenes/ui/unit_summary.tscn`

- [x] **Step 1:** Create `scripts/unit_summary.gd` with the following content:

```gdscript
extends Control
class_name UnitSummary

@export var unit_sprite: TextureRect
@export var unit_name_label: Label
@export var unit_description_label: Label
@export var stats_label: Label

# Cached unit data for stat updates
var current_unit_scene: PackedScene = null


func show_placeholder(text: String) -> void:
	"""Show placeholder text when no unit is selected."""
	if unit_sprite:
		unit_sprite.texture = null
	if unit_name_label:
		unit_name_label.text = text
	if unit_description_label:
		unit_description_label.text = ""
	if stats_label:
		stats_label.text = ""


func show_unit_from_scene(unit_scene: PackedScene, upgrades: Dictionary = {}) -> void:
	"""Display unit info by instantiating the scene to read its properties."""
	if unit_scene == null:
		show_placeholder("No unit")
		return

	current_unit_scene = unit_scene

	# Instantiate to read properties
	var instance := unit_scene.instantiate()

	# Get texture from AnimatedSprite2D
	var texture: Texture2D = null
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")

	if sprite and sprite.sprite_frames:
		var anim_name := "idle" if sprite.sprite_frames.has_animation("idle") else "default"
		if sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			texture = sprite.sprite_frames.get_frame_texture(anim_name, 0)

	if unit_sprite:
		unit_sprite.texture = texture

	# Get display info (if Unit script is attached)
	if instance is Unit:
		var unit := instance as Unit

		if unit_name_label:
			unit_name_label.text = unit.display_name

		if unit_description_label:
			unit_description_label.text = unit.description

		# Calculate stats with upgrades applied
		var hp := unit.max_hp + upgrades.get("hp", 0)
		var dmg := unit.damage + upgrades.get("damage", 0)
		var spd := int(unit.speed)
		var rng := int(unit.attack_range)

		if stats_label:
			stats_label.text = "HP: %d  DMG: %d  SPD: %d  RNG: %d" % [hp, dmg, spd, rng]
	else:
		# Fallback if not a Unit
		if unit_name_label:
			unit_name_label.text = "Unknown"
		if unit_description_label:
			unit_description_label.text = ""
		if stats_label:
			stats_label.text = ""

	instance.queue_free()


func update_stats(upgrades: Dictionary) -> void:
	"""Update just the stats display with new upgrade values."""
	if current_unit_scene == null:
		return

	# Re-instantiate to get base stats
	var instance := current_unit_scene.instantiate()

	if instance is Unit:
		var unit := instance as Unit
		var hp := unit.max_hp + upgrades.get("hp", 0)
		var dmg := unit.damage + upgrades.get("damage", 0)
		var spd := int(unit.speed)
		var rng := int(unit.attack_range)

		if stats_label:
			stats_label.text = "HP: %d  DMG: %d  SPD: %d  RNG: %d" % [hp, dmg, spd, rng]

	instance.queue_free()
```

- [x] **Step 2:** **Godot Editor:** Create `scenes/ui/unit_summary.tscn`:

1. Create a new scene with root node `Control`, name it `UnitSummary`
2. Attach the script `scripts/unit_summary.gd` to the root
3. Set custom minimum size to approximately 180x80
4. Add an `HBoxContainer` as child of root, anchored to fill
5. Inside HBoxContainer, add:
   - `TextureRect` named `UnitSprite`
     - Set custom minimum size to 64x64
     - Set expand_mode to "Ignore Size"
     - Set stretch_mode to "Keep Aspect Centered"
   - `VBoxContainer` named `InfoContainer`
6. Inside InfoContainer, add:
   - `Label` named `UnitName` with text "Unit Name"
   - `Label` named `UnitDescription` with text "A unit description."
   - `Label` named `StatsLabel` with text "HP: 3 DMG: 1 SPD: 100 RNG: 50"
7. Wire up exports on the root UnitSummary node:
   - `unit_sprite` → UnitSprite
   - `unit_name_label` → InfoContainer/UnitName
   - `unit_description_label` → InfoContainer/UnitDescription
   - `stats_label` → InfoContainer/StatsLabel
8. Save as `scenes/ui/unit_summary.tscn`

**Verify:**

- Ask user to:
  - Open `unit_summary.tscn` and confirm it has the correct structure
  - Confirm all exports are wired up
  - No errors in the console

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Add panes to upgrade screen scene (Godot Editor)

**Files:** `scenes/game.tscn` (Godot Editor work)

This task requires Godot Editor work. The executor should ask the user to perform these steps. Each pane will contain a UnitSummary instance plus action buttons.

- [ ] **Step 1:** **Godot Editor:** Add the upgrade pane above the PlayerArmy panel:

1. Open `scenes/game.tscn` in Godot
2. Navigate to `SubViewportContainer/SubViewport/UI/HUD/UpgradeScreen`
3. Add a new `PanelContainer` as a child of `UpgradeScreen`, name it `UpgradePane`
4. Position it above the `PlayerArmy` panel (user can adjust exact position)
5. Set size to approximately 200x140
6. Add a `VBoxContainer` child inside `UpgradePane`
7. Inside the VBoxContainer:
   - Instance `scenes/ui/unit_summary.tscn`, name it `UnitSummary`
   - Add a `Label` named `UpgradeLabel` with text "Select a unit to upgrade"
   - Add an `HBoxContainer` named `ButtonContainer`
8. Inside ButtonContainer, add two `Button` nodes:
   - `HPButton` with text "+HP"
   - `DamageButton` with text "+Damage"
9. Save the scene

- [ ] **Step 2:** **Godot Editor:** Add the recruit pane above the EnemyArmy panel:

1. Still in `scenes/game.tscn`, under `UpgradeScreen`
2. Add a new `PanelContainer` as a child of `UpgradeScreen`, name it `RecruitPane`
3. Position it above the `EnemyArmy` panel (user can adjust exact position)
4. Set size to approximately 200x140
5. Add a `VBoxContainer` child inside `RecruitPane`
6. Inside the VBoxContainer:
   - Instance `scenes/ui/unit_summary.tscn`, name it `UnitSummary`
   - Add a `Label` named `RecruitLabel` with text "Select an enemy to recruit"
   - Add a `Button` named `RecruitButton` with text "Recruit"
7. Save the scene

- [ ] **Step 3:** **Godot Editor:** Note the node paths for wiring up exports in the next task:

Upgrade Pane paths:

- `upgrade_pane` → UpgradePane
- `upgrade_unit_summary` → UpgradePane/VBoxContainer/UnitSummary
- `upgrade_label` → UpgradePane/VBoxContainer/UpgradeLabel
- `hp_button` → UpgradePane/VBoxContainer/ButtonContainer/HPButton
- `damage_button` → UpgradePane/VBoxContainer/ButtonContainer/DamageButton

Recruit Pane paths:

- `recruit_pane` → RecruitPane
- `recruit_unit_summary` → RecruitPane/VBoxContainer/UnitSummary
- `recruit_label` → RecruitPane/VBoxContainer/RecruitLabel
- `recruit_button` → RecruitPane/VBoxContainer/RecruitButton

**Verify:**

- Ask user to:
  - Run the game, win a battle, and view the upgrade screen
  - Confirm the two panes are visible above each tray
  - Each pane shows a UnitSummary with placeholder text

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Add selection and pane state to upgrade_screen.gd

**Files:** `scripts/upgrade_screen.gd`

- [x] **Step 1:** Add new exports for pane nodes at the top of the file, after the existing exports:

```gdscript
# Upgrade pane references
@export var upgrade_pane: PanelContainer
@export var upgrade_unit_summary: UnitSummary
@export var upgrade_label: Label
@export var hp_button: Button
@export var damage_button: Button

# Recruit pane references
@export var recruit_pane: PanelContainer
@export var recruit_unit_summary: UnitSummary
@export var recruit_label: Label
@export var recruit_button: Button
```

- [x] **Step 2:** Add state variables after the existing state section:

```gdscript
# Selection state
var selected_army_index: int = -1
var selected_enemy_index: int = -1
var recruited_indices: Array[int] = []

# References to slot arrays (populated when screen shows)
var army_slots: Array[UpgradeSlot] = []
var enemy_slots: Array[UpgradeSlot] = []

# Reference to game's army (set when screen shows)
var army_ref: Array = []
var enemies_faced_ref: Array = []
```

- [x] **Step 3:** Update `_ready()` to connect button signals. Add after the existing `_ready()` code:

```gdscript
	# Connect upgrade pane buttons
	if hp_button:
		hp_button.pressed.connect(_on_hp_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)

	# Connect recruit button
	if recruit_button:
		recruit_button.pressed.connect(_on_recruit_button_pressed)
```

- [x] **Step 4:** Update `show_upgrade_screen()` to store references and connect slots. Replace the existing function:

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

	# Show upgrade screen
	visible = true
```

- [x] **Step 5:** Add `_populate_army_tray()` function to replace the generic `_populate_display_tray` for army:

```gdscript
func _populate_army_tray(tray: GridContainer, units: Array) -> void:
	"""Populate the army tray with unit textures and connect click signals."""
	if not tray:
		return

	army_slots.clear()

	var slot_index := 0
	for child in tray.get_children():
		if child is UpgradeSlot:
			var slot := child as UpgradeSlot
			army_slots.append(slot)
			slot.slot_index = slot_index

			# Disconnect any existing connections
			if slot.slot_clicked.is_connected(_on_army_slot_clicked):
				slot.slot_clicked.disconnect(_on_army_slot_clicked)

			# Connect click signal
			slot.slot_clicked.connect(_on_army_slot_clicked)

			# Set texture
			if slot_index < units.size():
				var unit_data = units[slot_index]
				var scene: PackedScene = unit_data.unit_scene
				if scene:
					var texture := _get_texture_from_scene(scene)
					slot.set_unit_texture(texture)
				else:
					slot.set_unit_texture(null)
			else:
				slot.set_unit_texture(null)

			# Reset selection state
			slot.set_selected(false)

			slot_index += 1
```

- [x] **Step 6:** Add `_populate_enemy_tray()` function:

```gdscript
func _populate_enemy_tray(tray: GridContainer, units: Array) -> void:
	"""Populate the enemy tray with unit textures and connect click signals."""
	if not tray:
		return

	enemy_slots.clear()

	var slot_index := 0
	for child in tray.get_children():
		if child is UpgradeSlot:
			var slot := child as UpgradeSlot
			enemy_slots.append(slot)
			slot.slot_index = slot_index

			# Disconnect any existing connections
			if slot.slot_clicked.is_connected(_on_enemy_slot_clicked):
				slot.slot_clicked.disconnect(_on_enemy_slot_clicked)

			# Connect click signal
			slot.slot_clicked.connect(_on_enemy_slot_clicked)

			# Set texture
			if slot_index < units.size():
				var unit_data = units[slot_index]
				var scene: PackedScene = null
				if unit_data is Dictionary:
					scene = unit_data.get("unit_scene")
				else:
					scene = unit_data.unit_scene

				if scene:
					var texture := _get_texture_from_scene(scene)
					slot.set_unit_texture(texture)
				else:
					slot.set_unit_texture(null)
			else:
				slot.set_unit_texture(null)

			# Reset selection state
			slot.set_selected(false)

			slot_index += 1
```

- [x] **Step 7:** Add slot click handlers:

```gdscript
func _on_army_slot_clicked(slot_index: int) -> void:
	"""Handle click on an army slot."""
	# Check if slot has a unit
	if slot_index >= army_ref.size():
		return

	# Deselect previous
	if selected_army_index >= 0 and selected_army_index < army_slots.size():
		army_slots[selected_army_index].set_selected(false)

	# Select new
	selected_army_index = slot_index
	if slot_index < army_slots.size():
		army_slots[slot_index].set_selected(true)

	_refresh_upgrade_pane()


func _on_enemy_slot_clicked(slot_index: int) -> void:
	"""Handle click on an enemy slot."""
	# Check if slot has an enemy
	if slot_index >= enemies_faced_ref.size():
		return

	# Deselect previous
	if selected_enemy_index >= 0 and selected_enemy_index < enemy_slots.size():
		enemy_slots[selected_enemy_index].set_selected(false)

	# Select new
	selected_enemy_index = slot_index
	if slot_index < enemy_slots.size():
		enemy_slots[slot_index].set_selected(true)

	_refresh_recruit_pane()
```

- [x] **Step 8:** Add pane refresh functions:

```gdscript
func _refresh_upgrade_pane() -> void:
	"""Update the upgrade pane based on selected army unit."""
	if not upgrade_label or not hp_button or not damage_button:
		return

	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		# No selection - show instruction
		if upgrade_unit_summary:
			upgrade_unit_summary.show_placeholder("Select a unit to upgrade")
		upgrade_label.text = ""
		hp_button.disabled = true
		damage_button.disabled = true
		return

	# Get army unit data
	var army_unit = army_ref[selected_army_index]
	var total_upgrades := _get_total_upgrades(army_unit.upgrades)

	# Update unit summary
	if upgrade_unit_summary:
		upgrade_unit_summary.show_unit_from_scene(army_unit.unit_scene, army_unit.upgrades)

	upgrade_label.text = "%d/3 upgrades" % total_upgrades

	# Disable buttons if maxed
	var maxed := total_upgrades >= 3
	hp_button.disabled = maxed
	damage_button.disabled = maxed


func _refresh_recruit_pane() -> void:
	"""Update the recruit pane based on selected enemy unit."""
	if not recruit_label or not recruit_button:
		return

	if selected_enemy_index < 0 or selected_enemy_index >= enemies_faced_ref.size():
		# No selection - show instruction
		if recruit_unit_summary:
			recruit_unit_summary.show_placeholder("Select an enemy to recruit")
		recruit_label.text = ""
		recruit_button.disabled = true
		recruit_button.text = "Recruit"
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

	# Update unit summary
	if recruit_unit_summary:
		recruit_unit_summary.show_unit_from_scene(enemy_scene, enemy_upgrades)

	# Check if already recruited
	if selected_enemy_index in recruited_indices:
		recruit_label.text = "Already recruited!"
		recruit_button.disabled = true
		recruit_button.text = "Recruited"
		return

	# Check army size
	if army_ref.size() >= 10:
		recruit_label.text = "Army is full (10/10)"
		recruit_button.disabled = true
		recruit_button.text = "Recruit"
		return

	# Can recruit
	recruit_label.text = "Add to your army?"
	recruit_button.disabled = false
	recruit_button.text = "Recruit"


func _get_total_upgrades(upgrades: Dictionary) -> int:
	"""Count total upgrades from an upgrades dictionary."""
	var total := 0
	for count in upgrades.values():
		total += count
	return total
```

- [x] **Step 9:** Add placeholder button handlers (will be implemented in next tasks):

```gdscript
func _on_hp_button_pressed() -> void:
	"""Handle HP upgrade button press."""
	pass  # Implemented in Task 4


func _on_damage_button_pressed() -> void:
	"""Handle Damage upgrade button press."""
	pass  # Implemented in Task 4


func _on_recruit_button_pressed() -> void:
	"""Handle Recruit button press."""
	pass  # Implemented in Task 5
```

- [x] **Step 10:** Remove the old `_populate_display_tray()` function (it's replaced by the two new functions).

- [ ] **Step 11:** **Godot Editor:** Wire up all the new exports in `scenes/game.tscn`:

1. Open `scenes/game.tscn`
2. Select the `UpgradeScreen` node
3. In the Inspector, assign all the new exports to their corresponding nodes (you can wire them up however you prefer - no exact path matching required)
4. Save the scene

**Verify:**

- Ask user to:
  - Run the game, win a battle, view the upgrade screen
  - Click on a unit in the army tray - should show selection highlight and update pane to "0/3 upgrades"
  - Click on an enemy in the enemy tray - should show selection highlight and "Recruit" button enabled
  - Clicking different units should switch selection

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 6: Implement upgrade functionality

**Files:** `scripts/upgrade_screen.gd`

- [x] **Step 1:** Implement `_on_hp_button_pressed()`:

```gdscript
func _on_hp_button_pressed() -> void:
	"""Handle HP upgrade button press."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		return

	var army_unit = army_ref[selected_army_index]
	var total := _get_total_upgrades(army_unit.upgrades)

	if total >= 3:
		return  # Already maxed

	# Add HP upgrade
	if not army_unit.upgrades.has("hp"):
		army_unit.upgrades["hp"] = 0
	army_unit.upgrades["hp"] += 1

	# Update stats display immediately
	if upgrade_unit_summary:
		upgrade_unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates label and button states)
	_refresh_upgrade_pane()
```

- [x] **Step 2:** Implement `_on_damage_button_pressed()`:

```gdscript
func _on_damage_button_pressed() -> void:
	"""Handle Damage upgrade button press."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		return

	var army_unit = army_ref[selected_army_index]
	var total := _get_total_upgrades(army_unit.upgrades)

	if total >= 3:
		return  # Already maxed

	# Add damage upgrade
	if not army_unit.upgrades.has("damage"):
		army_unit.upgrades["damage"] = 0
	army_unit.upgrades["damage"] += 1

	# Update stats display immediately
	if upgrade_unit_summary:
		upgrade_unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates label and button states)
	_refresh_upgrade_pane()
```

**Verify:**

- Ask user to:
  - Run the game, win a battle, view the upgrade screen
  - Select a unit from your army
  - Click "+HP" - label should update to "1/3 upgrades"
  - Click "+Damage" twice - label should update to "3/3 upgrades" and buttons should disable
  - Continue to next battle, place that unit, win, and upgrade screen should still show "3/3 upgrades" for that unit
  - In battle, upgraded unit should have higher HP/damage (test by counting hits)

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 7: Implement recruit functionality

**Files:** `scripts/upgrade_screen.gd`, `scripts/game.gd`

- [x] **Step 1:** Implement `_on_recruit_button_pressed()` in `scripts/upgrade_screen.gd`:

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

	# Create new ArmyUnit and add to army
	# We need to access Game to create the ArmyUnit properly
	var game := _get_game()
	if game:
		game.recruit_enemy(enemy_data)

	# Mark as recruited
	recruited_indices.append(selected_enemy_index)

	# Refresh pane immediately
	_refresh_recruit_pane()


func _get_game() -> Node:
	"""Find the Game node."""
	var node := get_tree().get_first_node_in_group("game")
	return node
```

- [x] **Step 2:** Add `recruit_enemy()` function to `scripts/game.gd`. Add this after `place_unit_from_army()`:

```gdscript
func recruit_enemy(enemy_data: Dictionary) -> void:
	"""Add an enemy to the player's army."""
	if army.size() >= 10:
		push_warning("Cannot recruit: army is full")
		return

	var new_unit := ArmyUnit.new()
	new_unit.unit_scene = enemy_data.get("unit_scene")
	new_unit.unit_type = enemy_data.get("unit_type", "unknown")
	new_unit.placed = false
	new_unit.upgrades = enemy_data.get("upgrades", {}).duplicate()

	army.append(new_unit)
```

**Verify:**

- Ask user to:
  - Run the game, win a battle against multiple enemy types, view the upgrade screen
  - Select an enemy unit
  - Click "Recruit" - button should change to "Recruited" and disable
  - Click the same enemy again - should still show "Recruited"
  - Continue to next battle
  - In the army tray, the recruited enemy should now appear
  - Place the recruited unit and verify it works in battle

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [x] Clicking a unit in the upgrade screen selects it (shows highlight)
- [x] Clicking a different unit switches selection
- [x] Unit summary shows sprite, name, description, and stats when unit selected
- [x] Stats update immediately when upgrades are applied
- [x] Upgrade pane shows "X/3 upgrades" when army unit selected
- [x] HP and Damage buttons increment upgrades
- [x] Buttons disable when unit reaches 3 upgrades
- [x] Recruit pane shows "Recruit" button when enemy selected
- [x] Clicking Recruit adds enemy to army and shows "Recruited"
- [x] Cannot recruit same enemy twice
- [x] Cannot recruit if army is full (10 units)
- [x] Upgrades persist between battles
- [x] Recruited units appear in next battle's army tray
- [x] No errors in the console
