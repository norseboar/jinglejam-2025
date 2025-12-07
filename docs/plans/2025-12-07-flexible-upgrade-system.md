# Flexible Upgrade System Implementation Plan

**Goal:** Replace hardcoded HP/Damage upgrades with a flexible system where each unit can offer 3 custom upgrades from 6 stat types.

---

## Status

- [ ] Task 1: Create Upgrade Resource
- [ ] Task 2: Update Unit Class
- [ ] Task 3: Update Upgrade Screen UI
- [ ] Task 4: Create Example Upgrade Resources
- [ ] Task 5: Configure Unit Scenes with Upgrades

---

## Summary

**Task 1: Create Upgrade Resource** — Create a new UnitUpgrade resource class with stat types, amounts, and display labels.

**Task 2: Update Unit Class** — Add available_upgrades array to Unit and update apply_upgrades() to handle all stat types generically.

**Task 3: Update Upgrade Screen UI** — Replace hardcoded hp/damage buttons with 3 dynamic upgrade slots.

**Task 4: Create Example Upgrade Resources** — Create reusable upgrade resource files for common upgrades.

**Task 5: Configure Unit Scenes with Upgrades** — Assign 3 upgrades to each unit scene in the Godot editor.

---

## Tasks

### Task 1: Create Upgrade Resource

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

**Files:** `scripts/upgrade.gd` (new file)

- [ ] **Step 1:** Create `scripts/upgrade.gd` with the UnitUpgrade resource class:

```gdscript
extends Resource
class_name UnitUpgrade

enum StatType {
	MAX_HP,
	DAMAGE,
	SPEED,
	ATTACK_RANGE,
	ATTACK_COOLDOWN,
	ARMOR
}

@export var stat_type: StatType = StatType.MAX_HP
@export var amount: int = 10
@export var label_text: String = "HP"  # Short abbreviation for UI. Can use \n for multi-line (e.g., "ATK\nCDN", "ATK\nRNG")
```

**Verify:** File is created and has no syntax errors.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Update Unit Class

**Files:** `scripts/unit.gd`

- [ ] **Step 1:** Add the available_upgrades export at the top of the Unit class (around line 28, after the gold system properties):

```gdscript
# Upgrade system
@export var available_upgrades: Array[UnitUpgrade] = []
```

- [ ] **Step 2:** Replace the entire `apply_upgrades()` function (currently lines 441-452) with the new generic implementation:

```gdscript
func apply_upgrades() -> void:
	"""Apply upgrade bonuses to base stats and update visual markers."""
	for upgrade_index in upgrades:
		var count: int = upgrades[upgrade_index]

		# Get the upgrade definition
		if upgrade_index >= available_upgrades.size():
			push_error("Invalid upgrade index: %d" % upgrade_index)
			continue

		var upgrade: UnitUpgrade = available_upgrades[upgrade_index]
		var total_amount := upgrade.amount * count

		# Apply based on stat type
		match upgrade.stat_type:
			UnitUpgrade.StatType.MAX_HP:
				max_hp += total_amount
				current_hp = max_hp  # Refresh to new max
			UnitUpgrade.StatType.DAMAGE:
				damage += total_amount
			UnitUpgrade.StatType.SPEED:
				speed += total_amount
			UnitUpgrade.StatType.ATTACK_RANGE:
				attack_range += total_amount
			UnitUpgrade.StatType.ATTACK_COOLDOWN:
				attack_cooldown -= total_amount  # Note: negative to reduce cooldown
			UnitUpgrade.StatType.ARMOR:
				armor += total_amount

	_update_upgrade_markers()
```

**Verify:** File has no syntax errors. The upgrades dictionary will now use integer keys (0, 1, 2) instead of string keys ("hp", "damage").

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update Upgrade Screen UI

**Files:** `scripts/upgrade_screen.gd`

- [ ] **Step 1:** Replace the hardcoded upgrade button/label exports (lines 19-22) with 3 dynamic slots:

Replace:

```gdscript
@export var hp_button: BaseButton
@export var damage_button: BaseButton
```

With:

```gdscript
# Dynamic upgrade slots (3 per unit)
@export var upgrade_button_1: BaseButton
@export var upgrade_button_2: BaseButton
@export var upgrade_button_3: BaseButton
@export var upgrade_label_1: Label
@export var upgrade_label_2: Label
@export var upgrade_label_3: Label
```

- [ ] **Step 2:** Remove the old button connections in `_ready()` (lines 63-66):

Remove these lines:

```gdscript
	if hp_button:
		hp_button.pressed.connect(_on_hp_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
```

- [ ] **Step 3:** Add new button connections in `_ready()` after the recruit_button connection (around line 70):

```gdscript
	# Connect upgrade buttons
	if upgrade_button_1:
		upgrade_button_1.pressed.connect(_on_upgrade_button_pressed.bind(0))
	if upgrade_button_2:
		upgrade_button_2.pressed.connect(_on_upgrade_button_pressed.bind(1))
	if upgrade_button_3:
		upgrade_button_3.pressed.connect(_on_upgrade_button_pressed.bind(2))
```

- [ ] **Step 4:** Replace the entire `_refresh_upgrade_pane()` function (lines 321-365) with the new dynamic version:

