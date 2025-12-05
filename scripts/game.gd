extends Control
class_name Game

# Signals
signal unit_placed(unit_type: String)
signal army_unit_placed(slot_index: int)
signal gold_changed(new_amount: int)

# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"
var army: Array = []  # Array of ArmyUnit

# Gold system
@export var starting_gold := 20
var gold: int = 0
var total_gold_spent: int = 0  # Track gold spent for army value calculation

# Level management
## Array of LevelPool resources. Each pool contains multiple level scene options for that level.
@export var level_pools: Array[Resource] = []
## Total number of levels/battles in the game (used for completion tracking)
@export var total_levels: int = 10
var current_level_index := 0
var selected_level_scene: PackedScene = null  # The specific scene chosen from the pool

# Upgrade screen
@export var upgrade_background: Texture2D
var enemies_faced: Array = []  # Captured at end of battle for upgrade screen
var current_enemy_army: Array[ArmyUnit] = []  # Generated enemy army for current battle

# Current level references (set when level loads)
var current_level: LevelRoot = null

var is_draft_mode: bool = true

# Scene references
# (Removed unused swordsman_scene and archer_scene - units come from starting_unit_scenes and EnemyMarker.unit_scene)

# Starting roster for draft phase
@export var starting_roster: Roster

## Array of full rosters for enemy army generation
@export var full_rosters: Array[Roster] = []

# Node references (assign in inspector)
@export var background_rect: TextureRect
@export var gameplay: Node2D
@export var player_units: Node2D
@export var enemy_units: Node2D

# UI references (assign in inspector)
@export var hud: HUD
@export var ui_layer: CanvasLayer  # Where levels get loaded (same layer as HUD for drag-drop)

## Title screen scene path (loaded at runtime to avoid circular reference with titlescreen preloading game)
@export var title_screen_path: String = "res://scenes/titlescreen.tscn"


func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.auto_deploy_requested.connect(_on_auto_deploy_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	hud.battle_select_advance_data.connect(_on_battle_select_advance)
	hud.draft_complete.connect(_on_draft_complete)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)
	
	# Initialize gold
	gold = starting_gold
	gold_changed.emit(gold)
	
	# Start in draft mode
	_show_draft_screen()


func _show_draft_screen() -> void:
	"""Show the draft screen at game start."""
	# Set upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Initialize empty army
	army.clear()
	
	# Show draft screen via HUD
	hud.show_draft_screen(starting_roster)


func add_gold(amount: int) -> void:
	"""Add gold and notify listeners."""
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	"""Spend gold if available. Returns true if successful, false if insufficient."""
	if gold < amount:
		return false
	gold -= amount
	total_gold_spent += amount  # Track spending
	gold_changed.emit(gold)
	return true


func can_afford(amount: int) -> bool:
	"""Check if player has enough gold."""
	return gold >= amount


func calculate_army_value() -> int:
	"""
	Calculate the total value of the player's army.
	Value = current gold + sum of (base_recruit_cost + upgrade_cost * upgrades) for each unit.
	"""
	var value := gold

	for army_unit in army:
		if army_unit.unit_scene == null:
			continue

		# Get unit costs by instantiating temporarily
		var instance := army_unit.unit_scene.instantiate() as Unit
		if instance == null:
			continue

		var base_cost := instance.base_recruit_cost
		var upgrade_cost := instance.upgrade_cost
		instance.queue_free()

		# Add base cost
		value += base_cost

		# Add upgrade costs (full price, not discounted)
		var total_upgrades := 0
		for count in army_unit.upgrades.values():
			total_upgrades += count
		value += upgrade_cost * total_upgrades

	return value


