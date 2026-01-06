extends Control
class_name Game

# Signals
signal unit_placed(unit_type: String)
signal army_unit_placed(slot_index: int)
signal gold_changed(new_amount: int)

# Debug flag for enemy army generation
const DEBUG_DRAFT_ASSUME_GOLD := false  # If true, assume 10 gold when calculating army value for enemy generation
const DEBUG_DRAFT_GOLD_AMOUNT := 10  # Amount of gold to assume when debug flag is enabled

# Game state
var phase := "preparation"  # "preparation" | "battle" | "upgrade"
var army: Array = []  # Array of ArmyUnit

# Gold system
@export var starting_gold := 20
var gold: int = 0
var total_gold_spent: int = 0  # Track gold spent for army value calculation
## Percentage of unit value used for gold rewards when enemy units die (0.0-1.0)
## When enemy units die, they give this percentage of their value as gold.
@export var unit_value_percentage := 0.5  # 50% by default (can be changed to 0.75 for 75%, etc.)

# Level management
## Array of level data resources (defines difficulty progression)
@export var levels: Array[LevelData] = []
var current_level_index := 0

# Upgrade screen
@export var upgrade_background: Texture2D
var enemies_faced: Array = []  # Captured at end of battle for upgrade screen
var current_enemy_army: Array[ArmyUnit] = []  # Generated enemy army for current battle
var current_enemy_roster: Roster = null  # Track roster for music

# Current level references (set when level loads)
var current_level: LevelRoot = null

var is_draft_mode: bool = true

# Scene references
# (Removed unused swordsman_scene and archer_scene - units come from starting_unit_scenes and EnemyMarker.unit_scene)

# Starting roster for draft phase
@export var starting_roster: Roster

## Array of full rosters for enemy army generation
@export var full_rosters: Array[Roster] = []

## Neutral units that can mix into enemy armies after a level threshold
@export var neutral_roster: Roster

# Node references (assign in inspector)
@export var background_rect: TextureRect
@export var gameplay: Node2D
## DEPRECATED: Unit containers now live in the level. Use current_level.player_units instead.
@export var player_units: Node2D
## DEPRECATED: Unit containers now live in the level. Use current_level.enemy_units instead.
@export var enemy_units: Node2D

# UI references (assign in inspector)
@export var hud: HUD
@export var ui_layer: CanvasLayer  # Where levels get loaded (same layer as HUD for drag-drop)
@export var faction_select_screen: FactionSelectScreen

## Title screen scene path (loaded at runtime to avoid circular reference with titlescreen preloading game)
@export var title_screen_path: String = "res://scenes/titlescreen.tscn"

## Coin scene for gold collection animation
@export var coin_scene: PackedScene = preload("res://scenes/ui/coin.tscn")

## Squad scene for spawning multiple units
@export var squad_scene: PackedScene = preload("res://scenes/squad.tscn")


func _ready() -> void:
	hud.start_battle_requested.connect(_on_start_battle_requested)
	hud.auto_deploy_requested.connect(_on_auto_deploy_requested)
	hud.upgrade_confirmed.connect(_on_upgrade_confirmed)
	hud.show_upgrade_screen_requested.connect(_on_show_upgrade_screen_requested)
	hud.battle_select_advance_data.connect(_on_battle_select_advance)
	hud.draft_complete.connect(_on_draft_complete)
	unit_placed.connect(_on_unit_placed)
	army_unit_placed.connect(_on_army_unit_placed)
	if faction_select_screen:
		faction_select_screen.roster_selected.connect(_on_faction_roster_selected)
	
	# Initialize gold
	gold = starting_gold
	gold_changed.emit(gold)
	
	# Show faction selection before draft begins
	_show_faction_selection()


func _show_draft_screen() -> void:
	"""Show the draft screen at game start."""
	# Initialize empty army
	army.clear()
	
	# Show draft screen via HUD
	hud.show_draft_screen(starting_roster)


func _show_faction_selection() -> void:
	"""Display the faction select screen and pause draft flow until a roster is chosen."""
	if faction_select_screen:
		if hud:
			hud.hide_battle_section_for_faction_select()
		faction_select_screen.show_selector()
	else:
		# Fallback: proceed directly with whatever starting_roster is set
		_show_draft_screen()


