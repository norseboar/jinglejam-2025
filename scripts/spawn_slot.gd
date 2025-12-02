extends Control
class_name SpawnSlot

var is_occupied: bool = false
var is_highlighted: bool = false

@onready var visual: Control = $Visual  # ColorRect or TextureRect child


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_highlighted(active: bool) -> void:
	is_highlighted = active
	if visual:
		visual.modulate = Color(0, 1, 0, 0.5) if active else Color(1, 1, 1, 0.3)


func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if visual:
		visual.modulate = Color(0.5, 0.5, 0.5, 0.3) if occupied else Color(1, 1, 1, 0.3)


func get_slot_center() -> Vector2:
	return global_position + size / 2


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var game := get_tree().get_first_node_in_group("game") as Game
	if game and game.phase != "preparation":
		return false
	
	if not data is Dictionary:
		return false
	if not data.has("army_index"):
		return false
	if is_occupied:
		return false
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("army_index"):
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			var army_index: int = data.get("army_index", -1)
			game.place_unit_from_army(army_index, self)


func _on_mouse_entered() -> void:
	if not is_occupied:
		set_highlighted(true)


func _on_mouse_exited() -> void:
	set_highlighted(false)
