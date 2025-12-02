# Drag-and-Drop Setup Checklist

## ✅ Already Done (in code):
1. ✅ Game node is in "game" group (in `scenes/game.tscn`)
2. ✅ SpawnSlot has `mouse_filter = Control.MOUSE_FILTER_STOP` (in `spawn_slot.gd` `_ready()`)
3. ✅ SpawnSlot has `_can_drop_data()` and `_drop_data()` implemented
4. ✅ Game has `place_unit_on_slot()` function
5. ✅ HUD `_ready()` attaches `tray_slot_drag.gd` script to tray slots
6. ✅ `set_tray_unit_scenes()` sets metadata (`unit_type`, `slot_index`) on slots

## ⚠️ Potential Issues Found:

### Issue 1: Script Attachment Timing
The `tray_slot_drag.gd` script is attached in `_ready()`, but if `set_tray_unit_scenes()` is called later and clears/recreates things, the script might need to be re-attached.

**Fix needed:** Ensure script is attached when metadata is set, or attach it in `set_tray_unit_scenes()`.

### Issue 2: Missing Script Re-attachment
When `set_tray_unit_scenes()` runs (e.g., on level load), it clears slot children but doesn't ensure the drag script is still attached.

## 🔧 What Needs to be Done:

### In Godot Editor:

1. **Game Scene (`scenes/game.tscn`):**
   - ✅ Game node should be in "game" group (already done)
   - ✅ All `@export` variables should be assigned:
     - `swordsman_scene` → swordsman.tscn
     - `archer_scene` → archer.tscn  
     - `enemy_scene` → enemy.tscn
     - `starting_unit_scenes` → Array with unit scenes (you said you see units, so this is done)
     - `background_rect` → BackgroundRect node
     - `gameplay` → Gameplay node
     - `level_container` → LevelContainer node
     - `player_units` → PlayerUnits node
     - `enemy_units` → EnemyUnits node
     - `hud` → HUD node

2. **HUD Scene (`scenes/ui/hud.tscn`):**
   - ✅ All `@export` variables should be assigned (check in inspector):
     - `phase_label` → PhaseLabel
     - `tray_panel` → TrayPanel
     - `unit_tray` → UnitTray
     - `go_button` → GoButton
     - `upgrade_modal` → UpgradeModal
     - `upgrade_label` → UpgradeLabel
     - `upgrade_confirm_button` → UpgradeConfirmButton

3. **SpawnSlot Scene (`scenes/ui/spawn_slot.tscn`):**
   - ✅ Should be in "spawn_slots" group (check in Groups tab)
   - ✅ Should have `Visual` child (ColorRect)

4. **Level Scenes:**
   - ✅ Each level should have `LevelRoot` with `level_root.gd` script
   - ✅ `PlayerSpawnSlots` node with SpawnSlot instances
   - ✅ `EnemyMarkers` node with Marker2D children
   - ✅ `background_texture` export set on LevelRoot

## 🐛 Code Fix Needed:

The `tray_slot_drag.gd` script attachment should happen in `set_tray_unit_scenes()` to ensure it's attached after metadata is set, OR we should ensure the script persists when slots are cleared.

