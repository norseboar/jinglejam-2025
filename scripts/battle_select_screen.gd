extends Control
class_name BattleSelectScreen

signal advance_pressed(level_scene: PackedScene)

# Node references (assign in inspector)
@export var options_container: Container  # HBoxContainer or similar
@export var advance_button: Button

# Scene to instantiate for each option
@export var battle_option_scene: PackedScene

# State
var options: Array[BattleOption] = []
var selected_index: int = 0
var level_scenes: Array[PackedScene] = []


func _ready() -> void:
	# Connect advance button
	if advance_button:
		advance_button.pressed.connect(_on_advance_button_pressed)
	
	# Start hidden
	visible = false


func show_battle_select(scenes: Array[PackedScene]) -> void:
	"""Show the battle select screen with the given level scene options."""
	level_scenes = scenes
	selected_index = 0
	
	# Clear existing options
	_clear_options()
	
	# Create option for each scene
	for i in range(scenes.size()):
		var scene := scenes[i]
		_add_option(i, scene)
	
	# Pre-select first option
	if options.size() > 0:
		options[0].set_selected(true)
	
	# Show screen
	visible = true


func hide_battle_select() -> void:
	"""Hide the battle select screen."""
	visible = false
	_clear_options()


func _clear_options() -> void:
	"""Remove all option instances from the container."""
	for option in options:
		option.queue_free()
	options.clear()


func _add_option(index: int, scene: PackedScene) -> void:
	"""Add a battle option to the container."""
	if battle_option_scene == null or options_container == null:
		push_error("battle_option_scene or options_container not assigned!")
		return
	
	var option := battle_option_scene.instantiate() as BattleOption
	if option == null:
		push_error("Failed to instantiate BattleOption!")
		return
	
	options_container.add_child(option)
	option.setup(index, scene)
	option.selected.connect(_on_option_selected)
	options.append(option)


func _on_option_selected(index: int) -> void:
	"""Handle option selection."""
	# Deselect previous
	if selected_index >= 0 and selected_index < options.size():
		options[selected_index].set_selected(false)
	
	# Select new
	selected_index = index
	if index >= 0 and index < options.size():
		options[index].set_selected(true)


func _on_advance_button_pressed() -> void:
	"""Handle advance button press."""
	if selected_index < 0 or selected_index >= level_scenes.size():
		push_error("Invalid selected_index: %d" % selected_index)
		return
	
	var selected_scene := level_scenes[selected_index]
	advance_pressed.emit(selected_scene)