func generate_battle_options() -> Array[BattleOptionData]:
	"""Generate two battle options from random rosters with scaled armies."""
	var result: Array[BattleOptionData] = []

	if full_rosters.size() < 2:
		push_error("Need at least 2 full rosters for battle generation!")
		return result

	# Calculate player army value
	var army_value := calculate_army_value()

	# Generate multipliers
	var low_multiplier := randf_range(0.5, 1.0)
	var high_multiplier := randf_range(1.0, 1.5)
	var low_target := int(army_value * low_multiplier)
	var high_target := int(army_value * high_multiplier)

	print("Player army value: %d" % army_value)
	print("Target values - Low: %d (%.1fx), High: %d (%.1fx)" % [low_target, low_multiplier, high_target, high_multiplier])

	# Pick 2 random rosters
	var roster_indices: Array[int] = []
	for i in range(full_rosters.size()):
		roster_indices.append(i)
	roster_indices.shuffle()

	var roster_a: Roster = full_rosters[roster_indices[0]]
	var roster_b: Roster = full_rosters[roster_indices[1]]

	# Randomly assign low/high targets
	var targets := [low_target, high_target]
	targets.shuffle()

	# Generate option A
	var battlefield_a: PackedScene = roster_a.battlefields.pick_random() if not roster_a.battlefields.is_empty() else null
	if battlefield_a == null:
		push_error("Roster '%s' has no battlefields!" % roster_a.team_name)
		return result

	var slot_count_a := _count_enemy_slots(battlefield_a)
	var army_a := ArmyGenerator.generate_army(roster_a, targets[0], slot_count_a)
	var value_a := ArmyGenerator.calculate_army_value(army_a)
	print("Generated '%s' army worth %d gold (target: %d)" % [roster_a.team_name, value_a, targets[0]])
	result.append(BattleOptionData.create(roster_a, battlefield_a, army_a, targets[0]))

	# Generate option B
	var battlefield_b: PackedScene = roster_b.battlefields.pick_random() if not roster_b.battlefields.is_empty() else null
	if battlefield_b == null:
		push_error("Roster '%s' has no battlefields!" % roster_b.team_name)
		return result

	var slot_count_b := _count_enemy_slots(battlefield_b)
	var army_b := ArmyGenerator.generate_army(roster_b, targets[1], slot_count_b)
	var value_b := ArmyGenerator.calculate_army_value(army_b)
	print("Generated '%s' army worth %d gold (target: %d)" % [roster_b.team_name, value_b, targets[1]])
	result.append(BattleOptionData.create(roster_b, battlefield_b, army_b, targets[1]))

	return result


func _count_enemy_slots(battlefield_scene: PackedScene) -> int:
	"""Count the number of EnemySpawnSlots in a battlefield scene."""
	if battlefield_scene == null:
		return 6  # Default fallback

	var instance := battlefield_scene.instantiate()
	if instance == null:
		return 6

	var count := 0
	var spawn_slots: Array[EnemySpawnSlot] = []
	_find_enemy_spawn_slots_recursive(instance, spawn_slots)
	count = spawn_slots.size()

	instance.queue_free()
	return count if count > 0 else 6  # Fallback to 6 if no slots found


func _find_enemy_spawn_slots_recursive(node: Node, result: Array[EnemySpawnSlot]) -> void:
	"""Recursively find all EnemySpawnSlot nodes in the scene tree, preserving hierarchy order."""
	if node is EnemySpawnSlot:
		result.append(node)
	
	# Process children in hierarchy order (get_children() preserves scene tree order)
	for child in node.get_children():
		_find_enemy_spawn_slots_recursive(child, result)


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

	# Stop all units (but don't reset dying units - they need to stay "dying" to prevent double gold)
	for child in player_units.get_children():
		if child is Unit and child.state != "dying":
			child.set_state("idle")
	for child in enemy_units.get_children():
		if child is Unit and child.state != "dying":
			child.set_state("idle")

	# Capture enemy data for upgrade screen (only if victory and not last level, defeat will restart)
	if victory and current_level_index < total_levels - 1:
		_capture_enemies_faced()
	
	# Show battle end modal (which leads to upgrade screen on victory, or restart on defeat/last level)
	hud.show_battle_end_modal(victory, current_level_index + 1, total_levels)
	
	# Update auto-deploy button state (should be disabled during upgrade phase)
	if hud:
		hud._update_auto_deploy_button_state()


func load_level(index: int) -> void:
	"""Load a level by index, picking the first scene from that level's pool."""
	# Validate index first
	if index < 0 or index >= level_pools.size():
		push_error("Invalid level index: %d (pool count: %d)" % [index, level_pools.size()])
		return
	
	var pool = level_pools[index]
	if not pool is LevelPool:
		push_error("Level pool at index %d is not a LevelPool resource!" % index)
		return
	
	var level_pool: LevelPool = pool as LevelPool
	if level_pool == null or level_pool.level_scenes.size() == 0:
		push_error("Level pool at index %d is empty or invalid!" % index)
		return
	
	var level_scene: PackedScene = level_pool.level_scenes[0]
	if level_scene == null:
		push_error("First scene in level pool %d is null!" % index)
		return
	
	# Use the new load method
	await load_level_scene(level_scene)