func _on_faction_roster_selected(roster: Roster) -> void:
	"""Handle roster selection from the faction select screen."""
	if roster:
		starting_roster = roster
	_show_draft_screen()


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
	# Use debug gold if flag is enabled
	var gold_to_use := gold
	if DEBUG_DRAFT_ASSUME_GOLD:
		gold_to_use = DEBUG_DRAFT_GOLD_AMOUNT
	
	var value := gold_to_use

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

	# Get current level data
	if current_level_index < 0 or current_level_index >= levels.size():
		push_error("Invalid current_level_index: %d (levels size: %d)" % [current_level_index, levels.size()])
		return result

	var level_data := levels[current_level_index]

	# Calculate target values using level multipliers
	var low_target := int(army_value * level_data.low_multiplier)
	var high_target := int(army_value * level_data.high_multiplier)

	# Apply minimum gold floor
	low_target = max(low_target, level_data.minimum_gold)
	high_target = max(high_target, level_data.minimum_gold)

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
	var army_a := ArmyGenerator.generate_army(roster_a, targets[0], slot_count_a, level_data.forced_units, level_data.neutral_roster, level_data.minimum_gold)
	var _value_a := ArmyGenerator.calculate_army_value(army_a)
	result.append(BattleOptionData.create(roster_a, battlefield_a, army_a, targets[0]))

	# Generate option B
	var battlefield_b: PackedScene = roster_b.battlefields.pick_random() if not roster_b.battlefields.is_empty() else null
	if battlefield_b == null:
		push_error("Roster '%s' has no battlefields!" % roster_b.team_name)
		return result

	var slot_count_b := _count_enemy_slots(battlefield_b)
	var army_b := ArmyGenerator.generate_army(roster_b, targets[1], slot_count_b, level_data.forced_units, level_data.neutral_roster, level_data.minimum_gold)
	var _value_b := ArmyGenerator.calculate_army_value(army_b)
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

	if current_level == null:
		return
	
	var player_count := _count_living_units(current_level.player_units)
	var enemy_count := _count_living_units(current_level.enemy_units)

	if enemy_count == 0:
		_end_battle(true)  # Player wins
	elif player_count == 0:
		_end_battle(false)  # Player loses


func _clear_all_units() -> void:
	# Clear units from current level if it exists
	if current_level == null:
		return
	
	if current_level.player_units:
		for child in current_level.player_units.get_children():
			child.queue_free()
	
	if current_level.enemy_units:
		for child in current_level.enemy_units.get_children():
			child.queue_free()


