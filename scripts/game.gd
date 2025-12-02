extends Control
class_name Game

# Signals
signal unit_placed(unit_type: String)

# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"

# Level management
var level_paths: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
]
var current_level_index := 0

# Current level references (set when level loads)
var current_level: LevelRoot = null

# Scene references
@export var swordsman_scene: PackedScene
@export var archer_scene: PackedScene
@export var enemy_scene: PackedScene

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
	unit_placed.connect(_on_unit_placed)
	load_level(current_level_index)


func _process(_delta: float) -> void:
	if phase != "battle":
		return

	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)

	if enemy_count == 0:
		_end_battle(true)  # Player wins
	elif player_count == 0:
		_end_battle(false)  # Player loses


# func _setup_ui() -> void:  # Removed - HUD handles its own setup
# 	# Connect button signals (with null checks)
# 	if swordsman_button:
# 		swordsman_button.pressed.connect(_on_swordsman_button_pressed)
# 		swordsman_button.text = "Add Swordsman"
# 	if archer_button:
# 		archer_button.pressed.connect(_on_archer_button_pressed)
# 		archer_button.text = "Add Archer"
# 	if start_button:
# 		start_button.pressed.connect(_on_start_button_pressed)
# 		start_button.text = "Fight!"
# 		start_button.disabled = true  # Disable initially (no units yet)
# 	if restart_button:
# 		restart_button.pressed.connect(_on_restart_button_pressed)
# 		restart_button.text = "Restart"
# 		restart_button.visible = false  # Hide initially




# func _spawn_enemies() -> void:  # Temporarily commented out - enemies spawn from level scenes in Task 4
# 	# Check if unit_scene is assigned
# 	if enemy_scene == null:
# 		push_error("enemy_scene is not assigned in Game!")
# 		return
#
# 	# Get enemy spawn positions from Marker2D nodes
# 	var enemy_positions := _get_enemy_spawn_positions()
# 	if enemy_positions.is_empty():
# 		push_warning("No enemy spawn positions found! Add Marker2D nodes to EnemySpawnSlots.")
# 		return
#
# 	# Spawn an enemy at each position
# 	for pos in enemy_positions:
# 		var enemy: Unit = enemy_scene.instantiate() as Unit
# 		if enemy == null:
# 			push_error("Failed to instantiate enemy unit!")
# 			continue
#
# 		# Add to enemy units container first (needed for coordinate conversion)
# 		enemy_units.add_child(enemy)
#
# 		# Configure as enemy unit
# 		enemy.is_enemy = true
# 		enemy.enemy_container = player_units  # Enemies target player units
# 		# Convert global spawn position to local position relative to enemy_units
# 		enemy.global_position = pos


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

	# Show upgrade modal
	hud.show_upgrade_modal(victory, current_level_index + 1)


# func _validate_ui_references() -> void:  # Removed - HUD handles its own setup
# 	# Warn if UI references are not assigned
# 	if swordsman_button == null:
# 		push_warning("swordsman_button is not assigned! Assign it in the inspector.")
# 	if archer_button == null:
# 		push_warning("archer_button is not assigned! Assign it in the inspector.")
# 	if start_button == null:
# 		push_warning("start_button is not assigned! Assign it in the inspector.")
# 	if restart_button == null:
# 		push_warning("restart_button is not assigned! Assign it in the inspector.")


# func _validate_spawn_slots() -> void:  # Stubbed - spawn slots come from level scenes
# 	# Check if spawn slot containers exist
# 	if player_spawn_slots == null:
# 		push_error("PlayerSpawnSlots node not found! Add a Node2D named 'PlayerSpawnSlots' with Marker2D children.")
# 	if enemy_spawn_slots == null:
# 		push_error("EnemySpawnSlots node not found! Add a Node2D named 'EnemySpawnSlots' with Marker2D children.")
# 	
# 	# Warn if no spawn slots found
# 	if player_spawn_slots != null and player_spawn_slots.get_child_count() == 0:
# 		push_warning("No player spawn slots found! Add Marker2D nodes as children of PlayerSpawnSlots.")
# 	if enemy_spawn_slots != null and enemy_spawn_slots.get_child_count() == 0:
# 		push_warning("No enemy spawn slots found! Add Marker2D nodes as children of EnemySpawnSlots.")