func load_level_scene(level_scene: PackedScene) -> void:
	"""Load a specific level scene (used when player picks from battle select)."""
	if level_scene == null:
		push_error("level_scene is null!")
		return
	
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

	# Spawn enemies - use generated army if available, otherwise use EnemyMarkers
	if not current_enemy_army.is_empty():
		_spawn_enemies_from_generated_army()
	else:
		_spawn_enemies_from_level()

	# Update HUD
	phase = "preparation"
	hud.set_phase(phase, current_level_index + 1)
	
	# Populate tray from army data
	if army.size() > 0:
		hud.set_tray_from_army(army)
	
	# Update auto-deploy button state
	if hud:
		hud._update_auto_deploy_button_state()


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
		enemy.enemy_unit_died.connect(_on_enemy_unit_died)


func _spawn_enemies_from_generated_army() -> void:
	"""Spawn enemies from the current_enemy_army using EnemySpawnSlots."""
	if current_level == null:
		push_warning("current_level is null in _spawn_enemies_from_generated_army")
		return

	if current_enemy_army.is_empty():
		push_warning("current_enemy_army is empty")
		return

	# Collect spawn slots - use configured container if available, otherwise search entire scene
	var spawn_slots: Array[EnemySpawnSlot] = []
	if current_level.enemy_spawn_slots_container:
		# Use configured container - get_children() preserves hierarchy order
		for child in current_level.enemy_spawn_slots_container.get_children():
			if child is EnemySpawnSlot:
				spawn_slots.append(child)
	else:
		# Search entire scene tree for EnemySpawnSlot nodes
		# Recursive search preserves hierarchy order (depth-first traversal)
		_find_enemy_spawn_slots_recursive(current_level, spawn_slots)

	if spawn_slots.is_empty():
		push_warning("No EnemySpawnSlot nodes found in EnemySpawnSlots")
		return

	# Spawn units at slots (army is already sorted by priority)
	for i in range(mini(current_enemy_army.size(), spawn_slots.size())):
		var army_unit := current_enemy_army[i]
		var slot := spawn_slots[i]

		if army_unit.unit_scene == null:
			push_error("Generated army unit at index %d has no unit_scene!" % i)
			continue

		var enemy: Unit = army_unit.unit_scene.instantiate() as Unit
		if enemy == null:
			push_error("Failed to instantiate enemy unit at index %d!" % i)
			continue

		# Configure enemy
		enemy.is_enemy = true
		enemy.enemy_container = player_units
		enemy.global_position = slot.global_position
		enemy.upgrades = army_unit.upgrades.duplicate()

		enemy_units.add_child(enemy)
		enemy.apply_upgrades()

		# Connect death signal
		enemy.enemy_unit_died.connect(_on_enemy_unit_died)


func _capture_enemies_faced() -> void:
	"""Capture enemies for the upgrade screen - uses generated army if available."""
	enemies_faced.clear()

	# If we have a generated army, use that
	if not current_enemy_army.is_empty():
		for army_unit in current_enemy_army:
			enemies_faced.append({
				"unit_type": army_unit.unit_type,
				"unit_scene": army_unit.unit_scene,
				"upgrades": army_unit.upgrades.duplicate()
			})
		return

	# Fallback: read from EnemyMarkers (for non-generated levels)
	if current_level == null:
		return

	var enemy_markers := current_level.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return

	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue

		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue

		var unit_type: String = enemy_marker.unit_scene.resource_path.get_file().get_basename()
		enemies_faced.append({
			"unit_type": unit_type,
			"unit_scene": enemy_marker.unit_scene,
			"upgrades": enemy_marker.upgrades.duplicate()
		})


func get_current_pool_size() -> int:
	"""Get the number of level options in the current level's pool."""
	if current_level_index < 0 or current_level_index >= level_pools.size():
		return 0
	var pool = level_pools[current_level_index]
	if not pool is LevelPool:
		return 0
	var level_pool: LevelPool = pool as LevelPool
	if level_pool == null:
		return 0
	return level_pool.level_scenes.size()


