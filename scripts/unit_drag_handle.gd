extends Control
class_name UnitDragHandle

## Drag handle overlay for placed units
## Allows dragging units between spawn slots during preparation phase

@export var drag_preview_scene: PackedScene  # Custom scene for drag preview (optional - falls back to simple preview if not set)

var spawn_slot: SpawnSlot = null  # Reference to the spawn slot this unit is on


func _ready() -> void:
	print("UnitDragHandle._ready() called")
	
	# Make the control clickable but invisible
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	
	# Set size to cover the unit sprite (approximate)
	custom_minimum_size = Vector2(48, 48)
	size = Vector2(48, 48)
	
	# Center on parent unit
	position = Vector2(-24, -24)
	
	# Get spawn slot reference from parent unit
	var unit := get_parent() as Unit
	if unit:
		spawn_slot = unit.spawn_slot
	
	print("UnitDragHandle setup complete - position: %s, size: %s, mouse_filter: %s" % [position, size, mouse_filter])
	print("Parent: %s, global_position: %s, spawn_slot: %s" % [get_parent(), global_position, spawn_slot])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		print("UnitDragHandle: MOUSE BUTTON EVENT - button: %d, pressed: %s, position: %s" % [mouse_event.button_index, mouse_event.pressed, mouse_event.position])


func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Handle drag-and-drop during preparation phase."""
	print("UnitDragHandle._get_drag_data() called at position: %s" % _at_position)
	
	# Get parent unit
	var unit := get_parent() as Unit
	if not unit:
		print("UnitDragHandle: No parent unit found")
		return null
	
	print("UnitDragHandle: Parent unit found - army_index: %d" % unit.army_index)
	
	# Check phase - only allow dragging during preparation
	var game := get_tree().get_first_node_in_group("game") as Game
	if not game:
		print("UnitDragHandle: Game not found")
		return null
	
	print("UnitDragHandle: Game phase: %s" % game.phase)
	
	if game.phase != "preparation":
		print("UnitDragHandle: Not in preparation phase, blocking drag")
		return null
	
	# Ensure we have valid data
	if unit.army_index < 0:
		print("UnitDragHandle: Invalid army_index: %d" % unit.army_index)
		return null
	
	if spawn_slot == null:
		print("UnitDragHandle: spawn_slot is null")
		return null
	
	# Create drag preview - use custom scene if provided, otherwise fallback to simple preview
	var preview: Control = null
	
	if drag_preview_scene:
		# Use custom drag preview scene (assumes it has an AnimatedSprite2D child)
		preview = drag_preview_scene.instantiate() as Control
		if preview:
			# Find AnimatedSprite2D child (assumes it exists)
			var preview_sprite: AnimatedSprite2D = preview.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if preview_sprite and unit.animated_sprite and unit.animated_sprite.sprite_frames:
				preview_sprite.sprite_frames = unit.animated_sprite.sprite_frames
				preview_sprite.play("idle")
	else:
		# Fallback to colored rectangle if no preview scene
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview
	
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"army_index": unit.army_index,
		"source_spawn_slot": spawn_slot,
		"is_repositioning": true
	}

