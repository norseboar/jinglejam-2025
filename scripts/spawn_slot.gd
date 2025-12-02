extends Area2D
class_name SpawnSlot

@export var slot_id: String = ""
@export var is_player_slot: bool = true

var is_occupied: bool = false
var is_highlighted: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func set_highlighted(active: bool) -> void:
	is_highlighted = active
	if sprite:
		sprite.modulate = Color(0, 1, 0, 0.5) if active else Color(1, 1, 1, 0.3)

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.3) if occupied else Color(1, 1, 1, 0.3)

func get_slot_center() -> Vector2:
	return global_position