func get_random_level_options(pool_index: int, count: int = 2) -> Array[PackedScene]:
	"""Pick up to 'count' distinct random scenes from the specified pool."""
	var result: Array[PackedScene] = []
	
	if pool_index < 0 or pool_index >= level_pools.size():
		return result
	
	var pool = level_pools[pool_index]
	if not pool is LevelPool:
		return result
	
	var level_pool: LevelPool = pool as LevelPool
	if level_pool == null or level_pool.level_scenes.size() == 0:
		return result
	
	# Create a shuffled copy of indices
	var indices: Array[int] = []
	for i in range(level_pool.level_scenes.size()):
		indices.append(i)
	indices.shuffle()
	
	# Pick up to 'count' scenes
	var pick_count := mini(count, level_pool.level_scenes.size())
	for i in range(pick_count):
		var scene: PackedScene = level_pool.level_scenes[indices[i]]
		if scene != null:
			result.append(scene)
	
	return result


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
		hud._update_auto_deploy_button_state()


func _on_army_unit_placed(slot_index: int) -> void:
	if hud:
		hud.clear_tray_slot(slot_index)
		hud._update_auto_deploy_button_state()


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
	unit.army_index = army_index  # Track which army slot this unit came from
	unit.apply_upgrades()  # Apply after positioning
	
	# Connect player unit death signal
	unit.player_unit_died.connect(_on_player_unit_died)

	slot.set_occupied(true)
	
	# Mark army slot as placed
	army_unit.placed = true
	army_unit_placed.emit(army_index)
	
	# Notify HUD that a unit was placed
	unit_placed.emit(army_unit.unit_type)


func recruit_enemy(enemy_data) -> void:
	"""Add an enemy to the player's army. Accepts Dictionary or ArmyUnit."""
	if army.size() >= 10:
		push_warning("Cannot recruit: army is full")
		return

	var new_unit := ArmyUnit.new()
	if enemy_data is Dictionary:
		new_unit.unit_scene = enemy_data.get("unit_scene")
		new_unit.unit_type = enemy_data.get("unit_type", "unknown")
		new_unit.upgrades = enemy_data.get("upgrades", {}).duplicate()
	elif enemy_data is ArmyUnit:
		new_unit.unit_scene = enemy_data.unit_scene
		new_unit.unit_type = enemy_data.unit_type
		new_unit.upgrades = enemy_data.upgrades.duplicate()
	else:
		push_error("recruit_enemy: unexpected type %s" % typeof(enemy_data))
		return
	
	new_unit.placed = false
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


func _on_enemy_unit_died(gold_reward: int) -> void:
	"""Handle enemy unit death and award gold."""
	add_gold(gold_reward)


func _on_player_unit_died(army_index: int) -> void:
	"""Handle player unit death and remove from army."""
	if army_index < 0 or army_index >= army.size():
		return
	
	# Remove from army array
	army.remove_at(army_index)
	
	# Update army indices for remaining units (since array shifted)
	for child in player_units.get_children():
		if child is Unit:
			var unit := child as Unit
			if unit.army_index > army_index:
				unit.army_index -= 1
	
	# Update HUD tray
	if hud:
		hud.set_tray_from_army(army)


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
	
	# Update auto-deploy button state (should be disabled during battle)
	if hud:
		hud._update_auto_deploy_button_state()


func _on_show_upgrade_screen_requested() -> void:
	"""Handle request to show upgrade screen (after battle end modal button clicked on victory)."""
	# Swap to upgrade background
	if background_rect and upgrade_background:
		background_rect.texture = upgrade_background
	
	# Show upgrade screen with army and enemy data
	hud.show_upgrade_screen(true, army, enemies_faced)  # Only called on victory


func _on_battle_select_advance(option_data: BattleOptionData) -> void:
	"""Handle battle select advance - load the chosen battlefield with generated army."""
	current_enemy_army = option_data.army
	load_level_scene(option_data.battlefield)


func _return_to_title_screen() -> void:
	"""Return to the title screen when game is completed."""
	if not ResourceLoader.exists(title_screen_path):
		push_error("Title screen scene path does not exist: %s" % title_screen_path)
		return
	
	var scene := load(title_screen_path) as PackedScene
	if scene == null:
		push_error("Failed to load title screen scene from path: %s" % title_screen_path)
		return
	
	# Defer scene change to avoid input handling errors during transition
	call_deferred("_change_to_title_screen", scene)


func _change_to_title_screen(scene: PackedScene) -> void:
	"""Actually perform the scene change (called deferred)."""
	get_tree().change_scene_to_packed(scene)


