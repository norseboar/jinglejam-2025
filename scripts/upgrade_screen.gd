extends Control
class_name UpgradeScreen

# Signals
signal continue_pressed(victory: bool)
signal draft_complete()

# Node references (assign in inspector)
@export var army_slot_group: UnitSlotGroup
@export var enemy_slot_group: UnitSlotGroup
@export var continue_button: BaseButton
@export var start_battle_button: BaseButton

# Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

# Upgrade pane references
@export var upgrade_instructions: Node
@export var upgrade_data: Node
# Dynamic upgrade slots (3 per unit)
@export var upgrade_button_1: BaseButton
@export var upgrade_button_2: BaseButton
@export var upgrade_button_3: BaseButton
@export var upgrade_label_1: Label
@export var upgrade_label_2: Label
@export var upgrade_label_3: Label
@export var upgrade_price_label: Label
@export var sell_button: BaseButton
@export var sell_price_label: Label

# Recruit pane references
@export var recruit_instructions: Node
@export var recruit_data: Node
@export var recruit_button: BaseButton
@export var recruit_price_label: Label
@export var gold_label: Label
@export var draft_label: Label
@export var recruit_label: Label

# State
var current_victory_state: bool = false

# Selection state
var selected_army_index: int = -1
var selected_enemy_index: int = -1
var recruited_indices: Array[int] = []

var is_draft_mode: bool = false
var draft_roster: Array = []  # Array of ArmyUnit created from roster

# References to slot arrays (populated when screen shows)
var army_slots: Array[UnitSlot] = []
var enemy_slots: Array[UnitSlot] = []

# Reference to game's army (set when screen shows)
var army_ref: Array = []
var enemies_faced_ref: Array = []

# Store button parents for proper removal/adding
var start_battle_button_parent: Node = null
var continue_button_parent: Node = null
var start_battle_button_index: int = -1
var continue_button_index: int = -1


func _ready() -> void:
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

	# Connect start battle button
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_button_pressed)

	# Connect recruit button
	if recruit_button:
		recruit_button.pressed.connect(_on_recruit_button_pressed)

	# Connect upgrade buttons
	if upgrade_button_1:
		upgrade_button_1.pressed.connect(_on_upgrade_button_pressed.bind(0))
	if upgrade_button_2:
		upgrade_button_2.pressed.connect(_on_upgrade_button_pressed.bind(1))
	if upgrade_button_3:
		upgrade_button_3.pressed.connect(_on_upgrade_button_pressed.bind(2))

	# Connect sell button
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)

	# Hide editor background at runtime
	hide_editor_background()
	
	# Ensure screen is hidden initially
	visible = false
	
	# Connect to Game's gold_changed signal
	var game := _get_game()
	if game:
		game.gold_changed.connect(update_gold_display)


func hide_editor_background() -> void:
	"""Hide the editor-only background at runtime."""
	if editor_background:
		editor_background.visible = false


func show_upgrade_screen(victory: bool, player_army: Array, enemies_faced: Array) -> void:
	"""Show the upgrade screen with army and enemy data."""
	current_victory_state = victory

	# Store references
	army_ref = player_army
	enemies_faced_ref = enemies_faced

	# Reset selection state
	selected_army_index = -1
	selected_enemy_index = -1
	recruited_indices.clear()

	# Populate trays and connect slots
	_populate_army_tray(army_slot_group, player_army)
	_populate_enemy_tray(enemy_slot_group, enemies_faced)

	# Reset panes to instruction state
	_refresh_upgrade_pane()
	_refresh_recruit_pane()
	
	# Update gold display
	var game := _get_game()
	if game:
		update_gold_display(game.gold)

	# Set recruit mode (not draft)
	is_draft_mode = false
	_update_mode_display()

	# Show upgrade screen
	visible = true
	
	# Play shop music (post-battle upgrade screen only, not draft)
	MusicManager.play_track(MusicManager.shop_music)


