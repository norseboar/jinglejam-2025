# UnitSlot Component Implementation Plan

**Goal:** Create a reusable UnitSlot component that displays units with animated sprites, handles selection, hover/click detection, and optional drag-and-drop support.

---

## Status

- [x] Task 1: Add ArmyUnit.create_from_enemy() static method (moved to separate army_unit.gd script)
- [x] Task 2: Create UnitSlot script
- [x] Task 3: Create UnitSlot scene structure
- [x] Task 4: Update HUD to use UnitSlot for tray slots
- [x] Task 5: Update SpawnSlot to work with UnitSlot drag data

---

## Summary

**Task 1: Add ArmyUnit.create_from_enemy() static method** — Add a static factory method to convert enemy dictionaries to ArmyUnit instances.

**Task 2: Create UnitSlot script** — Implement the UnitSlot class with unit display, selection, hover/click signals, and optional drag-and-drop.

**Task 3: Create UnitSlot scene structure** — Create the scene file with AnimatedSprite2D, SelectionNode, and MouseCapture nodes.

**Task 4: Update HUD to use UnitSlot for tray slots** — Replace current tray slot implementation with UnitSlot instances.

**Task 5: Update SpawnSlot to work with UnitSlot drag data** — Ensure SpawnSlot can handle drag data from UnitSlot (which includes army_unit in addition to army_index).

---

## Tasks

> **For executor:** Follow `.cursor/rules/core-rules.mdc` — follow the plan exactly, stop after each step, don't guess.

### ✅ Task 1: Add ArmyUnit.create_from_enemy() static method

**Files:** `scripts/game.gd`

- [x] **Step 1:** Add the static factory method to the `ArmyUnit` inner class in `scripts/game.gd`

Add this method inside the `ArmyUnit` class definition (after the variable declarations):

```gdscript
static func create_from_enemy(enemy_dict: Dictionary) -> ArmyUnit:
	"""Create an ArmyUnit from enemy dictionary data."""
	var army_unit := ArmyUnit.new()
	army_unit.unit_scene = enemy_dict.get("unit_scene")
	army_unit.unit_type = enemy_dict.get("unit_type", "")
	army_unit.upgrades = enemy_dict.get("upgrades", {}).duplicate()
	army_unit.placed = false
	return army_unit
```

**Verify:**

- Ask user to verify the method compiles without errors
- Check that `Game.ArmyUnit.create_from_enemy()` can be called statically

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 2: Create UnitSlot script

**Files:** `scripts/unit_slot.gd`

- [x] **Step 1:** Create the UnitSlot script file with class definition and signals

Create `scripts/unit_slot.gd`:

```gdscript
extends Control
class_name UnitSlot

# Signals
signal unit_slot_hovered()
signal unit_slot_clicked()

# Node references (assign in inspector)
@export var animated_sprite: AnimatedSprite2D
@export var selection_node: Control  # Generic Control for selection visuals
@export var mouse_capture: Control   # Transparent overlay for mouse events

# Configuration
@export var enable_drag_drop: bool = false  # Enable drag-and-drop support

# State
var is_selected: bool = false
var slot_index: int = -1  # Set by parent when populating
var current_army_unit: Game.ArmyUnit = null
```

- [x] **Step 2:** Add `_ready()` method to initialize selection state

Add after the state variables:

```gdscript
func _ready() -> void:
	# Ensure selection node is hidden initially
	if selection_node:
		selection_node.visible = false

	# Set up mouse capture to fill the entire slot
	if mouse_capture:
		mouse_capture.mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_capture.modulate.a = 0.0  # Transparent but captures events
		# Connect mouse signals
		if not mouse_capture.mouse_entered.is_connected(_on_mouse_entered):
			mouse_capture.mouse_entered.connect(_on_mouse_entered)
		if not mouse_capture.mouse_exited.is_connected(_on_mouse_exited):
			mouse_capture.mouse_exited.connect(_on_mouse_exited)
```

- [x] **Step 3:** Add `set_unit()` method to extract SpriteFrames and display unit

Add after `_ready()`:

