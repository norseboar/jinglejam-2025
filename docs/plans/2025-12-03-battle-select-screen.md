# ✅ Battle Select Screen Plan

**Goal:** Add a battle selection screen where players choose between two randomly-picked battle options before each level (except level 1).

---

## Status

- [x] Task 1: Add army_name to LevelRoot
- [x] Task 2: Convert level_scenes to level_pools in Game.gd
- [x] Task 3: Create BattleOption scene and script
- [x] Task 4: Create BattleSelectScreen scene and script
- [x] Task 5: Integrate battle select into game flow
- [x] Task 6: Build UI in Godot editor and wire up exports

---

## Summary

**Task 1:** Add `@export var army_name: String` to `LevelRoot` so each level defines its army name.
**Task 2:** Change `level_scenes: Array[PackedScene]` to `level_pools: Array[Array]` and add a `load_level_scene()` method that takes a specific scene.
**Task 3:** Create `BattleOption` component that displays army name and enemy grid, with selection state.
**Task 4:** Create `BattleSelectScreen` that holds battle options in a container, handles selection, and emits advance signal.
**Task 5:** Update Game.gd and HUD.gd to show battle select screen after upgrade screen continue.
**Task 6:** Build the UI scenes in Godot editor and connect all the exports.

---

## Tasks

### ✅ Task 1: Add army_name to LevelRoot

**Files:** `scripts/level_root.gd`

- [x] **Step 1:** Add the army_name export after the existing exports:

```gdscript
extends Control
class_name LevelRoot

## The background texture for this level (applied to Game's BackgroundRect at runtime)
@export var background_texture: Texture2D

## Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

## The name of the enemy army for this level (shown in battle select screen)
@export var army_name: String = "Enemy Army"
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### ✅ Task 2: Convert level_scenes to level_pools in Game.gd

**Files:** `scripts/game.gd`

- [x] **Step 1:** Replace the `level_scenes` export with `level_pools`. Change line 25:

```gdscript
# OLD:
@export var level_scenes: Array[PackedScene] = []

# NEW:
## Array of level pools. level_pools[0] = [level_01.tscn], level_pools[1] = [level_02a.tscn, level_02b.tscn], etc.
@export var level_pools: Array[Array] = []
```

- [x] **Step 2:** Add a new variable to track the selected level scene (after `current_level_index`):

```gdscript
var current_level_index := 0
var selected_level_scene: PackedScene = null  # The specific scene chosen from the pool
```

- [x] **Step 3:** Add a helper method to get pool size. Add after `_capture_enemies_faced()`:

```gdscript
func get_current_pool_size() -> int:
	"""Get the number of level options in the current level's pool."""
	if current_level_index < 0 or current_level_index >= level_pools.size():
		return 0
	var pool = level_pools[current_level_index]
	if pool is Array:
		return pool.size()
	return 0
```

- [x] **Step 4:** Add a method to load a specific level scene (not by index). Add after `load_level()`:

```gdscript
func load_level_scene(level_scene: PackedScene) -> void:
	"""Load a specific level scene (used when player picks from battle select)."""
	if level_scene == null:
		push_error("level_scene is null!")
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

	# Clear all units
	_clear_all_units()

	# Remove old level if exists
	if current_level:
		current_level.queue_free()
		current_level = null

	# Wait a frame for cleanup
	await get_tree().process_frame

	current_level = level_scene.instantiate() as LevelRoot
	if current_level == null:
		push_error("Level scene is not a LevelRoot!")
		return

	# Add level to UI layer BEFORE HUD (so it renders behind)
	if ui_layer:
		ui_layer.add_child(current_level)
		ui_layer.move_child(current_level, 0)
	else:
		push_error("ui_layer not assigned!")
		return

	# Hide editor background (only for editing)
	current_level.hide_editor_background()

	# Set the game's background from level
	if background_rect and current_level.background_texture:
		background_rect.texture = current_level.background_texture

	# Reset all spawn slots to unoccupied
	_reset_spawn_slots()

	# Spawn enemies from level markers
	_spawn_enemies_from_level()

	# Update HUD
	phase = "preparation"
	hud.set_phase(phase, current_level_index + 1)

	# Populate tray from army data
	if army.size() > 0:
		hud.set_tray_from_army(army)
```

- [x] **Step 5:** Update `load_level()` to use pools. Replace the existing function:

```gdscript
func load_level(index: int) -> void:
	"""Load a level by index, picking the first scene from that level's pool."""
	# Validate index first
	if index < 0 or index >= level_pools.size():
		push_error("Invalid level index: %d (pool count: %d)" % [index, level_pools.size()])
		return

	var pool = level_pools[index]
	if not pool is Array or pool.size() == 0:
		push_error("Level pool at index %d is empty or invalid!" % index)
		return

	var level_scene: PackedScene = pool[0]
	if level_scene == null:
		push_error("First scene in level pool %d is null!" % index)
		return

	# Use the new load method
	await load_level_scene(level_scene)
