# Integrate UnitSlot and UnitSlotGroup into Battle Selection and Upgrade Screens Plan

**Goal:** Replace custom slot implementations in battle selection screen and upgrade/recruit screen with the new UnitSlot and UnitSlotGroup components for consistent UI and behavior.

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

---

## Status

- [ ] Task 1: Update BattleOption to use UnitSlotGroup
- [ ] Task 2: Update UpgradeScreen to use UnitSlotGroup for army tray
- [ ] Task 3: Update UpgradeScreen to use UnitSlotGroup for enemy tray
- [ ] Task 4: Remove UpgradeSlot script (no longer needed)

---

## Summary

**Task 1: Update BattleOption to use UnitSlotGroup** — Replace the enemy_grid custom slot system with UnitSlotGroup, converting EnemyMarker data to ArmyUnit objects for display.

**Task 2: Update UpgradeScreen to use UnitSlotGroup for army tray** — Replace UpgradeSlot usage in the army tray with UnitSlotGroup, updating population logic to use `set_unit()` with ArmyUnit objects.

**Task 3: Update UpgradeScreen to use UnitSlotGroup for enemy tray** — Replace UpgradeSlot usage in the enemy tray with UnitSlotGroup, converting enemy data dictionaries to ArmyUnit objects for display.

**Task 4: Remove UpgradeSlot script** — Delete the UpgradeSlot script file since it's no longer used anywhere.

---

## Tasks

### Task 1: Update BattleOption to use UnitSlotGroup

**Files:** `scripts/battle_option.gd`, `scenes/ui/battle_option.tscn` (Godot Editor)

**Overview:** Replace the custom enemy grid slot system with UnitSlotGroup. The enemy_grid should become a UnitSlotGroup, and we'll populate it with UnitSlot instances that display ArmyUnit objects created from EnemyMarker data.

- [ ] **Step 1:** Update `battle_option.gd` to use UnitSlotGroup instead of custom slots.

  - Change `@export var enemy_grid: GridContainer` to `@export var enemy_slot_group: UnitSlotGroup`
  - Remove `_populate_enemy_grid()` method
  - Remove `_get_texture_from_scene()` method (no longer needed)
  - Add new `_populate_enemy_slots()` method that:
    - Gets the UnitSlotGroup's slots array
    - Creates ArmyUnit objects from EnemyMarker data
    - Calls `set_unit()` on each slot with the corresponding ArmyUnit
  - Update `setup()` to call `_populate_enemy_slots()` instead of `_populate_enemy_grid()`

- [ ] **Step 2:** Update battle_option.tscn in Godot Editor.

  - Replace the `enemy_grid` GridContainer with a UnitSlotGroup instance (use `scenes/ui/unit_slot_group.tscn` or create new)
  - Ensure the UnitSlotGroup has enough UnitSlot children (at least 10 slots)
  - Update the script reference to point to the new `enemy_slot_group` export variable

**Verify:**
- Ask user to verify the battle selection screen shows enemy units correctly
- Check that enemy units display with animated sprites
- Verify selection/hover behavior works if needed

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 2: Update UpgradeScreen to use UnitSlotGroup for army tray

**Files:** `scripts/upgrade_screen.gd`, upgrade screen scene (Godot Editor)

**Overview:** Replace UpgradeSlot usage in the army tray with UnitSlotGroup. The `your_army_tray` should become a UnitSlotGroup, and we'll populate it using `set_unit()` with ArmyUnit objects from `army_ref`.

- [x] **Step 1:** Update `upgrade_screen.gd` to use UnitSlotGroup for army tray.

  - Change `@export var your_army_tray: GridContainer` to `@export var army_slot_group: UnitSlotGroup`
  - Change `var army_slots: Array[UpgradeSlot] = []` to `var army_slots: Array[UnitSlot] = []`
  - Update `_populate_army_tray()` method:
    - Remove all UpgradeSlot-specific logic (texture setting, slot_clicked signals)
    - Get slots from `army_slot_group.slots` array
    - Loop through slots and call `set_unit()` with ArmyUnit objects from `army_ref`
    - Connect to `unit_slot_clicked` signal instead of `slot_clicked`
    - Update slot selection state using `set_selected()`
  - Update `_on_army_slot_clicked()` to accept `UnitSlot` parameter instead of `slot_index: int`
  - Remove `_get_texture_from_scene()` method (no longer needed)

