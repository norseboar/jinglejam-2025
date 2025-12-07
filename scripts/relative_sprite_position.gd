extends Control
class_name RelativeSpritePosition

## Control script that positions an AnimatedSprite2D child at a relative position
## within the Control, maintaining that position as the screen resizes.
## 
## Calculates the ratio from the sprite's initial position at the reference size,
## then uses that ratio to maintain the relative position when the screen resizes.

@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var reference_size: Vector2 = Vector2(1280, 720)  # Default screen size used for ratio calculation
@export var enable_scaling: bool = true  # Whether to scale the sprite based on screen size
@export_enum("Average", "Width", "Height", "Smaller", "Larger") var scale_mode: String = "Average"  # How to calculate scale factor

var animated_sprite: AnimatedSprite2D = null
var position_ratio: Vector2 = Vector2.ZERO  # Calculated ratio (x_ratio, y_ratio)
var base_scale: Vector2 = Vector2.ONE  # Original scale of the sprite

func _ready() -> void:
	# Get the AnimatedSprite2D reference
	if sprite_path != NodePath():
		animated_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	
	# If not found via path, try to find it as a child
	if animated_sprite == null:
		for child in get_children():
			if child is AnimatedSprite2D:
				animated_sprite = child as AnimatedSprite2D
				break
	
	if animated_sprite == null:
		return
	
	# Store the original scale
	base_scale = animated_sprite.scale
	
	# Calculate the ratio from the sprite's current position
	# This assumes the sprite was positioned at the reference size in the editor
	var initial_pos := animated_sprite.position
	
	# Always use reference size for ratio calculation
	position_ratio.x = initial_pos.x / reference_size.x
	position_ratio.y = initial_pos.y / reference_size.y
	
	# Update position initially
	_update_sprite_position()
	
	# Connect to viewport size changes
	if get_viewport():
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Also connect to Control's size changes (in case Control resizes independently)
	if not resized.is_connected(_on_control_resized):
		resized.connect(_on_control_resized)

func _on_viewport_size_changed() -> void:
	_update_sprite_position()

func _on_control_resized() -> void:
	_update_sprite_position()

func _update_sprite_position() -> void:
	if animated_sprite == null:
		return
	
	# Get the Control's current size (or use viewport size if Control fills screen)
	var control_size := size
	
	if control_size == Vector2.ZERO:
		# Fallback to viewport size if Control hasn't been sized yet
		control_size = get_viewport().get_visible_rect().size
	
	# Calculate position based on the stored ratio
	var target_x := control_size.x * position_ratio.x
	var target_y := control_size.y * position_ratio.y
	var new_pos := Vector2(target_x, target_y)
	
	# Calculate scale based on screen size vs reference size
	var scale_factor := 1.0
	if enable_scaling:
		var width_ratio := control_size.x / reference_size.x
		var height_ratio := control_size.y / reference_size.y
		
		match scale_mode:
			"Average":
				scale_factor = (width_ratio + height_ratio) / 2.0
			"Width":
				scale_factor = width_ratio
			"Height":
				scale_factor = height_ratio
			"Smaller":
				scale_factor = min(width_ratio, height_ratio)
			"Larger":
				scale_factor = max(width_ratio, height_ratio)
	
	var new_scale := base_scale * scale_factor
	
	# Set the sprite's position and scale
	animated_sprite.position = new_pos
	if enable_scaling:
		animated_sprite.scale = new_scale
