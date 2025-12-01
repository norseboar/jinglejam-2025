extends Node2D
class_name Game

# Game state
var player_hp := 10
var phase := "placement"  # "placement" | "battle" | "end"

# Scene references
@export var swordsman_scene: PackedScene
@export var archer_scene: PackedScene
@export var enemy_scene: PackedScene

# Node references
@onready var fortress: Sprite2D = $Fortress
@onready var player_units: Node2D = $PlayerUnits
@onready var enemy_units: Node2D = $EnemyUnits
@onready var player_spawn_slots: Node2D = $PlayerSpawnSlots
@onready var enemy_spawn_slots: Node2D = $EnemySpawnSlots

# UI references (assign in inspector for flexibility)
@export var swordsman_button: Button
@export var archer_button: Button
@export var start_button: Button
@export var restart_button: Button
@export var hp_label: Label


func _ready() -> void:
	_validate_ui_references()
	_setup_ui()
	_update_hp_display()
	_validate_spawn_slots()
	_spawn_enemies()


func _process(_delta: float) -> void:
	# Only check battle end during battle phase
	if phase != "battle":
		return
	
	# Check if battle is over
	var player_count := _count_living_units(player_units)
	var enemy_count := _count_living_units(enemy_units)
	
	# Battle ends when one side is eliminated
	if player_count == 0 or enemy_count == 0:
		_end_battle(player_count > 0)


func _setup_ui() -> void:
	# Connect button signals (with null checks)
	if swordsman_button:
		swordsman_button.pressed.connect(_on_swordsman_button_pressed)
		swordsman_button.text = "Add Swordsman"
	if archer_button:
		archer_button.pressed.connect(_on_archer_button_pressed)
		archer_button.text = "Add Archer"
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		start_button.text = "Fight!"
		start_button.disabled = true  # Disable initially (no units yet)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		restart_button.text = "Restart"
		restart_button.visible = false  # Hide initially


func _update_hp_display() -> void:
	if hp_label:
		hp_label.text = "HP: %d" % player_hp


func _spawn_enemies() -> void:
	# Check if unit_scene is assigned
	if enemy_scene == null:
		push_error("enemy_scene is not assigned in Game!")
		return

	# Get enemy spawn positions from Marker2D nodes
	var enemy_positions := _get_enemy_spawn_positions()
	if enemy_positions.is_empty():
		push_warning("No enemy spawn positions found! Add Marker2D nodes to EnemySpawnSlots.")
		return

	# Spawn an enemy at each position
	for pos in enemy_positions:
		var enemy: Unit = enemy_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit!")
			continue

		# Add to enemy units container first (needed for coordinate conversion)
		enemy_units.add_child(enemy)

		# Configure as enemy unit
		enemy.is_enemy = true
		enemy.enemy_container = player_units  # Enemies target player units
		# Convert global spawn position to local position relative to enemy_units
		enemy.global_position = pos


func _clear_all_units() -> void:
	# Remove all player units
	for child in player_units.get_children():
		child.queue_free()

	# Remove all enemy units
	for child in enemy_units.get_children():
		child.queue_free()


func _end_battle(player_won: bool) -> void:
	phase = "end"
	
	# Stop all units from moving
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("idle")
	
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("idle")
	
	# If player lost, surviving enemies damage the fortress
	if not player_won:
		var surviving_enemies := _count_living_units(enemy_units)
		if surviving_enemies > 0:
			player_hp -= surviving_enemies
			player_hp = max(0, player_hp)  # Don't go below 0
			_update_hp_display()
			print("Fortress took %d damage! %d enemies survived." % [surviving_enemies, surviving_enemies])
	
	# Show restart button
	if restart_button:
		restart_button.visible = true
		restart_button.disabled = false
	
	print("Battle ended! Player won: ", player_won)


func _validate_ui_references() -> void:
	# Warn if UI references are not assigned
	if swordsman_button == null:
		push_warning("swordsman_button is not assigned! Assign it in the inspector.")
	if archer_button == null:
		push_warning("archer_button is not assigned! Assign it in the inspector.")
	if start_button == null:
		push_warning("start_button is not assigned! Assign it in the inspector.")
	if restart_button == null:
		push_warning("restart_button is not assigned! Assign it in the inspector.")
	if hp_label == null:
		push_warning("hp_label is not assigned! Assign it in the inspector.")


