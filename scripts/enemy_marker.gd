extends Marker2D
class_name EnemyMarker

## The unit scene to spawn at this marker position
@export var unit_scene: PackedScene

## Upgrades for the enemy unit (e.g., { "hp": 2, "damage": 1 })
@export var upgrades: Dictionary = {}