func _end_battle(victory: bool) -> void:
	phase = "battle_end"
	
	# Update HUD state to reflect the battle-end phase (keep battle UI while modal shows)
	if hud:
		hud.set_phase(phase, current_level_index + 1)

	# Stop all units (but don't reset dying units - they need to stay "dying" to prevent double gold)
	if current_level:
		if current_level.player_units:
			for child in current_level.player_units.get_children():
				if child is Unit and child.state != "dying":
					child.set_state("idle")
		
		if current_level.enemy_units:
			for child in current_level.enemy_units.get_children():
				if child is Unit and child.state != "dying":
					child.set_state("idle")

	# Capture enemy data for upgrade screen (only if victory and not last level, defeat will restart)
	if victory and current_level_index < levels.size() - 1:
		_capture_enemies_faced()
	
	# Play victory or defeat jingle (and duck current music)
	if victory:
		MusicManager.play_jingle_and_duck(MusicManager.victory_jingle)
	else:
		MusicManager.play_jingle_and_duck(MusicManager.defeat_jingle)
	
	# Show battle end modal (which leads to upgrade screen on victory, or restart on defeat/last level)
	hud.show_battle_end_modal(victory, current_level_index + 1, levels.size())
	
	# Update auto-deploy button state (should be disabled during upgrade phase)
	if hud:
		hud._update_auto_deploy_button_state()




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
	
	# Add level to gameplay node
	if gameplay:
		gameplay.add_child(current_level)
	else:
		push_error("gameplay not assigned!")
		return
	
	# Validate that level has required unit containers
	if current_level.player_units == null:
		push_error("Level '%s' is missing player_units container!" % current_level.name)
		return
	if current_level.enemy_units == null:
		push_error("Level '%s' is missing enemy_units container!" % current_level.name)
		return
	
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
	
	# Play battle music
	_play_battle_music()


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
		
		# Instantiate unit temporarily to get squad_count
		var temp_unit := enemy_marker.unit_scene.instantiate() as Unit
		if temp_unit == null:
			push_error("Failed to instantiate enemy unit from scene at marker %s!" % enemy_marker.global_position)
			return
		var unit_squad_count := temp_unit.squad_count
		temp_unit.queue_free()
		
		# Spawn squad instead of individual unit
		var squad: Squad = squad_scene.instantiate() as Squad
		if squad == null:
			push_error("Failed to instantiate enemy squad")
			return
		
		current_level.enemy_units.add_child(squad)
		squad.global_position = enemy_marker.global_position
		
		# Setup squad (spawns units)
		squad.setup(
			enemy_marker.unit_scene,
			unit_squad_count,
			enemy_marker.upgrades,
			true,  # is_enemy
			current_level.player_units,
			current_level.enemy_units
		)
		
		# Connect death signals for gold rewards
		for child in squad.get_children():
			if child is Unit:
				child.enemy_unit_died.connect(_on_enemy_unit_died)


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

		# Spawn squad instead of individual unit
		var squad: Squad = squad_scene.instantiate() as Squad
		if squad == null:
			push_error("Failed to instantiate enemy squad at index %d" % i)
			continue

		current_level.enemy_units.add_child(squad)
		squad.global_position = slot.global_position

		# Setup squad (spawns units)
		squad.setup(
			army_unit.unit_scene,
			army_unit.squad_count,
			army_unit.upgrades,
			true,  # is_enemy
			current_level.player_units,
			current_level.enemy_units
		)

		# Connect death signals for gold rewards
		for child in squad.get_children():
			if child is Unit:
				child.enemy_unit_died.connect(_on_enemy_unit_died)


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
	if hud and current_level and current_level.player_units:
		hud.update_placed_count(current_level.player_units.get_child_count())
		hud._update_auto_deploy_button_state()


func _on_army_unit_placed(slot_index: int) -> void:
	if hud:
		hud.clear_tray_slot(slot_index)
		hud._update_auto_deploy_button_state()


func place_unit_from_army(army_index: int, slot: SpawnSlot) -> void:
	"""Place a squad from the army array onto a spawn slot."""
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

	# Load squad scene
	var squad: Squad = squad_scene.instantiate() as Squad
	if squad == null:
		push_error("Failed to instantiate squad")
		return

	# Add squad to level's player_units container
	current_level.player_units.add_child(squad)

	# Set squad position to slot center
	squad.global_position = slot.get_slot_center()

	# Store references
	squad.army_index = army_index
	squad.spawn_slot = slot

	# Update drag handle's spawn slot reference
	if squad.drag_handle:
		squad.drag_handle.spawn_slot = slot

	# Setup squad (spawns units)
	squad.setup(
		army_unit.unit_scene,
		army_unit.squad_count,
		army_unit.upgrades,
		false,  # is_enemy
		current_level.enemy_units,
		current_level.player_units
	)

	# Note: We no longer remove dead units from army - they persist for upgrade screen

	# Mark slot as occupied
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
	var unit_scene: PackedScene = null
	if enemy_data is Dictionary:
		new_unit.unit_scene = enemy_data.get("unit_scene")
		new_unit.unit_type = enemy_data.get("unit_type", "unknown")
		new_unit.upgrades = enemy_data.get("upgrades", {}).duplicate()
		new_unit.squad_count = enemy_data.get("squad_count", 1)  # Copy squad_count if present
		unit_scene = new_unit.unit_scene
	elif enemy_data is ArmyUnit:
		new_unit.unit_scene = enemy_data.unit_scene
		new_unit.unit_type = enemy_data.unit_type
		new_unit.upgrades = enemy_data.upgrades.duplicate()
		new_unit.squad_count = enemy_data.squad_count  # Copy squad_count
		unit_scene = new_unit.unit_scene
	else:
		push_error("recruit_enemy: unexpected type %s" % typeof(enemy_data))
		return
	
	# If squad_count wasn't set, get it from unit scene
	if new_unit.squad_count == 1 and unit_scene != null:
		var temp_unit := unit_scene.instantiate() as Unit
		if temp_unit:
			new_unit.squad_count = temp_unit.squad_count
			temp_unit.queue_free()
	
	new_unit.placed = false
	army.append(new_unit)