func show_draft_screen(roster: Roster) -> void:
	"""Show the upgrade screen in draft mode with roster units to buy."""
	print("UpgradeScreen: show_draft_screen roster=%s units=%s" % [
		roster.team_name if roster else "null",
		roster.units.size() if roster else 0
	])
	is_draft_mode = true
	current_victory_state = true  # Not really relevant for draft

	# Store empty army reference (draft starts with no units)
	var game := _get_game()
	if game:
		army_ref = game.army
	else:
		army_ref = []

	# Convert roster to ArmyUnit array for the enemy tray
	draft_roster.clear()
	if roster:
		for unit_scene in roster.units:
			var army_unit := ArmyUnit.new()
			army_unit.unit_scene = unit_scene
			army_unit.unit_type = unit_scene.resource_path.get_file().get_basename()
			army_unit.placed = false
			army_unit.upgrades = {}
			draft_roster.append(army_unit)
	print("UpgradeScreen: draft_roster size=%d" % draft_roster.size())

	# Use draft_roster as the "enemies" to recruit from
	enemies_faced_ref = draft_roster

	# Reset selection state
	selected_army_index = -1
	selected_enemy_index = -1
	recruited_indices.clear()

	# Populate trays
	_populate_army_tray(army_slot_group, army_ref)
	_populate_enemy_tray(enemy_slot_group, draft_roster)

	# Reset panes to instruction state
	_refresh_upgrade_pane()
	_refresh_recruit_pane()

	# Update gold display
	if game:
		update_gold_display(game.gold)

	# Update label and buttons for draft mode
	_update_mode_display()

	# Show screen
	visible = true
	# Note: Draft screen does NOT play shop music - title music continues


func _update_mode_display() -> void:
	"""Update labels and buttons based on draft vs recruit mode."""
	# Show/hide appropriate label
	if draft_label:
		draft_label.visible = is_draft_mode
	if recruit_label:
		recruit_label.visible = not is_draft_mode

	# Store button parent references on first call
	if start_battle_button and start_battle_button_parent == null:
		start_battle_button_parent = start_battle_button.get_parent()
		if start_battle_button_parent:
			start_battle_button_index = start_battle_button.get_index()
	
	if continue_button and continue_button_parent == null:
		continue_button_parent = continue_button.get_parent()
		if continue_button_parent:
			continue_button_index = continue_button.get_index()

	# Show/hide appropriate button by removing/adding to tree
	# This ensures the VBoxContainer shrinks properly
	var vbox_container: VBoxContainer = null
	if start_battle_button_parent and start_battle_button_parent is VBoxContainer:
		vbox_container = start_battle_button_parent as VBoxContainer
	
	if start_battle_button and start_battle_button_parent:
		if is_draft_mode:
			# Add button if not already in tree
			if not start_battle_button.get_parent():
				if start_battle_button_index >= 0:
					start_battle_button_parent.add_child(start_battle_button)
					start_battle_button_parent.move_child(start_battle_button, start_battle_button_index)
				else:
					start_battle_button_parent.add_child(start_battle_button)
			start_battle_button.visible = true
			# Disable until army has at least 1 unit
			start_battle_button.disabled = army_ref.size() < 1
		else:
			# Remove button from tree when not needed
			if start_battle_button.get_parent():
				start_battle_button_parent.remove_child(start_battle_button)
	
	if continue_button and continue_button_parent:
		if not is_draft_mode:
			# Add button if not already in tree
			if not continue_button.get_parent():
				if continue_button_index >= 0:
					continue_button_parent.add_child(continue_button)
					continue_button_parent.move_child(continue_button, continue_button_index)
				else:
					continue_button_parent.add_child(continue_button)
			continue_button.visible = true
		else:
			# Remove button from tree when not needed
			if continue_button.get_parent():
				continue_button_parent.remove_child(continue_button)
	
	# Force VBoxContainer and PanelContainer to recalculate layout
	if vbox_container:
		# Update VBoxContainer first
		vbox_container.queue_sort()
		
		# Force parent PanelContainer to reset its size
		var panel_container := vbox_container.get_parent()
		if panel_container and panel_container is PanelContainer:
			# Reset the size to minimum so it recalculates based on content
			panel_container.reset_size()
			# Also queue sort to ensure proper layout
			call_deferred("_force_panel_resize", panel_container)


