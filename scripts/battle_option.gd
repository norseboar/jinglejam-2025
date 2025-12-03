extends Control
class_name BattleOption

signal selected(option_index: int)

# Node references (assign in inspector)
@export var army_name_label: Label
@export var enemy_grid: GridContainer
@export var selection_highlight: Control  # A panel/border shown when selected

# State
var option_index: int = 0
var level_scene: PackedScene = null
var is_selected: bool = false


func _ready() -> void:
	# Ensure highlight is hidden by default
	if selection_highlight:
		selection_highlight.visible = false
	
	# Connect click detection
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected.emit(option_index)


func setup(index: int, scene: PackedScene) -> void:
	"""Initialize this option with a level scene."""
	option_index = index
	level_scene = scene
	
	if scene == null:
		return
	
	# Instantiate temporarily to read data
	var level_instance := scene.instantiate() as LevelRoot
	if level_instance == null:
		return
	
	# Set army name
	if army_name_label:
		army_name_label.text = level_instance.army_name
	
	# Populate enemy grid
	_populate_enemy_grid(level_instance)
	
	# Clean up
	level_instance.queue_free()


func _populate_enemy_grid(level_instance: LevelRoot) -> void:
	"""Populate the grid with enemy unit sprites from the level."""
	if enemy_grid == null:
		return
	
	var enemy_markers := level_instance.get_node_or_null("EnemyMarkers")
	if enemy_markers == null:
		return
	
	# Get all slots in the grid
	var slots: Array[Control] = []
	for child in enemy_grid.get_children():
		if child is Control:
			slots.append(child)
	
	# Populate slots with enemy textures
	var slot_index := 0
	for marker in enemy_markers.get_children():
		if not marker is EnemyMarker:
			continue
		if slot_index >= slots.size():
			break
		
		var enemy_marker := marker as EnemyMarker
		if enemy_marker.unit_scene == null:
			continue
		
		var slot := slots[slot_index]
		var texture := _get_texture_from_scene(enemy_marker.unit_scene)
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(texture)
		
		slot_index += 1
	
	# Clear remaining slots
	for i in range(slot_index, slots.size()):
		var slot := slots[i]
		if slot.has_method("set_unit_texture"):
			slot.set_unit_texture(null)


func _get_texture_from_scene(scene: PackedScene) -> Texture2D:
	"""Extract the first frame texture from a unit scene's AnimatedSprite2D."""
	var instance := scene.instantiate()
	var texture: Texture2D = null
	
	# Look for AnimatedSprite2D
	var sprite: AnimatedSprite2D = null
	if instance is AnimatedSprite2D:
		sprite = instance
	elif instance.has_node("AnimatedSprite2D"):
		sprite = instance.get_node("AnimatedSprite2D")
	
	if sprite and sprite.sprite_frames:
		var anim_name := "idle" if sprite.sprite_frames.has_animation("idle") else "default"
		if sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.get_frame_count(anim_name) > 0:
			texture = sprite.sprite_frames.get_frame_texture(anim_name, 0)
	
	instance.queue_free()
	return texture


func set_selected(value: bool) -> void:
	"""Show or hide the selection highlight."""
	is_selected = value
	if selection_highlight:
		selection_highlight.visible = value

