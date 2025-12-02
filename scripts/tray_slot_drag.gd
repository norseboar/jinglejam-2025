extends Control

# This script is attached to tray slots to handle drag-and-drop

@export var texture_rect: TextureRect  # Assign in inspector


func set_unit_texture(texture: Texture2D) -> void:
	"""Set the unit texture to display in this slot."""
	if texture_rect:
		texture_rect.texture = texture


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Get army index from metadata (this is the index into the army array)
	var army_index: int = get_meta("slot_index", -1)
	if army_index < 0:
		return null
	
	# Find HUD by traversing up the tree
	var hud: HUD = null
	var current := get_parent()
	while current:
		if current is HUD:
			hud = current as HUD
			break
		current = current.get_parent()
	
	if not hud:
		return null
	
	# Check if we're in preparation phase
	if hud.current_phase != "preparation":
		return null
	
	# Create preview with sprite texture
	var unit_texture: Texture2D = null
	if texture_rect and texture_rect.texture:
		unit_texture = texture_rect.texture
	
	# Wrap preview in a container so we can offset it to center on cursor
	var preview_container := Control.new()
	preview_container.custom_minimum_size = Vector2(32, 32)
	
	var preview: Control
	if unit_texture:
		# Use TextureRect to show the sprite
		var texture_preview := TextureRect.new()
		texture_preview.texture = unit_texture
		texture_preview.custom_minimum_size = Vector2(32, 32)
		texture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview = texture_preview
	else:
		# Fallback to colored rectangle if no texture
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview
	
	# Offset preview so it's centered on cursor
	preview.position = Vector2(-16, -16)
	preview_container.add_child(preview)
	set_drag_preview(preview_container)
	
	return {
		"army_index": army_index,
		"unit_texture": unit_texture
	}