func _force_panel_resize(panel: PanelContainer) -> void:
	"""Helper to force panel to recalculate its size."""
	if panel:
		panel.reset_size()


func hide_upgrade_screen() -> void:
	"""Hide the upgrade screen."""
	visible = false


func _populate_army_tray(slot_group: UnitSlotGroup, units: Array) -> void:
	"""Populate the army tray with units using UnitSlotGroup."""
	if not slot_group:
		return

	# Get slots from UnitSlotGroup
	army_slots = slot_group.slots.duplicate()

	# Populate slots with ArmyUnit objects and connect signals
	for slot_index in range(army_slots.size()):
		var slot := army_slots[slot_index]
		
		# Disconnect any existing connections
		if slot.unit_slot_clicked.is_connected(_on_army_slot_clicked):
			slot.unit_slot_clicked.disconnect(_on_army_slot_clicked)

		# Connect click signal
		slot.unit_slot_clicked.connect(_on_army_slot_clicked)

		# Set unit from ArmyUnit object
		if slot_index < units.size():
			var army_unit = units[slot_index]
			slot.set_unit(army_unit)
		else:
			slot.set_unit(null)

		# Reset selection state
		slot.set_selected(false)


func _refresh_army_tray_slot(slot_index: int) -> void:
	"""Refresh a specific army tray slot to update upgrade visuals."""
	if slot_index < 0 or slot_index >= army_slots.size():
		return
	
	if slot_index >= army_ref.size():
		return
	
	var slot := army_slots[slot_index]
	var army_unit = army_ref[slot_index]
	
	# Preserve selection state
	var was_selected := slot.is_selected
	
	# Update the unit (this will refresh upgrade visuals)
	slot.set_unit(army_unit)
	
	# Restore selection state
	slot.set_selected(was_selected)


func _populate_enemy_tray(slot_group: UnitSlotGroup, units: Array) -> void:
	"""Populate the enemy tray with units using UnitSlotGroup."""
	if not slot_group:
		return

	# Get slots from UnitSlotGroup
	enemy_slots = slot_group.slots.duplicate()

	# Populate slots with ArmyUnit objects created from enemy data and connect signals
	for slot_index in range(enemy_slots.size()):
		var slot := enemy_slots[slot_index]
		
		# Disconnect any existing connections
		if slot.unit_slot_clicked.is_connected(_on_enemy_slot_clicked):
			slot.unit_slot_clicked.disconnect(_on_enemy_slot_clicked)

		# Connect click signal
		slot.unit_slot_clicked.connect(_on_enemy_slot_clicked)

		# Create ArmyUnit from enemy data and set on slot
		if slot_index < units.size():
			var unit_data = units[slot_index]
			# Convert enemy data to ArmyUnit
			var army_unit: ArmyUnit = null
			if unit_data is Dictionary:
				army_unit = ArmyUnit.create_from_enemy(unit_data)
			elif unit_data is ArmyUnit:
				# If it's already an ArmyUnit, use it directly
				army_unit = unit_data
			else:
				# Unexpected type - log error and skip
				push_error("Unexpected unit_data type in _populate_enemy_tray: %s" % typeof(unit_data))
				army_unit = null
			
			slot.set_unit(army_unit)
		else:
			slot.set_unit(null)

		# Reset selection state
		slot.set_selected(false)




func _on_army_slot_clicked(clicked_slot: UnitSlot) -> void:
	"""Handle click on an army slot."""
	# Get slot index from the slot
	var slot_index := clicked_slot.slot_index
	
	# Check if slot has a unit
	if slot_index < 0 or slot_index >= army_ref.size():
		return

	# Deselect previous
	if selected_army_index >= 0 and selected_army_index < army_slots.size():
		army_slots[selected_army_index].set_selected(false)

	# Select new
	selected_army_index = slot_index
	if slot_index < army_slots.size():
		army_slots[slot_index].set_selected(true)

	_refresh_upgrade_pane()


