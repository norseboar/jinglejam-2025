extends Node2D
class_name LevelRoot

## The background texture for this level (used by non-battle screens like upgrade screen)
@export var background_texture: Texture2D

## The gradient overlay texture for this level (deprecated - levels now use tilemaps)
@export var gradient_texture: Texture2D

## The name of the enemy army for this level (shown in battle select screen)
@export var army_name: String = "Enemy Army"

## Container node holding EnemySpawnSlot markers (optional - if not set, will search entire scene)
@export var enemy_spawn_slots_container: Node2D

## Container for player units (should be a Node2D with y_sort_enabled)
@export var player_units: Node2D

## Container for enemy units (should be a Node2D with y_sort_enabled)
@export var enemy_units: Node2D

## End zone X coordinates for default unit navigation
## Player units move toward end_zone_x_player, enemies move toward end_zone_x_enemy
@export var end_zone_x_player: float = 600.0  # Right side of screen
@export var end_zone_x_enemy: float = 40.0    # Left side of screen

func _ready() -> void:
	pass


func get_end_zone_position(is_enemy: bool, y_position: float) -> Vector2:
	"""Get the end zone target position for a unit based on their team and Y position.
	Units target the opposite side of the map at their starting Y coordinate."""
	var x := end_zone_x_enemy if is_enemy else end_zone_x_player
	return Vector2(x, y_position)
