extends Control
class_name UnitDragHandle

## Drag handle overlay for placed units
## Allows dragging units between spawn slots during preparation phase

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
	
	# Ensure drag handle is on top
	z_index = 100
	
	print("UnitDragHandle setup complete - position: %s, size: %s, mouse_filter: %s, z_index: %d" % [position, size, mouse_filter, z_index])
	print("Parent: %s, global_position: %s" % [get_parent(), global_position])


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
	
	# Create drag preview - use the unit's sprite
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	
	# Try to get texture from unit's animated sprite
	if unit.animated_sprite and unit.animated_sprite.sprite_frames:
		var anim_name := "idle" if unit.animated_sprite.sprite_frames.has_animation("idle") else "default"
		if unit.animated_sprite.sprite_frames.has_animation(anim_name):
			var frame_count := unit.animated_sprite.sprite_frames.get_frame_count(anim_name)
			if frame_count > 0:
				var texture := unit.animated_sprite.sprite_frames.get_frame_texture(anim_name, 0)
				if texture:
					preview.texture = texture
					preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"army_index": unit.army_index,
		"source_spawn_slot": spawn_slot,
		"is_repositioning": true
	}