```gdscript
func set_unit(army_unit: Game.ArmyUnit) -> void:
	"""Set the unit to display from an ArmyUnit."""
	current_army_unit = army_unit

	if not army_unit or not army_unit.unit_scene:
		# Clear the slot
		if animated_sprite:
			animated_sprite.sprite_frames = null
		return

	# Extract SpriteFrames from the unit scene
	var sprite_frames: SpriteFrames = _extract_sprite_frames(army_unit.unit_scene)
	if sprite_frames and animated_sprite:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle")
```

- [x] **Step 4:** Add helper method `_extract_sprite_frames()`

Add after `set_unit()`:

```gdscript
func _extract_sprite_frames(unit_scene: PackedScene) -> SpriteFrames:
	"""Extract SpriteFrames resource from a unit scene."""
	if not unit_scene:
		return null

	var instance := unit_scene.instantiate()
	var sprite_frames: SpriteFrames = null

	# Look for AnimatedSprite2D
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")

	if sprite:
		sprite_frames = sprite.sprite_frames

	instance.queue_free()
	return sprite_frames
```

- [x] **Step 5:** Add `set_selected()` method and update `is_selected` property

Add after `_extract_sprite_frames()`:

```gdscript
func set_selected(selected: bool) -> void:
	"""Show or hide the selection indicator."""
	is_selected = selected
	if selection_node:
		selection_node.visible = selected
```

- [x] **Step 6:** Add mouse event handlers for hover and click

Add after `set_selected()`:

```gdscript
func _on_mouse_entered() -> void:
	"""Handle mouse enter - emit hover signal."""
	unit_slot_hovered.emit()


func _on_mouse_exited() -> void:
	"""Handle mouse exit - no signal needed, but method exists for consistency."""
	pass


func _gui_input(event: InputEvent) -> void:
	"""Handle mouse click events."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			unit_slot_clicked.emit()
			accept_event()
```

- [x] **Step 7:** Add `_get_drag_data()` method for drag-and-drop support

Add after `_gui_input()`:

```gdscript
func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Handle drag-and-drop when enabled."""
	if not enable_drag_drop:
		return null

	if not current_army_unit or slot_index < 0:
		return null

	# Find HUD by traversing up the tree (for phase check)
	var hud: HUD = null
	var current := get_parent()
	while current:
		if current is HUD:
			hud = current as HUD
			break
		current = current.get_parent()

	if not hud:
		return null

	# Check if we're in preparation phase
	if hud.current_phase != "preparation":
		return null

	# Create drag preview using current sprite frame or extract texture
	var preview_texture: Texture2D = null
	if animated_sprite and animated_sprite.sprite_frames:
		var anim_name := "idle" if animated_sprite.sprite_frames.has_animation("idle") else "default"
		if animated_sprite.sprite_frames.has_animation(anim_name):
			preview_texture = animated_sprite.sprite_frames.get_frame_texture(anim_name, 0)

	# Wrap preview in a container so we can offset it to center on cursor
	var preview_container := Control.new()
	preview_container.custom_minimum_size = Vector2(32, 32)

	var preview: Control
	if preview_texture:
		# Use TextureRect to show the sprite
		var texture_preview := TextureRect.new()
		texture_preview.texture = preview_texture
		texture_preview.custom_minimum_size = Vector2(32, 32)
		texture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview = texture_preview
	else:
		# Fallback to colored rectangle if no texture
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview

	# Offset preview so it's centered on cursor
	preview.position = Vector2(-16, -16)
	preview_container.add_child(preview)
	set_drag_preview(preview_container)

	return {
		"army_unit": current_army_unit,
		"army_index": slot_index
	}
```

**Verify:**

- Ask user to verify the script compiles without errors
- Check that all methods are properly defined

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 3: Create UnitSlot scene structure

**Files:** `scenes/ui/unit_slot.tscn`

- [x] **Step 1:** **Godot Editor:** Create new scene file `scenes/ui/unit_slot.tscn`

1. In Godot editor, create a new scene
2. Add a `Control` node as the root
3. Rename it to `UnitSlot`
4. Save as `scenes/ui/unit_slot.tscn`

- [x] **Step 2:** **Godot Editor:** Link the UnitSlot script to the root node

1. Select the UnitSlot root node
2. In the Inspector, click the script icon next to the node name
3. Select `scripts/unit_slot.gd` from the file dialog
4. Verify the script is linked

