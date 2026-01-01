extends Control
class_name LevelRoot

## The background texture for this level (used by non-battle screens like upgrade screen)
@export var background_texture: Texture2D

## The gradient overlay texture for this level (deprecated - levels now use tilemaps)
@export var gradient_texture: Texture2D

## The name of the enemy army for this level (shown in battle select screen)
@export var army_name: String = "Enemy Army"

## Container node holding EnemySpawnSlot markers (optional - if not set, will search entire scene)
@export var enemy_spawn_slots_container: Node2D

## Visual bounds area for unit movement (Control node like ColorRect or Panel)
## Units with fly_height < 0 (ground units) will be constrained to stay within these bounds
## Position and resize this Control node in the editor to define the level bounds
@export var level_bounds_area: Control

func _ready() -> void:
	pass


func get_level_bounds() -> Dictionary:
	"""Get the level bounds as a dictionary with 'min_y' and 'max_y' keys.
	Bounds are calculated from the level_bounds_area Control node's position and size.
	Returns default bounds (0, 360) if area is not set.
	"""
	if level_bounds_area == null:
		return {
			"min_y": 0.0,
			"max_y": 360.0
		}
	
	# Get the Control area's global position and size
	var area_global_pos := level_bounds_area.global_position
	var area_size := level_bounds_area.size
	
	# Declare variables at function level
	var min_y: float
	var max_y: float
	
	# Convert from Control/CanvasLayer coordinate space to Node2D gameplay coordinate space
	# The SubViewport uses size_2d_override (640x360) for gameplay, but Control nodes
	# might use the full viewport size (1280x720). We need to convert to gameplay space.
	var game: Game = get_tree().get_first_node_in_group("game") as Game
	if game == null or game.gameplay == null:
		# Fallback: use global position directly
		min_y = area_global_pos.y
		max_y = area_global_pos.y + area_size.y
		return {
			"min_y": min_y,
			"max_y": max_y
		}
	
	# Convert the Control area's global position to gameplay's local space
	# This ensures we're using the same coordinate space as units (640x360)
	var gameplay_transform := game.gameplay.get_global_transform()
	var gameplay_inverse_transform := gameplay_transform.affine_inverse()
	
	var area_pos_in_gameplay := gameplay_inverse_transform * area_global_pos
	min_y = area_pos_in_gameplay.y
	max_y = area_pos_in_gameplay.y + area_size.y
	
	return {
		"min_y": min_y,
		"max_y": max_y
	}
