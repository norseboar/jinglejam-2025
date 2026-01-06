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
	
	# Allow repositioning onto occupied slots (will swap/move)
	# But block initial placement onto occupied slots
	if is_occupied and not data.get("is_repositioning", false):
		return false
	
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	
	var army_index: int = data.get("army_index", -1)
	if army_index < 0:
		return
	
	var game := get_tree().get_first_node_in_group("game") as Game
	if not game:
		return
	
	# Check if this is a repositioning operation
	if data.get("is_repositioning", false):
		# Moving an existing unit
		var source_slot: SpawnSlot = data.get("source_spawn_slot")
		if source_slot and source_slot != self:
			# Free up the source slot
			source_slot.set_occupied(false)
		
		# Find the squad in the player_units container
		if game.current_level and game.current_level.player_units:
			for child in game.current_level.player_units.get_children():
				if child is Squad:
					var squad := child as Squad
					if squad.army_index == army_index:
						# Move the squad to new position
						squad.global_position = get_slot_center()
						squad.spawn_slot = self

						# Update drag handle reference
						if squad.drag_handle:
							squad.drag_handle.spawn_slot = self

						# Mark new slot as occupied
						set_occupied(true)
						break
	else:
		# Initial placement - use existing logic
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