func _on_auto_deploy_requested() -> void:
	"""Handle auto-deploy request from HUD - automatically place all unplaced units."""
	if phase != "preparation":
		return
	
	# Get unplaced units
	var unplaced_units: Array[Dictionary] = []  # Array of {army_index: int, army_unit: ArmyUnit}
	for i in range(army.size()):
		var army_unit: ArmyUnit = army[i]
		if not army_unit.placed and army_unit.unit_scene != null:
			unplaced_units.append({"army_index": i, "army_unit": army_unit})
	
	if unplaced_units.is_empty():
		return  # No units to deploy
	
	# Sort by priority (high priority first)
	unplaced_units.sort_custom(_compare_units_by_priority)
	
	# Get available spawn slots (back to front)
	var spawn_slots: Array[SpawnSlot] = []
	if current_level:
		var spawn_slots_container := current_level.get_node_or_null("PlayerSpawnSlots")
		if spawn_slots_container:
			# Get all spawn slots and filter for unoccupied ones
			for child in spawn_slots_container.get_children():
				if child is SpawnSlot:
					var slot := child as SpawnSlot
					if not slot.is_occupied:
						spawn_slots.append(slot)
	
	if spawn_slots.is_empty():
		return  # No available slots
	
	# Reverse slots to go back to front
	spawn_slots.reverse()
	
	# Place units starting from the back
	var slots_used: int = min(unplaced_units.size(), spawn_slots.size())
	for i in range(slots_used):
		var unit_data: Dictionary = unplaced_units[i]
		var slot: SpawnSlot = spawn_slots[i]
		place_unit_from_army(unit_data["army_index"], slot)


func _compare_units_by_priority(a: Dictionary, b: Dictionary) -> bool:
	"""Compare function for sorting units by priority (higher priority first)."""
	var unit_a: ArmyUnit = a["army_unit"]
	var unit_b: ArmyUnit = b["army_unit"]
	
	# Get priority from unit scenes
	var priority_a := _get_unit_priority(unit_a.unit_scene)
	var priority_b := _get_unit_priority(unit_b.unit_scene)
	
	return priority_a > priority_b


func _get_unit_priority(unit_scene: PackedScene) -> int:
	"""Get the priority from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var p := instance.priority
	instance.queue_free()
	return p


func _on_draft_complete() -> void:
	"""Handle draft completion - start first battle directly (no battle select)."""
	is_draft_mode = false
	current_enemy_army.clear()  # Ensure clean state
	
	# Generate one random battle option for first battle
	if full_rosters.is_empty():
		push_error("No full rosters available for first battle!")
		return
	
	# Filter out rosters with the same name as starting roster
	var available_rosters: Array[Roster] = []
	for roster in full_rosters:
		if starting_roster and roster.team_name == starting_roster.team_name:
			continue  # Skip rosters matching starting roster name
		available_rosters.append(roster)
	
	if available_rosters.is_empty():
		push_warning("All rosters match starting roster name, using any roster")
		available_rosters = full_rosters
	
	# Pick one random roster from available ones
	var roster: Roster = available_rosters.pick_random()
	if roster.battlefields.is_empty():
		push_error("Roster '%s' has no battlefields!" % roster.team_name)
		return
	
	# Pick random battlefield from roster
	var battlefield: PackedScene = roster.battlefields.pick_random()
	
	# Calculate player army value and generate enemy army
	var army_value := calculate_army_value()
	var target_value := int(army_value * randf_range(0.7, 1.0))  # First battle slightly easier
	
	var slot_count := _count_enemy_slots(battlefield)
	var enemy_army := ArmyGenerator.generate_army(roster, target_value, slot_count)
	
	# Load battle directly
	current_enemy_army = enemy_army
	load_level_scene(battlefield)


func _on_upgrade_confirmed(victory: bool) -> void:
	# Hide upgrade screen
	hud.hide_upgrade_screen()
	
	if victory:
		# Check if all levels completed
		if current_level_index >= total_levels - 1:
			# All levels completed - return to title screen
			_return_to_title_screen()
			return
		
		# Clear the generated army for next battle
		current_enemy_army.clear()

		# Advance level index (used for tracking progress)
		current_level_index += 1

		# Clear old level and units before showing battle select
		_clear_all_units()
		if current_level:
			current_level.queue_free()
			current_level = null

		# Generate new battle options
		var options := generate_battle_options()
		if options.size() >= 2:
			hud.show_battle_select_generated(options)
		else:
			push_error("Failed to generate battle options!")
	else:
		# On defeat, return to title screen
		_return_to_title_screen()