# func _get_player_spawn_positions() -> Array[Vector2]:  # Stubbed - spawn slots come from level scenes
# 	var positions: Array[Vector2] = []
# 	if player_spawn_slots == null:
# 		return positions
# 	
# 	for child in player_spawn_slots.get_children():
# 		if child is Marker2D:
# 			positions.append(child.global_position)
# 	
# 	return positions


# func _get_enemy_spawn_positions() -> Array[Vector2]:  # Stubbed - spawn slots come from level scenes
# 	var positions: Array[Vector2] = []
# 	if enemy_spawn_slots == null:
# 		return positions
# 	
# 	for child in enemy_spawn_slots.get_children():
# 		if child is Marker2D:
# 			positions.append(child.global_position)
# 	
# 	return positions


# func _get_next_available_slot() -> Vector2:  # Stubbed - spawn slots come from level scenes
# 	# Get all currently occupied positions (in global coordinates)
# 	var occupied_positions := []
# 	for child in player_units.get_children():
# 		if child is Unit:
# 			occupied_positions.append(child.global_position)
# 	
# 	# Get spawn slot positions (in global coordinates)
# 	var spawn_positions := _get_player_spawn_positions()
# 	
# 	# Find the first slot that isn't occupied
# 	for slot_pos in spawn_positions:
# 		# Check if this position is occupied (with small tolerance for floating point)
# 		var is_occupied := false
# 		for occupied_pos in occupied_positions:
# 			if slot_pos.distance_to(occupied_pos) < 1.0:
# 				is_occupied = true
# 				break
# 		
# 		if not is_occupied:
# 			# Return global position - will be converted when setting unit position
# 			return slot_pos
# 	
# 	# All slots are occupied
# 	return Vector2.ZERO

func load_level(index: int) -> void:
	# Clear all units
	_clear_all_units()
	
	# Remove old level if exists
	if current_level:
		current_level.queue_free()
		current_level = null

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Load the level scene
	if index < 0 or index >= level_paths.size():
		push_error("Invalid level index: %d" % index)
		return
	
	var level_scene := load(level_paths[index]) as PackedScene
	if level_scene == null:
		push_error("Failed to load level: %s" % level_paths[index])
		return
	
	current_level = level_scene.instantiate() as LevelRoot
	if current_level == null:
		push_error("Level root is not a LevelRoot: %s" % level_paths[index])
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
	
	# Populate tray with starting unit scenes
	if starting_unit_scenes.size() > 0:
		hud.set_tray_unit_scenes(starting_unit_scenes)


func _spawn_enemies_from_level() -> void:
	if current_level == null:
		push_warning("current_level is null in _spawn_enemies_from_level")
		return
	
	if enemy_scene == null:
		push_warning("enemy_scene is not assigned in Game!")
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		push_warning("No EnemyMarkers node in level")
		return

	var marker_count := 0
	for marker in enemy_markers.get_children():
		if marker is Marker2D:
			marker_count += 1
			var enemy: Unit = enemy_scene.instantiate() as Unit
			if enemy == null:
				push_error("Failed to instantiate enemy unit!")
				continue
			
			enemy_units.add_child(enemy)
			enemy.is_enemy = true
			enemy.enemy_container = player_units
			enemy.global_position = marker.global_position
			print("Spawned enemy at global position: ", marker.global_position)
	
	print("Spawned %d enemies from %d markers" % [marker_count, enemy_markers.get_child_count()])


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


func place_unit_on_slot(unit_type: String, slot: SpawnSlot) -> void:
	if slot.is_occupied:
		return

	var unit_scene: PackedScene
	match unit_type:
		"swordsman":
			unit_scene = swordsman_scene
		"archer":
			unit_scene = archer_scene
		_:
			push_error("Unknown unit type: " + unit_type)
			return

	var unit: Unit = unit_scene.instantiate() as Unit
	player_units.add_child(unit)
	unit.is_enemy = false
	unit.enemy_container = enemy_units
	unit.global_position = slot.get_slot_center()

	slot.set_occupied(true)
	
	# Notify HUD that a unit was placed
	unit_placed.emit(unit_type)


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


func _on_upgrade_confirmed(victory: bool) -> void:
	if victory:
		# Advance to next level (clamp to last)
		current_level_index = mini(current_level_index + 1, level_paths.size() - 1)
	# else: reload same level (current_level_index unchanged)

	load_level(current_level_index)
