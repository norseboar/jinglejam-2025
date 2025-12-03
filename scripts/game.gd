extends Control
class_name Game

# Signals
signal unit_placed(unit_type: String)
signal army_unit_placed(slot_index: int)

# Army tracking
class ArmyUnit:
	var unit_type: String = ""
	var unit_scene: PackedScene = null
	var placed: bool = false
	var upgrades: Dictionary = {}  # NEW

# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"
var army: Array = []  # Array of ArmyUnit

# Level management
@export var level_scenes: Array[PackedScene] = []
var current_level_index := 0

# Upgrade screen
@export var upgrade_background: Texture2D
var enemies_faced: Array = []  # Captured at end of battle for upgrade screen

# Current level references (set when level loads)
var current_level: LevelRoot = null

# Scene references
# (Removed unused swordsman_scene and archer_scene - units come from starting_unit_scenes and EnemyMarker.unit_scene)

# Starting units for the tray (can have duplicates)
@export var starting_unit_scenes: Array[PackedScene] = []

# Node references (assign in inspector)
@export var background_rect: TextureRect
@export var gameplay: Node2D
@export var player_units: Node2D
@export var enemy_units: Node2D

# UI references (assign in inspector)
@export var hud: HUD
@export var ui_layer: CanvasLayer  # Where levels get loaded (same layer as HUD for drag-drop)


func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)
	load_level(current_level_index)


func _init_army() -> void:
	army.clear()
	for scene in starting_unit_scenes:
		var slot := ArmyUnit.new()
		slot.unit_scene = scene
		slot.unit_type = scene.resource_path.get_file().get_basename()
		slot.placed = false
		army.append(slot)


func _process(_delta: float) -> void:
	if phase != "battle":
		return

	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)

	if enemy_count == 0:
		_end_battle(true)  # Player wins
	elif player_count == 0:
		_end_battle(false)  # Player loses


func _clear_all_units() -> void:
	# Remove all player units
	for child in player_units.get_children():
		child.queue_free()

	# Remove all enemy units
	for child in enemy_units.get_children():
		child.queue_free()


func _end_battle(victory: bool) -> void:
	phase = "upgrade"

	# Stop all units
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("idle")
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("idle")

	# Capture enemy data for upgrade screen (only if victory and not last level, defeat will restart)
	if victory and current_level_index < level_scenes.size() - 1:
		_capture_enemies_faced()
	
	# Show battle end modal (which leads to upgrade screen on victory, or restart on defeat/last level)
	hud.show_battle_end_modal(victory, current_level_index + 1, level_scenes.size())


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
		push_error("Level root is not a LevelRoot at index %d" % index)
		return
	
	# Add level to UI layer BEFORE HUD (so it renders behind)
	# HUD should be the last child to render on top
	if ui_layer:
		ui_layer.add_child(current_level)
		ui_layer.move_child(current_level, 0)  # Move to first position (behind HUD)
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
	hud.set_phase(phase, index + 1)
	
	# Populate tray from army data
	if army.size() > 0:
		hud.set_tray_from_army(army)


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


func _set_spawn_slots_visible(should_show: bool) -> void:
	# Spawn slots are now part of the level scene
	if current_level:
		var spawn_slots_container := current_level.get_node_or_null("PlayerSpawnSlots")
		if spawn_slots_container:
			spawn_slots_container.visible = should_show


func _reset_spawn_slots() -> void:
	for slot in get_tree().get_nodes_in_group("spawn_slots"):
		if slot is SpawnSlot:
			slot.set_occupied(false)
			slot.set_highlighted(false)


func _on_unit_placed(_unit_type: String) -> void:
	# Update HUD to reflect placed unit count
	if hud:
		hud.update_placed_count(player_units.get_child_count())


func _on_army_unit_placed(slot_index: int) -> void:
	if hud:
		hud.clear_tray_slot(slot_index)


func place_unit_from_army(army_index: int, slot: SpawnSlot) -> void:
	"""Place a unit from the army array onto a spawn slot."""
	if slot.is_occupied:
		return
	
	if army_index < 0 or army_index >= army.size():
		push_error("Invalid army index: %d (army size: %d)" % [army_index, army.size()])
		return
	
	var army_unit: ArmyUnit = army[army_index]
	if army_unit.placed:
		push_warning("Army unit at index %d already placed" % army_index)
		return
	
	if army_unit.unit_scene == null:
		push_error("Army unit at index %d has no unit_scene" % army_index)
		return
	
	var unit: Unit = army_unit.unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit from scene at army index %d" % army_index)
		return
	
	player_units.add_child(unit)
	unit.is_enemy = false
	unit.enemy_container = enemy_units
	unit.global_position = slot.get_slot_center()
	unit.upgrades = army_unit.upgrades.duplicate()  # Copy upgrades
	unit.apply_upgrades()  # Apply after positioning

	slot.set_occupied(true)
	
	# Mark army slot as placed
	army_unit.placed = true
	army_unit_placed.emit(army_index)
	
	# Notify HUD that a unit was placed
	unit_placed.emit(army_unit.unit_type)


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


func _count_living_units(container: Node2D) -> int:
	var count := 0
	for child in container.get_children():
		if child is Unit:
			var unit := child as Unit
			# Count units that are not dead or dying
			if unit.current_hp > 0 and unit.state != "dying":
				count += 1
	return count


func _on_start_battle_requested() -> void:
	if phase != "preparation":
		return

	if player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return

	phase = "battle"
	hud.set_phase(phase, current_level_index + 1)
	_set_spawn_slots_visible(false)

	# Set all units to moving
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("moving")
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("moving")


func _on_show_upgrade_screen_requested() -> void:
	"""Handle request to show upgrade screen (after battle end modal button clicked on victory)."""
	# Swap to upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Show upgrade screen with army and enemy data
	hud.show_upgrade_screen(true, army, enemies_faced)  # Only called on victory


func _on_upgrade_confirmed(victory: bool) -> void:
	# Hide upgrade screen
	hud.hide_upgrade_screen()
	
	if victory:
		# Advance to next level if not already at the last level
		if current_level_index < level_scenes.size() - 1:
			current_level_index += 1
		else:
			# Completed all levels - restart at level 1
			current_level_index = 0
			army.clear()  # Reset army for new run
	else:
		# On defeat, reset everything
		army.clear()  # Clear army so it reinitializes
		current_level_index = 0

	load_level(current_level_index)