- [x] **Step 3:** **Godot Editor:** Add AnimatedSprite2D child node

1. Right-click UnitSlot node → Add Child Node
2. Select `AnimatedSprite2D`
3. Name it `AnimatedSprite2D`
4. In Inspector, set anchors to fill parent (anchors_preset = 15)
5. Set mouse_filter to Ignore (so it doesn't block mouse events)

- [x] **Step 4:** **Godot Editor:** Add SelectionNode Control child

1. Right-click UnitSlot node → Add Child Node
2. Select `Control`
3. Name it `SelectionNode`
4. In Inspector, set anchors to fill parent (anchors_preset = 15)
5. Set mouse_filter to Ignore
6. Add a child ColorRect to SelectionNode for visual selection indicator:
   - Right-click SelectionNode → Add Child Node → ColorRect
   - Name it `SelectionHighlight`
   - Set anchors to fill parent
   - Set color to something visible (e.g., yellow with alpha 0.3)
   - Set mouse_filter to Ignore

- [x] **Step 5:** **Godot Editor:** Add MouseCapture Control child

1. Right-click UnitSlot node → Add Child Node
2. Select `Control`
3. Name it `MouseCapture`
4. In Inspector, set anchors to fill parent (anchors_preset = 15)
5. Set mouse_filter to Stop (so it captures events)
6. Set modulate alpha to 0.0 (transparent but captures events)

- [x] **Step 6:** **Godot Editor:** Link node references in UnitSlot script

1. Select UnitSlot root node
2. In Inspector, find the exported variables:
   - `animated_sprite` → drag AnimatedSprite2D node to this field
   - `selection_node` → drag SelectionNode node to this field
   - `mouse_capture` → drag MouseCapture node to this field

- [x] **Step 7:** **Godot Editor:** Set custom minimum size

1. Select UnitSlot root node
2. In Inspector, set `custom_minimum_size` to `Vector2(32, 32)` (or desired size)

**Verify:**

- Ask user to verify the scene structure:
  - UnitSlot (Control) root with script linked
  - AnimatedSprite2D child
  - SelectionNode (Control) child with SelectionHighlight (ColorRect) child
  - MouseCapture (Control) child
  - All node references linked in inspector
- Verify the scene can be instantiated without errors

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 4: Update HUD to use UnitSlot for tray slots

**Files:** `scripts/hud.gd`, `scenes/ui/hud.tscn`

- [x] **Step 1:** Update `_ready()` in `scripts/hud.gd` to work with UnitSlot

Find the section that gets tray slots (around line 56-61) and update it to check for UnitSlot instead:

```gdscript
# Get all tray slot Controls and set them up
if unit_tray:
	for child in unit_tray.get_children():
		if child is UnitSlot:
			tray_slots.append(child)
			var slot := child as UnitSlot
			slot.slot_index = tray_slots.size() - 1
			slot.enable_drag_drop = true  # Enable drag for tray slots
```

- [x] **Step 2:** Update `set_tray_from_army()` in `scripts/hud.gd` to use UnitSlot.set_unit()

Replace the method implementation (around lines 133-164):

```gdscript
func set_tray_from_army(army_units: Array) -> void:
	"""Populate the tray from army slot data."""
	placed_unit_count = 0

	if not unit_tray:
		return

	for i in range(tray_slots.size()):
		var slot = tray_slots[i]
		if not slot:
			continue

		if i < army_units.size():
			var army_unit = army_units[i]
			if army_unit.placed:
				# Slot already used, clear it
				if slot is UnitSlot:
					var unit_slot := slot as UnitSlot
					unit_slot.set_unit(null)
				else:
					# Fallback for old slots
					slot.set_meta("unit_type", "")
					slot.set_meta("slot_index", i)
					if slot.has_method("set_unit_texture"):
						slot.set_unit_texture(null)
			else:
				# Slot available, populate it
				if slot is UnitSlot:
					var unit_slot := slot as UnitSlot
					unit_slot.slot_index = i
					unit_slot.set_unit(army_unit)
				else:
					# Fallback for old slots
					slot.set_meta("unit_type", army_unit.unit_type)
					slot.set_meta("slot_index", i)
					var texture: Texture2D = _get_texture_from_scene(army_unit.unit_scene)
					if slot.has_method("set_unit_texture"):
						slot.set_unit_texture(texture)
		else:
			# Empty slot
			if slot is UnitSlot:
				var unit_slot := slot as UnitSlot
				unit_slot.set_unit(null)
			else:
				# Fallback for old slots
				slot.set_meta("unit_type", "")
				if slot.has_method("set_unit_texture"):
					slot.set_unit_texture(null)
```

- [x] **Step 3:** Update `clear_tray_slot()` in `scripts/hud.gd` to work with UnitSlot

Replace the method (around lines 324-332):

```gdscript
func clear_tray_slot(index: int) -> void:
	"""Clear a tray slot after its unit has been placed."""
	if index < 0 or index >= tray_slots.size():
		return

	var slot := tray_slots[index]
	if slot is UnitSlot:
		var unit_slot := slot as UnitSlot
		unit_slot.set_unit(null)
	else:
		# Fallback for old slots
		slot.set_meta("unit_type", "")
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(null)
```

- [x] **Step 4:** Update `update_placed_count()` in `scripts/hud.gd` to work with UnitSlot

The method should still work, but verify it handles UnitSlot properly. The modulate and mouse_filter changes should work on UnitSlot since it extends Control.

- [x] **Step 5:** **Godot Editor:** Replace tray slot instances in `scenes/ui/hud.tscn` with UnitSlot

1. Open `scenes/ui/hud.tscn` in Godot editor
2. Find the UnitTray GridContainer
3. For each existing UnitSlot instance (UnitSlot, UnitSlot2, etc.):
   - Delete the old instance
   - Right-click UnitTray → Instance Child Scene
   - Select `scenes/ui/unit_slot.tscn`
   - Name it appropriately (UnitSlot, UnitSlot2, etc.)
4. Repeat for all tray slots (there should be 6 based on the scene structure)

**Verify:**

- Ask user to:
  - Run the game
  - Verify tray slots display units with animated sprites (idle animation playing)
  - Verify drag-and-drop still works from tray to spawn slots
  - Verify units can be placed correctly

**After this task:** STOP and ask user to verify manually before continuing.

---

### ✅ Task 5: Update SpawnSlot to work with UnitSlot drag data

**Files:** `scripts/spawn_slot.gd`

- [x] **Step 1:** Update `_can_drop_data()` to accept UnitSlot drag data

The current method checks for `data.has("army_index")`. UnitSlot returns both `army_unit` and `army_index`, so this should still work. Verify the method handles the new structure:

```gdscript
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var game := get_tree().get_first_node_in_group("game") as Game
	if game and game.phase != "preparation":
		return false

	if not data is Dictionary:
		return false
	# Accept either army_index (old) or army_unit (new UnitSlot)
	if not data.has("army_index") and not data.has("army_unit"):
		return false
	if is_occupied:
		return false
	return true
```

- [x] **Step 2:** Update `_drop_data()` to extract army_index from UnitSlot data

Update the method to handle both old format (just army_index) and new format (army_unit + army_index):

```gdscript
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return

	var army_index: int = -1

	# Handle new UnitSlot format (has army_unit and army_index)
	if data.has("army_index"):
		army_index = data.get("army_index", -1)
	# Fallback: if only army_unit provided, we'd need to look it up
	# But UnitSlot always provides army_index, so this shouldn't be needed

	if army_index >= 0:
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			game.place_unit_from_army(army_index, self)
```

**Verify:**

- Ask user to:
  - Run the game
  - Drag a unit from tray to a spawn slot
  - Verify the unit is placed correctly
  - Verify no errors in console

**After this task:** STOP and ask user to verify manually before continuing.

---

## Exit Criteria

- [ ] UnitSlot component can display units with animated sprites (idle animation)
- [ ] UnitSlot can be selected (selection indicator shows/hides)
- [ ] UnitSlot emits hover and click signals
- [ ] UnitSlot supports drag-and-drop when enabled
- [ ] Tray slots use UnitSlot and display units correctly
- [ ] Drag-and-drop from tray to spawn slots works
- [ ] ArmyUnit.create_from_enemy() can convert enemy dictionaries
- [ ] No errors in console when using UnitSlot
- [ ] UnitSlot can be used in other contexts (upgrade screen, battle select) in future
