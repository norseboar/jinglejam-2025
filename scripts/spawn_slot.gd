extends Control
class_name SpawnSlot

@export var center_offset: Vector2 = Vector2.ZERO
@export var visual: AnimatedSprite2D  ## Assign the AnimatedSprite2D in the editor
@export var idle_color: Color = Color(1, 1, 1, 0.5)  ## Color when not hovered
@export var hovered_color: Color = Color(0, 1, 0, 1)  ## Color when hovered with a unit

var is_occupied: bool = false
var is_highlighted: bool = false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if visual:
		visual.play("pulse")
		visual.modulate = idle_color


func set_highlighted(active: bool) -> void:
	is_highlighted = active
	if visual:
		visual.modulate = hovered_color if active else idle_color


func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if visual:
		visual.visible = not occupied
		if not occupied:
			visual.modulate = idle_color


func get_slot_center() -> Vector2:
	return global_position + size / 2 + center_offset


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var game := get_tree().get_first_node_in_group("game") as Game
	if game and game.phase != "preparation":
		return false
	
	if not data is Dictionary:
		return false
	
	# Accept either army_index (old) or army_unit (new UnitSlot)
	if not data.has("army_index") and not data.has("army_unit"):
		return false
	
	if is_occupied:
		return false
	
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	
	var army_index: int = -1
	
	# Handle new UnitSlot format (has army_unit and army_index)
	if data.has("army_index"):
		army_index = data.get("army_index", -1)
	# Fallback: if only army_unit provided, we'd need to look it up
	# But UnitSlot always provides army_index, so this shouldn't be needed
	
	if army_index >= 0:
		var game := get_tree().get_first_node_in_group("game") as Game
		if game:
			game.place_unit_from_army(army_index, self)


func _on_mouse_entered() -> void:
	if not is_occupied and _is_dragging_unit():
		set_highlighted(true)


func _on_mouse_exited() -> void:
	if is_highlighted:
		set_highlighted(false)


func _is_dragging_unit() -> bool:
	if not get_viewport().gui_is_dragging():
		return false
	var drag_data = get_viewport().gui_get_drag_data()
	if not drag_data is Dictionary:
		return false
	return drag_data.has("army_index") or drag_data.has("army_unit")
