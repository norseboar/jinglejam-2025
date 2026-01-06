extends Control
class_name UnitDragHandle

## Drag handle overlay for placed units
## Allows dragging units between spawn slots during preparation phase

@export var drag_preview_scene: PackedScene  # Custom scene for drag preview (optional - falls back to simple preview if not set)

var spawn_slot: SpawnSlot = null  # Reference to the spawn slot this unit is on


func _ready() -> void:
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



func _get_drag_data(_at_position: Vector2) -> Variant:
	"""Handle drag-and-drop during preparation phase."""
	# Get parent (could be Unit or Squad)
	var parent := get_parent()
	if not parent:
		return null

	# Check phase - only allow dragging during preparation
	var game := get_tree().get_first_node_in_group("game") as Game
	if not game:
		return null

	if game.phase != "preparation":
		return null

	# Get army_index (works for both Unit and Squad)
	var parent_army_index := -1
	if parent.has("army_index"):
		parent_army_index = parent.army_index

	if parent_army_index < 0:
		return null

	if spawn_slot == null:
		return null

	# Create drag preview
	var preview: Control = null

	# Try to get sprite from first unit child (if parent is Squad)
	var sprite_frames: SpriteFrames = null
	if parent is Squad:
		# Get first Unit child's sprite
		for child in parent.get_children():
			if child is Unit:
				var unit := child as Unit
				if unit.animated_sprite and unit.animated_sprite.sprite_frames:
					sprite_frames = unit.animated_sprite.sprite_frames
					break
	elif parent is Unit:
		var unit := parent as Unit
		if unit.animated_sprite and unit.animated_sprite.sprite_frames:
			sprite_frames = unit.animated_sprite.sprite_frames

	if drag_preview_scene and sprite_frames:
		preview = drag_preview_scene.instantiate() as Control
		if preview:
			var preview_sprite: AnimatedSprite2D = preview.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if preview_sprite:
				preview_sprite.sprite_frames = sprite_frames
				preview_sprite.play("idle")
	else:
		# Fallback
		var color_preview := ColorRect.new()
		color_preview.custom_minimum_size = Vector2(32, 32)
		color_preview.color = Color(0.5, 0.5, 1.0, 0.7)
		preview = color_preview

	set_drag_preview(preview)

	# Return drag data
	return {
		"army_index": parent_army_index,
		"source_spawn_slot": spawn_slot,
		"is_repositioning": true
	}