func _validate_spawn_slots() -> void:
	# Check if spawn slot containers exist
	if player_spawn_slots == null:
		push_error("PlayerSpawnSlots node not found! Add a Node2D named 'PlayerSpawnSlots' with Marker2D children.")
	if enemy_spawn_slots == null:
		push_error("EnemySpawnSlots node not found! Add a Node2D named 'EnemySpawnSlots' with Marker2D children.")
	
	# Warn if no spawn slots found
	if player_spawn_slots != null and player_spawn_slots.get_child_count() == 0:
		push_warning("No player spawn slots found! Add Marker2D nodes as children of PlayerSpawnSlots.")
	if enemy_spawn_slots != null and enemy_spawn_slots.get_child_count() == 0:
		push_warning("No enemy spawn slots found! Add Marker2D nodes as children of EnemySpawnSlots.")


func _get_player_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if player_spawn_slots == null:
		return positions
	
	for child in player_spawn_slots.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	
	return positions


func _get_enemy_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if enemy_spawn_slots == null:
		return positions
	
	for child in enemy_spawn_slots.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	
	return positions


func _get_next_available_slot() -> Vector2:
	# Get all currently occupied positions (in global coordinates)
	var occupied_positions := []
	for child in player_units.get_children():
		if child is Unit:
			occupied_positions.append(child.global_position)
	
	# Get spawn slot positions (in global coordinates)
	var spawn_positions := _get_player_spawn_positions()
	
	# Find the first slot that isn't occupied
	for slot_pos in spawn_positions:
		# Check if this position is occupied (with small tolerance for floating point)
		var is_occupied := false
		for occupied_pos in occupied_positions:
			if slot_pos.distance_to(occupied_pos) < 1.0:
				is_occupied = true
				break
		
		if not is_occupied:
			# Return global position - will be converted when setting unit position
			return slot_pos
	
	# All slots are occupied
	return Vector2.ZERO


func _on_swordsman_button_pressed() -> void:
	_spawn_player_unit(swordsman_scene)


func _on_archer_button_pressed() -> void:
	_spawn_player_unit(archer_scene)


func _spawn_player_unit(unit_scene: PackedScene) -> void:
	# Only allow spawning during placement phase
	if phase != "placement":
		return

	# Find next available spawn position
	var spawn_pos := _get_next_available_slot()
	if spawn_pos == Vector2.ZERO:
		# All slots are filled
		if swordsman_button:
			swordsman_button.disabled = true
		if archer_button:
			archer_button.disabled = true
		return

	# Check if unit_scene is assigned
	if unit_scene == null:
		push_error("unit_scene is not assigned!")
		return

	# Instantiate the unit
	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Failed to instantiate unit scene!")
		return

	# Add to player units container first (needed for coordinate conversion)
	player_units.add_child(unit)
	
	# Configure the unit as a player unit
	unit.is_enemy = false
	unit.enemy_container = enemy_units  # Player units target enemies
	# Convert global spawn position to local position relative to player_units
	unit.global_position = spawn_pos

	# Disable buttons if all slots filled
	var spawn_positions := _get_player_spawn_positions()
	if player_units.get_child_count() >= spawn_positions.size():
		if swordsman_button:
			swordsman_button.disabled = true
		if archer_button:
			archer_button.disabled = true
	
	# Enable start button now that we have at least one unit
	if start_button:
		start_button.disabled = false


func _count_living_units(container: Node2D) -> int:
	var count := 0
	for child in container.get_children():
		if child is Unit:
			var unit := child as Unit
			# Count units that are not dead or dying
			if unit.current_hp > 0 and unit.state != "dying":
				count += 1
	return count


func _on_start_button_pressed() -> void:
	# Only allow starting battle during placement phase
	if phase != "placement":
		return
	
	# Don't start if no player units spawned
	if player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return
	
	# Transition to battle phase
	phase = "battle"
	
	# Set all units to moving state
	for child in player_units.get_children():
		if child is Unit:
			child.set_state("moving")
	
	for child in enemy_units.get_children():
		if child is Unit:
			child.set_state("moving")
	
	# Update UI
	if swordsman_button:
		swordsman_button.visible = false
		swordsman_button.disabled = true
	if archer_button:
		archer_button.visible = false
		archer_button.disabled = true
	if start_button:
		start_button.disabled = true


func _on_restart_button_pressed() -> void:
	# Only allow restart during end phase
	if phase != "end":
		return
	
	# Clear all units
	_clear_all_units()
	
	# Wait a frame for units to be fully removed (queue_free needs time)
	await get_tree().process_frame
	
	# Re-spawn enemies
	_spawn_enemies()
	
	# Reset UI to placement phase state
	if swordsman_button:
		swordsman_button.visible = true
		swordsman_button.disabled = false
	if archer_button:
		archer_button.visible = true
		archer_button.disabled = false
	# Disable start button if no units (will be enabled when units are spawned)
	if start_button:
		start_button.disabled = (player_units.get_child_count() == 0)
	if restart_button:
		restart_button.visible = false
		restart_button.disabled = true
	
	# Reset game phase
	phase = "placement"
	
	print("Game restarted!")
