extends Control
class_name SpawnSlot

@export var slot_id: String = ""
@export var is_player_slot: bool = true

var is_occupied: bool = false
var is_highlighted: bool = false

@onready var visual: Control = $Visual  # ColorRect or TextureRect child


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	custom_minimum_size = Vector2(32, 32)
	size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("[SpawnSlot] _ready: ", name, " mouse_filter: ", mouse_filter, " global_pos: ", global_position, " size: ", size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("[SpawnSlot] _gui_input on: ", name)


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
	print("[SpawnSlot] _can_drop_data called on: ", name, " data: ", data)
	var game := get_tree().get_first_node_in_group("game") as Game
	if game and game.phase != "preparation":
		print("[SpawnSlot] Rejected: not preparation phase")
		return false
	
	if not data is Dictionary:
		print("[SpawnSlot] Rejected: not a Dictionary")
		return false
	if not data.has("unit_type"):
		print("[SpawnSlot] Rejected: no unit_type")
		return false
	if is_occupied:
		print("[SpawnSlot] Rejected: occupied")
		return false
	print("[SpawnSlot] Accepting drop")
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("[SpawnSlot] _drop_data called on: ", name, " data: ", data)
	if data is Dictionary and data.has("unit_type"):
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			print("[SpawnSlot] Placing unit: ", data["unit_type"])
			game.place_unit_on_slot(data["unit_type"], self)
		else:
			print("[SpawnSlot] ERROR: Game not found!")


func _on_mouse_entered() -> void:
	if not is_occupied:
		set_highlighted(true)


func _on_mouse_exited() -> void:
	set_highlighted(false)
