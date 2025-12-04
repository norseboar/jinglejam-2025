extends Node
## Autoload singleton that plays UI sounds for all buttons automatically.

@export var button_click_sounds: Array[AudioStream] = [
	preload("res://assets/sfx/click.wav")
]

var audio_player: AudioStreamPlayer


func _ready() -> void:
	# Create audio player (non-positional for UI)
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Connect to tree signals to catch all buttons
	get_tree().node_added.connect(_on_node_added)
	
	# Also connect to any buttons already in the tree
	_connect_existing_buttons(get_tree().root)


func _connect_existing_buttons(node: Node) -> void:
	"""Recursively find and connect all existing buttons."""
	if node is BaseButton:
		_connect_button(node as BaseButton)
	
	for child in node.get_children():
		_connect_existing_buttons(child)


func _on_node_added(node: Node) -> void:
	"""Called when any node is added to the tree."""
	if node is BaseButton:
		# Defer connection to ensure button is fully ready
		_connect_button.call_deferred(node as BaseButton)


func _connect_button(button: BaseButton) -> void:
	"""Connect a button's pressed signal to play click sound."""
	if not button.pressed.is_connected(_play_click_sound):
		button.pressed.connect(_play_click_sound)


func _play_click_sound() -> void:
	"""Play a random click sound."""
	if button_click_sounds.is_empty() or audio_player == null:
		return
	
	var random_index := randi() % button_click_sounds.size()
	var sound: AudioStream = button_click_sounds[random_index]
	if sound != null:
		audio_player.stream = sound
		audio_player.play()