```

- [x] **Step 6:** Update `_end_battle()` to use `level_pools.size()` instead of `level_scenes.size()`. Find and replace:

```gdscript
# In _end_battle(), change:
if victory and current_level_index < level_scenes.size() - 1:
# To:
if victory and current_level_index < level_pools.size() - 1:

# And change:
hud.show_battle_end_modal(victory, current_level_index + 1, level_scenes.size())
# To:
hud.show_battle_end_modal(victory, current_level_index + 1, level_pools.size())
```

- [x] **Step 7:** Update `_on_upgrade_confirmed()` to use `level_pools.size()`. Find and replace:

```gdscript
# Change:
if current_level_index < level_scenes.size() - 1:
# To:
if current_level_index < level_pools.size() - 1:
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### ✅ Task 3: Create BattleOption scene and script

**Files:** `scripts/battle_option.gd`

- [x] **Step 1:** Create `scripts/battle_option.gd`:

```gdscript
extends Control
class_name BattleOption

signal selected(option_index: int)

# Node references (assign in inspector)
@export var army_name_label: Label
@export var enemy_grid: GridContainer
@export var selection_highlight: Control  # A panel/border shown when selected

# State
var option_index: int = 0
var level_scene: PackedScene = null
var is_selected: bool = false


func _ready() -> void:
	# Ensure highlight is hidden by default
	if selection_highlight:
		selection_highlight.visible = false

	# Connect click detection
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected.emit(option_index)


func setup(index: int, scene: PackedScene) -> void:
	"""Initialize this option with a level scene."""
	option_index = index
	level_scene = scene

	if scene == null:
		return

	# Instantiate temporarily to read data
	var level_instance := scene.instantiate() as LevelRoot
	if level_instance == null:
		return

	# Set army name
	if army_name_label:
		army_name_label.text = level_instance.army_name

	# Populate enemy grid
	_populate_enemy_grid(level_instance)

	# Clean up
	level_instance.queue_free()


func _populate_enemy_grid(level_instance: LevelRoot) -> void:
	"""Populate the grid with enemy unit sprites from the level."""
	if enemy_grid == null:
		return

	var enemy_markers := level_instance.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return

	# Get all slots in the grid
	var slots: Array[Control] = []
	for child in enemy_grid.get_children():
		if child is Control:
			slots.append(child)

	# Populate slots with enemy textures
	var slot_index := 0
	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue
		if slot_index >= slots.size():
			break

		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue

		var slot := slots[slot_index]
		var texture := _get_texture_from_scene(enemy_marker.unit_scene)
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(texture)

		slot_index += 1

	# Clear remaining slots
	for i in range(slot_index, slots.size()):
		var slot := slots[i]
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(null)


func _get_texture_from_scene(scene: PackedScene) -> Texture2D:
	"""Extract the first frame texture from a unit scene's AnimatedSprite2D."""
	var instance := scene.instantiate()
	var texture: Texture2D = null

	# Look for AnimatedSprite2D
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")

	if sprite and sprite.sprite_frames:
		var anim_name := "idle" if sprite.sprite_frames.has_animation("idle") else "default"
		if sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			texture = sprite.sprite_frames.get_frame_texture(anim_name, 0)

	instance.queue_free()
	return texture


func set_selected(value: bool) -> void:
	"""Show or hide the selection highlight."""
	is_selected = value
	if selection_highlight:
		selection_highlight.visible = value
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### ✅ Task 4: Create BattleSelectScreen scene and script

**Files:** `scripts/battle_select_screen.gd`

- [x] **Step 1:** Create `scripts/battle_select_screen.gd`:

```gdscript
extends Control
class_name BattleSelectScreen

signal advance_pressed(level_scene: PackedScene)

# Node references (assign in inspector)
@export var options_container: Container  # HBoxContainer or similar
@export var advance_button: Button
@export var title_label: Label

# Scene to instantiate for each option
@export var battle_option_scene: PackedScene

# Editor-only background (hidden at runtime)
@export var editor_background: CanvasItem

# State
var options: Array[BattleOption] = []
var selected_index: int = 0
var level_scenes: Array[PackedScene] = []


func _ready() -> void:
	# Connect advance button
	if advance_button:
		advance_button.pressed.connect(_on_advance_button_pressed)

	# Hide editor background at runtime
	if editor_background:
		editor_background.visible = false

	# Start hidden
	visible = false


func show_battle_select(scenes: Array[PackedScene]) -> void:
	"""Show the battle select screen with the given level scene options."""
	level_scenes = scenes
	selected_index = 0

	# Clear existing options
	_clear_options()

	# Create option for each scene
	for i in range(scenes.size()):
		var scene := scenes[i]
		_add_option(i, scene)

	# Pre-select first option
	if options.size() > 0:
		options[0].set_selected(true)

	# Show screen
	visible = true


