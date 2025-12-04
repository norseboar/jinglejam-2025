extends Control
class_name UpgradeScreen

# Signals
signal continue_pressed(victory: bool)

# Node references (assign in inspector)
@export var army_slot_group: UnitSlotGroup
@export var enemy_slot_group: UnitSlotGroup
@export var continue_button: BaseButton

# Editor-only background for placement reference (hidden at runtime)
@export var editor_background: CanvasItem

# Upgrade pane references
@export var upgrade_instructions: Node
@export var upgrade_data: Node
@export var hp_button: BaseButton
@export var damage_button: BaseButton
@export var upgrade_label: Label

# Recruit pane references
@export var recruit_instructions: Node
@export var recruit_data: Node
@export var recruit_button: BaseButton
@export var recruit_label: Label
@export var gold_label: Label

# State
var current_victory_state: bool = false

# Selection state
var selected_army_index: int = -1
var selected_enemy_index: int = -1
var recruited_indices: Array[int] = []

# References to slot arrays (populated when screen shows)
var army_slots: Array[UnitSlot] = []
var enemy_slots: Array[UnitSlot] = []

# Reference to game's army (set when screen shows)
var army_ref: Array = []
var enemies_faced_ref: Array = []


func _ready() -> void:
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	
	# Connect upgrade pane buttons
	if hp_button:
		hp_button.pressed.connect(_on_hp_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)

	# Connect recruit button
	if recruit_button:
		recruit_button.pressed.connect(_on_recruit_button_pressed)
	
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

	# Show upgrade screen
	visible = true


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
			# Convert enemy data to ArmyUnit using the static method
			var army_unit: ArmyUnit = null
			if unit_data is Dictionary:
				army_unit = ArmyUnit.create_from_enemy(unit_data)
			else:
				# If it's already an ArmyUnit-like object, create from it
				army_unit = ArmyUnit.new()
				army_unit.unit_scene = unit_data.unit_scene
				army_unit.unit_type = unit_data.get("unit_type", "") if unit_data.has("unit_type") else ""
				army_unit.upgrades = unit_data.get("upgrades", {}).duplicate() if unit_data.has("upgrades") else {}
				army_unit.placed = false
			
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
		if hp_button:
			hp_button.disabled = true
		if damage_button:
			damage_button.disabled = true
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

	# Update upgrade label
	if upgrade_label:
		upgrade_label.text = "Upgrade: %d Gold" % upgrade_cost

	# Disable buttons if maxed or can't afford
	var maxed := total_upgrades >= 3
	if hp_button:
		hp_button.disabled = maxed or not can_afford_upgrade
	if damage_button:
		damage_button.disabled = maxed or not can_afford_upgrade


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

	# Calculate recruit cost: base_recruit_cost + (upgrade_cost * total_upgrades)
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var recruit_cost := base_cost + (upgrade_cost * total_upgrades)
	
	# Update recruit label
	if recruit_label:
		recruit_label.text = "Recruit: %d Gold" % recruit_cost

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


func _on_hp_button_pressed() -> void:
	"""Handle HP upgrade button press."""
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

	# Add HP upgrade
	if not army_unit.upgrades.has("hp"):
		army_unit.upgrades["hp"] = 0
	army_unit.upgrades["hp"] += 1

	# Update stats display immediately
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates button states and text)
	_refresh_upgrade_pane()


func _on_damage_button_pressed() -> void:
	"""Handle Damage upgrade button press."""
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

	# Add damage upgrade
	if not army_unit.upgrades.has("damage"):
		army_unit.upgrades["damage"] = 0
	army_unit.upgrades["damage"] += 1

	# Update stats display immediately
	var unit_summary := upgrade_data.get_node_or_null("UnitSummary") as UnitSummary
	if unit_summary:
		unit_summary.update_stats(army_unit.upgrades)

	# Refresh pane (updates button states and text)
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

	# Calculate recruit cost
	var base_cost := _get_unit_base_recruit_cost(enemy_scene)
	var upgrade_cost := _get_unit_upgrade_cost(enemy_scene)
	var total_upgrades := _get_total_upgrades(enemy_upgrades)
	var recruit_cost := base_cost + (upgrade_cost * total_upgrades)
	
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

	# Refresh pane immediately (updates button states and text)
	_refresh_recruit_pane()


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
