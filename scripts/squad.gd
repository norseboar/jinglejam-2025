extends Node2D
class_name Squad

## Container for spawning multiple units in formation
## Handles drag-and-drop for the entire squad

var army_index := -1  # Index in Game.army array
var spawn_slot: SpawnSlot = null  # Which spawn slot this squad occupies
var drag_handle: UnitDragHandle = null  # Reference to drag handle child

# Position markers for unit placement (can be set in inspector or found automatically)
@export var position_markers: Array[Marker2D] = []


func _ready() -> void:
	# Collect position markers if not already set in inspector
	if position_markers.is_empty():
		_collect_position_markers()

	# Get drag handle reference if not set
	if drag_handle == null:
		drag_handle = get_node_or_null("DragHandle") as UnitDragHandle


func _collect_position_markers() -> void:
	"""Find and collect position markers by name."""
	position_markers.clear()
	for i in range(1, 7):
		var marker := get_node_or_null("Position%d" % i) as Marker2D
		if marker:
			position_markers.append(marker)


func setup(unit_scene: PackedScene, squad_count: int, upgrades: Dictionary, is_enemy: bool, enemy_container: Node2D, friendly_container: Node2D) -> void:
	"""Instantiate units at marker positions and configure them."""
	if unit_scene == null:
		push_error("Squad.setup called with null unit_scene")
		return

	# Ensure position markers are collected (defensive - handles case where setup() called before _ready())
	if position_markers.is_empty():
		_collect_position_markers()

	# Clamp squad_count to available positions
	var spawn_count := mini(squad_count, position_markers.size())
	
	# Spawn units at first 'squad_count' positions
	for i in range(spawn_count):
		var marker := position_markers[i]
		var unit: Unit = unit_scene.instantiate() as Unit
		if unit == null:
			push_error("Failed to instantiate unit in squad")
			continue

		# Configure unit properties BEFORE adding to tree
		unit.is_enemy = is_enemy
		unit.enemy_container = enemy_container
		unit.friendly_container = friendly_container
		unit.upgrades = upgrades.duplicate()
		unit.army_index = army_index  # Pass through army_index to units

		# Add unit as child at marker position
		add_child(unit)
		unit.position = marker.position

		# Store initial Y position (relative to squad)
		unit.initial_y_position = unit.global_position.y

		# Apply upgrades after added to tree
		unit.apply_upgrades()