func _on_enemy_slot_clicked(clicked_slot: UnitSlot) -> void:
	"""Handle click on an enemy slot."""
	# Get slot index from the slot
	var slot_index := clicked_slot.slot_index
	
	# Check if slot has an enemy
	if slot_index < 0 or slot_index >= enemies_faced_ref.size():
		return

	# Deselect previous
	if selected_enemy_index >= 0 and selected_enemy_index < enemy_slots.size():
		enemy_slots[selected_enemy_index].set_selected(false)

	# Select new
	selected_enemy_index = slot_index
	if slot_index < enemy_slots.size():
		enemy_slots[slot_index].set_selected(true)

	_refresh_recruit_pane()


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
		# Disable sell button when no unit selected
		if sell_button:
			sell_button.disabled = true
		if sell_price_label:
			sell_price_label.text = ""
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

	# Disable all buttons if maxed
	var maxed := total_upgrades >= 3

	# Update upgrade price label
	if upgrade_price_label:
		if maxed:
			upgrade_price_label.text = "Upgrade limit reached"
		else:
			upgrade_price_label.text = "Upgrade: %d Gold" % upgrade_cost

	# Calculate and display sell price (half of base cost + upgrade costs)
	var base_cost := _get_unit_base_recruit_cost(army_unit.unit_scene)
	var total_upgrade_cost := upgrade_cost * total_upgrades
	var sell_price := int((base_cost + total_upgrade_cost) / 2.0)
	if sell_price_label:
		sell_price_label.text = "+%d gold" % sell_price

	# Enable sell button (always enabled when unit is selected)
	if sell_button:
		sell_button.disabled = false

	# Get available upgrades from unit scene
	var unit_instance := army_unit.unit_scene.instantiate() as Unit
	if unit_instance == null:
		push_error("Failed to instantiate unit for upgrade display")
		return
	var available_upgrades := unit_instance.available_upgrades
	unit_instance.queue_free()

	# Populate each upgrade slot (0-2)
	var upgrade_buttons := [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	var upgrade_labels := [upgrade_label_1, upgrade_label_2, upgrade_label_3]

	for i in range(3):
		var button: BaseButton = upgrade_buttons[i]
		var label: Label = upgrade_labels[i]

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
			# Replace \n with actual newlines (handles both literal \n and actual newlines)
			var display_text := upgrade.label_text.replace("\\n", "\n")
			label.text = "%s +%d" % [display_text, upgrade.amount]
			label.visible = true

		# Update button state
		if button:
			button.visible = true
			button.disabled = maxed or not can_afford_upgrade


func _refresh_recruit_pane() -> void:
	"""Update the recruit pane based on selected enemy unit."""
	if selected_enemy_index < 0 or selected_enemy_index >= enemies_faced_ref.size():
		# No selection - show instructions, hide data
		if recruit_instructions:
			recruit_instructions.visible = true
		if recruit_data:
			recruit_data.visible = false
		if recruit_button:
			recruit_button.disabled = true
		return

	# Has selection - hide instructions, show data
	if recruit_instructions:
		recruit_instructions.visible = false
	if recruit_data:
		recruit_data.visible = true

	# Get enemy data
	var enemy_data = enemies_faced_ref[selected_enemy_index]
	var enemy_scene: PackedScene = null
	var enemy_upgrades: Dictionary = {}

	if enemy_data is Dictionary:
		enemy_scene = enemy_data.get("unit_scene")
		enemy_upgrades = enemy_data.get("upgrades", {})
	else:
		enemy_scene = enemy_data.unit_scene
		enemy_upgrades = enemy_data.upgrades

	# Update unit summary (should be inside recruit_data)
	var unit_summary := recruit_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.show_unit_from_scene(enemy_scene, enemy_upgrades)

	# Calculate recruit cost: base_recruit_cost + (upgrade_cost * total_upgrades) with upgrades half off (rounded up)
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var full_upgrade_cost := upgrade_cost * total_upgrades
	var discounted_upgrade_cost := int(ceil(full_upgrade_cost / 2.0))
	var recruit_cost := base_cost + discounted_upgrade_cost
	
	# Update recruit price label
	if recruit_price_label:
		recruit_price_label.text = "Recruit: %d Gold" % recruit_cost

	# Check if already recruited
	if selected_enemy_index in recruited_indices:
		if recruit_button:
			recruit_button.disabled = true
		return

	# Check army size
	if army_ref.size() >= 10:
		if recruit_button:
			recruit_button.disabled = true
		return
	
	# Check if can afford
	var game := _get_game()
	var can_afford := game != null and game.can_afford(recruit_cost)

	# Update button
	if recruit_button:
		recruit_button.disabled = not can_afford


func _get_total_upgrades(upgrades: Dictionary) -> int:
	"""Count total upgrades from an upgrades dictionary."""
	var total := 0
	for count in upgrades.values():
		total += count
	return total


func _find_next_available_enemy_index(start_index: int) -> int:
	"""Find the next available enemy unit index, checking adjacent slots first, then wrapping around."""
	if enemies_faced_ref.is_empty():
		return -1
	
	var total_enemies := enemies_faced_ref.size()
	
	# First, try the next slot
	var next_index := (start_index + 1) % total_enemies
	if next_index != start_index and next_index not in recruited_indices:
		return next_index
	
	# Then try the previous slot
	var prev_index := (start_index - 1 + total_enemies) % total_enemies
	if prev_index != start_index and prev_index not in recruited_indices:
		return prev_index
	
	# If adjacent slots are taken, search for any available unit
	for i in range(total_enemies):
		var check_index := (start_index + i + 1) % total_enemies
		if check_index not in recruited_indices:
			return check_index
	
	# No available units
	return -1


func update_gold_display(amount: int) -> void:
	"""Update the gold label text."""
	if gold_label:
		gold_label.text = "Gold: %d" % amount


func _get_unit_upgrade_cost(unit_scene: PackedScene) -> int:
	"""Get the upgrade_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.upgrade_cost
	instance.queue_free()
	return cost


func _get_unit_base_recruit_cost(unit_scene: PackedScene) -> int:
	"""Get the base_recruit_cost from a unit scene."""
	if unit_scene == null:
		return 0
	var instance := unit_scene.instantiate() as Unit
	if instance == null:
		return 0
	var cost := instance.base_recruit_cost
	instance.queue_free()
	return cost


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

	# Refresh the army tray to update upgrade visuals
	_refresh_army_tray_slot(selected_army_index)

	# Refresh pane (updates button states and text)
	_refresh_upgrade_pane()


func _on_sell_button_pressed() -> void:
	"""Handle Sell button press."""
	if selected_army_index < 0 or selected_army_index >= army_ref.size():
		return

	var army_unit = army_ref[selected_army_index]
	
	# Calculate sell price (half of base cost + upgrade costs)
	var base_cost := _get_unit_base_recruit_cost(army_unit.unit_scene)
	var upgrade_cost := _get_unit_upgrade_cost(army_unit.unit_scene)
	var total_upgrades := _get_total_upgrades(army_unit.upgrades)
	var total_upgrade_cost := upgrade_cost * total_upgrades
	var sell_price := int((base_cost + total_upgrade_cost) / 2.0)
	
	# Get game instance
	var game := _get_game()
	if game == null:
		return
	
	# Remove unit from army_ref
	army_ref.remove_at(selected_army_index)
	
	# Also remove from game's army array (they should be the same reference)
	if game.army.size() > selected_army_index:
		game.army.remove_at(selected_army_index)
	
	# Give gold
	game.add_gold(sell_price)
	
	# Select next unit (or deselect if no units left)
	if army_ref.size() > 0:
		# Select the same index (which now points to the next unit) or the last unit if we removed the last one
		var next_index: int = min(selected_army_index, army_ref.size() - 1)
		selected_army_index = next_index
		
		# Update selection in tray
		if next_index < army_slots.size():
			# Deselect previous
			for slot in army_slots:
				if slot:
					slot.set_selected(false)
			# Select new
			army_slots[next_index].set_selected(true)
	else:
		# No units left, deselect
		selected_army_index = -1
		for slot in army_slots:
			if slot:
				slot.set_selected(false)
	
	# Refresh army tray
	_populate_army_tray(army_slot_group, army_ref)
	
	# Update selection after refreshing tray
	if selected_army_index >= 0 and selected_army_index < army_slots.size():
		army_slots[selected_army_index].set_selected(true)
	
	# Refresh upgrade pane (will show instructions if no unit selected)
	_refresh_upgrade_pane()


func _on_recruit_button_pressed() -> void:
	"""Handle Recruit button press."""
	if selected_enemy_index < 0 or selected_enemy_index >= enemies_faced_ref.size():
		return

	# Check if already recruited
	if selected_enemy_index in recruited_indices:
		return

	# Check army size
	if army_ref.size() >= 10:
		return

	# Get enemy data
	var enemy_data = enemies_faced_ref[selected_enemy_index]
	var enemy_scene: PackedScene = null
	var enemy_upgrades: Dictionary = {}

	if enemy_data is Dictionary:
		enemy_scene = enemy_data.get("unit_scene")
		enemy_upgrades = enemy_data.get("upgrades", {})
	else:
		enemy_scene = enemy_data.unit_scene
		enemy_upgrades = enemy_data.upgrades

	# Calculate recruit cost: base_recruit_cost + (upgrade_cost * total_upgrades) with upgrades half off (rounded up)
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var full_upgrade_cost := upgrade_cost * total_upgrades
	var discounted_upgrade_cost := int(ceil(full_upgrade_cost / 2.0))
	var recruit_cost := base_cost + discounted_upgrade_cost
	
	# Spend gold
	var game := _get_game()
	if game == null or not game.spend_gold(recruit_cost):
		return  # Can't afford

	# Create new ArmyUnit and add to army
	if game:
		game.recruit_enemy(enemy_data)
		# Update army_ref to reflect the new unit
		army_ref = game.army

	# Mark as recruited
	recruited_indices.append(selected_enemy_index)

	# Refresh army tray to show the newly recruited unit
	_populate_army_tray(army_slot_group, army_ref)

	# Store the previously selected index before clearing
	var previous_index := selected_enemy_index

	# Hide the recruited enemy from the enemy tray
	if previous_index >= 0 and previous_index < enemy_slots.size():
		enemy_slots[previous_index].set_unit(null)
		enemy_slots[previous_index].set_selected(false)

	# Find and select the next available unit (adjacent to the one just recruited)
	var next_index := _find_next_available_enemy_index(previous_index)
	if next_index >= 0:
		selected_enemy_index = next_index
		# Select the slot visually
		if next_index < enemy_slots.size():
			enemy_slots[next_index].set_selected(true)
	else:
		# No available units, clear selection
		selected_enemy_index = -1

	# Refresh pane immediately (updates button states and text)
	_refresh_recruit_pane()

	# Update start battle button state (may now have enough units)
	if is_draft_mode and start_battle_button:
		start_battle_button.disabled = army_ref.size() < 1


func _get_game() -> Game:
	"""Find the Game node."""
	var node := get_tree().get_first_node_in_group("game") as Game
	if node == null:
		# Fallback: search for Game class_name
		for child in get_tree().root.get_children():
			if child is Game:
				return child as Game
	return node


func _on_continue_button_pressed() -> void:
	"""Handle continue button press on upgrade screen."""
	hide_upgrade_screen()
	continue_pressed.emit(current_victory_state)


func _on_start_battle_button_pressed() -> void:
	"""Handle Start Battle button press in draft mode."""
	if army_ref.size() < 1:
		return  # Need at least 1 unit

	hide_upgrade_screen()
	draft_complete.emit()