- [ ] **Step 2:** Update upgrade screen scene in Godot Editor.

  - Replace the `your_army_tray` GridContainer with a UnitSlotGroup instance
  - Ensure the UnitSlotGroup has enough UnitSlot children (at least 10 slots)
  - Update the script reference to point to the new `army_slot_group` export variable

**Verify:**
- Ask user to verify the army tray displays units correctly with animated sprites
- Check that clicking units selects them and shows upgrade pane
- Verify selection highlighting works

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 3: Update UpgradeScreen to use UnitSlotGroup for enemy tray

**Files:** `scripts/upgrade_screen.gd`, upgrade screen scene (Godot Editor)

**Overview:** Replace UpgradeSlot usage in the enemy tray with UnitSlotGroup. The `enemies_faced_tray` should become a UnitSlotGroup, and we'll populate it using `set_unit()` with ArmyUnit objects created from enemy data dictionaries.

- [x] **Step 1:** Update `upgrade_screen.gd` to use UnitSlotGroup for enemy tray.

  - Change `@export var enemies_faced_tray: GridContainer` to `@export var enemy_slot_group: UnitSlotGroup`
  - Change `var enemy_slots: Array[UpgradeSlot] = []` to `var enemy_slots: Array[UnitSlot] = []`
  - Update `_populate_enemy_tray()` method:
    - Remove all UpgradeSlot-specific logic (texture setting, slot_clicked signals)
    - Get slots from `enemy_slot_group.slots` array
    - Loop through slots and create ArmyUnit objects from enemy data dictionaries using `ArmyUnit.create_from_enemy()`
    - Call `set_unit()` on each slot with the created ArmyUnit
    - Connect to `unit_slot_clicked` signal instead of `slot_clicked`
    - Update slot selection state using `set_selected()`
  - Update `_on_enemy_slot_clicked()` to accept `UnitSlot` parameter instead of `slot_index: int`

- [ ] **Step 2:** Update upgrade screen scene in Godot Editor.

  - Replace the `enemies_faced_tray` GridContainer with a UnitSlotGroup instance
  - Ensure the UnitSlotGroup has enough UnitSlot children (at least 10 slots)
  - Update the script reference to point to the new `enemy_slot_group` export variable

**Verify:**
- Ask user to verify the enemy tray displays units correctly with animated sprites
- Check that clicking enemy units selects them and shows recruit pane
- Verify selection highlighting works
- Test that recruiting still works correctly

**After this task:** STOP and ask user to verify manually before continuing.

---

### Task 4: Remove UpgradeSlot script

**Files:** `scripts/upgrade_slot.gd`

**Overview:** The UpgradeSlot script is no longer needed since we've replaced all usage with UnitSlot.

- [x] **Step 1:** Delete `scripts/upgrade_slot.gd` file.

**Verify:**
- Check that no other files reference UpgradeSlot
- Confirm the game still compiles and runs without errors

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] Battle selection screen displays enemy units using UnitSlotGroup with animated sprites
- [ ] Upgrade screen army tray displays units using UnitSlotGroup with animated sprites
- [ ] Upgrade screen enemy tray displays units using UnitSlotGroup with animated sprites
- [ ] Click selection works correctly in both screens
- [ ] Upgrade functionality still works correctly
- [ ] Recruit functionality still works correctly
- [ ] UpgradeSlot script is removed
- [ ] No compilation errors or runtime errors

---

## Notes

- UnitSlot uses `set_unit(army_unit: ArmyUnit)` to populate slots, so we need to convert enemy data to ArmyUnit objects where needed
- UnitSlotGroup automatically manages selection state (only one selected at a time)
- UnitSlot handles hover/click signals internally, so we connect to `unit_slot_clicked` instead of custom signals
- The `slot_index` property on UnitSlot is set automatically by UnitSlotGroup, so we can use it to map back to the original data arrays