func hide_battle_select() -> void:
	"""Hide the battle select screen."""
	visible = false
	_clear_options()


func _clear_options() -> void:
	"""Remove all option instances from the container."""
	for option in options:
		option.queue_free()
	options.clear()


func _add_option(index: int, scene: PackedScene) -> void:
	"""Add a battle option to the container."""
	if battle_option_scene == null or options_container == null:
		push_error("battle_option_scene or options_container not assigned!")
		return

	var option := battle_option_scene.instantiate() as BattleOption
	if option == null:
		push_error("Failed to instantiate BattleOption!")
		return

	options_container.add_child(option)
	option.setup(index, scene)
	option.selected.connect(_on_option_selected)
	options.append(option)


func _on_option_selected(index: int) -> void:
	"""Handle option selection."""
	# Deselect previous
	if selected_index >= 0 and selected_index < options.size():
		options[selected_index].set_selected(false)

	# Select new
	selected_index = index
	if index >= 0 and index < options.size():
		options[index].set_selected(true)


func _on_advance_button_pressed() -> void:
	"""Handle advance button press."""
	if selected_index < 0 or selected_index >= level_scenes.size():
		push_error("Invalid selected_index: %d" % selected_index)
		return

	var selected_scene := level_scenes[selected_index]
	advance_pressed.emit(selected_scene)
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### ✅ Task 5: Integrate battle select into game flow

**Files:** `scripts/game.gd`, `scripts/hud.gd`

- [x] **Step 1:** Add battle select screen reference to HUD. In `scripts/hud.gd`, add after line 22 (`@export var upgrade_screen: UpgradeScreen`):

```gdscript
@export var battle_select_screen: BattleSelectScreen
```

- [x] **Step 2:** Add signal for battle select advance in HUD. In `scripts/hud.gd`, add after line 7 (`signal show_upgrade_screen_requested`):

```gdscript
signal battle_select_advance(level_scene: PackedScene)
```

- [x] **Step 3:** Connect battle select screen signal in HUD `_ready()`. Add after line 44 (`upgrade_screen.continue_pressed.connect(_on_upgrade_screen_continue_pressed)`):

```gdscript
	# Connect battle select screen signal
	if battle_select_screen:
		battle_select_screen.advance_pressed.connect(_on_battle_select_advance_pressed)
```

- [x] **Step 4:** Add method to show battle select in HUD. Add after `hide_upgrade_screen()`:

```gdscript
func show_battle_select(scenes: Array[PackedScene]) -> void:
	"""Show the battle select screen with level options."""
	if battle_select_screen:
		battle_select_screen.show_battle_select(scenes)


func hide_battle_select() -> void:
	"""Hide the battle select screen."""
	if battle_select_screen:
		battle_select_screen.hide_battle_select()


func _on_battle_select_advance_pressed(level_scene: PackedScene) -> void:
	"""Handle advance from battle select screen."""
	hide_battle_select()
	battle_select_advance.emit(level_scene)
```

- [x] **Step 5:** Connect battle select signal in Game. In `scripts/game.gd` `_ready()`, add after line 55 (`hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)`):

```gdscript
	hud.battle_select_advance.connect(_on_battle_select_advance)
```

- [x] **Step 6:** Add helper to pick random options from pool. In `scripts/game.gd`, add after `get_current_pool_size()`:

```gdscript
func get_random_level_options(pool_index: int, count: int = 2) -> Array[PackedScene]:
	"""Pick up to 'count' distinct random scenes from the specified pool."""
	var result: Array[PackedScene] = []

	if pool_index < 0 or pool_index >= level_pools.size():
		return result

	var pool = level_pools[pool_index]
	if not pool is Array or pool.size() == 0:
		return result

	# Create a shuffled copy of indices
	var indices: Array[int] = []
	for i in range(pool.size()):
		indices.append(i)
	indices.shuffle()

	# Pick up to 'count' scenes
	var pick_count := mini(count, pool.size())
	for i in range(pick_count):
		var scene: PackedScene = pool[indices[i]]
		if scene != null:
			result.append(scene)

	return result
```

- [x] **Step 7:** Add handler for battle select advance. In `scripts/game.gd`, add after `_on_show_upgrade_screen_requested()`:

```gdscript
func _on_battle_select_advance(level_scene: PackedScene) -> void:
	"""Handle battle select advance - load the chosen level."""
	load_level_scene(level_scene)
```

- [x] **Step 8:** Modify `_on_upgrade_confirmed()` to show battle select instead of loading next level. Replace the existing function:

```gdscript
func _on_upgrade_confirmed(victory: bool) -> void:
	# Hide upgrade screen
	hud.hide_upgrade_screen()

	if victory:
		# Advance to next level if not already at the last level
		if current_level_index < level_pools.size() - 1:
			current_level_index += 1

			# Show battle select screen with options from next level's pool
			var options := get_random_level_options(current_level_index, 2)
			if options.size() > 0:
				hud.show_battle_select(options)
			else:
				# Fallback: load first scene from pool
				load_level(current_level_index)
		else:
			# Completed all levels - restart at level 1
			current_level_index = 0
			army.clear()  # Reset army for new run
			load_level(current_level_index)
	else:
		# On defeat, reset everything
		army.clear()  # Clear army so it reinitializes
		current_level_index = 0
		load_level(current_level_index)
```

**After this task:** STOP and wait for user to confirm before continuing.

---

### Task 6: Build UI in Godot editor and wire up exports

**This task is done entirely in the Godot editor.**

#### Step 1: Create BattleOption scene

1. Create new scene: `scenes/ui/battle_option.tscn`
2. Root node: `Control` (name it `BattleOption`)
3. Attach script: `scripts/battle_option.gd`
4. Set `mouse_filter` to `MOUSE_FILTER_STOP` (so clicks are detected)
5. Add children:
   - `Panel` (for background, optional)
   - `Label` (name it `ArmyNameLabel`) - for army name at top
   - `GridContainer` (name it `EnemyGrid`) - set columns to 5
   - `Panel` or `ColorRect` (name it `SelectionHighlight`) - for selection visual, set visible = false
6. Add 10 instances of `unit_tray_slot.tscn` to `EnemyGrid`
7. Wire up exports in inspector:
   - `army_name_label` → `ArmyNameLabel`
   - `enemy_grid` → `EnemyGrid`
   - `selection_highlight` → `SelectionHighlight`

#### Step 2: Create BattleSelectScreen scene structure in HUD

1. Open `scenes/ui/hud.tscn`
2. Add a new `Control` node as child of HUD, name it `BattleSelectScreen`
3. Attach script: `scripts/battle_select_screen.gd`
4. Set anchors to fill screen (Full Rect preset)
5. Set visible = false
6. Set `mouse_filter` to `MOUSE_FILTER_IGNORE`
7. Add children:
   - `Label` (name it `TitleLabel`) - text "Choose Your Battle", center at top
   - `HBoxContainer` (name it `OptionsContainer`) - center of screen, add spacing
   - `Button` (name it `AdvanceButton`) - text "Advance", center-bottom

#### Step 3: Wire up BattleSelectScreen exports

1. Select `BattleSelectScreen` node
2. In Inspector, assign:
   - `options_container` → `OptionsContainer`
   - `advance_button` → `AdvanceButton`
   - `title_label` → `TitleLabel`
   - `battle_option_scene` → `res://scenes/ui/battle_option.tscn`

#### Step 4: Wire up HUD export

1. Select `HUD` node
2. In Inspector, assign:
   - `battle_select_screen` → `BattleSelectScreen`

#### Step 5: Update Game's level_pools

1. Open `scenes/game.tscn`
2. Select the `Game` node
3. In Inspector, you'll see `level_pools` as an empty array
4. For now, set up as:
   - `level_pools[0]` = `[level_01.tscn]`
   - `level_pools[1]` = `[level_02.tscn]` (add more variants later)
   - `level_pools[2]` = `[level_03.tscn]` (add more variants later)

#### Step 6: Add army names to existing levels

1. Open each level scene (`level_01.tscn`, `level_02.tscn`, `level_03.tscn`)
2. Select the root `LevelRoot` node
3. In Inspector, set `army_name` to something appropriate (e.g., "The Training Dummies", "Shadow Legion", etc.)

**After this task:** Test the game:

- Beat level 1
- Complete upgrade screen
- Verify battle select screen appears
- Verify clicking an option selects it (highlight shows)
- Verify clicking Advance loads the selected level

---

## Exit Criteria

- [x] LevelRoot has `army_name` export that appears in battle select — Met by Task 1
- [x] Game uses `level_pools` array-of-arrays instead of flat `level_scenes` — Met by Task 2 (using LevelPool resources)
- [x] Battle select screen appears after upgrade screen (for level 2+) — Met by Task 5 integration
- [x] Two options shown (or one if pool only has one scene) — Met by `get_random_level_options()` in Task 5
- [x] First option is pre-selected — Met by `show_battle_select()` in Task 4
- [x] Clicking an option changes selection (highlight visible) — Met by `_on_option_selected()` in Task 4
- [x] Clicking Advance loads the selected level — Met by `_on_battle_select_advance()` in Task 5
- [x] Level 1 loads directly without battle select (first level of game) — Met by `load_level()` in Task 2 (loads first scene from pool[0])