func _unpack_squads() -> void:
	"""Move units out of Squad containers to be direct children of their containers.
	Called at battle start so all existing battle logic works with units."""
	if not current_level:
		return
	
	# Unpack player squads
	if current_level.player_units:
		_unpack_squads_in_container(current_level.player_units)
	
	# Unpack enemy squads
	if current_level.enemy_units:
		_unpack_squads_in_container(current_level.enemy_units)


func _unpack_squads_in_container(container: Node2D) -> void:
	"""Helper to unpack all squads in a given container."""
	var squads_to_remove: Array[Squad] = []
	
	for child in container.get_children():
		if child is Squad:
			var squad := child as Squad
			
			# Move all units from squad to container
			for squad_child in squad.get_children():
				if squad_child is Unit:
					var unit := squad_child as Unit
					
					# Store the unit's current global position before reparenting
					var saved_global_pos := unit.global_position
					
					# Remove from squad (without freeing)
					squad.remove_child(unit)
					
					# Add to container
					container.add_child(unit)
					
					# Restore the exact global position
					unit.global_position = saved_global_pos
			
			# Mark squad for removal
			squads_to_remove.append(squad)
	
	# Remove empty squad containers
	for squad in squads_to_remove:
		squad.queue_free()


func _count_living_units(container: Node2D) -> int:
	var count := 0
	for child in container.get_children():
		if child is Unit:
			var unit := child as Unit
			# Count units that are not dead or dying
			if unit.current_hp > 0 and unit.state != "dying":
				count += 1
	return count


func _on_enemy_unit_died(gold_reward: int, death_position: Vector2) -> void:
	"""Handle enemy unit death and award gold."""
	# Spawn coin animation
	_spawn_coin_animation(death_position)
	
	# Award gold (will be updated when coin reaches counter, but we can award immediately)
	add_gold(gold_reward)


func _spawn_coin_animation(start_position: Vector2) -> void:
	"""Spawn a coin animation that moves from start_position to the gold counter."""
	if coin_scene == null:
		push_warning("coin_scene not assigned, cannot spawn coin animation")
		return
	
	if hud == null:
		push_warning("HUD not available, cannot spawn coin animation")
		return
	
	# Get gold counter position from HUD
	var target_position: Vector2 = hud.get_gold_counter_position()
	
	# Instantiate coin
	var coin: CoinAnimation = coin_scene.instantiate() as CoinAnimation
	if coin == null:
		push_error("Failed to instantiate coin scene as CoinAnimation")
		return
	
	# Add to UI layer so it renders above gameplay
	if ui_layer:
		ui_layer.add_child(coin)
	else:
		# Fallback to gameplay layer if ui_layer not available
		if gameplay:
			gameplay.add_child(coin)
		else:
			push_error("No suitable parent for coin animation")
			coin.queue_free()
			return
	
	# Start animation
	coin.animate_to_target(start_position, target_position)


func _on_player_unit_died(_army_index: int) -> void:
	"""Handle player unit death (currently no-op - units persist in army for upgrade screen)."""
	# Previously removed unit from army array, but now we keep all units
	# so they show up on the upgrade screen even if they died
	pass


func _on_start_battle_requested() -> void:
	if phase != "preparation":
		return
	
	if not current_level:
		return
	
	if not current_level.player_units:
		push_error("Current level has no player_units container!")
		return

	if current_level.player_units.get_child_count() == 0:
		push_warning("Cannot start battle with no units!")
		return

	phase = "battle"
	hud.set_phase(phase, current_level_index + 1)
	_set_spawn_slots_visible(false)

	# Unpack squads - move units out of Squad containers and make them direct children
	_unpack_squads()

	# Set all units to moving
	if current_level.player_units:
		for child in current_level.player_units.get_children():
			if child is Unit:
				child.set_state("moving")
	
	if current_level.enemy_units:
		for child in current_level.enemy_units.get_children():
			if child is Unit:
				child.set_state("moving")
	
	# Update auto-deploy button state (should be disabled during battle)
	if hud:
		hud._update_auto_deploy_button_state()