```gdscript
func _refresh_upgrade_pane() -> void:
	"""Update the upgrade pane based on selected army unit."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		# No selection - show instructions, hide data
		if upgrade_instructions:
			upgrade_instructions.visible = true
		if upgrade_data:
			upgrade_data.visible = false
		# Disable all upgrade buttons
		if upgrade_button_1:
			upgrade_button_1.disabled = true
		if upgrade_button_2:
			upgrade_button_2.disabled = true
		if upgrade_button_3:
			upgrade_button_3.disabled = true
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

	# Update upgrade price label
	if upgrade_price_label:
		upgrade_price_label.text = "Upgrade: %d Gold" % upgrade_cost

	# Get available upgrades from unit scene
	var unit_instance := army_unit.unit_scene.instantiate() as Unit
	if unit_instance == null:
		push_error("Failed to instantiate unit for upgrade display")
		return
	var available_upgrades := unit_instance.available_upgrades
	unit_instance.queue_free()

	# Disable all buttons if maxed
	var maxed := total_upgrades >= 3

	# Populate each upgrade slot (0-2)
	var upgrade_buttons := [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	var upgrade_labels := [upgrade_label_1, upgrade_label_2, upgrade_label_3]

	for i in range(3):
		var button := upgrade_buttons[i]
		var label := upgrade_labels[i]

		if i >= available_upgrades.size() or available_upgrades[i] == null:
			# No upgrade in this slot
			if button:
				button.disabled = true
				button.visible = false
			if label:
				label.visible = false
			continue

		var upgrade: UnitUpgrade = available_upgrades[i]

		# Update label text
		if label:
			label.text = "%s +%d" % [upgrade.label_text, upgrade.amount]
			label.visible = true

		# Update button state
		if button:
			button.visible = true
			button.disabled = maxed or not can_afford_upgrade
```

- [ ] **Step 5:** Replace the old `_on_hp_button_pressed()` and `_on_damage_button_pressed()` functions (lines 500-559) with a single generic handler:

```gdscript
func _on_upgrade_button_pressed(slot_index: int) -> void:
	"""Handle upgrade button press for any upgrade slot."""
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

	# Add upgrade to the specified slot
	if not army_unit.upgrades.has(slot_index):
		army_unit.upgrades[slot_index] = 0
	army_unit.upgrades[slot_index] += 1

	# Update stats display immediately
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates button states and text)
	_refresh_upgrade_pane()
```

**Verify:** File has no syntax errors. The upgrade screen now uses dynamic slots instead of hardcoded buttons.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Create Example Upgrade Resources

**Files:** Create new `.tres` files in a new folder

- [ ] **Step 1:** **Godot Editor:** Create a new folder `units/upgrades/` for storing upgrade resources.

- [ ] **Step 2:** **Godot Editor:** Create example upgrade resource files. For each one:
  1. Right-click on `units/upgrades/` folder
  2. Create New → Resource
  3. Select `UnitUpgrade` as the resource type
  4. Configure the properties in the inspector:

Example upgrades to create (including multi-line labels with \n):

- `hp_10.tres`: stat_type = MAX_HP, amount = 10, label_text = "HP"
- `hp_15.tres`: stat_type = MAX_HP, amount = 15, label_text = "HP"
- `dmg_5.tres`: stat_type = DAMAGE, amount = 5, label_text = "DMG"
- `dmg_10.tres`: stat_type = DAMAGE, amount = 10, label_text = "DMG"
- `spd_20.tres`: stat_type = SPEED, amount = 20, label_text = "SPD"
- `rng_10.tres`: stat_type = ATTACK_RANGE, amount = 10, label_text = "ATK\nRNG" (multi-line)
- `cdn_0.5.tres`: stat_type = ATTACK_COOLDOWN, amount = 0.5, label_text = "ATK\nCDN" (multi-line)
- `arm_2.tres`: stat_type = ARMOR, amount = 2, label_text = "ARM"

**Verify:** Ask user to confirm the upgrade resources are created and visible in the FileSystem panel.

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 5: Configure Unit Scenes with Upgrades

**Files:** All unit scene files (`.tscn` files in `units/` subdirectories)

- [ ] **Step 1:** **Godot Editor:** For each unit scene, assign 3 upgrades. Example for `units/humans/knight.tscn`:
  1. Open the unit scene in the Godot editor
  2. Select the root node (e.g., "Knight")
  3. In the Inspector, find the "Available Upgrades" property (under the Unit script section)
  4. Set the array size to 3
  5. Drag 3 upgrade resources from `units/upgrades/` into the array slots
  6. Save the scene

Example configuration for Knight:

- Slot 0: `hp_15.tres` (HP +15)
- Slot 1: `dmg_10.tres` (DMG +10)
- Slot 2: `arm_2.tres` (ARM +2)

- [ ] **Step 2:** **Godot Editor:** Apply the same process to all other unit scenes. Choose appropriate upgrades for each unit type based on their role.

**Verify:** Ask user to:

- Open a few unit scenes
- Confirm each has exactly 3 upgrades assigned
- Confirm no errors appear in the console

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] UnitUpgrade resource class exists with 6 stat types
- [ ] Unit class has available_upgrades array and updated apply_upgrades()
- [ ] Upgrade screen dynamically shows 3 upgrade slots per unit
- [ ] Example upgrade resources are created
- [ ] All unit scenes have 3 upgrades assigned
- [ ] User can select a unit and see 3 upgrade options with custom labels (e.g., "HP +10", "DMG +5", "ATK\nRNG +10")
- [ ] Clicking an upgrade button spends gold and applies the upgrade
- [ ] Units with 3 total upgrades cannot purchase more
- [ ] No errors in console when viewing upgrade screen
