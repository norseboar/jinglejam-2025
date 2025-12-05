extends Control
class_name BattleOption

signal selected(option_index: int)

# Node references (assign in inspector)
@export var army_name_label: Label
@export var enemy_slot_group: UnitSlotGroup
@export var selection_highlight: Control  # A panel/border shown when selected
@export var click_area: Control  # A full-screen clickable area (ColorRect/Panel) that covers the whole option

# State
var option_index: int = 0
var level_scene: PackedScene = null
var option_data: BattleOptionData = null  # New: holds generated battle data
var is_selected: bool = false


func _ready() -> void:
	# Ensure highlight is hidden by default
	if selection_highlight:
		selection_highlight.visible = false
	
	# Connect click detection - prefer click_area if provided, otherwise use self
	if click_area:
		click_area.gui_input.connect(_on_gui_input)
	else:
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
	
	# Populate enemy slots
	_populate_enemy_slots(level_instance)
	
	# Clean up
	level_instance.queue_free()


func setup_from_data(index: int, data: BattleOptionData) -> void:
	"""Initialize this option with generated battle data."""
	option_index = index
	option_data = data
	level_scene = data.battlefield  # Store battlefield as level_scene for compatibility

	# Set army name from roster
	if army_name_label and data.roster:
		army_name_label.text = data.roster.team_name

	# Populate enemy slots from generated army
	_populate_slots_from_army(data.army)


func _populate_slots_from_army(generated_army: Array[ArmyUnit]) -> void:
	"""Populate the UnitSlotGroup with units from the generated army."""
	if enemy_slot_group == null:
		return

	var slots := enemy_slot_group.slots

	for i in range(slots.size()):
		var slot := slots[i]
		if i < generated_army.size():
			# Create a copy of the ArmyUnit for display
			var army_unit := generated_army[i]
			slot.set_unit(army_unit)
		else:
			slot.set_unit(null)


func _populate_enemy_slots(level_instance: LevelRoot) -> void:
	"""Populate the UnitSlotGroup with enemy units from the level."""
	if enemy_slot_group == null:
		return
	
	var enemy_markers := level_instance.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return
	
	# Get slots from UnitSlotGroup
	var slots := enemy_slot_group.slots
	
	# Create ArmyUnit objects from EnemyMarker data and populate slots
	var slot_index := 0
	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue
		if slot_index >= slots.size():
			break
		
		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue
		
		# Create ArmyUnit from EnemyMarker data
		var army_unit := ArmyUnit.new()
		army_unit.unit_scene = enemy_marker.unit_scene
		army_unit.unit_type = enemy_marker.unit_scene.resource_path.get_file().get_basename()
		army_unit.upgrades = enemy_marker.upgrades.duplicate()
		army_unit.placed = false
		
		# Set unit on slot
		var slot := slots[slot_index]
		slot.set_unit(army_unit)
		
		slot_index += 1
	
	# Clear remaining slots
	for i in range(slot_index, slots.size()):
		var slot := slots[i]
		slot.set_unit(null)


func set_selected(value: bool) -> void:
	"""Show or hide the selection highlight."""
	is_selected = value
	if selection_highlight:
		selection_highlight.visible = value

