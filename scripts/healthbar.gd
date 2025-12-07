extends Node2D
class_name Healthbar

## Healthbar component that displays unit health with a vertical fill bar.
## Fill color changes based on alignment (player = green, enemy = red).

@export var player_color: Color = Color(0.2, 0.8, 0.2)  # Green for player units
@export var enemy_color: Color = Color(0.9, 0.2, 0.2)   # Red for enemy units
@export var fill: Sprite2D = null

var is_enemy: bool = false
var fill_texture_height: float = 0.0
var fill_original_position: Vector2 = Vector2.ZERO
var original_x_position: float = 0.0


func _ready() -> void:
	# Store the original X position (for flipping)
	original_x_position = position.x
	
	# Set initial color based on alignment
	_update_color()
	
	# Get the texture height for region calculations
	if fill and fill.texture:
		fill_texture_height = fill.texture.get_height()
		fill_original_position = fill.position
		# Enable region mode
		fill.region_enabled = true
		fill.region_rect = Rect2(0, 0, fill.texture.get_width(), fill_texture_height)


func set_alignment(enemy: bool) -> void:
	"""Set whether this healthbar is for an enemy unit."""
	is_enemy = enemy
	_update_color()
	_update_position()


func _update_position() -> void:
	"""Flip the healthbar position for enemy units."""
	# Flip the X position - if originally at -13, enemies get +13
	position.x = -original_x_position if is_enemy else original_x_position


func update_health(current_hp: int, max_hp: int) -> void:
	"""Update the healthbar fill based on current and max HP."""
	if fill == null or fill.texture == null:
		return
	
	if max_hp <= 0:
		fill.region_rect.size.y = 0.0
		return
	
	# Calculate health fraction (0.0 to 1.0)
	var health_fraction := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	
	# Update region rect to show only the health portion (drains from top)
	var visible_height := fill_texture_height * health_fraction
	var y_start := fill_texture_height - visible_height
	
	fill.region_rect = Rect2(
		0, 
		y_start,
		fill.texture.get_width(), 
		visible_height
	)
	
	# Adjust position to keep the bar anchored at the bottom
	# The center of the region moves as we change y_start and height
	if fill.centered:
		# With centered = true, adjust position to keep bottom edge fixed
		var height_lost := fill_texture_height - visible_height
		fill.position = fill_original_position + Vector2(0, height_lost / 2.0)
	else:
		# With centered = false, adjust offset to compensate for region y position
		fill.offset = Vector2(fill.offset.x, y_start)


func _update_color() -> void:
	"""Update fill color based on alignment."""
	if fill == null:
		return
	
	fill.modulate = enemy_color if is_enemy else player_color
