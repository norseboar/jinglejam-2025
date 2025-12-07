extends Control
class_name BattleSelectScreen

signal advance_pressed(option_data: BattleOptionData)

# Node references (assign in inspector)
@export var options_container: Container  # HBoxContainer or similar
@export var advance_button: BaseButton

# Scene to instantiate for each option
@export var battle_option_scene: PackedScene
@export var background_texture: Texture2D

# State
var options: Array[BattleOption] = []
var selected_index: int = 0
var option_data_list: Array[BattleOptionData] = []  # Replaces level_scenes


func _ready() -> void:
	# Connect advance button
	if advance_button:
		advance_button.pressed.connect(_on_advance_button_pressed)
	
	# Start hidden
	visible = false


func show_battle_select(scenes: Array[PackedScene]) -> void:
	"""Show the battle select screen with the given level scene options (legacy method)."""
	# This method is kept for backward compatibility but should use show_battle_select_generated instead
	selected_index = 0
	_apply_background_texture()
	
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


func show_battle_select_generated(data_list: Array[BattleOptionData]) -> void:
	"""Show the battle select screen with generated battle options."""
	option_data_list = data_list
	selected_index = 0
	_apply_background_texture()

	# Clear existing options
	_clear_options()

	# Create option for each data
	for i in range(data_list.size()):
		var data := data_list[i]
		_add_option_from_data(i, data)

	# Pre-select first option
	if options.size() > 0:
		options[0].set_selected(true)

	# Show screen
	visible = true


func _add_option_from_data(index: int, data: BattleOptionData) -> void:
	"""Add a battle option from generated data."""
	if battle_option_scene == null or options_container == null:
		push_error("battle_option_scene or options_container not assigned!")
		return

	var option := battle_option_scene.instantiate() as BattleOption
	if option == null:
		push_error("Failed to instantiate BattleOption!")
		return

	options_container.add_child(option)
	option.setup_from_data(index, data)
	option.selected.connect(_on_option_selected)
	options.append(option)


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
	if selected_index < 0 or selected_index >= option_data_list.size():
		push_error("Invalid selected_index: %d" % selected_index)
		return

	var selected_data := option_data_list[selected_index]
	advance_pressed.emit(selected_data)


func _apply_background_texture() -> void:
	"""Apply this screen's background texture to the game's background, if available."""
	if background_texture == null:
		return
	var game := _get_game()
	if game and game.background_rect:
		game.background_rect.texture = background_texture


func _get_game() -> Game:
	return get_tree().get_first_node_in_group("game") as Game