func _on_show_upgrade_screen_requested() -> void:
	"""Handle request to show upgrade screen (after battle end modal button clicked on victory)."""
	phase = "upgrade"
	if hud:
		hud.set_phase(phase, current_level_index + 1)
	
	# Clear leftover units from the battle
	_clear_all_units()
	
	# Keep the level visible - upgrade screen will slide over it
	# (Level will be hidden later when transitioning to battle select)
	
	# Show upgrade screen with army and enemy data
	hud.show_upgrade_screen(true, army, enemies_faced)  # Only called on victory


func _on_battle_select_advance(option_data: BattleOptionData) -> void:
	"""Handle battle select advance - load the chosen battlefield with generated army."""
	current_enemy_roster = option_data.roster  # Store for music
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
	
	# Get available spawn slots (in hierarchy order - topmost first)
	var spawn_slots: Array[SpawnSlot] = []
	if current_level:
		var spawn_slots_container := current_level.get_node_or_null("PlayerSpawnSlots")
		if spawn_slots_container:
			# Get all spawn slots and filter for unoccupied ones
			# get_children() preserves hierarchy order (topmost slot first)
			for child in spawn_slots_container.get_children():
				if child is SpawnSlot:
					var slot := child as SpawnSlot
					if not slot.is_occupied:
						spawn_slots.append(slot)
	
	if spawn_slots.is_empty():
		return  # No available slots
	
	# Place highest priority units in topmost slots (first in hierarchy order)
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
	"""Handle draft completion - show battle select screen for first battle."""
	is_draft_mode = false
	current_enemy_army.clear()  # Ensure clean state
	
	# Set level index to 0 for first battle
	current_level_index = 0
	
	# Clear any old level and units before showing battle select
	_clear_all_units()
	if current_level:
		current_level.queue_free()
		current_level = null
	
	# Generate battle options (same as after victory)
	var options := generate_battle_options()
	if options.size() >= 2:
		hud.show_battle_select_generated(options)
	else:
		push_error("Failed to generate battle options!")


func _play_battle_music() -> void:
	"""Play the battle music for the current enemy roster."""
	if not current_enemy_roster:
		push_warning("No current_enemy_roster set")
		return

	# Check if we have valid level data
	if current_level_index < 0 or current_level_index >= levels.size():
		push_warning("Invalid level index for music selection")
		# Fallback to normal music
		if current_enemy_roster.battle_music:
			MusicManager.play_track(current_enemy_roster.battle_music)
		return

	var level_data := levels[current_level_index]
	var track: AudioStream = null

	# Check if we should use intense music
	if level_data.use_intense_music and current_enemy_roster.battle_music_intense:
		track = current_enemy_roster.battle_music_intense
	else:
		track = current_enemy_roster.battle_music

	if track:
		MusicManager.play_track(track)
	else:
		push_warning("No battle music available for current roster")


func _on_upgrade_confirmed(victory: bool) -> void:
	if victory:
		# Check if all levels completed
		if current_level_index >= levels.size() - 1:
			# All levels completed - hide upgrade screen and return to title
			hud.hide_upgrade_screen()
			_return_to_title_screen()
			return
		
		# Clear the generated army for next battle
		current_enemy_army.clear()

		# Advance level index (used for tracking progress)
		current_level_index += 1

		# Hide the battlefield and clear units before showing battle select
		if current_level:
			current_level.visible = false
		_clear_all_units()
		if current_level:
			current_level.queue_free()
			current_level = null

		# Generate new battle options
		var options := generate_battle_options()
		if options.size() >= 2:
			# Show battle select screen FIRST (it will be behind the upgrade screen)
			hud.show_battle_select_generated(options)
			# Then hide upgrade screen (which animates up, revealing battle select)
			hud.hide_upgrade_screen()
		else:
			push_error("Failed to generate battle options!")
			hud.hide_upgrade_screen()
	else:
		# On defeat, hide upgrade screen and return to title screen
		hud.hide_upgrade_screen()
		_return_to_title_screen()
